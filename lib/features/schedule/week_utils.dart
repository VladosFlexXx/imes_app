class WeekUtils {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Понедельник выбранной недели
  static DateTime weekStart(DateTime d) {
    final x = dateOnly(d);
    return x.subtract(Duration(days: x.weekday - DateTime.monday));
  }

  /// Воскресенье выбранной недели
  static DateTime weekEnd(DateTime d) {
    final start = weekStart(d);
    return start.add(const Duration(days: 6));
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool inRange(DateTime d, DateTime start, DateTime end) {
    final x = dateOnly(d);
    final s = dateOnly(start);
    final e = dateOnly(end);
    return !x.isBefore(s) && !x.isAfter(e);
  }

  static bool sameWeek(DateTime a, DateTime b) =>
      isSameDay(weekStart(a), weekStart(b));
}
