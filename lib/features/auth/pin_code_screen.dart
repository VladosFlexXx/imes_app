import 'dart:math';
import 'package:flutter/material.dart';

import 'package:vuz_app/core/auth/biometric_service.dart';
import 'package:vuz_app/core/auth/pin_code_service.dart';
import 'package:vuz_app/ui/app_haptics.dart';

enum PinScreenMode {
  create,
  verify,
  change,
}

class PinCodeScreen extends StatefulWidget {
  const PinCodeScreen({
    super.key,
    required this.mode,
    this.canCancel = true,
    this.onSuccess,
  });

  final PinScreenMode mode;
  final bool canCancel;
  final VoidCallback? onSuccess;

  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  String _currentPin = '';
  String _firstEnteredPin = '';
  int _step = 0; // for create and change modes
  String _errorMessage = '';

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    if (widget.mode == PinScreenMode.verify) {
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    final enabled = await BiometricService.instance.isEnabled();
    if (enabled && mounted) {
      setState(() => _biometricAvailable = true);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPress(String digit) {
    if (_currentPin.length >= _pinLength) return;

    AppHaptics.selectionClick();
    setState(() {
      _errorMessage = '';
      _currentPin += digit;
    });

    if (_currentPin.length == _pinLength) {
      _handleCompletePin(_currentPin);
    }
  }

  void _onDeletePress() {
    if (_currentPin.isEmpty) return;

    AppHaptics.selectionClick();
    setState(() {
      _errorMessage = '';
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
    });
  }

  Future<void> _triggerBiometric() async {
    AppHaptics.mediumImpact();
    final ok = await BiometricService.instance.authenticate(
      reason: 'Подтвердите вход по биометрии',
    );
    if (ok && mounted) {
      _handleSuccess();
    }
  }

  Future<void> _handleCompletePin(String pin) async {
    switch (widget.mode) {
      case PinScreenMode.verify:
        final valid = await PinCodeService.instance.verify(pin);
        if (valid) {
          _handleSuccess();
        } else {
          _handleWrongPin('Неверный PIN-код');
        }
        break;

      case PinScreenMode.create:
        if (_step == 0) {
          _firstEnteredPin = pin;
          setState(() {
            _step = 1;
            _currentPin = '';
          });
        } else {
          if (pin == _firstEnteredPin) {
            await PinCodeService.instance.setPin(pin);
            _handleSuccess();
          } else {
            _handleWrongPin('PIN-коды не совпали. Попробуйте снова.');
            setState(() {
              _step = 0;
              _firstEnteredPin = '';
            });
          }
        }
        break;

      case PinScreenMode.change:
        if (_step == 0) {
          final valid = await PinCodeService.instance.verify(pin);
          if (valid) {
            setState(() {
              _step = 1;
              _currentPin = '';
            });
          } else {
            _handleWrongPin('Неверный текущий PIN-код');
          }
        } else if (_step == 1) {
          _firstEnteredPin = pin;
          setState(() {
            _step = 2;
            _currentPin = '';
          });
        } else {
          if (pin == _firstEnteredPin) {
            await PinCodeService.instance.setPin(pin);
            _handleSuccess();
          } else {
            _handleWrongPin('PIN-коды не совпали. Попробуйте снова.');
            setState(() {
              _step = 1;
              _firstEnteredPin = '';
            });
          }
        }
        break;
    }
  }

  void _handleWrongPin(String message) {
    AppHaptics.heavyImpact();
    _shakeController.forward(from: 0.0);
    setState(() {
      _errorMessage = message;
      _currentPin = '';
    });
  }

  void _handleSuccess() {
    AppHaptics.mediumImpact();
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  String get _title {
    switch (widget.mode) {
      case PinScreenMode.verify:
        return 'Вход в приложение';
      case PinScreenMode.create:
        return _step == 0 ? 'Задайте PIN-код' : 'Повторите PIN-код';
      case PinScreenMode.change:
        if (_step == 0) return 'Текущий PIN-код';
        if (_step == 1) return 'Новый PIN-код';
        return 'Повторите новый PIN-код';
    }
  }

  String get _subtitle {
    switch (widget.mode) {
      case PinScreenMode.verify:
        return 'Введите 4-значный код безопасности';
      case PinScreenMode.create:
        return _step == 0
            ? 'Придумайте 4 цифры для быстрого входа'
            : 'Введите код ещё раз для подтверждения';
      case PinScreenMode.change:
        if (_step == 0) return 'Введите ваш действующий PIN-код';
        if (_step == 1) return 'Придумайте новый 4-значный код';
        return 'Введите новый код ещё раз для подтверждения';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return PopScope(
      canPop: widget.canCancel,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: widget.canCancel
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Shield Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.12),
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_rounded,
                    size: 32,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                _title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage.isNotEmpty ? _errorMessage : _subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _errorMessage.isNotEmpty
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontWeight: _errorMessage.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // PIN dots with Shake Animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final offset = sin(_shakeAnimation.value * pi * 4) * 12;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final isFilled = index < _currentPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: isFilled ? 18 : 14,
                      height: isFilled ? 18 : 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? primaryColor
                            : theme.colorScheme.onSurface.withValues(
                                alpha: isDark ? 0.22 : 0.18,
                              ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              const Spacer(flex: 3),

              // Keypad
              _buildKeypad(theme, primaryColor, isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme, Color primaryColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(['1', '2', '3'], theme, isDark),
          const SizedBox(height: 14),
          _buildRow(['4', '5', '6'], theme, isDark),
          const SizedBox(height: 14),
          _buildRow(['7', '8', '9'], theme, isDark),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Bottom-left: Biometrics (if verify mode & enabled) or empty
              SizedBox(
                width: 72,
                height: 72,
                child: _biometricAvailable && widget.mode == PinScreenMode.verify
                    ? IconButton(
                        icon: Icon(
                          Icons.fingerprint_rounded,
                          size: 34,
                          color: primaryColor,
                        ),
                        onPressed: _triggerBiometric,
                      )
                    : null,
              ),

              // 0
              _buildKeypadButton('0', theme, isDark),

              // Bottom-right: Backspace
              SizedBox(
                width: 72,
                height: 72,
                child: _currentPin.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.backspace_outlined,
                          size: 26,
                        ),
                        onPressed: _onDeletePress,
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> digits, ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((digit) => _buildKeypadButton(digit, theme, isDark))
          .toList(),
    );
  }

  Widget _buildKeypadButton(String digit, ThemeData theme, bool isDark) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onDigitPress(digit),
          child: Center(
            child: Text(
              digit,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

