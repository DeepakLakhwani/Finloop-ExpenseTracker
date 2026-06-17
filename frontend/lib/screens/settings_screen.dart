import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../services/security_service.dart';
import 'passcode_setup_screen.dart';
import 'passcode_options_screen.dart';
import 'import_export_screen.dart';
import 'feedback_screen.dart';
import 'settings/widgets/settings_tile.dart';
import 'settings/widgets/appearance_card.dart';
import 'settings/currency_settings_screen.dart';
import 'settings/privacy_policy_screen.dart';

// Main settings hub (previously ProfileScreen in profile_screen.dart)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isPasscodeOn = false;
  bool _showAppearanceOptions = false;

  @override
  void initState() {
    super.initState();
    _checkPasscodeStatus();
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
    final settingsProvider = context.watch<SettingsProvider>();
    final currencySymbol = settingsProvider.currency;
    final currencyCode = settingsProvider.currencyCode;

    // Appearance Status
    final themeMode = context.watch<ThemeProvider>().themeMode;
    String appearanceStatus = 'System';
    if (themeMode == ThemeMode.light) {
      appearanceStatus = 'Light';
    } else if (themeMode == ThemeMode.dark) {
      appearanceStatus = 'Dark';
    }

    // Currency Status
    final currencyStatus = '$currencySymbol $currencyCode';

    // Passcode Status
    final passcodeStatus = _isPasscodeOn ? 'On' : 'Off';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Account Settings Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SettingsTile(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                onTap: () => setState(
                  () => _showAppearanceOptions = !_showAppearanceOptions,
                ),
                status: appearanceStatus,
              ),
              if (_showAppearanceOptions) ...[
                const AppearanceCard(),
                const SizedBox(height: 12),
              ],
              SettingsTile(
                title: 'Currency',
                icon: Icons.payments_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CurrencySettingsScreen(),
                  ),
                ),
                status: currencyStatus,
              ),
              SettingsTile(
                title: 'Passcode',
                icon: Icons.lock_outline,
                onTap: () => _navigateToPasscode(context),
                status: passcodeStatus,
              ),
              SettingsTile(
                title: 'Backup',
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
                title: 'Feedback',
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
                title: 'Privacy Policy',
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
                title: 'Notifications',
                icon: Icons.notifications_none,
                onTap: () {},
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _notificationsEnabled,
                    onChanged: (val) =>
                        setState(() => _notificationsEnabled = val),
                    activeThumbColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Version Info
              const Text(
                'FinLoop Version 1.0.0 (1)',
                style: TextStyle(color: AppColors.neutralLight, fontSize: 11),
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PasscodeOptionsScreen()),
      ).then((_) {
        _checkPasscodeStatus();
      });
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
