import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../providers/language_provider.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import 'charts_screen.dart';
import 'manage_accounts_screen.dart';
import 'add_account_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Defer context-dependent calls until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndFetch());
  }

  Future<void> _initAndFetch() async {
    if (!mounted) return;
    final firestore = context.read<FirestoreService>();
    await firestore.initializeUser();

    // One-time cleanup of previously seeded dummy data
    try {
      final hasCleaned = await firestore.hasCleanedDummyData();
      if (!hasCleaned) {
        await firestore.cleanupDummyData();
        await firestore.setHasCleanedDummyData();
      }
    } catch (e) {
      debugPrint("Error cleaning dummy data: $e");
    }

    // Seed dummy data if no accounts exist and we haven't seeded yet
    try {
      final hasSeeded = await firestore.hasSeededDummyData();
      if (!hasSeeded) {
        final accounts = await firestore.getAccountsList();
        if (accounts.isEmpty) {
          final accId = await firestore.createAccount({
            'name': 'Cash',
            'type': 'Cash',
            'balance': 50000.0,
          });

          final categories = await firestore.getCategoriesList();
          final salaryCat = categories.firstWhere(
            (c) => c['name'].toString().contains('Salary'),
            orElse: () => categories.first,
          );
          final foodCat = categories.firstWhere(
            (c) => c['name'].toString().contains('Food'),
            orElse: () => categories.first,
          );

          final now = DateTime.now();

          // Income
          await firestore.createTransaction({
            'account_id': accId,
            'account_name': 'Cash',
            'category_id': salaryCat['id'],
            'category_name': salaryCat['name'],
            'category_key': salaryCat['key'],
            'amount': 30000.0,
            'type': 'Income',
            'date': now,
            'note': 'Salary',
          });

          // Expense
          await firestore.createTransaction({
            'account_id': accId,
            'account_name': 'Cash',
            'category_id': foodCat['id'],
            'category_name': foodCat['name'],
            'category_key': foodCat['key'],
            'amount': 1500.0,
            'type': 'Expense',
            'date': now.subtract(const Duration(days: 1)),
            'note': 'Dinner',
          });
          debugPrint("Dummy data seeded successfully!");
        }
        await firestore.setHasSeededDummyData();
      }
    } catch (e) {
      debugPrint("Error seeding dummy data: $e");
    }
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch language changes to rebuild bottom navigation immediately
    context.watch<LanguageProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        appBar: _appBarForIndex(_selectedIndex),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget? _appBarForIndex(int index) {
    switch (index) {
      case 1:
        return _styledAppBar(title: context.translate('charts_analytics'));
      case 2:
        return _styledAppBar(
          title: context.translate('manage_accounts'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddAccountScreen()),
                ),
              ),
            ),
          ],
        );
      default:
        return null; // Transactions & Settings use no AppBar
    }
  }

  AppBar _styledAppBar({required String title, List<Widget>? actions}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      actions: actions,
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const TransactionsScreen();
      case 1:
        return const ChartsScreen();
      case 2:
        return const ManageAccountsScreen(isTab: true);
      case 3:
        return const SettingsScreen();
      default:
        return const Center(child: Text('Coming Soon'));
    }
  }

  // ── Bottom Nav ──────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.receipt_long_rounded,
                context.translate('transactions'),
              ),
              _buildNavItem(
                1,
                Icons.bar_chart_rounded,
                context.translate('charts'),
              ),
              _buildNavItem(
                2,
                Icons.account_balance_wallet_rounded,
                context.translate('accounts'),
              ),
              _buildNavItem(
                3,
                Icons.settings_outlined,
                context.translate('settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          TransactionsScreen.onTransactionsTabTapped();
        }
        setState(() => _selectedIndex = index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
