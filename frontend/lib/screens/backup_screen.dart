import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../providers/language_provider.dart';
import '../services/google_drive_service.dart';

const String _kNeverBackedUp = 'Never';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _googleAccountEmail;
  String _autoBackupFrequency = 'off'; // 'off', 'daily', 'weekly', 'monthly'
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLoadingState = true;
  String _lastBackupTime = _kNeverBackedUp;
  double _backupProgress = 0.0;
  String _backupStatusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  Future<void> _loadBackupSettings() async {
    setState(() => _isLoadingState = true);
    try {
      final email = await GoogleDriveService.getConnectedAccountEmail();
      final freq = await GoogleDriveService.getAutoBackupFrequency();
      final lastTime = await GoogleDriveService.getLastDriveBackupTime();

      if (!mounted) return;
      setState(() {
        _googleAccountEmail = email;
        _autoBackupFrequency = freq;
        _lastBackupTime = lastTime;
        _isLoadingState = false;
      });
    } catch (e) {
      debugPrint('Error loading backup settings: $e');
      if (mounted) {
        setState(() => _isLoadingState = false);
      }
    }
  }

  Future<void> _selectGoogleAccount() async {
    try {
      final account = await GoogleDriveService.selectGoogleAccount();
      if (!mounted) return;
      if (account != null) {
        setState(() {
          _googleAccountEmail = account.email;
        });
        _showSuccessSnackBar(
          icon: Icons.account_circle,
          message: 'Connected to ${account.email}',
        );
      } else {
        setState(() {
          _googleAccountEmail = null;
        });
      }
    } catch (e) {
      debugPrint('Error selecting Google account: $e');
      if (!mounted) return;
      setState(() {
        _googleAccountEmail = null;
      });
      _showErrorSnackBar('Unable to connect Google Account');
    }
  }

  Future<void> _switchGoogleAccount() async {
    try {
      final account = await GoogleDriveService.switchGoogleAccount();
      if (!mounted) return;
      if (account != null) {
        setState(() {
          _googleAccountEmail = account.email;
        });
        _showSuccessSnackBar(
          icon: Icons.account_circle,
          message: 'Switched to ${account.email}',
        );
      }
    } catch (e) {
      debugPrint('Error switching Google account: $e');
    }
  }

  Future<void> _disconnectGoogleAccount() async {
    try {
      await GoogleDriveService.disconnectGoogleAccount();
      await GoogleDriveService.setAutoBackupFrequency('off');
      if (!mounted) return;
      setState(() {
        _googleAccountEmail = null;
        _autoBackupFrequency = 'off';
      });
      _showWarningSnackBar('Google Drive backup disabled');
    } catch (e) {
      debugPrint('Error disconnecting account: $e');
    }
  }

  Future<void> _updateAutoBackupFrequency(String freq) async {
    if (_googleAccountEmail == null && freq != 'off') {
      _showWarningSnackBar('Please enable Google Drive Backup first');
      return;
    }

    setState(() {
      _autoBackupFrequency = freq;
    });

    await GoogleDriveService.setAutoBackupFrequency(freq);
    if (!mounted) return;
    _showSuccessSnackBar(
      icon: Icons.schedule,
      message: 'Auto-backup updated to ${freq.toUpperCase()}',
    );
  }

  // Trigger Google Drive Backup with real-time status updates
  Future<void> _triggerDriveBackup() async {
    if (_isBackingUp || _isRestoring) return;

    if (_googleAccountEmail == null) {
      await _selectGoogleAccount();
      if (_googleAccountEmail == null) return;
    }

    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.05;
      _backupStatusMessage = 'Initializing cloud backup...';
    });

    final success = await GoogleDriveService.uploadBackupToDrive(
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _backupStatusMessage = status;
            _backupProgress = progress;
          });
        }
      },
    );

    if (!mounted) return;

    if (success) {
      final nowStr = DateFormat('MMM dd, yyyy, hh:mm a').format(DateTime.now());
      setState(() {
        _isBackingUp = false;
        _backupProgress = 1.0;
        _lastBackupTime = nowStr;
        _backupStatusMessage = '';
      });
      _showSuccessSnackBar(
        icon: Icons.cloud_done,
        message: context.translate('msg_backup_success'),
      );
    } else {
      setState(() {
        _isBackingUp = false;
        _backupProgress = 0.0;
        _backupStatusMessage = '';
      });
      _showErrorSnackBar(context.translate('err_backup_failed'));
    }
  }

  // Trigger Local File Backup (Export .enc file via Share)
  Future<void> _triggerLocalBackup() async {
    if (_isBackingUp || _isRestoring) return;

    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.05;
      _backupStatusMessage = 'Exporting local backup file...';
    });

    final success = await GoogleDriveService.exportBackupToLocalFile(
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _backupStatusMessage = status;
            _backupProgress = progress;
          });
        }
      },
    );

    if (!mounted) return;

    setState(() {
      _isBackingUp = false;
      _backupProgress = 0.0;
      _backupStatusMessage = '';
    });

    if (success) {
      _showSuccessSnackBar(
        icon: Icons.share_arrival_time_outlined,
        message: 'Local backup file generated successfully',
      );
    } else {
      _showErrorSnackBar('Failed to export local backup file');
    }
  }

  // Trigger Local File Restore (Pick .enc / .json file and inspect before restore)
  Future<void> _triggerLocalRestore() async {
    if (_isBackingUp || _isRestoring) return;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final rawPayload = await file.readAsString();

      final summary = await GoogleDriveService.inspectBackupPayload(rawPayload);
      if (summary == null) {
        _showErrorSnackBar('Invalid or corrupted backup file');
        return;
      }

      if (!mounted) return;
      final confirm = await _showBackupContentPreviewModal(summary);
      if (confirm != true) return;

      setState(() => _isRestoring = true);
      final success = await GoogleDriveService.restoreFromRawPayload(
        rawPayload,
        restoreMode: _selectedRestoreMode,
      );
      if (!mounted) return;
      setState(() => _isRestoring = false);

      if (success) {
        _showSuccessSnackBar(
          icon: Icons.restore_outlined,
          message: context.translate('msg_restore_success'),
        );
      } else {
        _showErrorSnackBar(context.translate('err_restore_failed'));
      }
    } catch (e) {
      debugPrint('Error picking local backup file: $e');
      if (mounted) {
        setState(() => _isRestoring = false);
        _showErrorSnackBar('Failed to read local backup file');
      }
    }
  }

  // Trigger Google Drive Restore using a modern Bottom Sheet
  Future<void> _triggerDriveRestore() async {
    if (_isBackingUp || _isRestoring) return;

    if (_googleAccountEmail == null) {
      await _selectGoogleAccount();
      if (_googleAccountEmail == null) return;
    }

    setState(() => _isRestoring = true);
    final backups = await GoogleDriveService.listDriveBackups();
    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (backups.isEmpty) {
      _showWarningSnackBar('No Google Drive backups found in this account.');
      return;
    }

    final selectedBackup = await _showDriveBackupListBottomSheet(backups);
    if (selectedBackup == null) return;

    // Fetch and inspect payload before confirming restore
    setState(() => _isRestoring = true);
    final rawPayload = await GoogleDriveService.fetchDriveBackupRawPayload(selectedBackup['id']!);
    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (rawPayload == null) {
      _showErrorSnackBar('Unable to download selected backup from Google Drive');
      return;
    }

    final summary = await GoogleDriveService.inspectBackupPayload(rawPayload);
    if (summary == null) {
      _showErrorSnackBar('Backup file is invalid or corrupted.');
      return;
    }

    final confirm = await _showBackupContentPreviewModal(summary);
    if (confirm != true) return;

    setState(() => _isRestoring = true);
    final success = await GoogleDriveService.restoreFromRawPayload(
      rawPayload,
      restoreMode: _selectedRestoreMode,
    );
    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (success) {
      _showSuccessSnackBar(
        icon: Icons.cloud_done_outlined,
        message: context.translate('msg_restore_success'),
      );
    } else {
      _showErrorSnackBar(context.translate('err_restore_failed'));
    }
  }

  // Bottom Sheet listing Google Drive backups with delete option
  Future<Map<String, String>?> _showDriveBackupListBottomSheet(List<Map<String, String>> initialBackups) {
    List<Map<String, String>> currentList = List.from(initialBackups);

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setBottomSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primaryColor = Theme.of(context).colorScheme.primary != Colors.black
              ? Theme.of(context).colorScheme.primary
              : AppColors.primary;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.cloud_download_outlined, color: primaryColor, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Google Drive Backups',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, null),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a backup to preview records and restore',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                if (currentList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No backups available',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: currentList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = currentList[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: primaryColor.withValues(alpha: 0.12),
                            child: Icon(Icons.insert_drive_file_outlined, color: primaryColor, size: 20),
                          ),
                          title: Text(
                            item['date'] ?? 'Backup',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Size: ${item['size']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () async {
                              final confirmDelete = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Cloud Backup?'),
                                  content: Text('Are you sure you want to permanently delete backup from ${item['date']}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmDelete == true) {
                                final deleted = await GoogleDriveService.deleteDriveBackup(item['id']!);
                                if (deleted) {
                                  setBottomSheetState(() {
                                    currentList.removeAt(index);
                                  });
                                }
                              }
                            },
                          ),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Backup Content Inspection Summary Modal before restoring
  Future<bool?> _showBackupContentPreviewModal(Map<String, dynamic> summary) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary != Colors.black
        ? Theme.of(context).colorScheme.primary
        : AppColors.primary;

    RestoreMode mode = RestoreMode.replaceAll;
    final isOlder = await GoogleDriveService.isBackupOlderThanLocal(summary);

    if (!mounted) return false;

    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.inventory_2_outlined, color: primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Backup Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOlder) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: This backup is older than your current transactions. Restoring will replace newer data.',
                              style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Metadata Breakdown
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildMetaRow(Icons.calendar_today, 'Backup Date', summary['exported_at'] ?? 'Unknown'),
                        const Divider(height: 12),
                        _buildMetaRow(Icons.phone_android, 'Device / App', '${summary['device']} (v${summary['appVersion']})'),
                        const Divider(height: 12),
                        _buildMetaRow(Icons.lock_outline, 'Encryption', '${summary['encryption']} (${summary['compression'].toString().toUpperCase()})'),
                        const Divider(height: 12),
                        _buildMetaRow(Icons.attach_money, 'Currency', summary['currency'] ?? 'USD'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Record Breakdown Grid
                  const Text('Records to Restore:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildStatRow(Icons.receipt_long, 'Transactions', summary['transactionsCount'].toString()),
                        const Divider(height: 12),
                        _buildStatRow(Icons.account_balance, 'Accounts', summary['accountsCount'].toString()),
                        const Divider(height: 12),
                        _buildStatRow(Icons.category_outlined, 'Categories', summary['categoriesCount'].toString()),
                        const Divider(height: 12),
                        _buildStatRow(Icons.pie_chart_outline, 'Budgets', summary['budgetsCount'].toString()),
                        if ((summary['mainAccountsCount'] ?? 0) > 0) ...[
                          const Divider(height: 12),
                          _buildStatRow(Icons.account_tree_outlined, 'Main Accounts', summary['mainAccountsCount'].toString()),
                        ],
                        if ((summary['notesCount'] ?? 0) > 0) ...[
                          const Divider(height: 12),
                          _buildStatRow(Icons.sticky_note_2_outlined, 'Scratchpad Notes', summary['notesCount'].toString()),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Restore Mode Strategy Chooser
                  const Text('Restore Strategy:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildStrategyOption(
                    currentMode: mode,
                    modeValue: RestoreMode.replaceAll,
                    title: 'Replace All Data (Recommended)',
                    subtitle: 'Wipes existing records to guarantee exact match with backup snapshot.',
                    primaryColor: primaryColor,
                    onTap: () => setModalState(() => mode = RestoreMode.replaceAll),
                  ),
                  _buildStrategyOption(
                    currentMode: mode,
                    modeValue: RestoreMode.merge,
                    title: 'Merge with Existing Data',
                    subtitle: 'Merges backup records alongside current database.',
                    primaryColor: primaryColor,
                    onTap: () => setModalState(() => mode = RestoreMode.merge),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  _selectedRestoreMode = mode;
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOlder ? Colors.amber.shade900 : primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Restore Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  RestoreMode _selectedRestoreMode = RestoreMode.replaceAll;

  Widget _buildStrategyOption({
    required RestoreMode currentMode,
    required RestoreMode modeValue,
    required String title,
    required String subtitle,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    final isSelected = currentMode == modeValue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? primaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showSuccessSnackBar({required IconData icon, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPremiumToggle({
    required bool value,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        width: 42,
        height: 22,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: isDark
              ? (value ? Colors.white : const Color(0xFF334155))
              : (value ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? (value ? const Color(0xFF0F172A) : Colors.white)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary != Colors.black
        ? Theme.of(context).colorScheme.primary
        : AppColors.primary;
    final isDriveEnabled = _googleAccountEmail != null;

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
          context.translate('backup_restore_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: _isLoadingState
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                          child: SvgPicture.asset(
                            'assets/icon/last_backup_icon.svg',
                            width: 22,
                            height: 22,
                            colorFilter: ColorFilter.mode(primaryColor, BlendMode.srcIn),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.translate('label_last_backup_status'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lastBackupTime == _kNeverBackedUp ? context.translate('never') : _lastBackupTime,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // E2E Security Badge Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AES-256 Client-Side Encrypted',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.green.shade400 : Colors.green.shade800,
                                ),
                              ),
                              Text(
                                'Your financial records are encrypted locally before upload.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.green.shade200 : Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Google Drive Backup Section
                  Text(
                    'GOOGLE DRIVE BACKUP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDriveEnabled
                                    ? primaryColor.withValues(alpha: 0.12)
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: SvgPicture.asset(
                                'assets/icon/google-drive-icon.svg',
                                width: 24,
                                height: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google Drive Backup',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isDriveEnabled
                                        ? 'Backup enabled & active'
                                        : 'Turn on to connect Google Account',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDriveEnabled
                                          ? Colors.green.shade600
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      fontWeight: isDriveEnabled ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                             _buildPremiumToggle(
                               value: isDriveEnabled,
                               isDark: isDark,
                               onTap: isDriveEnabled ? _disconnectGoogleAccount : _selectGoogleAccount,
                             ),
                          ],
                        ),

                        if (isDriveEnabled) ...[
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  'assets/icon/google.svg',
                                  width: 20,
                                  height: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Email',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    Text(
                                      _googleAccountEmail!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _switchGoogleAccount,
                                icon: const Icon(Icons.sync, size: 14),
                                label: const Text(
                                  'Switch',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Auto-Backup Frequency Section
                  Text(
                    'AUTOMATED BACKUP SCHEDULE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule automatic backups to your Google Drive:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFreqChip('off', 'Disabled'),
                            _buildFreqChip('daily', 'Daily'),
                            _buildFreqChip('weekly', 'Weekly'),
                            _buildFreqChip('monthly', 'Monthly'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Backup & Restore Actions Card
                  Text(
                    'CLOUD BACKUP & RESTORE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          CardActionItem(
                            title: 'Backup to Google Drive Now',
                            subtitle: 'Upload a fresh backup file to your Google account',
                            icon: Icons.cloud_upload_outlined,
                            isLoading: _isBackingUp,
                            progress: _backupProgress,
                            statusMessage: _backupStatusMessage,
                            onTap: _triggerDriveBackup,
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 72,
                          ),
                          CardActionItem(
                            title: 'Restore from Google Drive',
                            subtitle: 'Select and restore a backup from Google Drive',
                            icon: Icons.cloud_download_outlined,
                            isLoading: _isRestoring,
                            progress: null,
                            onTap: _triggerDriveRestore,
                            iconColor: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Offline / Local File Backup Section
                  Text(
                    'OFFLINE / LOCAL FILE BACKUP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          CardActionItem(
                            title: 'Export Encrypted Local File',
                            subtitle: 'Generate and share encrypted .enc file to device or storage',
                            icon: Icons.upload_file_outlined,
                            isLoading: _isBackingUp,
                            progress: _backupProgress,
                            statusMessage: _backupStatusMessage,
                            onTap: _triggerLocalBackup,
                            iconColor: Colors.teal,
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                            indent: 72,
                          ),
                          CardActionItem(
                            title: 'Restore from Local File',
                            subtitle: 'Select a saved .enc file from phone storage to restore',
                            icon: Icons.file_open_outlined,
                            isLoading: _isRestoring,
                            progress: null,
                            onTap: _triggerLocalRestore,
                            iconColor: Colors.indigo,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildFreqChip(String value, String label) {
    final isSelected = _autoBackupFrequency == value;
    final primaryColor = Theme.of(context).colorScheme.primary != Colors.black
        ? Theme.of(context).colorScheme.primary
        : AppColors.primary;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      onSelected: (_) => _updateAutoBackupFrequency(value),
    );
  }
}

class CardActionItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLoading;
  final double? progress;
  final String? statusMessage;
  final VoidCallback onTap;
  final Color? iconColor;

  const CardActionItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLoading,
    this.progress,
    this.statusMessage,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary != Colors.black
        ? Theme.of(context).colorScheme.primary
        : AppColors.primary;
    final color = iconColor ?? primaryColor;

    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (isLoading && progress != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: color.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                    if (statusMessage != null && statusMessage!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }
}
