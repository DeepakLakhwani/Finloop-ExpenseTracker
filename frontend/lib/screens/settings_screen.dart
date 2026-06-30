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
    final settingsProvider = context.watch<SettingsProvider>();
    final currencySymbol = settingsProvider.currency;
    final currencyCode = settingsProvider.currencyCode;
    final languageProvider = context.watch<LanguageProvider>();

    // Appearance Status
    final themeMode = context.watch<ThemeProvider>().themeMode;
    String appearanceStatus = context.translate('appearance_system');
    if (themeMode == ThemeMode.light) {
      appearanceStatus = context.translate('appearance_light');
    } else if (themeMode == ThemeMode.dark) {
      appearanceStatus = context.translate('appearance_dark');
    }

    // Currency Status
    final currencyStatus = '$currencySymbol $currencyCode';

    // Passcode Status
    final passcodeStatus = _isPasscodeOn ? 'On' : 'Off';

    // Language Status
    final languageStatus =
        LanguageProvider.supportedLanguages[languageProvider.languageCode] ??
        'English';

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
                      title: context.translate('appearance'),
                      icon: Icons.palette_outlined,
                      onTap: _showAppearanceDialog,
                      status: appearanceStatus,
                    ),
                    SettingsTile(
                      title: context.translate('currency'),
                      icon: Icons.payments_outlined,
                      onTap: _showCurrencyDialog,
                      status: currencyStatus,
                    ),
                    SettingsTile(
                      title: context.translate('language'),
                      icon: Icons.language_outlined,
                      onTap: _showLanguageDialog,
                      status: languageStatus,
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

  void _showAppearanceDialog() {
    final themeProvider = context.read<ThemeProvider>();
    ThemeMode currentMode = themeProvider.themeMode;

    final List<Map<String, dynamic>> options = [
      {
        'mode': ThemeMode.system,
        'label': context.translate('appearance_system'),
        'icon': Icons.settings_brightness_outlined,
      },
      {
        'mode': ThemeMode.light,
        'label': context.translate('appearance_light'),
        'icon': Icons.light_mode_outlined,
      },
      {
        'mode': ThemeMode.dark,
        'label': context.translate('appearance_dark'),
        'icon': Icons.dark_mode_outlined,
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Text(
                    context.translate('appearance'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final item = options[index];
                    final ThemeMode mode = item['mode'];
                    final String label = item['label'];
                    final IconData icon = item['icon'];
                    final isSelected = currentMode == mode;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.08),
                        child: Icon(
                          icon,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        context.read<ThemeProvider>().setThemeMode(mode);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.translate('settings_saved')),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCurrencyDialog() {
    final settingsProvider = context.read<SettingsProvider>();
    String currentCurrency = settingsProvider.currencyCode;

    final List<Map<String, String>> currenciesList = [
      {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
      {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
      {'code': 'GBP', 'name': 'British Pound Sterling', 'symbol': '£'},
      {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
      {'code': 'CNY', 'name': 'Chinese Yuan Renminbi', 'symbol': '¥'},
      {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
      {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
      {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
      {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'Fr'},
      {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
      {'code': 'HKD', 'name': 'Hong Kong Dollar', 'symbol': 'HK\$'},
      {'code': 'NZD', 'name': 'New Zealand Dollar', 'symbol': 'NZ\$'},
      {'code': 'KRW', 'name': 'South Korean Won', 'symbol': '₩'},
      {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'د.إ'},
      {'code': 'SAR', 'name': 'Saudi Riyal', 'symbol': 'ر.س'},
      {'code': 'RUB', 'name': 'Russian Ruble', 'symbol': '₽'},
      {'code': 'THB', 'name': 'Thai Baht', 'symbol': '฿'},
      {'code': 'MYR', 'name': 'Malaysian Ringgit', 'symbol': 'RM'},
      {'code': 'ZAR', 'name': 'South African Rand', 'symbol': 'R'},
      {'code': 'TRY', 'name': 'Turkish Lira', 'symbol': '₺'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Text(
                    context.translate('select_currency'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: currenciesList.length,
                    itemBuilder: (context, index) {
                      final item = currenciesList[index];
                      final code = item['code']!;
                      final name = item['name']!;
                      final symbol = item['symbol']!;
                      final isSelected = currentCurrency == code;

                      final translatedName = context.translate(
                        'curr_${code.toLowerCase()}',
                      );
                      final displayName =
                          translatedName == 'curr_${code.toLowerCase()}'
                          ? name
                          : translatedName;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.08),
                          child: Text(
                            symbol,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          '$code - $displayName',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () {
                          context.read<SettingsProvider>().setCurrency(code);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.translate('settings_saved'),
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageDialog() {
    final languageProvider = context.read<LanguageProvider>();
    String currentLanguageCode = languageProvider.languageCode;

    final languages = LanguageProvider.supportedLanguages;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Text(
                    context.translate('select_language'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      final entry = languages.entries.elementAt(index);
                      final code = entry.key;
                      final name = entry.value;
                      final isSelected = currentLanguageCode == code;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.08),
                          child: Text(
                            code.toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () async {
                          await context.read<LanguageProvider>().setLanguage(
                            code,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.translate('settings_saved'),
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
