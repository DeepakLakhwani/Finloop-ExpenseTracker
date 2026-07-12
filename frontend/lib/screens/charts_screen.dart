import 'dart:async';

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
  static const double chartHeight = 200;

  static final List<Color> palette = [
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
  StreamSubscription<List<Map<String, dynamic>>>? _catSub;

  int _touchedIndex = -1;
  int _selectedTab = 1; // 0 = Income, 1 = Expense
  bool _isLoading = true;
  bool _hasError = false;

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _userAccounts = [];
  List<Map<String, dynamic>> _allBudgets = [];
  List<Map<String, dynamic>> _userCategories = [];

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
    _catSub?.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────
  void _subscribeToData() {
    final firestore = context.read<FirestoreService>();

    // Subscribe to streams independently so none leak
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

    _catSub = firestore.getCategories().listen((catList) {
      if (!mounted) return;
      setState(() => _userCategories = catList);
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
      userCategories: _userCategories,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(month: DateTime.now(), isIncome: _selectedTab == 0),
            const SizedBox(height: 16),

            // Simple Tab Selector (Income Left, Expense Right, no background color)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedTab != 0) {
                          setState(() {
                            _selectedTab = 0;
                            _touchedIndex = -1;
                          });
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              context.translate('income'),
                              style: TextStyle(
                                color: _selectedTab == 0
                                    ? AppColors.primary
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                fontWeight: _selectedTab == 0
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 2.5,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _selectedTab == 0
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_selectedTab != 1) {
                          setState(() {
                            _selectedTab = 1;
                            _touchedIndex = -1;
                          });
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              context.translate('expense'),
                              style: TextStyle(
                                color: _selectedTab == 1
                                    ? AppColors.primary
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                fontWeight: _selectedTab == 1
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 2.5,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _selectedTab == 1
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedTab == 0) ...[
              // Income Analytics
              _DistributionCard(
                pieData: analytics.incomePieData,
                totalExpenses: analytics.totalCurrentMonthIncome,
                currency: currency,
                touchedIndex: _touchedIndex,
                onTouch: (i) => setState(() => _touchedIndex = i),
                categories: _userCategories,
                isIncome: true,
              ),
              const SizedBox(height: 12),
              _MonthlyTrendsCard(
                months: analytics.trendMonths,
                dataValues: analytics.monthlyIncome,
                maxY: analytics.incomeMaxY,
                currency: currency,
                formatY: _formatY,
                isIncome: true,
              ),
              const SizedBox(height: 12),
              _AvailableBudgetCard(
                balance: analytics.totalBalance,
                currency: currency,
              ),
            ] else ...[
              // Expense Analytics
              _DistributionCard(
                pieData: analytics.pieData,
                totalExpenses: analytics.totalCurrentMonthExpenses,
                currency: currency,
                touchedIndex: _touchedIndex,
                onTouch: (i) => setState(() => _touchedIndex = i),
                categories: _userCategories,
                isIncome: false,
              ),
              const SizedBox(height: 12),
              if (_allBudgets.isNotEmpty) ...[
                _BudgetsCard(
                  budgets: _allBudgets,
                  transactions: _allTransactions,
                  currency: currency,
                  categories: _userCategories,
                ),
                const SizedBox(height: 12),
              ],
              _MonthlyTrendsCard(
                months: analytics.trendMonths,
                dataValues: analytics.monthlyExpenses,
                maxY: analytics.maxY,
                currency: currency,
                formatY: _formatY,
                isIncome: false,
              ),
              const SizedBox(height: 12),
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
            ],
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
  const _Header({required this.month, required this.isIncome});
  final DateTime month;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final langProvider = context.watch<LanguageProvider>();
    final localizedMonth = DateFormat(
      'MMMM',
      langProvider.languageCode,
    ).format(month);
    final subtitle = context
        .translate(isIncome ? 'income_intelligence' : 'spending_intelligence')
        .replaceAll('{month}', localizedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: color.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────
Color _parseHexColor(String? hex, Color fallbackColor) {
  if (hex == null || !hex.startsWith('#')) return fallbackColor;
  try {
    return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
  } catch (_) {
    return fallbackColor;
  }
}

IconData _getCategoryIcon(String? iconName) {
  switch (iconName) {
    case 'work':
      return Icons.work_outline;
    case 'payments':
      return Icons.payments_outlined;
    case 'card_giftcard':
      return Icons.card_giftcard_outlined;
    case 'stars':
      return Icons.stars_outlined;
    case 'account_balance_wallet':
      return Icons.account_balance_wallet_outlined;
    case 'home':
      return Icons.home_outlined;
    case 'restaurant':
      return Icons.restaurant_outlined;
    case 'directions_car':
      return Icons.directions_car_outlined;
    case 'shopping_bag':
      return Icons.shopping_bag_outlined;
    case 'movie':
      return Icons.movie_outlined;
    case 'medical_services':
      return Icons.medical_services_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'credit_card':
      return Icons.credit_card_outlined;
    case 'people':
      return Icons.people_outline;
    case 'flight':
      return Icons.flight_outlined;
    case 'pets':
      return Icons.pets_outlined;
    case 'sports_esports':
      return Icons.sports_esports_outlined;
    case 'fitness_center':
      return Icons.fitness_center_outlined;
    case 'local_cafe':
      return Icons.local_cafe_outlined;
    case 'build':
      return Icons.build_outlined;
    case 'swap_horiz':
      return Icons.swap_horiz;
    default:
      return Icons.category_outlined;
  }
}

// ── Financial Distribution ────────────────────
class _DistributionCard extends StatefulWidget {
  const _DistributionCard({
    required this.pieData,
    required this.totalExpenses,
    required this.currency,
    required this.touchedIndex,
    required this.onTouch,
    required this.categories,
    required this.isIncome,
  });

  final List<MapEntry<String, double>> pieData;
  final double totalExpenses;
  final String currency;
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  final List<Map<String, dynamic>> categories;
  final bool isIncome;

  @override
  State<_DistributionCard> createState() => _DistributionCardState();
}

class _DistributionCardState extends State<_DistributionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.totalExpenses <= 0)
      return _EmptyDistributionCard(isIncome: widget.isIncome);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final parts = widget.pieData.first.key.split('::');
    final topKey = parts[0];
    final topFallback = parts.length > 1 ? parts[1] : '';
    final topCategory = widget.pieData.first.key == 'Others'
        ? context.translate('others')
        : context.getLocalizedCategory(topKey, topFallback);
    final topPct = (widget.pieData.first.value / widget.totalExpenses * 100)
        .toStringAsFixed(0);

    // Build the dynamic center widget based on the active touch selection
    Widget centerWidget;
    if (widget.touchedIndex >= 0 &&
        widget.touchedIndex < widget.pieData.length) {
      final entry = widget.pieData[widget.touchedIndex];
      final parts = entry.key.split('::');
      final key = parts[0];
      final fallback = parts.length > 1 ? parts[1] : '';
      final label = entry.key == 'Others'
          ? context.translate('others')
          : context.getLocalizedCategory(key, fallback);
      final value = entry.value;
      final percent = widget.totalExpenses > 0
          ? (value / widget.totalExpenses * 100)
          : 0.0;

      final matchedCat = widget.categories.firstWhere(
        (c) => (key.isNotEmpty && c['key'] == key) || c['name'] == fallback,
        orElse: () => <String, dynamic>{},
      );
      final catColor = _parseHexColor(
        matchedCat['color'],
        _K.palette[widget.touchedIndex % _K.palette.length],
      );

      centerWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.currency}${context.formatAmount(value)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: catColor,
              ),
            ),
          ],
        ),
      );
    } else {
      centerWidget = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.translate(widget.isIncome ? 'total_income' : 'total_spent'),
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.currency}${context.formatAmount(widget.totalExpenses)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.translate(widget.isIncome ? 'income' : 'all_expenses'),
            style: TextStyle(
              fontSize: 9,
              color: onSurface.withValues(alpha: 0.35),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    const limit = 3;
    final hasMore = widget.pieData.length > limit;
    final displayedCount = (_isExpanded || !hasMore)
        ? widget.pieData.length
        : limit;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: context.translate(
              widget.isIncome ? 'income_distribution' : 'expense_distribution',
            ),
            subtitle: context
                .translate('top_category_pct')
                .replaceAll('{category}', topCategory)
                .replaceAll('{pct}', topPct),
            icon: Icons.pie_chart_outline,
          ),
          const SizedBox(height: 24),

          // Donut Chart Box
          Center(
            child: SizedBox(
              height: 180,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
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
                          widget.onTouch(idx);
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 4,
                      centerSpaceRadius: 62,
                      sections: List.generate(widget.pieData.length, (i) {
                        final isTouched = i == widget.touchedIndex;
                        final entry = widget.pieData[i];
                        final parts = entry.key.split('::');
                        final key = parts[0];
                        final fallback = parts.length > 1 ? parts[1] : '';

                        final matchedCat = widget.categories.firstWhere(
                          (c) =>
                              (key.isNotEmpty && c['key'] == key) ||
                              c['name'] == fallback,
                          orElse: () => <String, dynamic>{},
                        );
                        final catColor = _parseHexColor(
                          matchedCat['color'],
                          _K.palette[i % _K.palette.length],
                        );

                        return PieChartSectionData(
                          color: catColor,
                          value: entry.value,
                          showTitle: false,
                          radius: isTouched ? 22 : 16,
                        );
                      }),
                    ),
                  ),
                  centerWidget,
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Vertical Legend & Progress List
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedCount,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = widget.pieData[i];
                final parts = entry.key.split('::');
                final key = parts[0];
                final fallback = parts.length > 1 ? parts[1] : '';
                final label = entry.key == 'Others'
                    ? context.translate('others')
                    : context.getLocalizedCategory(key, fallback);
                final value = entry.value;
                final percent = widget.totalExpenses > 0
                    ? (value / widget.totalExpenses)
                    : 0.0;

                final matchedCat = widget.categories.firstWhere(
                  (c) =>
                      (key.isNotEmpty && c['key'] == key) ||
                      c['name'] == fallback,
                  orElse: () => <String, dynamic>{},
                );
                final catColor = _parseHexColor(
                  matchedCat['color'],
                  _K.palette[i % _K.palette.length],
                );
                final catIcon = _getCategoryIcon(matchedCat['icon']);
                final isSelected = i == widget.touchedIndex;

                return InkWell(
                  onTap: () {
                    if (isSelected) {
                      widget.onTouch(-1);
                    } else {
                      widget.onTouch(i);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withValues(alpha: 0.08)
                          : (isDark ? theme.colorScheme.surface : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? catColor.withValues(alpha: 0.4)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.04),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Category Icon Box
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(catIcon, color: catColor, size: 18),
                        ),
                        const SizedBox(width: 12),

                        // Name and Progress Indicator
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${(percent * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? catColor
                                          : onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: percent,
                                  minHeight: 5,
                                  backgroundColor:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.03),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    catColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Value/Amount
                        Text(
                          '${widget.currency}${context.formatAmount(value)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (hasMore) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isExpanded
                          ? context.translate('show_less')
                          : '${context.translate('show_more')} (+${widget.pieData.length - limit})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyDistributionCard extends StatelessWidget {
  const _EmptyDistributionCard({required this.isIncome});
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return _SurfaceCard(
      child: Column(
        children: [
          _CardHeader(
            title: context.translate(
              isIncome ? 'income_distribution' : 'expense_distribution',
            ),
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
            context.translate(
              isIncome ? 'no_income_this_month' : 'no_expense_this_month',
            ),
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

// ── Monthly Trends (Area Gradient Chart) ──────
class _MonthlyTrendsCard extends StatefulWidget {
  const _MonthlyTrendsCard({
    required this.months,
    required this.dataValues,
    required this.maxY,
    required this.currency,
    required this.formatY,
    required this.isIncome,
  });

  final List<DateTime> months;
  final List<double> dataValues;
  final double maxY;
  final String currency;
  final String Function(double) formatY;
  final bool isIncome;

  @override
  State<_MonthlyTrendsCard> createState() => _MonthlyTrendsCardState();
}

class _MonthlyTrendsCardState extends State<_MonthlyTrendsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _drawAnimation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _drawAnimation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    // Start the draw-in animation
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    final langProvider = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate month-over-month change for subtitle
    final hasMultiple = widget.dataValues.length >= 2;
    String? changeText;
    if (hasMultiple) {
      final prev = widget.dataValues[widget.dataValues.length - 2];
      final curr = widget.dataValues[widget.dataValues.length - 1];
      if (prev > 0) {
        final pctChange = ((curr - prev) / prev * 100).abs();
        final arrow = curr <= prev ? '↓' : '↑';
        changeText =
            '$arrow ${pctChange.toStringAsFixed(0)}% vs ${DateFormat('MMM', langProvider.languageCode).format(widget.months[widget.months.length - 2])}';
      }
    }

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: context.translate(
              widget.isIncome
                  ? 'monthly_income_trends'
                  : 'monthly_spending_trends',
            ),
            subtitle: changeText,
            icon: Icons.show_chart_rounded,
          ),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: _drawAnimation,
            builder: (context, _) {
              // Animate the Y values from 0 → actual value
              final animatedExpenses = widget.dataValues
                  .map((e) => e * _drawAnimation.value)
                  .toList();
              final animatedMaxY =
                  widget.maxY * _drawAnimation.value.clamp(0.3, 1.0);

              return SizedBox(
                height: _K.chartHeight + 20,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: animatedMaxY < 10 ? 100 : animatedMaxY,
                    clipData: const FlClipData.all(),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        showOnTopOfTheChartBoxArea: true,
                        getTooltipColor: (_) =>
                            isDark ? const Color(0xFF2A2A2A) : surface,
                        tooltipBorder: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        tooltipMargin: 16,
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            final idx = spot.spotIndex;
                            final label = DateFormat(
                              'MMMM yyyy',
                              langProvider.languageCode,
                            ).format(widget.months[idx]);
                            return LineTooltipItem(
                              '$label\n',
                              TextStyle(
                                color: onSurface.withValues(alpha: 0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${widget.currency}${context.formatAmount(widget.dataValues[idx], listen: false)}',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                      getTouchedSpotIndicator: (data, indices) {
                        return indices.map((idx) {
                          return TouchedSpotIndicatorData(
                            // Vertical dashed indicator line
                            FlLine(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              strokeWidth: 1.5,
                              dashArray: [6, 4],
                            ),
                            // Glowing dot at touch point
                            FlDotData(
                              show: true,
                              getDotPainter: (spot, pct, bar, idx) {
                                return FlDotCirclePainter(
                                  radius: 7,
                                  color: AppColors.primary,
                                  strokeWidth: 2.5,
                                  strokeColor: surface,
                                );
                              },
                            ),
                          );
                        }).toList();
                      },
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= widget.months.length) {
                              return const SizedBox.shrink();
                            }
                            final isCurrentMonth =
                                i == widget.months.length - 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                DateFormat(
                                  'MMM',
                                  langProvider.languageCode,
                                ).format(widget.months[i]),
                                style: TextStyle(
                                  color: isCurrentMonth
                                      ? AppColors.primary
                                      : onSurface.withValues(alpha: 0.45),
                                  fontWeight: isCurrentMonth
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max || value == meta.min) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                widget.formatY(value),
                                style: TextStyle(
                                  color: onSurface.withValues(alpha: 0.35),
                                  fontWeight: FontWeight.w600,
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
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: animatedMaxY > 0
                          ? animatedMaxY / 4
                          : 25,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: onSurface.withValues(alpha: 0.05),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          widget.months.length,
                          (i) => FlSpot(i.toDouble(), animatedExpenses[i]),
                        ),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        preventCurveOverShooting: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        isStrokeJoinRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, pct, bar, idx) {
                            final isCurrentMonth =
                                idx == widget.months.length - 1;
                            if (isCurrentMonth) {
                              // Glowing larger dot for current month
                              return FlDotCirclePainter(
                                radius: 5.5,
                                color: AppColors.primary,
                                strokeWidth: 3,
                                strokeColor: surface,
                              );
                            }
                            // Subtle dots for past months
                            return FlDotCirclePainter(
                              radius: 3.5,
                              color: surface,
                              strokeWidth: 2,
                              strokeColor: AppColors.primary.withValues(
                                alpha: 0.6,
                              ),
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(
                                alpha: isDark ? 0.25 : 0.20,
                              ),
                              AppColors.primary.withValues(
                                alpha: isDark ? 0.08 : 0.05,
                              ),
                              AppColors.primary.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                        shadow: Shadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                context.translate('last_6_months'),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Smart Insight ─────────────────────────────
class _SmartInsightCard extends StatelessWidget {
  const _SmartInsightCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                context.translate('smart_insight'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: onSurface.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.45,
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
    return _SurfaceCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              size: 24,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$currency${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
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
    return Padding(padding: const EdgeInsets.only(bottom: 32), child: child);
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
    required this.categories,
  });

  final List<Map<String, dynamic>> budgets;
  final List<Map<String, dynamic>> transactions;
  final String currency;
  final List<Map<String, dynamic>> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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

      return context.read<SettingsProvider>().isDateInFocusedMonth(date, now);
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

            // Category configuration lookup
            Color catColor = AppColors.primary;
            IconData catIcon = Icons.track_changes_outlined;
            if (!isGlobal) {
              final matchedCat = categories.firstWhere(
                (c) => c['id'] == categoryId,
                orElse: () => <String, dynamic>{},
              );
              if (matchedCat.isNotEmpty) {
                catColor = _parseHexColor(
                  matchedCat['color'],
                  AppColors.primary,
                );
                catIcon = _getCategoryIcon(matchedCat['icon']);
              }
            } else {
              catIcon = Icons.all_inclusive_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon Badge
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(catIcon, color: catColor, size: 18),
                      ),
                      const SizedBox(width: 12),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Spent / Limit values
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currency${spent.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isExceeded
                                  ? Colors.redAccent
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'of $currency${limitAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      minHeight: 6,
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
