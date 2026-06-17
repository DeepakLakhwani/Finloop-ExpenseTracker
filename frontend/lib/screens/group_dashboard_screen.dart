import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../providers/group_provider.dart';
import '../providers/settings_provider.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/group_expense.dart';
import '../models/group_settlement.dart';
import '../services/group_service.dart';
import '../theme/app_colors.dart';
import 'add_group_expense_screen.dart';
import 'group_settlement_screen.dart';
import 'group_members_screen.dart';
import '../main.dart';

// ---------------------------------------------------------------------------
// Static helpers — instantiated once, not on every build
// ---------------------------------------------------------------------------
final _dayFmt = DateFormat('dd');
final _monthFmt = DateFormat('MMM');
final _fullDateFmt = DateFormat('dd MMM yyyy');

GroupMember _unknownMember(String fallbackName) => GroupMember(
  id: '',
  name: fallbackName,
  isAppUser: false,
  balance: 0.0,
  joinedAt: DateTime.now(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class GroupDashboardScreen extends StatefulWidget {
  final String groupId;
  const GroupDashboardScreen({super.key, required this.groupId});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Use a Set so multiple cards can be expanded simultaneously if desired.
  // If you prefer accordion behaviour, keep a single nullable String instead.
  final Set<String> _expandedExpenseIds = {};

  // Tracks in-progress async operations to disable buttons and show loaders.
  bool _isDeletingGroup = false;
  final Set<String> _deletingExpenseIds = {};
  final Set<String> _deletingSettlementIds = {};

  // Cache the group future so it isn't recreated on every build.
  late Future<Group?> _groupFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _groupFuture = GroupService().getGroupDetails(widget.groupId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Delete group
  // ---------------------------------------------------------------------------
  Future<void> _handleDeleteGroup(Group group) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Group',
      content:
          'Are you sure you want to delete "${group.name}"? This action is permanent '
          'and will delete all expenses, settlements, and member records.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirm || !mounted) return;

    // Capture what we need before popping context.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final groupProvider = context.read<GroupProvider>();
    final groupName = group.name;

    // Navigate away immediately so the user isn't stuck on a dead screen.
    navigator.pop();

    try {
      await groupProvider.deleteGroup(widget.groupId);
      messenger.showSnackBar(
        SnackBar(content: Text('Group "$groupName" deleted successfully')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete group: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Delete expense
  // ---------------------------------------------------------------------------
  Future<void> _handleDeleteExpense(GroupExpense exp) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Expense',
      content:
          'Are you sure you want to delete this shared expense? All member balances '
          'will be adjusted back, and any linked personal transactions will be deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirm || !mounted) return;

    setState(() => _deletingExpenseIds.add(exp.id));
    try {
      await context.read<GroupProvider>().deleteExpense(widget.groupId, exp);
      if (mounted) {
        _expandedExpenseIds.remove(exp.id);
        showTopNotification('Expense deleted successfully!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete expense: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingExpenseIds.remove(exp.id));
    }
  }

  // ---------------------------------------------------------------------------
  // Delete settlement
  // ---------------------------------------------------------------------------
  Future<void> _handleDeleteSettlement(GroupSettlement settlement) async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Settlement',
      content:
          'Are you sure you want to delete this settlement record? Members outstanding '
          'balances will be restored, and any automatically linked bank transactions '
          'will be deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirm || !mounted) return;

    setState(() => _deletingSettlementIds.add(settlement.id));
    try {
      await context.read<GroupProvider>().deleteSettlement(
        widget.groupId,
        settlement,
      );
      if (mounted) showTopNotification('Settlement deleted successfully!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete settlement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingSettlementIds.remove(settlement.id));
    }
  }

  // ---------------------------------------------------------------------------
  // Shared confirm dialog helper
  // ---------------------------------------------------------------------------
  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: isDestructive ? AppColors.error : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Show a full-screen loader while we are deleting the group.
    if (_isDeletingGroup) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<Group?>(
      future: _groupFuture,
      builder: (context, groupSnap) {
        if (groupSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (groupSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error loading group: ${groupSnap.error}'),
            ),
          );
        }

        final group = groupSnap.data;
        if (group == null) {
          return const Scaffold(body: Center(child: Text('Group not found.')));
        }

        return StreamBuilder<List<GroupMember>>(
          stream: context.read<GroupProvider>().getGroupMembersStream(
            widget.groupId,
          ),
          builder: (context, membersSnap) {
            if (membersSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Error loading members: ${membersSnap.error}'),
                ),
              );
            }

            final members = membersSnap.data ?? [];
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final currency = context.watch<SettingsProvider>().currency;

            final currentUserMember = uid != null
                ? members.firstWhere(
                    (m) => m.id == uid,
                    orElse: () => _unknownMember('You'),
                  )
                : _unknownMember('You');

            final myBalance = currentUserMember.balance;
            final (balanceColor, balanceStatus) = _resolveBalance(
              myBalance,
              currency,
            );

            return Scaffold(
              appBar: _buildAppBar(context, group, myBalance),
              body: Column(
                children: [
                  _buildHeaderStats(
                    context,
                    group,
                    currency,
                    balanceStatus,
                    balanceColor,
                    myBalance,
                  ),
                  _buildActionsRow(context, members),
                  _buildTabBar(context),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildExpensesTab(context, members, currency, uid),
                        _buildSettlementsTab(context, members, currency, uid),
                        _buildBalancesTab(context, members, currency, uid),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Balance helpers
  // ---------------------------------------------------------------------------
  (Color, String) _resolveBalance(double balance, String currency) {
    if (balance > 0.01) {
      return (
        AppColors.success,
        'You are owed $currency${balance.toStringAsFixed(2)} overall',
      );
    } else if (balance < -0.01) {
      return (
        AppColors.error,
        'You owe $currency${balance.abs().toStringAsFixed(2)} overall',
      );
    }
    return (Colors.grey, 'You are all settled up');
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    Group group,
    double myBalance,
  ) {
    return AppBar(
      title: Text(
        group.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: 'Delete Group',
          onPressed: () => _handleDeleteGroup(group),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Group Settings',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupMembersScreen(groupId: widget.groupId),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header stats card
  // ---------------------------------------------------------------------------
  Widget _buildHeaderStats(
    BuildContext context,
    Group group,
    String currency,
    String status,
    Color balanceColor,
    double myBalance,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settled = myBalance.abs() < 0.01;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Spending',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$currency${group.totalExpenses.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: balanceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  settled ? 'Settled Up' : (myBalance > 0 ? 'Owed' : 'Owe'),
                  style: TextStyle(
                    color: balanceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                settled
                    ? Icons.check_circle_outline
                    : (myBalance > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded),
                color: balanceColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: balanceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions row
  // ---------------------------------------------------------------------------
  Widget _buildActionsRow(BuildContext context, List<GroupMember> members) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddGroupExpenseScreen(
                    groupId: widget.groupId,
                    members: members,
                  ),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Add Expense',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupSettlementScreen(
                    groupId: widget.groupId,
                    members: members,
                  ),
                ),
              ),
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: const Text(
                'Settle Up',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.primary,
                elevation: 0,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab bar
  // ---------------------------------------------------------------------------
  Widget _buildTabBar(BuildContext context) {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppColors.primary,
      labelColor: AppColors.primary,
      unselectedLabelColor: Theme.of(
        context,
      ).colorScheme.onSurface.withOpacity(0.6),
      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      tabs: const [
        Tab(text: 'Expenses'),
        Tab(text: 'Settlements'),
        Tab(text: 'Balances'),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Expenses tab
  // ---------------------------------------------------------------------------
  Widget _buildExpensesTab(
    BuildContext context,
    List<GroupMember> members,
    String currency,
    String? uid,
  ) {
    return StreamBuilder<List<GroupExpense>>(
      stream: context.read<GroupProvider>().getGroupExpensesStream(
        widget.groupId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final expenses = snapshot.data ?? [];
        if (expenses.isEmpty) {
          return _buildTabEmptyState(
            context,
            Icons.receipt_long_outlined,
            'No Shared Expenses Yet',
            'Tap "Add Expense" to share dinner, cabs, or stay bills!',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: expenses.length,
          itemBuilder: (context, index) => _buildExpenseTile(
            context,
            expenses[index],
            members,
            currency,
            uid,
          ),
        );
      },
    );
  }

  Widget _buildExpenseTile(
    BuildContext context,
    GroupExpense exp,
    List<GroupMember> members,
    String currency,
    String? uid,
  ) {
    final isExpanded = _expandedExpenseIds.contains(exp.id);
    final isDeleting = _deletingExpenseIds.contains(exp.id);

    final payerMember = members.firstWhere(
      (m) => m.id == exp.paidBy,
      orElse: () => _unknownMember('Someone'),
    );
    final payerName = payerMember.id == uid ? 'You' : payerMember.name;

    final myShare = exp.splitAmong[uid] ?? 0.0;
    final didIPay = exp.paidBy == uid;

    final String cardAmountText;
    final Color cardAmountColor;
    final String involvementText;

    if (didIPay) {
      final lent = exp.amount - myShare;
      cardAmountText = '+$currency${lent.toStringAsFixed(2)}';
      cardAmountColor = AppColors.success;
      involvementText = 'You lent $currency${lent.toStringAsFixed(2)}';
    } else if (myShare > 0) {
      cardAmountText = '-$currency${myShare.toStringAsFixed(2)}';
      cardAmountColor = AppColors.error;
      involvementText = 'You borrowed $currency${myShare.toStringAsFixed(2)}';
    } else {
      cardAmountText = '${currency}0.00';
      cardAmountColor = Colors.grey;
      involvementText = 'You were not involved';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayFmt.format(exp.date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    _monthFmt.format(exp.date),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              exp.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: Text(
              '$payerName paid $currency${exp.amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.5)),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  cardAmountText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cardAmountColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  involvementText,
                  style: TextStyle(
                    fontSize: 10,
                    color: onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedExpenseIds.remove(exp.id);
                } else {
                  _expandedExpenseIds.add(exp.id);
                }
              });
            },
          ),
          if (isExpanded) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (exp.description.isNotEmpty) ...[
                    _detailLabel(context, 'Description:'),
                    const SizedBox(height: 2),
                    Text(exp.description, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                  ],
                  _detailLabel(
                    context,
                    'Split Breakdown (${exp.splitType.name.toUpperCase()}):',
                  ),
                  const SizedBox(height: 6),
                  ...exp.splitAmong.entries.map((entry) {
                    final member = members.firstWhere(
                      (m) => m.id == entry.key,
                      orElse: () => _unknownMember('Someone'),
                    );
                    final mName = member.id == uid ? 'You' : member.name;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(mName, style: const TextStyle(fontSize: 13)),
                          Text(
                            '$currency${entry.value.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (exp.notes != null && exp.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailLabel(context, 'Notes:'),
                    const SizedBox(height: 2),
                    Text(
                      exp.notes!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category: ${exp.category}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: onSurface.withOpacity(0.4),
                        ),
                      ),
                      isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              tooltip: 'Delete Expense',
                              onPressed: () => _handleDeleteExpense(exp),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settlements tab
  // ---------------------------------------------------------------------------
  Widget _buildSettlementsTab(
    BuildContext context,
    List<GroupMember> members,
    String currency,
    String? uid,
  ) {
    return StreamBuilder<List<GroupSettlement>>(
      stream: context.read<GroupProvider>().getGroupSettlementsStream(
        widget.groupId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final settlements = snapshot.data ?? [];
        if (settlements.isEmpty) {
          return _buildTabEmptyState(
            context,
            Icons.handshake_outlined,
            'No Settlements Yet',
            'Tap "Settle Up" to record payments between members and clear balances!',
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: settlements.length,
          itemBuilder: (context, index) => _buildSettlementTile(
            context,
            settlements[index],
            members,
            currency,
            uid,
            isDark,
          ),
        );
      },
    );
  }

  Widget _buildSettlementTile(
    BuildContext context,
    GroupSettlement setVal,
    List<GroupMember> members,
    String currency,
    String? uid,
    bool isDark,
  ) {
    final debtor = members.firstWhere(
      (m) => m.id == setVal.fromMemberId,
      orElse: () => _unknownMember('Someone'),
    );
    final creditor = members.firstWhere(
      (m) => m.id == setVal.toMemberId,
      orElse: () => _unknownMember('Someone'),
    );

    final fromName = debtor.id == uid ? 'You' : debtor.name;
    final toName = creditor.id == uid ? 'You' : creditor.name;
    final dateStr = _fullDateFmt.format(setVal.date);
    final isDeleting = _deletingSettlementIds.contains(setVal.id);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Theme-aware RichText using DefaultTextStyle
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    children: [
                      TextSpan(
                        text: fromName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' settled with '),
                      TextSpan(
                        text: toName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: onSurface.withOpacity(0.4),
                  ),
                ),
                if (setVal.notes != null && setVal.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    setVal.notes!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency${setVal.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.success,
                ),
              ),
              isDeleting
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                        size: 18,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete Settlement',
                      onPressed: () => _handleDeleteSettlement(setVal),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Balances tab
  // ---------------------------------------------------------------------------
  Widget _buildBalancesTab(
    BuildContext context,
    List<GroupMember> members,
    String currency,
    String? uid,
  ) {
    final groupProvider = context.read<GroupProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final simplifiedDebts = groupProvider.getSimplifiedDebts(members);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All Group Balances',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ...members.map((m) {
            final isMe = m.id == uid;
            final mName = isMe ? 'You' : m.name;
            final bal = m.balance;

            final Color amountColor;
            final String ledgerText;

            if (bal > 0.01) {
              amountColor = AppColors.success;
              ledgerText = 'is owed $currency${bal.toStringAsFixed(2)}';
            } else if (bal < -0.01) {
              amountColor = AppColors.error;
              ledgerText = 'owes $currency${bal.abs().toStringAsFixed(2)}';
            } else {
              amountColor = Colors.grey;
              ledgerText = 'is settled up';
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          m.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mName,
                        style: TextStyle(
                          fontWeight: isMe
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    ledgerText,
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 28),
          const Text(
            'Simplified Debts (Clean Payments)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'FinLoop automatically simplifies debts in the background to calculate '
            'the minimal transactions required for everyone to be settled up!',
            style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.5)),
          ),
          const SizedBox(height: 12),
          if (simplifiedDebts.isEmpty)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Everyone is fully settled! No debts to clear.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            )
          else
            ...simplifiedDebts.map((debt) {
              final debtor = members.firstWhere(
                (m) => m.id == debt.from,
                orElse: () => _unknownMember('Someone'),
              );
              final creditor = members.firstWhere(
                (m) => m.id == debt.to,
                orElse: () => _unknownMember('Someone'),
              );

              final fromName = debtor.id == uid ? 'You' : debtor.name;
              final toName = creditor.id == uid ? 'You' : creditor.name;
              final showSettleButton = debtor.id == uid || creditor.id == uid;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_circle_right_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: onSurface, fontSize: 13),
                            children: [
                              TextSpan(
                                text: fromName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ' owes '),
                              TextSpan(
                                text: toName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text:
                                    '$currency${debt.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showSettleButton)
                        ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupSettlementScreen(
                                groupId: widget.groupId,
                                members: members,
                                prefilledFrom: debtor.id,
                                prefilledTo: creditor.id,
                                prefilledAmount: debt.amount,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Settle',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------
  Widget _detailLabel(BuildContext context, String label) {
    return Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }

  Widget _buildTabEmptyState(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
