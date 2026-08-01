import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../providers/language_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final List<Map<String, dynamic>> sections = [
      {
        'index': '1',
        'icon': Icons.assignment_outlined,
        'titleKey': 'privacy_policy_sec_1_title',
        'contentKey': 'privacy_policy_sec_1_content',
      },
      {
        'index': '2',
        'icon': Icons.auto_graph_outlined,
        'titleKey': 'privacy_policy_sec_2_title',
        'contentKey': 'privacy_policy_sec_2_content',
      },
      {
        'index': '3',
        'icon': Icons.cloud_sync_outlined,
        'titleKey': 'privacy_policy_sec_3_title',
        'contentKey': 'privacy_policy_sec_3_content',
      },
      {
        'index': '4',
        'icon': Icons.share_outlined,
        'titleKey': 'privacy_policy_sec_4_title',
        'contentKey': 'privacy_policy_sec_4_content',
      },
      {
        'index': '5',
        'icon': Icons.verified_user_outlined,
        'titleKey': 'privacy_policy_sec_5_title',
        'contentKey': 'privacy_policy_sec_5_content',
      },
      {
        'index': '6',
        'icon': Icons.import_export_outlined,
        'titleKey': 'privacy_policy_sec_6_title',
        'contentKey': 'privacy_policy_sec_6_content',
      },
      {
        'index': '7',
        'icon': Icons.notifications_none_outlined,
        'titleKey': 'privacy_policy_sec_7_title',
        'contentKey': 'privacy_policy_sec_7_content',
      },
      {
        'index': '8',
        'icon': Icons.fingerprint_outlined,
        'titleKey': 'privacy_policy_sec_8_title',
        'contentKey': 'privacy_policy_sec_8_content',
      },
      {
        'index': '9',
        'icon': Icons.child_care_outlined,
        'titleKey': 'privacy_policy_sec_9_title',
        'contentKey': 'privacy_policy_sec_9_content',
      },
      {
        'index': '10',
        'icon': Icons.admin_panel_settings_outlined,
        'titleKey': 'privacy_policy_sec_10_title',
        'contentKey': 'privacy_policy_sec_10_content',
      },
      {
        'index': '11',
        'icon': Icons.update_outlined,
        'titleKey': 'privacy_policy_sec_11_title',
        'contentKey': 'privacy_policy_sec_11_content',
      },
      {
        'index': '12',
        'icon': Icons.mail_outline,
        'titleKey': 'privacy_policy_sec_12_title',
        'contentKey': 'privacy_policy_sec_12_content',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.translate('privacy_policy'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.translate('privacy_policy_header_title'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                context.translate('privacy_policy_effective_date'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: cs.onSurface.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.translate('privacy_policy_welcome_desc'),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Policy Section Cards
            ...sections.map((sec) {
              return _buildSectionCard(
                context,
                sec['index'] as String,
                sec['icon'] as IconData,
                context.translate(sec['titleKey'] as String),
                context.translate(sec['contentKey'] as String),
                isDark,
              );
            }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String index,
    IconData icon,
    String title,
    String content,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lines = content.split('\n');
    final List<Widget> parsedWidgets = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        parsedWidgets.add(const SizedBox(height: 6));
        continue;
      }

      if (trimmed.startsWith('•') || trimmed.startsWith('-')) {
        final bulletText = trimmed.substring(1).trim();
        parsedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    bulletText,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        final isSubheader = trimmed.length < 55 && !trimmed.endsWith('.');
        parsedWidgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: isSubheader ? 10 : 0,
              bottom: isSubheader ? 6 : 8,
            ),
            child: Text(
              trimmed,
              style: TextStyle(
                fontSize: isSubheader ? 14 : 13.5,
                fontWeight: isSubheader ? FontWeight.bold : FontWeight.normal,
                color: isSubheader
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.75),
                height: 1.45,
              ),
            ),
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$index',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.onSurface.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 12),
          // Content items
          ...parsedWidgets,
        ],
      ),
    );
  }
}
