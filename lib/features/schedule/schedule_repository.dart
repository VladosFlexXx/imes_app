import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cached_repository.dart';
import 'convert.dart';
import 'merge.dart';
import 'models.dart';
import 'schedule_rule.dart';
import 'schedule_service.dart';
import 'week_parity.dart';
import 'week_parity_service.dart';

const _kCacheKey = 'schedule_cache_v3';
const _kCacheUpdatedKey = 'schedule_cache_updated_v3';

const _baseUrl = 'https://eos.imes.su/mod/page/view.php?id=41428';
const _changesUrl = 'https://eos.imes.su/mod/page/view.php?id=56446';

List<Lesson> _parseLessons(String html) => lessonsFromHtml(html);

String _normDay(String s) => s.toUpperCase().trim();

class ScheduleRepository extends CachedRepository<List<Lesson>> {
  ScheduleRepository._()
      : super(
          initialData: const [],
          ttl: const Duration(minutes: 10),
        );

  static final ScheduleRepository instance = ScheduleRepository._();

  List<Lesson> get lessons => data;

  /// ✅ ЕДИНЫЙ ИСТОЧНИК ИСТИНЫ:
  /// реальные пары на конкретную дату с учётом:
  /// - чёт/нечет
  /// - конкретных дат
  /// - дня недели
  List<Lesson> lessonsForDate(DateTime date) {
    final dayName = _weekdayRuUpper(date);
    final parity = WeekParityService.parityFor(date);

    return lessons
        .where((l) {
          if (_normDay(l.day) != dayName) return false;

          final rule = ScheduleRule.parseFromSubject(l.subject);

          switch (rule.type) {
            case ScheduleRuleType.always:
              return true;

            case ScheduleRuleType.evenWeeks:
              return parity == WeekParity.even;

            case ScheduleRuleType.oddWeeks:
              return parity == WeekParity.odd;

            case ScheduleRuleType.specificDates:
              return rule.dates.any((dm) {
                final resolved = dm.resolveNear(date);
                return resolved.year == date.year &&
                    resolved.month == date.month &&
                    resolved.day == date.day;
              });
          }
        })
        .toList()
      ..sort((a, b) => _timeRank(a.time).compareTo(_timeRank(b.time)));
  }

  @override
  Future<List<Lesson>?> readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      final updatedRaw = prefs.getString(_kCacheUpdatedKey);

      if (updatedRaw != null && updatedRaw.trim().isNotEmpty) {
        setUpdatedAtFromCache(DateTime.tryParse(updatedRaw));
      }

      if (raw == null || raw.trim().isEmpty) return null;

      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(_lessonFromJson).toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCache(List<Lesson> data, DateTime updatedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(data.map(_lessonToJson).toList());
    await prefs.setString(_kCacheKey, raw);
    await prefs.setString(_kCacheUpdatedKey, updatedAt.toIso8601String());
  }

  @override
  Future<List<Lesson>> fetchRemote() async {
    final service = ScheduleService();

    final baseHtml = await service.loadPage(_baseUrl);
    final baseLessons = await compute(_parseLessons, baseHtml);

    List<Lesson> changeLessons = const [];
    try {
      final changesHtml = await service.loadPage(_changesUrl);
      changeLessons = await compute(_parseLessons, changesHtml);
    } catch (_) {}

    return mergeSchedule(base: baseLessons, changes: changeLessons);
  }

  Map<String, dynamic> _lessonToJson(Lesson l) => {
        'day': l.day,
        'time': l.time,
        'subject': l.subject,
        'place': l.place,
        'type': l.type,
        'teacher': l.teacher,
        'status': l.status.name,
      };

  Lesson _lessonFromJson(Map<String, dynamic> j) => Lesson(
        day: j['day'],
        time: j['time'],
        subject: j['subject'],
        place: j['place'],
        type: j['type'],
        teacher: j['teacher'],
        status: LessonStatus.values.firstWhere(
          (e) => e.name == j['status'],
          orElse: () => LessonStatus.normal,
        ),
      );
}

String _weekdayRuUpper(DateTime d) {
  const map = {
    1: 'ПОНЕДЕЛЬНИК',
    2: 'ВТОРНИК',
    3: 'СРЕДА',
    4: 'ЧЕТВЕРГ',
    5: 'ПЯТНИЦА',
    6: 'СУББОТА',
    7: 'ВОСКРЕСЕНЬЕ',
  };
  return map[d.weekday]!;
}

int _timeRank(String time) {
  final start = time.split('-').first.trim().replaceAll(':', '.');
  final parts = start.split('.');
  final h = int.tryParse(parts[0]) ?? 99;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return h * 100 + m;
}
