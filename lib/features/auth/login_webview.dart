import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:imes_app/core/auth/auth_settings.dart';
import 'package:imes_app/core/demo/demo_mode.dart';
import 'package:imes_app/core/network/eios_client.dart';
import 'package:imes_app/ui/app_haptics.dart';
import 'package:imes_app/ui/app_theme.dart';
import 'package:imes_app/ui/shimmer_skeleton.dart';

import 'login_web_screen.dart';
import '../home/home_screen.dart';
import '../notifications/inbox_repository.dart';

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

  String? _capturedUsername;
  String? _capturedPassword;

  static const String _captureScript = """
    (function() {
      function tryCapture() {
        try {
          var u = document.querySelector('input[name="username"]') || 
                  document.getElementById('username') || 
                  document.querySelector('input[type="text"][autocomplete*="user"]') ||
                  document.querySelector('input[type="email"]');
          var p = document.querySelector('input[name="password"]') || 
                  document.getElementById('password') || 
                  document.querySelector('input[type="password"]');

          if (u && p && u.value && p.value) {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
              window.flutter_inappwebview.callHandler('onCredentialsCaptured', u.value, p.value);
            }
          }
        } catch(e) {}
      }

      document.addEventListener('submit', function(e) {
        tryCapture();
      }, true);

      document.addEventListener('click', function(e) {
        var target = e.target;
        if (target && (target.id === 'loginbtn' || target.type === 'submit' || target.closest('button[type="submit"]'))) {
          tryCapture();
        }
      }, true);

      window.addEventListener('beforeunload', function() {
        tryCapture();
      });

      var interval = setInterval(tryCapture, 800);
      setTimeout(function() { clearInterval(interval); }, 30000);
    })();
  """;

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
    await NotificationInboxRepository.instance.seedDemoItems(replace: true);
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

      // Всё ок — проверяем, нужно ли предложить авто-вход
      await DemoMode.instance.setEnabled(false);

      final auth = AuthSettings.instance;
      final existingCreds = await auth.getCredentials();

      if (_capturedUsername != null &&
          _capturedPassword != null &&
          (existingCreds == null || !auth.credsEnabled)) {
        if (mounted) {
          await _showSaveCredentialsPrompt(
            context,
            _capturedUsername!,
            _capturedPassword!,
          );
        }
      }

      await _goToApp();
    } finally {
      _verifying = false;
    }
  }

  Future<void> _showSaveCredentialsPrompt(
    BuildContext context,
    String username,
    String password,
  ) async {
    final accent = appAccentOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.key_rounded,
                      size: 30,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Включить авто-вход?',
                  textAlign: TextAlign.center,
                  style: t.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_circle_outlined, size: 16, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          username,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Сохранить данные в зашифрованное хранилище (Keystore)? '
                  'Приложение сможет автоматически продлевать сессию в фоне, и вам не придётся заново вводить пароль при истечении сессии.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isDark
                        ? const Color(0xFF141924)
                        : const Color(0xFFF1F5FB),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : cs.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 20, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Пароль защищён аппаратным чипом безопасности смартфона и передаётся только на eos.imes.su.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    AppHaptics.mediumImpact();
                    final auth = AuthSettings.instance;
                    await auth.setCredentials(username: username, password: password);
                    await auth.setCredsEnabled(true);
                    await auth.setMode(AuthReloginMode.silentWithCredentials);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: const Text('Включить авто-вход'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    AppHaptics.selectionClick();
                    Navigator.of(sheetContext).pop();
                  },
                  child: Text(
                    'Не сейчас',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    if (kIsWeb) {
      return const LoginWebScreen();
    }
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
              ? const LoadingSkeletonStrip()
              : const SizedBox(height: 3),
        ),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_startUrl)),
        initialUserScripts: UnmodifiableListView<UserScript>([
          UserScript(
            source: _captureScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
          UserScript(
            source: _captureScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
          sharedCookiesEnabled: true,
          thirdPartyCookiesEnabled: true,
          userAgent:
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        ),
        onWebViewCreated: (c) {
          _controller = c;
          c.addJavaScriptHandler(
            handlerName: 'onCredentialsCaptured',
            callback: (args) {
              if (args.length >= 2) {
                final u = args[0]?.toString() ?? '';
                final p = args[1]?.toString() ?? '';
                if (u.trim().isNotEmpty && p.isNotEmpty) {
                  _capturedUsername = u.trim();
                  _capturedPassword = p;
                  debugPrint('CREDENTIALS CAPTURED: user=$_capturedUsername');
                }
              }
            },
          );
        },
        onProgressChanged: (_, p) => setState(() => _progress = p / 100),
        onLoadStop: (controller, url) async {
          try {
            await controller.evaluateJavascript(source: _captureScript);
          } catch (_) {}
          await _maybeDetectLoggedIn(url?.toString());
        },
        shouldOverrideUrlLoading: (controller, action) async {
          try {
            await controller.evaluateJavascript(source: _captureScript);
          } catch (_) {}
          final u = action.request.url?.toString();
          // каждый переход — шанс понять, что залогинились
          unawaited(_maybeDetectLoggedIn(u));
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }
}
