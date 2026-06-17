import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/group_expense.dart';
import '../models/group_settlement.dart';

class SimplifiedDebt {
  final String from;
  final String to;
  final double amount;

  SimplifiedDebt({required this.from, required this.to, required this.amount});
}

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  String? get _email => _auth.currentUser?.email;
  String? get _displayName => _auth.currentUser?.displayName;

  // --- Group Management ---

  Stream<List<Map<String, dynamic>>> getJoinedGroups() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    // Direct read from users/{uid}/groups subcollection for minimal reads & high speed
    return _db
        .collection('users')
        .doc(uid)
        .collection('groups')
        .orderBy('lastActive', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<Group?> getGroupDetails(String groupId) async {
    try {
      final doc = await _db.collection('groups').doc(groupId).get();
      if (!doc.exists) return null;
      return Group.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint("Error getting group details: $e");
      return null;
    }
  }

  Stream<List<GroupMember>> getGroupMembers(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => GroupMember.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<GroupExpense>> getGroupExpenses(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => GroupExpense.fromMap(doc.id, doc.data())).toList());
  }

  Stream<List<GroupSettlement>> getGroupSettlements(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => GroupSettlement.fromMap(doc.id, doc.data())).toList());
  }

  Future<String?> createGroup(String name, String description, String? imageUrl) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final batch = _db.batch();
      
      // 1. Create group doc
      final groupRef = _db.collection('groups').doc();
      final groupId = groupRef.id;

      final groupData = {
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'totalExpenses': 0.0,
      };
      batch.set(groupRef, groupData);

      // 2. Add creator as first member
      final memberRef = _db.collection('groups').doc(groupId).collection('members').doc(uid);
      final memberData = {
        'name': _displayName?.isNotEmpty == true ? _displayName! : (_email ?? 'Creator'),
        'email': _email,
        'isAppUser': true,
        'balance': 0.0,
        'joinedAt': FieldValue.serverTimestamp(),
      };
      batch.set(memberRef, memberData);

      // 3. Link group in user's denormalized groups subcollection
      final userGroupRef = _db.collection('users').doc(uid).collection('groups').doc(groupId);
      final userGroupData = {
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'userBalance': 0.0,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };
      batch.set(userGroupRef, userGroupData);

      await batch.commit();
      return groupId;
    } catch (e) {
      debugPrint("Error creating group: $e");
      return null;
    }
  }

  Future<void> updateGroup(String groupId, String name, String description, String? imageUrl) async {
    try {
      final batch = _db.batch();
      
      // Update group doc
      final groupRef = _db.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'name': name,
        'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });

      // We should update the denormalized group name/desc in all members' subcollections.
      // For now, let's fetch members first and run updates, or just update the active user's subcollection.
      // In a serverless architecture, we update the active user's document immediately.
      final uid = _uid;
      if (uid != null) {
        final userGroupRef = _db.collection('users').doc(uid).collection('groups').doc(groupId);
        batch.update(userGroupRef, {
          'name': name,
          'description': description,
          if (imageUrl != null) 'imageUrl': imageUrl,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error updating group: $e");
    }
  }

  Future<void> deleteGroup(String groupId) async {
    // Delete in a production system can involve deleting subcollections,
    // which requires recursive deletion or cloud functions.
    // Client-side, we delete the group doc and user's reference.
    final uid = _uid;
    if (uid == null) return;
    try {
      final batch = _db.batch();
      batch.delete(_db.collection('groups').doc(groupId));
      batch.delete(_db.collection('users').doc(uid).collection('groups').doc(groupId));
      await batch.commit();
    } catch (e) {
      debugPrint("Error deleting group: $e");
    }
  }

  // --- Member Management ---

  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    try {
      final query = await _db.collection('users').where('email', isEqualTo: email.trim().toLowerCase()).get();
      return query.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint("Error searching users: $e");
      return [];
    }
  }

  Future<bool> addMember(String groupId, {required String name, String? email, String? uid}) async {
    try {
      final batch = _db.batch();
      
      // 1. Generate member ID (use uid if it is an app user, else generate new document ID)
      final memberId = uid ?? _db.collection('groups').doc(groupId).collection('members').doc().id;
      final isAppUser = uid != null;

      final memberRef = _db.collection('groups').doc(groupId).collection('members').doc(memberId);
      final memberData = {
        'name': name,
        'email': email?.trim().toLowerCase(),
        'isAppUser': isAppUser,
        'balance': 0.0,
        'joinedAt': FieldValue.serverTimestamp(),
      };
      batch.set(memberRef, memberData);

      // 2. If it is an app user, link the group in their users/{uid}/groups list
      if (isAppUser) {
        final groupSnap = await _db.collection('groups').doc(groupId).get();
        if (groupSnap.exists) {
          final groupData = groupSnap.data()!;
          final userGroupRef = _db.collection('users').doc(uid).collection('groups').doc(groupId);
          batch.set(userGroupRef, {
            'name': groupData['name'],
            'description': groupData['description'],
            'imageUrl': groupData['imageUrl'],
            'userBalance': 0.0,
            'joinedAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error adding member: $e");
      return false;
    }
  }

  Future<void> removeMember(String groupId, String memberId) async {
    try {
      final batch = _db.batch();
      
      // Remove member doc
      batch.delete(_db.collection('groups').doc(groupId).collection('members').doc(memberId));
      
      // If they are an app user, delete their user's group reference too
      // (This will delete the group from their dashboard)
      batch.delete(_db.collection('users').doc(memberId).collection('groups').doc(groupId));
      
      await batch.commit();
    } catch (e) {
      debugPrint("Error removing member: $e");
    }
  }

  // --- Split Calculations ---

  Map<String, double> calculateSplit({
    required double amount,
    required SplitType type,
    required List<String> participants,
    required Map<String, double> inputs, // exact owes / percentages / shares
  }) {
    if (participants.isEmpty) return {};
    final shares = <String, double>{};
    double sum = 0.0;

    switch (type) {
      case SplitType.equal:
        final share = (amount * 100).floorToDouble() / participants.length / 100;
        for (int i = 0; i < participants.length; i++) {
          if (i == participants.length - 1) {
            shares[participants[i]] = double.parse((amount - sum).toStringAsFixed(2));
          } else {
            shares[participants[i]] = double.parse(share.toStringAsFixed(2));
            sum += share;
          }
        }
        break;

      case SplitType.exact:
        // Use manual input directly, ensuring penny roundings check
        for (var p in participants) {
          shares[p] = double.parse((inputs[p] ?? 0.0).toStringAsFixed(2));
        }
        break;

      case SplitType.percentage:
        for (int i = 0; i < participants.length; i++) {
          final pct = inputs[participants[i]] ?? 0.0;
          final share = double.parse((amount * pct / 100).toStringAsFixed(2));
          if (i == participants.length - 1) {
            shares[participants[i]] = double.parse((amount - sum).toStringAsFixed(2));
          } else {
            shares[participants[i]] = share;
            sum += share;
          }
        }
        break;

      case SplitType.shares:
        final totalShares = participants.fold<double>(0.0, (val, p) => val + (inputs[p] ?? 0.0));
        if (totalShares <= 0) {
          // Fallback to equal split if shares are zero
          return calculateSplit(amount: amount, type: SplitType.equal, participants: participants, inputs: {});
        }
        for (int i = 0; i < participants.length; i++) {
          final sh = inputs[participants[i]] ?? 0.0;
          final share = double.parse((amount * sh / totalShares).toStringAsFixed(2));
          if (i == participants.length - 1) {
            shares[participants[i]] = double.parse((amount - sum).toStringAsFixed(2));
          } else {
            shares[participants[i]] = share;
            sum += share;
          }
        }
        break;
    }

    return shares;
  }

  // --- Group Expense operations ---

  Future<bool> addExpense(
    String groupId, {
    required String title,
    required String description,
    required double amount,
    required String currency,
    required DateTime date,
    required String category,
    required String paidBy,
    required Map<String, double> splitAmong,
    required SplitType splitType,
    String? receiptUrl,
    String? notes,
    // Personal Finance Integration
    String? personalAccountId,
    String? personalAccountName,
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final batch = _db.batch();
      
      // 1. Create Group Expense Document
      final expenseRef = _db.collection('groups').doc(groupId).collection('expenses').doc();
      final expenseId = expenseRef.id;

      // 2. Personal Finance Auto-Integration Check
      String? personalTxId;
      if (paidBy == uid && personalAccountId != null) {
        // Current user paid the full bill. Auto-create a personal transaction!
        final personalTxRef = _db.collection('users').doc(uid).collection('transactions').doc();
        personalTxId = personalTxRef.id;

        final txData = {
          'account_id': personalAccountId,
          'account_name': personalAccountName ?? 'Account',
          'category_id': 'group_expense_temp',
          'category_name': category,
          'amount': amount,
          'type': 'Expense',
          'date': Timestamp.fromDate(date),
          'notes': notes ?? '',
          'description': "[Group: $title] $description",
          'fees': 0.0,
          'linkedGroupExpenseId': expenseId,
          'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(personalTxRef, txData);

        // Update personal account balance atomically
        final accountRef = _db.collection('users').doc(uid).collection('accounts').doc(personalAccountId);
        batch.update(accountRef, {'balance': FieldValue.increment(-amount)});
      }

      // 3. Store the Group Expense
      final expenseData = {
        'groupId': groupId,
        'title': title,
        'description': description,
        'amount': amount,
        'currency': currency,
        'date': Timestamp.fromDate(date),
        'category': category,
        'paidBy': paidBy,
        'splitAmong': splitAmong,
        'splitType': splitType.toString().split('.').last,
        'receiptUrl': receiptUrl,
        'createdBy': uid,
        'notes': notes,
        'linkedTransactionId': personalTxId,
      };
      batch.set(expenseRef, expenseData);

      // 4. Update the total expenses of the group
      final groupRef = _db.collection('groups').doc(groupId);
      batch.update(groupRef, {'totalExpenses': FieldValue.increment(amount)});

      // 5. Update balances of all group members involved
      final membersSnap = await _db.collection('groups').doc(groupId).collection('members').get();
      final appUserIds = membersSnap.docs
          .where((doc) => doc.data()['isAppUser'] == true)
          .map((doc) => doc.id)
          .toSet();

      final allParticipants = {...splitAmong.keys, paidBy}.toList();
      for (var memberId in allParticipants) {
        final share = splitAmong[memberId] ?? 0.0;
        final paid = memberId == paidBy ? amount : 0.0;
        final netChange = double.parse((paid - share).toStringAsFixed(2));

        if (netChange == 0.0) continue;

        // Update member balance in groups/{groupId}/members/{memberId}
        final memberRef = _db.collection('groups').doc(groupId).collection('members').doc(memberId);
        batch.update(memberRef, {'balance': FieldValue.increment(netChange)});

        // If the member is a registered App User, propagate to users/{memberId}/groups/{groupId}
        if (appUserIds.contains(memberId)) {
          final userGroupRef = _db.collection('users').doc(memberId).collection('groups').doc(groupId);
          batch.update(userGroupRef, {
            'userBalance': FieldValue.increment(netChange),
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error adding group expense: $e");
      return false;
    }
  }

  Future<void> deleteExpense(String groupId, GroupExpense expense) async {
    try {
      final batch = _db.batch();

      // 1. Delete group expense document
      batch.delete(_db.collection('groups').doc(groupId).collection('expenses').doc(expense.id));

      // 2. Decrement total expenses of group
      batch.update(_db.collection('groups').doc(groupId), {
        'totalExpenses': FieldValue.increment(-expense.amount),
      });

      // 3. Revert balances of all involved members
      final membersSnap = await _db.collection('groups').doc(groupId).collection('members').get();
      final appUserIds = membersSnap.docs
          .where((doc) => doc.data()['isAppUser'] == true)
          .map((doc) => doc.id)
          .toSet();

      final allParticipants = {...expense.splitAmong.keys, expense.paidBy}.toList();
      for (var memberId in allParticipants) {
        final share = expense.splitAmong[memberId] ?? 0.0;
        final paid = memberId == expense.paidBy ? expense.amount : 0.0;
        final netChange = double.parse((paid - share).toStringAsFixed(2));

        if (netChange == 0.0) continue;

        // Revert member balance (subtract netChange)
        batch.update(
          _db.collection('groups').doc(groupId).collection('members').doc(memberId),
          {'balance': FieldValue.increment(-netChange)},
        );

        // Revert users/{memberId}/groups/{groupId}
        if (appUserIds.contains(memberId)) {
          batch.update(
            _db.collection('users').doc(memberId).collection('groups').doc(groupId),
            {'userBalance': FieldValue.increment(-netChange)},
          );
        }
      }

      // 4. Personal Finance Sync: delete associated transaction if it exists
      final linkedTxId = expense.linkedTransactionId;
      final creatorUid = expense.paidBy; // Whichever user paid for it holds the personal transaction
      if (linkedTxId != null) {
        final txDoc = await _db.collection('users').doc(creatorUid).collection('transactions').doc(linkedTxId).get();
        if (txDoc.exists) {
          final txData = txDoc.data()!;
          final accountId = txData['account_id'];
          final amount = (txData['amount'] as num).toDouble();

          // Delete transaction document
          batch.delete(_db.collection('users').doc(creatorUid).collection('transactions').doc(linkedTxId));

          // Revert personal account balance (increment by expense amount)
          if (accountId != null) {
            batch.update(
              _db.collection('users').doc(creatorUid).collection('accounts').doc(accountId),
              {'balance': FieldValue.increment(amount)},
            );
          }
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error deleting expense: $e");
    }
  }

  // --- Group Settlement Operations ---

  Future<bool> addSettlement(
    String groupId, {
    required String fromMemberId, // debtor
    required String toMemberId, // creditor
    required double amount,
    required DateTime date,
    String? notes,
    // Personal Finance Integration
    String? personalAccountId,
    String? personalAccountName,
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      final batch = _db.batch();

      // 1. Create settlement doc
      final settlementRef = _db.collection('groups').doc(groupId).collection('settlements').doc();
      final settlementId = settlementRef.id;

      final settlementData = {
        'groupId': groupId,
        'fromMemberId': fromMemberId,
        'toMemberId': toMemberId,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'notes': notes,
        'createdBy': uid,
      };
      batch.set(settlementRef, settlementData);

      // 2. Personal Finance Auto-Integration
      if (personalAccountId != null) {
        final personalTxRef = _db.collection('users').doc(uid).collection('transactions').doc();

        // Is current user debtor (Expense) or creditor (Income)?
        final isDebtor = uid == fromMemberId;
        final txType = isDebtor ? 'Expense' : 'Income';
        final txAmount = amount;
        final catName = 'Transfer';
        final txDesc = isDebtor ? "[Group Settlement] Paid money" : "[Group Settlement] Received money";

        final txData = {
          'account_id': personalAccountId,
          'account_name': personalAccountName ?? 'Account',
          'category_id': 'group_settlement_temp',
          'category_name': catName,
          'amount': txAmount,
          'type': txType,
          'date': Timestamp.fromDate(date),
          'notes': notes ?? '',
          'description': txDesc,
          'fees': 0.0,
          'linkedGroupExpenseId': settlementId,
          'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(personalTxRef, txData);

        // Update personal account balance atomically
        // If debtor: decrement account balance. If creditor: increment account balance.
        final change = isDebtor ? -txAmount : txAmount;
        final accountRef = _db.collection('users').doc(uid).collection('accounts').doc(personalAccountId);
        batch.update(accountRef, {'balance': FieldValue.increment(change)});
      }

      // 3. Update member balances
      // Debtor's debt reduces (balance becomes more positive)
      final debtorRef = _db.collection('groups').doc(groupId).collection('members').doc(fromMemberId);
      batch.update(debtorRef, {'balance': FieldValue.increment(amount)});

      // Creditor's credit reduces (balance becomes more negative)
      final creditorRef = _db.collection('groups').doc(groupId).collection('members').doc(toMemberId);
      batch.update(creditorRef, {'balance': FieldValue.increment(-amount)});

      // Propagate user balances to users/{uid}/groups/{groupId}
      final debtorSnap = await _db.collection('groups').doc(groupId).collection('members').doc(fromMemberId).get();
      final creditorSnap = await _db.collection('groups').doc(groupId).collection('members').doc(toMemberId).get();
      final isDebtorAppUser = debtorSnap.exists && debtorSnap.data()?['isAppUser'] == true;
      final isCreditorAppUser = creditorSnap.exists && creditorSnap.data()?['isAppUser'] == true;

      if (isDebtorAppUser) {
        final userDebtorGroupRef = _db.collection('users').doc(fromMemberId).collection('groups').doc(groupId);
        batch.update(userDebtorGroupRef, {
          'userBalance': FieldValue.increment(amount),
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      if (isCreditorAppUser) {
        final userCreditorGroupRef = _db.collection('users').doc(toMemberId).collection('groups').doc(groupId);
        batch.update(userCreditorGroupRef, {
          'userBalance': FieldValue.increment(-amount),
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error adding settlement: $e");
      return false;
    }
  }

  Future<void> deleteSettlement(String groupId, GroupSettlement settlement) async {
    try {
      final batch = _db.batch();

      // 1. Delete settlement doc
      batch.delete(_db.collection('groups').doc(groupId).collection('settlements').doc(settlement.id));

      // 2. Revert member balances (Debtor's balance decremented, Creditor's incremented)
      batch.update(
        _db.collection('groups').doc(groupId).collection('members').doc(settlement.fromMemberId),
        {'balance': FieldValue.increment(-settlement.amount)},
      );
      batch.update(
        _db.collection('groups').doc(groupId).collection('members').doc(settlement.toMemberId),
        {'balance': FieldValue.increment(settlement.amount)},
      );

      // Revert user group links
      final debtorSnap = await _db.collection('groups').doc(groupId).collection('members').doc(settlement.fromMemberId).get();
      final creditorSnap = await _db.collection('groups').doc(groupId).collection('members').doc(settlement.toMemberId).get();
      final isDebtorAppUser = debtorSnap.exists && debtorSnap.data()?['isAppUser'] == true;
      final isCreditorAppUser = creditorSnap.exists && creditorSnap.data()?['isAppUser'] == true;

      if (isDebtorAppUser) {
        batch.update(
          _db.collection('users').doc(settlement.fromMemberId).collection('groups').doc(groupId),
          {'userBalance': FieldValue.increment(-settlement.amount)},
        );
      }
      if (isCreditorAppUser) {
        batch.update(
          _db.collection('users').doc(settlement.toMemberId).collection('groups').doc(groupId),
          {'userBalance': FieldValue.increment(settlement.amount)},
        );
      }

      // 3. Personal Sync: delete linked transactions
      // Check if creator is one of debtor or creditor and if they have transactions
      // (The model doesn't store linkedTransactionId for settlements, but we can search for it in transactions where linkedGroupExpenseId == settlement.id)
      final fromUid = settlement.fromMemberId;
      final toUid = settlement.toMemberId;

      await _revertSettlementTransaction(batch, fromUid, settlement.id, isDebtor: true);
      await _revertSettlementTransaction(batch, toUid, settlement.id, isDebtor: false);

      await batch.commit();
    } catch (e) {
      debugPrint("Error deleting settlement: $e");
    }
  }

  Future<void> _revertSettlementTransaction(WriteBatch batch, String uid, String settlementId, {required bool isDebtor}) async {
    try {
      final query = await _db
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .where('linkedGroupExpenseId', isEqualTo: settlementId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final txData = doc.data();
        final accountId = txData['account_id'];
        final amount = (txData['amount'] as num).toDouble();

        batch.delete(doc.reference);

        if (accountId != null) {
          // If debtor: they paid, so we increment balance back
          // If creditor: they received, so we decrement balance back
          final change = isDebtor ? amount : -amount;
          batch.update(
            _db.collection('users').doc(uid).collection('accounts').doc(accountId),
            {'balance': FieldValue.increment(change)},
          );
        }
      }
    } catch (e) {
      debugPrint("Error reverting settlement transaction: $e");
    }
  }

  // --- Debt Simplification Core Engine ---

  List<SimplifiedDebt> simplifyDebts(List<GroupMember> members) {
    List<MapEntry<String, double>> debtors = [];
    List<MapEntry<String, double>> creditors = [];

    for (var m in members) {
      double bal = double.parse(m.balance.toStringAsFixed(2));
      if (bal < -0.01) {
        debtors.add(MapEntry(m.id, bal));
      } else if (bal > 0.01) {
        creditors.add(MapEntry(m.id, bal));
      }
    }

    debtors.sort((a, b) => a.value.compareTo(b.value)); // e.g. -100, -50
    creditors.sort((a, b) => b.value.compareTo(a.value)); // e.g. 120, 80

    List<SimplifiedDebt> simplified = [];
    int dIdx = 0;
    int cIdx = 0;

    List<double> dBal = debtors.map((e) => e.value).toList();
    List<double> cBal = creditors.map((e) => e.value).toList();

    while (dIdx < debtors.length && cIdx < creditors.length) {
      double debt = -dBal[dIdx];
      double credit = cBal[cIdx];

      double settleAmount = debt < credit ? debt : credit;

      simplified.add(SimplifiedDebt(
        from: debtors[dIdx].key,
        to: creditors[cIdx].key,
        amount: double.parse(settleAmount.toStringAsFixed(2)),
      ));

      dBal[dIdx] += settleAmount;
      cBal[cIdx] -= settleAmount;

      if (dBal[dIdx].abs() < 0.01) {
        dIdx++;
      }
      if (cBal[cIdx].abs() < 0.01) {
        cIdx++;
      }
    }

    return simplified;
  }
}
