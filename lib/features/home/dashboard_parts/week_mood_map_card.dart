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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _dashboardAccent(context);
    final today = DateTime.now();
    final weekMax = days
        .map((d) => lessonsByDay[d.weekday] ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF121316), Color(0xFF17181C)]
                : const [Color(0xFFEDEEF0), Color(0xFFE7E8EB)],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    'Карта настроения недели',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (int i = 0; i < days.length; i++) ...[
                    Expanded(
                      child: _MiniMoodDay(
                        count: lessonsByDay[days[i].weekday] ?? 0,
                        maxCount: weekMax,
                        label: _dayLabel(days[i].weekday),
                        isToday:
                            days[i].year == today.year &&
                            days[i].month == today.month &&
                            days[i].day == today.day,
                        accent: accent,
                      ),
                    ),
                    if (i != days.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMoodDay extends StatelessWidget {
  final int count;
  final int maxCount;
  final String label;
  final bool isToday;
  final Color accent;

  const _MiniMoodDay({
    required this.count,
    required this.maxCount,
    required this.label,
    required this.isToday,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalized = maxCount <= 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
    const minBarHeight = 16.0;
    const maxBarHeight = 40.0;
    final barHeight = minBarHeight + (maxBarHeight - minBarHeight) * normalized;

    final barBg = isToday
        ? accent
        : (count > 0
              ? (isDark ? const Color(0xFF2E3138) : const Color(0xFFE4E6EB))
              : (isDark ? const Color(0xFF24272E) : const Color(0xFFD6D9E1)));

    final barBorder = isToday
        ? accent.withValues(alpha: 0.95)
        : (isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.10));

    final countColor = isDark
        ? Colors.white.withValues(alpha: isToday ? 0.98 : 0.88)
        : (isToday ? Colors.white : const Color(0xFF2B3240));
    final dayColor = isToday
        ? accent
        : (isDark
              ? Colors.white.withValues(alpha: 0.76)
              : const Color(0xFF596170));

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: count > 0 ? barHeight : 14,
          alignment: Alignment.bottomCenter,
          child: count > 0
              ? Container(
                  width: 30,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: barBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: barBorder),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.42),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: t.labelLarge?.copyWith(
                      color: countColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              : Container(
                  width: 28,
                  height: 2,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.34)
                        : Colors.black.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: t.labelMedium?.copyWith(
            color: dayColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
