import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/firestore_service.dart';
import '../services/ad_service.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../providers/language_provider.dart';
import '../main.dart';
import 'import_export/services/excel_service.dart';
import 'import_export/widgets/backup_guidance_card.dart';

class ImportExportScreen extends StatefulWidget {
  final bool isBackupMode;

  const ImportExportScreen({super.key, this.isBackupMode = false});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedAccountId; // null = All Accounts
  List<Map<String, dynamic>> _userAccounts = [];
  List<Map<String, dynamic>> _userCategories = [];
  bool _isLoadingAccounts = true;
  bool _isExporting = false;
  bool _isImporting = false;

  // Prevents double-firing the export when an ad reward + close both arrive.
  bool _rewardGranted = false;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(
      Duration(days: widget.isBackupMode ? 365 : 30),
    );
    _toDate = DateTime.now();
    _fetchMetadata();
  }

  // ─── Data Fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchMetadata() async {
    try {
      final firestore = context.read<FirestoreService>();
      final results = await Future.wait([
        firestore.getAccountsList(),
        firestore.getCategoriesList(),
      ]);

      if (!mounted) return;
      setState(() {
        _userAccounts = List<Map<String, dynamic>>.from(results[0]);
        _userCategories = List<Map<String, dynamic>>.from(results[1]);
        _isLoadingAccounts = false;
      });
    } catch (e, stack) {
      debugPrint('Error fetching metadata: $e\n$stack');
      if (!mounted) return;
      setState(() => _isLoadingAccounts = false);
      _showNotification(
        context.translate('err_load_account_details'),
        isError: true,
      );
    }
  }

  // ─── Account / Category Resolution ─────────────────────────────────────────

  /// Returns the existing account ID or creates a new one.
  Future<String> _resolveAccount(
    String name,
    FirestoreService firestore,
  ) async {
    final trimmed = name.trim();
    final existing = _userAccounts.firstWhere(
      (a) => (a['name'] as String?)?.toLowerCase() == trimmed.toLowerCase(),
      orElse: () => {},
    );
    if (existing.isNotEmpty) return existing['id'].toString();

    final type = _inferAccountType(trimmed);
    final currency = context.read<SettingsProvider>().currency;

    final newId = await firestore.createAccount({
      'name': trimmed,
      'type': type,
      'balance': 0.0,
      'currency': currency,
    });

    if (mounted) {
      setState(
        () => _userAccounts.add({'id': newId, 'name': trimmed, 'type': type}),
      );
    }
    return newId;
  }

  String _inferAccountType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bank')) return 'Account';
    if (lower.contains('card')) return 'Card';
    if (lower.contains('wallet')) return 'Cash';
    return 'Cash';
  }

  /// Returns the existing category ID or creates a new one.
  Future<String> _resolveCategory(
    String name,
    String type,
    FirestoreService firestore,
  ) async {
    final trimmed = name.trim();
    final existing = _userCategories.firstWhere(
      (c) =>
          (c['name'] as String?)?.toLowerCase() == trimmed.toLowerCase() &&
          c['type'] == type,
      orElse: () => {},
    );
    if (existing.isNotEmpty) return existing['id'].toString();

    final newId = await firestore.createCategoryWithId({
      'name': trimmed,
      'type': type,
      'icon': 'attach_money',
      'color': '#42A5F5',
    });

    if (mounted) {
      setState(
        () => _userCategories.add({'id': newId, 'name': trimmed, 'type': type}),
      );
    }
    return newId;
  }

  // ─── Export ─────────────────────────────────────────────────────────────────

  void _promptExport() {
    if (_fromDate == null || _toDate == null) {
      _showNotification(context.translate('select_date_hint'), isError: true);
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.translate('title_unlock_premium_export')),
        content: Text(context.translate('desc_premium_export')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
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
                    _playRewardedAdThenExport();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(
                    context.translate('btn_watch_export'),
                    style: const TextStyle(
                      color: Colors.white,
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

  void _playRewardedAdThenExport() {
    _rewardGranted = false;
    _showNotification(context.translate('msg_ad_preparing'));

    AdService.showRewarded(
      onRewardEarned: () {
        _rewardGranted = true;
        _showNotification(context.translate('msg_export_compiling'));
        _runExport();
      },
      onAdClosed: () {
        // Only show the "must watch" message when the reward was NOT earned.
        if (!_rewardGranted) {
          _showNotification(
            context.translate('err_ad_unwatched'),
            isError: true,
          );
        }
      },
      onAdFailed: () {
        _showNotification(context.translate('msg_ad_failed_fallback'));
        _runExport();
      },
    );
  }

  Future<void> _runExport() async {
    if (_fromDate == null || _toDate == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showNotification(
        context.translate('err_sign_in_to_export'),
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isExporting = true);

    try {
      final firestore = context.read<FirestoreService>();
      final allTxs = await firestore.getTransactionsList();
      if (!mounted) return;

      // Build an inclusive end-of-day boundary in local time.
      final start = _fromDate!;
      final end = DateTime(
        _toDate!.year,
        _toDate!.month,
        _toDate!.day,
        23,
        59,
        59,
        999,
      );

      final filtered = allTxs.where((tx) {
        final date = _parseDate(tx['date']);
        if (date == null) return false;
        if (date.isBefore(start) || date.isAfter(end)) return false;

        if (_selectedAccountId != null) {
          final fromId =
              tx['account_id']?.toString() ?? tx['accountId']?.toString();
          final toId =
              tx['to_account_id']?.toString() ?? tx['toAccountId']?.toString();
          return fromId == _selectedAccountId || toId == _selectedAccountId;
        }
        return true;
      }).toList();

      if (filtered.isEmpty) {
        _showNotification(context.translate('err_no_tx_found'), isError: true);
        return;
      }

      final formattedList = filtered.map((tx) {
        final date = _parseDate(tx['date'])!;
        return <String, dynamic>{
          'date': date,
          'type': tx['type'],
          'category_name': tx['category_name'],
          'account_name': tx['account_name'],
          'to_account_name': tx['to_account_name'],
          'amount': tx['amount'],
          'notes': tx['notes'],
          'description': tx['description'],
          'fees': tx['fees'],
        };
      }).toList();

      final bytes = ExcelService.exportTransactions(
        transactions: formattedList,
      );
      if (bytes == null) {
        _showNotification(
          context.translate('err_export_failed_gen'),
          isError: true,
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'finloop_export_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final filePath = '${tempDir.path}/$fileName';
      await File(filePath).writeAsBytes(bytes);

      if (!mounted) return;
      _showNotification(context.translate('msg_export_success'));
      await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath)], text: 'Exported Transactions'),
      );
    } catch (e, stack) {
      debugPrint('Export error: $e\n$stack');
      if (!mounted) return;
      _showNotification(context.translate('err_export_failed'), isError: true);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── Import ─────────────────────────────────────────────────────────────────

  Future<void> _importTransactions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showNotification(
        context.translate('err_sign_in_to_import'),
        isError: true,
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, // always request bytes — safe on web & desktop
      );

      if (!mounted) return;

      if (result == null || result.files.single.bytes == null) {
        setState(() => _isImporting = false);
        return;
      }

      final bytes = result.files.single.bytes!;
      final parsedRows = ExcelService.parseExcel(bytes);

      if (parsedRows.isEmpty) {
        _showNotification(
          context.translate('err_empty_import_file'),
          isError: true,
        );
        setState(() => _isImporting = false);
        return;
      }

      // Capture service reference before entering the async loop.
      final firestore = context.read<FirestoreService>();

      int importCount = 0;
      int skipCount = 0;

      for (final row in parsedRows) {
        try {
          final date = _parseDate(row['date']);
          final type = row['type']?.toString().trim() ?? '';
          final catName = row['category_name']?.toString().trim() ?? '';
          final accName = row['account_name']?.toString().trim() ?? '';
          final toAccName = row['to_account_name']?.toString().trim() ?? '';
          final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
          final notes = row['notes']?.toString().trim() ?? '';
          final description = row['description']?.toString().trim() ?? '';
          final fees = (row['fees'] as num?)?.toDouble() ?? 0.0;

          // Validate required fields.
          if (date == null || type.isEmpty || accName.isEmpty || amount <= 0) {
            debugPrint('Skipping invalid row: $row');
            skipCount++;
            continue;
          }

          final accountId = await _resolveAccount(accName, firestore);
          if (!mounted) return;

          String? toAccountId;
          if (type == 'Transfer' && toAccName.isNotEmpty) {
            toAccountId = await _resolveAccount(toAccName, firestore);
            if (!mounted) return;
          }

          String? categoryId;
          if (type != 'Transfer' && catName.isNotEmpty) {
            categoryId = await _resolveCategory(catName, type, firestore);
            if (!mounted) return;
          }

          await firestore.createTransaction({
            'account_id': accountId,
            'to_account_id': toAccountId,
            'category_id': categoryId,
            'category_name': type == 'Transfer' ? 'Transfer' : catName,
            'account_name': accName,
            'to_account_name': type == 'Transfer' ? toAccName : null,
            'amount': amount,
            'type': type,
            'date': Timestamp.fromDate(date),
            'notes': notes.isNotEmpty ? notes : null,
            'description': description.isNotEmpty ? description : null,
            'fees': fees,
          });

          importCount++;
        } catch (rowError, rowStack) {
          debugPrint('Error importing row: $rowError\n$rowStack');
          skipCount++;
        }
      }

      if (!mounted) return;

      final msg = skipCount > 0
          ? '${context.translate('msg_import_success_partial')} ($importCount/$skipCount)'
          : context.translate('msg_import_success_full');
      _showNotification(msg, isError: skipCount > 0 && importCount == 0);

      await _fetchMetadata();
    } catch (e, stack) {
      debugPrint('Import error: $e\n$stack');
      if (!mounted) return;
      _showNotification(context.translate('err_import_failed'), isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    showTopNotification(message, isError: isError);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        child: child!,
      ),
    );

    if (date == null || !mounted) return;

    setState(() {
      if (isFrom) {
        _fromDate = date;
        if (_toDate != null && _fromDate!.isAfter(_toDate!))
          _toDate = _fromDate;
      } else {
        _toDate = date;
        if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
          _fromDate = _toDate;
        }
      }
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isBackupMode
              ? context.translate('backup_restore_title')
              : '${context.translate('header_import_tx')} & ${context.translate('header_export_tx')}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: _isLoadingAccounts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isBackupMode) ...[
                    const BackupGuidanceCard(),
                    const SizedBox(height: 24),
                  ],
                  _SectionHeader(
                    title: widget.isBackupMode
                        ? context.translate('header_create_backup')
                        : context.translate('header_export_tx'),
                  ),
                  const SizedBox(height: 12),
                  _ExportCard(
                    fromDate: _fromDate,
                    toDate: _toDate,
                    selectedAccountId: _selectedAccountId,
                    userAccounts: _userAccounts,
                    isExporting: _isExporting,
                    isBackupMode: widget.isBackupMode,
                    onPickFromDate: () => _pickDate(isFrom: true),
                    onPickToDate: () => _pickDate(isFrom: false),
                    onSelectAccount: (id) =>
                        setState(() => _selectedAccountId = id),
                    onExport: _promptExport,
                  ),
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: widget.isBackupMode
                        ? context.translate('header_restore_backup')
                        : context.translate('header_import_tx'),
                  ),
                  const SizedBox(height: 12),
                  _ImportCard(
                    isImporting: _isImporting,
                    isBackupMode: widget.isBackupMode,
                    onImport: _importTransactions,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        letterSpacing: 1.1,
      ),
    );
  }
}

