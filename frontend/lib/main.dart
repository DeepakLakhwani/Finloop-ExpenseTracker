import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/passcode_lock_screen.dart';
import 'services/security_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/language_provider.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/ad_service.dart';
import 'services/app_review_service.dart';
import 'services/google_drive_service.dart';
import 'theme/app_theme.dart';
import 'widgets/language_change_overlay.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_svg/flutter_svg.dart';

final GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  // Asynchronously precache the splash screen SVG asset during startup
  final loader = const SvgAssetLoader('assets/icon/Final_App_Icon_512x512.svg');
  svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  // Initialize Google Mobile Ads SDK
  await AdService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        Provider(create: (_) => FirestoreService()),
      ],
      child: const FinloopApp(),
    ),
  );
}

class FinloopApp extends StatefulWidget {
  const FinloopApp({super.key});

  @override
  State<FinloopApp> createState() => _FinloopAppState();
}

class _FinloopAppState extends State<FinloopApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppReviewService.logAppOpen();
    _loadInitialSettings();
    _initNotifications();
    _checkAutoBackup();
  }

  Future<void> _checkAutoBackup() async {
    try {
      await GoogleDriveService.checkAndRunAutoBackup();
    } catch (e) {
      debugPrint('Auto backup check error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final security = SecurityService();
    if (state == AppLifecycleState.paused) {
      // If an ad is currently showing, bypass background lock trigger
      if (AdService.isAdShowing) return;

      // Record closing timestamp when app goes to background
      await security.recordAppClosedTime();
    } else if (state == AppLifecycleState.resumed) {
      // If an ad was showing, bypass lock checks on resume
      if (AdService.isAdShowing) return;

      // If the app hasn't been unlocked initially, bypass background-lock logic.
      if (!security.isSessionUnlocked()) return;

      // App returned to foreground
      final shouldLock = await security.shouldShowLockScreen();
      if (shouldLock) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          bool isLockScreenVisible = false;
          // Look up if PasscodeLockScreen is already present in the navigator stack
          navigatorKey.currentState?.popUntil((route) {
            if (route.settings.name == '/lock_screen') {
              isLockScreenVisible = true;
            }
            return true;
          });

          if (!isLockScreenVisible) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                settings: const RouteSettings(name: '/lock_screen'),
                builder: (context) => const PasscodeLockScreen(),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _initNotifications() async {
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _loadInitialSettings() async {
    // 1. Instantly load local settings from SharedPreferences for immediate offline readiness
    if (mounted) {
      context.read<ThemeProvider>().loadSettings(null);
      context.read<LanguageProvider>().loadSettings(null);
      context.read<SettingsProvider>().loadSettings(null);
    }

    // 2. Sync user doc settings if available
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && mounted) {
          final data = userDoc.data()!;
          context.read<ThemeProvider>().loadSettings(
            data['themeMode'],
            data['accentColor'],
          );
          context.read<SettingsProvider>().loadSettings(
            data['defaultCurrency'],
            data,
          );
          context.read<LanguageProvider>().loadSettings(data['language']);
        }
      }
    } catch (e) {
      debugPrint('Error loading cloud initial settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    // Watch LanguageProvider so the app rebuilds and switches languages dynamically
    context.watch<LanguageProvider>();

    return MaterialApp(
      title: 'Finloop',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: snackbarKey,
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.getLightTheme(themeProvider.accentColor),
      darkTheme: AppTheme.getDarkTheme(themeProvider.accentColor),
      builder: (context, child) => LanguageChangeOverlay(child: child ?? const SizedBox()),
      home: const SplashScreen(),
    );
  }
}

OverlayEntry? _currentOverlay;

// Global utility for showing top notifications using Overlay (Does not push content)
void showTopNotification(String message, {bool isError = false}) {
  final navigatorState = navigatorKey.currentState;
  if (navigatorState == null) return;

  final overlay = navigatorState.overlay;
  if (overlay == null) return;

  final Color successGreen = const Color(0xFF2ECC71);
  final Color errorRed = const Color(0xFFE74C3C);

  // Remove existing overlay if any
  _currentOverlay?.remove();
  _currentOverlay = null;

  _currentOverlay = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          tween: Tween(begin: -120.0, end: 0.0),
          curve: Curves.decelerate,
          builder: (context, value, child) {
            return Transform.translate(offset: Offset(0, value), child: child);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isError ? errorRed : successGreen,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  overlay.insert(_currentOverlay!);

  final OverlayEntry myEntry = _currentOverlay!;

  // Auto-remove after 3 seconds
  Future.delayed(const Duration(seconds: 3), () {
    try {
      if (myEntry.mounted) {
        myEntry.remove();
      }
    } catch (_) {
      // Safely ignore if already removed or disposed
    }
    if (_currentOverlay == myEntry) {
      _currentOverlay = null;
    }
  });
}
