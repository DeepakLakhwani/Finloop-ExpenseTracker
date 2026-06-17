import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // --- User & Initial Setup ---

  Future<void> initializeUser() async {
    try {
      final uid = _uid;
      if (uid == null) return;
      
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        await _db.collection('users').doc(uid).set({
          'email': _auth.currentUser?.email,
          'displayName': _auth.currentUser?.displayName ?? '',
          'defaultCurrency': 'USD',
          'createdAt': FieldValue.serverTimestamp(),
          'hasSeededDummyData': true, // New users don't need seeding from dashboard_screen
        });
        await _createDefaultCategories();
        await _createDefaultAccounts();
      }
    } catch (e) {
      debugPrint("Firestore initialization error: $e");
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
      final accountsSnap = await _db.collection('users').doc(uid).collection('accounts').get();
      String? dummyAccountId;
      for (var doc in accountsSnap.docs) {
        final data = doc.data();
        final name = data['name']?.toString();
        final type = data['type']?.toString();
        if (name == 'Cash' && (type == 'Cash' || type == 'Cash/Cash wallet')) {
          dummyAccountId = doc.id;
          break;
        }
      }

      final batch = _db.batch();
      bool hasDeletes = false;

      if (dummyAccountId != null) {
        batch.delete(_db.collection('users').doc(uid).collection('accounts').doc(dummyAccountId));
        hasDeletes = true;
      }

      final txsSnap = await _db.collection('users').doc(uid).collection('transactions').get();
      for (var doc in txsSnap.docs) {
        final data = doc.data();
        final accId = data['account_id']?.toString() ?? data['accountId']?.toString();
        final note = data['note']?.toString() ?? data['description']?.toString();
        if (accId == dummyAccountId || note == 'Salary' || note == 'Dinner') {
          batch.delete(_db.collection('users').doc(uid).collection('transactions').doc(doc.id));
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
      {'name': '💼 Salary & Work', 'type': 'Income', 'icon': 'work', 'color': '#4CAF50'},
      {'name': '💵 Petty cash', 'type': 'Income', 'icon': 'payments', 'color': '#81C784'},
      {'name': '🎁 Bonus', 'type': 'Income', 'icon': 'card_giftcard', 'color': '#FFD54F'},
      {'name': '🏆 Rewards', 'type': 'Income', 'icon': 'stars', 'color': '#FFB300'},
      {'name': 'Opening Balance', 'type': 'Income', 'icon': 'account_balance_wallet', 'color': '#9E9E9E'},

      // Expense Categories
      {'name': '🏠Home & Living', 'type': 'Expense', 'icon': 'home', 'color': '#FF5722'},
      {'name': '🍔Food & Dining', 'type': 'Expense', 'icon': 'restaurant', 'color': '#FF9800'},
      {'name': '🚗 Transportation', 'type': 'Expense', 'icon': 'directions_car', 'color': '#2196F3'},
      {'name': '🛍 Shopping', 'type': 'Expense', 'icon': 'shopping_bag', 'color': '#E91E63'},
      {'name': '🎬 Entertainment', 'type': 'Expense', 'icon': 'movie', 'color': '#9C27B0'},
      {'name': '🏥Health & Fitness', 'type': 'Expense', 'icon': 'medical_services', 'color': '#F44336'},
      {'name': '📚 Education', 'type': 'Expense', 'icon': 'school', 'color': '#03A9F4'},
      {'name': '💳 Finance', 'type': 'Expense', 'icon': 'credit_card', 'color': '#607D8B'},
      {'name': '\u{1F46A} Family', 'type': 'Expense', 'icon': 'people', 'color': '#8D6E63'},
      {'name': '✈ Travel', 'type': 'Expense', 'icon': 'flight', 'color': '#00BCD4'},

      // Transfer Category
      {'name': 'Transfer', 'type': 'Transfer', 'icon': 'swap_horiz', 'color': '#757575'},
    ];

    try {
      final batch = _db.batch();
      for (var cat in categories) {
        final docRef = _db.collection('users').doc(uid).collection('categories').doc();
        batch.set(docRef, cat);
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error creating default categories: $e");
    }
  }

  Future<void> _createDefaultAccounts() async {
    // Only show head accounts by default. Users will create sub accounts manually.
    return;
  }

  // --- Accounts ---

  Stream<List<Map<String, dynamic>>> getAccounts() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('users').doc(uid).collection('accounts')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              if (data['type'] == 'Cash/Cash wallet') {
                data['type'] = 'Cash';
              }
              return {'id': doc.id, ...data};
            }).toList());
  }

  Future<String> createAccount(Map<String, dynamic> accountData) async {
    final uid = _uid;
    if (uid == null) throw Exception("User not logged in");
    final docRef = await _db.collection('users').doc(uid).collection('accounts').add({
      ...accountData,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateAccount(String id, Map<String, dynamic> accountData) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('accounts').doc(id).update({
      ...accountData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAccount(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('accounts').doc(id).delete();
  }

  Future<Map<String, dynamic>> getAccountSummary() async {
    final uid = _uid;
    if (uid == null) return {'totalBalance': 0.0, 'accountCount': 0};
    try {
      final snapshot = await _db.collection('users').doc(uid).collection('accounts').get();
      double totalBalance = 0;
      int accountCount = snapshot.docs.length;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['type'] != 'Credit Card') {
          totalBalance += (double.tryParse(data['balance']?.toString() ?? '0') ?? 0.0);
        }
      }

      return {
        'totalBalance': totalBalance,
        'accountCount': accountCount,
      };
    } catch (e) {
      debugPrint("Error getting account summary: $e");
      return {'totalBalance': 0.0, 'accountCount': 0};
    }
  }

  // --- Categories ---

  Stream<List<Map<String, dynamic>>> getCategories() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('users').doc(uid).collection('categories')
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) {
            await _createDefaultCategories();
            final newSnap = await _db.collection('users').doc(uid).collection('categories').get();
            return newSnap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
          }
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final String nameStr = data['name']?.toString() ?? '';
            if (nameStr == '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} Family & Personal' ||
                nameStr == '\u{1F468}\u{1F469}\u{1F467} Family & Personal' ||
                nameStr == '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} Family' ||
                nameStr == '\u{1F468}\u{1F469}\u{1F467} Family' ||
                nameStr.contains('Family & Personal')) {
              data['name'] = '\u{1F46A} Family';
              // Silently correct the database name in the background
              _db.collection('users').doc(uid).collection('categories').doc(doc.id).update({'name': '\u{1F46A} Family'});
            }
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  Future<void> createCategory(Map<String, dynamic> categoryData) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('categories').add(categoryData);
  }

  Future<String> createCategoryWithId(Map<String, dynamic> categoryData) async {
    final uid = _uid;
    if (uid == null) throw Exception("User not logged in");
    final ref = await _db.collection('users').doc(uid).collection('categories').add(categoryData);
    return ref.id;
  }

  Future<Map<String, dynamic>?> getOpeningBalanceCategory() async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _db.collection('users').doc(uid).collection('categories')
        .where('name', isEqualTo: 'Opening Balance')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return {'id': snap.docs.first.id, ...snap.docs.first.data()};
    }
    return null;
  }

  Future<void> updateCategory(String id, Map<String, dynamic> categoryData) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('categories').doc(id).update(categoryData);
  }

  Future<void> deleteCategory(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('categories').doc(id).delete();
  }

  // --- Transactions ---

  Stream<List<Map<String, dynamic>>> getTransactions() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db.collection('users').doc(uid).collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> createTransaction(Map<String, dynamic> txData) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _db.batch();
    final txRef = _db.collection('users').doc(uid).collection('transactions').doc();
    
    batch.set(txRef, {
      ...txData,
      'date': txData['date'] is String ? DateTime.parse(txData['date']) : txData['date'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _updateBalances(batch, txData, isAddition: true);
    await batch.commit();
  }

  Future<void> updateTransaction(String id, Map<String, dynamic> newData, Map<String, dynamic> oldData) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _db.batch();
    final txRef = _db.collection('users').doc(uid).collection('transactions').doc(id);

    // 1. Revert old balance changes
    await _updateBalances(batch, oldData, isAddition: false);

    // 2. Apply new balance changes
    await _updateBalances(batch, newData, isAddition: true);

    // 3. Update transaction
    batch.update(txRef, {
      ...newData,
      'date': newData['date'] is String ? DateTime.parse(newData['date']) : newData['date'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> deleteTransaction(Map<String, dynamic> txData) async {
    final uid = _uid;
    if (uid == null) return;
    final batch = _db.batch();
    final txRef = _db.collection('users').doc(uid).collection('transactions').doc(txData['id']);

    // 1. Revert balance changes
    await _updateBalances(batch, txData, isAddition: false);

    // 2. Delete transaction
    batch.delete(txRef);

    await batch.commit();
  }

  Future<void> _updateBalances(WriteBatch batch, Map<String, dynamic> txData, {required bool isAddition}) async {
    final uid = _uid;
    if (uid == null) return;
    final accountId = txData['account_id']?.toString() ?? txData['accountId']?.toString();
    if (accountId == null) return;

    final accountRef = _db.collection('users').doc(uid).collection('accounts').doc(accountId);
    final amount = (txData['amount'] as num).toDouble();
    final type = txData['type'];

    if (type == 'Transfer') {
      final toAccountId = txData['to_account_id']?.toString() ?? txData['toAccountId']?.toString();
      if (toAccountId == null) return;
      final toAccountRef = _db.collection('users').doc(uid).collection('accounts').doc(toAccountId);

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
          batch.update(toAccountRef, {'balance': FieldValue.increment(-amount)});
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

  Future<List<Map<String, dynamic>>> getAccountTransactions(String accountId) async {
    final uid = _uid;
    if (uid == null) return [];
    
    final snap1 = await _db.collection('users').doc(uid).collection('transactions')
        .where('account_id', isEqualTo: accountId)
        .get();
        
    final snap2 = await _db.collection('users').doc(uid).collection('transactions')
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
    final snap = await _db.collection('users').doc(uid).collection('accounts').get();
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
    final snap = await _db.collection('users').doc(uid).collection('categories').get();
    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> getTransactionsList() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db.collection('users').doc(uid).collection('transactions').orderBy('date', descending: true).get();
    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Stream<DocumentSnapshot> getScratchpadSnapshot() {
    final uid = _uid;
    if (uid == null) throw Exception("User not logged in");
    return _db.collection('users').doc(uid).collection('notes').doc('scratchpad').snapshots();
  }

  Future<void> submitFeedback(Map<String, dynamic> feedbackData) async {
    await _db.collection('feedback').add(feedbackData);
  }
}
