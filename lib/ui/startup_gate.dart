import 'package:flutter/material.dart';
import '../core/auth/app_security_service.dart';
import '../core/auth/biometric_service.dart';
import '../core/auth/pin_code_service.dart';
import '../features/auth/pin_code_screen.dart';

/// Keeps the splash above the destination until its first frame is rendered.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.prepare,
    required this.builder,
    required this.splash,
  });

  final Future<void> Function() prepare;
  final WidgetBuilder builder;
  final Widget splash;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _ready = false;
  bool _revealing = false;
  bool _finished = false;
  bool _failed = false;
  bool _biometricLocked = false;
  bool _pinLocked = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await widget.prepare();
      if (!mounted) return;

      // Apply screen privacy protection if enabled
      await AppSecurityService.instance.init();

      final bioEnabled = await BiometricService.instance.isEnabled();
      final pinEnabled = await PinCodeService.instance.isEnabled();

      if (pinEnabled) {
        // If PIN is enabled, check biometrics first if user has it active
        if (bioEnabled) {
          final authenticated = await BiometricService.instance.authenticate(
            reason: 'Подтвердите вход в Мой ИМЭС',
          );
          if (authenticated) {
            _finishReveal();
            return;
          }
        }
        // If biometric failed or wasn't enabled, require PIN
        if (mounted) setState(() => _pinLocked = true);
        return;
      } else if (bioEnabled) {
        final authenticated = await BiometricService.instance.authenticate(
          reason: 'Подтвердите вход в Мой ИМЭС',
        );
        if (!authenticated) {
          if (mounted) setState(() => _biometricLocked = true);
          return;
        }
      }

      _finishReveal();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'startup'),
      );
      if (mounted) setState(() => _failed = true);
    }
  }

  void _finishReveal() {
    setState(() => _ready = true);

    // The destination is mounted and painted underneath the opaque splash.
    // Reveal once the first frame has painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _revealing = true);
      }
    });
  }

  Future<void> _unlockBiometric() async {
    final authenticated = await BiometricService.instance.authenticate(
      reason: 'Подтвердите вход в Мой ИМЭС',
    );
    if (authenticated && mounted) {
      setState(() {
        _biometricLocked = false;
      });
      _finishReveal();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pinLocked) {
      return PinCodeScreen(
        mode: PinScreenMode.verify,
        canCancel: false,
        onSuccess: () {
          setState(() {
            _pinLocked = false;
          });
          _finishReveal();
        },
      );
    }

    if (_biometricLocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint_rounded, size: 72),
                const SizedBox(height: 16),
                const Text(
                  'Приложение заблокировано',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Подтвердите личность для входа',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _unlockBiometric,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Разблокировать'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_failed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Ошибка запуска',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Не удалось инициализировать приложение. Попробуйте перезапустить.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _failed = false;
                      _ready = false;
                      _revealing = false;
                      _finished = false;
                    });
                    _prepare();
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_ready) widget.builder(context),
        if (!_finished)
          AnimatedOpacity(
            opacity: _revealing ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            onEnd: () {
              if (_revealing && mounted) {
                setState(() => _finished = true);
              }
            },
            child: widget.splash,
          ),
      ],
    );
  }
}
