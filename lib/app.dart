import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'features/auth/login_webview.dart';
import 'features/home/home_screen.dart';
import 'theme_controller.dart';

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
      _loadVersion(),
    ]);
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // version = 0.1.0, buildNumber = 3
      final v = info.version.trim();
      final b = info.buildNumber.trim();
      final combined = (v.isNotEmpty && b.isNotEmpty) ? '$v+$b' : (v.isNotEmpty ? v : '');
      if (mounted) setState(() => _appVersion = combined);
    } catch (_) {
      // если не смогли получить версию — просто покажем BETA без версии
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  ThemeData _lightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: Colors.indigo,
    );

    final cs = base.colorScheme;

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),

      // ✅ фикс контрастности нижней навигации
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withOpacity(0.65),
        selectedIconTheme: IconThemeData(color: cs.primary),
        unselectedIconTheme: IconThemeData(color: cs.onSurface.withOpacity(0.65)),
        showUnselectedLabels: true,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  ThemeData _darkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.indigo,
    );

    final cs = base.colorScheme;

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F1115),

      // ✅ фикс контрастности нижней навигации
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withOpacity(0.75),
        selectedIconTheme: IconThemeData(color: cs.primary),
        unselectedIconTheme: IconThemeData(color: cs.onSurface.withOpacity(0.75)),
        showUnselectedLabels: true,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: const Color(0xFF171A21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _wrapWithBetaBadge(BuildContext context, Widget child) {
    // В debug: бейдж всегда.
    // В release: только если --dart-define=BETA=true
    final bool betaEnabled =
        !kReleaseMode || const bool.fromEnvironment('BETA', defaultValue: false);

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
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.tertiary.withOpacity(0.35)),
              ),
              child: Text(
                label,
                style: t.labelSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: cs.onTertiaryContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!themeController.loaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            _wrapWithBetaBadge(context, child ?? const SizedBox.shrink()),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ЭИОС',
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: themeController.mode,
      builder: (context, child) =>
          _wrapWithBetaBadge(context, child ?? const SizedBox.shrink()),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  static const _storage = FlutterSecureStorage();
  bool? _hasCookie;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final v = await _storage.read(key: 'cookie_header');
    if (!mounted) return;
    setState(() => _hasCookie = (v != null && v.trim().isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCookie == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _hasCookie! ? const HomeScreen() : const LoginWebViewScreen();
  }
}
