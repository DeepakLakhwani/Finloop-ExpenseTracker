import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../providers/settings_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import 'add_account/widgets/card_preview.dart';
import 'add_account/widgets/color_selector.dart';

class AddAccountScreen extends StatefulWidget {
  final Map<String, dynamic>? initialAccount;
  final String? prefilledType;

  const AddAccountScreen({super.key, this.initialAccount, this.prefilledType});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _name;
  late String _type;
  bool _isLoading = false;

  // FIX #1: Use a TextEditingController for balance instead of initialValue + onSaved
  // This prevents stale values when the user never focuses away from the field.
  late final TextEditingController _balanceController;

  // Credit Card fields
  final _limitController = TextEditingController();
  final _usedAmountController = TextEditingController();
  final _issuerController = TextEditingController();
  int _statementDate = 15;
  int _dueDate = 30;
  String _selectedColorHex = '#1E3A8A';

  final List<String> _premiumColors = [
    '#1E3A8A', // Sapphire Blue
    '#064E3B', // Emerald Green
    '#111827', // Midnight Black
    '#374151', // Platinum Silver
    '#881337', // Rose Gold / Crimson
    '#4C1D95', // Royal Purple
    '#78350F', // Gold Amber
    '#B91C1C', // Ruby Red
  ];

  @override
  void initState() {
    super.initState();
    _name = widget.initialAccount?['name'] ?? '';
    _type = widget.initialAccount?['type'] ?? widget.prefilledType ?? 'Cash';

    final initialBalance =
        (double.tryParse(
          widget.initialAccount?['balance']?.toString() ?? '0.0',
        ) ??
        0.0);

    // FIX #1: Initialize controller for balance
    _balanceController = TextEditingController(
      text: initialBalance.toStringAsFixed(2),
    );

    if (_type == 'Credit Card') {
      _limitController.text = widget.initialAccount?['limit']?.toString() ?? '';
      _usedAmountController.text =
          widget.initialAccount?['usedAmount']?.toString() ?? '';
      _issuerController.text = widget.initialAccount?['cardIssuer'] ?? '';
      _statementDate = widget.initialAccount?['statementDate'] ?? 15;
      _dueDate = widget.initialAccount?['dueDate'] ?? 30;
      _selectedColorHex = widget.initialAccount?['color'] ?? '#1E3A8A';
    }
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _limitController.dispose();
    _usedAmountController.dispose();
    _issuerController.dispose();
    super.dispose();
  }

  // FIX #2: Helper getters so values are always read from controllers (single source of truth)
  double get _balance => double.tryParse(_balanceController.text) ?? 0.0;
  double get _creditLimit => double.tryParse(_limitController.text) ?? 0.0;
  double get _usedAmount => double.tryParse(_usedAmountController.text) ?? 0.0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final currency = context.read<SettingsProvider>().currency;

