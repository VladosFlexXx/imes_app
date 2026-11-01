import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'core/auth/auth_settings.dart';
import 'core/app_icon_service.dart';
import 'core/auth/session_manager.dart';
import 'core/network/eios_client.dart';
import 'core/logging/app_logger.dart';
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
import 'ui/startup_gate.dart';

final themeController = ThemeController();

class VuzApp extends StatefulWidget {
  const VuzApp({super.key});

  @override
  State<VuzApp> createState() => _VuzAppState();
}

class _VuzAppState extends State<VuzApp> {
  String _appVersion = ''; // например 0.1.0+3
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    themeController.addListener(_onThemeChanged);
  }

  Future<void> _loadOptional(Future<void> Function() load) async {
    try {
      await load();
    } catch (error, stack) {
      AppLogger.instance.e('[BOOT] local settings load failed', error, stack);
    }
  }

  Future<void> _prepareInitialScreen() async {
    const storage = FlutterSecureStorage();
    // Settings must be ready before selecting demo/auth and fetching data.
    await Future.wait([
      _loadOptional(themeController.load),
      _loadOptional(AppIconService.instance.init),
      _loadOptional(AuthSettings.instance.load),
      _loadOptional(DemoMode.instance.load),
      _loadVersion(),
      ScheduleRepository.instance.init(),
      GradesRepository.instance.init(),
      ProfileRepository.instance.init(),
      StudyPlanRepository.instance.init(),
      RecordbookRepository.instance.init(),
      _loadOptional(NotificationInboxRepository.instance.init),
    ]);

    final demo = DemoMode.instance.enabled;
    String cookieHeader = '';
    if (!demo) {
      try {
        cookieHeader = (await storage.read(key: 'cookie_header')) ?? '';
      } catch (_) {}
      if (!cookieHeader.contains('MoodleSession=')) {
        if (mounted) setState(() => _isLoggedIn = false);
        return;
      }
    }

    SessionManager.instance.reset();
    // Fresh cached data is ready immediately. Stale/missing data is fetched
    // before revealing the dashboard; repository errors preserve the cache.
    await Future.wait([
      ScheduleRepository.instance.refresh(force: demo),
      GradesRepository.instance.refresh(force: demo),
      ProfileRepository.instance.refresh(force: demo),
      if (demo)
        _loadOptional(
          () => NotificationInboxRepository.instance.seedDemoItems(),
        ),
    ]);

    if (!demo && SessionManager.instance.expired.value) {
      await storage.delete(key: 'cookie_header');
      EiosClient.instance.invalidateCookieCache();
      SessionManager.instance.reset();
      if (mounted) setState(() => _isLoggedIn = false);
      return;
    }
    if (mounted) setState(() => _isLoggedIn = true);
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
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final useMaterialYou = themeController.materialYou;
        return MaterialApp(
          title: 'Мой ИМЭС',
          theme: AppTheme.light(
            seed: themeController.seedColor,
            uiScale: themeController.uiScale,
            dynamicColorScheme: useMaterialYou ? lightDynamic : null,
          ),
          darkTheme: AppTheme.dark(
            seed: themeController.seedColor,
            uiScale: themeController.uiScale,
            amoled: themeController.amoledBlack,
            dynamicColorScheme: useMaterialYou ? darkDynamic : null,
          ),
          themeMode: themeController.mode,
          routes: {
            '/login': (_) => const LoginWebViewScreen(),
            '/home': (_) => const HomeScreen(),
          },
          home: StartupGate(
            prepare: _prepareInitialScreen,
            builder: (_) => _isLoggedIn
                ? const HomeScreen(initialDataReady: true)
                : const LoginWebViewScreen(),
            splash: const _BootSplash(),
          ),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final scale = themeController.uiScale;
            final scaledChild = MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
            return _wrapWithBetaBadge(context, scaledChild);
          },
        );
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
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
