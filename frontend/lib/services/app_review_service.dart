import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppReviewService {
  static const String _keyFirstLaunchDate = 'app_review_first_launch_date';
  static const String _keyAppOpenCount = 'app_review_app_open_count';
  static const String _keyLastPromptDate = 'app_review_last_prompt_date';
  static const String _keyHasRated = 'app_review_has_rated';

  /// Log an app open event and initialize review timing tracking if not already set.
  static Future<void> logAppOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Set first launch date if not already set
      if (!prefs.containsKey(_keyFirstLaunchDate)) {
        await prefs.setString(_keyFirstLaunchDate, DateTime.now().toIso8601String());
      }

      // 2. Increment app open count
      final currentOpenCount = prefs.getInt(_keyAppOpenCount) ?? 0;
      await prefs.setInt(_keyAppOpenCount, currentOpenCount + 1);

      debugPrint('[AppReviewService] Logged app open. Total opens: ${currentOpenCount + 1}');
    } catch (e) {
      debugPrint('[AppReviewService] Error logging app open: $e');
    }
  }

  /// Check if the user is eligible for an in-app review request.
  static Future<bool> isEligibleForReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. If user already rated, don't prompt
      if (prefs.getBool(_keyHasRated) ?? false) {
        return false;
      }

      // 2. Check time elapsed since first launch (5 days required)
      final firstLaunchStr = prefs.getString(_keyFirstLaunchDate);
      if (firstLaunchStr == null) return false;

      final firstLaunchDate = DateTime.parse(firstLaunchStr);
      final daysSinceLaunch = DateTime.now().difference(firstLaunchDate).inDays;
      if (daysSinceLaunch < 5) {
        debugPrint('[AppReviewService] Not eligible: launch was only $daysSinceLaunch days ago.');
        return false;
      }

      // 3. Check app open count (5 times required)
      final openCount = prefs.getInt(_keyAppOpenCount) ?? 0;
      if (openCount < 5) {
        debugPrint('[AppReviewService] Not eligible: app open count is $openCount.');
        return false;
      }

      // 4. Check time elapsed since last prompt (14 days required)
      final lastPromptStr = prefs.getString(_keyLastPromptDate);
      if (lastPromptStr != null) {
        final lastPromptDate = DateTime.parse(lastPromptStr);
        final daysSinceLastPrompt = DateTime.now().difference(lastPromptDate).inDays;
        if (daysSinceLastPrompt < 14) {
          debugPrint('[AppReviewService] Not eligible: last prompt was $daysSinceLastPrompt days ago.');
          return false;
        }
      }

      // 5. Verify if the In-App Review API is supported/available
      final isAvailable = await InAppReview.instance.isAvailable();
      if (!isAvailable) {
        debugPrint('[AppReviewService] Not eligible: In-App Review API is not available.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[AppReviewService] Error checking eligibility: $e');
      return false;
    }
  }

  /// Request the in-app review dialog if eligible.
  static Future<void> requestInAppReview() async {
    try {
      final isEligible = await isEligibleForReview();
      if (!isEligible) return;

      final prefs = await SharedPreferences.getInstance();
      
      // Request review
      await InAppReview.instance.requestReview();
      
      // Update last prompt date
      await prefs.setString(_keyLastPromptDate, DateTime.now().toIso8601String());
      debugPrint('[AppReviewService] In-app review requested successfully.');
    } catch (e) {
      debugPrint('[AppReviewService] Error requesting in-app review: $e');
    }
  }

  /// Redirect the user directly to the app store page.
  /// Also flags hasRated to true to prevent future passive prompts.
  static Future<void> openStoreListing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasRated, true);

      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.openStoreListing();
        debugPrint('[AppReviewService] Opened store listing natively.');
      } else {
        await _launchStoreUrl();
      }
    } catch (e) {
      debugPrint('[AppReviewService] Error opening store listing natively: $e. Trying fallback...');
      await _launchStoreUrl();
    }
  }

  static Future<void> _launchStoreUrl() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;
      
      Uri url;
      if (Platform.isAndroid) {
        url = Uri.parse('market://details?id=$packageName');
      } else if (Platform.isIOS) {
        url = Uri.parse('https://apps.apple.com/app/id$packageName');
      } else {
        url = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
      }

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('[AppReviewService] Could not launch store URL.');
        }
      }
    } catch (e) {
      debugPrint('[AppReviewService] Error launching store URL: $e');
    }
  }
}
