import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import '../services/security_service.dart';
import '../services/notification_service.dart';
import 'passcode_setup_screen.dart';
import 'passcode_options_screen.dart';
import 'passcode_lock_screen.dart';
import 'import_export_screen.dart';
import 'feedback_screen.dart';
import 'settings/widgets/settings_tile.dart';
import 'settings/privacy_policy_screen.dart';
import 'settings/budgets_management_screen.dart';
import 'settings/general_settings_screen.dart';
import '../services/app_review_service.dart';

// Main settings hub (previously ProfileScreen in profile_screen.dart)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isPasscodeOn = false;

  @override
  void initState() {
    super.initState();
    _checkPasscodeStatus();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
      });
    }
  }

  Future<void> _checkPasscodeStatus() async {
    final hasPasscode = await SecurityService().hasPasscode();
    if (mounted) {
      setState(() {
        _isPasscodeOn = hasPasscode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers so the settings screen rebuilds when they change
    context.watch<SettingsProvider>();
    context.watch<ThemeProvider>();
    context.watch<LanguageProvider>();

    // Passcode Status
    final passcodeStatus = _isPasscodeOn ? 'On' : 'Off';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Account Settings Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.translate('app_settings').toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Theme.of(context).colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SettingsTile(
                      title: context.translate('general'),
                      icon: Icons.tune_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GeneralSettingsScreen(),
                        ),
                      ),
                    ),
                    SettingsTile(
                      title: context.translate('budgets'),
                      icon: Icons.track_changes_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BudgetsManagementScreen(),
                        ),
                      ),
                    ),
                    SettingsTile(
                      title: context.translate('passcode'),
                      icon: Icons.lock_outline,
                      onTap: () => _navigateToPasscode(context),
                      status: passcodeStatus,
                    ),
                    SettingsTile(
                      title: context.translate('backup'),
                      icon: Icons.cloud_upload_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ImportExportScreen(isBackupMode: true),
                          ),
                        );
                      },
                      status: 'Excel',
                    ),
                    SettingsTile(
                      title: context.translate('feedback'),
                      icon: Icons.feedback_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FeedbackScreen(),
                          ),
                        );
                      },
                    ),
                    SettingsTile(
                      title: context.translate('rate_us'),
                      icon: Icons.star_outline,
                      onTap: () {
                        AppReviewService.openStoreListing();
                      },
                    ),
                    SettingsTile(
                      title: context.translate('privacy_policy'),
                      icon: Icons.privacy_tip_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),
                    SettingsTile(
                      title: context.translate('notifications'),
                      icon: Icons.notifications_none,
                      onTap: () {},
                      trailing: Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _notificationsEnabled,
                          onChanged: (val) async {
                            setState(() => _notificationsEnabled = val);
                            await NotificationService().setNotificationsEnabled(
                              val,
                            );
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Version Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.translate('version_info'),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPasscode(BuildContext context) async {
    final hasPasscode = await SecurityService().hasPasscode();
    if (!context.mounted) return;

    if (hasPasscode) {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const PasscodeLockScreen(verificationOnly: true),
        ),
      );

      if (verified == true && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PasscodeOptionsScreen(),
          ),
        ).then((_) {
          _checkPasscodeStatus();
        });
      }
    } else {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const PasscodeSetupScreen()),
      );

      if (success == true && mounted) {
        // Immediately redirect to passcode settings options screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PasscodeOptionsScreen(),
          ),
        ).then((_) {
          _checkPasscodeStatus();
        });
      }
    }
  }
}
