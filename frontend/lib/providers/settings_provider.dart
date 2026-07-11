import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  String _currency = 'USD';
  String _startDayOfWeek = 'Monday';
  int _salaryDate = 1;
  String _defaultAccountId = 'Last Used';
  bool _budgetRollover = false;
  bool _showDecimals = true;
  String _numberFormatStyle = 'comma_dot';
  String _backupReminder = 'none';

  static const Map<String, String> _currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'INR': '₹',
    'CAD': 'C\$',
    'AUD': 'A\$',
    'CHF': 'Fr',
    'SGD': 'S\$',
    'HKD': 'HK\$',
    'NZD': 'NZ\$',
    'KRW': '₩',
    'AED': 'د.إ',
    'SAR': 'ر.س',
    'RUB': '₽',
    'THB': '฿',
    'MYR': 'RM',
    'ZAR': 'R',
    'TRY': '₺',
  };

  // Getters
  String get currency => _currencySymbols[_currency] ?? _currency;
  String get currencyCode => _currency;
  String get startDayOfWeek => _startDayOfWeek;
  int get salaryDate => _salaryDate;
  String get defaultAccountId => _defaultAccountId;
  bool get budgetRollover => _budgetRollover;
  bool get showDecimals => _showDecimals;
  String get numberFormatStyle => _numberFormatStyle;
  String get backupReminder => _backupReminder;

  // Amount formatter helper
  String formatAmount(double amount) {
    final pattern = _showDecimals ? '#,##0.00' : '#,##0';
    if (_numberFormatStyle == 'dot_comma') {
      final formatted = NumberFormat(pattern, 'en_US').format(amount);
      if (!_showDecimals) {
        return formatted.replaceAll(',', '.');
      } else {
        return formatted.replaceAll(',', '_').replaceAll('.', ',').replaceAll('_', '.');
      }
    } else {
      return NumberFormat(pattern, 'en_US').format(amount);
    }
  }

  // Setters
  void setCurrency(String code) async {
    _currency = code;
    notifyListeners();
    await _saveLocal('settings_currency', code);
    await _saveRemote('defaultCurrency', code);
  }

  void setStartDayOfWeek(String value) async {
    _startDayOfWeek = value;
    notifyListeners();
    await _saveLocal('settings_start_day_of_week', value);
    await _saveRemote('startDayOfWeek', value);
  }

  void setSalaryDate(int value) async {
    _salaryDate = value;
    notifyListeners();
    await _saveLocalInt('settings_salary_date', value);
    await _saveRemote('salaryDate', value);
  }

  void setDefaultAccountId(String value) async {
    _defaultAccountId = value;
    notifyListeners();
    await _saveLocal('settings_default_account_id', value);
    await _saveRemote('defaultAccountId', value);
  }

  void setBudgetRollover(bool value) async {
    _budgetRollover = value;
    notifyListeners();
    await _saveLocalBool('settings_budget_rollover', value);
    await _saveRemote('budgetRollover', value);
  }

  void setShowDecimals(bool value) async {
    _showDecimals = value;
    notifyListeners();
    await _saveLocalBool('settings_show_decimals', value);
    await _saveRemote('showDecimals', value);
  }

  void setNumberFormatStyle(String value) async {
    _numberFormatStyle = value;
    notifyListeners();
    await _saveLocal('settings_number_format_style', value);
    await _saveRemote('numberFormatStyle', value);
  }

  void setBackupReminder(String value) async {
    _backupReminder = value;
    notifyListeners();
    await _saveLocal('settings_backup_reminder', value);
    await _saveRemote('backupReminder', value);
    await NotificationService().updateBackupReminder(value);
  }

  // Save Helpers
  Future<void> _saveLocal(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('Error saving $key locally: $e');
    }
  }

  Future<void> _saveLocalInt(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      debugPrint('Error saving $key locally: $e');
    }
  }

  Future<void> _saveLocalBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Error saving $key locally: $e');
    }
  }

  Future<void> _saveRemote(String key, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          key: value,
        });
      } catch (e) {
        debugPrint('Error saving $key remotely: $e');
      }
    }
  }

  bool isDateInFocusedMonth(DateTime date, DateTime focusedDate) {
    if (_salaryDate == 1) {
      return date.year == focusedDate.year && date.month == focusedDate.month;
    }
    final start = DateTime(focusedDate.year, focusedDate.month, _salaryDate);
    final end = DateTime(focusedDate.year, focusedDate.month + 1, _salaryDate);
    return (date.isAtSameMomentAs(start) || date.isAfter(start)) && date.isBefore(end);
  }

  // Load Settings
  void loadSettings(String? currencyCodeFromFirestore, [Map<String, dynamic>? firestoreData]) async {
    // 1. Load from SharedPreferences first
    try {
      final prefs = await SharedPreferences.getInstance();
      _currency = prefs.getString('settings_currency') ?? _currency;
      _startDayOfWeek = prefs.getString('settings_start_day_of_week') ?? _startDayOfWeek;
      _salaryDate = prefs.getInt('settings_salary_date') ?? _salaryDate;
      _defaultAccountId = prefs.getString('settings_default_account_id') ?? _defaultAccountId;
      _budgetRollover = prefs.getBool('settings_budget_rollover') ?? _budgetRollover;
      _showDecimals = prefs.getBool('settings_show_decimals') ?? _showDecimals;
      _numberFormatStyle = prefs.getString('settings_number_format_style') ?? _numberFormatStyle;
      _backupReminder = prefs.getString('settings_backup_reminder') ?? _backupReminder;
    } catch (e) {
      debugPrint('Error loading local settings: $e');
    }

    // 2. Override with Firestore data if present
    if (currencyCodeFromFirestore != null) {
      _currency = currencyCodeFromFirestore;
    }
    if (firestoreData != null) {
      _startDayOfWeek = firestoreData['startDayOfWeek'] ?? _startDayOfWeek;
      _salaryDate = firestoreData['salaryDate'] ?? _salaryDate;
      _defaultAccountId = firestoreData['defaultAccountId'] ?? _defaultAccountId;
      _budgetRollover = firestoreData['budgetRollover'] ?? _budgetRollover;
      _showDecimals = firestoreData['showDecimals'] ?? _showDecimals;
      _numberFormatStyle = firestoreData['numberFormatStyle'] ?? _numberFormatStyle;
      _backupReminder = firestoreData['backupReminder'] ?? _backupReminder;
    }
    notifyListeners();
    NotificationService().updateBackupReminder(_backupReminder);
  }
}

extension FormatExtension on BuildContext {
  String formatAmount(double amount, {bool listen = true}) {
    return Provider.of<SettingsProvider>(this, listen: listen).formatAmount(amount);
  }
}
