import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/language_provider.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/ad_service.dart';
import 'services/app_review_service.dart';
import 'theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  try {
    await Firebase.initializeApp();
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

class _FinloopAppState extends State<FinloopApp> {
  @override
  void initState() {
    super.initState();
    AppReviewService.logAppOpen();
    _loadInitialSettings();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _loadInitialSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && mounted) {
          final data = userDoc.data()!;
          context.read<ThemeProvider>().loadSettings(data['themeMode']);
          context.read<SettingsProvider>().loadSettings(
            data['defaultCurrency'],
          );
          context.read<LanguageProvider>().loadSettings(data['language']);
        }
      } else {
        // Even if user is not logged in, load language from SharedPreferences
        if (mounted) {
          context.read<LanguageProvider>().loadSettings(null);
        }
      }
    } catch (e) {
      debugPrint('Error loading initial settings: $e');
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
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
