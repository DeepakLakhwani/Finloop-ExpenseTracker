import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import 'widgets/settings_tile.dart';

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

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
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

                    // Section 1: Theme
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

                    // Section 2: Accent Color
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
