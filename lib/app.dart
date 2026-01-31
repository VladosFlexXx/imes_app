import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/auth/auth_settings.dart';
import 'features/auth/login_webview.dart';
import 'features/home/home_screen.dart';
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
      _loadVersion(),
    ]);
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      final b = info.buildNumber.trim();
      final combined = (v.isNotEmpty && b.isNotEmpty) ? '$v+$b' : (v.isNotEmpty ? v : '');
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
    final bool betaEnabled = !kReleaseMode || const bool.fromEnvironment('BETA', defaultValue: false);
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
                  color: cs.shadow.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              label,
              style: t.labelLarge?.copyWith(color: cs.onError, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ЭИОС ИМЭС',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeController.mode,
      routes: {
        '/login': (_) => const LoginWebViewScreen(),
        '/home': (_) => const HomeScreen(),
      },
      home: _wrapWithBetaBadge(
        context,
        const _BootGate(),
      ),
    );
  }
}

class _BootGate extends StatefulWidget {
  const _BootGate();

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    const storage = FlutterSecureStorage();
    final cookieHeader = await storage.read(key: 'cookie_header');

    if (!mounted) return;

    if (cookieHeader != null && cookieHeader.trim().isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
