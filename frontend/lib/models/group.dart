import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String createdBy;
  final DateTime createdAt;
  final double totalExpenses;

  Group({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    required this.totalExpenses,
  });

  factory Group.fromMap(String id, Map<String, dynamic> map) {
    return Group(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'],
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalExpenses': totalExpenses,
    };
  }
}
