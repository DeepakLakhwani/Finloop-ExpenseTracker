import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/settings_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import '../services/firestore_service.dart';
import '../services/app_review_service.dart';
import 'add_transaction_screen.dart';
import '../widgets/banner_ad_widget.dart';
import '../services/ad_service.dart';
import '../services/pdf_service.dart';
import 'transactions/widgets/transaction_tile.dart';
import 'transactions/widgets/scratchpad_card.dart';
import '../main.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  static final List<VoidCallback> _onBottomBarTappedCallbacks = [];

  static void onTransactionsTabTapped() {
    for (final cb in _onBottomBarTappedCallbacks) {
      cb();
    }
  }

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _tabs = const [
    'Daily',
    'Weekly',
    'Monthly',
    'Calendar',
    'Notes',
  ];
  String _selectedTab =
      'Daily'; // Daily, Calendar, Weekly, Monthly, Summary, Notes
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedCalendarDay = DateTime.now();
  final Set<int> _expandedWeeks = {};
  final Set<int> _expandedMonths = {};
  Stream<List<Map<String, dynamic>>>? _transactionsStream;
  Stream<DocumentSnapshot>? _scratchpadStream;

  // Search & Filter state
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'All'; // All, Income, Expense, Transfer
  String? _filterAccountId;
  List<Map<String, dynamic>> _userAccounts = [];
  bool _showOnlyStarred = false;
  bool _isAdLoaded = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabs.indexOf(_selectedTab);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
    _tabController.addListener(_handleTabSelection);
    TransactionsScreen._onBottomBarTappedCallbacks.add(_handleBottomBarTap);
    _selectedCalendarDay = DateTime(
      _focusedDate.year,
      _focusedDate.month,
      _focusedDate.day,
    );
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final firestore = context.read<FirestoreService>();
      _transactionsStream = firestore.getTransactions();
      _scratchpadStream = firestore.getScratchpadSnapshot();
      _fetchUserAccounts();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    TransactionsScreen._onBottomBarTappedCallbacks.remove(_handleBottomBarTap);
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!mounted) return;
    if (FocusManager.instance.primaryFocus?.hasFocus ?? false) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    final newTab = _tabs[_tabController.index];
    if (_selectedTab != newTab) {
      setState(() {
        _selectedTab = newTab;
        if (newTab == 'Calendar') {
          final now = DateTime.now();
          _focusedDate = DateTime(now.year, now.month, 1);
          _selectedCalendarDay = DateTime(now.year, now.month, now.day);
        }
      });
    }
  }

  void _handleBottomBarTap() {
    if (mounted) {
      setState(() {
        _selectedTab = 'Daily';
        _focusedDate = DateTime.now();
        _selectedCalendarDay = DateTime(
          _focusedDate.year,
          _focusedDate.month,
          _focusedDate.day,
        );
        _isSearching = false;
        _searchQuery = '';
        _searchController.clear();
        _filterType = 'All';
        _filterAccountId = null;
        _showOnlyStarred = false;
      });
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
      }
    }
  }

  void _fetchUserAccounts() {
    context.read<FirestoreService>().getAccounts().listen((accounts) {
      if (mounted) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _userAccounts = accounts;
            });
          }
        });
      }
    });
  }

  void _adjustPeriod(int offset) {
    setState(() {
      if (_selectedTab == 'Daily' ||
          _selectedTab == 'Calendar' ||
          _selectedTab == 'Summary' ||
          _selectedTab == 'Weekly') {
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month + offset,
          1,
        );
        _selectedCalendarDay = DateTime(
          _focusedDate.year,
          _focusedDate.month,
          1,
        );
      } else if (_selectedTab == 'Monthly') {
        _focusedDate = DateTime(
          _focusedDate.year + offset,
          _focusedDate.month,
          1,
        );
      }
    });
  }

  String _getPeriodLabel() {
    if (_selectedTab == 'Daily' ||
        _selectedTab == 'Calendar' ||
        _selectedTab == 'Summary' ||
        _selectedTab == 'Weekly') {
      return DateFormat('MMM yyyy').format(_focusedDate);
    } else {
      return DateFormat('yyyy').format(_focusedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Initializing secure session...',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactionsStream == null) {
      final firestore = context.read<FirestoreService>();
      _transactionsStream = firestore.getTransactions();
      _scratchpadStream = firestore.getScratchpadSnapshot();
      _fetchUserAccounts();
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Period Selector Banner
                if (_selectedTab != 'Notes') _buildPeriodSelector(),

                // Top Custom Tab Bar
                _buildCustomTabBar(),

                // Transactions Stream & Dynamic Layout Views
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream:
                        _transactionsStream ??
                        context.read<FirestoreService>().getTransactions(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        debugPrint("StreamBuilder error: ${snapshot.error}");
                      }
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final allTransactions = snapshot.data ?? [];

                      return TabBarView(
                        controller: _tabController,
                        children: _tabs.map((tab) {
                          if (tab == 'Notes') {
                            return ScratchpadCard(
                              userId: userId,
                              scratchpadStream: _scratchpadStream,
                            );
                          }

                          final filteredTransactions = _filterTransactions(
                            allTransactions,
                            tab,
                          );
                          final summary = _calculateSummary(
                            filteredTransactions,
                            allTransactions,
                            tab,
                          );

                          return Column(
                            children: [
                              // Overview Summary Row
                              _buildSummaryBanner(summary, currency),

                              // Dynamic View Container
                              Expanded(
                                child:
                                    filteredTransactions.isEmpty &&
                                        tab != 'Calendar'
                                    ? _buildEmptyPlaceholder()
                                    : _buildDynamicView(
                                        tab,
                                        filteredTransactions,
                                        currency,
                                      ),
                              ),
                            ],
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),

                BannerAdWidget(
                  key: const ValueKey('transactions_banner_ad'),
                  onAdLoaded: (loaded) {
                    if (_isAdLoaded != loaded) {
                      setState(() {
                        _isAdLoaded = loaded;
                      });
                    }
                  },
                ),
              ],
            ),

            // Fixed Positioned Plus Button (stays stationary above the ad banner)
            if (_selectedTab != 'Notes')
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                right: 16,
                bottom: _isAdLoaded ? 80 : 16,
                child: FloatingActionButton(
                  heroTag: 'transactionsListFab',
                  shape: const CircleBorder(),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddTransactionScreen(),
                      ),
                    ).then((saved) {
                      if (saved == true) {
                        AdService.showInterstitial(() {
                          AppReviewService.requestInAppReview();
                        });
                      }
                    });
                  },
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Dynamic Layout Views ---

  Widget _buildDynamicView(
    String tab,
    List<Map<String, dynamic>> transactions,
    String currency,
  ) {
    if (tab == 'Daily') {
      return _buildDailyView(transactions, currency);
    } else if (tab == 'Calendar') {
      return _buildCalendarView(transactions, currency);
    } else if (tab == 'Weekly') {
      return _buildWeeklyView(transactions, currency);
    } else if (tab == 'Monthly') {
      return _buildMonthlyView(transactions, currency);
    } else {
      return _buildSummaryView(transactions, currency);
    }
  }

  Widget _buildDailyView(
    List<Map<String, dynamic>> transactions,
    String currency,
  ) {
    // Group transactions by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var tx in transactions) {
      final date = _parseDate(tx['date']);
      final key = DateFormat('yyyy-MM-dd').format(date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final dayTxs = grouped[key]!;
        final date = DateTime.parse(key);

        // Day Summary
        double dayIncome = 0;
        double dayExpense = 0;
        for (var tx in dayTxs) {
          final amt = (double.tryParse(tx['amount'].toString()) ?? 0.0).abs();
          if (tx['type'] == 'Income') {
            dayIncome += amt;
          } else if (tx['type'] == 'Expense') {
            dayExpense += amt;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Section Header
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Column 1: Date Info (under top Income column)
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('EEEE').format(date),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(date),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 1),
                    // Column 2: Income total (under top Expense column)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$currency${context.formatAmount(dayIncome)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 1),
                    // Column 3: Expense total (under top Balance column)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$currency${context.formatAmount(dayExpense)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...dayTxs.asMap().entries.map((entry) {
              final idx = entry.key;
              final tx = entry.value;
              return Column(
                children: [
                  if (idx > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  TransactionTile(transaction: tx, currency: currency),
                ],
              );
            }),
            Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarView(
    List<Map<String, dynamic>> transactions,
    String currency,
  ) {
    // Generate dates for current focused month
    final daysInMonth = DateTime(
      _focusedDate.year,
      _focusedDate.month + 1,
      0,
    ).day;
    final firstDayWeekday = DateTime(
      _focusedDate.year,
      _focusedDate.month,
      1,
    ).weekday;

    final startOnSunday =
        context.read<SettingsProvider>().startDayOfWeek == 'Sunday';
    final int padCount = startOnSunday
        ? (firstDayWeekday % 7)
        : (firstDayWeekday - 1);

    // List of calendar cells
    final List<DateTime?> calendarCells = [];
    // Pad start days
    for (int i = 0; i < padCount; i++) {
      calendarCells.add(null);
    }
    // Fill active days
    for (int i = 1; i <= daysInMonth; i++) {
      calendarCells.add(DateTime(_focusedDate.year, _focusedDate.month, i));
    }

    // Daily indicators
    final Map<int, List<String>> cellIndicators = {};
    for (var tx in transactions) {
      final date = _parseDate(tx['date']);
      if (date.year == _focusedDate.year && date.month == _focusedDate.month) {
        cellIndicators.putIfAbsent(date.day, () => []).add(tx['type']);
      }
    }

    final selectedDayTransactions = transactions.where((tx) {
      final date = _parseDate(tx['date']);
      return date.year == _selectedCalendarDay.year &&
          date.month == _selectedCalendarDay.month &&
          date.day == _selectedCalendarDay.day;
    }).toList();

    final weekdays = startOnSunday
        ? ['S', 'M', 'T', 'W', 'T', 'F', 'S']
        : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Weekday labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays
                .map(
                  (label) => Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.38),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 4),

        // Grid Calendar View
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: calendarCells.length,
            itemBuilder: (context, index) {
              final date = calendarCells[index];
              if (date == null) return const SizedBox.shrink();

              final isSelected =
                  _selectedCalendarDay.year == date.year &&
                  _selectedCalendarDay.month == date.month &&
                  _selectedCalendarDay.day == date.day;

              final indicators = cellIndicators[date.day] ?? [];
              final hasIncome = indicators.contains('Income');
              final hasExpense = indicators.contains('Expense');

              final now = DateTime.now();
              final isToday =
                  now.year == date.year &&
                  now.month == date.month &&
                  now.day == date.day;

              return InkWell(
                onTap: () => setState(() => _selectedCalendarDay = date),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isToday
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Theme.of(context).colorScheme.surface),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? (isToday ? Colors.white : Colors.white30)
                          : (isToday
                                ? AppColors.primary
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.08)),
                      width: isToday || isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isToday
                                    ? AppColors.primary
                                    : Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasIncome)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasIncome && hasExpense) const SizedBox(width: 3),
                          if (hasExpense)
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: Colors.white10),

        // Selected Day Transactions List
        Expanded(
          child: selectedDayTransactions.isEmpty
              ? Center(
                  child: Text(
                    'No entries on this day',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: selectedDayTransactions.length,
                  itemBuilder: (context, idx) {
                    final tx = selectedDayTransactions[idx];
                    return Column(
                      children: [
                        if (idx > 0)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                        TransactionTile(transaction: tx, currency: currency),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWeeklyView(
    List<Map<String, dynamic>> transactions,
    String currency,
  ) {
    // Group transactions by week
    final Map<int, List<Map<String, dynamic>>> grouped = {};
    for (var tx in transactions) {
      final date = _parseDate(tx['date']);
      final weekNum = (date.day / 7).ceil();
      grouped.putIfAbsent(weekNum, () => []).add(tx);
    }

    final sortedWeeks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: sortedWeeks.length,
      itemBuilder: (context, index) {
        final week = sortedWeeks[index];
        final weekTxs = grouped[week]!;
        final isExpanded = _expandedWeeks.contains(week);

        double weekIncome = 0;
        double weekExpense = 0;
        for (var tx in weekTxs) {
          final amt = (double.tryParse(tx['amount'].toString()) ?? 0.0).abs();
          if (tx['type'] == 'Income') weekIncome += amt;
          if (tx['type'] == 'Expense') weekExpense += amt;
        }

        return Column(
          children: [
            if (index > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            // Weekly Section Header
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedWeeks.remove(week);
                    } else {
                      _expandedWeeks.add(week);
                    }
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Column 1: Week Info (under top Income column)
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Week $week',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 1),
                      // Column 2: Income total (under top Expense column)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$currency${context.formatAmount(weekIncome)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 1),
                      // Column 3: Expense total (under top Balance column)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$currency${context.formatAmount(weekExpense)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ...weekTxs.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final tx = entry.value;
                      return Column(
                        children: [
                          if (idx > 0)
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.08),
                            ),
                          TransactionTile(
                            transaction: tx,
                            currency: currency,
                            showDate: true,
                            isNested: true,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMonthlyView(
    List<Map<String, dynamic>> transactions,
    String currency,
  ) {
    // Group transactions by month
    final Map<int, List<Map<String, dynamic>>> grouped = {};
    for (var tx in transactions) {
      final date = _parseDate(tx['date']);
      grouped.putIfAbsent(date.month, () => []).add(tx);
    }

    final sortedMonths = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final month = sortedMonths[index];
        final monthTxs = grouped[month]!;
        final isExpanded = _expandedMonths.contains(month);

        double monthIncome = 0;
        double monthExpense = 0;
        for (var tx in monthTxs) {
          final amt = (double.tryParse(tx['amount'].toString()) ?? 0.0).abs();
          if (tx['type'] == 'Income') monthIncome += amt;
          if (tx['type'] == 'Expense') monthExpense += amt;
        }

        final dummyDate = DateTime(_focusedDate.year, month, 1);

        return Column(
          children: [
            if (index > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            // Monthly Section Header
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedMonths.remove(month);
                    } else {
                      _expandedMonths.add(month);
                    }
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Column 1: Month Info (under top Income column)
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMMM').format(dummyDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 1),
                      // Column 2: Income total (under top Expense column)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$currency${context.formatAmount(monthIncome)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 1),
                      // Column 3: Expense total (under top Balance column)
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$currency${context.formatAmount(monthExpense)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ...monthTxs.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final tx = entry.value;
                      return Column(
                        children: [
                          if (idx > 0)
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.08),
                            ),
                          TransactionTile(
                            transaction: tx,
                            currency: currency,
                            showDate: true,
                            isNested: true,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryView(
    List<Map<String, dynamic>> transactions,
    String currency,
  ) {
    // Category Breakdown for expenses
    final Map<String, double> categorySums = {};
    double totalExpense = 0;

    for (var tx in transactions) {
      if (tx['type'] == 'Expense') {
        final amt = double.tryParse(tx['amount'].toString()) ?? 0.0;
        final cat = tx['category_name'] ?? 'General';
        categorySums[cat] = (categorySums[cat] ?? 0.0) + amt;
        totalExpense += amt;
      }
    }

    final categoryList = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Expense Category Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '$currency${totalExpense.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categoryList.length,
            itemBuilder: (context, index) {
              final entry = categoryList[index];
              final percent = totalExpense > 0
                  ? (entry.value / totalExpense)
                  : 0.0;
              final catColor = _getCategoryColor(entry.key);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(percent * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$currency${entry.value.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(catColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('shopping') || n.contains('shop')) return Colors.purple;
    if (n.contains('house') || n.contains('rent')) return Colors.teal;
    if (n.contains('grocery')) return Colors.red;
    if (n.contains('salary')) return Colors.green;
    return Colors.amber;
  }

  // --- Subcomponents & Helpers ---

  Widget _buildCustomTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          bottom: BorderSide(
            color: Color.fromARGB(20, 167, 163, 163),
            width: 1.0,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.primary,
        unselectedLabelColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
        ),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicatorWeight: 2.5,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 20),
        tabs: _tabs.map((tab) {
          final String label;
          switch (tab) {
            case 'Daily':
              label = context.translate('daily');
              break;
            case 'Weekly':
              label = context.translate('weekly');
              break;
            case 'Monthly':
              label = context.translate('monthly');
              break;
            case 'Calendar':
              label = context.translate('calendar');
              break;
            case 'Notes':
              label = context.translate('notes');
              break;
            default:
              label = tab;
          }
          return Tab(text: label);
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    if (_isSearching) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: const Border(
            bottom: BorderSide(color: Colors.white24, width: 1.0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: context.translate('hint_search_transactions'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                });
              },
              child: Text(
                context.translate('cancel'),
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasActiveFilters = _filterType != 'All' || _filterAccountId != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          bottom: BorderSide(color: Colors.white24, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          Text(
            _getPeriodLabel(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _adjustPeriod(-1),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_left,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => _adjustPeriod(1),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                Icons.chevron_right,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _showOnlyStarred ? Icons.star : Icons.star_border_outlined,
              color: _showOnlyStarred
                  ? Colors.amber
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: () {
              setState(() {
                _showOnlyStarred = !_showOnlyStarred;
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.filter_list_rounded,
                  color: hasActiveFilters
                      ? AppColors.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                onPressed: _showFilterBottomSheet,
              ),
              if (hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.print_outlined,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: _showPrintPdfDialog,
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    String localType = _filterType;
    String? localAccountId = _filterAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.translate('filter_transactions'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setBottomSheetState(() {
                            localType = 'All';
                            localAccountId = null;
                          });
                        },
                        child: Text(context.translate('btn_reset_all')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    context.translate('transaction_type'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'Income', 'Expense', 'Transfer'].map((
                      type,
                    ) {
                      final isSelected = localType == type;
                      return ChoiceChip(
                        label: Text(
                          type == 'All'
                              ? context.translate('all')
                              : type == 'Income'
                              ? context.translate('income')
                              : type == 'Expense'
                              ? context.translate('expense')
                              : context.translate('transfer'),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        backgroundColor: Colors.transparent,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.12),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setBottomSheetState(() {
                              localType = type;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    context.translate('filter_by_account'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _userAccounts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            context.translate('msg_no_accounts_in_category'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(
                                context.translate('filter_all_accounts'),
                              ),
                              selected: localAccountId == null,
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.2,
                              ),
                              backgroundColor: Colors.transparent,
                              labelStyle: TextStyle(
                                color: localAccountId == null
                                    ? AppColors.primary
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                fontWeight: localAccountId == null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: localAccountId == null
                                    ? AppColors.primary
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.12),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setBottomSheetState(() {
                                    localAccountId = null;
                                  });
                                }
                              },
                            ),
                            ..._userAccounts.map((acc) {
                              final accId = acc['id']?.toString();
                              final isSelected = localAccountId == accId;
                              return ChoiceChip(
                                label: Text(
                                  context.getLocalizedAccountName(acc['name']),
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                backgroundColor: Colors.transparent,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Theme.of(context).colorScheme.onSurface
                                            .withValues(alpha: 0.12),
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setBottomSheetState(() {
                                      localAccountId = accId;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ],
                        ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filterType = 'All';
                              _filterAccountId = null;
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            context.translate('btn_clear'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (localType != 'All' || localAccountId != null) {
                              _checkAndUnlockFilters(
                                context,
                                onUnlocked: () {
                                  setState(() {
                                    _filterType = localType;
                                    _filterAccountId = localAccountId;
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            } else {
                              setState(() {
                                _filterType = 'All';
                                _filterAccountId = null;
                              });
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            context.translate('btn_apply'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _checkAndUnlockFilters(
    BuildContext context, {
    required VoidCallback onUnlocked,
    VoidCallback? onCancelled,
  }) async {
    if (!AdService.adsEnabled) {
      onUnlocked();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final unlockUntil = prefs.getInt('filters_unlocked_until') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now < unlockUntil) {
      onUnlocked();
      return;
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              context.translate('title_unlock_filters'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          context.translate('desc_unlock_filters'),
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (onCancelled != null) onCancelled();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(
                    context.translate('cancel'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _playRewardedAdThenUnlock(
                      context,
                      onUnlocked: onUnlocked,
                      onCancelled: onCancelled,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(
                    context.translate('btn_watch_unlock'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _playRewardedAdThenUnlock(
    BuildContext context, {
    required VoidCallback onUnlocked,
    VoidCallback? onCancelled,
  }) {
    showTopNotification(context.translate('msg_ad_preparing'));

    AdService.showRewarded(
      onRewardEarned: () async {
        final prefs = await SharedPreferences.getInstance();
        final newUnlockTime = DateTime.now()
            .add(const Duration(hours: 24))
            .millisecondsSinceEpoch;
        await prefs.setInt('filters_unlocked_until', newUnlockTime);
        showTopNotification(context.translate('msg_unlock_success'));
        onUnlocked();
      },
      onAdClosed: () {
        showTopNotification(
          context.translate('err_ad_unwatched'),
          isError: true,
        );
        if (onCancelled != null) onCancelled();
      },
      onAdFailed: () async {
        // Fallback reward if ad failed to show
        final prefs = await SharedPreferences.getInstance();
        final newUnlockTime = DateTime.now()
            .add(const Duration(hours: 24))
            .millisecondsSinceEpoch;
        await prefs.setInt('filters_unlocked_until', newUnlockTime);
        onUnlocked();
      },
    );
  }

  Widget _buildSummaryBanner(Map<String, double> summary, String currency) {
    final income = summary['Income'] ?? 0.0;
    final expense = summary['Expense'] ?? 0.0;
    final balance = summary['Balance'] ?? (income - expense);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          bottom: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryColumn(
              context.translate('income'),
              income,
              Colors.green,
              currency,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _buildSummaryColumn(
              context.translate('expense'),
              expense,
              Colors.red,
              currency,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.12),
          ),
          Expanded(
            child: _buildSummaryColumn(
              context.translate('balance'),
              balance.abs(),
              balance >= 0
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.red,
              currency,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(
    String label,
    double val,
    Color valColor,
    String currency,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$currency${context.formatAmount(val)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              context.translate('title_no_entries_period'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.translate('desc_no_entries_period'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Calculations & Filters ---

  List<Map<String, dynamic>> _filterTransactions(
    List<Map<String, dynamic>> all,
    String tab,
  ) {
    var list = all.where((tx) {
      final date = _parseDate(tx['date']);
      if (tab == 'Daily' ||
          tab == 'Calendar' ||
          tab == 'Summary' ||
          tab == 'Weekly') {
        return context.read<SettingsProvider>().isDateInFocusedMonth(
          date,
          _focusedDate,
        );
      } else {
        return date.year == _focusedDate.year;
      }
    }).toList();

    // Starred filter
    if (_showOnlyStarred) {
      list = list
          .where((tx) => tx['is_starred'] == true || tx['isStarred'] == true)
          .toList();
    }

    // 2. Search filter
    if (_isSearching && _searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((tx) {
        final cat = (tx['category_name'] ?? '').toString().toLowerCase();
        final note = (tx['notes'] ?? '').toString().toLowerCase();
        final amt = (tx['amount'] ?? '').toString().toLowerCase();
        return cat.contains(query) ||
            note.contains(query) ||
            amt.contains(query);
      }).toList();
    }

    // 3. Filter by type
    if (_filterType != 'All') {
      list = list.where((tx) => tx['type'] == _filterType).toList();
    }

    // 4. Filter by account
    if (_filterAccountId != null) {
      list = list.where((tx) {
        final fromAccId =
            tx['account_id']?.toString() ?? tx['accountId']?.toString();
        final toAccId =
            tx['to_account_id']?.toString() ?? tx['toAccountId']?.toString();
        return fromAccId == _filterAccountId || toAccId == _filterAccountId;
      }).toList();
    }

    return list;
  }

  Map<String, double> _calculateSummary(
    List<Map<String, dynamic>> filtered,
    List<Map<String, dynamic>> all,
    String tab,
  ) {
    // 1. Calculate periodic income and expense from filtered list
    double income = 0;
    double expense = 0;
    for (var tx in filtered) {
      final amt = double.tryParse(tx['amount'].toString()) ?? 0.0;
      if (tx['type'] == 'Income') {
        income += amt;
      } else if (tx['type'] == 'Expense') {
        expense += amt;
      }
    }

    // 2. Calculate cumulative balance up to the end of the current period (excluding credit cards)
    DateTime endOfPeriod;
    if (tab == 'Daily' ||
        tab == 'Calendar' ||
        tab == 'Summary' ||
        tab == 'Weekly') {
      endOfPeriod = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
    } else {
      // Monthly tab (shows year)
      endOfPeriod = DateTime(_focusedDate.year + 1, 1, 1);
    }

    final creditCardIds = _userAccounts
        .where((acc) => acc['type'] == 'Credit Card' || acc['type'] == 'Card')
        .map((acc) => acc['id']?.toString())
        .whereType<String>()
        .toSet();

    double cumulativeBalance = 0.0;
    for (var tx in all) {
      final date = _parseDate(tx['date']);
      if (date.isBefore(endOfPeriod)) {
        final amt = double.tryParse(tx['amount'].toString()) ?? 0.0;
        final txType = tx['type']?.toString();
        final fromAccId =
            tx['account_id']?.toString() ?? tx['accountId']?.toString();
        final toAccId =
            tx['to_account_id']?.toString() ?? tx['toAccountId']?.toString();

        final isFromCreditCard = creditCardIds.contains(fromAccId);
        final isToCreditCard = creditCardIds.contains(toAccId);

        if (txType == 'Income') {
          if (!isFromCreditCard) {
            cumulativeBalance += amt;
          }
        } else if (txType == 'Expense') {
          if (!isFromCreditCard) {
            cumulativeBalance -= amt;
          }
        } else if (txType == 'Transfer') {
          // Transfer from Cash/Bank to Credit Card (spending/payment) decreases Cash/Bank balance
          if (!isFromCreditCard && isToCreditCard) {
            cumulativeBalance -= amt;
          }
          // Transfer from Credit Card to Cash/Bank (advance) increases Cash/Bank balance
          else if (isFromCreditCard && !isToCreditCard) {
            cumulativeBalance += amt;
          }
        }
      }
    }

    return {'Income': income, 'Expense': expense, 'Balance': cumulativeBalance};
  }

  DateTime _parseDate(dynamic dateVal) {
    if (dateVal is DateTime) return dateVal;
    if (dateVal is String) return DateTime.parse(dateVal);
    try {
      return dateVal.toDate();
    } catch (_) {
      return DateTime.now();
    }
  }

  void _showPrintPdfDialog() {
    final uniqueAccounts = <String, Map<String, dynamic>>{};
    for (var acc in _userAccounts) {
      final id = acc['id']?.toString();
      if (id != null && id.isNotEmpty) {
        uniqueAccounts[id] = acc;
      }
    }

    final bool hasAccount = uniqueAccounts.containsKey(_filterAccountId);
    String? localSelectedAccountId = hasAccount ? _filterAccountId : null;
    DateTime localStartDate = DateTime(
      _focusedDate.year,
      _focusedDate.month,
      1,
    );
    DateTime localEndDate = DateTime(
      _focusedDate.year,
      _focusedDate.month + 1,
      0,
    );
    bool localIncludeSummary = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            final cs = Theme.of(dialogContext).colorScheme;
            final isDark =
                Theme.of(dialogContext).brightness == Brightness.dark;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.05,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Header Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: cs.onSurface.withValues(alpha: 0.7),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.translate('title_export_pdf_statement'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.translate('desc_export_pdf_statement'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: cs.onSurface.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 20),

                    // Select Account label
                    Text(
                      context.translate('select_account'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dropdown
                    DropdownButtonFormField<String?>(
                      initialValue: localSelectedAccountId,
                      isExpanded: true,
                      dropdownColor: cs.surface,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF161817)
                            : const Color(0xFFF3F4F6),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: cs.onSurface.withValues(
                              alpha: isDark ? 0.08 : 0.06,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            context.translate('all_accounts'),
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ...uniqueAccounts.values.map((acc) {
                          return DropdownMenuItem<String?>(
                            value: acc['id'].toString(),
                            child: Text(
                              acc['name']?.toString() ?? '',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          localSelectedAccountId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    // Date pickers row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.translate('label_start_date'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: localStartDate,
                                    firstDate: DateTime(1970),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      localStartDate = picked;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF161817)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cs.onSurface.withValues(
                                        alpha: isDark ? 0.08 : 0.06,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(localStartDate),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.translate('label_end_date'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: dialogContext,
                                    initialDate: localEndDate,
                                    firstDate: DateTime(1970),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      localEndDate = picked;
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF161817)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: cs.onSurface.withValues(
                                        alpha: isDark ? 0.08 : 0.06,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(localEndDate),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Include period summary row (tappable)
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          localIncludeSummary = !localIncludeSummary;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: localIncludeSummary,
                                activeColor: AppColors.primary,
                                checkColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (val) {
                                  setDialogState(() {
                                    localIncludeSummary = val ?? true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.translate(
                                      'label_include_period_summary',
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (localIncludeSummary)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        context.translate(
                                          'desc_include_period_summary',
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.4,
                                          color: cs.onSurface.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(
                                  color: cs.onSurface.withValues(alpha: 0.12),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                context.translate('cancel'),
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _playRewardedAdThenGeneratePdf(
                                  localSelectedAccountId,
                                  localStartDate,
                                  localEndDate,
                                  localIncludeSummary,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                elevation: 3,
                                shadowColor: AppColors.primary.withValues(
                                  alpha: 0.3,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                context.translate('btn_generate'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _playRewardedAdThenGeneratePdf(
    String? accountId,
    DateTime start,
    DateTime end,
    bool includeSummary,
  ) {
    showTopNotification(context.translate('msg_ad_preparing'));

    bool rewardGranted = false;

    AdService.showRewarded(
      onRewardEarned: () {
        rewardGranted = true;
        showTopNotification(context.translate('msg_export_compiling'));
        _generatePdf(accountId, start, end, includeSummary);
      },
      onAdClosed: () {
        if (!rewardGranted) {
          showTopNotification(
            context.translate('err_ad_unwatched'),
            isError: true,
          );
        }
      },
      onAdFailed: () {
        showTopNotification(context.translate('msg_ad_failed_fallback'));
        _generatePdf(accountId, start, end, includeSummary);
      },
    );
  }

  Future<void> _generatePdf(
    String? accountId,
    DateTime start,
    DateTime end,
    bool includeSummary,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );

    try {
      final firestore = context.read<FirestoreService>();
      final allTxs = await firestore.getTransactionsList();

      final inclusiveEnd = DateTime(
        end.year,
        end.month,
        end.day,
        23,
        59,
        59,
        999,
      );

      final filtered = allTxs.where((tx) {
        final rawDate = tx['date'];
        DateTime? date;
        if (rawDate is DateTime) {
          date = rawDate;
        } else if (rawDate is Timestamp) {
          date = rawDate.toDate();
        } else if (rawDate is String) {
          date = DateTime.tryParse(rawDate);
        }

        if (date == null) return false;
        if (date.isBefore(start) || date.isAfter(inclusiveEnd)) return false;

        if (accountId != null) {
          final fromId =
              tx['account_id']?.toString() ?? tx['accountId']?.toString();
          final toId =
              tx['to_account_id']?.toString() ?? tx['toAccountId']?.toString();
          return fromId == accountId || toId == accountId;
        }
        return true;
      }).toList();

      filtered.sort((a, b) {
        DateTime dateA;
        if (a['date'] is Timestamp) {
          dateA = (a['date'] as Timestamp).toDate();
        } else if (a['date'] is DateTime) {
          dateA = a['date'] as DateTime;
        } else {
          dateA =
              DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
        }

        DateTime dateB;
        if (b['date'] is Timestamp) {
          dateB = (b['date'] as Timestamp).toDate();
        } else if (b['date'] is DateTime) {
          dateB = b['date'] as DateTime;
        } else {
          dateB =
              DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
        }

        return dateA.compareTo(dateB);
      });

      String accountName = 'All Accounts';
      if (accountId != null) {
        final matched = _userAccounts.firstWhere(
          (acc) => acc['id']?.toString() == accountId,
          orElse: () => {},
        );
        if (matched.isNotEmpty) {
          accountName = matched['name']?.toString() ?? 'Account';
        }
      }

      if (context.mounted) Navigator.pop(context);

      if (filtered.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No transactions found for the selected criteria'),
            ),
          );
        }
        return;
      }

      final settingsProvider = context.read<SettingsProvider>();
      final currencySymbol = settingsProvider.currency;

      await PdfService.generateAndPrintStatement(
        transactions: filtered,
        accountName: accountName,
        startDate: start,
        endDate: end,
        currencySymbol: currencySymbol,
        includeSummary: includeSummary,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint('Error generating PDF: $e');
    }
  }
}
