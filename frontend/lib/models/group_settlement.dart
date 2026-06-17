import 'package:cloud_firestore/cloud_firestore.dart';

class GroupSettlement {
  final String id;
  final String groupId;
  final String fromMemberId; // debtor
  final String toMemberId; // creditor
  final double amount;
  final DateTime date;
  final String? notes;
  final String createdBy;

  GroupSettlement({
    required this.id,
    required this.groupId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.date,
    this.notes,
    required this.createdBy,
  });

  factory GroupSettlement.fromMap(String id, Map<String, dynamic> map) {
    return GroupSettlement(
      id: id,
      groupId: map['groupId'] ?? '',
      fromMemberId: map['fromMemberId'] ?? '',
      toMemberId: map['toMemberId'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'],
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'fromMemberId': fromMemberId,
      'toMemberId': toMemberId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'createdBy': createdBy,
    };
  }
}
