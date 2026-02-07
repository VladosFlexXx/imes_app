import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cached_repository.dart';
import '../schedule/schedule_service.dart';
import 'models.dart';
import 'parser.dart';

const _kStudyPlanCacheKey = 'study_plan_cache_v1';
const _kStudyPlanUpdatedKey = 'study_plan_cache_updated_v1';

const _studyPlanUrl = 'https://eos.imes.su/local/cdo_education_plan/education_plan.php';

List<StudyPlanItem> _parseStudyPlan(String html) => StudyPlanParser.parse(html);

class StudyPlanRepository extends CachedRepository<List<StudyPlanItem>> {
  StudyPlanRepository._()
      : super(
          initialData: const [],
          ttl: const Duration(hours: 12),
        );

  static final StudyPlanRepository instance = StudyPlanRepository._();

  List<StudyPlanItem> get items => data;

  @override
  Future<List<StudyPlanItem>?> readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStudyPlanCacheKey);
      final upd = prefs.getString(_kStudyPlanUpdatedKey);

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
  Future<void> writeCache(List<StudyPlanItem> data, DateTime updatedAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kStudyPlanCacheKey,
      jsonEncode(data.map(_toJson).toList()),
    );
    await prefs.setString(_kStudyPlanUpdatedKey, updatedAt.toIso8601String());
  }

  @override
  Future<List<StudyPlanItem>> fetchRemote() async {
    final service = ScheduleService();
    final html = await service.loadPage(_studyPlanUrl);
    final parsed = await compute(_parseStudyPlan, html);

    parsed.sort((a, b) {
      final s = a.semester.compareTo(b.semester);
      if (s != 0) return s;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return parsed;
  }

  Map<String, dynamic> _toJson(StudyPlanItem i) => {
        'semester': i.semester,
        'code': i.code,
        'name': i.name,
        'control': i.control,
        'totalHours': i.totalHours,
        'lectures': i.lectures,
        'practices': i.practices,
        'labs': i.labs,
        'selfWork': i.selfWork,
        'columns': i.columns,
      };

  StudyPlanItem _fromJson(Map<String, dynamic> j) => StudyPlanItem(
        semester: int.tryParse((j['semester'] ?? '0').toString()) ?? 0,
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        control: (j['control'] ?? '').toString(),
        totalHours: (j['totalHours'] ?? '').toString(),
        lectures: (j['lectures'] ?? '').toString(),
        practices: (j['practices'] ?? '').toString(),
        labs: (j['labs'] ?? '').toString(),
        selfWork: (j['selfWork'] ?? '').toString(),
        columns: ((j['columns'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
}
