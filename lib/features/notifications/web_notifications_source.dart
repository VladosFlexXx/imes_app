import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../../core/network/eios_endpoints.dart';
import '../../core/logging/app_logger.dart';
import '../schedule/schedule_service.dart';

class WebNotificationItem {
  final String title;
  final String body;
  final String? link;
  final int createdAtMs;

  const WebNotificationItem({
    required this.title,
    required this.body,
    required this.createdAtMs,
    this.link,
  });
}

class WebNotificationsSource {
  final ScheduleService _service;
  static const _storage = FlutterSecureStorage();

  WebNotificationsSource({ScheduleService? service})
    : _service = service ?? ScheduleService();

  Future<List<WebNotificationItem>> fetchLatest({int maxItems = 30}) async {
    final html = await _service.loadPage(EiosEndpoints.notificationsWeb);
    final now = DateTime.now();
    final doc = html_parser.parse(html);

    final sesskey = _extractSesskey(html);
    final userId = _extractUserId(html, doc);
    AppLogger.instance.i(
      '[NOTIFY] bootstrap sesskey=${sesskey != null && sesskey.isNotEmpty} userId=${userId ?? '-'}',
    );
    if (sesskey != null && sesskey.isNotEmpty) {
      try {
        final ajax = await _fetchFromMoodleAjax(
          sesskey: sesskey,
          userId: userId,
          maxItems: maxItems,
          now: now,
        );
        if (ajax.isNotEmpty) {
          AppLogger.instance.i(
            '[NOTIFY] parsed via ajax: ${ajax.length} item(s)',
          );
          return ajax;
        }
      } catch (e, st) {
        AppLogger.instance.w('[NOTIFY] ajax parse failed: $e');
        if (kDebugMode) {
          // ignore: avoid_print
          print('[NOTIFY] ajax parse failed: $e\n$st');
        }
      }
    }

    final containers = <dynamic>{
      ...doc.querySelectorAll(
        '.notification, li.notification, [data-region="notification"]',
      ),
      ...doc.querySelectorAll(
        '.content-item-container, .list-group-item, .popover-region-content li',
      ),
      ...doc.querySelectorAll('.notification-wrapper, .media.notification'),
    }.toList();

    final viewLinks = doc
        .querySelectorAll('a')
        .where(
          (a) => _clean(a.text)
              .toLowerCase()
              .contains('просмотреть уведомление полностью'),
        )
        .toList();
    for (final a in viewLinks) {
      dynamic p = a.parent;
      for (var i = 0; i < 5 && p != null; i++) {
        if (p.localName == 'li' || p.localName == 'article' || p.localName == 'div') {
          containers.add(p);
          break;
        }
        p = p.parent;
      }
    }

    final out = <WebNotificationItem>[];
    for (final c in containers) {
      final fullText = _clean(c.text ?? '');
      if (fullText.isEmpty) continue;

      final hasViewLink =
          c.querySelector('a[href*="notification"]') != null ||
          fullText.toLowerCase().contains('просмотреть уведомление');
      if (!hasViewLink && fullText.length < 24) continue;

      final title =
          _pickFirst(c, [
            '.notification-title',
            '.subject',
            '.h6',
            'h6',
            'h5',
            'h4',
            'strong',
            'b',
          ]) ??
          _deriveTitle(fullText);
      if (title.isEmpty) continue;

      String body =
          _pickFirst(c, [
            '.notification-message',
            '.description',
            '.content-item-body',
            'p',
          ]) ??
          '';
      body = _clean(body);
      if (body == title) body = '';

      final href = c.querySelector('a[href]')?.attributes['href'];
      final absHref = href == null || href.trim().isEmpty
          ? null
          : _absUrl(href.trim());

      final timeText =
          _pickFirst(c, [
            'time',
            '.time',
            '.date',
            '.metadata',
            '.notification-time',
            '.timecreated',
          ]) ??
          fullText;

      out.add(
        WebNotificationItem(
          title: title,
          body: body,
          link: absHref,
          createdAtMs: _parseRelativeTimeMs(timeText, now),
        ),
      );
      if (out.length >= maxItems) break;
    }

    AppLogger.instance.i(
      '[NOTIFY] html fallback containers=${containers.length} parsed=${out.length}',
    );
    return out;
  }

  Future<List<WebNotificationItem>> _fetchFromMoodleAjax({
    required String sesskey,
    required int? userId,
    required int maxItems,
    required DateTime now,
  }) async {
    final cookieHeader = await _storage.read(key: 'cookie_header');
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      AppLogger.instance.w('[NOTIFY] ajax skipped: no cookie_header');
      return const [];
    }

    final uri = Uri.parse(
      '${EiosEndpoints.base}/lib/ajax/service.php?sesskey=$sesskey&info=message_popup_get_popup_notifications',
    );
    final reqBody = jsonEncode([
      {
        'index': 0,
        'methodname': 'message_popup_get_popup_notifications',
        'args': {
          'limit': maxItems,
          'offset': 0,
          if (userId != null) 'useridto': userId,
        },
      },
    ]);
    AppLogger.instance.i(
      '[NOTIFY] ajax request method=message_popup_get_popup_notifications limit=$maxItems userId=${userId ?? '-'}',
    );

