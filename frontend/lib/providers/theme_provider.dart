import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _accentColorName = 'blue';

  static const Map<String, Color> accentColors = {
    'blue': Color(0xFF42A5F5),
    'green': Color(0xFF10B981),
    'orange': Color(0xFFF97316),
    'pink': Color(0xFFEC4899),
  };

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Color get accentColor => accentColors[_accentColorName] ?? const Color(0xFF42A5F5);
  String get accentColorName => _accentColorName;

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr = 'system';
      if (mode == ThemeMode.dark) modeStr = 'dark';
      if (mode == ThemeMode.light) modeStr = 'light';
      await prefs.setString('theme_mode', modeStr);
    } catch (e) {
      debugPrint('Error saving theme mode to SharedPreferences: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        String modeStr = 'system';
        if (mode == ThemeMode.dark) modeStr = 'dark';
        if (mode == ThemeMode.light) modeStr = 'light';
        
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'themeMode': modeStr,
        });
      } catch (e) {
        debugPrint('Error saving theme to Firestore: $e');
      }
    }
  }

  void setAccentColor(String colorName) async {
    if (!accentColors.containsKey(colorName)) return;
    _accentColorName = colorName;
    AppColors.primary = accentColor;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accent_color', colorName);
    } catch (e) {
      debugPrint('Error saving accent color to SharedPreferences: $e');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'accentColor': colorName,
        });
      } catch (e) {
        debugPrint('Error saving accent color to Firestore: $e');
      }
    }
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  void loadSettings(String? mode, [String? accent]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localMode = prefs.getString('theme_mode');
      final localAccent = prefs.getString('accent_color');
      
      if (localMode != null) {
        if (localMode == 'dark') _themeMode = ThemeMode.dark;
        else if (localMode == 'light') _themeMode = ThemeMode.light;
        else if (localMode == 'system') _themeMode = ThemeMode.system;
      }
      if (localAccent != null && accentColors.containsKey(localAccent)) {
        _accentColorName = localAccent;
        AppColors.primary = accentColor;
      }
    } catch (e) {
      debugPrint('Error loading theme settings from SharedPreferences: $e');
    }

    if (mode != null) {
      if (mode == 'dark') _themeMode = ThemeMode.dark;
      else if (mode == 'light') _themeMode = ThemeMode.light;
      else if (mode == 'system') _themeMode = ThemeMode.system;
    }
    if (accent != null && accentColors.containsKey(accent)) {
      _accentColorName = accent;
      AppColors.primary = accentColor;
    }
    notifyListeners();
  }
}
