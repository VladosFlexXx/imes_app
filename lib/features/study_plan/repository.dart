import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cached_repository.dart';
import '../../core/data_source/app_data_source.dart';
import '../../core/demo/demo_data.dart';
import '../../core/demo/demo_mode.dart';
import 'data/api_study_plan_remote_source.dart';
import 'data/study_plan_remote_source.dart';
import 'data/web_study_plan_remote_source.dart';
import 'models.dart';

const _kStudyPlanCacheKey = 'study_plan_cache_v1';
const _kStudyPlanUpdatedKey = 'study_plan_cache_updated_v1';

class StudyPlanRepository extends CachedRepository<List<StudyPlanItem>> {
  final StudyPlanRemoteSource _remoteSource;

  StudyPlanRepository._({StudyPlanRemoteSource? remoteSource})
    : _remoteSource =
          remoteSource ??
          selectDataSource<StudyPlanRemoteSource>(
            web: WebStudyPlanRemoteSource(),
            api: ApiStudyPlanRemoteSource(),
          ),
      super(initialData: const [], ttl: const Duration(hours: 12));

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
    if (DemoMode.instance.enabled) {
      return DemoData.studyPlan();
    }
    return _remoteSource.fetchItems();
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
    columns: ((j['columns'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
  );
}
