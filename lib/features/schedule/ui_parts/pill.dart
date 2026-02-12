part of '../../home/tab_schedule.dart';

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final _PillTone tone;

  const _Pill({
    required this.icon,
    required this.text,
    this.tone = _PillTone.normal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final accent = _scheduleAccent(context);

    Color border = cs.outlineVariant.withValues(alpha: 0.35);
    Color bg = cs.surfaceContainerHighest.withValues(alpha: 0.35);
    Color fg = cs.onSurface.withValues(alpha: 0.80);

    if (tone == _PillTone.warn) {
      border = accent.withValues(alpha: 0.40);
      bg = accent.withValues(alpha: 0.24);
      fg = accent;
    }

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
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: t.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