    final res = await http
        .post(
          uri,
          headers: {
            'Cookie': cookieHeader,
            'User-Agent': 'Mozilla/5.0',
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
            'Origin': EiosEndpoints.base,
            'Referer': EiosEndpoints.notificationsWeb,
          },
          body: reqBody,
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('ajax status=${res.statusCode}');
    }
    AppLogger.instance.i('[NOTIFY] ajax status=200 bytes=${res.bodyBytes.length}');

    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) {
      return const [];
    }

    final first = decoded.first;
    if (first is! Map) {
      return const [];
    }
    final error = first['error'];
    if (error is bool && error) {
      final msg = first['exception'] ?? first['message'] ?? 'unknown ajax error';
      throw Exception('ajax error: $msg');
    }

    final data = first['data'];
    if (data is! Map) {
      AppLogger.instance.w('[NOTIFY] ajax data is not map: ${data.runtimeType}');
      return const [];
    }

    dynamic rawItems = data['notifications'];
    rawItems ??= data['messages'];
    if (rawItems is! List) {
      AppLogger.instance.w('[NOTIFY] ajax notifications is not list');
      return const [];
    }

    final out = <WebNotificationItem>[];
    for (final r in rawItems) {
      if (r is! Map) continue;

      final subject = _clean((r['subject'] ?? r['shortenedsubject'] ?? '').toString());
      final fullMessage = _htmlToPlain(
        (r['fullmessagehtml'] ?? r['fullmessage'] ?? r['smallmessage'] ?? '').toString(),
      );
      final body = _clean(fullMessage);
      final title = subject.isNotEmpty ? subject : _deriveTitle(body);
      if (title.isEmpty) continue;

      final contextUrlRaw = (r['contexturl'] ?? r['url'] ?? '').toString().trim();
      final link = contextUrlRaw.isEmpty ? null : _absUrl(contextUrlRaw);

      final tsRaw = r['timecreated'] ?? r['timecreatedfromepoch'] ?? r['timesent'];
      int createdAt = now.millisecondsSinceEpoch;
      if (tsRaw is num) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(tsRaw.toInt() * 1000)
            .millisecondsSinceEpoch;
      } else if (tsRaw != null) {
        final p = int.tryParse(tsRaw.toString());
        if (p != null) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(p * 1000).millisecondsSinceEpoch;
        }
      }

      out.add(
        WebNotificationItem(
          title: title,
          body: body == title ? '' : body,
          link: link,
          createdAtMs: createdAt,
        ),
      );
      if (out.length >= maxItems) break;
    }
    return out;
  }

  static String _clean(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').replaceAll('\u00A0', ' ').trim();

  static String? _pickFirst(dynamic root, List<String> selectors) {
    for (final s in selectors) {
      final text = _clean(root.querySelector(s)?.text ?? '');
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static String _deriveTitle(String full) {
    final t = _clean(full);
    if (t.isEmpty) return '';
    final cut = t.split(RegExp(r'[.!?]')).first.trim();
    return cut.length > 120 ? '${cut.substring(0, 117)}...' : cut;
  }

  static String _htmlToPlain(String html) {
    final frag = html_parser.parseFragment(html);
    return _clean(frag.text ?? '');
  }

  static String? _extractSesskey(String html) {
    final m = RegExp(
      r'"sesskey"\s*:\s*"([^"]+)"|sesskey=([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(html);
    if (m == null) return null;
    final g1 = m.group(1);
    final g2 = m.group(2);
    if (g1 != null && g1.isNotEmpty) return g1;
    if (g2 != null && g2.isNotEmpty) return g2;
    return null;
  }

  static int? _extractUserId(String html, dynamic doc) {
    final m1 = RegExp(r'"userId"\s*:\s*(\d+)').firstMatch(html);
    if (m1 != null) return int.tryParse(m1.group(1)!);

    final raw = doc
        .querySelector('[data-region="popover-region"][data-userid]')
        ?.attributes['data-userid'];
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  static String _absUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${EiosEndpoints.base}$url';
    return '${EiosEndpoints.base}/$url';
  }

  static int _parseRelativeTimeMs(String text, DateTime now) {
    final t = text.toLowerCase();
    final d = RegExp(r'(\d+)\s*д').firstMatch(t);
    final h = RegExp(r'(\d+)\s*ч').firstMatch(t);
    final m = RegExp(r'(\d+)\s*мин').firstMatch(t);
    final justNow = t.contains('только что') || t.contains('сейчас');

    if (justNow) return now.millisecondsSinceEpoch;

    var delta = Duration.zero;
    if (d != null) delta += Duration(days: int.tryParse(d.group(1)!) ?? 0);
    if (h != null) delta += Duration(hours: int.tryParse(h.group(1)!) ?? 0);
    if (m != null) delta += Duration(minutes: int.tryParse(m.group(1)!) ?? 0);

    if (delta == Duration.zero) {
      return now.millisecondsSinceEpoch;
    }
    return now.subtract(delta).millisecondsSinceEpoch;
  }
}
