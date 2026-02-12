part of '../../home/tab_schedule.dart';

class _DayPage extends StatelessWidget {
  final DateTime date;

  final List<Lesson> lessons;
  final Lesson? nextLesson;

  final bool Function(Lesson l) isOngoing;
  final bool Function(Lesson l) isPast;

  final void Function(Lesson l) onLessonTap;

  const _DayPage({
    required this.date,
    required this.lessons,
    required this.nextLesson,
    required this.isOngoing,
    required this.isPast,
    required this.onLessonTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = _scheduleAccent(context);

    if (lessons.isEmpty) {
      return Row(
        children: [
          Icon(Icons.event_busy_outlined, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Нет занятий',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < lessons.length; i++) ...[
          _LessonCard(
            lesson: lessons[i],
            isToday: WeekUtils.isSameDay(date, DateTime.now()),
            isOngoing: isOngoing(lessons[i]),
            isNext:
                nextLesson != null &&
                nextLesson!.day == lessons[i].day &&
                nextLesson!.time == lessons[i].time &&
                nextLesson!.subject == lessons[i].subject,
            isPast: isPast(lessons[i]),
            onTap: () => onLessonTap(lessons[i]),
          ),
        ],
      ],
    );
  }
}
