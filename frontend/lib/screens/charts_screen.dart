import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/financial_analytics.dart';
import '../providers/settings_provider.dart';
import '../providers/language_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────
abstract final class _K {
  static const double cardRadius = 24;
  static const double cardPadding = 24;
  static const double sectionGap = 24;
  static const double chartHeight = 200;
  static const double pieCenter = 50;
  static const double barWidth = 32;

  static const List<Color> palette = [
    Colors.green,
    AppColors.primary,
    Color(0xFFE57373),
    Colors.purple,
    Colors.amber,
    Colors.teal,
    Colors.pinkAccent,
  ];
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  // Stream subscriptions kept for proper disposal
  StreamSubscription<List<Map<String, dynamic>>>? _txSub;
  StreamSubscription<List<Map<String, dynamic>>>? _accSub;
  StreamSubscription<List<Map<String, dynamic>>>? _budgetSub;

  int _touchedIndex = -1;
  bool _isLoading = true;
  bool _hasError = false;

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _userAccounts = [];
  List<Map<String, dynamic>> _allBudgets = [];

  @override
  void initState() {
    super.initState();
    _subscribeToData();
  }

  @override
  void dispose() {
    _txSub?.cancel();
    _accSub?.cancel();
    _budgetSub?.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────
  void _subscribeToData() {
    final firestore = FirestoreService();

    // Subscribe to both streams independently so neither leaks
    _txSub = firestore.getTransactions().listen((txList) {
      if (!mounted) return;
      setState(() {
        _allTransactions = txList;
        _isLoading = false;
      });
    }, onError: (_) => _setError());

    _accSub = firestore.getAccounts().listen((accList) {
      if (!mounted) return;
      setState(() => _userAccounts = accList);
    }, onError: (_) => _setError());

    _budgetSub = firestore.getBudgets().listen((budgetList) {
      if (!mounted) return;
      setState(() => _allBudgets = budgetList);
    }, onError: (_) => _setError());
  }

  void _setError() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  // ── Helpers ───────────────────────────────────
  String _formatY(double value) {
    if (value >= 1_000_000) {
      return '${(value / 1_000_000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (value >= 1_000) {
      return '${(value / 1_000).toStringAsFixed(1).replaceAll('.0', '')}k';
    }
    return value.toStringAsFixed(0);
  }

  // ── Build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasError) {
      return Scaffold(
        body: Center(child: Text(context.translate('err_load_data_retry'))),
      );
    }

