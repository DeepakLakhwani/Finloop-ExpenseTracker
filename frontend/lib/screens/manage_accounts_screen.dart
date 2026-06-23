import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import 'account_entries_screen.dart';
import 'add_account_screen.dart';
import 'add_transaction_screen.dart';

// ---------------------------------------------------------------------------
// Shared formatter (instantiated once, not on every build)
// ---------------------------------------------------------------------------

final _fmt = NumberFormat('#,##0.00');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Safely parses a value that may be a [num], [String], or null to [double].
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Converts a Firestore [Timestamp] or an ISO-8601 [String] to [DateTime].
/// Falls back to [DateTime.now] so sorts never throw.
DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

/// Returns a human-readable countdown to the credit-card due day.
///
/// Uses proper [DateTime] arithmetic so December → January wrap-around is safe.
String _dueCountdownText(int dueDay) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Build the next occurrence of [dueDay].
  final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
  final clampedThisMonth = dueDay.clamp(1, daysInCurrentMonth);
  var dueDate = DateTime(now.year, now.month, clampedThisMonth);

  // If the due date has already passed this month, move to next month.
  if (!dueDate.isAfter(today)) {
    final nextMonth = DateTime(now.year, now.month + 1); // safe across Dec→Jan
    final daysInNextMonth = DateTime(
      nextMonth.year,
      nextMonth.month + 1,
      0,
    ).day;
    final clampedNextMonth = dueDay.clamp(1, daysInNextMonth);
    dueDate = DateTime(nextMonth.year, nextMonth.month, clampedNextMonth);
  }

  final diff = dueDate.difference(today).inDays;
  if (diff == 0) return 'due today!';
  return 'due in $diff day${diff == 1 ? '' : 's'}';
}

/// Formats a balance for display.
///
/// For credit cards the [balance] represents outstanding debt (positive = owed).
/// A zero or positive credit balance renders in green; debt renders in red with
/// a leading minus sign.
String _formatBalance({
  required double balance,
  required bool isCreditCard,
  required String currency,
}) {
  if (isCreditCard) {
    // balance > 0  → outstanding debt  → show as negative
    // balance <= 0 → no debt           → show 0.00
    if (balance > 0.01) return '-$currency ${_fmt.format(balance)}';
    return '$currency ${_fmt.format(0.0)}';
  }
  return '$currency ${_fmt.format(balance)}';
}

// ---------------------------------------------------------------------------
// Data model for account categories
// ---------------------------------------------------------------------------

class _AccountCategory {
  const _AccountCategory({
    required this.name,
    required this.dbType,
    required this.icon,
  });

  final String name;
  final String dbType;
  final IconData icon;
}

