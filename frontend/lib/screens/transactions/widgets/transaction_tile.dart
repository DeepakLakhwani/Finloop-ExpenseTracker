import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../add_transaction_screen.dart';
import '../../../services/ad_service.dart';
import '../../../providers/language_provider.dart';

class TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String currency;
  final bool showDate;
  final bool isNested;
  final double amountFontSize;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currency,
    this.showDate = false,
    this.isNested = false,
    this.amountFontSize = 12.0,
  });

  DateTime _parseDate(dynamic dateVal) {
    if (dateVal is DateTime) return dateVal;
    if (dateVal is String) return DateTime.parse(dateVal);
    // Firestore Timestamp check
    try {
      return dateVal.toDate();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'];
    final isIncome = type == 'Income';
    final isTransfer = type == 'Transfer';
    final amount = (double.tryParse(transaction['amount'].toString()) ?? 0.0)
        .abs();
    final catName = transaction['category_name']?.toString() ?? 'General';
    final displayName = isTransfer
        ? context.translate('cat_transfer')
        : context.getLocalizedCategory(
            transaction['category_key']?.toString(),
            catName,
          );

    final amountColor = isIncome
        ? Colors.green
        : (isTransfer ? Colors.blue : Colors.red);

    final tileContent = Padding(
      padding: isNested
          ? const EdgeInsets.symmetric(vertical: 8, horizontal: 0)
          : const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Category Name, Optional Notes, and Optional Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (transaction['notes'] != null &&
                        transaction['notes'].toString().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '• ${transaction['notes']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (transaction['attachment_url'] != null &&
                        transaction['attachment_url']
                            .toString()
                            .isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.attach_file,
                        size: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ],
                  ],
                ),
                if (showDate) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(
                      'dd MMM yyyy',
                    ).format(_parseDate(transaction['date'])),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Amount and Account Name
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency${NumberFormat('#,##0.00').format(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: amountFontSize == 12.0 ? 14.0 : amountFontSize,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isTransfer
                    ? '${transaction['account_name'] ?? 'Account'} ➔ ${transaction['to_account_name'] ?? 'Account'}'
                    : (transaction['account_name'] ?? 'No Account'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );

    if (isNested) {
      return GestureDetector(
        onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddTransactionScreen(initialTransaction: transaction),
              ),
            ).then((saved) {
              if (saved == true) {
                AdService.showInterstitial(() {});
              }
            }),
        child: tileContent,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddTransactionScreen(initialTransaction: transaction),
              ),
            ).then((saved) {
              if (saved == true) {
                AdService.showInterstitial(() {});
              }
            }),
        child: tileContent,
      ),
    );
  }
}
