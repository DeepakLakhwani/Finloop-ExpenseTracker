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
      duration: const Duration(milliseconds: 3000),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 4,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 88,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 8,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.05).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 60,
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

    if (isChanging) {
      if (!_controller.isAnimating) {
        _controller.forward(from: 0.0);
      }
    }

    final primaryBlue = Theme.of(context).colorScheme.primary != Colors.black
        ? Theme.of(context).colorScheme.primary
        : AppColors.primary;

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
                    child: Material(
                      color: Colors.white,
                      child: SizedBox.expand(
                        child: Center(
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryBlue,
                                  width: 4.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryBlue.withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: ClipOval(
                                  child: SvgPicture.asset(
                                    'assets/icon/Final_App_Icon_512x512.svg',
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.cover,
                                  ),
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
