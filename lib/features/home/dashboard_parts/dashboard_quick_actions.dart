part of '../tab_dashboard.dart';

class _DashboardQuickActions extends StatelessWidget {
  final void Function(int index) onNavigate;

  const _DashboardQuickActions({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _dashboardAccent(context);

    final actions = [
      _QuickActionData(
        icon: Icons.assignment_outlined,
        label: 'Дедлайны',
        onTap: () {
          AppHaptics.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HomeworkScreen()),
          );
        },
      ),
      _QuickActionData(
        icon: Icons.map_outlined,
        label: 'Навигатор',
        onTap: () {
          AppHaptics.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CampusFloorPlanScreen()),
          );
        },
      ),
      _QuickActionData(
        icon: Icons.contacts_outlined,
        label: 'Контакты',
        onTap: () {
          AppHaptics.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CampusContactsScreen()),
          );
        },
      ),
      _QuickActionData(
        icon: Icons.school_outlined,
        label: 'Оценки',
        onTap: () {
          AppHaptics.lightImpact();
          onNavigate(2); // Переход на вкладку Оценки
        },
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: actions[i].onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? const Color(0xFF16181D)
                      : const Color(0xFFEEF1F6),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actions[i].icon, size: 22, color: accent),
                    const SizedBox(height: 6),
                    Text(
                      actions[i].label,
                      style: t.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: isDark ? Colors.white.withValues(alpha: 0.82) : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i < actions.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _QuickActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