const List<_AccountCategory> _kCategories = [
  _AccountCategory(
    name: 'Bank',
    dbType: 'Bank Account',
    icon: Icons.account_balance_outlined,
  ),
  _AccountCategory(name: 'Cash', dbType: 'Cash', icon: Icons.payments_outlined),
  _AccountCategory(
    name: 'Cards',
    dbType: 'Credit Card',
    icon: Icons.credit_card_outlined,
  ),
  _AccountCategory(
    name: 'Wallet',
    dbType: 'Wallet',
    icon: Icons.account_balance_wallet_outlined,
  ),
];

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class ManageAccountsScreen extends StatefulWidget {
  const ManageAccountsScreen({super.key, this.isTab = false});

  final bool isTab;

  @override
  State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;
  Object? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  // Guard against concurrent navigations triggered by rapid taps.
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so that context.read is safe even if the widget
    // tree hasn't fully settled during hot-reload / deep linking scenarios.
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToAccounts());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Data
  // -------------------------------------------------------------------------

  void _listenToAccounts() {
    if (!mounted) return;
    _sub?.cancel();
    _sub = context.read<FirestoreService>().getAccounts().listen(
      (accounts) {
        if (!mounted) return;
        setState(() {
          _accounts = accounts;
          _isLoading = false;
          _error = null;
        });
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[ManageAccounts] Firestore error: $e\n$st');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = e;
        });
      },
    );
  }

  void _retryLoad() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _listenToAccounts();
  }

  // -------------------------------------------------------------------------
  // Navigation helpers
  // -------------------------------------------------------------------------

  Future<void> _openAddAccount() => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => const AddAccountScreen()),
  );

  Future<void> _openAccountDetail(Map<String, dynamic> acc) async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    // Show a non-dismissible loader while we fetch entries.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );

    try {
      final firestore = context.read<FirestoreService>();
      final accountId = acc['id']?.toString() ?? '';
      final entries = await firestore.getAccountTransactions(accountId);

      // Sort newest-first using the shared _toDateTime helper.
      entries.sort(
        (a, b) => _toDateTime(b['date']).compareTo(_toDateTime(a['date'])),
      );

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      if (entries.isEmpty) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AddAccountScreen(initialAccount: acc),
          ),
        );
      } else {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                AccountEntriesScreen(account: acc, entries: entries),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[ManageAccounts] Error loading account entries: $e\n$st');
      if (mounted) {
        // Dismiss loader only if it is still on the stack.
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load account details. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isNavigating = false;
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      appBar: widget.isTab
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              title: Text(
                'Manage Accounts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    icon: Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: _openAddAccount,
                    tooltip: 'Add account',
                  ),
                ),
              ],
            ),

      floatingActionButton: null,

      body: _buildBody(currency),
    );
  }

  Widget _buildBody(String currency) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(
        message: 'Failed to load accounts.\nPlease try again.',
        onRetry: _retryLoad,
      );
    }

    // Compute bottom padding so content is never hidden by the FAB.
    final bottomPad = widget.isTab
        ? MediaQuery.of(context).padding.bottom + 80
        : MediaQuery.of(context).padding.bottom + 16;

    return ListView(
      padding: EdgeInsets.fromLTRB(0, 10, 0, bottomPad),
      children: [
        _DuesBanner(accounts: _accounts, currency: currency),
        for (final cat in _kCategories)
          _AccountCategorySection(
            category: cat,
            accounts: _accounts
                .where((acc) => acc['type'] == cat.dbType)
                .toList(growable: false),
            currency: currency,
            onAccountTap: _openAccountDetail,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dues banner
// ---------------------------------------------------------------------------

class _DuesBanner extends StatelessWidget {
  const _DuesBanner({required this.accounts, required this.currency});

  final List<Map<String, dynamic>> accounts;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // Filter only cards that have an outstanding balance.
    final cardsWithDues = accounts
        .where((acc) {
          if (acc['type'] != 'Credit Card') return false;
          final limit = _parseDouble(acc['limit']);
          final available = _parseDouble(acc['balance']);
          return limit > 0 && (limit - available) > 0.01;
        })
        .toList(growable: false);

    if (cardsWithDues.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 16, right: 16),
          child: Text(
            'Upcoming Card Dues',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
            ),
          ),
        ),
        for (final acc in cardsWithDues) _DueCard(acc: acc, currency: currency),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.acc, required this.currency});

  final Map<String, dynamic> acc;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final limit = _parseDouble(acc['limit']);
    final available = _parseDouble(acc['balance']);
    final outstanding = limit - available;
    final dueDay = (acc['dueDate'] as int?) ?? 30;
    final countdownText = _dueCountdownText(dueDay);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withAlpha(20),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Card info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${acc['cardIssuer'] ?? 'Credit Card'} (${acc['name'] ?? ''})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currency${_fmt.format(outstanding)} outstanding • $countdownText',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Pay bill button
          ElevatedButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AddTransactionScreen(
                  initialType: 'Transfer',
                  prefilledToAccountId: acc['id']?.toString() ?? '',
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              elevation: 0,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Pay Bill',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category section (header + sub-account list)
// ---------------------------------------------------------------------------

class _AccountCategorySection extends StatelessWidget {
  const _AccountCategorySection({
    required this.category,
    required this.accounts,
    required this.currency,
    required this.onAccountTap,
  });

  final _AccountCategory category;
  final List<Map<String, dynamic>> accounts;
  final String currency;
  final void Function(Map<String, dynamic> acc) onAccountTap;

  bool get _isCreditCard => category.dbType == 'Credit Card';

  /// For credit cards: sum of outstanding debt (positive = money owed).
  /// For all other types: sum of available balances.
  double get _sectionTotal {
    if (_isCreditCard) {
      return accounts.fold<double>(0.0, (sum, acc) {
        final limit = _parseDouble(acc['limit']);
        final available = _parseDouble(acc['balance']);
        return sum + (limit - available).clamp(0, double.infinity);
      });
    }
    return accounts.fold<double>(
      0.0,
      (sum, acc) => sum + _parseDouble(acc['balance']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _sectionTotal;
    final dividerColor = Theme.of(context).dividerColor.withOpacity(0.2);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Header row ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isCreditCard
                        ? Colors.redAccent.withAlpha(25)
                        : AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category.icon,
                    color: _isCreditCard ? Colors.redAccent : AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  // For credit cards, total > 0 means money owed → show as negative.
                  _formatBalance(
                    balance: total,
                    isCreditCard: _isCreditCard,
                    currency: currency,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _isCreditCard && total > 0.01
                        ? const Color(0xFFE74C3C)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // ---- Sub-account list OR empty-state notice ----
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                'No ${category.name.toLowerCase()} accounts yet.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                ),
              ),
            )
          else ...[
            Divider(height: 1, thickness: 1, color: dividerColor),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accounts.length,
              itemBuilder: (context, index) => _SubAccountTile(
                acc: accounts[index],
                currency: currency,
                isCreditCard: _isCreditCard,
                onTap: () => onAccountTap(accounts[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-account tile
// ---------------------------------------------------------------------------

class _SubAccountTile extends StatelessWidget {
  const _SubAccountTile({
    required this.acc,
    required this.currency,
    required this.isCreditCard,
    required this.onTap,
  });

  final Map<String, dynamic> acc;
  final String currency;
  final bool isCreditCard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double displayBalance;
    final double limit;
    final double available;

    if (isCreditCard) {
      limit = _parseDouble(acc['limit']);
      available = _parseDouble(acc['balance']);
      // Positive value = outstanding debt.
      displayBalance = (limit - available).clamp(0, double.infinity);
    } else {
      limit = 0;
      available = 0;
      displayBalance = _parseDouble(acc['balance']);
    }

    // For credit cards: any outstanding debt is "negative" from the user's pov.
    // For regular accounts: a negative balance is an overdraft.
    final isDebt = isCreditCard
        ? displayBalance > 0.01
        : displayBalance < -0.01;

    final balanceText = _formatBalance(
      balance: displayBalance,
      isCreditCard: isCreditCard,
      currency: currency,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            const SizedBox(width: 6),
            const Icon(
              Icons.subdirectory_arrow_right,
              color: Colors.grey,
              size: 14,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acc['name']?.toString() ?? '—',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (isCreditCard) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Limit: $currency${_fmt.format(limit)}  |  Avail: $currency${_fmt.format(available)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(100),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              balanceText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDebt
                    ? const Color(0xFFE74C3C)
                    : const Color(0xFF2ECC71),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
