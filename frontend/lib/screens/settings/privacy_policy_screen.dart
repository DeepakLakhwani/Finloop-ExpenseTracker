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
            // Top Welcome Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('privacy_policy_header_title'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.translate('privacy_policy_effective_date'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.translate('privacy_policy_welcome_desc'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    index,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: onSurfaceColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5, color: Colors.black12),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: onSurfaceColor.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
