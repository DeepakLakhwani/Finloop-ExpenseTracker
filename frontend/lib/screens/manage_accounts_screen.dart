import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/language_provider.dart';
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
String _dueCountdownText(BuildContext context, int dueDay) {
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
  if (diff == 0) return context.translate('due_today');
  return context.translate('due_in_days').replaceAll('{days}', diff.toString());
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
    this.id,
  });

  final String name;
  final String dbType;
  final IconData icon;
  final String? id;
}

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
  List<Map<String, dynamic>> _customMainAccounts = [];
  bool _isLoading = true;
  Object? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  StreamSubscription<List<Map<String, dynamic>>>? _customMainSub;

  // Guard against concurrent navigations triggered by rapid taps.
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so that context.read is safe even if the widget
    // tree hasn't fully settled during hot-reload / deep linking scenarios.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToAccounts();
      _listenToCustomMainAccounts();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _customMainSub?.cancel();
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
    _listenToCustomMainAccounts();
  }

  void _listenToCustomMainAccounts() {
    if (!mounted) return;
    _customMainSub?.cancel();
    _customMainSub = context.read<FirestoreService>().getMainAccounts().listen(
      (customCats) {
        if (!mounted) return;
        setState(() {
          _customMainAccounts = customCats;
        });
      },
      onError: (Object e) {
        debugPrint(
          '[ManageAccounts] Error listening to custom main accounts: $e',
        );
      },
    );
  }

  IconData _mapStringToIcon(String name) {
    switch (name) {
      case 'account_balance':
      case 'account_balance_outlined':
        return Icons.account_balance_outlined;
      case 'payments':
      case 'payments_outlined':
        return Icons.payments_outlined;
      case 'credit_card':
      case 'credit_card_outlined':
        return Icons.credit_card_outlined;
      case 'savings':
      case 'savings_outlined':
        return Icons.savings_outlined;
      case 'trending_up':
      case 'trending_up_outlined':
        return Icons.trending_up_outlined;
      case 'handshake':
      case 'handshake_outlined':
        return Icons.handshake_outlined;
      case 'security':
      case 'security_outlined':
        return Icons.security_outlined;
      case 'token':
      case 'token_outlined':
        return Icons.token_outlined;
      case 'account_balance_wallet':
      case 'account_balance_wallet_outlined':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.token_outlined;
    }
  }

  void _showAddMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final surfaceColor = Theme.of(context).colorScheme.surface;
        final textColor = Theme.of(context).colorScheme.onSurface;

        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: textColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.translate('title_add_new'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                title: Text(
                  context.translate('title_new_account'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  context.translate('desc_new_account'),
                  style: TextStyle(
                    color: textColor.withAlpha(120),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openAddAccount();
                },
              ),
              const Divider(height: 20, thickness: 0.5),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.category_outlined,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                title: Text(
                  context.translate('title_new_category'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  context.translate('desc_new_category'),
                  style: TextStyle(
                    color: textColor.withAlpha(120),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateMainAccountDialog();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showCreateMainAccountDialog() {
    final controller = TextEditingController();
    String selectedIcon = 'token_outlined';

    final iconsList = [
      {
        'name': 'account_balance_outlined',
        'icon': Icons.account_balance_outlined,
      },
      {'name': 'payments_outlined', 'icon': Icons.payments_outlined},
      {'name': 'credit_card_outlined', 'icon': Icons.credit_card_outlined},
      {'name': 'savings_outlined', 'icon': Icons.savings_outlined},
      {'name': 'trending_up_outlined', 'icon': Icons.trending_up_outlined},
      {'name': 'handshake_outlined', 'icon': Icons.handshake_outlined},
      {'name': 'security_outlined', 'icon': Icons.security_outlined},
      {'name': 'token_outlined', 'icon': Icons.token_outlined},
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                context.translate('title_new_category'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: context.translate('hint_category_name'),
                      labelText: context.translate('label_name'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.translate('label_select_icon'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.maxFinite,
                    height: 90,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: iconsList.length,
                      itemBuilder: (context, idx) {
                        final item = iconsList[idx];
                        final isSelected = selectedIcon == item['name'];
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = item['name'] as String;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withAlpha(40)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.withAlpha(50),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: isSelected
                                  ? AppColors.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    context.translate('cancel'),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      await context.read<FirestoreService>().createMainAccount({
                        'name': name,
                        'icon': selectedIcon,
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: Text(
                    context.translate('save'),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
      builder: (_) => Center(
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
          SnackBar(
            content: Text(context.translate('err_load_account_details')),
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
                context.translate('manage_accounts'),
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
                    onPressed: _showAddMenu,
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
        message: context.translate('err_load_accounts_retry'),
        onRetry: _retryLoad,
      );
    }

    // Compute bottom padding so content is never hidden by the FAB.
    final bottomPad = widget.isTab
        ? MediaQuery.of(context).padding.bottom + 80
        : MediaQuery.of(context).padding.bottom + 16;

    // System-defined types that are not in the default 3 categories:
    final extraSystemTypes = {
      'Savings': Icons.savings_outlined,
      'Investments': Icons.trending_up_outlined,
      'Loan': Icons.handshake_outlined,
      'Insurance': Icons.security_outlined,
      'Others': Icons.token_outlined,
    };

    // Find which extra system types have active accounts:
    final activeExtraCategories = <_AccountCategory>[];
    for (final entry in extraSystemTypes.entries) {
      final dbType = entry.key;
      final icon = entry.value;
      final hasAccounts = _accounts.any((acc) => acc['type'] == dbType);
      if (hasAccounts) {
        activeExtraCategories.add(
          _AccountCategory(name: dbType, dbType: dbType, icon: icon),
        );
      }
    }

    final allCategories = [
      ..._customMainAccounts.map((cat) {
        final id = cat['id'] as String?;
        final name = cat['name'] as String? ?? 'Others';
        final iconName = cat['icon'] as String? ?? 'token_outlined';
        return _AccountCategory(
          id: id,
          name: name,
          dbType: name,
          icon: _mapStringToIcon(iconName),
        );
      }),
      ...activeExtraCategories,
    ];

    // Sort categories: 1. Account, 2. Cash, 3. Card, then others.
    allCategories.sort((a, b) {
      int getWeight(String dbType) {
        if (dbType == 'Account' || dbType == 'Bank' || dbType == 'Bank Account')
          return 1;
        if (dbType == 'Cash') return 2;
        if (dbType == 'Card' || dbType == 'Credit Card' || dbType == 'Cards')
          return 3;
        return 100;
      }

      final wA = getWeight(a.dbType);
      final wB = getWeight(b.dbType);
      if (wA != wB) {
        return wA.compareTo(wB);
      }
      return a.name.compareTo(b.name);
    });

    return ListView(
      padding: EdgeInsets.fromLTRB(0, 10, 0, bottomPad),
      children: [
        _DuesBanner(accounts: _accounts, currency: currency),
        for (final cat in allCategories)
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
          if (acc['type'] != 'Credit Card' && acc['type'] != 'Card')
            return false;
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
            context.translate('header_card_dues'),
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
    final countdownText = _dueCountdownText(context, dueDay);

    return Card(
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.orangeAccent.withAlpha(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    '${acc['cardIssuer'] ?? 'Card'} (${acc['name'] ?? ''})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency${_fmt.format(outstanding)} ${context.translate('label_outstanding')} • $countdownText',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                elevation: 0,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                context.translate('btn_pay_bill'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
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

  bool get _isCreditCard =>
      category.dbType == 'Card' || category.dbType == 'Credit Card';

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
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.2);

    return Card(
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
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
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category.icon,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    () {
                      final key =
                          'type_${category.name.toLowerCase().replaceAll(' ', '_')}';
                      final val = context.translate(key);
                      return val == key ? category.name : val;
                    }(),
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
                context.translate('msg_no_accounts_in_category'),
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
                      '${context.translate('label_limit')}: $currency${_fmt.format(limit)}  |  ${context.translate('label_available')}: $currency${_fmt.format(available)}',
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
