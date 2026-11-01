part of '../../home/tab_grades.dart';

class _CourseCard extends StatefulWidget {
  final GradeCourse course;
  final bool isInSchedule;
  final int? points;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    this.isInSchedule = false,
    this.points,
    required this.onTap,
  });

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _pressed = false;

  String _cleanName(String raw) {
    var s = raw.trim();
    s = s.replaceAll(
      RegExp(r'^\s*(?:од\s*\.?\s*\d*|дисциплина\s*:?|дисц\s*\.?)\s*', caseSensitive: false),
      '',
    );
    s = s.replaceAll('_', ' ');
    s = s.replaceAll(RegExp(r'\(.*?недел.*?\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\b\d+\s*/\s*\d+(?:\s*/\s*\d+)?\b'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  IconData _subjectIcon(String name) {
    final l = name.toLowerCase();
    if (l.contains('язык') || l.contains('иностран') || l.contains('английск')) {
      return Icons.language_rounded;
    }
    if (l.contains('информ') ||
        l.contains('программ') ||
        l.contains('it') ||
        l.contains('компьют') ||
        l.contains('сетей') ||
        l.contains('баз данных') ||
        l.contains('интеллект')) {
      return Icons.terminal_rounded;
    }
    if (l.contains('эконом') ||
        l.contains('менедж') ||
        l.contains('маркет') ||
        l.contains('бухгалтер') ||
        l.contains('учет') ||
        l.contains('финанс')) {
      return Icons.trending_up_rounded;
    }
    if (l.contains('прав') ||
        l.contains('юрисп') ||
        l.contains('закон') ||
        l.contains('государств')) {
      return Icons.gavel_rounded;
    }
    if (l.contains('математ') ||
        l.contains('статистик') ||
        l.contains('алгебр')) {
      return Icons.calculate_outlined;
    }
    if (l.contains('философ') ||
        l.contains('культур') ||
        l.contains('истор') ||
        l.contains('социол')) {
      return Icons.auto_stories_rounded;
    }
    if (l.contains('безопасн') || l.contains('бжд') || l.contains('охран')) {
      return Icons.security_rounded;
    }
    if (l.contains('физ') || l.contains('спорт')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.menu_book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _gradesAccent(context);
    final cleanTitle = _cleanName(widget.course.courseName);
    final icon = _subjectIcon(cleanTitle);

    final pts = widget.points;
    final isPassed = pts != null && pts >= 50;

    final rawGrade = widget.course.grade?.trim();
    final hasValidGrade = rawGrade != null &&
        rawGrade.isNotEmpty &&
        rawGrade != '—' &&
        rawGrade != '-';

    final isAmoled = isDark && themeController.amoledBlack;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isAmoled
            ? Colors.black
            : (isDark
                ? const Color(0xFF1B2028)
                : const Color(0xFFFFFFFF)),
        border: Border.all(
          color: isAmoled
              ? accent.withValues(alpha: 0.35)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
          width: isAmoled ? 1.2 : 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          onTap: () {
            AppHaptics.selectionClick();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Compact Icon
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
                    ),
                    child: Center(
                      child: Icon(icon, color: accent, size: 18),
                    ),
                  ),
                  const SizedBox(width: 11),

                  // Title and in-schedule badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cleanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            height: 1.22,
                            letterSpacing: -0.2,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.94)
                                : const Color(0xFF1D222C),
                          ),
                        ),
                        if (widget.isInSchedule) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00C853),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'В расписании',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.50)
                                      : Colors.black.withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Points / Score indicator
                  if (pts != null && pts > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$pts',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: isPassed ? const Color(0xFF00C853) : accent,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              ' / 100',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 10.5,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.38)
                                    : Colors.black.withValues(alpha: 0.38),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: SizedBox(
                            width: 38,
                            height: 3,
                            child: LinearProgressIndicator(
                              value: (pts / 100).clamp(0.0, 1.0),
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.10)
                                  : Colors.black.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation(
                                isPassed ? const Color(0xFF00C853) : accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (hasValidGrade)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
                      ),
                      child: Text(
                        rawGrade,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: accent,
                        ),
                      ),
                    )
                  else
                    Text(
                      '—',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.25),
                      ),
                    ),

                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.28)
                        : Colors.black.withValues(alpha: 0.25),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
