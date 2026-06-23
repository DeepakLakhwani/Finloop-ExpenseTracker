import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class SettingsTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? status;

  const SettingsTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.neutralLight,
                    size: 20,
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
