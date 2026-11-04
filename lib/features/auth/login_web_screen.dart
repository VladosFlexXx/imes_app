import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:imes_app/app.dart';
import 'package:imes_app/core/auth/auth_settings.dart';
import 'package:imes_app/core/auth/session_manager.dart';
import 'package:imes_app/core/demo/demo_mode.dart';
import 'package:imes_app/core/network/eios_client.dart';
import 'package:imes_app/features/grades/repository.dart';
import 'package:imes_app/features/home/home_screen.dart';
import 'package:imes_app/features/notifications/inbox_repository.dart';
import 'package:imes_app/features/profile/repository.dart';
import 'package:imes_app/features/schedule/schedule_repository.dart';
import 'package:imes_app/ui/app_haptics.dart';
import 'package:imes_app/ui/app_theme.dart';

class LoginWebScreen extends StatefulWidget {
  const LoginWebScreen({super.key});

  @override
  State<LoginWebScreen> createState() => _LoginWebScreenState();
}

class _LoginWebScreenState extends State<LoginWebScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _loading = false;
  String? _errorMessage;
  WebProxyProvider _proxyProvider = WebProxyProvider.auto;

  @override
  void initState() {
    super.initState();
    _loadSavedCreds();
  }

  Future<void> _loadSavedCreds() async {
    final s = AuthSettings.instance;
    final creds = await s.getCredentials();
    await EiosClient.instance.initProxyProvider();
    if (mounted) {
      setState(() {
        if (creds != null) {
          _usernameController.text = creds.username;
          _passwordController.text = creds.password;
        }
        _proxyProvider = EiosClient.instance.proxyProvider;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Введите логин и пароль от ЭИОС';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    AppHaptics.mediumImpact();

    try {
      final ok = await EiosClient.instance.silentLogin(
        username: username,
        password: password,
        persistCookieHeader: true,
      );

      if (!mounted) return;

      if (ok) {
        AppHaptics.lightImpact();

        if (_rememberMe) {
          await AuthSettings.instance.setCredentials(
            username: username,
            password: password,
          );
          await AuthSettings.instance.setCredsEnabled(true);
        }

        SessionManager.instance.reset();

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );

        // Фоновое обновление данных
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          unawaited(ScheduleRepository.instance.refresh(force: true));
          unawaited(ProfileRepository.instance.refresh(force: true));
          unawaited(GradesRepository.instance.refresh(force: true));
        });
      } else {
        AppHaptics.heavyImpact();
        setState(() {
          _errorMessage = EiosClient.instance.lastWebLoginError ?? 'Неверный логин или пароль от ЭИОС ИМЭС';
        });
      }
    } catch (e) {
      AppHaptics.heavyImpact();
      setState(() {
        _errorMessage = 'Ошибка подключения к серверу: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _enterDemo() async {
    AppHaptics.selectionClick();
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'cookie_header');
    EiosClient.instance.invalidateCookieCache();
    await DemoMode.instance.setEnabled(true);
    await NotificationInboxRepository.instance.seedDemoItems(replace: true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final accent = appAccentOf(context);

    final bg = isAmoled
        ? Colors.black
        : (isDark ? const Color(0xFF14171C) : const Color(0xFFF4F6FB));
    final cardBg = isAmoled
        ? const Color(0xFF0C0D0F)
        : (isDark ? const Color(0xFF1C1F26) : Colors.white);
    final cardBorder = isAmoled
        ? accent.withValues(alpha: 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(color: cardBorder, width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Логотип
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [accent, accent.withValues(alpha: 0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.30),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Мой ИМЭС',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Вход в ЭИОС (Moodle) для iPhone и Web',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9EABB8) : const Color(0xFF5F6E7C),
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Поле логина
                      TextField(
                        controller: _usernameController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Логин или email ЭИОС',
                          hintText: 'ivanov.i или ivanov@imes.su',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: accent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Поле пароля
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _doLogin(),
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              AppHaptics.selectionClick();
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF7F9FC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: accent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Запомнить меня
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (v) {
                              AppHaptics.selectionClick();
                              setState(() => _rememberMe = v ?? true);
                            },
                          ),
                          GestureDetector(
                            onTap: () {
                              AppHaptics.selectionClick();
                              setState(() => _rememberMe = !_rememberMe);
                            },
                            child: Text(
                              'Запомнить меня',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Выбор шлюза (РФ / VPN / Авто)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    _proxyProvider == WebProxyProvider.cloudflare
                                        ? Icons.vpn_lock_rounded
                                        : (_proxyProvider == WebProxyProvider.yandex
                                            ? Icons.dns_rounded
                                            : Icons.bolt_rounded),
                                    size: 14,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Шлюз подключения:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<WebProxyProvider>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment<WebProxyProvider>(
                                    value: WebProxyProvider.auto,
                                    label: Text('⚡ Авто'),
                                    tooltip: 'Авто-переключение при включённом VPN',
                                  ),
                                  ButtonSegment<WebProxyProvider>(
                                    value: WebProxyProvider.yandex,
                                    label: Text('🇷🇺 Яндекс'),
                                    tooltip: 'РФ сервер (без VPN)',
                                  ),
                                  ButtonSegment<WebProxyProvider>(
                                    value: WebProxyProvider.cloudflare,
                                    label: Text('🌐 Cloudflare'),
                                    tooltip: 'Работает с любым VPN',
                                  ),
                                ],
                                selected: {_proxyProvider},
                                onSelectionChanged: (Set<WebProxyProvider> newSelection) async {
                                  AppHaptics.selectionClick();
                                  final selected = newSelection.first;
                                  setState(() => _proxyProvider = selected);
                                  await EiosClient.instance.setProxyProvider(selected);
                                },
                                style: SegmentedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  textStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  selectedBackgroundColor: accent.withValues(alpha: 0.18),
                                  selectedForegroundColor: accent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Кнопка Войти
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _doLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Войти',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Демо-режим
                      SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _enterDemo,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Демо-режим (без входа)',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Безопасность сноска
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _proxyProvider == WebProxyProvider.cloudflare
                                ? 'Шлюз Cloudflare • Доступен через любой VPN'
                                : (_proxyProvider == WebProxyProvider.yandex
                                    ? 'Сервер в РФ • Работает без VPN'
                                    : 'Умный шлюз • Работает и с VPN, и без него'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
