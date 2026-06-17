import 'package:cloud_firestore/cloud_firestore.dart';

class GroupMember {
  final String id; // uid for app user, or custom generated ID for manual member
  final String name;
  final String? email;
  final bool isAppUser;
  final double balance; // positive = owed money, negative = owes money
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    required this.name,
    this.email,
    required this.isAppUser,
    required this.balance,
    required this.joinedAt,
  });

  factory GroupMember.fromMap(String id, Map<String, dynamic> map) {
    return GroupMember(
      id: id,
      name: map['name'] ?? '',
      email: map['email'],
      isAppUser: map['isAppUser'] ?? false,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'isAppUser': isAppUser,
      'balance': balance,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}
