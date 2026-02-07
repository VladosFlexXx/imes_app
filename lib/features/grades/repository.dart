import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cached_repository.dart';
import '../schedule/schedule_service.dart';
import 'models.dart';
import 'parser.dart';

const _kGradesCacheKey = 'grades_cache_v1';
const _kGradesUpdatedKey = 'grades_cache_updated_v1';

const _gradesOverviewUrl =
    'https://eos.imes.su/grade/report/overview/index.php';

/// compute требует top-level функцию
List<GradeCourse> _parseOverview(String html) => GradesParser.parseOverview(html);

class GradesRepository extends CachedRepository<List<GradeCourse>> {
  GradesRepository._()
      : super(
          initialData: const [],
          ttl: const Duration(minutes: 15), // можно поменять как захочешь
        );

  static final GradesRepository instance = GradesRepository._();

  /// Оставим старые геттеры, чтобы UI не менять
  List<GradeCourse> get courses => data;

  @override
  Future<List<GradeCourse>?> readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kGradesCacheKey);
      final upd = prefs.getString(_kGradesUpdatedKey);

      if (upd != null && upd.trim().isNotEmpty) {
        setUpdatedAtFromCache(DateTime.tryParse(upd));
      }

      if (raw == null || raw.trim().isEmpty) return null;

      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(_fromJson).toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCache(List<GradeCourse> data, DateTime updatedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(data.map(_toJson).toList());
    await prefs.setString(_kGradesCacheKey, raw);
    await prefs.setString(_kGradesUpdatedKey, updatedAt.toIso8601String());
  }

  @override
  Future<List<GradeCourse>> fetchRemote() async {
    final service = ScheduleService(); // HTTP + cookies
    final html = await service.loadPage(_gradesOverviewUrl);

    final parsed = await compute(_parseOverview, html);

    // сортируем по названию курса
    parsed.sort(
      (a, b) => a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase()),
    );

    return parsed;
  }

  Map<String, dynamic> _toJson(GradeCourse c) => {
        'courseName': c.courseName,
        'courseUrl': c.courseUrl,
        'columns': c.columns,
      };

  GradeCourse _fromJson(Map<String, dynamic> j) => GradeCourse(
        courseName: (j['courseName'] ?? '').toString(),
        courseUrl: (j['courseUrl'] as String?)?.toString(),
        columns: ((j['columns'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
}