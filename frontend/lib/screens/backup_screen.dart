import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../providers/language_provider.dart';

// Fix #1: Centralize magic string into a constant
const String _kNeverBackedUp = 'Never';
const String _kAutoBackupKey = 'auto_backup_enabled';
const String _kLastBackupTimeKey = 'last_backup_time';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _autoBackupEnabled = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String _lastBackupTime = _kNeverBackedUp;
  double _backupProgress = 0.0;

  // Fix #2: Use a Timer instead of looping Future.delayed to avoid blocking
  Timer? _backupTimer;

  @override
  void initState() {
    super.initState();
    _loadBackupSettings();
  }

  @override
  void dispose() {
    // Fix #3: Cancel timer on dispose to prevent setState after unmount
    _backupTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBackupSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _autoBackupEnabled = prefs.getBool(_kAutoBackupKey) ?? false;
        _lastBackupTime =
            prefs.getString(_kLastBackupTimeKey) ?? _kNeverBackedUp;
      });
    } catch (e) {
      debugPrint('Error loading backup settings: $e');
      // Fix #4: Show error to user, not just console
      if (!mounted) return;
      _showErrorSnackBar(context.translate('err_load_backup_settings'));
    }
  }

  Future<void> _toggleAutoBackup(bool value) async {
    setState(() {
      _autoBackupEnabled = value;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAutoBackupKey, value);
    } catch (e) {
      debugPrint('Error saving auto backup setting: $e');
      // Fix #5: Revert toggle on failure and inform the user
      if (!mounted) return;
      setState(() {
        _autoBackupEnabled = !value;
      });
      _showErrorSnackBar(context.translate('err_save_auto_backup'));
    }
  }

  Future<void> _triggerBackup() async {
    if (_isBackingUp || _isRestoring) return;

    // Fix #6: Reset progress before starting a new backup
    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.0;
    });

    // Fix #7: Use a Timer.periodic instead of a blocking loop with Future.delayed
    int step = 0;
    _backupTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) async {
      step++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _backupProgress = step / 10.0;
      });

      if (step >= 10) {
        timer.cancel();
        await _finalizeBackup();
      }
    });
  }

  Future<void> _finalizeBackup() async {
    final nowStr = DateFormat('MMM dd, yyyy, hh:mm a').format(DateTime.now());

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastBackupTimeKey, nowStr);
      if (!mounted) return;
      setState(() {
        _isBackingUp = false;
        _lastBackupTime = nowStr;
      });
      _showSuccessSnackBar(
        icon: Icons.check_circle_outline,
        message: context.translate('msg_backup_success'),
      );
    } catch (e) {
      debugPrint('Error saving last backup time: $e');
      // Fix #8: Show error and reset state on failure
      if (!mounted) return;
      setState(() {
        _isBackingUp = false;
        _backupProgress = 0.0;
      });
      _showErrorSnackBar(context.translate('err_backup_failed'));
    }
  }

  Future<void> _triggerRestore() async {
    if (_isBackingUp || _isRestoring) return;

    if (_lastBackupTime == _kNeverBackedUp) {
      _showWarningSnackBar(context.translate('err_no_backup_found'));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('title_restore_data')),
        content: Text(
          context.translate('restore_data_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.translate('restore'),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Fix #9: mounted check after async dialog gap
    if (!mounted) return;

    setState(() {
      _isRestoring = true;
    });

    try {
      // Simulate restore progress
      await Future.delayed(const Duration(seconds: 2));

      // Fix #10: mounted check after async gap before setState and SnackBar
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
      });

      _showSuccessSnackBar(
        icon: Icons.cloud_done_outlined,
        message: context.translate('msg_restore_success'),
      );
    } catch (e) {
      debugPrint('Error during restore: $e');
      if (!mounted) return;
      setState(() {
        _isRestoring = false;
      });
      _showErrorSnackBar(context.translate('err_restore_failed'));
    }
  }

  // Fix #11: Extracted snack bar helpers to reduce duplication
  void _showSuccessSnackBar({required IconData icon, required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

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
          context.translate('backup_restore_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text(
                  context.translate('label_auto_backup'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    // Fix #12: Replace deprecated withOpacity with withValues
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _autoBackupEnabled,
                    onChanged: _toggleAutoBackup,
                    activeThumbColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.translate('label_last_backup_status'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  _lastBackupTime == _kNeverBackedUp ? context.translate('never') : _lastBackupTime,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              context.translate('header_actions'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),

            // Back Up Now card
            CardActionItem(
              title: context.translate('btn_backup_now'),
              subtitle: context.translate('desc_backup_now'),
              icon: Icons.backup_outlined,
              isLoading: _isBackingUp,
              progress: _backupProgress,
              onTap: _triggerBackup,
            ),
            const SizedBox(height: 16),

            // Restore card
            CardActionItem(
              title: context.translate('title_restore_data'),
              subtitle: context.translate('desc_restore_data'),
              icon: Icons.settings_backup_restore_outlined,
              isLoading: _isRestoring,
              // Fix #14: Pass progress: null explicitly for restore (indeterminate spinner)
              progress: null,
              onTap: _triggerRestore,
              iconColor: Colors.orange,
            ),
          ],
        ),
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        // Fix #15: Replace withOpacity with withValues
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
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
                        color: (iconColor ?? AppColors.primary).withValues(
                          alpha: 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Fix #16: Show spinner for indeterminate loading (restore),
                    // hide chevron while loading for both backup and restore
                    if (isLoading && progress == null)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else if (!isLoading)
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                  ],
                ),
                if (isLoading && progress != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(progress! * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
