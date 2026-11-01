part of '../tab_dashboard.dart';

class _DashboardDeadlinesCard extends StatelessWidget {
  const _DashboardDeadlinesCard();

  String _formatDeadline(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dt.year, dt.month, dt.day);
    final diff = deadlineDay.difference(today).inDays;

    if (diff < 0) return 'Просрочено';
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Завтра';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }

  Color _deadlineColor(DateTime dt, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dt.year, dt.month, dt.day);
    final diff = deadlineDay.difference(today).inDays;

    if (diff < 0) return const Color(0xFFFF5C5C);
    if (diff <= 1) return const Color(0xFFFF9800);
    return isDark ? Colors.white60 : Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _dashboardAccent(context);
    final repo = HomeworkRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final deadlines = repo.upcomingDeadlines.take(2).toList();
        final activeCount = repo.activeCount;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF131518), Color(0xFF181A20)]
                    : const [Color(0xFFEDEEF0), Color(0xFFE7E8EB)],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 20, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'Дедлайны и ДЗ',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$activeCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        AppHaptics.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HomeworkScreen()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              'Все',
                              style: t.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 16, color: accent),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (deadlines.isEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activeCount == 0
                              ? 'Все задачи сданы! Добавьте новую при необходимости.'
                              : 'Нет горящих дедлайнов.',
                          style: t.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () {
                          AppHaptics.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HomeworkScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Задание', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ] else ...[
                  for (final item in deadlines) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isDark ? const Color(0xFF1E2128) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              AppHaptics.selectionClick();
                              repo.toggleComplete(item.id);
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.deadline != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: _deadlineColor(item.deadline!, isDark).withValues(alpha: 0.12),
                              ),
                              child: Text(
                                _formatDeadline(item.deadline!),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _deadlineColor(item.deadline!, isDark),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

