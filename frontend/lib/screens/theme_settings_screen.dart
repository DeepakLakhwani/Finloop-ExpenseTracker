import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildThemeOption(
              context, 
              'System Default', 
              Icons.brightness_auto, 
              ThemeMode.system, 
              themeProvider.themeMode == ThemeMode.system
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              context, 
              'Light Mode', 
              Icons.light_mode, 
              ThemeMode.light, 
              themeProvider.themeMode == ThemeMode.light
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              context, 
              'Dark Mode', 
              Icons.dark_mode, 
              ThemeMode.dark, 
              themeProvider.themeMode == ThemeMode.dark
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, IconData icon, ThemeMode mode, bool isSelected) {
    const primaryColor = Color(0xFF1E17EB);
    
    return GestureDetector(
      onTap: () => context.read<ThemeProvider>().setThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? primaryColor : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(
              fontSize: 14, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? primaryColor : null,
            )),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: primaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