class _ExportCard extends StatelessWidget {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? selectedAccountId;
  final List<Map<String, dynamic>> userAccounts;
  final bool isExporting;
  final bool isBackupMode;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final ValueChanged<String?> onSelectAccount;
  final VoidCallback onExport;

  const _ExportCard({
    required this.fromDate,
    required this.toDate,
    required this.selectedAccountId,
    required this.userAccounts,
    required this.isExporting,
    required this.isBackupMode,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onSelectAccount,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date pickers
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: context.translate('label_from_date'),
                    date: fromDate,
                    isDark: isDark,
                    onTap: onPickFromDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    label: context.translate('label_to_date'),
                    date: toDate,
                    isDark: isDark,
                    onTap: onPickToDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Account filter
            Text(
              context.translate('select_account'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _AccountChip(
                    label: context.translate('filter_all_accounts'),
                    isSelected: selectedAccountId == null,
                    onSelected: () => onSelectAccount(null),
                  ),
                  const SizedBox(width: 8),
                  ...userAccounts.map((acc) {
                    final id = acc['id']?.toString();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AccountChip(
                        label: acc['name']?.toString() ?? '',
                        isSelected: selectedAccountId == id,
                        onSelected: () => onSelectAccount(id),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Export button
            ElevatedButton.icon(
              onPressed: isExporting ? null : onExport,
              icon: isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download_rounded, color: Colors.white),
              label: Text(
                isExporting
                    ? context.translate('btn_exporting')
                    : (isBackupMode
                          ? context.translate('btn_export_backup')
                          : context.translate('btn_export_excel')),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool isDark;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : AppColors.neutralLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date == null
                        ? context.translate('select_date_hint')
                        : DateFormat('dd MMM yyyy').format(date!),
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _AccountChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : cs.onSurface.withValues(alpha: 0.12),
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : cs.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final bool isImporting;
  final bool isBackupMode;
  final VoidCallback onImport;

  const _ImportCard({
    required this.isImporting,
    required this.isBackupMode,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.translate('header_import_instructions'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.translate('desc_import_instructions'),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: isImporting ? null : onImport,
              icon: isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded, color: Colors.white),
              label: Text(
                isImporting
                    ? context.translate('btn_importing')
                    : (isBackupMode
                          ? context.translate('btn_upload_backup')
                          : context.translate('btn_upload_excel')),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppColors.success,
                disabledBackgroundColor: AppColors.success.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
