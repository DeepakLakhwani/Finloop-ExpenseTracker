import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../providers/language_provider.dart';
import '../services/google_drive_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  Timer? _backupTimer;

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  @override
  void dispose() {
    _backupTimer?.cancel();
    super.dispose();
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

  Future<void> _toggleGoogleDriveBackup(bool enable) async {
    if (enable) {
      await _selectGoogleAccount();
    } else {
      await _disconnectGoogleAccount();
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

  Future<void> _triggerDriveBackup() async {
    if (_isBackingUp || _isRestoring) return;

    if (_googleAccountEmail == null) {
      await _selectGoogleAccount();
      if (_googleAccountEmail == null) return;
    }

    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.1;
    });

    int step = 1;
    _backupTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      setState(() {
        _backupProgress = (step / 10.0).clamp(0.1, 0.85);
      });
      if (step >= 8) {
        timer.cancel();
      }
    });

    final success = await GoogleDriveService.uploadBackupToDrive();
    _backupTimer?.cancel();

    if (!mounted) return;

    if (success) {
      final nowStr = DateFormat('MMM dd, yyyy, hh:mm a').format(DateTime.now());
      setState(() {
        _isBackingUp = false;
        _backupProgress = 1.0;
        _lastBackupTime = nowStr;
      });
      _showSuccessSnackBar(
        icon: Icons.cloud_done,
        message: context.translate('msg_backup_success'),
      );
    } else {
      setState(() {
        _isBackingUp = false;
        _backupProgress = 0.0;
      });
      _showErrorSnackBar(context.translate('err_backup_failed'));
    }
  }

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

    final selectedFileId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.cloud_download_outlined, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Select Backup to Restore',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: backups.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final b = backups[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
                ),
                title: Text(b['date'] ?? 'Backup', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Size: ${b['size']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                onTap: () => Navigator.pop(context, b['id']),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (selectedFileId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('title_restore_data')),
        content: Text(context.translate('restore_data_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.translate('restore'),
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _isRestoring = true);
    final success = await GoogleDriveService.restoreFromDrive(selectedFileId);
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
            fontSize: 20,
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
                          child: Icon(Icons.cloud_sync, color: primaryColor),
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
                                  fontSize: 15,
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
                  const SizedBox(height: 24),

                  // Google Drive Backup Section
                  Text(
                    'Google Drive Backup',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                                      fontSize: 16,
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
                            // Premium White Thumb Switch Toggle
                            Switch(
                              value: isDriveEnabled,
                              onChanged: _toggleGoogleDriveBackup,
                              activeThumbColor: Colors.white,
                              activeTrackColor: primaryColor,
                              inactiveThumbColor: isDark ? Colors.grey.shade400 : Colors.white,
                              inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
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
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    Text(
                                      _googleAccountEmail!,
                                      style: TextStyle(
                                        fontSize: 13,
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
                    'Automated Backup Schedule',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                            fontSize: 13,
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

                  // Google Drive Actions
                  Text(
                    'Backup & Restore Actions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
  final VoidCallback onTap;
  final Color? iconColor;

  const CardActionItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLoading,
    this.progress,
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
