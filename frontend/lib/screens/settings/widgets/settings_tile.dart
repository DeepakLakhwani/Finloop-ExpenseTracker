import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? status;
  final Color? iconColor;
  final Color? iconBgColor;

  const SettingsTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.status,
    this.iconColor,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Crisp, prominent icon color matching the text.
    final finalIconColor = iconColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.85);

    return Container(
      color: Colors.transparent, // Let the Card handle the background color
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20, // Spacious padding matching the reference image
          vertical: 6,
        ),
        horizontalTitleGap: 16, // Elegant gap between icon and title
        onTap: onTap,
        leading: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: Icon(
              icon,
              color: finalIconColor,
              size: 22,
            ),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500, // Medium weight for crisp, legible text
            fontSize: 16, // Clean readable size
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        trailing: trailing ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status != null) ...[
                  Text(
                    status!,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.arrow_forward_rounded, // Precise horizontal arrow matching the image
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  size: 18,
                ),
              ],
            ),
      ),
    );
  }
}
