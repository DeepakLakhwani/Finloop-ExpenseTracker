import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'translations/en.dart';
import 'translations/hi.dart';
import 'translations/gu.dart';
import 'translations/es.dart';
import 'translations/pt.dart';
import 'translations/fr.dart';
import 'translations/de.dart';
import 'translations/ja.dart';
import 'translations/ko.dart';
import 'translations/ar.dart';
import 'translations/ru.dart';
import 'translations/th.dart';
import 'translations/ms.dart';
import 'translations/tr.dart';

class LanguageProvider extends ChangeNotifier {
  String _languageCode = 'en';

  String get languageCode => _languageCode;

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'Hindi (हिन्दी)',
    'gu': 'Gujarati (ગુજરાતી)',
    'es': 'Spanish (Español)',
    'pt': 'Portuguese (Português)',
    'fr': 'French (Français)',
    'de': 'German (Deutsch)',
    'ja': 'Japanese (日本語)',
    'ko': 'Korean (한국어)',
    'ar': 'Arabic (العربية)',
    'ru': 'Russian (Русский)',
    'th': 'Thai (ไทย)',
    'ms': 'Malay (Bahasa Melayu)',
    'tr': 'Turkish (Türkçe)',
  };

  static const Map<String, Map<String, String>> _translations = {
    'en': enTranslations,
    'hi': hiTranslations,
    'gu': guTranslations,
    'es': esTranslations,
    'pt': ptTranslations,
    'fr': frTranslations,
    'de': deTranslations,
    'ja': jaTranslations,
    'ko': koTranslations,
    'ar': arTranslations,
    'ru': ruTranslations,
    'th': thTranslations,
    'ms': msTranslations,
    'tr': trTranslations,
  };

  String translate(String key) {
    return _translations[_languageCode]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguages.containsKey(code)) return;
    _languageCode = code;
    Intl.defaultLocale = code;
    notifyListeners();

    // Save to SharedPreferences for offline access
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('languageCode', code);
    } catch (e) {
      debugPrint('Error saving language to SharedPreferences: $e');
    }

    // Save to Firestore if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'language': code});
      } catch (e) {
        debugPrint('Error saving language to Firestore: $e');
      }
    }
  }

  Future<void> loadSettings(String? code) async {
    if (code != null && supportedLanguages.containsKey(code)) {
      _languageCode = code;
      Intl.defaultLocale = code;
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final localCode = prefs.getString('languageCode');
        if (localCode != null && supportedLanguages.containsKey(localCode)) {
          _languageCode = localCode;
          Intl.defaultLocale = localCode;
        }
      } catch (e) {
        debugPrint('Error loading language from SharedPreferences: $e');
      }
    }
    notifyListeners();
  }
}

extension LocalizationExtension on BuildContext {
  String translate(String key) {
    return Provider.of<LanguageProvider>(this, listen: false).translate(key);
  }

  /// Translates a category key, falling back to a default value (e.g. legacy name) if translation is missing.
  String getLocalizedCategory(String? key, String fallbackName) {
    if (key == null || key.isEmpty) return fallbackName;
    final translated = translate(key);
    // If the translation returns the key itself (which means it's missing), return the fallbackName
    if (translated == key) return fallbackName;
    return translated;
  }

  /// Localizes an account name dynamically if it is one of the default created accounts.
  String getLocalizedAccountName(String? name) {
    if (name == null || name.isEmpty) return translate('no_account');
    if (name == 'Account' || name == 'Bank Account') return translate('type_bank');
    if (name == 'Cash') return translate('type_cash');
    if (name == 'Card' || name == 'Credit Card') return translate('type_cards');
    return name;
  }

  /// Localizes an account type dynamically.
  String getLocalizedAccountType(String? type) {
    if (type == null || type.isEmpty) return '';
    if (type == 'Bank Account' || type == 'Account') return translate('type_bank');
    if (type == 'Cash') return translate('type_cash');
    if (type == 'Credit Card' || type == 'Card') return translate('type_cards');
    final key = 'type_${type.toLowerCase().replaceAll(' ', '_')}';
    final val = translate(key);
    return val == key ? type : val;
  }
}
