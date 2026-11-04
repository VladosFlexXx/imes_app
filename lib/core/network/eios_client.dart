import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_settings.dart';
import '../auth/session_manager.dart';
import '../logging/app_logger.dart';

enum WebProxyProvider {
  auto,
  yandex,
  cloudflare,
}

class SessionExpiredException implements Exception {
  final String message;
  const SessionExpiredException([this.message = 'Session expired']);

  @override
  String toString() => 'SessionExpiredException: $message';
}

class NoAuthCookiesException implements Exception {
  final String message;
  const NoAuthCookiesException([this.message = 'No auth cookies found']);

  @override
  String toString() => 'NoAuthCookiesException: $message';
}

class EiosClient {
  EiosClient._();
  static final EiosClient instance = EiosClient._();

  static const String kWebProxyYandex = 'https://functions.yandexcloud.net/d4em24u7p4j095oqk5kc';
  static const String kWebProxyCloudflare = 'https://imes-proxy.v-lobanov-o89.workers.dev';
  static const String kWebProxyUrl = kWebProxyYandex;
  static const String _kWebProxyProviderKey = 'web_proxy_provider_choice_v1';

  static const _storage = FlutterSecureStorage();
  final http.Client _client = http.Client();

  WebProxyProvider _proxyProvider = WebProxyProvider.auto;
  String _activeProxyUrl = kWebProxyYandex;
  bool _proxyConfigLoaded = false;

  WebProxyProvider get proxyProvider => _proxyProvider;
  String get activeProxyUrl => _activeProxyUrl;

