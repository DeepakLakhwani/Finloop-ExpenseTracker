import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';
import 'passcode_lock_screen.dart';
import 'passcode_setup_screen.dart';
import '../providers/language_provider.dart';

class PasscodeOptionsScreen extends StatefulWidget {
  const PasscodeOptionsScreen({super.key});

  @override
  State<PasscodeOptionsScreen> createState() => _PasscodeOptionsScreenState();
}

class _PasscodeOptionsScreenState extends State<PasscodeOptionsScreen> {
  final SecurityService _securityService = SecurityService();
  final BiometricService _biometricService = BiometricService();

  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _biometricService.stopAuthentication();
    super.dispose();
  }

  void _loadSettings() async {
    final enabled = await _securityService.isBiometricEnabled();
    final available = await _biometricService.isBiometricAvailable();
    setState(() {
      _biometricEnabled = enabled;
      _biometricAvailable = available;
    });
  }

  void _verifyAndTurnOff() async {
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PasscodeLockScreen(verificationOnly: true),
      ),
    );

    if (verified == true) {
      await _securityService.clearPasscode();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                context.translate('msg_passcode_disabled'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  void _verifyAndChange() async {
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PasscodeLockScreen(verificationOnly: true),
      ),
    );

    if (verified == true && mounted) {
      // Go to setup screen
      final setupSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const PasscodeSetupScreen()),
      );

      if (setupSuccess == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  void _toggleBiometric(bool val) async {
    if (val) {
      // Prompt biometric authentication first to verify fingerprint works
      final success = await _biometricService.authenticate();
      if (success) {
        await _securityService.setBiometricEnabled(true);
        setState(() {
          _biometricEnabled = true;
        });
      } else {
        setState(() {
          _biometricEnabled = false;
        });
      }
    } else {
      await _securityService.setBiometricEnabled(false);
      setState(() {
        _biometricEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.translate('passcode_settings'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Turn Off
            GestureDetector(
              onTap: _verifyAndTurnOff,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_open_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.translate('btn_turn_off_passcode'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Change
            GestureDetector(
              onTap: _verifyAndChange,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_reset_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.translate('btn_change_passcode'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Biometric Toggle if available
            if (_biometricAvailable)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fingerprint_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.translate('btn_biometric_login'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Switch.adaptive(
                      value: _biometricEnabled,
                      activeColor: AppColors.primary,
                      onChanged: _toggleBiometric,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
