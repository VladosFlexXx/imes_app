part of '../tab_dashboard.dart';

class _NextLessonCard extends StatelessWidget {
  final Lesson? lesson;
  final String? subtitle;
  final VoidCallback onOpenSchedule;
  final bool skeletonize;

  const _NextLessonCard({
    required this.lesson,
    required this.subtitle,
    required this.onOpenSchedule,
    required this.skeletonize,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final baseScale = MediaQuery.textScalerOf(context).scale(1.0);
    final targetScale = (baseScale * 0.92).clamp(0.74, 1.0).toDouble();
    final theme = Theme.of(context);
    final accent = _dashboardAccent(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF111317) : const Color(0xFFEDEEF0);
    final innerBg = isDark ? const Color(0xFF1A1D23) : const Color(0xFFE6E7EA);
    final mainText = isDark ? Colors.white : const Color(0xFF1E2430);
    final subText = isDark
        ? Colors.white.withValues(alpha: 0.76)
        : const Color(0xFF626A78);
    final statusChipBg = isDark
        ? const Color(0xFF0F5A34)
        : const Color(0xFFDDF8E8);
    final statusChipBorder = isDark
        ? const Color(0xFF19A864)
        : const Color(0xFF7EDFA8);
    final statusChipText = isDark
        ? const Color(0xFF74FFB6)
        : const Color(0xFF0B8F4B);

    if (lesson == null) {
      return MediaQuery(
        data: mq.copyWith(textScaler: TextScaler.linear(targetScale)),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          color: cardBg,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.coffee_outlined, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: skeletonize
                          ? const _DashSkLine(width: 180, height: 22)
                          : Text(
                              'Ближайших пар нет',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: mainText,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (skeletonize)
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashSkLine(width: double.infinity, height: 16),
                      SizedBox(height: 6),
                      _DashSkLine(width: 260, height: 16),
                    ],
                  )
                else
                  Text(
                    'Можно немного выдохнуть или проверить расписание на другие дни.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: subText),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenSchedule,
                    icon: const Icon(Icons.view_agenda_outlined),
                    label: const Text('Открыть расписание'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(targetScale)),
      child: Card(
        elevation: 0,
        color: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.09),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: skeletonize
                          ? const _DashSkLine(width: 160, height: 22)
                          : Text(
                              'Ближайшая пара',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: mainText,
                              ),
                            ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: statusChipBg,
                          border: Border.all(color: statusChipBorder),
                        ),
                        child: skeletonize
                            ? const _DashSkLine(width: 90, height: 14)
                            : Text(
                                subtitle!,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: statusChipText,
                                ),
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: innerBg,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: skeletonize
                                ? const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _DashSkLine(
                                        width: double.infinity,
                                        height: 28,
                                      ),
                                      SizedBox(height: 8),
                                      _DashSkLine(width: 220, height: 28),
                                    ],
                                  )
                                : Text(
                                    lesson!.subject,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: mainText,
                                          height: 1.12,
                                        ),
                                  ),
                          ),
                          if (lesson!.type.trim().isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _TypeBadge(text: lesson!.type, accent: accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (skeletonize)
                        const _DashSkLine(width: 120, height: 16)
                      else
                        Text(
                          'чётная неделя',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: subText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            icon: Icons.access_time_rounded,
                            text: lesson!.time,
                            skeletonize: skeletonize,
                            isDark: isDark,
                          ),
                          _Pill(
                            icon: Icons.place_outlined,
                            text: lesson!.place,
                            skeletonize: skeletonize,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      if (lesson!.teacher.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.72)
                                  : const Color(0xFF6B7380),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: skeletonize
                                  ? const _DashSkLine(width: 260, height: 18)
                                  : Text(
                                      lesson!.teacher,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.84,
                                                  )
                                                : const Color(0xFF4E5663),
                                          ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenSchedule,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Открыть расписание'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String text;
  final Color accent;

  const _TypeBadge({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: accent.withValues(alpha: 0.18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool skeletonize;
  final bool isDark;

  const _Pill({
    required this.icon,
    required this.text,
    required this.skeletonize,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isDark ? const Color(0xFF3A3A3D) : const Color(0xFFECEDEF),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark
                ? Colors.white.withValues(alpha: 0.88)
                : const Color(0xFF555D69),
          ),
          const SizedBox(width: 8),
          if (skeletonize)
            const _DashSkLine(width: 90, height: 16)
          else
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.95)
                    : const Color(0xFF38404D),
              ),
            ),
        ],
      ),
    );
  }
}
