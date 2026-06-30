import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:characters/characters.dart';
import '../services/firestore_service.dart';
import '../services/ad_service.dart';
import '../providers/settings_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import 'add_account_screen.dart';
import 'add_transaction_screen.dart';

class AccountEntriesScreen extends StatefulWidget {
  final Map<String, dynamic> account;
  final List<dynamic> entries;

  const AccountEntriesScreen({
    super.key,
    required this.account,
    required this.entries,
  });

  @override
  State<AccountEntriesScreen> createState() => _AccountEntriesScreenState();
}

class _AccountEntriesScreenState extends State<AccountEntriesScreen> {
  late Map<String, dynamic> _account;
  late List<dynamic> _entries;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _entries = widget.entries;
  }

  Future<void> _refreshAccountAndEntries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // ✅ Fix #8: capture service before any await
    final firestore = context.read<FirestoreService>();

    try {
      final accounts = await firestore.getAccounts().first;
      if (!mounted) return;

      final matchingList = accounts.where((acc) => acc['id'] == _account['id']);
      final Map<String, dynamic>? updatedAccount = matchingList.isNotEmpty
          ? matchingList.first
          : null;

      if (updatedAccount == null) {
        if (mounted) Navigator.pop(context, true);
        return;
      }

      // ✅ Fix #3: null-safe account ID
      final accountId = _account['id']?.toString() ?? '';
      if (accountId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final newEntries = await firestore.getAccountTransactions(accountId);
      if (!mounted) return;

      newEntries.sort((a, b) {
        final aDate = _parseDate(a['date']);
        final bDate = _parseDate(b['date']);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _account = updatedAccount;
        _entries = newEntries;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error refreshing account entries: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editAccount() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAccountScreen(initialAccount: _account),
      ),
    );
    // ✅ Fix #9: mounted check after await
    if (result == true && mounted) {
      _refreshAccountAndEntries();
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.translate('title_delete_account')),
        content: Text(context.translate('delete_account_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.translate('delete'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    // ✅ Fix #1: capture service before await to avoid stale context
    final firestore = context.read<FirestoreService>();

    setState(() => _isLoading = true);
    try {
      await firestore.deleteAccount(_account['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      }
    }
  }

  String _getCategoryDisplay(String categoryName) {
    var name = categoryName.trim();
    if (name.isEmpty) return '';

    final emojiRegex = RegExp(
      r'[\u{1F000}-\u{1FAFF}]|[\u{2600}-\u{27BF}]',
      unicode: true,
    );
    name = name.replaceAll(emojiRegex, '').trim();

    if (name.isEmpty) return '';
    return name.characters.first.toUpperCase();
  }

  // ✅ Fix #4: use tryParse instead of parse to avoid throws on bad strings
  DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  // ✅ Fix #6: safe hex color parsing with fallback
  Color _parseCardColor(String? hex, {Color fallback = AppColors.primary}) {
    try {
      if (hex == null || hex.isEmpty) return fallback;
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildTransactionItem(
    Map<String, dynamic> tx,
    String currency,
    double closingBalance,
  ) {
    final type = tx['type'];
    final isIncome = type == 'Income';
    final isTransfer = type == 'Transfer';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
    final catName = tx['category_name']?.toString() ?? 'General';
    final displayName = isTransfer ? 'Transfer' : catName;
    final isOpeningBalance =
        displayName.toLowerCase() == 'opening balance' ||
        tx['category_id'] == 'opening_balance';

    Color color = Colors.orange;
    if (isOpeningBalance) {
      color = Colors.grey;
    } else if (isIncome) {
      color = Colors.green;
    } else if (isTransfer) {
      color = Colors.blue;
    } else {
      final cat = catName.toLowerCase();
      if (cat.contains('grocery')) {
        color = Colors.red;
      } else if (cat.contains('rent')) {
        color = Colors.blue;
      } else if (cat.contains('dining') || cat.contains('food')) {
        color = Colors.orange;
      } else if (cat.contains('salary')) {
        color = Colors.green;
      }
    }

    final displayString = _getCategoryDisplay(displayName);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddTransactionScreen(initialTransaction: tx),
          ),
        );
        // ✅ Fix #5: only show ad and refresh if transaction was actually saved
        if (result == true && mounted) {
          _refreshAccountAndEntries();
          AdService.showInterstitial(() {});
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            // Left: Category Initials Badge
            Container(
              alignment: Alignment.center,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                displayString,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Name, Notes, Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tx['notes'] != null &&
                      tx['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes_outlined,
                          size: 10,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tx['notes'],
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy').format(_parseDate(tx['date'])),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Right: Amount & Closing Balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$currency${NumberFormat('#,##0.00').format(amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isIncome
                        ? Colors.green
                        : (isTransfer ? Colors.blue : Colors.red),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bal: $currency${NumberFormat('#,##0.00').format(closingBalance)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    final balance =
        double.tryParse(_account['balance']?.toString() ?? '0') ?? 0.0;

    // ✅ Fix #3 & #7: safe account ID; use index-based key to avoid empty-string collisions
    final accountIdStr = _account['id']?.toString() ?? '';
    final Map<int, double> closingBalances = {};
    double runningBalance = balance;

    for (var i = 0; i < _entries.length; i++) {
      final tx = _entries[i];
      // Store closing balance BEFORE this transaction (running total going backward)
      closingBalances[i] = runningBalance;

      final amt = double.tryParse(tx['amount']?.toString() ?? '0.0') ?? 0.0;
      final type = tx['type']?.toString() ?? '';
      final fees = double.tryParse(tx['fees']?.toString() ?? '0.0') ?? 0.0;

      // ✅ Fix #2: correct direction — entries are newest-first so we go backward in time
      // Income means money came IN, so going backward we subtract it
      // Expense means money went OUT, so going backward we add it back
      if (type == 'Income') {
        runningBalance -= amt;
      } else if (type == 'Expense') {
        runningBalance += amt;
      } else if (type == 'Transfer') {
        final fromAccId =
            (tx['account_id'] ?? tx['accountId'])?.toString() ?? '';
        final toAccId =
            (tx['to_account_id'] ?? tx['toAccountId'])?.toString() ?? '';
        if (fromAccId == accountIdStr) {
          runningBalance += (amt + fees);
        } else if (toAccId == accountIdStr) {
          runningBalance -= amt;
        }
      }
    }

    final limit =
        double.tryParse(_account['limit']?.toString() ?? '0.0') ?? 0.0;
    final available =
        double.tryParse(_account['balance']?.toString() ?? '0.0') ?? 0.0;
    final used = limit > 0 ? (limit - available) : 0.0;
    final isCreditCard = _account['type'] == 'Credit Card';

    // ✅ Fix #6: safe color parsing
    final cardColor = isCreditCard
        ? _parseCardColor(_account['color'], fallback: const Color(0xFF1E3A8A))
        : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          _account['name'] ?? 'Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed: _editAccount,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 22,
            ),
            onPressed: _deleteAccount,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // Account summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cardColor, cardColor.withValues(alpha: 0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: cardColor.withValues(alpha: 0.24),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCreditCard
                                  ? '${_account['cardIssuer'] ?? 'Credit Card'} (${_account['type']})'
                                  : (_account['type'] ?? 'Account'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (isCreditCard) ...[
                              Text(
                                '$currency ${NumberFormat('#,##0.00').format(available)}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Available Credit',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Used: $currency${NumberFormat('#,##0.00').format(used)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Limit: $currency${NumberFormat('#,##0.00').format(limit)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                '$currency ${NumberFormat('#,##0.00').format(balance)}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${_entries.length} Transaction${_entries.length == 1 ? "" : "s"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _entries.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No entries in this account',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _entries.length,
                          physics: const BouncingScrollPhysics(),
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 1,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          itemBuilder: (context, index) {
                            final tx = _entries[index];
                            final closingBalance =
                                closingBalances[index] ?? 0.0;
                            return _buildTransactionItem(
                              tx,
                              currency,
                              closingBalance,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTransactionScreen(
                prefilledAccountId: _account['id']?.toString(),
              ),
            ),
          );
          if (result == true && mounted) {
            _refreshAccountAndEntries();
            AdService.showInterstitial(() {});
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