    final currency = context.watch<SettingsProvider>().currency;
    final analytics = FinancialAnalytics(
      allTransactions: _allTransactions,
      userAccounts: _userAccounts,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(month: DateTime.now()),
            const SizedBox(height: _K.sectionGap),
            _ExpenseDistributionCard(
              pieData: analytics.pieData,
              totalExpenses: analytics.totalCurrentMonthExpenses,
              currency: currency,
              touchedIndex: _touchedIndex,
              onTouch: (i) => setState(() => _touchedIndex = i),
            ),
            if (_allBudgets.isNotEmpty) ...[
              const SizedBox(height: _K.sectionGap),
              _BudgetsCard(
                budgets: _allBudgets,
                transactions: _allTransactions,
                currency: currency,
              ),
            ],
            const SizedBox(height: _K.sectionGap),
            _MonthlyTrendsCard(
              months: analytics.trendMonths,
              expenses: analytics.monthlyExpenses,
              maxY: analytics.maxY,
              currency: currency,
              formatY: _formatY,
            ),
            const SizedBox(height: _K.sectionGap),
            _SmartInsightCard(
              text: () {
                final info = analytics.insightInfo;
                final localized = context.translate(info.key);
                if (info.percent != null) {
                  return localized.replaceAll('{percent}', info.percent!);
                }
                return localized;
              }(),
            ),
            const SizedBox(height: _K.sectionGap),
            _AvailableBudgetCard(
              balance: analytics.totalBalance,
              currency: currency,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets (private, stateless where possible)
// ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final langProvider = context.watch<LanguageProvider>();
    final localizedMonth = DateFormat(
      'MMMM',
      langProvider.languageCode,
    ).format(month);
    final subtitle = context
        .translate('spending_intelligence')
        .replaceAll('{month}', localizedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.translate('charts_analytics'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

// ── Expense Distribution ──────────────────────
class _ExpenseDistributionCard extends StatelessWidget {
  const _ExpenseDistributionCard({
    required this.pieData,
    required this.totalExpenses,
    required this.currency,
    required this.touchedIndex,
    required this.onTouch,
  });

  final List<MapEntry<String, double>> pieData;
  final double totalExpenses;
  final String currency;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  @override
  Widget build(BuildContext context) {
    if (totalExpenses <= 0) return const _EmptyDistributionCard();

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final parts = pieData.first.key.split('::');
    final topKey = parts[0];
    final topFallback = parts.length > 1 ? parts[1] : '';
    final topCategory = pieData.first.key == 'Others'
        ? context.translate('others')
        : context.getLocalizedCategory(topKey, topFallback);
    final topPct = (pieData.first.value / totalExpenses * 100).toStringAsFixed(
      0,
    );

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: context.translate('expense_distribution'),
            subtitle: context
                .translate('top_category_pct')
                .replaceAll('{category}', topCategory)
                .replaceAll('{pct}', topPct),
            icon: Icons.pie_chart_outline,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final idx =
                            (!event.isInterestedForInteractions ||
                                response?.touchedSection == null)
                            ? -1
                            : response!.touchedSection!.touchedSectionIndex;
                        onTouch(idx);
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 0,
                    centerSpaceRadius: _K.pieCenter,
                    sections: List.generate(pieData.length, (i) {
                      final isTouched = i == touchedIndex;

                      // Calculate mid angle in radians
                      double sumBefore = 0.0;
                      for (int j = 0; j < i; j++) {
                        sumBefore += pieData[j].value;
                      }
                      final double currentValue = pieData[i].value;
                      final double startAngle = totalExpenses > 0
                          ? (sumBefore / totalExpenses) * 360
                          : 0.0;
                      final double sweepAngle = totalExpenses > 0
                          ? (currentValue / totalExpenses) * 360
                          : 0.0;
                      final double midAngleRadians =
                          (startAngle + (sweepAngle / 2)) * math.pi / 180;

                      final parts = pieData[i].key.split('::');
                      final key = parts[0];
                      final fallback = parts.length > 1 ? parts[1] : '';
                      final label = pieData[i].key == 'Others'
                          ? context.translate('others')
                          : context.getLocalizedCategory(key, fallback);

                      return PieChartSectionData(
                        color: _K.palette[i % _K.palette.length],
                        value: pieData[i].value,
                        showTitle: false,
                        radius: isTouched ? 58 : 48,
                        badgeWidget: _CalloutBadge(
                          angle: midAngleRadians,
                          label: label,
                          amount:
                              '$currency${NumberFormat('#,##0.00').format(pieData[i].value)}',
                          color: _K.palette[i % _K.palette.length],
                          textColor: onSurface,
                          isTouched: isTouched,
                        ),
                        badgePositionPercentageOffset: 2.0,
                      );
                    }),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.translate('total_spent'),
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$currency${totalExpenses.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalloutBadge extends StatelessWidget {
  final double angle;
  final String label;
  final String amount;
  final Color color;
  final Color textColor;
  final bool isTouched;

  const _CalloutBadge({
    required this.angle,
    required this.label,
    required this.amount,
    required this.color,
    required this.textColor,
    required this.isTouched,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = math.cos(angle) < 0;

    return CustomPaint(
      painter: _CalloutLinePainter(
        angle: angle,
        color: color,
        isLeft: isLeft,
        isTouched: isTouched,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: isLeft ? 0 : 12,
          right: isLeft ? 12 : 0,
          bottom: 2,
        ),
        child: SizedBox(
          width: 75,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isLeft
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: textColor.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalloutLinePainter extends CustomPainter {
  final double angle;
  final Color color;
  final bool isLeft;
  final bool isTouched;

  const _CalloutLinePainter({
    required this.angle,
    required this.color,
    required this.isLeft,
    required this.isTouched,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double pieRadius = 48.0;
    final double sliceRadius = isTouched ? 58.0 : 48.0;
    const double badgeOffsetRadius = 2.0 * pieRadius;

    final double distanceToEdge = badgeOffsetRadius - sliceRadius;

    final double cosVal = math.cos(angle);
    final double sinVal = math.sin(angle);

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    final double dx = -distanceToEdge * cosVal + centerX;
    final double dy = -distanceToEdge * sinVal + centerY;

    final double elbowY = size.height;
    final path = Path();

    if (isLeft) {
      path.moveTo(dx, dy);
      path.lineTo(size.width, elbowY);
      path.lineTo(0.0, elbowY);
    } else {
      path.moveTo(dx, dy);
      path.lineTo(0.0, elbowY);
      path.lineTo(size.width, elbowY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CalloutLinePainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.color != color ||
        oldDelegate.isLeft != isLeft ||
        oldDelegate.isTouched != isTouched;
  }
}

class _EmptyDistributionCard extends StatelessWidget {
  const _EmptyDistributionCard();

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return _SurfaceCard(
      child: Column(
        children: [
          _CardHeader(
            title: context.translate('expense_distribution'),
            icon: Icons.pie_chart_outline,
          ),
          const SizedBox(height: 40),
          Icon(
            Icons.donut_large_rounded,
            size: 48,
            color: onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            context.translate('no_expense_this_month'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Monthly Trends ────────────────────────────
class _MonthlyTrendsCard extends StatelessWidget {
  const _MonthlyTrendsCard({
    required this.months,
    required this.expenses,
    required this.maxY,
    required this.currency,
    required this.formatY,
  });

  final List<DateTime> months;
  final List<double> expenses;
  final double maxY;
  final String currency;
  final String Function(double) formatY;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final langProvider = context.watch<LanguageProvider>();

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('monthly_spending_trends'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: _K.chartHeight,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => surface,
                    tooltipBorder: BorderSide(
                      color: onSurface.withValues(alpha: 0.08),
                    ),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, _) {
                      final label = DateFormat(
                        'MMMM yyyy',
                        langProvider.languageCode,
                      ).format(months[groupIndex]);
                      return BarTooltipItem(
                        '$label\n',
                        TextStyle(
                          color: onSurface.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '$currency${NumberFormat('#,##0.00').format(rod.toY)}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        final isCurrentMonth = i == months.length - 1;
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            DateFormat(
                              'MMM',
                              langProvider.languageCode,
                            ).format(months[i]),
                            style: TextStyle(
                              color: isCurrentMonth
                                  ? AppColors.primary
                                  : onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max) return const SizedBox.shrink();
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            formatY(value),
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: onSurface.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  months.length,
                  (i) => _buildBar(
                    i,
                    expenses[i],
                    isHighlight: i == months.length - 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              context.translate('last_6_months'),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBar(int x, double y, {required bool isHighlight}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isHighlight
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.15),
          width: _K.barWidth,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(8),
            bottom: Radius.circular(8),
          ),
        ),
      ],
    );
  }
}

// ── Smart Insight ─────────────────────────────
class _SmartInsightCard extends StatelessWidget {
  const _SmartInsightCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_K.cardPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_K.cardRadius),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('smart_insight'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Available Balance ─────────────────────────
class _AvailableBudgetCard extends StatelessWidget {
  const _AvailableBudgetCard({required this.balance, required this.currency});
  final double balance;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_K.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.translate('available_balance'),
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$currency${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared layout primitives
// ─────────────────────────────────────────────

/// White/surface rounded card with consistent shadow.
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_K.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(_K.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Consistent card header row with title, optional subtitle, and icon.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, this.subtitle, required this.icon});

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        Icon(icon, color: AppColors.primary),
      ],
    );
  }
}

// ── Budgets Card ──────────────────────────────
class _BudgetsCard extends StatelessWidget {
  const _BudgetsCard({
    required this.budgets,
    required this.transactions,
    required this.currency,
  });

  final List<Map<String, dynamic>> budgets;
  final List<Map<String, dynamic>> transactions;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final currentMonthExpenses = transactions.where((tx) {
      if (tx['type'] != 'Expense') return false;
      final dateRaw = tx['date'];
      if (dateRaw == null) return false;

      final DateTime date;
      if (dateRaw is DateTime) {
        date = dateRaw;
      } else if (dateRaw is Timestamp) {
        date = dateRaw.toDate();
      } else {
        date = DateTime.tryParse(dateRaw.toString()) ?? DateTime.now();
      }

      return date.year == now.year && date.month == now.month;
    }).toList();

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: context.translate('active_budgets'),
            subtitle: context.translate('monthly_limit_progress'),
            icon: Icons.track_changes_outlined,
          ),
          const SizedBox(height: 24),
          ...budgets.map((budget) {
            final isGlobal = budget['categoryId'] == null;
            final categoryId = budget['categoryId'];
            final limitAmount =
                (budget['limitAmount'] as num?)?.toDouble() ?? 0.0;
            final displayTitle = isGlobal
                ? context.translate('all_expenses')
                : context.getLocalizedCategory(
                    budget['categoryKey']?.toString(),
                    budget['categoryName'] ?? 'Budget',
                  );

            // Sum current month transactions matching category
            double spent = 0.0;
            for (var tx in currentMonthExpenses) {
              if (isGlobal || tx['category_id'] == categoryId) {
                spent += (tx['amount'] as num?)?.toDouble() ?? 0.0;
              }
            }

            final percent = limitAmount > 0
                ? (spent / limitAmount).clamp(0.0, 1.0)
                : 0.0;
            final isExceeded = spent > limitAmount;

            // Determine status color
            Color progressColor = Colors.green;
            if (spent >= limitAmount) {
              progressColor = Colors.redAccent;
            } else if (spent >= limitAmount * 0.75) {
              progressColor = Colors.amber;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '$currency${spent.toStringAsFixed(0)} / $currency${limitAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isExceeded
                              ? Colors.redAccent
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isExceeded)
                    Text(
                      context
                          .translate('exceeded_by')
                          .replaceAll(
                            '{amount}',
                            '$currency${(spent - limitAmount).toStringAsFixed(0)}',
                          ),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Text(
                      context
                          .translate('remaining_amount')
                          .replaceAll(
                            '{amount}',
                            '$currency${(limitAmount - spent).toStringAsFixed(0)}',
                          ),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
