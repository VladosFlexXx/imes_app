import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      final combined = v.isNotEmpty ? v : '';
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
  static const _kMinBootScreen = Duration(seconds: 6);
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
          child: const Center(child: _GifSplash()),
        ),
      ),
    );
  }
}

class _GifSplash extends StatelessWidget {
  const _GifSplash();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final targetWidth = (screenWidth * 0.82).clamp(260.0, 640.0).toDouble();
    return SizedBox(
      width: targetWidth,
      child: Image.asset(
        'assets/splash/logo_header.gif',
        fit: BoxFit.contain,
        gaplessPlayback: true,
      ),
    );
  }
}
