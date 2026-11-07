part of '../../home/tab_schedule.dart';

class _LessonCard extends StatefulWidget {
  final Lesson lesson;
  final DateTime? date;

  final bool isToday;
  final bool isOngoing;
  final bool isNext;
  final bool isPast;

  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    this.date,
    required this.isToday,
    required this.isOngoing,
    required this.isNext,
    required this.isPast,
    required this.onTap,
  });

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    LessonNotesStorage.revision.addListener(_onRevisionChanged);
  }

  @override
  void dispose() {
    LessonNotesStorage.revision.removeListener(_onRevisionChanged);
    super.dispose();
  }

  void _onRevisionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _scheduleAccent(context);

    final lesson = widget.lesson;
    final isCancelled = lesson.status == LessonStatus.cancelled;
    final isFinished = widget.isPast;

    final live = widget.isToday
        ? LessonLiveStatus.calculate(
            timeStr: lesson.time,
            date: widget.date ?? DateTime.now(),
          )
        : null;

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

    final lineColor = widget.isOngoing
        ? const Color(0xFF00D04D)
        : (isFinished ? const Color(0xFF5B6070) : accent);
    final typeChipAccent = isFinished ? const Color(0xFF565D6A) : accent;
    final isAmoled = isDark && themeController.amoledBlack;
    final cardBg = isAmoled
        ? Colors.black
        : (isFinished
            ? (isDark ? const Color(0xFF14171C) : const Color(0xFFDCE0E8))
            : (isDark ? const Color(0xFF1A1D23) : const Color(0xFFF1F3F7)));
    final cardBorder = isAmoled
        ? (isFinished
            ? Colors.white.withValues(alpha: 0.10)
            : accent.withValues(alpha: 0.35))
        : (isFinished
            ? (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.08))
            : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.10)));
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
              border: Border.all(
                color: cardBorder,
                width: isAmoled && !isFinished ? 1.2 : 1.0,
              ),
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
              onHighlightChanged: (v) => setState(() => _pressed = v),
              onTap: () {
                AppHaptics.lightImpact();
                widget.onTap();
              },
              child: AnimatedScale(
                scale: _pressed ? 0.985 : 1.0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
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
                            if (widget.isOngoing && live != null && live.isOngoing)
                              Container(
                                width: 4,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: live.progress.clamp(0.08, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
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
                            if (widget.isOngoing && live != null && live.isOngoing) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withValues(alpha: isDark ? 0.20 : 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.45)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _LivePulsingDot(size: 6.5),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Идёт сейчас · ${live.remainingMinutes} мин',
                                      style: const TextStyle(
                                        color: Color(0xFF22C55E),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (widget.isNext && widget.isToday && live != null && live.isUpcoming && (live.startsInMinutes ?? 999) < 120) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 11, color: accent),
                                    const SizedBox(width: 4),
                                    Text(
                                      live.label,
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                                if (widget.date != null &&
                                    LessonNotesStorage.hasNoteSync(
                                      widget.date!,
                                      lesson.subject,
                                      lesson.time,
                                    ))
                                  const _InfoChip(
                                    icon: Icons.edit_note_rounded,
                                    text: 'ДЗ / Заметка',
                                    accentBlue: true,
                                    accentColor: Color(0xFFEAB308),
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
      ),
    );
  }
}

class _LivePulsingDot extends StatefulWidget {
  final double size;

  const _LivePulsingDot({
    this.size = 6.5,
  });

  static const Color color = Color(0xFF22C55E);

  @override
  State<_LivePulsingDot> createState() => _LivePulsingDotState();
}

class _LivePulsingDotState extends State<_LivePulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (themeController.reduceAnimations) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: _LivePulsingDot.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final scale = 0.82 + (0.32 * _animation.value);
        final alpha = 0.50 + (0.50 * _animation.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _LivePulsingDot.color.withValues(alpha: alpha),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _LivePulsingDot.color.withValues(alpha: 0.55 * _animation.value),
                  blurRadius: 6 * _animation.value,
                  spreadRadius: 1 * _animation.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
