import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import 'widgets/settings_tile.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final list = await context.read<FirestoreService>().getAccountsList();
      if (mounted) {
        setState(() {
          _accounts = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading accounts for settings: $e');
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

    // Language Status
    final languageStatus =
        LanguageProvider.supportedLanguages[languageProvider.languageCode] ??
        'English';

    // Number format status
    final numberFormatStatus = settingsProvider.numberFormatStyle == 'comma_dot' ? '1,234.56' : '1.234,56';

    // Start day of week status
    final startDayOfWeekStatus = settingsProvider.startDayOfWeek == 'Monday'
        ? context.translate('monday')
        : context.translate('sunday');

    // Salary date status
    final salaryDateStatus = '${settingsProvider.salaryDate}';

    // Budget rollover status
    final budgetRolloverStatus = settingsProvider.budgetRollover
        ? context.translate('status_on')
        : context.translate('status_off');

    // Default account status
    String defaultAccountStatus = context.translate('settings_last_used');
    if (settingsProvider.defaultAccountId != 'Last Used') {
      final matched = _accounts.firstWhere(
        (a) => a['id'] == settingsProvider.defaultAccountId,
        orElse: () => <String, dynamic>{},
      );
      if (matched.isNotEmpty) {
        defaultAccountStatus = context.getLocalizedAccountName(matched['name']);
      }
    }

    // Backup reminder status
    String backupReminderStatus = context.translate('none');
    if (settingsProvider.backupReminder == 'weekly') {
      backupReminderStatus = context.translate('weekly');
    } else if (settingsProvider.backupReminder == 'monthly') {
      backupReminderStatus = context.translate('monthly');
    }

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
          context.translate('general'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        children: [
          // Section 1: Localization & Display
          _buildSectionHeader(context.translate('settings_general_localization')),
          _buildSectionCard(context, [
            SettingsTile(
              title: context.translate('appearance'),
              icon: Icons.palette_outlined,
              onTap: () => _showAppearanceDialog(context),
              status: appearanceStatus,
            ),
            SettingsTile(
              title: context.translate('currency'),
              icon: Icons.payments_outlined,
              onTap: () => _showCurrencyDialog(context),
              status: currencyStatus,
            ),
            SettingsTile(
              title: context.translate('language'),
              icon: Icons.language_outlined,
              onTap: () => _showLanguageDialog(context),
              status: languageStatus,
            ),
            SettingsTile(
              title: context.translate('settings_number_format'),
              icon: Icons.onetwothree_outlined,
              onTap: () => _showNumberFormatDialog(context),
              status: numberFormatStatus,
            ),
            SettingsTile(
              title: context.translate('settings_decimals'),
              icon: Icons.pin_outlined,
              onTap: () {},
              trailing: Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: settingsProvider.showDecimals,
                  onChanged: (val) {
                    settingsProvider.setShowDecimals(val);
                  },
                  activeColor: AppColors.primary,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Section 2: Calendar & Finance
          _buildSectionHeader(context.translate('settings_general_calendar_finance')),
          _buildSectionCard(context, [
            SettingsTile(
              title: context.translate('settings_start_day_of_week'),
              icon: Icons.calendar_view_week_outlined,
              onTap: () => _showStartDayOfWeekDialog(context),
              status: startDayOfWeekStatus,
            ),
            SettingsTile(
              title: context.translate('settings_salary_date'),
              icon: Icons.calendar_month_outlined,
              onTap: () => _showSalaryDateDialog(context),
              status: salaryDateStatus,
            ),
            SettingsTile(
              title: context.translate('settings_default_account'),
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => _showDefaultAccountDialog(context),
              status: defaultAccountStatus,
            ),
            SettingsTile(
              title: context.translate('settings_rollover'),
              icon: Icons.replay_outlined,
              onTap: () => _showBudgetRolloverDialog(context),
              status: budgetRolloverStatus,
            ),
          ]),
          const SizedBox(height: 16),

          // Section 3: Reminders
          _buildSectionHeader(context.translate('settings_general_reminders')),
          _buildSectionCard(context, [
            SettingsTile(
              title: context.translate('settings_backup_reminder'),
              icon: Icons.backup_outlined,
              onTap: () => _showBackupReminderDialog(context),
              status: backupReminderStatus,
            ),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 24), // Spacious gap between cards
      child: Text(
        _toTitleCase(title),
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

  // --- Dialogs ---

  void _showStartDayOfWeekDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final currentDay = settings.startDayOfWeek;

    final List<Map<String, dynamic>> options = [
      {
        'value': 'Monday',
        'label': context.translate('monday'),
        'icon': Icons.calendar_view_week,
      },
      {
        'value': 'Sunday',
        'label': context.translate('sunday'),
        'icon': Icons.calendar_today,
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.calendar_view_week_outlined,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.translate('settings_start_day_of_week'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose start day of the week',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final value = opt['value'] as String;
                  final label = opt['label'] as String;
                  final icon = opt['icon'] as IconData;
                  final isSelected = currentDay == value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        settings.setStartDayOfWeek(value);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.12 : 0.08,
                                )
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.02)
                                  : Colors.black.withValues(alpha: 0.01)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSelected)
                              Icon(
                                Icons.radio_button_checked,
                                color: AppColors.primary,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.radio_button_off,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.2),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSalaryDateDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.translate('settings_salary_date')),
          content: SizedBox(
            width: double.maxFinite,
            height: 250,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 31,
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = settings.salaryDate == day;
                return InkWell(
                  onTap: () {
                    settings.setSalaryDate(day);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDefaultAccountDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final currentId = settings.defaultAccountId;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.translate('settings_default_account'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose default transaction account',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Last Used option
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              settings.setDefaultAccountId('Last Used');
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: currentId == 'Last Used'
                                    ? AppColors.primary.withValues(
                                        alpha: isDark ? 0.12 : 0.08,
                                      )
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.02)
                                        : Colors.black.withValues(alpha: 0.01)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: currentId == 'Last Used'
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.08),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history,
                                    color: currentId == 'Last Used' ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      context.translate('settings_last_used'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: currentId == 'Last Used' ? FontWeight.bold : FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (currentId == 'Last Used')
                                    Icon(
                                      Icons.radio_button_checked,
                                      color: AppColors.primary,
                                      size: 20,
                                    )
                                  else
                                    Icon(
                                      Icons.radio_button_off,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.2),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Account list options
                        ..._accounts.map((acc) {
                          final id = acc['id']?.toString() ?? '';
                          final name = acc['name']?.toString() ?? '';
                          final isSelected = currentId == id;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                settings.setDefaultAccountId(id);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(
                                          alpha: isDark ? 0.12 : 0.08,
                                        )
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.02)
                                          : Colors.black.withValues(alpha: 0.01)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary.withValues(alpha: 0.5)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.08),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.account_balance,
                                      color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        context.getLocalizedAccountName(name),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isSelected)
                                      Icon(
                                        Icons.radio_button_checked,
                                        color: AppColors.primary,
                                        size: 20,
                                      )
                                    else
                                      Icon(
                                        Icons.radio_button_off,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.2),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBudgetRolloverDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final currentRollover = settings.budgetRollover;

    final List<Map<String, dynamic>> options = [
      {
        'value': true,
        'label': context.translate('status_on'),
        'icon': Icons.check_circle_outline,
        'color': AppColors.primary,
      },
      {
        'value': false,
        'label': context.translate('status_off'),
        'icon': Icons.cancel_outlined,
        'color': Colors.grey,
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.replay_outlined,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.translate('settings_rollover'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'About Budget Rollover',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Budget Rollover carries your remaining or exceeded budget amounts from the previous month over to the next month automatically to keep your finances continuous.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final value = opt['value'] as bool;
                  final label = opt['label'] as String;
                  final icon = opt['icon'] as IconData;
                  final color = opt['color'] as Color;
                  final isSelected = currentRollover == value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        settings.setBudgetRollover(value);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.12 : 0.08,
                                )
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.02)
                                  : Colors.black.withValues(alpha: 0.01)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? AppColors.primary : color.withValues(alpha: 0.6),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSelected)
                              Icon(
                                Icons.radio_button_checked,
                                color: AppColors.primary,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.radio_button_off,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.2),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNumberFormatDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final currentStyle = settings.numberFormatStyle;

    final List<Map<String, dynamic>> options = [
      {
        'value': 'comma_dot',
        'label': '1,234.56',
        'icon': Icons.onetwothree,
      },
      {
        'value': 'dot_comma',
        'label': '1.234,56',
        'icon': Icons.onetwothree,
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.onetwothree_outlined,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.translate('settings_number_format'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose number separator format',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final value = opt['value'] as String;
                  final label = opt['label'] as String;
                  final icon = opt['icon'] as IconData;
                  final isSelected = currentStyle == value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        settings.setNumberFormatStyle(value);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.12 : 0.08,
                                )
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.02)
                                  : Colors.black.withValues(alpha: 0.01)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              size: 22,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSelected)
                              Icon(
                                Icons.radio_button_checked,
                                color: AppColors.primary,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.radio_button_off,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.2),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBackupReminderDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final currentReminder = settings.backupReminder;

    final List<Map<String, dynamic>> options = [
      {
        'value': 'none',
        'label': context.translate('none'),
        'description': 'Disable automated alerts and handle backup manually',
        'icon': Icons.notifications_off_outlined,
        'color': Colors.grey,
      },
      {
        'value': 'weekly',
        'label': context.translate('weekly'),
        'description': 'Remind me to secure my records once a week',
        'icon': Icons.calendar_view_week_outlined,
        'color': AppColors.primary,
      },
      {
        'value': 'monthly',
        'label': context.translate('monthly'),
        'description': 'Remind me to back up at the end of each month',
        'icon': Icons.calendar_month_outlined,
        'color': Colors.blue,
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.backup_outlined,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.translate('settings_backup_reminder'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose how often to back up your data',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.08),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final value = opt['value'] as String;
                  final label = opt['label'] as String;
                  final desc = opt['description'] as String;
                  final icon = opt['icon'] as IconData;
                  final isSelected = currentReminder == value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () async {
                        settings.setBackupReminder(value);
                        Navigator.pop(context);

                        if (value != 'none') {
                          final bool isDebug = kDebugMode;
                          final String message = isDebug
                              ? '$label reminder set. A test notification has been sent!'
                              : '$label reminder set.';

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 4),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                          // Trigger a test notification that fires in 4 seconds only in debug mode
                          if (isDebug) {
                            await NotificationService().sendInstantTestNotification();
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(
                                  alpha: isDark ? 0.12 : 0.08,
                                )
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.02)
                                  : Colors.black.withValues(alpha: 0.01)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                icon,
                                color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 15,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.circle_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.25),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Reused Dialogs ---

  void _showAppearanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                final ThemeMode currentMode = themeProvider.themeMode;
                final String currentAccent = themeProvider.accentColorName;

                final List<Map<String, dynamic>> themeOptions = [
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

                final Map<String, Color> colorOptions =
                    ThemeProvider.accentColors;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Text(
                        context.translate('theme').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: themeOptions.length,
                      itemBuilder: (context, index) {
                        final item = themeOptions[index];
                        final ThemeMode mode = item['mode'];
                        final String label = item['label'];
                        final IconData icon = item['icon'];
                        final isSelected = currentMode == mode;

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.08),
                            child: Icon(
                              icon,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: themeProvider.accentColor,
                                )
                              : null,
                          onTap: () {
                            themeProvider.setThemeMode(mode);
                          },
                        );
                      },
                    ),

                    const Divider(),
                    const SizedBox(height: 4),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Text(
                        context.translate('accent_color').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: colorOptions.entries.map((entry) {
                          final name = entry.key;
                          final color = entry.value;
                          final isSelected = currentAccent == name;

                          return GestureDetector(
                            onTap: () {
                              themeProvider.setAccentColor(name);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        width: 3,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    String currentCurrency = settingsProvider.currencyCode;

    final List<Map<String, String>> currenciesList = [
      {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
      {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
      {'code': 'GBP', 'name': 'British Pound Sterling', 'symbol': '£'},
      {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
      {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
      {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
      {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
      {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'Fr'},
      {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
      {'code': 'HKD', 'name': 'Hong Kong Dollar', 'symbol': 'HK\$'},
      {'code': 'NZD', 'name': 'New Zealand Dollar', 'symbol': 'NZ\$'},
      {'code': 'KRW', 'name': 'South Korean Won', 'symbol': '₩'},
      {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'د.إ'},
      {'code': 'SAR', 'name': 'Saudi Riyal', 'symbol': 'ر.स'},
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
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          context.read<SettingsProvider>().setCurrency(code);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.translate('settings_saved'),
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
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

  void _showLanguageDialog(BuildContext context) {
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
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              )
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
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
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
}
