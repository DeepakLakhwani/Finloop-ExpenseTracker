import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
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

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  void loadSettings(String? mode) {
    if (mode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (mode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (mode == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }
}
