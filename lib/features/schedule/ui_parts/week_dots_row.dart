part of '../../home/tab_schedule.dart';

class _WeekDotsRow extends StatelessWidget {
  final DateTime weekStart;
  final int? filledSelectedIndex;
  final int? todayIndex;
  final List<String> labels;
  final ValueChanged<int> onTap;

  const _WeekDotsRow({
    super.key,
    required this.weekStart,
    required this.filledSelectedIndex,
    required this.todayIndex,
    required this.labels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _scheduleAccent(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final raw = (constraints.maxWidth - gap * 6) / 7;
        final size = raw.clamp(40.0, 54.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(labels.length, (i) {
            final isSelected =
                filledSelectedIndex != null && i == filledSelectedIndex;
            final isToday = todayIndex != null && i == todayIndex;

            final date = weekStart.add(Duration(days: i));
            final dayNum = date.day;

            final bg = isSelected
                ? accent
                : (isDark
                      ? const Color(0xFF20232A)
                      : cs.surfaceContainerHighest);

            // сегодня обводим только если НЕ выбран (иначе будет “обводка + заливка”)
            final showTodayOutline = isToday && !isSelected;

            final borderColor = isSelected
                ? accent
                : (showTodayOutline
                      ? accent
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : cs.outlineVariant.withValues(alpha: 0.62)));

            final borderWidth = showTodayOutline
                ? 1.6
                : (isSelected ? 0.0 : 1.0);

            final fgMain = isSelected
                ? Colors.white
                : (isDark
                      ? Colors.white.withValues(alpha: 0.88)
                      : cs.onSurface.withValues(alpha: 0.84));
            final fgSub = isSelected
                ? Colors.white.withValues(alpha: 0.86)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.62)
                      : cs.onSurface.withValues(alpha: 0.62));

            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onTap(i),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bg,
                  border: borderWidth == 0.0
                      ? null
                      : Border.all(color: borderColor, width: borderWidth),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: fgMain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: fgSub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
