import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../add_transaction_screen.dart';
import '../../../services/ad_service.dart';

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
    final amount = (double.tryParse(transaction['amount'].toString()) ?? 0.0).abs();
    final catName = transaction['category_name']?.toString() ?? 'General';
    final displayName = isTransfer ? 'Transfer' : catName;




    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddTransactionScreen(initialTransaction: transaction),
        ),
      ).then((saved) {
        if (saved == true) {
          AdService.showInterstitial(() {});
        }
      }),
      child: Container(
        margin: EdgeInsets.zero,
        padding: isNested
            ? const EdgeInsets.symmetric(vertical: 8, horizontal: 0)
            : const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: isNested
            ? null
            : BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Column 1: Details - aligned under Date column (1/3 of width)
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (showDate) ...[
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMM yyyy').format(_parseDate(transaction['date'])),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 1),
                // Column 2: Income Amount (centered, under daily Income column)
                Expanded(
                  child: isIncome
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '$currency${NumberFormat('#,##0.00').format(amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: amountFontSize,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transaction['account_name'] ?? 'No Account',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 1),
                // Column 3: Expense/Transfer Amount (centered, under daily Expense column)
                Expanded(
                  child: !isIncome
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '$currency${NumberFormat('#,##0.00').format(amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: amountFontSize,
                                color: isTransfer ? Colors.blue : Colors.red,
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
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.455),
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            if (transaction['notes'] != null && transaction['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_outlined,
                      size: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        transaction['notes'],
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
