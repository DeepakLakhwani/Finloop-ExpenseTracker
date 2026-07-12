import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';
import 'passcode_lock_screen.dart';
import 'passcode_setup_screen.dart';
import '../providers/language_provider.dart';
import 'settings/widgets/settings_tile.dart';

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
        settings: const RouteSettings(name: '/lock_screen'),
        builder: (context) => const PasscodeLockScreen(verificationOnly: true),
      ),
    );

    if (verified == true) {
      await _securityService.clearPasscode();
      if (!mounted) return;

      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 12),
              Text(
                context.translate('msg_passcode_disabled'),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          backgroundColor: theme.colorScheme.primary,
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
        settings: const RouteSettings(name: '/lock_screen'),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 10, top: 24),
      child: Text(
        _toTitleCase(title),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildSectionCard(List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final List<Widget> dividedChildren = [];
    for (int i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i < children.length - 1) {
        dividedChildren.add(
          Divider(
            height: 1,
            thickness: 0.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            indent: 60,
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: dividedChildren,
        ),
      ),
    );
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context.translate('passcode_settings')),
            _buildSectionCard([
              SettingsTile(
                title: context.translate('btn_turn_off_passcode'),
                icon: Icons.lock_open_outlined,
                onTap: _verifyAndTurnOff,
              ),
              SettingsTile(
                title: context.translate('btn_change_passcode'),
                icon: Icons.lock_reset_outlined,
                onTap: _verifyAndChange,
              ),
              if (_biometricAvailable)
                SettingsTile(
                  title: context.translate('btn_biometric_login'),
                  icon: Icons.fingerprint_outlined,
                  onTap: () => _toggleBiometric(!_biometricEnabled),
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      value: _biometricEnabled,
                      activeColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                      onChanged: _toggleBiometric,
                    ),
                  ),
                ),
            ]),
            
            // Request Time is always shown because passcode is active on this screen
            _buildSectionHeader(context.translate('bio_request_time')),
            _buildSectionCard([
              SettingsTile(
                title: context.translate('bio_request_time'),
                icon: Icons.schedule_outlined,
                status: _timeoutLabel(context, _biometricTimeout),
                onTap: _showRequestTimePicker,
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
