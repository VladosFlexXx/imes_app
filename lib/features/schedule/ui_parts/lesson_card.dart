part of '../../home/tab_schedule.dart';

class _LessonCard extends StatelessWidget {
  final Lesson lesson;

  final bool isToday;
  final bool isOngoing;
  final bool isNext;
  final bool isPast;

  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.isToday,
    required this.isOngoing,
    required this.isNext,
    required this.isPast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _scheduleAccent(context);

    final isCancelled = lesson.status == LessonStatus.cancelled;
    final isFinished = isPast;

    final opacity = 1.0;

    final titleStyle = t.bodyLarge?.copyWith(
      fontWeight: FontWeight.w900,
      fontSize: 35 / 2, // ~17.5
      decoration: isCancelled ? TextDecoration.lineThrough : null,
    );

    final timeStyle = t.bodySmall?.copyWith(
      fontWeight: FontWeight.w900,
      fontSize: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.9)
          : cs.onSurface.withValues(alpha: 0.88),
      decoration: isCancelled ? TextDecoration.lineThrough : null,
    );

    String startTime() {
      final pieces = lesson.time.split('-');
      final raw = pieces.isNotEmpty ? pieces.first.trim() : lesson.time;
      return raw.replaceAll('.', ':');
    }

    String endTime() {
      final pieces = lesson.time.split('-');
      final raw = pieces.length > 1 ? pieces[1].trim() : '';
      return raw.replaceAll('.', ':');
    }

    final lineColor = isOngoing
        ? const Color(0xFF00D04D)
        : (isFinished ? const Color(0xFF5B6070) : accent);
    final typeChipAccent = isFinished ? const Color(0xFF565D6A) : accent;
    final cardBg = isFinished
        ? (isDark ? const Color(0xFF14171C) : const Color(0xFFDCE0E8))
        : (isDark ? const Color(0xFF1A1D23) : const Color(0xFFF1F3F7));
    final cardBorder = isFinished
        ? (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.08))
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.10));
    final subjectColor = isFinished
        ? (isDark
              ? Colors.white.withValues(alpha: 0.82)
              : cs.onSurface.withValues(alpha: 0.72))
        : (isDark
              ? Colors.white.withValues(alpha: 0.96)
              : cs.onSurface.withValues(alpha: 0.92));
    final teacherColor = isFinished
        ? (isDark
              ? Colors.white.withValues(alpha: 0.58)
              : cs.onSurface.withValues(alpha: 0.52))
        : (isDark
              ? Colors.white.withValues(alpha: 0.76)
              : cs.onSurface.withValues(alpha: 0.68));

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? (isFinished ? 0.14 : 0.2) : 0.06,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Column(
                        children: [
                          Text(startTime(), style: timeStyle),
                          const SizedBox(height: 8),
                          Container(
                            width: 4,
                            height: 62,
                            decoration: BoxDecoration(
                              color: lineColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            endTime(),
                            style: t.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.52)
                                  : cs.onSurface.withValues(alpha: 0.52),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lesson.subject,
                                  style: titleStyle?.copyWith(
                                    color: subjectColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (lesson.type.trim().isNotEmpty)
                                _InfoChip(
                                  icon: Icons.circle,
                                  text: lesson.type,
                                  accentBlue: true,
                                  accentColor: typeChipAccent,
                                ),
                              if (lesson.place.trim().isNotEmpty)
                                _InfoChip(
                                  icon: Icons.place_outlined,
                                  text: lesson.place,
                                ),
                            ],
                          ),
                          if (lesson.teacher.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.66)
                                      : cs.onSurface.withValues(alpha: 0.56),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lesson.teacher,
                                    style: t.bodyMedium?.copyWith(
                                      color: teacherColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
