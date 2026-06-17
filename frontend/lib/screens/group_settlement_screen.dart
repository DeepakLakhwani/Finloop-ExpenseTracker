import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/group_member.dart';
import '../providers/group_provider.dart';
import '../providers/settings_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../main.dart';

class GroupSettlementScreen extends StatefulWidget {
  final String groupId;
  final List<GroupMember> members;
  final String? prefilledFrom;
  final String? prefilledTo;
  final double? prefilledAmount;

  const GroupSettlementScreen({
    super.key,
    required this.groupId,
    required this.members,
    this.prefilledFrom,
    this.prefilledTo,
    this.prefilledAmount,
  });

  @override
  State<GroupSettlementScreen> createState() => _GroupSettlementScreenState();
}

class _GroupSettlementScreenState extends State<GroupSettlementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _debtorId; // from member (debtor)
  String? _creditorId; // to member (creditor)

  // Personal accounts sync fields
  List<Map<String, dynamic>> _personalAccounts = [];
  String? _selectedAccountId;
  bool _isLoadingAccounts = true;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Set prefilled values if any, otherwise set defaults
    _debtorId =
        widget.prefilledFrom ??
        (widget.members.any((m) => m.id == uid)
            ? uid
            : widget.members.first.id);
    // Creditor must be different from debtor
    _creditorId =
        widget.prefilledTo ??
        widget.members
            .firstWhere(
              (m) => m.id != _debtorId,
              orElse: () => widget.members.first,
            )
            .id;

    if (widget.prefilledAmount != null) {
      _amountController.text = widget.prefilledAmount!.toStringAsFixed(2);
    }

    _fetchPersonalAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchPersonalAccounts() async {
    try {
      final firestore = context.read<FirestoreService>();
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

  Widget _buildPersonalAccountSelector() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isDebtor = _debtorId == uid;
    final isCreditor = _creditorId == uid;
    final isMeInvolved = isDebtor || isCreditor;

    if (!isMeInvolved) return const SizedBox.shrink();

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
          'No personal bank accounts found in Finloop. This settlement will not create a personal transaction.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange.shade700,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final String headingText = isDebtor
        ? 'Debit from Personal Account'
        : 'Credit to Personal Account';
    final String footnoteText = isDebtor
        ? 'FinLoop will auto-generate an Expense transaction in your personal ledger and decrease its balance!'
        : 'FinLoop will auto-generate an Income transaction in your personal ledger and increase its balance!';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              headingText,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedAccountId,
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
          footnoteText,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      showTopNotification(
        'Please enter a valid settlement amount greater than zero!',
        isError: true,
      );
      return;
    }

    if (_debtorId == _creditorId) {
      showTopNotification(
        'Debtor and Creditor must be different members!',
        isError: true,
      );
      return;
    }

    // Get personal account name if syncing
    String? accountName;
    if (_selectedAccountId != null && _personalAccounts.isNotEmpty) {
      final match = _personalAccounts.firstWhere(
        (a) => a['id'].toString() == _selectedAccountId,
      );
      accountName = match['name'] ?? 'Account';
    }

    final provider = context.read<GroupProvider>();
    final success = await provider.addSettlement(
      widget.groupId,
      fromMemberId: _debtorId!,
      toMemberId: _creditorId!,
      amount: amount,
      date: _selectedDate,
      notes: _notesController.text.trim(),
      personalAccountId: _selectedAccountId,
      personalAccountName: accountName,
    );

    if (success && mounted) {
      showTopNotification('Settlement recorded successfully!');
      Navigator.pop(context);
    } else {
      showTopNotification(
        'Failed to record settlement. Please check inputs and try again.',
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
          'Record Settlement',
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
                    // Debtor Selection
                    const Text(
                      'Who Paid (Debtor)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _debtorId,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: widget.members.map((m) {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final label = m.id == uid ? 'You' : m.name;
                        return DropdownMenuItem(
                          value: m.id,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _debtorId = val;
                          // Ensure creditor is not the same
                          if (_creditorId == val) {
                            _creditorId = widget.members
                                .firstWhere((m) => m.id != val)
                                .id;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Creditor Selection
                    const Text(
                      'Who Received (Creditor)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _creditorId,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: widget.members.where((m) => m.id != _debtorId).map(
                        (m) {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          final label = m.id == uid ? 'You' : m.name;
                          return DropdownMenuItem(
                            value: m.id,
                            child: Text(label),
                          );
                        },
                      ).toList(),
                      onChanged: (val) {
                        setState(() {
                          _creditorId = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Amount & Date
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _amountController,
                            hintText: '0.00',
                            label: 'Settlement Amount ($currency)',
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
                    const SizedBox(height: 24),

                    // Link Account Sync
                    _buildPersonalAccountSelector(),
                    const SizedBox(height: 24),

                    // Notes
                    CustomTextField(
                      controller: _notesController,
                      hintText: 'e.g. Sent via UPI, Cash handed over',
                      label: 'Notes / Payment Details',
                    ),
                    const SizedBox(height: 28),

                    CustomButton(text: 'Record Settlement', onPressed: _submit),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
