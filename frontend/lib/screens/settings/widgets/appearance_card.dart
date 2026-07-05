import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/language_provider.dart';

class AppearanceCard extends StatelessWidget {
  const AppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.translate('header_choose_theme').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThemeOptionCard(
                  context,
                  context.translate('appearance_system'),
                  Icons.brightness_auto_outlined,
                  ThemeMode.system,
                  themeProvider.themeMode == ThemeMode.system,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildThemeOptionCard(
                  context,
                  context.translate('appearance_light'),
                  Icons.light_mode_outlined,
                  ThemeMode.light,
                  themeProvider.themeMode == ThemeMode.light,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildThemeOptionCard(
                  context,
                  context.translate('appearance_dark'),
                  Icons.dark_mode_outlined,
                  ThemeMode.dark,
                  themeProvider.themeMode == ThemeMode.dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOptionCard(
    BuildContext context,
    String label,
    IconData icon,
    ThemeMode mode,
    bool isSelected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => context.read<ThemeProvider>().setThemeMode(mode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : AppColors.neutralLight.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05)),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.white54 : AppColors.neutral),
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white70 : AppColors.neutralDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