  Future<void> initProxyProvider() async {
    if (_proxyConfigLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_kWebProxyProviderKey);
      if (val != null) {
        _proxyProvider = WebProxyProvider.values.firstWhere(
          (e) => e.name == val,
          orElse: () => WebProxyProvider.auto,
        );
      }
      if (_proxyProvider == WebProxyProvider.cloudflare) {
        _activeProxyUrl = kWebProxyCloudflare;
      } else {
        _activeProxyUrl = kWebProxyYandex;
      }
    } catch (_) {}
    _proxyConfigLoaded = true;
  }

  Future<void> setProxyProvider(WebProxyProvider provider) async {
    _proxyProvider = provider;
    if (provider == WebProxyProvider.cloudflare) {
      _activeProxyUrl = kWebProxyCloudflare;
    } else {
      _activeProxyUrl = kWebProxyYandex;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kWebProxyProviderKey, provider.name);
    } catch (_) {}
  }

  String? lastWebLoginError;
  String? _cookieHeader;
  bool _cookieLoaded = false;

  void invalidateCookieCache() {
    _cookieLoaded = false;
    _cookieHeader = null;
  }

  Future<String> _getCookieHeader() async {
    if (_cookieLoaded) {
      final v = _cookieHeader;
      if (v == null || v.trim().isEmpty) throw const NoAuthCookiesException();
      return v;
    }

    final cookie = await _storage.read(key: 'cookie_header');
    _cookieLoaded = true;
    _cookieHeader = cookie;

    if (cookie == null || cookie.trim().isEmpty) {
      throw const NoAuthCookiesException();
    }
    return cookie;
  }

  bool _looksLikeLoginPage(String lowerHtml) {
    return lowerHtml.contains('name="username"') &&
        (lowerHtml.contains('name="password"') || lowerHtml.contains('type="password"'));
  }

  bool _isRedirectLoop(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('redirect loop detected');
  }

  bool _isLoginRedirectUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('/login') || u.contains('login/index.php') || u.contains('loginredirect=1');
  }

  bool _isAuthExpiredError(Object e) {
    final s = e.toString().toLowerCase();
    return _isRedirectLoop(e) ||
        s.contains('loginredirect=1') ||
        s.contains('login/index.php') ||
        s.contains('/login');
  }

  // set-cookie может быть одной строкой со многими cookies (и с запятыми из expires)
  List<String> _extractSetCookiePairsFromHeader(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final parts = raw.split(RegExp(r',\s*(?=[^;,]+=)'));
    final out = <String>[];

    for (final p in parts) {
      final s = p.trim();
      if (s.isEmpty) continue;
      final semi = s.indexOf(';');
      final main = (semi >= 0) ? s.substring(0, semi) : s;
      final eq = main.indexOf('=');
      if (eq <= 0) continue;
      out.add(main.trim());
    }
    return out;
  }

  void _mergeCookiePairsIntoJar(Map<String, String> jar, List<String> pairs) {
    for (final p in pairs) {
      final idx = p.indexOf('=');
      if (idx <= 0) continue;
      jar[p.substring(0, idx)] = p.substring(idx + 1);
    }
  }

  String _buildCookieHeaderFromMap(Map<String, String> map) {
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<http.Response> _sendNoRedirect(http.Request req, {Duration timeout = const Duration(seconds: 25)}) async {
    req.followRedirects = false; // ✅ важно: сами обработаем редиректы
    final streamed = await _client.send(req).timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  bool _isRedirectStatus(int code) => code == 301 || code == 302 || code == 303 || code == 307 || code == 308;

  /// ✅ Отправка запроса + ручное следование редиректам с накоплением Set-Cookie на каждом шаге.
  Future<http.Response> _sendWithRedirects(
    http.Request req,
    Map<String, String> jar, {
    Duration timeout = const Duration(seconds: 25),
    int maxHops = 10,
  }) async {
    http.Request current = req;

    for (int hop = 0; hop <= maxHops; hop++) {
      // подкладываем актуальные cookies перед каждым запросом
      final cookieHeader = _buildCookieHeaderFromMap(jar);
      current.headers.remove('Cookie');
      if (cookieHeader.isNotEmpty) current.headers['Cookie'] = cookieHeader;

      final res = await _sendNoRedirect(current, timeout: timeout);

      // собираем cookies с каждого ответа
      _mergeCookiePairsIntoJar(jar, _extractSetCookiePairsFromHeader(res.headers['set-cookie']));

      if (!_isRedirectStatus(res.statusCode)) {
        return res;
      }

      final loc = res.headers['location'];
      if (loc == null || loc.trim().isEmpty) {
        return res; // редирект без location — странно, но выходим
      }

      final nextUri = Uri.parse(loc).isAbsolute ? Uri.parse(loc) : current.url.resolve(loc);

      // 303 обычно означает: следующий запрос должен быть GET
      final nextMethod = (res.statusCode == 303) ? 'GET' : current.method;

      // При 302 после POST многие сервера тоже ждут GET — но не всегда.
      // Moodle обычно ок с GET, так что для 301/302 после POST тоже делаем GET.
      final method = (current.method == 'POST' && (res.statusCode == 301 || res.statusCode == 302))
          ? 'GET'
          : nextMethod;

      final nextReq = http.Request(method, nextUri);
      nextReq.headers.addAll(current.headers);

      // Referer полезен для Moodle
      nextReq.headers['Referer'] = current.url.toString();

      current = nextReq;
    }

    throw Exception('Too many redirects');
  }

  /// ✅ Тихий логин с правильным cookie-flow (сбор куки на редиректах)
  Future<bool> silentLogin({
    required String username,
    required String password,
    bool persistCookieHeader = true,
  }) async {
    final u = username.trim();
    if (u.isEmpty || password.isEmpty) return false;

    final jar = <String, String>{};

    try {
      AppLogger.instance.i('[AUTH] silentLogin start user=$u persist=$persistCookieHeader');

      if (kIsWeb) {
        lastWebLoginError = null;
        await initProxyProvider();

        Future<bool> tryProxyLogin(String proxyUrl, {required Duration timeout}) async {
          AppLogger.instance.i('[AUTH] web silentLogin trying: $proxyUrl (timeout=${timeout.inSeconds}s)');
          final res = await _client
              .post(
                Uri.parse(proxyUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'username': u, 'password': password}),
              )
              .timeout(timeout);

          Map<String, dynamic>? data;
          try {
            data = jsonDecode(res.body) as Map<String, dynamic>?;
          } catch (_) {}

          if (res.statusCode == 200 && data != null && data['success'] == true) {
            final cookie = data['cookie'] as String?;
            if (cookie != null && cookie.isNotEmpty) {
              _cookieHeader = cookie;
              _cookieLoaded = true;
              _activeProxyUrl = proxyUrl;
              if (persistCookieHeader) {
                await _storage.write(key: 'cookie_header', value: cookie);
              }
              AppLogger.instance.i('[AUTH] web silentLogin OK via $proxyUrl');
              return true;
            }
          }

          final err = data?['error'] ?? data?['status'] ?? 'HTTP ${res.statusCode}: ${res.body}';
          final debugInfo = data?['debug'] != null ? ' (${data!['debug']})' : '';
          lastWebLoginError = '$err$debugInfo';
          AppLogger.instance.w('[AUTH] web silentLogin failed via $proxyUrl: $lastWebLoginError');
          return false;
        }

        if (_proxyProvider == WebProxyProvider.yandex) {
          try {
            return await tryProxyLogin(kWebProxyYandex, timeout: const Duration(seconds: 25));
          } catch (e) {
            lastWebLoginError = 'Сетевая ошибка Яндекс: $e';
            AppLogger.instance.e('[AUTH] web silentLogin Yandex error', e);
            return false;
          }
        } else if (_proxyProvider == WebProxyProvider.cloudflare) {
          try {
            return await tryProxyLogin(kWebProxyCloudflare, timeout: const Duration(seconds: 25));
          } catch (e) {
            lastWebLoginError = 'Сетевая ошибка Cloudflare: $e';
            AppLogger.instance.e('[AUTH] web silentLogin Cloudflare error', e);
            return false;
          }
        } else {
          // Auto: Try Yandex first with short 3.5s timeout. If it hangs or fails, fallback to Cloudflare
          try {
            final ok = await tryProxyLogin(kWebProxyYandex, timeout: const Duration(milliseconds: 3500));
            if (ok) return true;
          } catch (e) {
            AppLogger.instance.w('[AUTH] Auto mode: Yandex failed ($e), falling back to Cloudflare');
          }

          if (lastWebLoginError != null && lastWebLoginError!.contains('Неверный логин или пароль')) {
            return false;
          }

          try {
            final ok = await tryProxyLogin(kWebProxyCloudflare, timeout: const Duration(seconds: 25));
            return ok;
          } catch (e) {
            lastWebLoginError = 'Сетевая ошибка (РФ и VPN): $e';
            AppLogger.instance.e('[AUTH] web silentLogin Cloudflare fallback error', e);
            return false;
          }
        }
      }

      // 1) GET login page -> token + cookies
      final getReq = http.Request('GET', Uri.parse('https://eos.imes.su/login/index.php'));
      getReq.headers.addAll({
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      });

      final getRes = await _sendWithRedirects(getReq, jar);
      if (getRes.statusCode != 200) {
        AppLogger.instance.w('[AUTH] silentLogin GET login status=${getRes.statusCode}');
        return false;
      }

      final loginHtml = getRes.body;
      final tokenMatch = RegExp(r'name="logintoken"\s+value="([^"]+)"', caseSensitive: false).firstMatch(loginHtml);
      final token = tokenMatch?.group(1);

      // 2) POST login (ВАЖНО: без авто-редиректов, и собираем cookies на редиректах)
      final postReq = http.Request('POST', Uri.parse('https://eos.imes.su/login/index.php'));
      postReq.headers.addAll({
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': 'https://eos.imes.su/login/index.php',
        'Origin': 'https://eos.imes.su',
      });

      final form = <String, String>{
        'username': u,
        'password': password,
        // Moodle иногда любит это поле (не всегда, но не мешает)
        'anchor': '',
      };
      if (token != null && token.isNotEmpty) {
        form['logintoken'] = token;
      }

      postReq.body = form.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');

      final postRes = await _sendWithRedirects(postReq, jar);
      if (postRes.statusCode != 200 && !_isRedirectStatus(postRes.statusCode)) {
        AppLogger.instance.w('[AUTH] silentLogin POST status=${postRes.statusCode}');
        return false;
      }

      // 3) VERIFY: /my/ (тоже с ручными редиректами + сбор куки)
      final myReq = http.Request('GET', Uri.parse('https://eos.imes.su/my/'));
      myReq.headers.addAll({
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      });

      final myRes = await _sendWithRedirects(myReq, jar);
      if (myRes.statusCode != 200) {
        AppLogger.instance.w('[AUTH] silentLogin VERIFY status=${myRes.statusCode}');
        return false;
      }

      final finalUrl = myRes.request?.url.toString() ?? '';
      final lower = myRes.body.toLowerCase();

      final isStillLogin = _isLoginRedirectUrl(finalUrl) || _looksLikeLoginPage(lower);
      if (isStillLogin) {
        // 👇 лог добавим, чтобы если снова “неверно”, было что смотреть
        final cookieHeaderDbg = _buildCookieHeaderFromMap(jar);
        AppLogger.instance.w('[AUTH] silentLogin FAILED: still login. finalUrl=$finalUrl cookie_len=${cookieHeaderDbg.length}');
        return false;
      }

      final cookieHeader = _buildCookieHeaderFromMap(jar);

      if (persistCookieHeader) {
        await _storage.write(key: 'cookie_header', value: cookieHeader);
        invalidateCookieCache();
      }

      AppLogger.instance.i('[AUTH] silentLogin OK finalUrl=$finalUrl cookie_len=${cookieHeader.length}');
      return true;
    } catch (e, st) {
      AppLogger.instance.e('[AUTH] silentLogin exception', e, st);
      return false;
    }
  }

  Future<bool> _tryReloginIfEnabled() async {
    final s = AuthSettings.instance;

    if (s.mode == AuthReloginMode.safeUiLogin) return false;
    if (!s.credsEnabled) return false;

    final creds = await s.getCredentials();
    if (creds == null) return false;

    return silentLogin(
      username: creds.username,
      password: creds.password,
      persistCookieHeader: true,
    );
  }

  void _markSessionExpired(String reason) {
    AppLogger.instance.w('[AUTH] session expired: $reason');
    SessionManager.instance.markExpired();
  }

  Future<String> getHtml(
    String url, {
    Duration timeout = const Duration(seconds: 20),
    int retries = 1,
  }) async {
    String cookies;
    try {
      cookies = await _getCookieHeader();
    } catch (_) {
      _markSessionExpired('no cookie_header');
      rethrow;
    }

    final parsedUri = Uri.parse(url);
    final isAllowedHost = parsedUri.host.isEmpty || parsedUri.host.endsWith('imes.su');

    Future<http.Response> doRequest(String cookieHeader) async {
      if (kIsWeb) {
        Future<http.Response> makeProxyRequest(String proxyUrl) {
          final uri = Uri.parse(proxyUrl).replace(queryParameters: {
            'url': url,
            if (cookieHeader.isNotEmpty) 'cookie': cookieHeader,
          });
          return _client
              .get(
                uri,
                headers: {
                  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                },
              )
              .timeout(timeout);
        }

        try {
          return await makeProxyRequest(_activeProxyUrl);
        } catch (e) {
          if (_proxyProvider == WebProxyProvider.auto) {
            final fallbackUrl = _activeProxyUrl == kWebProxyYandex
                ? kWebProxyCloudflare
                : kWebProxyYandex;
            AppLogger.instance.w('[HTTP] Web request to $_activeProxyUrl failed, trying fallback $fallbackUrl');
            final resp = await makeProxyRequest(fallbackUrl);
            _activeProxyUrl = fallbackUrl;
            return resp;
          }
          rethrow;
        }
      }

      final headers = <String, String>{
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      };
      if (isAllowedHost) {
        headers['Cookie'] = cookieHeader;
      }
      return _client
          .get(
            parsedUri,
            headers: headers,
          )
          .timeout(timeout);
    }

    final sw = Stopwatch()..start();
    AppLogger.instance.i('[HTTP] GET $url timeout=${timeout.inSeconds}s retries=$retries');

    http.Response? res;
    Exception? lastErr;
    bool reloginTried = false;

    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        res = await doRequest(cookies);
        break;
      } catch (e) {
        final err = Exception(e.toString());
        lastErr = err;

        if (_isAuthExpiredError(e)) {
          AppLogger.instance.w('[HTTP] auth expired on $url err=$e');

          if (!reloginTried) {
            reloginTried = true;

            final ok = await _tryReloginIfEnabled();
            if (ok) {
              cookies = await _getCookieHeader();
              AppLogger.instance.i('[HTTP] retry after silent relogin: $url');
              try {
                res = await doRequest(cookies);
                break;
              } catch (e2) {
                lastErr = Exception(e2.toString());
                _markSessionExpired('silent relogin retry failed');
              }
            } else {
              _markSessionExpired('auth expired (safe mode or no creds)');
            }
          } else {
            _markSessionExpired('auth expired (already tried relogin)');
          }
        }

        if (attempt == retries) {
          sw.stop();
          AppLogger.instance.e('[HTTP] FAIL $url (${sw.elapsedMilliseconds}ms)', lastErr);
          throw lastErr;
        }

        AppLogger.instance.w('[HTTP] ERROR attempt=${attempt + 1}/$retries url=$url err=$e');
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }

    final response = res;
    if (response == null) {
      sw.stop();
      AppLogger.instance.e('[HTTP] FAIL(no response) $url (${sw.elapsedMilliseconds}ms)', lastErr);
      throw lastErr ?? Exception('Unknown network error');
    }

    if (response.statusCode != 200) {
      sw.stop();
      AppLogger.instance.e(
        '[HTTP] ${response.statusCode} $url (${sw.elapsedMilliseconds}ms) bytes=${response.bodyBytes.length}',
      );
      throw Exception('Failed to load page: ${response.statusCode} for $url');
    }

    final html = response.body;
    final lower = html.toLowerCase();
    final finalUrl = response.request?.url.toString() ?? '';

    final redirectedToLogin = _isLoginRedirectUrl(finalUrl) || _looksLikeLoginPage(lower);
    if (redirectedToLogin) {
      sw.stop();
      AppLogger.instance.w('[HTTP] login page detected url=$url finalUrl=$finalUrl (${sw.elapsedMilliseconds}ms)');
      _markSessionExpired('login page detected');
      throw const SessionExpiredException('Moodle returned login page');
    }

    sw.stop();
    AppLogger.instance.i('[HTTP] 200 $url (${sw.elapsedMilliseconds}ms) bytes=${response.bodyBytes.length}');

    if (kDebugMode) {
      // ignore: avoid_print
      print('[EOIS] GET $url -> ${response.statusCode} (${html.length} chars)');
    }

    return html;
  }
}
