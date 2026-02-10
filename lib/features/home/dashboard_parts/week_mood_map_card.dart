part of '../tab_dashboard.dart';

class _WeekMoodMapCard extends StatelessWidget {
  final List<DateTime> days;
  final Map<int, int> lessonsByDay;

  const _WeekMoodMapCard({required this.days, required this.lessonsByDay});

  String _dayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Пн';
      case DateTime.tuesday:
        return 'Вт';
      case DateTime.wednesday:
        return 'Ср';
      case DateTime.thursday:
        return 'Чт';
      case DateTime.friday:
        return 'Пт';
      case DateTime.saturday:
        return 'Сб';
      case DateTime.sunday:
      default:
        return 'Вс';
    }
  }

  ({Color bg, Color border, Color fg}) _toneFor(
    int count,
    int weekMax,
    int peakDaysCount,
    ColorScheme cs,
    bool isDark,
  ) {
    if (count <= 0) {
      return (
        bg: isDark ? const Color(0xFF262938) : cs.surfaceContainerHighest,
        border: cs.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.55),
        fg: cs.onSurface.withValues(alpha: isDark ? 0.70 : 0.78),
      );
    }

    if (weekMax <= 0) {
      return (
        bg: isDark ? const Color(0xFF213C39) : const Color(0xFFD8F3EC),
        border: isDark ? const Color(0xFF3C8B82) : const Color(0xFF55B79F),
        fg: isDark ? const Color(0xFFB6F2E5) : const Color(0xFF0E5A4D),
      );
    }

    final ratio = count / weekMax;
    if (ratio >= 0.80) {
      final isRarePeak = peakDaysCount <= 2 && count == weekMax;
      return (
        bg: isDark
            ? (isRarePeak ? const Color(0xFF5E3615) : const Color(0xFF4C3117))
            : (isRarePeak ? const Color(0xFFFFD9B0) : const Color(0xFFFFE1BF)),
        border: isDark
            ? (isRarePeak ? const Color(0xFFFFC987) : const Color(0xFFE3A563))
            : (isRarePeak ? const Color(0xFFCC7A2F) : const Color(0xFFE49A45)),
        fg: isDark
            ? (isRarePeak ? const Color(0xFFFFF1DE) : const Color(0xFFFFE7C8))
            : const Color(0xFF7A3F00),
      );
    }
    if (ratio >= 0.45) {
      return (
        bg: isDark ? const Color(0xFF1E3253) : const Color(0xFFD9E9FF),
        border: isDark ? const Color(0xFF4B8EDF) : const Color(0xFF6FA5E8),
        fg: isDark ? const Color(0xFFD6EBFF) : const Color(0xFF123E6A),
      );
    }
    return (
      bg: isDark ? const Color(0xFF1B3A36) : const Color(0xFFD8F3EC),
      border: isDark ? const Color(0xFF41A28E) : const Color(0xFF55B79F),
      fg: isDark ? const Color(0xFFC2F4E7) : const Color(0xFF0E5A4D),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();

    final heaviest = days
        .map((d) => (day: d, count: lessonsByDay[d.weekday] ?? 0))
        .reduce((a, b) => b.count > a.count ? b : a);
    final weekMax = heaviest.count;
    final peakDaysCount = days
        .where((d) => (lessonsByDay[d.weekday] ?? 0) == weekMax && weekMax > 0)
        .length;

    final summary = heaviest.count == 0
        ? 'Неделя выглядит спокойно'
        : 'Пик нагрузки: ${_dayLabel(heaviest.day.weekday)} (${heaviest.count} пар)';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface.withValues(alpha: 0.94),
              cs.surface.withValues(alpha: 0.86),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Карта настроения недели',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                summary,
                style: t.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.64),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < days.length; i++) ...[
                    Expanded(
                      child: _MoodDayCell(
                        dayLabel: _dayLabel(days[i].weekday),
                        dayNumber: days[i].day,
                        lessonsCount: lessonsByDay[days[i].weekday] ?? 0,
                        isToday:
                            days[i].year == today.year &&
                            days[i].month == today.month &&
                            days[i].day == today.day,
                        tone: _toneFor(
                          lessonsByDay[days[i].weekday] ?? 0,
                          weekMax,
                          peakDaysCount,
                          cs,
                          isDark,
                        ),
                      ),
                    ),
                    if (i != days.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _MoodLegend(
                      text: 'Нет пар',
                      color: isDark
                          ? const Color(0xFF747787)
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    _MoodLegend(
                      text: 'Мало пар',
                      color: isDark
                          ? const Color(0xFF41A28E)
                          : const Color(0xFF2E8C78),
                    ),
                    const SizedBox(width: 8),
                    _MoodLegend(
                      text: 'Средне',
                      color: isDark
                          ? const Color(0xFF4B8EDF)
                          : const Color(0xFF4B86D6),
                    ),
                    const SizedBox(width: 8),
                    _MoodLegend(
                      text: 'Много',
                      color: isDark
                          ? const Color(0xFFE3A563)
                          : const Color(0xFFCC7A2F),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodDayCell extends StatelessWidget {
  final String dayLabel;
  final int dayNumber;
  final int lessonsCount;
  final bool isToday;
  final ({Color bg, Color border, Color fg}) tone;

  const _MoodDayCell({
    required this.dayLabel,
    required this.dayNumber,
    required this.lessonsCount,
    required this.isToday,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday ? tone.fg : tone.border,
          width: isToday ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            dayLabel,
            style: t.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: tone.fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$dayNumber',
            style: t.labelSmall?.copyWith(
              color: tone.fg.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$lessonsCount',
            style: t.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: tone.fg,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            lessonsCount == 1 ? 'пара' : 'пар',
            style: t.labelSmall?.copyWith(
              color: tone.fg.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodLegend extends StatelessWidget {
  final String text;
  final Color color;

  const _MoodLegend({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        text,
        style: t.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
