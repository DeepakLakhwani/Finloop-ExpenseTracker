import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../theme/app_colors.dart';

class LanguageChangeOverlay extends StatefulWidget {
  final Widget child;

  const LanguageChangeOverlay({super.key, required this.child});

  @override
  State<LanguageChangeOverlay> createState() => _LanguageChangeOverlayState();
}

class _LanguageChangeOverlayState extends State<LanguageChangeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 73,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 15,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.03).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.03, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 65,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          context.read<LanguageProvider>().completeLanguageChange();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final isChanging = languageProvider.isChangingLanguage;
    final targetLang = languageProvider.targetLanguageName ?? '';

    if (isChanging) {
      if (!_controller.isAnimating) {
        _controller.forward(from: 0.0);
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = Theme.of(context).colorScheme.primary != Colors.black
        ? Theme.of(context).colorScheme.primary
        : AppColors.primary;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Stack(
      children: [
        widget.child,
        if (isChanging)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final isTransparent = _fadeAnimation.value < 0.02;
                return IgnorePointer(
                  ignoring: isTransparent,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
                        child: Center(
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                width: 240,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: primaryBlue.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryBlue.withValues(alpha: 0.2),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: cardBg,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: primaryBlue,
                                              width: 3.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryBlue.withValues(alpha: 0.25),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: SvgPicture.asset(
                                              'assets/icon/Final_App_Icon_512x512.svg',
                                              width: 74,
                                              height: 74,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: primaryBlue,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.2),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.translate_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Changing Language',
                                      style: TextStyle(
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    if (targetLang.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        targetLang,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: 100,
                                      height: 3,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          backgroundColor: primaryBlue.withValues(alpha: 0.15),
                                          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
