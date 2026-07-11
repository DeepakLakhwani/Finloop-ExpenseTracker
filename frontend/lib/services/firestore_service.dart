import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  String? _lastUid;
  Future<void>? _initFuture;

  // --- User & Initial Setup ---

  Future<void> initializeUser() async {
    final uid = _uid;
    if (uid == null) return;

    if (uid != _lastUid) {
      _initFuture = null;
      _lastUid = uid;
    }

    if (_initFuture != null) {
      return _initFuture!;
    }

    _initFuture = _runInitialization(uid);
    return _initFuture!;
  }

  Future<void> _runInitialization(String uid) async {
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        await _db.collection('users').doc(uid).set({
          'email': _auth.currentUser?.email,
          'displayName': _auth.currentUser?.displayName ?? '',
          'defaultCurrency': 'USD',
          'createdAt': FieldValue.serverTimestamp(),
          'hasSeededDummyData':
              true, // New users don't need seeding from dashboard_screen
          'hasCleanedDummyData':
              true, // New users don't need dummy data cleanup either
        });
        await _createDefaultCategories();
      }

      // Check and seed main accounts if empty
      final mainAccountsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('main_accounts')
          .limit(1)
          .get();
      if (mainAccountsSnap.docs.isEmpty) {
        await _createDefaultMainAccounts();
      }

      // Check and seed sub-accounts if empty
      final accountsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .limit(1)
          .get();
      if (accountsSnap.docs.isEmpty) {
        await _createDefaultAccounts();
      }

      // Migration: update 'Bank Account' / 'Bank' main accounts to 'Account'
      final legacyMainAccounts = await _db
          .collection('users')
          .doc(uid)
          .collection('main_accounts')
          .where('name', whereIn: ['Bank Account', 'Bank'])
          .get();
      for (var doc in legacyMainAccounts.docs) {
        await doc.reference.update({'name': 'Account'});
      }

      // Migration: update 'Bank Account' / 'Bank' sub-accounts type to 'Account'
      final legacyAccounts = await _db
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .where('type', whereIn: ['Bank Account', 'Bank'])
          .get();
      for (var doc in legacyAccounts.docs) {
        await doc.reference.update({'type': 'Account'});
      }

      // Migration: if they have a sub-account named 'Accounts', rename it to 'Account'
      final pluralAccounts = await _db
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .where('name', isEqualTo: 'Accounts')
          .where('type', isEqualTo: 'Account')
          .get();
      for (var doc in pluralAccounts.docs) {
        await doc.reference.update({'name': 'Account'});
      }
    } catch (e) {
      debugPrint("Firestore initialization error: $e");
      // Reset future on error to allow retry
      _initFuture = null;
    }
  }

  Future<bool> hasSeededDummyData() async {
    final uid = _uid;
    if (uid == null) return true;
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    final data = userDoc.data();
    return data?['hasSeededDummyData'] == true;
  }

  Future<void> setHasSeededDummyData() async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'hasSeededDummyData': true,
    }, SetOptions(merge: true));
  }

  Future<bool> hasCleanedDummyData() async {
    final uid = _uid;
    if (uid == null) return true;
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return false;
    final data = userDoc.data();
    return data?['hasCleanedDummyData'] == true;
  }

  Future<void> setHasCleanedDummyData() async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'hasCleanedDummyData': true,
    }, SetOptions(merge: true));
  }

  Future<void> cleanupDummyData() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final accountsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .get();
      String? dummyAccountId;
      for (var doc in accountsSnap.docs) {
        final data = doc.data();
        final name = data['name']?.toString();
        final type = data['type']?.toString();
        final balance = double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0;
        // Only target the seeded dummy cash account (which starts with 50000.0)
        // rather than the newly created default Cash sub-account (which starts with 0.0)
        if (name == 'Cash' && 
            (type == 'Cash' || type == 'Cash/Cash wallet') && 
            (balance - 50000.0).abs() < 0.01) {
          dummyAccountId = doc.id;
          break;
        }
      }

      final batch = _db.batch();
      bool hasDeletes = false;

      if (dummyAccountId != null) {
        batch.delete(
          _db
              .collection('users')
              .doc(uid)
              .collection('accounts')
              .doc(dummyAccountId),
        );
        hasDeletes = true;
      }

      final txsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .get();
      for (var doc in txsSnap.docs) {
        final data = doc.data();
        final accId =
            data['account_id']?.toString() ?? data['accountId']?.toString();
        final note =
            data['note']?.toString() ?? data['description']?.toString();
        if (accId == dummyAccountId || note == 'Salary' || note == 'Dinner') {
          batch.delete(
            _db
                .collection('users')
                .doc(uid)
                .collection('transactions')
                .doc(doc.id),
          );
          hasDeletes = true;
        }
      }

      if (hasDeletes) {
        await batch.commit();
        debugPrint("Dummy data cleaned up successfully!");
      }
    } catch (e) {
      debugPrint("Error cleaning up dummy data: $e");
    }
  }

  Future<void> _createDefaultCategories() async {
    final uid = _uid;
    if (uid == null) return;
    final categories = [
      // Income Categories
      {
        'name': '💼 Salary & Work',
        'type': 'Income',
        'icon': 'work',
        'color': '#10B981',
        'key': 'cat_salary',
      },
      {
        'name': '💵 Petty cash',
        'type': 'Income',
        'icon': 'payments',
        'color': '#84CC16',
        'key': 'cat_petty_cash',
      },
      {
        'name': '🎁 Bonus',
        'type': 'Income',
        'icon': 'card_giftcard',
        'color': '#EAB308',
        'key': 'cat_bonus',
      },
      {
        'name': '🏆 Rewards',
        'type': 'Income',
        'icon': 'stars',
        'color': '#F59E0B',
        'key': 'cat_rewards',
      },
      {
        'name': 'Opening Balance',
        'type': 'Income',
        'icon': 'account_balance_wallet',
        'color': '#9CA3AF',
        'key': 'cat_opening_balance',
      },

      // Expense Categories
      {
        'name': '🏠Home & Living',
        'type': 'Expense',
        'icon': 'home',
        'color': '#EF4444',
        'key': 'cat_home_living',
      },
      {
        'name': '🍔Food & Dining',
        'type': 'Expense',
        'icon': 'restaurant',
        'color': '#F97316',
        'key': 'cat_food_dining',
      },
      {
        'name': '🚗 Transportation',
        'type': 'Expense',
        'icon': 'directions_car',
        'color': '#3B82F6',
        'key': 'cat_transportation',
      },
      {
        'name': '🛍 Shopping',
        'type': 'Expense',
        'icon': 'shopping_bag',
        'color': '#EC4899',
        'key': 'cat_shopping',
      },
      {
        'name': '🎬 Entertainment',
        'type': 'Expense',
        'icon': 'movie',
        'color': '#8B5CF6',
        'key': 'cat_entertainment',
      },
      {
        'name': '🏥Health & Fitness',
        'type': 'Expense',
        'icon': 'medical_services',
        'color': '#FA8072',
        'key': 'cat_health_fitness',
      },
      {
        'name': '📚 Education',
        'type': 'Expense',
        'icon': 'school',
        'color': '#9F1239',
        'key': 'cat_education',
      },
      {
        'name': '💳 Finance',
        'type': 'Expense',
        'icon': 'credit_card',
        'color': '#0F766E',
        'key': 'cat_finance',
      },
      {
        'name': '\u{1F46A} Family',
        'type': 'Expense',
        'icon': 'people',
        'color': '#8D6E63',
        'key': 'cat_family',
      },
      {
        'name': '✈ Travel',
        'type': 'Expense',
        'icon': 'flight',
        'color': '#00E5FF',
        'key': 'cat_travel',
      },

      // Transfer Category
      {
        'name': 'Transfer',
        'type': 'Transfer',
        'icon': 'swap_horiz',
        'color': '#4B5563',
        'key': 'cat_transfer',
      },
    ];

    try {
      final batch = _db.batch();
      for (var cat in categories) {
        final docRef = _db
            .collection('users')
            .doc(uid)
            .collection('categories')
            .doc();
        batch.set(docRef, cat);
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error creating default categories: $e");
    }
  }

  Future<void> _createDefaultAccounts() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final batch = _db.batch();

      // 1. Account default sub-account
      final bankRef = _db
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc();
      batch.set(bankRef, {
        'name': 'Account',
        'type': 'Account',
        'currency': 'USD',
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Cash default sub-account
      final cashRef = _db
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc();
      batch.set(cashRef, {
        'name': 'Cash',
        'type': 'Cash',
        'currency': 'USD',
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint("Default sub-accounts created successfully!");
    } catch (e) {
      debugPrint("Error creating default sub-accounts: $e");
    }
  }

  Future<void> _createDefaultMainAccounts() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final batch = _db.batch();

      // 1. Account default main account
      final bankRef = _db
          .collection('users')
          .doc(uid)
          .collection('main_accounts')
          .doc();
      batch.set(bankRef, {
        'name': 'Account',
        'icon': 'account_balance_outlined',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Cash default main account
      final cashRef = _db
          .collection('users')
          .doc(uid)
          .collection('main_accounts')
          .doc();
      batch.set(cashRef, {
        'name': 'Cash',
        'icon': 'payments_outlined',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Card default main account
      final cardRef = _db
          .collection('users')
          .doc(uid)
          .collection('main_accounts')
          .doc();
      batch.set(cardRef, {
        'name': 'Card',
        'icon': 'credit_card_outlined',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint("Default main accounts created successfully!");
    } catch (e) {
      debugPrint("Error creating default main accounts: $e");
    }
  }

  // --- Accounts ---

  Stream<List<Map<String, dynamic>>> getAccounts() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            if (data['type'] == 'Cash/Cash wallet') {
              data['type'] = 'Cash';
            }
            return {'id': doc.id, ...data};
          }).toList(),
        );
  }

  Future<String> createAccount(Map<String, dynamic> accountData) async {
    final uid = _uid;
    if (uid == null) throw Exception("User not logged in");
    final docRef = await _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .add({...accountData, 'createdAt': FieldValue.serverTimestamp()});
    return docRef.id;
  }

  Future<void> updateAccount(
    String id,
    Map<String, dynamic> accountData,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .doc(id)
        .update({...accountData, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteAccount(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .doc(id)
        .delete();
  }

  Stream<List<Map<String, dynamic>>> getMainAccounts() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('main_accounts')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getMainAccountsList() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('main_accounts')
        .get();
    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> createMainAccount(Map<String, dynamic> accountData) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('main_accounts').add({
      ...accountData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMainAccount(
    String id,
    Map<String, dynamic> data,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('main_accounts')
        .doc(id)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteMainAccount(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('main_accounts')
        .doc(id)
        .delete();
  }

  Future<Map<String, dynamic>> getAccountSummary() async {
    final uid = _uid;
    if (uid == null) return {'totalBalance': 0.0, 'accountCount': 0};
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .get();
      double totalBalance = 0;
      int accountCount = snapshot.docs.length;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] != 'Credit Card' && data['type'] != 'Card') {
          totalBalance +=
              (double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0);
        }
      }

      return {'totalBalance': totalBalance, 'accountCount': accountCount};
    } catch (e) {
      debugPrint("Error getting account summary: $e");
      return {'totalBalance': 0.0, 'accountCount': 0};
    }
  }

  // --- Categories ---

  Stream<List<Map<String, dynamic>>> getCategories() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) {
            await _createDefaultCategories();
            final newSnap = await _db
                .collection('users')
                .doc(uid)
                .collection('categories')
                .get();
            return newSnap.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
          }
          final List<Map<String, dynamic>> results = [];
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final String nameStr = data['name']?.toString() ?? '';

            // Legacy family corrections
            if (nameStr ==
                    '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} Family & Personal' ||
                nameStr == '\u{1F468}\u{1F469}\u{1F467} Family & Personal' ||
                nameStr ==
                    '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} Family' ||
                nameStr == '\u{1F468}\u{1F469}\u{1F467} Family' ||
                nameStr.contains('Family & Personal')) {
              data['name'] = '\u{1F46A} Family';
              _db
                  .collection('users')
                  .doc(uid)
                  .collection('categories')
                  .doc(doc.id)
                  .update({'name': '\u{1F46A} Family'});
            }

            // Assign keys to existing/legacy default categories on-the-fly if missing
            if (data['key'] == null) {
              final cleanName = nameStr
                  .replaceAll(RegExp(r'[^\s\w\&]'), '')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim()
                  .toLowerCase();
              final Map<String, String> nameToKeyMap = {
                'salary & work': 'cat_salary',
                'petty cash': 'cat_petty_cash',
                'bonus': 'cat_bonus',
                'rewards': 'cat_rewards',
                'opening balance': 'cat_opening_balance',
                'home & living': 'cat_home_living',
                'food & dining': 'cat_food_dining',
                'transportation': 'cat_transportation',
                'shopping': 'cat_shopping',
                'entertainment': 'cat_entertainment',
                'health & fitness': 'cat_health_fitness',
                'education': 'cat_education',
                'finance': 'cat_finance',
                'family': 'cat_family',
                'travel': 'cat_travel',
                'transfer': 'cat_transfer',
              };

              final matchedKey = nameToKeyMap[cleanName];
              if (matchedKey != null) {
                data['key'] = matchedKey;
                _db
                    .collection('users')
                    .doc(uid)
                    .collection('categories')
                    .doc(doc.id)
                    .update({'key': matchedKey});
              }
            }
            results.add({'id': doc.id, ...data});
          }
          return results;
        });
  }

  Future<void> createCategory(Map<String, dynamic> categoryData) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .add(categoryData);
  }

  Future<String> createCategoryWithId(Map<String, dynamic> categoryData) async {
    final uid = _uid;
    if (uid == null) throw Exception("User not logged in");
    final ref = await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .add(categoryData);
    return ref.id;
  }

  Future<Map<String, dynamic>?> getOpeningBalanceCategory() async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .where('name', isEqualTo: 'Opening Balance')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return {'id': snap.docs.first.id, ...snap.docs.first.data()};
    }
    return null;
  }

  Future<void> updateCategory(
    String id,
    Map<String, dynamic> categoryData,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(id)
        .update(categoryData);
  }

  Future<void> deleteCategory(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(id)
        .delete();
  }

  // --- Transactions ---

  Stream<List<Map<String, dynamic>>> getTransactions() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<void> createTransaction(Map<String, dynamic> txData) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _db.batch();
    final txRef = _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc();

    batch.set(txRef, {
      ...txData,
      'date': txData['date'] is String
          ? DateTime.parse(txData['date'])
          : txData['date'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _updateBalances(batch, txData, isAddition: true);
    await batch.commit();
  }

  Future<void> updateTransaction(
    String id,
    Map<String, dynamic> newData,
    Map<String, dynamic> oldData,
  ) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _db.batch();
    final txRef = _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(id);

    // 1. Revert old balance changes
    await _updateBalances(batch, oldData, isAddition: false);

    // 2. Apply new balance changes
    await _updateBalances(batch, newData, isAddition: true);

    // 3. Update transaction
    batch.update(txRef, {
      ...newData,
      'date': newData['date'] is String
          ? DateTime.parse(newData['date'])
          : newData['date'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> deleteTransaction(Map<String, dynamic> txData) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _db.batch();
    final txRef = _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(txData['id']);

    // 1. Revert balance changes
    await _updateBalances(batch, txData, isAddition: false);

    // 2. Delete transaction
    batch.delete(txRef);

    await batch.commit();
  }

  Future<void> _updateBalances(
    WriteBatch batch,
    Map<String, dynamic> txData, {
    required bool isAddition,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final accountId =
        txData['account_id']?.toString() ?? txData['accountId']?.toString();
    if (accountId == null) return;

    final accountRef = _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .doc(accountId);
    final amount = (txData['amount'] as num).toDouble();
    final type = txData['type'];

    if (type == 'Transfer') {
      final toAccountId =
          txData['to_account_id']?.toString() ??
          txData['toAccountId']?.toString();
      if (toAccountId == null) return;
      final toAccountRef = _db
          .collection('users')
          .doc(uid)
          .collection('accounts')
          .doc(toAccountId);

      final accountSnap = await accountRef.get();
      final toAccountSnap = await toAccountRef.get();

      if (isAddition) {
        if (accountSnap.exists) {
          batch.update(accountRef, {'balance': FieldValue.increment(-amount)});
        }
        if (toAccountSnap.exists) {
          batch.update(toAccountRef, {'balance': FieldValue.increment(amount)});
        }
      } else {
        if (accountSnap.exists) {
          batch.update(accountRef, {'balance': FieldValue.increment(amount)});
        }
        if (toAccountSnap.exists) {
          batch.update(toAccountRef, {
            'balance': FieldValue.increment(-amount),
          });
        }
      }
    } else {
      double change = type == 'Income' ? amount : -amount;
      if (!isAddition) change = -change;

      final accountSnap = await accountRef.get();
      if (accountSnap.exists) {
        batch.update(accountRef, {'balance': FieldValue.increment(change)});
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAccountTransactions(
    String accountId,
  ) async {
    final uid = _uid;
    if (uid == null) return [];

    final snap1 = await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .where('account_id', isEqualTo: accountId)
        .get();

    final snap2 = await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .where('to_account_id', isEqualTo: accountId)
        .get();

    final results = [
      ...snap1.docs.map((doc) => {'id': doc.id, ...doc.data()}),
      ...snap2.docs.map((doc) => {'id': doc.id, ...doc.data()}),
    ];

    return results;
  }

  Future<List<Map<String, dynamic>>> getAccountsList() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('accounts')
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      if (data['type'] == 'Cash/Cash wallet') {
        data['type'] = 'Cash';
      }
      return {'id': doc.id, ...data};
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getCategoriesList() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('categories')
        .get();

    final List<Map<String, dynamic>> results = [];
    for (var doc in snap.docs) {
      final data = doc.data();
      final String nameStr = data['name']?.toString() ?? '';

      // Assign keys to existing/legacy default categories on-the-fly if missing
      if (data['key'] == null) {
        final cleanName = nameStr
            .replaceAll(RegExp(r'[^\s\w\&]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim()
            .toLowerCase();
        final Map<String, String> nameToKeyMap = {
          'salary & work': 'cat_salary',
          'petty cash': 'cat_petty_cash',
          'bonus': 'cat_bonus',
          'rewards': 'cat_rewards',
          'opening balance': 'cat_opening_balance',
          'home & living': 'cat_home_living',
          'food & dining': 'cat_food_dining',
          'transportation': 'cat_transportation',
          'shopping': 'cat_shopping',
          'entertainment': 'cat_entertainment',
          'health & fitness': 'cat_health_fitness',
          'education': 'cat_education',
          'finance': 'cat_finance',
          'family': 'cat_family',
          'travel': 'cat_travel',
          'transfer': 'cat_transfer',
        };

        final matchedKey = nameToKeyMap[cleanName];
        if (matchedKey != null) {
          data['key'] = matchedKey;
          await _db
              .collection('users')
              .doc(uid)
              .collection('categories')
              .doc(doc.id)
              .update({'key': matchedKey});
        }
      }
      results.add({'id': doc.id, ...data});
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> getTransactionsList() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Stream<DocumentSnapshot> getScratchpadSnapshot() {
    final uid = _uid;
    if (uid == null) throw Exception("User not logged in");
    return _db
        .collection('users')
        .doc(uid)
        .collection('notes')
        .doc('scratchpad')
        .snapshots();
  }

  Stream<List<Map<String, dynamic>>> getBudgets() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<void> createBudget(Map<String, dynamic> budgetData) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('budgets').add({
      ...budgetData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBudget(String id, Map<String, dynamic> budgetData) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('budgets').doc(id).update(
      {...budgetData, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  Future<void> deleteBudget(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(id)
        .delete();
  }

  Future<void> submitFeedback(Map<String, dynamic> feedbackData) async {
    await _db.collection('feedback').add(feedbackData);
  }
}
