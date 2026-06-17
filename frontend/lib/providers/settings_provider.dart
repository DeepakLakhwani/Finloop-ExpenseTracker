import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsProvider extends ChangeNotifier {
  String _currency = 'USD';

  static const Map<String, String> _currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
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

  String get currency {
    return _currencySymbols[_currency] ?? _currency;
  }

  String get currencyCode {
    if (_currencySymbols.containsKey(_currency)) {
      return _currency;
    }
    for (var entry in _currencySymbols.entries) {
      if (entry.value == _currency) {
        return entry.key;
      }
    }
    return _currency;
  }

  void setCurrency(String currency) async {
    String targetCode = currency;
    for (var entry in _currencySymbols.entries) {
      if (entry.value == currency) {
        targetCode = entry.key;
        break;
      }
    }

    _currency = targetCode;
    notifyListeners();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'defaultCurrency': targetCode,
        });
      } catch (e) {
        debugPrint('Error saving currency to Firestore: $e');
      }
    }
  }

  void loadSettings(String? currency) {
    if (currency != null) {
      String targetCode = currency;
      for (var entry in _currencySymbols.entries) {
        if (entry.value == currency) {
          targetCode = entry.key;
          break;
        }
      }
      _currency = targetCode;
      notifyListeners();
    }
  }
}
