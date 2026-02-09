import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vuz_app/core/demo/demo_mode.dart';
import 'package:vuz_app/core/network/eios_client.dart';

import '../home/home_screen.dart';

class LoginWebViewScreen extends StatefulWidget {
  const LoginWebViewScreen({super.key});

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  static const _storage = FlutterSecureStorage();

  InAppWebViewController? _controller;
  double _progress = 0;

  bool _didEnterHome = false;
  bool _savingCookies = false;
  bool _verifying = false;

  // Стартуем с /my/ — если не залогинен, Moodle редиректнет на login
  static const String _startUrl = 'https://eos.imes.su/my/';

  Future<void> _goToApp() async {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<void> _enterDemo() async {
    await _storage.delete(key: 'cookie_header');
    EiosClient.instance.invalidateCookieCache();
    await DemoMode.instance.setEnabled(true);
    await _goToApp();
  }

  Future<String> _buildCookieHeader() async {
    // Берём cookies для домена (важно: именно https://eos.imes.su/)
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri('https://eos.imes.su/'),
    );

    // k=v; k2=v2
    final header = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    return header.trim();
  }

  bool _hasMoodleSessionCookie(String cookieHeader) {
    // MoodleSession может быть MoodleSession / MoodleSessionTest / MoodleSessionXXXX
    // но обычно начинается с "MoodleSession"
    return cookieHeader.contains('MoodleSession=');
  }

  Future<void> _saveCookiesForDomain() async {
    if (_savingCookies) return;
    _savingCookies = true;

    try {
      final header = await _buildCookieHeader();

      if (header.isNotEmpty) {
        await _storage.write(key: 'cookie_header', value: header);
        EiosClient.instance.invalidateCookieCache();
        debugPrint('COOKIE_HEADER saved, len=${header.length}');
      } else {
        debugPrint('COOKIE_HEADER empty (not saved)');
      }
    } catch (e) {
      debugPrint('SAVE COOKIES ERROR: $e');
    } finally {
      _savingCookies = false;
    }
  }

  /// Строгий признак "вышли после логина"
  bool _urlLooksLoggedIn(String? url) {
    final u = (url ?? '').toLowerCase();
    if (!u.contains('eos.imes.su')) return false;

    // Не считаем logged-in, если это /login
    if (u.contains('/login') || u.contains('login/index.php')) return false;

    // Надёжные цели после логина
    return u.contains('eos.imes.su/my/') || u.contains('eos.imes.su/user/');
  }

  Future<bool> _domLooksLoggedIn() async {
    // Ищем link на logout.php — намного точнее, чем "ВЫХОД"
    try {
      if (_controller == null) return false;

      const js = """
        (function() {
          const a = document.querySelector('a[href*="logout.php"]');
          if (a) return true;
          // иногда logout спрятан в меню
          const html = document.documentElement ? document.documentElement.innerHTML : '';
          return html.includes('logout.php');
        })();
      """;

      final res = await _controller!.evaluateJavascript(source: js);
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyAndEnterApp() async {
    if (_verifying) return;
    _verifying = true;

    try {
      // 1) сохраним cookies
      await _saveCookiesForDomain();

      // 2) прочитаем cookie_header и проверим MoodleSession
      final header = (await _storage.read(key: 'cookie_header')) ?? '';
      if (header.trim().isEmpty || !_hasMoodleSessionCookie(header)) {
        debugPrint(
          'LOGIN VERIFY: missing MoodleSession in cookie_header, stay in WebView',
        );
        // даём время CookieManager’у синхронизироваться и попробуем ещё раз
        await Future.delayed(const Duration(milliseconds: 500));
        await _saveCookiesForDomain();
        final header2 = (await _storage.read(key: 'cookie_header')) ?? '';
        if (header2.trim().isEmpty || !_hasMoodleSessionCookie(header2)) {
          debugPrint(
            'LOGIN VERIFY: still no MoodleSession, not leaving WebView',
          );
          return;
        }
      }

      // 3) контрольный запрос через EiosClient: если вернёт login page — НЕ выходим
      try {
        await EiosClient.instance.getHtml(
          'https://eos.imes.su/my/',
          retries: 0,
        );
      } catch (e) {
        debugPrint('LOGIN VERIFY: /my/ via http still not authed: $e');
        return;
      }

      // Всё ок — уходим
      await DemoMode.instance.setEnabled(false);
      await _goToApp();
    } finally {
      _verifying = false;
    }
  }

  Future<void> _maybeDetectLoggedIn(String? url) async {
    if (_didEnterHome) return;

    final urlOk = _urlLooksLoggedIn(url);
    final domOk = await _domLooksLoggedIn();

    if (urlOk || domOk) {
      _didEnterHome = true;
      await _verifyAndEnterApp();
      // если verify не прошёл — разрешим пробовать ещё раз
      if (!mounted) return;
      _didEnterHome = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход в ЭИОС'),
        actions: [
          TextButton.icon(
            onPressed: _enterDemo,
            icon: const Icon(Icons.slideshow_outlined),
            label: const Text('Демо-вход'),
          ),
          const SizedBox(width: 8),
        ],
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
          userAgent:
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        ),
        onWebViewCreated: (c) => _controller = c,
        onProgressChanged: (_, p) => setState(() => _progress = p / 100),
        onLoadStop: (controller, url) async {
          await _maybeDetectLoggedIn(url?.toString());
        },
        shouldOverrideUrlLoading: (controller, action) async {
          final u = action.request.url?.toString();
          // каждый переход — шанс понять, что залогинились
          unawaited(_maybeDetectLoggedIn(u));
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
