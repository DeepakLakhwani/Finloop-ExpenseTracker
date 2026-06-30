import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final String? label;
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool isUnderline;

  const CustomTextField({
    super.key,
    this.label,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.isUnderline = false,
  });

  @override
  Widget build(BuildContext context) {
    final textThemeColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: textThemeColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          onTap: onTap,
          style: TextStyle(
            color: textThemeColor,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : AppColors.neutral,
              fontSize: 14,
            ),
            prefixIcon: prefixIcon != null ? IconTheme(
              data: IconThemeData(color: isDark ? Colors.white38 : AppColors.neutral),
              child: prefixIcon!,
            ) : null,
            suffixIcon: suffixIcon,
            filled: !isUnderline,
            fillColor: isUnderline 
                ? Colors.transparent 
                : (isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.neutralLight.withValues(alpha: 0.5)),
            border: isUnderline 
                ? UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white38 : AppColors.neutral, width: 1.2))
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
            enabledBorder: isUnderline 
                ? UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white38 : AppColors.neutral, width: 1.2))
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
            focusedBorder: isUnderline
                ? const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 2.5))
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
            errorBorder: isUnderline
                ? const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.error, width: 1.2))
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.error, width: 1),
                  ),
            contentPadding: isUnderline 
                ? const EdgeInsets.symmetric(vertical: 12)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
