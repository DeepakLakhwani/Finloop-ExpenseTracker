import 'package:flutter/material.dart';

class AppColors {
  // Theme state reference to dynamically serve correct primary color
  static ThemeMode themeMode = ThemeMode.light;

  // Primary color: white on dark theme, black on light theme
  static Color get primary {
    final bool isDark;
    if (themeMode == ThemeMode.system) {
      isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    } else {
      isDark = themeMode == ThemeMode.dark;
    }
    return isDark ? Colors.white : Colors.black;
  }

  // Secondary colors
  static const Color secondary = Color(0xFF0F172A);

  // Tertiary colors
  static const Color tertiary = Color(0xFF752C00);

  // Neutral colors
  static const Color neutral = Color(0xFF64748B);
  static const Color neutralLight = Color(0xFFF1F5F9);
  static const Color neutralDark = Color(0xFF475569);

  // Background colors
  static const Color backgroundLight = Color(
    0xFFF4F5F7,
  ); // Clean neutral off-white background color
  static const Color backgroundDark = Color(
    0xFF1A1919,
  ); // Premium charcoal background

  // Surface colors
  static const Color surfaceLight =
      Colors.white; // Exact light surface/card color
  static const Color surfaceDark = Color(
    0xFF242323,
  ); // Balanced charcoal card surface

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}
