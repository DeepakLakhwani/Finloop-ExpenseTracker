import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../providers/language_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurfaceColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.translate('privacy_policy'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: onSurfaceColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            Text(
              context.translate('privacy_policy_header_title'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: onSurfaceColor,
              ),
            ),
            const SizedBox(height: 8),
            // Effective Date
            Text(
              context.translate('privacy_policy_effective_date'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onSurfaceColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            // Welcome Description
            Text(
              context.translate('privacy_policy_welcome_desc'),
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: onSurfaceColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 32),

            // Policy Sections
            _buildSection(
              context,
              '1',
              context.translate('privacy_policy_sec_1_title'),
              context.translate('privacy_policy_sec_1_content'),
            ),
            _buildSection(
              context,
              '2',
              context.translate('privacy_policy_sec_2_title'),
              context.translate('privacy_policy_sec_2_content'),
            ),
            _buildSection(
              context,
              '3',
              context.translate('privacy_policy_sec_3_title'),
              context.translate('privacy_policy_sec_3_content'),
            ),
            _buildSection(
              context,
              '4',
              context.translate('privacy_policy_sec_4_title'),
              context.translate('privacy_policy_sec_4_content'),
            ),
            _buildSection(
              context,
              '5',
              context.translate('privacy_policy_sec_5_title'),
              context.translate('privacy_policy_sec_5_content'),
            ),
            _buildSection(
              context,
              '6',
              context.translate('privacy_policy_sec_6_title'),
              context.translate('privacy_policy_sec_6_content'),
            ),
            _buildSection(
              context,
              '7',
              context.translate('privacy_policy_sec_7_title'),
              context.translate('privacy_policy_sec_7_content'),
            ),
            _buildSection(
              context,
              '8',
              context.translate('privacy_policy_sec_8_title'),
              context.translate('privacy_policy_sec_8_content'),
            ),
            _buildSection(
              context,
              '9',
              context.translate('privacy_policy_sec_9_title'),
              context.translate('privacy_policy_sec_9_content'),
            ),
            _buildSection(
              context,
              '10',
              context.translate('privacy_policy_sec_10_title'),
              context.translate('privacy_policy_sec_10_content'),
            ),
            _buildSection(
              context,
              '11',
              context.translate('privacy_policy_sec_11_title'),
              context.translate('privacy_policy_sec_11_content'),
            ),
            _buildSection(
              context,
              '12',
              context.translate('privacy_policy_sec_12_title'),
              context.translate('privacy_policy_sec_12_content'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String index,
    String title,
    String content,
  ) {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final lines = content.split('\n');
    List<Widget> textWidgets = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        textWidgets.add(const SizedBox(height: 8));
        continue;
      }

      if (trimmed.startsWith('•') || trimmed.startsWith('-')) {
        // Bullet list item
        final text = trimmed.substring(1).trim();
        textWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: onSurfaceColor.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // If it's a subheader (e.g. short, or not ending with a period and followed by list items)
        final isSubheader = trimmed.length < 50 && !trimmed.endsWith('.');
        textWidgets.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: isSubheader ? 6 : 8,
              top: isSubheader ? 10 : 0,
            ),
            child: Text(
              trimmed,
              style: TextStyle(
                fontSize: isSubheader ? 15 : 14,
                fontWeight: isSubheader ? FontWeight.bold : FontWeight.normal,
                color: isSubheader
                    ? onSurfaceColor
                    : onSurfaceColor.withValues(alpha: 0.7),
                height: 1.45,
              ),
            ),
          ),
        );
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    index,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: onSurfaceColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Section parsed content
          ...textWidgets,
        ],
      ),
    );
  }
}
