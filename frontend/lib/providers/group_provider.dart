import 'package:flutter/material.dart';
import '../services/group_service.dart';
import '../models/group_member.dart';
import '../models/group_expense.dart';
import '../models/group_settlement.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _groupService = GroupService();
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // --- Real-time Streams ---

  Stream<List<Map<String, dynamic>>> get joinedGroupsStream => _groupService.getJoinedGroups();

  Stream<List<GroupMember>> getGroupMembersStream(String groupId) {
    return _groupService.getGroupMembers(groupId);
  }

  Stream<List<GroupExpense>> getGroupExpensesStream(String groupId) {
    return _groupService.getGroupExpenses(groupId);
  }

  Stream<List<GroupSettlement>> getGroupSettlementsStream(String groupId) {
    return _groupService.getGroupSettlements(groupId);
  }

  // --- Group Actions ---

  Future<String?> createGroup(String name, String description, String? imageUrl) async {
    _setLoading(true);
    try {
      final id = await _groupService.createGroup(name, description, imageUrl);
      return id;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateGroup(String groupId, String name, String description, String? imageUrl) async {
    _setLoading(true);
    try {
      await _groupService.updateGroup(groupId, name, description, imageUrl);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteGroup(String groupId) async {
    _setLoading(true);
    try {
      await _groupService.deleteGroup(groupId);
    } finally {
      _setLoading(false);
    }
  }

  // --- Member Actions ---

  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    return await _groupService.searchUsersByEmail(email);
  }

  Future<bool> addMember(String groupId, {required String name, String? email, String? uid}) async {
    _setLoading(true);
    try {
      return await _groupService.addMember(groupId, name: name, email: email, uid: uid);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeMember(String groupId, String memberId) async {
    _setLoading(true);
    try {
      await _groupService.removeMember(groupId, memberId);
    } finally {
      _setLoading(false);
    }
  }

  // --- Split Calculators ---

  Map<String, double> calculateSplit({
    required double amount,
    required SplitType type,
    required List<String> participants,
    required Map<String, double> inputs,
  }) {
    return _groupService.calculateSplit(
      amount: amount,
      type: type,
      participants: participants,
      inputs: inputs,
    );
  }

  // --- Expense Actions ---

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
    String? personalAccountId,
    String? personalAccountName,
  }) async {
    _setLoading(true);
    try {
      return await _groupService.addExpense(
        groupId,
        title: title,
        description: description,
        amount: amount,
        currency: currency,
        date: date,
        category: category,
        paidBy: paidBy,
        splitAmong: splitAmong,
        splitType: splitType,
        receiptUrl: receiptUrl,
        notes: notes,
        personalAccountId: personalAccountId,
        personalAccountName: personalAccountName,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteExpense(String groupId, GroupExpense expense) async {
    _setLoading(true);
    try {
      await _groupService.deleteExpense(groupId, expense);
    } finally {
      _setLoading(false);
    }
  }

  // --- Settlement Actions ---

  Future<bool> addSettlement(
    String groupId, {
    required String fromMemberId,
    required String toMemberId,
    required double amount,
    required DateTime date,
    String? notes,
    String? personalAccountId,
    String? personalAccountName,
  }) async {
    _setLoading(true);
    try {
      return await _groupService.addSettlement(
        groupId,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        amount: amount,
        date: date,
        notes: notes,
        personalAccountId: personalAccountId,
        personalAccountName: personalAccountName,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteSettlement(String groupId, GroupSettlement settlement) async {
    _setLoading(true);
    try {
      await _groupService.deleteSettlement(groupId, settlement);
    } finally {
      _setLoading(false);
    }
  }

  // --- Debt Simplification ---

  List<SimplifiedDebt> getSimplifiedDebts(List<GroupMember> members) {
    return _groupService.simplifyDebts(members);
  }
}
