import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

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
          'Privacy Policy',
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
                    AppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'FinLoop Privacy Policy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Effective Date: May 26, 2026',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your privacy is important to us. This Privacy Policy explains how FinLoop collects, uses, stores, and protects your information when you use the application.',
                    style: TextStyle(
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
              'Information We Collect',
              'Personal Financial Information\nFinLoop may store:\n• Transactions\n• Categories\n• Account names\n• Balances\n• Notes\n• Budget records\n\nThis information is stored solely for app functionality.\n\nDevice Information\nWe may collect:\n• Device type\n• Operating system version\n• App version\n• Crash logs\n\nfor improving app stability and performance.\n\nAuthentication Information\nIf enabled by the user:\n• Biometric authentication\n• Passcode settings\n\nare securely handled using device-level security systems.\n\nFinLoop does NOT store raw fingerprint or Face ID data.',
            ),
            _buildSection(
              context,
              '2',
              'How We Use Your Information',
              'We use your data to:\n• Provide finance tracking features\n• Generate analytics\n• Sync notes and records\n• Improve app performance\n• Secure user accounts\n• Enable export/import functionality',
            ),
            _buildSection(
              context,
              '3',
              'Data Storage',
              'Local Storage\nMost financial information is stored locally on the user\'s device.\n\nCloud Synchronization\nCertain features such as:\n• Scratchpad notes\n• Optional backups\n• Sync services\n\nmay use secure cloud infrastructure such as Firebase Firestore.',
            ),
            _buildSection(
              context,
              '4',
              'Data Sharing',
              'FinLoop does NOT sell user data.\n\nWe do NOT share personal financial information with third parties except:\n• When required by law\n• When necessary for app functionality\n• With secure infrastructure providers',
            ),
            _buildSection(
              context,
              '5',
              'Data Security',
              'We implement:\n• Secure local storage\n• Encrypted authentication methods\n• Device-level biometric protection\n• Secure Firebase communication\n\nHowever, no system can guarantee absolute security.',
            ),
            _buildSection(
              context,
              '6',
              'Excel Import & Export',
              'Users can:\n• Export financial data to Excel files\n• Share exported files externally\n\nUsers are responsible for protecting exported files shared outside the app.',
            ),
            _buildSection(
              context,
              '7',
              'Notifications',
              'FinLoop may send:\n• Financial reminders\n• App-related alerts\n• Local notifications\n\nUsers can disable notifications anytime through settings.',
            ),
            _buildSection(
              context,
              '8',
              'Biometric Authentication',
              'Biometric authentication is optional.\n\nFingerprint and Face ID data are processed only through the device operating system and are never directly accessed or stored by FinLoop.',
            ),
            _buildSection(
              context,
              '9',
              'Children\'s Privacy',
              'FinLoop is not intended for children under 13 years of age.\n\nWe do not knowingly collect information from children.',
            ),
            _buildSection(
              context,
              '10',
              'User Rights',
              'Users may:\n• Delete app data\n• Disable cloud synchronization\n• Remove passcodes\n• Export their data\n• Uninstall the application anytime',
            ),
            _buildSection(
              context,
              '11',
              'Changes to This Privacy Policy',
              'We may update this Privacy Policy periodically. Users are encouraged to review this page regularly.',
            ),
            _buildSection(
              context,
              '12',
              'Contact Information',
              'For questions regarding this Privacy Policy:\n\nEmail: support.finloop@gmail.com',
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
        border: Border.all(color: Colors.black.withOpacity(0.05)),
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
                  color: AppColors.primary.withOpacity(0.1),
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
              color: onSurfaceColor.withOpacity(0.65),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
