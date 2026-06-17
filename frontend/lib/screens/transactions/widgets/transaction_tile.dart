import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:characters/characters.dart';
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
    this.amountFontSize = 14.0,
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

  Color _getCategoryColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('shopping') || n.contains('shop')) return Colors.purple;
    if (n.contains('house') || n.contains('rent')) return Colors.teal;
    if (n.contains('grocery')) return Colors.red;
    if (n.contains('salary')) return Colors.green;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    final type = transaction['type'];
    final isIncome = type == 'Income';
    final isTransfer = type == 'Transfer';
    final amount = (double.tryParse(transaction['amount'].toString()) ?? 0.0).abs();
    final catName = transaction['category_name']?.toString() ?? 'General';
    final displayName = isTransfer ? 'Transfer' : catName;
    final isOpeningBalance = displayName.toLowerCase() == 'opening balance' || transaction['category_id'] == 'opening_balance';

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
      } else {
        color = _getCategoryColor(catName);
      }
    }

    final displayChar = _getCategoryDisplay(displayName);

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
        child: Row(
          children: [
            // Column 1: Details (Initials badge + details) - flex 4
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    alignment: Alignment.center,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      displayChar,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        if (transaction['notes'] != null && transaction['notes'].toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notes_outlined,
                                size: 10,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  transaction['notes'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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

            // Column 2: Right-aligned Amount Block - flex 3
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currency${NumberFormat('#,##0.00').format(amount)}',
                      style: TextStyle(
                        fontWeight: amountFontSize == 12 ? FontWeight.w600 : FontWeight.bold,
                        fontSize: amountFontSize,
                        color: isIncome
                            ? Colors.green
                            : isTransfer
                                ? Colors.blue
                                : Colors.red,
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
