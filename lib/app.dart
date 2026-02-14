import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/auth/auth_settings.dart';
import 'core/demo/demo_mode.dart';
import 'features/auth/login_webview.dart';
import 'features/grades/repository.dart';
import 'features/home/home_screen.dart';
import 'features/profile/repository.dart';
import 'features/schedule/schedule_repository.dart';
import 'features/study_plan/repository.dart';
import 'features/recordbook/repository.dart';
import 'features/notifications/inbox_repository.dart';
import 'theme_controller.dart';
import 'ui/app_theme.dart';

final themeController = ThemeController();

class VuzApp extends StatefulWidget {
  const VuzApp({super.key});

  @override
  State<VuzApp> createState() => _VuzAppState();
}

class _VuzAppState extends State<VuzApp> {
  String _appVersion = ''; // например 0.1.0+3

  @override
  void initState() {
    super.initState();
    themeController.addListener(_onThemeChanged);
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      themeController.load(),
      AuthSettings.instance.load(),
      DemoMode.instance.load(),
      _loadVersion(),
    ]);
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      final b = info.buildNumber.trim();
      final combined = (v.isNotEmpty && b.isNotEmpty)
          ? '$v+$b'
          : (v.isNotEmpty ? v : '');
      if (mounted) setState(() => _appVersion = combined);
    } catch (_) {}
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  Widget _wrapWithBetaBadge(BuildContext context, Widget child) {
    final bool betaEnabled =
        !kReleaseMode ||
        const bool.fromEnvironment('BETA', defaultValue: false);
    if (!betaEnabled) return child;

    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final label = _appVersion.trim().isEmpty ? 'BETA' : 'BETA $_appVersion';

    return Stack(
      children: [
        child,
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.error,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              label,
              style: t.labelLarge?.copyWith(
                color: cs.onError,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мой ИМЭС',
      theme: AppTheme.light(seed: themeController.seedColor),
      darkTheme: AppTheme.dark(seed: themeController.seedColor),
      themeMode: themeController.mode,
      routes: {
        '/login': (_) => const LoginWebViewScreen(),
        '/home': (_) => const HomeScreen(),
      },
      home: _wrapWithBetaBadge(context, const _BootGate()),
    );
  }
}

class _BootGate extends StatefulWidget {
  const _BootGate();

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  static const _kMinBootScreen = Duration(milliseconds: 2800);
  static const _kFadeOutDuration = Duration(milliseconds: 360);
  late final DateTime _bootStartedAt;
  bool _navigating = false;
  bool _fadeOut = false;

  @override
  void initState() {
    super.initState();
    _bootStartedAt = DateTime.now();
    _go();
  }

  Future<void> _ensureMinBootScreen() async {
    final elapsed = DateTime.now().difference(_bootStartedAt);
    final remain = _kMinBootScreen - elapsed;
    if (remain > Duration.zero) {
      await Future<void>.delayed(remain);
    }
  }

  Future<void> _go() async {
    // Прогреваем локальные кэши, пока пользователь видит стартовый экран.
    // Важно: тут только init (чтение кэша), без сетевого refresh.
    await Future.wait([
      ScheduleRepository.instance.init(),
      GradesRepository.instance.init(),
      ProfileRepository.instance.init(),
      StudyPlanRepository.instance.init(),
      RecordbookRepository.instance.init(),
      NotificationInboxRepository.instance.init(),
    ]);

    if (DemoMode.instance.enabled) {
      await _ensureMinBootScreen();
      await _navigateWithFade('/home');
      return;
    }

    String cookieHeader = '';
    try {
      const storage = FlutterSecureStorage();
      cookieHeader = (await storage.read(key: 'cookie_header')) ?? '';
    } catch (_) {
      cookieHeader = '';
    }

    await _ensureMinBootScreen();

    final normalized = cookieHeader.trim();
    final hasSession = normalized.contains('MoodleSession=');

    if (normalized.isNotEmpty && hasSession) {
      await _navigateWithFade('/home');
    } else {
      await _navigateWithFade('/login');
    }
  }

  Future<void> _navigateWithFade(String route) async {
    if (!mounted || _navigating) return;
    _navigating = true;
    setState(() => _fadeOut = true);
    await Future<void>.delayed(_kFadeOutDuration);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedOpacity(
        opacity: _fadeOut ? 0 : 1,
        duration: _kFadeOutDuration,
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.55 : 0.72,
                ),
                cs.surface,
              ],
            ),
          ),
          child: const Center(
            child: _LogoRevealSplash(),
          ),
        ),
      ),
    );
  }
}

class _LogoRevealSplash extends StatefulWidget {
  const _LogoRevealSplash();

  @override
  State<_LogoRevealSplash> createState() => _LogoRevealSplashState();
}

class _LogoRevealSplashState extends State<_LogoRevealSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load('assets/splash/logo_big.png');
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final targetWidth = (screenWidth * 0.98).clamp(340.0, 980.0).toDouble();
    final ratio = _image == null
        ? (1024.0 / 512.0)
        : (_image!.width / _image!.height);
    return SizedBox(
      width: targetWidth,
      child: AspectRatio(
        aspectRatio: ratio,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            return CustomPaint(
              painter: _LogoRevealPainter(
                image: _image,
                progress: _controller.value,
                tint: cs.primary,
              ),
              child: child,
            );
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LogoRevealPainter extends CustomPainter {
  final ui.Image? image;
  final double progress;
  final Color tint;

  const _LogoRevealPainter({
    required this.image,
    required this.progress,
    required this.tint,
  });

  Path _maskPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.12, -h * 0.24)
      ..cubicTo(w * 0.13, -h * 0.08, w * 0.14, h * 0.12, w * 0.16, h * 0.30)
      ..cubicTo(w * 0.25, h * 0.45, w * 0.30, h * 0.76, w * 0.40, h * 0.70)
      ..cubicTo(w * 0.52, h * 0.62, w * 0.56, h * 0.24, w * 0.67, h * 0.30)
      ..cubicTo(w * 0.78, h * 0.38, w * 0.83, h * 0.66, w * 0.90, h * 0.70);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;

    final path = _maskPath(size);
    final metric = path.computeMetrics().first;
    final revealLen = metric.length * progress;
    final brushRadius = size.shortestSide * 0.34;

    // Собираем "кисть" как Path из окружностей вдоль кривой.
    final revealPath = Path();
    final steps = 220;
    for (var i = 0; i <= steps; i++) {
      final d = revealLen * (i / steps);
      final tangent = metric.getTangentForOffset(d);
      if (tangent != null) {
        revealPath.addOval(
          Rect.fromCircle(center: tangent.position, radius: brushRadius),
        );
      }
    }

    // Рендерим картинку только внутри reveal-path (без saveLayer/srcIn).
    canvas.save();
    canvas.clipPath(revealPath);
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image!,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LogoRevealPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.image != image;
  }
}
