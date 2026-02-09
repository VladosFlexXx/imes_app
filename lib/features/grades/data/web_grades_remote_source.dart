import 'package:flutter/foundation.dart';

import '../../../core/network/eios_endpoints.dart';
import '../../schedule/schedule_service.dart';
import '../models.dart';
import '../parser.dart';
import 'grades_remote_source.dart';

List<GradeCourse> _parseOverview(String html) =>
    GradesParser.parseOverview(html);
CourseGradeReport _parseUserReport(Map<String, String> input) =>
    GradesParser.parseUserReport(
      input['html'] ?? '',
      fallbackCourseName: input['fallbackCourseName'] ?? 'Дисциплина',
    );

class WebGradesRemoteSource implements GradesRemoteSource {
  final ScheduleService _service;

  WebGradesRemoteSource({ScheduleService? service})
    : _service = service ?? ScheduleService();

  @override
  Future<List<GradeCourse>> fetchCourses() async {
    final html = await _service.loadPage(EiosEndpoints.gradesOverview);
    final parsed = await compute(_parseOverview, html);
    parsed.sort(
      (a, b) =>
          a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase()),
    );
    return parsed;
  }

  @override
  Future<CourseGradeReport> fetchCourseReport(GradeCourse course) async {
    final reportUrl = _resolveReportUrl(course);
    final html = await _service.loadPage(reportUrl);
    return compute(_parseUserReport, {
      'html': html,
      'fallbackCourseName': course.courseName,
    });
  }

  String _resolveReportUrl(GradeCourse course) {
    final raw = (course.courseUrl ?? '').trim();
    if (raw.isEmpty) {
      throw Exception('Для дисциплины нет ссылки на детальный отчёт.');
    }

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      throw Exception('Некорректный URL отчёта: $raw');
    }

    final id = uri.queryParameters['id']?.trim();
    if (id == null || id.isEmpty) {
      if (raw.contains('/grade/report/user/index.php')) {
        return raw;
      }
      throw Exception('Не удалось определить id курса для отчёта.');
    }

    final user = uri.queryParameters['user']?.trim();
    final q = <String, String>{
      'id': id,
      if (user != null && user.isNotEmpty) 'userid': user,
    };
    final reportUri = Uri.parse(
      '${EiosEndpoints.base}/grade/report/user/index.php',
    ).replace(queryParameters: q);
    return reportUri.toString();
  }
}
