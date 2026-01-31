import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_settings.dart';
import '../auth/session_manager.dart';
import '../logging/app_logger.dart';

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

  static const _storage = FlutterSecureStorage();
  final http.Client _client = http.Client();

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

      // если это POST->GET, то тело уже не нужно
      if (method != 'GET' && current is http.Request) {
        // на всякий случай — но у нас метод либо GET либо POST без повторов
      }

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

    Future<http.Response> doRequest(String cookieHeader) {
      return _client
          .get(
            Uri.parse(url),
            headers: {
              'Cookie': cookieHeader,
              'User-Agent': 'Mozilla/5.0',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
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
          throw lastErr ?? Exception('Unknown network error');
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
      throw HttpException('Failed to load page: ${response.statusCode}', uri: Uri.parse(url));
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
