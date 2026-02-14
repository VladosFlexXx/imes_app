part of '../../home/tab_grades.dart';

class _CourseCard extends StatefulWidget {
  final GradeCourse course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _pressed = false;

  bool _hasGrade() {
    final g = widget.course.grade;
    return g != null &&
        g.trim().isNotEmpty &&
        g.trim() != '—' &&
        g.trim() != '-';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final any = _hasGrade();
    final grade = widget.course.grade?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1A1E23), Color(0xFF171B21)]
              : const [Color(0xFFF1F3F7), Color(0xFFE9EDF4)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onHighlightChanged: (v) => setState(() => _pressed = v),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.course.courseName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.95)
                            : cs.onSurface.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (any && grade != null)
                    _Badge(text: grade)
                  else
                    Text(
                      '—',
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.86)
                            : cs.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.55)
                        : cs.onSurface.withValues(alpha: 0.54),
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
