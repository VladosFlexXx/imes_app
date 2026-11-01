part of '../../home/tab_schedule.dart';

class _WeekDotsRowAnimated extends StatelessWidget {
  final DateTime weekStart;
  final int slideDir; // -1 / 0 / +1

  /// Заполненный (выбранный) день, или null если UI-неделя != неделя расписания.
  final int? filledSelectedIndex;

  /// Сегодня (обводка), если UI-неделя = текущая.
  final int? todayIndex;

  final List<String> labels;

  final ValueChanged<int> onTap;
  final ValueChanged<int> onSwipeWeek; // -1 / +1

  const _WeekDotsRowAnimated({
    required this.weekStart,
    required this.slideDir,
    required this.filledSelectedIndex,
    required this.todayIndex,
    required this.labels,
    required this.onTap,
    required this.onSwipeWeek,
  });

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(
      '${weekStart.year}-${weekStart.month}-${weekStart.day}',
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 250) return;
        if (v < 0) {
          onSwipeWeek(1);
        } else {
          onSwipeWeek(-1);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          final beginX = slideDir == 0 ? 0.0 : (slideDir > 0 ? 0.18 : -0.18);

          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(beginX, 0),
                end: Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
          );
        },
        child: _WeekDotsRow(
          key: key,
          weekStart: weekStart,
          filledSelectedIndex: filledSelectedIndex,
          todayIndex: todayIndex,
          labels: labels,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// КРУЖКИ:
/// - выбранный: ЗАЛИВКА (filled)
/// - сегодня: ОБВОДКА (outline), но только если сегодня НЕ выбран (иначе и так видно)
/// - никаких точек

