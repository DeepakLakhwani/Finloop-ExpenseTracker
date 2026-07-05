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
  int _biometricTimeout = 0; // seconds

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
    final timeout = await _securityService.getBiometricTimeout();
    setState(() {
      _biometricEnabled = enabled;
      _biometricAvailable = available;
      _biometricTimeout = timeout;
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
        // Default to "Immediately" (0 seconds)
        await _securityService.setBiometricTimeout(0);
        setState(() {
          _biometricEnabled = true;
          _biometricTimeout = 0;
        });
        // Immediately show the request time picker
        if (mounted) {
          _showRequestTimePicker();
        }
      } else {
        setState(() {
          _biometricEnabled = false;
        });
      }
    } else {
      await _securityService.setBiometricEnabled(false);
      setState(() {
        _biometricEnabled = false;
        _biometricTimeout = 0;
      });
    }
  }

  // -----------------------------------------------------------------------
  // Request Time helpers
  // -----------------------------------------------------------------------

  /// The available timeout options: value in seconds → localization key.
  static const List<int> _timeoutOptions = [0, 60, 300, 3600];

  String _timeoutLabel(BuildContext context, int seconds) {
    switch (seconds) {
      case 0:
        return context.translate('bio_timeout_immediately');
      case 60:
        return context.translate('bio_timeout_1_min');
      case 300:
        return context.translate('bio_timeout_5_min');
      case 3600:
        return context.translate('bio_timeout_1_hour');
      default:
        return context.translate('bio_timeout_immediately');
    }
  }

  void _showRequestTimePicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Text(
                    context.translate('bio_request_time'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _timeoutOptions.length,
                  itemBuilder: (context, index) {
                    final seconds = _timeoutOptions[index];
                    final label = _timeoutLabel(context, seconds);
                    final isSelected = _biometricTimeout == seconds;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                        child: Icon(
                          _timeoutIcon(seconds),
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () async {
                        await _securityService.setBiometricTimeout(seconds);
                        setState(() {
                          _biometricTimeout = seconds;
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _timeoutIcon(int seconds) {
    switch (seconds) {
      case 0:
        return Icons.flash_on_outlined;
      case 60:
        return Icons.timer_outlined;
      case 300:
        return Icons.timelapse_outlined;
      case 3600:
        return Icons.access_time_outlined;
      default:
        return Icons.timer_outlined;
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
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Theme.of(context).colorScheme.surface,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Turn Off Passcode
                  InkWell(
                    onTap: _verifyAndTurnOff,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_open_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.translate('btn_turn_off_passcode'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                        ],
                      ),
                    ),
                  ),

                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),

                  // Change Passcode
                  InkWell(
                    onTap: _verifyAndChange,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_reset_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.translate('btn_change_passcode'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                        ],
                      ),
                    ),
                  ),

                  // Biometric Toggle if available
                  if (_biometricAvailable) ...[
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fingerprint_outlined,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.translate('btn_biometric_login'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch.adaptive(
                              value: _biometricEnabled,
                              activeThumbColor: AppColors.primary,
                              activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                              onChanged: _toggleBiometric,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Request Time — only visible when biometric is enabled
                  if (_biometricAvailable && _biometricEnabled) ...[
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    ),
                    InkWell(
                      onTap: _showRequestTimePicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              color: Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.translate('bio_request_time'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              _timeoutLabel(context, _biometricTimeout),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
