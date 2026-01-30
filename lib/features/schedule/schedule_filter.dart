import 'models.dart';
import 'schedule_rule.dart';
import 'week_parity_service.dart';

/// Фильтрация расписания под текущую учебную неделю.
///
/// Текущий UI показывает «одну неделю» целиком (группировка по дням).
/// Поэтому логика такая:
/// - пары с "(чётная/нечётная неделя)" показываем только на нужной чётности
/// - пары с "(16.02, 16.03...)" показываем только если указанная дата попадает
///   в границы текущей учебной недели
/// - остальные пары показываем всегда
List<Lesson> filterLessonsForCurrentWeek(
  List<Lesson> lessons, {
  DateTime? referenceDate,
}) {
  final ref = referenceDate ?? DateTime.now();
  final parity = WeekParityService.parityFor(ref);
  final bounds = WeekParityService.weekBoundsFor(ref);
  final weekStart = bounds.start;
  final weekEnd = bounds.end;

  return lessons.where((l) {
    final rule = ScheduleRule.parseFromSubject(l.subject);
    return rule.appliesForWeek(
      parity: parity,
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
  }).toList();
}