    setState(() => _isLoading = true);
    try {
      final firestore = context.read<FirestoreService>();

      Map<String, dynamic> accountData;

      if (_type == 'Credit Card') {
        accountData = {
          'name': _name,
          'type': _type,
          'currency': currency,
          'balance': _creditLimit - _usedAmount, // Available credit
          'limit': _creditLimit,
          'usedAmount': _usedAmount,
          'statementDate': _statementDate,
          'dueDate': _dueDate,
          'cardIssuer': _issuerController.text.trim(),
          'color': _selectedColorHex,
        };
      } else {
        accountData = {
          'name': _name,
          'type': _type,
          'currency': currency,
          'balance': _balance,
        };
      }

      final initialId = widget.initialAccount?['id']?.toString();

      if (initialId != null) {
        // Editing an existing account — just update, never create opening transactions
        await firestore.updateAccount(initialId, accountData);
      } else {
        if (_type == 'Credit Card') {
          // No opening transaction for credit cards to prevent reporting skew
          await firestore.createAccount(accountData);
        } else if (_balance > 0) {
          // Create account with zero balance, then add an opening balance transaction
          final zeroBalanceData = {...accountData, 'balance': 0.0};
          final newAccountId = await firestore.createAccount(zeroBalanceData);

          // FIX #3: Removed redundant local userId variable; use FirebaseAuth directly
          String categoryId = 'opening_balance';
          String categoryName = 'Opening Balance';

          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final openingCategory = await firestore.getOpeningBalanceCategory();
            if (openingCategory != null) {
              categoryId = openingCategory['id'].toString();
              categoryName = openingCategory['name'] ?? 'Opening Balance';
            } else {
              categoryId = await firestore.createCategoryWithId({
                'name': 'Opening Balance',
                'type': 'Income',
                'icon': 'account_balance_wallet',
                'color': '#9E9E9E',
              });
              categoryName = 'Opening Balance';
            }
          }

          final txData = {
            'account_id': newAccountId,
            'to_account_id': null,
            'category_id': categoryId,
            'category_name': categoryName,
            'account_name': _name,
            'amount': _balance,
            'type': 'Income',
            'date': DateTime.now(),
            'notes': 'Account opening balance',
            'description': 'Opening Balance',
            'fees': 0.0,
          };
          await firestore.createTransaction(txData);
        } else {
          // Zero or negative balance — just create the account
          await firestore.createAccount(accountData);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.translate('err_save_account')}$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('title_delete_account')),
        content: Text(context.translate('delete_account_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.translate('delete'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final firestore = context.read<FirestoreService>();
      final initialId = widget.initialAccount?['id']?.toString();
      if (initialId != null) {
        await firestore.deleteAccount(initialId);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.translate('err_delete_account')}$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;
    final isEditing = widget.initialAccount != null;

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
          isEditing ? context.translate('title_edit_account') : context.translate('title_new_account'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 22,
              ),
              onPressed: _deleteAccount,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Credit card live preview
                    if (_type == 'Credit Card') ...[
                      CardPreview(
                        currency: currency,
                        limitText: _limitController.text,
                        usedText: _usedAmountController.text,
                        issuerText: _issuerController.text,
                        // FIX #4: _name is kept live via onChanged below so preview
                        // always reflects what the user is typing.
                        nameText: _name,
                        colorHex: _selectedColorHex,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Account Name ──────────────────────────────────────────
                    _buildRow(
                      icon: Icons.subtitles_outlined,
                      child: TextFormField(
                        initialValue: _name,
                        style: _fieldTextStyle(context),
                        decoration: _underlineDecoration(
                          label: context.translate('label_account_name'),
                          hint: context.translate('hint_account_name'),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? context.translate('err_invalid_name')
                            : null,
                        // FIX #4: onChanged keeps _name live for CardPreview
                        onChanged: (val) => setState(() => _name = val.trim()),
                        onSaved: (val) => _name = val?.trim() ?? '',
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Account Type ──────────────────────────────────────────
                    _buildRow(
                      icon: Icons.account_balance_outlined,
                      child: DropdownButtonFormField<String>(
                        value: _type,
                        style: _fieldTextStyle(context),
                        dropdownColor: _dropdownColor(context),
                        decoration: _underlineDecoration(label: context.translate('label_account_type')),
                        items: [
                          DropdownMenuItem(value: 'Cash', child: Text(context.translate('type_cash'))),
                          DropdownMenuItem(
                            value: 'Bank Account',
                            child: Text(context.translate('type_bank')),
                          ),
                          DropdownMenuItem(
                            value: 'Credit Card',
                            child: Text(context.translate('type_cards')),
                          ),
                          DropdownMenuItem(
                            value: 'Wallet',
                            child: Text(context.translate('type_wallet')),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _type = val);
                        },
                      ),
                    ),

                    // ── Non-credit-card: Balance field ────────────────────────
                    if (_type != 'Credit Card') ...[
                      const SizedBox(height: 20),
                      _buildRow(
                        icon: Icons.savings_outlined,
                        child: TextFormField(
                          // FIX #1: use controller instead of initialValue + onSaved
                          controller: _balanceController,
                          style: _fieldTextStyle(context),
                          decoration: _underlineDecoration(
                            label: context.translate('label_balance'),
                            prefix: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                currency,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) =>
                              val == null || double.tryParse(val) == null
                              ? context.translate('err_invalid_amount')
                              : null,
                          // FIX #1: no onSaved needed — controller always has current value
                        ),
                      ),
                    ] else ...[
                      // ── Credit Card specific fields ───────────────────────

                      // Card Issuer
                      const SizedBox(height: 20),
                      _buildRow(
                        icon: Icons.business_outlined,
                        child: TextFormField(
                          controller: _issuerController,
                          style: _fieldTextStyle(context),
                          decoration: _underlineDecoration(
                            label: context.translate('label_card_issuer'),
                            hint: context.translate('hint_card_issuer'),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),

                      // Credit Limit
                      const SizedBox(height: 20),
                      _buildRow(
                        icon: Icons.credit_score_outlined,
                        child: TextFormField(
                          controller: _limitController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: _fieldTextStyle(context),
                          decoration: _underlineDecoration(
                            label: context.translate('label_credit_limit'),
                            prefixText: '$currency ',
                          ),
                          validator: (val) {
                            final parsed = double.tryParse(val ?? '');
                            if (parsed == null || parsed <= 0) {
                              return context.translate('err_invalid_limit');
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),

                      // Already Used Amount
                      const SizedBox(height: 20),
                      _buildRow(
                        icon: Icons.money_off_outlined,
                        child: TextFormField(
                          controller: _usedAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: _fieldTextStyle(context),
                          decoration: _underlineDecoration(
                            label: context.translate('label_used_amount'),
                            prefixText: '$currency ',
                          ),
                          // FIX #5: Validate that usedAmount is numeric when provided
                          // and does not exceed the credit limit.
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return null;
                            final used = double.tryParse(val);
                            if (used == null || used < 0) {
                              return context.translate('err_invalid_amount');
                            }
                            final limit =
                                double.tryParse(_limitController.text) ?? 0;
                            if (used > limit) {
                              return context.translate('err_used_exceeds_limit');
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),

                      // Billing Cycle
                      const SizedBox(height: 24),
                      Text(
                        context.translate('header_billing_cycle'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _statementDate,
                              menuMaxHeight: 280,
                              dropdownColor: _dropdownColor(context),
                              style: _fieldTextStyle(context),
                              decoration: _underlineDecoration(
                                label: context.translate('label_statement_date'),
                                labelSize: 12,
                              ),
                              items: List.generate(
                                31,
                                (i) => DropdownMenuItem<int>(
                                  value: i + 1,
                                  child: Text(
                                    context.translate('label_day_count')
                                        .replaceAll('{day}', '${i + 1}'),
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _statementDate = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _dueDate,
                              menuMaxHeight: 280,
                              dropdownColor: _dropdownColor(context),
                              style: _fieldTextStyle(context),
                              decoration: _underlineDecoration(
                                label: context.translate('label_due_date'),
                                labelSize: 12,
                              ),
                              items: List.generate(
                                31,
                                (i) => DropdownMenuItem<int>(
                                  value: i + 1,
                                  child: Text(
                                    context.translate('label_day_count')
                                        .replaceAll('{day}', '${i + 1}'),
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _dueDate = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      // Card Theme
                      const SizedBox(height: 28),
                      Text(
                        context.translate('header_card_theme'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ColorSelector(
                        colors: _premiumColors,
                        selectedColorHex: _selectedColorHex,
                        onColorSelected: (colorHex) {
                          setState(() => _selectedColorHex = colorHex);
                        },
                      ),
                    ],

                    const SizedBox(height: 40),

                    // ── Submit button ─────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isEditing
                              ? context.translate('btn_save_changes')
                              : context.translate('btn_create_account'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Wraps a field with its leading icon in a consistent Row.
  Widget _buildRow({required IconData icon, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 12),
          child: Icon(icon, color: AppColors.neutral, size: 18),
        ),
        Expanded(child: child),
      ],
    );
  }

  TextStyle _fieldTextStyle(BuildContext context) =>
      TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15);

  Color _dropdownColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2C2C2C)
      : Colors.white;

  /// Shared underline InputDecoration to eliminate duplication.
  InputDecoration _underlineDecoration({
    required String label,
    String? hint,
    String? prefixText,
    Widget? prefix,
    double labelSize = 13,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.neutral, fontSize: labelSize),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
      ),
      prefix: prefix,
      filled: false,
      contentPadding: const EdgeInsets.only(top: 4, bottom: 4),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey, width: 1.2),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey, width: 1.2),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
