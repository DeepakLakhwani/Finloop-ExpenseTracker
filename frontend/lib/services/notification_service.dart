import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static const String _prefsKey = 'notifications_enabled';

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    if (enabled) {
      await requestPermissionsAndSchedule();
    } else {
      await cancelDailyReminder();
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz.initializeTimeZones();

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // iOS settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false, // will request explicitly below
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle when user taps notification (optional)
      },
    );

    _initialized = true;

    // Check if enabled before scheduling
    final enabled = await areNotificationsEnabled();
    if (enabled) {
      await requestPermissionsAndSchedule();
    } else {
      await cancelDailyReminder();
    }
  }

  Future<void> requestPermissionsAndSchedule() async {
    // Request permission for Android (13+)
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    // Request permission for iOS
    final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Schedule the daily reminder notification
    await scheduleDailyReminder();
  }

  Future<void> scheduleDailyReminder() async {
    // Android specifics
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminders',
      channelDescription: 'Reminders to log transactions daily',
      importance: Importance.max,
      priority: Priority.high,
    );

    // iOS specifics
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for 8:00 PM (20:00) every day
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      20, // 8 PM
      0,
    );

    // If it's already past 8 PM today, schedule it starting from tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      0, // Notification ID
      'Finloop Daily Reminder',
      'Have you recorded your transaction for today?',
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // Inexact scheduling to prevent SecurityException/crash on Android 12+
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Re-schedules daily
    );
  }

  Future<void> cancelDailyReminder() async {
    await _localNotifications.cancel(0);
  }

  Future<void> updateBackupReminder(String style) async {
    // Cancel any existing backup reminder notifications (ID 1)
    await _localNotifications.cancel(1);

    if (style == 'none') return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'backup_reminder_channel',
      'Backup Reminders',
      channelDescription: 'Reminders to back up your data',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);

    if (style == 'weekly') {
      // Schedule weekly reminder (e.g. every Sunday at 11:00 AM)
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        11,
        0,
      );

      int daysUntilSunday = (DateTime.sunday - scheduledTime.weekday + 7) % 7;
      if (daysUntilSunday == 0 && scheduledTime.isBefore(now)) {
        daysUntilSunday = 7;
      }
      scheduledTime = scheduledTime.add(Duration(days: daysUntilSunday));

      await _localNotifications.zonedSchedule(
        1,
        'Finloop Backup Reminder',
        'Keep your financial data safe by exporting a backup statement today.',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } else if (style == 'monthly') {
      // Schedule monthly reminder (e.g. on the 1st of every month at 11:00 AM)
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        1,
        11,
        0,
      );

      if (scheduledTime.isBefore(now)) {
        scheduledTime = tz.TZDateTime(
          tz.local,
          now.year,
          now.month + 1,
          1,
          11,
          0,
        );
      }

      await _localNotifications.zonedSchedule(
        1,
        'Finloop Backup Reminder',
        'Monthly backup reminder: keep your data secure by exporting a statement backup.',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  Future<void> sendInstantTestNotification() async {
    // Request permissions first to ensure it triggers
    await requestPermissionsAndSchedule();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'backup_reminder_channel',
      'Backup Reminders',
      channelDescription: 'Reminders to back up your data',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      99, // Test Notification ID
      'Finloop Backup Test',
      'This is an instant test notification for your backup reminder!',
      notificationDetails,
    );
  }
}
