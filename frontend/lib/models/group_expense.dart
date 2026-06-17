import 'package:cloud_firestore/cloud_firestore.dart';

enum SplitType { equal, exact, percentage, shares }

class GroupExpense {
  final String id;
  final String groupId;
  final String title;
  final String description;
  final double amount;
  final String currency;
  final DateTime date;
  final String category;
  final String paidBy; // memberId of the payer
  final Map<String, double> splitAmong; // Map of memberId -> owed share / percentage / amount / shares
  final SplitType splitType;
  final String? receiptUrl;
  final String createdBy;
  final String? notes;
  final String? linkedTransactionId; // linked personal transaction ID (if any)

  GroupExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.description,
    required this.amount,
    required this.currency,
    required this.date,
    required this.category,
    required this.paidBy,
    required this.splitAmong,
    required this.splitType,
    this.receiptUrl,
    required this.createdBy,
    this.notes,
    this.linkedTransactionId,
  });

  factory GroupExpense.fromMap(String id, Map<String, dynamic> map) {
    final rawSplit = map['splitAmong'] as Map<dynamic, dynamic>? ?? {};
    final splitMap = rawSplit.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()));
    
    final splitTypeStr = map['splitType'] ?? 'equal';
    final type = SplitType.values.firstWhere(
      (e) => e.toString().split('.').last == splitTypeStr,
      orElse: () => SplitType.equal,
    );

    return GroupExpense(
      id: id,
      groupId: map['groupId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'USD',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: map['category'] ?? 'Food',
      paidBy: map['paidBy'] ?? '',
      splitAmong: splitMap,
      splitType: type,
      receiptUrl: map['receiptUrl'],
      createdBy: map['createdBy'] ?? '',
      notes: map['notes'],
      linkedTransactionId: map['linkedTransactionId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      'createdBy': createdBy,
      'notes': notes,
      'linkedTransactionId': linkedTransactionId,
    };
  }
}
