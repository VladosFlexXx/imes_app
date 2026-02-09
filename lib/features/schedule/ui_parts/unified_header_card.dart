part of '../../home/tab_schedule.dart';

class _UnifiedHeaderCard extends StatelessWidget {
  final String parityText;
  final String rangeText;
  final String updatedText;

  final int dayChanges;

  final String dayTitle;

  final String todayLabel;
  final VoidCallback onTodayTap;

  final bool changesOnly;
  final VoidCallback onToggleChangesOnly;
  final VoidCallback onOpenWeekPicker;

  const _UnifiedHeaderCard({
    required this.parityText,
    required this.rangeText,
    required this.updatedText,
    required this.dayChanges,
    required this.dayTitle,
    required this.todayLabel,
    required this.onTodayTap,
    required this.changesOnly,
    required this.onToggleChangesOnly,
    required this.onOpenWeekPicker,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final titleStyle = t.titleMedium?.copyWith(fontWeight: FontWeight.w900);
    final subStyle = t.bodySmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface.withValues(alpha: 0.78),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Расписание',
                        style: t.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          rangeText,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.sync,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 6),
                Text(updatedText, style: subStyle),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              color: cs.outlineVariant.withValues(alpha: 0.35),
              height: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    dayTitle,
                    style: titleStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.swap_vert_circle_outlined,
                  size: 17,
                  color: cs.onSurface.withValues(alpha: 0.78),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    parityText,
                    style: t.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.82),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TapPill(
                  icon: Icons.calendar_month_outlined,
                  text: 'Неделя',
                  active: true,
                  onTap: onOpenWeekPicker,
                ),
                _TapPill(
                  icon: Icons.today,
                  text: todayLabel,
                  active: true,
                  onTap: onTodayTap,
                ),
                _TapPill(
                  icon: Icons.edit_calendar_outlined,
                  text: 'Изм. $dayChanges',
                  active: changesOnly,
                  onTap: onToggleChangesOnly,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

