import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum CustomButtonType { primary, secondary, inverted, outlined }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonType type;
  final bool isLoading;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CustomButtonType.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color foregroundColor;
    BorderSide borderSide = BorderSide.none;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case CustomButtonType.primary:
        backgroundColor = AppColors.primary;
        foregroundColor = Colors.white;
        break;
      case CustomButtonType.secondary:
        backgroundColor = isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.neutralLight;
        foregroundColor = isDark ? Colors.white : AppColors.secondary;
        break;
      case CustomButtonType.inverted:
        backgroundColor = isDark ? Colors.white : AppColors.secondary;
        foregroundColor = isDark ? AppColors.secondary : Colors.white;
        break;
      case CustomButtonType.outlined:
        backgroundColor = Colors.transparent;
        foregroundColor = isDark ? Colors.white : AppColors.secondary;
        borderSide = BorderSide(color: isDark ? Colors.white30 : AppColors.neutral, width: 1);
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: 56, // Fixed height for consistency
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.7),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.7),
          side: borderSide,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(text),
              ],
            ),
      ),
    );
  }
}
