import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/network/eios_endpoints.dart';
import '../convert.dart';
import '../merge.dart';
import '../models.dart';
import '../schedule_service.dart';
import 'schedule_remote_source.dart';

List<Lesson> _parseLessons(String html) => lessonsFromHtml(html);

class WebScheduleRemoteSource implements ScheduleRemoteSource {
  final ScheduleService _service;

  WebScheduleRemoteSource({ScheduleService? service})
      : _service = service ?? ScheduleService();

  /// Извлекает динамическую ссылку на изменения в расписании из HTML курса/страницы
  static String? extractChangesUrl(String html) {
    try {
      final doc = html_parser.parse(html);
      final links = doc.querySelectorAll('a[href]');

      // 1. Ищем ссылки с ключевыми словами
      for (final a in links) {
        final href = (a.attributes['href'] ?? '').trim();
        if (href.isEmpty) continue;

        final isViewPage = href.contains('view.php?id=');
        if (!isViewPage) continue;

        // Пропускаем саму страницу курса (id=54) и базовое расписание (id=41428)
        if (href.contains('id=54') || href.contains('id=41428')) continue;

        final text =
            '${a.text} ${a.attributes['title'] ?? ''} ${a.attributes['aria-label'] ?? ''}'
                .toLowerCase();

        final isChange = text.contains('изменен') ||
            text.contains('замен') ||
            text.contains('перенос') ||
            text.contains('сетка');

        if (isChange) {
          if (href.startsWith('http://') || href.startsWith('https://')) {
            final uri = Uri.tryParse(href);
            if (uri != null && uri.host.endsWith('imes.su')) {
              return href;
            }
            return null;
          }
          if (href.startsWith('/')) {
            return '${EiosEndpoints.base}$href';
          }
          return '${EiosEndpoints.base}/$href';
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Future<List<Lesson>> fetchLessons() async {
    final baseHtml = await _service.loadPage(EiosEndpoints.scheduleBase);
    final baseLessons = await compute(_parseLessons, baseHtml);

    String? changesUrl;

    // 1. Ищем актуальную ссылку на изменения в разделе курса id=54
    try {
      final courseHtml = await _service.loadPage(EiosEndpoints.scheduleCourse);
      changesUrl = extractChangesUrl(courseHtml);
    } catch (_) {}

    // 2. Если в курсе 54 не нашлось, проверяем страницу базового расписания
    if (changesUrl == null || changesUrl.trim().isEmpty) {
      changesUrl = extractChangesUrl(baseHtml);
    }

    // 3. Fallback на резервный URL
    changesUrl ??= EiosEndpoints.scheduleChanges;

    List<Lesson> changeLessons = const [];
    try {
      final changesHtml = await _service.loadPage(changesUrl);
      changeLessons = await compute(_parseLessons, changesHtml);
    } catch (_) {}

    return mergeSchedule(base: baseLessons, changes: changeLessons);
  }
}
