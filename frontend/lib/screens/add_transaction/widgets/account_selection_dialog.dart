import 'package:flutter/material.dart';

class AccountSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final bool isToAccount;
  final Color activeColor;
  final ValueChanged<String> onAccountSelected;

  const AccountSelectionDialog({
    super.key,
    required this.accounts,
    required this.isToAccount,
    required this.activeColor,
    required this.onAccountSelected,
  });

  IconData _getAccountIcon(String? type) {
    switch (type) {
      case 'Bank Account':
        return Icons.account_balance_outlined;
      case 'Cash':
        return Icons.payments_outlined;
      case 'Credit Card':
        return Icons.credit_card_outlined;
      case 'Wallet':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.account_balance_wallet;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isToAccount ? 'Select Destination Account' : 'Select Account',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: accounts.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No accounts found.'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: accounts.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: 0.5,
                ),
                itemBuilder: (context, index) {
                  final acc = accounts[index];
                  return ListTile(
                    leading: Icon(
                      _getAccountIcon(acc['type']),
                      color: activeColor,
                    ),
                    title: Text(acc['name']),
                    onTap: () {
                      onAccountSelected(acc['id'].toString());
                      Navigator.pop(context);
                    },
                  );
                },
              ),
      ),
    );
  }
}
