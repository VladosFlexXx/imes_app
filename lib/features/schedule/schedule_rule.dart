import 'week_parity.dart';

enum ScheduleRuleType {
  /// Всегда показывать.
  always,

  /// Только на чётных неделях.
  evenWeeks,

  /// Только на нечётных неделях.
  oddWeeks,

  /// Только в конкретные даты (dd.MM).
  specificDates,
}

/// Правило отображения пары.
///
/// Moodle в расписании часто хранит ограничения прямо в тексте предмета:
/// - "(четная неделя)"
/// - "(нечетная неделя)"
/// - "(16.02, 16.03, 13.04)"
///
/// Мы парсим это и применяем при фильтрации расписания.
class ScheduleRule {
  final ScheduleRuleType type;
  final List<_DayMonth> dates; // только для specificDates

  const ScheduleRule._(this.type, this.dates);

  factory ScheduleRule.always() => const ScheduleRule._(ScheduleRuleType.always, []);

  factory ScheduleRule.evenWeeks() => const ScheduleRule._(ScheduleRuleType.evenWeeks, []);

  factory ScheduleRule.oddWeeks() => const ScheduleRule._(ScheduleRuleType.oddWeeks, []);

  factory ScheduleRule.specificDates(List<_DayMonth> dates) =>
      ScheduleRule._(ScheduleRuleType.specificDates, dates);

  static ScheduleRule parseFromSubject(String subject) {
    final s = subject.toLowerCase();

    // Важно: "нечетная" содержит "чет", поэтому сначала проверяем "нечет".
    if (s.contains('нечет') && s.contains('недел')) {
      return ScheduleRule.oddWeeks();
    }
    if (s.contains('чет') && s.contains('недел')) {
      return ScheduleRule.evenWeeks();
    }

    // Даты вида 16.02, 24.03 и т.д.
    final reg = RegExp(r'(\b[0-3]?\d)\.(\d{2})\b');
    final matches = reg.allMatches(s).toList();
    if (matches.isNotEmpty) {
      final list = <_DayMonth>[];
      for (final m in matches) {
        final day = int.tryParse(m.group(1) ?? '');
        final month = int.tryParse(m.group(2) ?? '');
        if (day == null || month == null) continue;
        if (month < 1 || month > 12) continue;
        if (day < 1 || day > 31) continue;
        list.add(_DayMonth(day: day, month: month));
      }
      if (list.isNotEmpty) return ScheduleRule.specificDates(list);
    }

    return ScheduleRule.always();
  }

  /// Применяется ли пара на неделе.
  ///
  /// Для weekly-view (как у тебя сейчас):
  /// - even/odd → по чётности текущей недели
  /// - specificDates → если хоть одна дата попадает в границы текущей недели
  bool appliesForWeek({
    required WeekParity parity,
    required DateTime weekStart,
    required DateTime weekEnd,
  }) {
    switch (type) {
      case ScheduleRuleType.always:
        return true;
      case ScheduleRuleType.evenWeeks:
        return parity == WeekParity.even;
      case ScheduleRuleType.oddWeeks:
        return parity == WeekParity.odd;
      case ScheduleRuleType.specificDates:
        if (dates.isEmpty) return false;
        for (final dm in dates) {
          final resolved = dm.resolveNear(weekStart);
          if (!_isBeforeDay(resolved, weekStart) && !_isAfterDay(resolved, weekEnd)) {
            return true;
          }
        }
        return false;
    }
  }
}

class _DayMonth {
  final int day;
  final int month;

  const _DayMonth({required this.day, required this.month});

  /// Moodle обычно не даёт год, поэтому подбираем год, который ближе к [anchor].
  DateTime resolveNear(DateTime anchor) {
    final a = DateTime(anchor.year, anchor.month, anchor.day);
    // Кандидаты: прошлый/текущий/следующий год.
    final candidates = <DateTime>[
      DateTime(a.year - 1, month, day),
      DateTime(a.year, month, day),
      DateTime(a.year + 1, month, day),
    ];

    DateTime best = candidates.first;
    int bestAbs = (best.difference(a).inDays).abs();

    for (final c in candidates.skip(1)) {
      final abs = (c.difference(a).inDays).abs();
      if (abs < bestAbs) {
        best = c;
        bestAbs = abs;
      }
    }
    return best;
  }
}

bool _isBeforeDay(DateTime a, DateTime b) {
  final aa = DateTime(a.year, a.month, a.day);
  final bb = DateTime(b.year, b.month, b.day);
  return aa.isBefore(bb);
}

bool _isAfterDay(DateTime a, DateTime b) {
  final aa = DateTime(a.year, a.month, a.day);
  final bb = DateTime(b.year, b.month, b.day);
  return aa.isAfter(bb);
}
