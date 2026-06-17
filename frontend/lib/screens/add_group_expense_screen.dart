import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/group_member.dart';
import '../models/group_expense.dart';
import '../providers/group_provider.dart';
import '../providers/settings_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../main.dart';

class AddGroupExpenseScreen extends StatefulWidget {
  final String groupId;
  final List<GroupMember> members;

  const AddGroupExpenseScreen({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  State<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends State<AddGroupExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Food';
  String? _paidById;
  SplitType _splitType = SplitType.equal;

  final List<String> _categories = [
    'Food',
    'Travel',
    'Shopping',
    'Health',
    'Rent',
    'Office',
    'Entertainment',
    'Other',
  ];

  // Participant selections
  final Map<String, bool> _selectedParticipants = {};
  // Manual inputs for split shares/ratios
  final Map<String, TextEditingController> _inputControllers = {};

  // Personal account sync fields
  List<Map<String, dynamic>> _personalAccounts = [];
  String? _selectedAccountId;
  bool _isLoadingAccounts = true;

  // FIX #8: Named listener so it can be removed in dispose
  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _paidById = widget.members.any((m) => m.id == uid)
        ? uid
        : widget.members.first.id;

    for (var m in widget.members) {
      _selectedParticipants[m.id] = true;
      _inputControllers[m.id] = TextEditingController(
        text: _splitType == SplitType.shares ? '1' : '',
      );
    }

    // FIX #8: Use named listener so it can be cleanly removed
    _amountController.addListener(_onAmountChanged);

    _fetchPersonalAccounts();
  }

  @override
  void dispose() {
    // FIX #8: Remove named listener before disposing
    _amountController.removeListener(_onAmountChanged);

    _titleController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _notesController.dispose();
    for (var controller in _inputControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchPersonalAccounts() async {
    // FIX #3: Capture context-dependent service before the async gap
    final firestore = context.read<FirestoreService>();

    try {
      final list = await firestore.getAccounts().first;
      if (mounted) {
        setState(() {
          _personalAccounts = list;
          if (_personalAccounts.isNotEmpty) {
            _selectedAccountId = _personalAccounts.first['id'].toString();
          }
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching personal accounts: $e');
      if (mounted) setState(() => _isLoadingAccounts = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildCategoryPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.surfaceDark
                              : AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.black12,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPayerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paid By',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        // FIX #1 & #6: Use `value` instead of the non-existent `initialValue`
        DropdownButtonFormField<String>(
          value: _paidById,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: widget.members.map((m) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final label = m.id == uid ? 'You' : m.name;
            return DropdownMenuItem(value: m.id, child: Text(label));
          }).toList(),
          onChanged: (val) {
            setState(() {
              _paidById = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSplitTypeToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final splitTypes = [
      {'type': SplitType.equal, 'label': 'Equal'},
      {'type': SplitType.exact, 'label': 'Exact'},
      {'type': SplitType.percentage, 'label': 'Percentage'},
      {'type': SplitType.shares, 'label': 'Shares'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Split Type',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: splitTypes.map((item) {
            final type = item['type'] as SplitType;
            final label = item['label'] as String;
            final isSelected = _splitType == type;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _splitType = type;
                    for (var key in _inputControllers.keys) {
                      _inputControllers[key]!.text = type == SplitType.shares
                          ? '1'
                          : '';
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.surfaceDark
                              : AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.black12,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // FIX #2: Replace deprecated withOpacity with withValues
                      color: isSelected
                          ? Colors.white
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPersonalAccountSelector() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_paidById != uid) return const SizedBox.shrink();

    if (_isLoadingAccounts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: LinearProgressIndicator(),
      );
    }

    if (_personalAccounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No personal bank accounts found in Finloop. This will not create a personal transaction.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              'Debit from Personal Account',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // FIX #1: Use `value` instead of `initialValue`
        DropdownButtonFormField<String>(
          value: _selectedAccountId,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _personalAccounts.map((a) {
            return DropdownMenuItem(
              value: a['id'].toString(),
              child: Text(a['name'] ?? 'Account'),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedAccountId = val;
            });
          },
        ),
        const SizedBox(height: 6),
        Text(
          'FinLoop will auto-generate an Expense transaction of this amount in your personal ledger and decrease its balance!',
          style: TextStyle(
            fontSize: 10,
            // FIX #2: Replace deprecated withOpacity with withValues
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsList(String currency) {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeIds = _selectedParticipants.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    final inputs = <String, double>{};
    for (var m in widget.members) {
      inputs[m.id] = double.tryParse(_inputControllers[m.id]!.text) ?? 0.0;
    }

    // FIX #4: Read provider once outside the builder to avoid repeated reads
    // during the build phase; result is computed as a plain map, not inside itemBuilder
    final calculatedShares = context.read<GroupProvider>().calculateSplit(
      amount: amount,
      type: _splitType,
      participants: activeIds,
      inputs: inputs,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        // FIX #2: Replace deprecated withOpacity with withValues
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Participants & Review Split',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.members.length,
            itemBuilder: (context, index) {
              final m = widget.members[index];
              final isChecked = _selectedParticipants[m.id] ?? false;
              final uid = FirebaseAuth.instance.currentUser?.uid;
              final mName = m.id == uid ? 'You' : m.name;
              final share = calculatedShares[m.id] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() {
                          _selectedParticipants[m.id] = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        mName,
                        style: TextStyle(
                          fontWeight: isChecked
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    if (isChecked && _splitType != SplitType.equal) ...[
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _inputControllers[m.id],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: _splitType == SplitType.percentage
                                ? '%'
                                : (_splitType == SplitType.shares
                                      ? 'shares'
                                      : currency),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],

                    Text(
                      '$currency${share.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isChecked
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      showTopNotification(
        'Please enter a valid amount greater than zero!',
        isError: true,
      );
      return;
    }

    // FIX #5: Validate _paidById before using it — avoid force-unwrap crash
    if (_paidById == null) {
      showTopNotification(
        'Please select who paid for this expense.',
        isError: true,
      );
      return;
    }

    final activeIds = _selectedParticipants.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    if (activeIds.isEmpty) {
      showTopNotification(
        'Please select at least one participant to split the bill!',
        isError: true,
      );
      return;
    }

    final inputs = <String, double>{};
    for (var m in widget.members) {
      inputs[m.id] = double.tryParse(_inputControllers[m.id]!.text) ?? 0.0;
    }

    final provider = context.read<GroupProvider>();
    final splitAmong = provider.calculateSplit(
      amount: amount,
      type: _splitType,
      participants: activeIds,
      inputs: inputs,
    );

    if (_splitType == SplitType.percentage) {
      final sumPct = activeIds.fold(
        0.0,
        (val, id) => val + (inputs[id] ?? 0.0),
      );
      if ((sumPct - 100.0).abs() > 0.01) {
        showTopNotification(
          'The sum of percentages must equal exactly 100%! Current sum: $sumPct%',
          isError: true,
        );
        return;
      }
    } else if (_splitType == SplitType.exact) {
      final sumAmt = activeIds.fold(
        0.0,
        (val, id) => val + (inputs[id] ?? 0.0),
      );
      if ((sumAmt - amount).abs() > 0.02) {
        showTopNotification(
          'The sum of exact amounts must equal the total amount! Current sum: $sumAmt, Total: $amount',
          isError: true,
        );
        return;
      }
    }

    // FIX #7: Use orElse to avoid StateError if account id not found
    String? accountName;
    if (_selectedAccountId != null && _personalAccounts.isNotEmpty) {
      final match = _personalAccounts.firstWhere(
        (a) => a['id'].toString() == _selectedAccountId,
        orElse: () => {},
      );
      accountName = match.isNotEmpty ? (match['name'] ?? 'Account') : null;
    }

    final currency = context.read<SettingsProvider>().currency;

    final success = await provider.addExpense(
      widget.groupId,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      amount: amount,
      currency: currency,
      date: _selectedDate,
      category: _selectedCategory,
      paidBy: _paidById!,
      splitAmong: splitAmong,
      splitType: _splitType,
      notes: _notesController.text.trim(),
      personalAccountId: _selectedAccountId,
      personalAccountName: accountName,
    );

    if (success && mounted) {
      showTopNotification('Shared expense added successfully!');
      Navigator.pop(context);
    } else {
      showTopNotification(
        'Failed to add expense. Please check inputs and try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Shared Expense',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: groupProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      controller: _titleController,
                      hintText: 'e.g. Dinner at Goa, Airbnb Booking',
                      label: 'Expense Title',
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter expense title'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descController,
                      hintText: 'e.g. Seafood & drinks at beachside restaurant',
                      label: 'Description (Optional)',
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _amountController,
                            hintText: '0.00',
                            label: 'Amount ($currency)',
                            keyboardType: TextInputType.number,
                            validator: (val) =>
                                val == null ||
                                    double.tryParse(val) == null ||
                                    double.parse(val) <= 0
                                ? 'Enter valid amount'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                              ),
                              label: Text(
                                DateFormat('dd/MM/yy').format(_selectedDate),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildCategoryPicker(),
                    const SizedBox(height: 16),

                    _buildPayerDropdown(),
                    const SizedBox(height: 16),

                    _buildSplitTypeToggle(),
                    const SizedBox(height: 24),

                    _buildPersonalAccountSelector(),
                    const SizedBox(height: 24),

                    _buildParticipantsList(currency),
                    const SizedBox(height: 24),

                    CustomTextField(
                      controller: _notesController,
                      hintText: 'Add special comments, UPI links...',
                      label: 'Notes (Optional)',
                    ),
                    const SizedBox(height: 28),

                    CustomButton(text: 'Save Expense', onPressed: _submit),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
