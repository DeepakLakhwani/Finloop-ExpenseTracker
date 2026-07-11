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
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Color get accentColor => isDarkMode ? Colors.white : Colors.black;
  String get accentColorName => isDarkMode ? 'white' : 'black';

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    AppColors.themeMode = _themeMode;
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
    // Disabled accent color picker setting, it will always be dynamic opposite of the theme.
    notifyListeners();
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
      
      if (localMode != null) {
        if (localMode == 'dark') _themeMode = ThemeMode.dark;
        else if (localMode == 'light') _themeMode = ThemeMode.light;
        else if (localMode == 'system') _themeMode = ThemeMode.system;
      }
    } catch (e) {
      debugPrint('Error loading theme settings from SharedPreferences: $e');
    }

    if (mode != null) {
      if (mode == 'dark') _themeMode = ThemeMode.dark;
      else if (mode == 'light') _themeMode = ThemeMode.light;
      else if (mode == 'system') _themeMode = ThemeMode.system;
    }
    AppColors.themeMode = _themeMode;
    notifyListeners();
  }
}
