import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import 'package:intl/intl.dart';

class AccountSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final bool isToAccount;
  final Color activeColor;
  final String? selectedAccountId;
  final ValueChanged<String> onAccountSelected;

  const AccountSelectionDialog({
    super.key,
    required this.accounts,
    required this.isToAccount,
    required this.activeColor,
    this.selectedAccountId,
    required this.onAccountSelected,
  });

  IconData _getAccountIcon(String? type) {
    switch (type) {
      case 'Bank Account':
      case 'Account':
        return Icons.account_balance_outlined;
      case 'Cash':
        return Icons.payments_outlined;
      case 'Credit Card':
      case 'Card':
        return Icons.credit_card_outlined;
      case 'Wallet':
        return Icons.account_balance_wallet_outlined;
      case 'Savings':
        return Icons.savings_outlined;
      case 'Investments':
        return Icons.trending_up_outlined;
      case 'Loan':
        return Icons.handshake_outlined;
      case 'Insurance':
        return Icons.security_outlined;
      case 'Others':
        return Icons.token_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final currency = context.watch<SettingsProvider>().currency;
    final formatter = NumberFormat('#,##0.00');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToAccount ? 'Select Destination Account' : 'Select Account',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),

          // Content List
          Flexible(
            child: accounts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No accounts found.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final acc = accounts[index];
                      final isSelected = selectedAccountId == acc['id'].toString();
                      final balance = _parseDouble(acc['balance']);

                      return InkWell(
                        onTap: () {
                          onAccountSelected(acc['id'].toString());
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? activeColor.withValues(alpha: 0.08)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? activeColor
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isSelected ? activeColor : Theme.of(context).colorScheme.onSurface).withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getAccountIcon(acc['type']),
                                  color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc['name'] ?? '',
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        fontSize: 15,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      acc['type'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$currency${formatter.format(balance)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(height: 4),
                                    Icon(
                                      Icons.check_circle,
                                      color: activeColor,
                                      size: 16,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
