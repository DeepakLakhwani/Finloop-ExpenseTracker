import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import '../providers/language_provider.dart';

class PasscodeLockScreen extends StatefulWidget {
  final bool verificationOnly;
  const PasscodeLockScreen({super.key, this.verificationOnly = false});

  @override
  State<PasscodeLockScreen> createState() => _PasscodeLockScreenState();
}

class _PasscodeLockScreenState extends State<PasscodeLockScreen> {
  final SecurityService _securityService = SecurityService();
  final BiometricService _biometricService = BiometricService();
  String _enteredCode = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _triggerBiometrics();
  }

  @override
  void dispose() {
    _biometricService.stopAuthentication();
    super.dispose();
  }

  void _triggerBiometrics({bool force = false}) async {
    final enabled = await _securityService.isBiometricEnabled();
    final available = await _biometricService.isBiometricAvailable();
    if (enabled && available) {
      final success = await _biometricService.authenticate();
      if (success && mounted) {
        _onAuthSuccess();
      }
    }
  }

  void _onAuthSuccess() async {
    await _securityService.clearAppClosedTime();
    _securityService.setSessionUnlocked(true);
    if (!mounted) return;
    if (widget.verificationOnly) {
      Navigator.pop(context, true);
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    }
  }

  void _onNumberTap(int val) async {
    if (_enteredCode.length >= 4) return;
    setState(() {
      _errorMessage = '';
      _enteredCode += val.toString();
    });

    if (_enteredCode.length == 4) {
      final matches = await _securityService.verifyPasscode(_enteredCode);
      if (matches) {
        Future.delayed(
          const Duration(milliseconds: 200),
          () => _onAuthSuccess(),
        );
      } else {
        // Failed
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _enteredCode = '';
              _errorMessage = context.translate('err_incorrect_passcode');
            });
          }
        });
      }
    }
  }

  void _onBackspace() {
    if (_enteredCode.isEmpty) return;
    setState(() {
      _errorMessage = '';
      _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.verificationOnly,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: widget.verificationOnly
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                )
              : null,
          title: Text(
            widget.verificationOnly ? context.translate('title_verify_identity') : context.translate('title_enter_passcode'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
  
              // Instruction / Icon
              Icon(Icons.lock_outline, size: 36, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                widget.verificationOnly
                    ? context.translate('msg_verify_identity_instruction')
                    : context.translate('msg_enter_passcode_instruction'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
  
              // Passcode dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _enteredCode.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isFilled ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFilled
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
  
              // Error Message
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
  
              const Spacer(flex: 3),
  
              // Number Keypad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeypadButton(1),
                        _buildKeypadButton(2),
                        _buildKeypadButton(3),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeypadButton(4),
                        _buildKeypadButton(5),
                        _buildKeypadButton(6),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeypadButton(7),
                        _buildKeypadButton(8),
                        _buildKeypadButton(9),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBiometricButton(),
                        _buildKeypadButton(0),
                        _buildBackspaceButton(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(int value) {
    return GestureDetector(
      onTap: () => _onNumberTap(value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {

    return FutureBuilder<bool>(
      future: _securityService.isBiometricEnabled(),
      builder: (context, snapshot) {
        final enabled = snapshot.data == true;
        if (!enabled) return const SizedBox(width: 70, height: 70);

        return GestureDetector(
          onTap: () => _triggerBiometrics(force: true),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 70,
            height: 70,
            child: Center(
              child: Icon(
                Icons.fingerprint,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _onBackspace,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        height: 70,
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Theme.of(context).colorScheme.onSurface,
            size: 22,
          ),
        ),
      ),
    );
  }
}
