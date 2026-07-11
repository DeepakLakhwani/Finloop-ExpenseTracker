import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
import 'settings/faq_screen.dart';
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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _checkPasscodeStatus();
    _checkNotificationStatus();
    _loadAppVersion();
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

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (_) {}
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildSectionHeader(context, 'app_settings'),
              _buildSectionCard(context, [
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
              ]),
              const SizedBox(height: 8),

              _buildSectionHeader(context, 'security_and_data'),
              _buildSectionCard(context, [
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
              ]),
              const SizedBox(height: 8),

              _buildSectionHeader(context, 'support_and_feedback'),
              _buildSectionCard(context, [
                SettingsTile(
                  title: context.translate('faq'),
                  icon: Icons.help_outline,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FaqScreen(),
                      ),
                    );
                  },
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
              ]),
              const SizedBox(height: 8),

              _buildSectionHeader(context, 'about'),
              _buildSectionCard(context, [
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
              ]),
              const SizedBox(height: 24),
              
              // Version Info
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _appVersion.isNotEmpty
                      ? context.translate('version_info').replaceAll('1.0.0 (1)', _appVersion)
                      : context.translate('version_info'),
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

  Widget _buildSectionHeader(BuildContext context, String titleKey) {
    String title = context.translate(titleKey);
    if (title.toUpperCase() == "SETTINGS") {
      title = "Settings";
    } else {
      title = _toTitleCase(title);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500, // Medium weight for header text
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45), // Sleek, modern grey
        ),
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildSectionCard(BuildContext context, List<Widget> children) {
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
            indent: 60, // Perfectly aligns with the start of the title text
          ),
        );
      }
    }

    return Container(
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
