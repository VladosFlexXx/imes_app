import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cached_repository.dart';
import '../../core/demo/demo_data.dart';
import '../../core/demo/demo_mode.dart';
import '../schedule/schedule_service.dart';
import 'models.dart';
import 'parser.dart';

const _kRecordbookCacheKey = 'recordbook_cache_v1';
const _kRecordbookUpdatedKey = 'recordbook_cache_updated_v1';

const _recordbookUrl =
    'https://eos.imes.su/local/cdo_academic_progress/academic_progress.php';

List<RecordbookGradebook> _parseRecordbook(String html) =>
    RecordbookParser.parse(html);

class RecordbookRepository extends CachedRepository<List<RecordbookGradebook>> {
  RecordbookRepository._()
    : super(initialData: const [], ttl: const Duration(hours: 12));

  static final RecordbookRepository instance = RecordbookRepository._();

  List<RecordbookGradebook> get gradebooks => data;

  @override
  Future<List<RecordbookGradebook>?> readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRecordbookCacheKey);
      final upd = prefs.getString(_kRecordbookUpdatedKey);

      if (upd != null && upd.trim().isNotEmpty) {
        setUpdatedAtFromCache(DateTime.tryParse(upd));
      }

      if (raw == null || raw.trim().isEmpty) return null;

      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(_fromJsonGradebook).toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCache(
    List<RecordbookGradebook> data,
    DateTime updatedAt,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRecordbookCacheKey,
      jsonEncode(data.map(_toJsonGradebook).toList()),
    );
    await prefs.setString(_kRecordbookUpdatedKey, updatedAt.toIso8601String());
  }

  @override
  Future<List<RecordbookGradebook>> fetchRemote() async {
    if (DemoMode.instance.enabled) {
      return DemoData.recordbook();
    }

    final service = ScheduleService();
    final html = await service.loadPage(_recordbookUrl);
    final parsed = await compute(_parseRecordbook, html);

    parsed.sort((a, b) => a.number.compareTo(b.number));
    for (final g in parsed) {
      g.semesters.sort((a, b) => a.semester.compareTo(b.semester));
    }

    return parsed;
  }

  Map<String, dynamic> _toJsonGradebook(RecordbookGradebook g) => {
    'number': g.number,
    'semesters': g.semesters
        .map(
          (s) => {
            'semester': s.semester,
            'rows': s.rows
                .map(
                  (r) => {
                    'discipline': r.discipline,
                    'date': r.date,
                    'controlType': r.controlType,
                    'mark': r.mark,
                    'retake': r.retake,
                    'teacher': r.teacher,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  };

  RecordbookGradebook _fromJsonGradebook(Map<String, dynamic> j) {
    final semestersRaw =
        (j['semesters'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final semesters = <RecordbookSemester>[];

    for (final s in semestersRaw) {
      final sem = int.tryParse((s['semester'] ?? '0').toString()) ?? 0;
      final rowsRaw =
          (s['rows'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final rows = rowsRaw
          .map(
            (r) => RecordbookRow(
              discipline: (r['discipline'] ?? '').toString(),
              date: (r['date'] ?? '').toString(),
              controlType: (r['controlType'] ?? '').toString(),
              mark: (r['mark'] ?? '').toString(),
              retake: (r['retake'] ?? '').toString(),
              teacher: (r['teacher'] ?? '').toString(),
            ),
          )
          .toList();
      semesters.add(RecordbookSemester(semester: sem, rows: rows));
    }

    semesters.sort((a, b) => a.semester.compareTo(b.semester));

    return RecordbookGradebook(
      number: (j['number'] ?? '').toString(),
      semesters: semesters,
    );
  }
}
