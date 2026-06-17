import 'package:cloud_firestore/cloud_firestore.dart';

/// Pure domain class responsible for calculating and aggregating financial analytics.
class FinancialAnalytics {
  final List<Map<String, dynamic>> allTransactions;
  final List<Map<String, dynamic>> userAccounts;

  FinancialAnalytics({
    required this.allTransactions,
    required this.userAccounts,
  });

  DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.parse(val);
    return DateTime.now();
  }

  /// Calculates total expense amount for the current calendar month.
  double get totalCurrentMonthExpenses {
    final now = DateTime.now();
    double total = 0.0;
    for (var tx in allTransactions) {
      final date = _parseDate(tx['date']);
      if (date.year == now.year && date.month == now.month && tx['type'] == 'Expense') {
        total += double.tryParse(tx['amount']?.toString() ?? '0.0') ?? 0.0;
      }
    }
    return total;
  }

  /// Groups, sorts, and filters expense data for the current month into primary categories and 'Others'.
  List<MapEntry<String, double>> get pieData {
    final now = DateTime.now();
    final categoryMap = <String, double>{};

    for (var tx in allTransactions) {
      final date = _parseDate(tx['date']);
      if (date.year == now.year && date.month == now.month && tx['type'] == 'Expense') {
        final amt = double.tryParse(tx['amount']?.toString() ?? '0.0') ?? 0.0;
        final catName = tx['category_name']?.toString() ?? 'Other';
        categoryMap[catName] = (categoryMap[catName] ?? 0.0) + amt;
      }
    }

    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <MapEntry<String, double>>[];
    double othersSum = 0.0;
    for (int i = 0; i < sortedCategories.length; i++) {
      if (i < 3) {
        result.add(sortedCategories[i]);
      } else {
        othersSum += sortedCategories[i].value;
      }
    }
    if (othersSum > 0.0) {
      result.add(MapEntry('Others', othersSum));
    }
    return result;
  }

  /// Returns the past 6 calendar months as a chronological list of Dates.
  List<DateTime> get trendMonths {
    final now = DateTime.now();
    final result = <DateTime>[];
    for (int i = 5; i >= 0; i--) {
      result.add(DateTime(now.year, now.month - i, 1));
    }
    return result;
  }

  /// Calculates chronological expense totals for the past 6 months.
  List<double> get monthlyExpenses {
    final result = <double>[];
    for (var m in trendMonths) {
      final sum = allTransactions.where((tx) {
        final date = _parseDate(tx['date']);
        return date.year == m.year && date.month == m.month && tx['type'] == 'Expense';
      }).fold<double>(0.0, (sum, tx) => sum + (double.tryParse(tx['amount']?.toString() ?? '0.0') ?? 0.0));
      result.add(sum);
    }
    return result;
  }

  /// Computes the optimal Y-axis bounds for the spending trend bar charts.
  double get maxY {
    double maxExpense = monthlyExpenses.fold(0.0, (max, val) => val > max ? val : max);
    return maxExpense > 0 ? maxExpense * 1.15 : 100;
  }

  /// Computes a smart analysis string comparing current month spending against the previous month.
  String get insightText {
    final now = DateTime.now();
    final currentMonthExpenses = totalCurrentMonthExpenses;

    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prevMonthTxs = allTransactions.where((tx) {
      final date = _parseDate(tx['date']);
      return date.year == prevMonthDate.year && date.month == prevMonthDate.month;
    }).toList();
    
    final prevMonthExpenses = prevMonthTxs
        .where((tx) => tx['type'] == 'Expense')
        .fold<double>(0.0, (sum, tx) => sum + (double.tryParse(tx['amount']?.toString() ?? '0.0') ?? 0.0));

    if (prevMonthExpenses > 0) {
      final diffPercent = ((prevMonthExpenses - currentMonthExpenses) / prevMonthExpenses * 100).abs();
      final formattedPercent = diffPercent.toStringAsFixed(0);
      if (currentMonthExpenses < prevMonthExpenses) {
        return "You've spent $formattedPercent% less this month compared to last month. Great job!";
      } else {
        return "You've spent $formattedPercent% more this month compared to last month. Consider reviewing your budgets.";
      }
    } else if (currentMonthExpenses > 0) {
      return "You've started tracking your expenses. Keep it up to see comparison next month!";
    }
    return 'Keep tracking your transactions to see smart insights here next month.';
  }

  /// Calculates total net balance across all bank accounts and wallets (excluding credit cards).
  double get totalBalance {
    double total = 0.0;
    for (var acc in userAccounts) {
      if (acc['type'] != 'Credit Card') {
        total += double.tryParse(acc['balance']?.toString() ?? '0.0') ?? 0.0;
      }
    }
    return total;
  }
}
