import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cached_repository.dart';
import '../../core/demo/demo_data.dart';
import '../../core/demo/demo_mode.dart';
import 'data/grades_remote_source.dart';
import 'data/web_grades_remote_source.dart';
import 'models.dart';

const _kGradesCacheKey = 'grades_cache_v1';
const _kGradesUpdatedKey = 'grades_cache_updated_v1';

class GradesRepository extends CachedRepository<List<GradeCourse>> {
  final GradesRemoteSource _remoteSource;

  GradesRepository._({GradesRemoteSource? remoteSource})
    : _remoteSource = remoteSource ?? WebGradesRemoteSource(),
      super(
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
    if (DemoMode.instance.enabled) {
      return DemoData.grades();
    }
    return _remoteSource.fetchCourses();
  }

  Map<String, dynamic> _toJson(GradeCourse c) => {
    'courseName': c.courseName,
    'courseUrl': c.courseUrl,
    'columns': c.columns,
  };

  GradeCourse _fromJson(Map<String, dynamic> j) => GradeCourse(
    courseName: (j['courseName'] ?? '').toString(),
    courseUrl: (j['courseUrl'] as String?)?.toString(),
    columns: ((j['columns'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
  );
}
