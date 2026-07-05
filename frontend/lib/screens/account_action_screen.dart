import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import 'add_account_screen.dart';

enum AccountActionMode { edit, delete }

class AccountActionScreen extends StatefulWidget {
  final AccountActionMode mode;
  const AccountActionScreen({super.key, required this.mode});

  @override
  State<AccountActionScreen> createState() => _AccountActionScreenState();
}

class _AccountActionScreenState extends State<AccountActionScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    try {
      final firestore = context.read<FirestoreService>();
      final accounts = await firestore.getAccounts().first;
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching accounts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDeleteMode = widget.mode == AccountActionMode.delete;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isDeleteMode ? 'Delete Accounts' : 'Select Account to Edit',
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? const Center(child: Text('No accounts found'))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final account = _accounts[index];
                final balance = account['balance'];
                final displayBalance = balance != null
                    ? (double.tryParse(balance.toString()) ?? 0.0)
                    : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: isDeleteMode
                        ? GestureDetector(
                            onTap: () => _showDeleteConfirmation(account),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getAccountIcon(account['type']),
                              color: primaryColor,
                            ),
                          ),
                    title: Text(
                      account['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(account['type']),
                    trailing: Text(
                      '${account['currency']} ${displayBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // ✅ Fix #5: onTap only handles edit; delete is via leading icon only
                    onTap: widget.mode == AccountActionMode.edit
                        ? () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddAccountScreen(initialAccount: account),
                              ),
                            );
                            if (result == true && mounted) _fetchAccounts();
                          }
                        : null,
                  ),
                );
              },
            ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
          'Are you sure you want to delete "${account['name']}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            // ✅ Fix #4: capture service before await to avoid stale context
            onPressed: () async {
              final firestoreService = context.read<FirestoreService>();
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await firestoreService.deleteAccount(account['id']);
                if (mounted) _fetchAccounts();
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting account: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  IconData _getAccountIcon(String type) {
    switch (type) {
      case 'Bank Account':
      case 'Account':
        return Icons.account_balance;
      case 'Wallet':
        return Icons.account_balance_wallet;
      case 'Credit Card':
      case 'Card':
        return Icons.credit_card;
      case 'Savings':
        return Icons.savings;
      case 'Investments':
        return Icons.trending_up;
      case 'Loan':
        return Icons.handshake;
      case 'Insurance':
        return Icons.security;
      case 'Others':
        return Icons.token;
      default:
        return Icons.money;
    }
  }
}
