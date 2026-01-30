import 'week_parity.dart';

/// Определяет номер учебной недели и чётность.
///
/// В приложении расписание сейчас показывается как «одна неделя» целиком,
/// без выбора конкретной календарной даты. Чтобы понять, какие пары отображать,
/// мы считаем чётность недели относительно старта семестра (неделя №1).
///
/// ⚠️ ВАЖНО: [dateStartWeek1] нужно обновлять при смене семестра.
/// Сейчас выставлено под таблицу с твоего скрина: 19.01–24.01 = неделя №1 (НЕЧЁТНАЯ).
class WeekParityService {
  /// Первый день 1-й учебной недели (обычно понедельник).
  static final DateTime dateStartWeek1 = DateTime(2026, 1, 19);

  /// Получить номер учебной недели (1..N) относительно [dateStartWeek1].
  /// Возвращает -1 если дата раньше начала семестра.
  static int weekNumberFor(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(dateStartWeek1.year, dateStartWeek1.month, dateStartWeek1.day);
    final diffDays = d.difference(s).inDays;
    if (diffDays < 0) return -1;
    return (diffDays ~/ 7) + 1;
  }

  /// Чётность недели для даты.
  static WeekParity parityFor(DateTime date) {
    final weekNumber = weekNumberFor(date);
    if (weekNumber <= 0) return WeekParity.unknown;
    return weekNumber.isEven ? WeekParity.even : WeekParity.odd;
  }

  /// Границы текущей учебной недели (понедельник..воскресенье) для [referenceDate].
  ///
  /// Если дата раньше семестра — возвращаем календарную неделю как fallback.
  static ({DateTime start, DateTime end}) weekBoundsFor(DateTime referenceDate) {
    final weekNumber = weekNumberFor(referenceDate);
    if (weekNumber <= 0) {
      final d = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
      final start = d.subtract(Duration(days: d.weekday - DateTime.monday));
      final end = start.add(const Duration(days: 6));
      return (start: start, end: end);
    }

    final start = DateTime(dateStartWeek1.year, dateStartWeek1.month, dateStartWeek1.day)
        .add(Duration(days: (weekNumber - 1) * 7));
    final end = start.add(const Duration(days: 6));
    return (start: start, end: end);
  }
}
