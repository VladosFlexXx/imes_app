import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
        (lowerHtml.contains('name="password"') ||
            lowerHtml.contains('type="password"'));
  }

  Future<String> getHtml(
    String url, {
    Duration timeout = const Duration(seconds: 20),
    int retries = 1,
  }) async {
    final cookies = await _getCookieHeader();

    Future<http.Response> doRequest() {
      return _client
          .get(
            Uri.parse(url),
            headers: {
              'Cookie': cookies,
              'User-Agent': 'Mozilla/5.0',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          )
          .timeout(timeout);
    }

    final sw = Stopwatch()..start();
    AppLogger.instance.i('[HTTP] GET $url timeout=${timeout.inSeconds}s retries=$retries');

    http.Response? res;
    Exception? lastErr;

    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        res = await doRequest();
        break;
      } on TimeoutException catch (e) {
        lastErr = e;
        AppLogger.instance.w('[HTTP] TIMEOUT attempt=${attempt + 1}/$retries url=$url');
      } on SocketException catch (e) {
        lastErr = e;
        AppLogger.instance.w('[HTTP] SOCKET attempt=${attempt + 1}/$retries url=$url err=$e');
      } catch (e) {
        lastErr = Exception(e.toString());
        AppLogger.instance.w('[HTTP] ERROR attempt=${attempt + 1}/$retries url=$url err=$e');
      }

      if (attempt == retries) {
        sw.stop();
        AppLogger.instance.e('[HTTP] FAIL $url (${sw.elapsedMilliseconds}ms)', lastErr);
        throw lastErr ?? Exception('Unknown network error');
      }

      await Future<void>.delayed(
        Duration(milliseconds: 250 * (attempt + 1)),
      );
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
    final redirectedToLogin =
        finalUrl.contains('/login') || finalUrl.contains('login/index.php');

    if (redirectedToLogin || _looksLikeLoginPage(lower)) {
      sw.stop();
      AppLogger.instance.w('[HTTP] login page detected url=$url finalUrl=$finalUrl (${sw.elapsedMilliseconds}ms)');
      SessionManager.instance.markExpired();
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
