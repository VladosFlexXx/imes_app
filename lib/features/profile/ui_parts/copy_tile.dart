part of '../../home/tab_profile.dart';

class _CopyTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onCopy;
  final Color accent;

  const _CopyTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onCopy,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final v = (value ?? '').trim();
    final show = v.isNotEmpty && onCopy != null;

    return InkWell(
      onTap: show ? onCopy : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: accent.withValues(alpha: 0.16),
                border: Border.all(color: accent.withValues(alpha: 0.46)),
              ),
              child: Icon(icon, size: 22, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.86),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (v.isNotEmpty) ? v : '—',
                    style: t.titleMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: v.isNotEmpty ? 0.98 : 0.55),
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (show)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

