import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/security_service.dart';
import '../services/firestore_service.dart';
import 'passcode_lock_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Wait for 2 seconds for the splash branding effect
    await Future.delayed(const Duration(seconds: 2));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Sign in anonymously in the background to ensure uid exists for Firestore
        await FirebaseAuth.instance.signInAnonymously();
      }

      // Initialize the user doc and seed default categories & accounts
      if (FirebaseAuth.instance.currentUser != null) {
        final firestoreService = context.read<FirestoreService>();
        await firestoreService.initializeUser();
      } else {
        throw Exception(
          "Failed to acquire a secure session. Please check your internet connection.",
        );
      }
    } catch (e) {
      debugPrint("Error during anonymous initialization: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Unable to connect to Finloop.\nPlease check your network connection and try again.";
        });
      }
      return;
    }

    if (!mounted) return;

    final shouldLock = await SecurityService().shouldShowLockScreen();

    if (!mounted) return;

    if (shouldLock) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/lock_screen'),
          builder: (context) => const PasscodeLockScreen(),
        ),
      );
    } else {
      SecurityService().setSessionUnlocked(true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ClipOval(
                      child: SvgPicture.asset(
                        'assets/icon/app_icon_dark_512x512.svg',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Brand Name
                const _AnimatedBrandName(
                  text: 'FinLoop',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Tagline
                Text(
                  'FINANCIAL CLARITY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 20),

                // Divider Line
                Container(
                  width: 150,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(height: 30),

                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),

                if (_errorMessage != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _initializeApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Retry Connection',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bottom Encryption Text
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Securely encrypted by FinLoop Systems',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBrandName extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _AnimatedBrandName({required this.text, required this.style});

  @override
  State<_AnimatedBrandName> createState() => _AnimatedBrandNameState();
}

class _AnimatedBrandNameState extends State<_AnimatedBrandName>
    with TickerProviderStateMixin {
  static const Duration _letterDuration = Duration(milliseconds: 600);
  static const Duration _staggerDelay = Duration(milliseconds: 100);

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _slideAnimations;
  late final List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.text.length, (index) {
      final controller = AnimationController(
        vsync: this,
        duration: _letterDuration,
      );

      // Delay the start of each character's animation
      Future.delayed(_staggerDelay * index, () {
        if (mounted) {
          controller.forward();
        }
      });

      return controller;
    });

    _slideAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: -60.0,
        end: 0.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));
    }).toList();

    _fadeAnimations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.text.length, (index) {
        final char = widget.text[index];
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimations[index].value),
              child: Opacity(
                opacity: _fadeAnimations[index].value,
                child: Text(char, style: widget.style),
              ),
            );
          },
        );
      }),
    );
  }
}
