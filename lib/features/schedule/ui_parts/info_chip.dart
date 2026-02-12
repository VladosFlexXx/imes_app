part of '../../home/tab_schedule.dart';

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool accentBlue;
  final Color? accentColor;

  const _InfoChip({
    required this.icon,
    required this.text,
    this.accentBlue = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chipBlue = accentColor ?? _scheduleAccent(context);
    final bg = accentBlue
        ? chipBlue
        : (isDark ? const Color(0xFF2A2D33) : const Color(0xFFE7EAF1));
    final border = accentBlue
        ? chipBlue
        : (isDark
              ? const Color(0xFF3A404D)
              : Colors.black.withValues(alpha: 0.14));
    final fg = accentBlue
        ? Colors.white.withValues(alpha: 0.95)
        : (isDark
              ? Colors.white.withValues(alpha: 0.78)
              : cs.onSurface.withValues(alpha: 0.76));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: t.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PillTone { normal, warn }
