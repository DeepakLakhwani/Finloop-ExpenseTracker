import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/language_provider.dart';
import '../../theme/app_colors.dart';

class BudgetsManagementScreen extends StatefulWidget {
  const BudgetsManagementScreen({super.key});

  @override
  State<BudgetsManagementScreen> createState() => _BudgetsManagementScreenState();
}

class _BudgetsManagementScreenState extends State<BudgetsManagementScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await context.read<FirestoreService>().getCategoriesList();
      if (mounted) {
        setState(() {
          _categories = list;
          _loadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreService>();
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.translate('title_manage_budgets'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _loadingCategories ? null : () => _showBudgetForm(),
          ),
        ],
      ),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: firestore.getBudgets(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(context.translate('err_load_budgets')));
                }
                final budgets = snapshot.data ?? [];
                if (budgets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.track_changes_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.translate('msg_no_budgets'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.translate('msg_create_budgets_hint'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final budgetWidgets = budgets.map<Widget>((budget) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.track_changes, color: AppColors.primary),
                    ),
                    title: Text(
                      context.getLocalizedCategory(
                        budget['categoryKey']?.toString(),
                        budget['categoryName'] ?? context.translate('label_category'),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${context.translate('label_limit')}: $currency ${budget['limitAmount']}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showBudgetForm(budget: budget),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _deleteConfirm(budget['id']),
                        ),
                      ],
                    ),
                  );
                }).toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _buildSectionCard(budgetWidgets),
                );
              },
            ),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final List<Widget> dividedChildren = [];
    for (int i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i < children.length - 1) {
        dividedChildren.add(
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            indent: 60,
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: dividedChildren,
        ),
      ),
    );
  }

  Future<void> _deleteConfirm(String budgetId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('title_delete_budget')),
        content: Text(context.translate('delete_budget_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.translate('delete'),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<FirestoreService>().deleteBudget(budgetId);
    }
  }

  void _showBudgetForm({Map<String, dynamic>? budget}) {
    final isEditing = budget != null;
    final amountController = TextEditingController(
      text: isEditing ? budget['limitAmount'].toString() : '',
    );
    String? selectedCategoryId = isEditing ? budget['categoryId'] : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? context.translate('title_edit_budget') : context.translate('title_add_budget'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Category Dropdown
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCategoryId,
                    dropdownColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2C2C2C)
                        : Colors.white,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: context.translate('label_category'),
                      border: const UnderlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(context.translate('all_expenses')),
                      ),
                      ..._categories.where((c) => c['type'] == 'Expense').map((c) {
                        return DropdownMenuItem<String?>(
                          value: c['id'],
                          child: Text(context.getLocalizedCategory(c['key']?.toString(), c['name'] ?? '')),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedCategoryId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  // Limit Amount
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: context.translate('label_monthly_limit'),
                      prefixText: '${context.read<SettingsProvider>().currency} ',
                      border: const UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.translate('err_invalid_amount'))),
                          );
                          return;
                        }

                        final firestore = context.read<FirestoreService>();
                        String categoryName = 'All Expenses';
                        String? categoryKey;
                        if (selectedCategoryId != null) {
                          final cat = _categories.firstWhere((c) => c['id'] == selectedCategoryId);
                          categoryName = cat['name'] ?? 'Category';
                          categoryKey = cat['key']?.toString();
                        } else {
                          categoryKey = 'all_expenses';
                        }

                        final budgetData = {
                          'categoryId': selectedCategoryId,
                          'categoryName': categoryName,
                          'categoryKey': categoryKey,
                          'limitAmount': amount,
                        };

                        if (isEditing) {
                          await firestore.updateBudget(budget['id'], budgetData);
                        } else {
                          await firestore.createBudget(budgetData);
                        }

                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(isEditing ? context.translate('save_changes') : context.translate('btn_create_budget')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
