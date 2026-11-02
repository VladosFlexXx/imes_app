import 'package:flutter/material.dart';

import '../../../ui/app_haptics.dart';
import '../../profile/repository.dart';
import '../../profile/widgets/auth_avatar.dart';
import '../../schedule/schedule_search_screen.dart';
import '../../settings/settings_screen.dart';
import '../tab_profile.dart';

class DesktopScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;
  final Widget body;

  const DesktopScaffold({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    required this.body,
  });

  String _tabTitle(int index) {
    switch (index) {
      case 0:
        return 'Главная';
      case 1:
        return 'Расписание';
      case 2:
        return 'Оценки';
      case 3:
      default:
        return 'Ещё';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = cs.primary;

    final sidebarBg = isDark ? const Color(0xFF0F1117) : const Color(0xFFF3F5F9);
    final contentBg = isDark ? const Color(0xFF0A0B10) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: contentBg,
      body: Row(
        children: [
          // 1. ЛЕВЫЙ САЙДБАР (SIDEBAR)
          Container(
            width: 230,
            decoration: BoxDecoration(
              color: sidebarBg,
              border: Border(right: BorderSide(color: borderColor, width: 1.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Логотип приложения
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [accent, accent.withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Мой ИМЭС',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Студенческий портал',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Навигационные кнопки
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      _DesktopNavItem(
                        icon: Icons.home_rounded,
                        label: 'Главная',
                        selected: currentIndex == 0,
                        onTap: () {
                          AppHaptics.selectionClick();
                          onNavigate(0);
                        },
                      ),
                      const SizedBox(height: 6),
                      _DesktopNavItem(
                        icon: Icons.calendar_today_rounded,
                        label: 'Расписание',
                        selected: currentIndex == 1,
                        onTap: () {
                          AppHaptics.selectionClick();
                          onNavigate(1);
                        },
                      ),
                      const SizedBox(height: 6),
                      _DesktopNavItem(
                        icon: Icons.school_rounded,
                        label: 'Оценки',
                        selected: currentIndex == 2,
                        onTap: () {
                          AppHaptics.selectionClick();
                          onNavigate(2);
                        },
                      ),
                      const SizedBox(height: 6),
                      _DesktopNavItem(
                        icon: Icons.more_horiz_rounded,
                        label: 'Ещё',
                        selected: currentIndex == 3,
                        onTap: () {
                          AppHaptics.selectionClick();
                          onNavigate(3);
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Кнопка Настройки внизу сайдбара
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                  child: _DesktopNavItem(
                    icon: Icons.settings_rounded,
                    label: 'Настройки',
                    selected: false,
                    onTap: () {
                      AppHaptics.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. ОСНОВНАЯ ОБЛАСТЬ (HEADER + CONTENT)
          Expanded(
            child: Column(
              children: [
                // ВЕРХНИЙ ТОПБАР
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: contentBg,
                    border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                  ),
                  child: Row(
                    children: [
                      // Заголовок текущей вкладки
                      Text(
                        _tabTitle(currentIndex),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 32),

                      // Поисковая плашка (Ctrl + K)
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                AppHaptics.selectionClick();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ScheduleSearchScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Поиск по предметам и преподавателям',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.08)
                                            : Colors.black.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Text(
                                        'Ctrl + K',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Статус синхронизации
                      Row(
                        children: [
                          Icon(
                            Icons.sync_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Синхронизировано',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 12,
                                    color: Color(0xFF22C55E),
                                  ),
                                ],
                              ),
                              Text(
                                'Сегодня, ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),

                      // Аватар профиля
                      ListenableBuilder(
                        listenable: ProfileRepository.instance,
                        builder: (context, _) {
                          final profile = ProfileRepository.instance.profile;
                          final avatarUrl = profile?.avatarUrl;

                          return InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              AppHaptics.selectionClick();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ProfileTab()),
                              );
                            },
                            child: Row(
                              children: [
                                ClipOval(
                                  child: AuthAvatar(
                                    avatarUrl: avatarUrl,
                                    radius: 18,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: cs.onSurfaceVariant,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ТЕЛО СТРАНИЦЫ
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = cs.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? Colors.white
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.72)
                      : cs.onSurface.withValues(alpha: 0.72)),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
                color: selected
                    ? Colors.white
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : cs.onSurface.withValues(alpha: 0.85)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
