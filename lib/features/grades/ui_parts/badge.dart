part of '../../home/tab_grades.dart';

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  double? _scoreRaw(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized);
  }

  double? _scorePercent(String value) {
    final raw = _scoreRaw(value);
    if (raw == null) return null;
    if (raw <= 5.0) return (raw / 5.0) * 100.0;
    if (raw <= 100.0) return raw;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = _scorePercent(text);
    final accent = _gradesAccent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final bool hasScore = p != null;
    final bool low = hasScore && p < 45;
    final bool mid = hasScore && p >= 45 && p < 75;

    final bg = !hasScore
        ? (isDark ? const Color(0xFF2B3040) : const Color(0xFFE3E7EF))
        : (low
              ? accent.withValues(alpha: 0.22)
              : (mid
                    ? accent.withValues(alpha: 0.30)
                    : accent.withValues(alpha: 0.42)));
    final fg = isDark
        ? Colors.white.withValues(alpha: 0.95)
        : cs.onSurface.withValues(alpha: 0.92);
    final borderColor = !hasScore
        ? Colors.white.withValues(alpha: 0.14)
        : accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}
