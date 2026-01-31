import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:vuz_app/core/auth/session_manager.dart';
import 'package:vuz_app/core/network/eios_client.dart';

import 'package:vuz_app/features/home/home_screen.dart';
import 'package:vuz_app/features/schedule/schedule_repository.dart';
import 'package:vuz_app/features/grades/repository.dart';
import 'package:vuz_app/features/profile/repository.dart';

class LoginWebViewScreen extends StatefulWidget {
  const LoginWebViewScreen({super.key});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  static const _storage = FlutterSecureStorage();

  InAppWebViewController? _controller;
  double _progress = 0;

  bool _savingCookies = false;
  bool _verifying = false;
  bool _navigated = false;

  static const String _startUrl = 'https://eos.imes.su/my/';

  Future<void> _goToApp() async {
    // ✅ сбросить флаг "сессия умерла"
    SessionManager.instance.reset();

    // ✅ форс-обновление после входа
    unawaited(ScheduleRepository.instance.refresh(force: true));
    unawaited(GradesRepository.instance.refresh(force: true));
    unawaited(ProfileRepository.instance.refresh(force: true));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<String> _buildCookieHeader() async {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri('https://eos.imes.su/'),
    );
    return cookies.map((c) => '${c.name}=${c.value}').join('; ').trim();
  }

  bool _hasMoodleSessionCookie(String cookieHeader) {
    return cookieHeader.contains('MoodleSession=');
  }

  Future<void> _saveCookies() async {
    if (_savingCookies) return;
    _savingCookies = true;
    try {
      final header = await _buildCookieHeader();
      if (header.isNotEmpty) {
        await _storage.write(key: 'cookie_header', value: header);
        EiosClient.instance.invalidateCookieCache();
      }
    } finally {
      _savingCookies = false;
    }
  }

  bool _urlLooksLoggedIn(String? url) {
    final u = (url ?? '').toLowerCase();
    if (!u.contains('eos.imes.su')) return false;
    if (u.contains('/login') || u.contains('login/index.php')) return false;
    return u.contains('/my/') || u.contains('/user/');
  }

  Future<bool> _domLooksLoggedIn() async {
    try {
      final c = _controller;
      if (c == null) return false;

      const js = """
        (function() {
          const a = document.querySelector('a[href*="logout.php"]');
          if (a) return true;
          const html = document.documentElement ? document.documentElement.innerHTML : '';
          return html.includes('logout.php');
        })();
      """;

      final res = await c.evaluateJavascript(source: js);
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyAndEnter() async {
    if (_verifying) return;
    _verifying = true;
    try {
      await _saveCookies();

      // 1) Проверим наличие MoodleSession в cookie_header
      final header = (await _storage.read(key: 'cookie_header')) ?? '';
      if (header.trim().isEmpty || !_hasMoodleSessionCookie(header)) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await _saveCookies();
        final header2 = (await _storage.read(key: 'cookie_header')) ?? '';
        if (header2.trim().isEmpty || !_hasMoodleSessionCookie(header2)) {
          return; // остаёмся в webview
        }
      }

      // 2) Проверим реальным HTTP GET, что /my/ не редиректит на login
      try {
        await EiosClient.instance.getHtml('https://eos.imes.su/my/', retries: 0);
      } catch (_) {
        return; // ещё не залогинен по мнению HTTP-клиента
      }

      // 3) Заходим в приложение
      await _goToApp();
    } finally {
      _verifying = false;
      _navigated = false;
    }
  }

  Future<void> _maybeDetectAndEnter(String? url) async {
    if (_navigated) return;

    final urlOk = _urlLooksLoggedIn(url);
    final domOk = await _domLooksLoggedIn();

    if (urlOk || domOk) {
      _navigated = true;
      await _verifyAndEnter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход в ЭИОС'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: _progress < 1
              ? LinearProgressIndicator(value: _progress)
              : const SizedBox(height: 3),
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_startUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
          sharedCookiesEnabled: true,
          thirdPartyCookiesEnabled: true,
        ),
        onWebViewCreated: (c) => _controller = c,
        onProgressChanged: (_, p) => setState(() => _progress = p / 100),
        onLoadStop: (_, url) async {
          await _maybeDetectAndEnter(url?.toString());
        },
        shouldOverrideUrlLoading: (_, action) async {
          final u = action.request.url?.toString();
          unawaited(_maybeDetectAndEnter(u));
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
