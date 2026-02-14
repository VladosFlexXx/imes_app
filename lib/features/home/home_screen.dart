import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:vuz_app/core/auth/session_manager.dart';
import 'package:vuz_app/core/demo/demo_mode.dart';
import 'package:vuz_app/core/network/eios_client.dart';
import 'package:vuz_app/features/auth/login_webview.dart';
import 'package:vuz_app/ui/app_theme.dart';

import '../notifications/notification_service.dart';
import '../notifications/inbox_repository.dart';
import '../grades/repository.dart';
import '../profile/repository.dart';
import '../recordbook/repository.dart';
import '../schedule/schedule_repository.dart';
import '../study_plan/repository.dart';
import 'tab_dashboard.dart';
import 'tab_grades.dart';
import 'tab_more.dart';
import 'tab_schedule.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();

  late final VoidCallback _sessionListener;

  Future<void> _handleSessionExpired() async {
    if (DemoMode.instance.enabled) return;

    await _storage.delete(key: 'cookie_header');
    EiosClient.instance.invalidateCookieCache();

    SessionManager.instance.reset();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginWebViewScreen()),
      (_) => false,
    );
  }

  int _index = 0;
  DateTime? _lastBackPress;
  final Set<int> _visitedTabs = <int>{0};
  final Set<int> _warmedTabs = <int>{};
  late final AnimationController _tabOverlayController;
  int _tabOverlayDir = 1;

  void _navigateTo(int i) {
    if (i == _index) return;
    final old = _index;
    setState(() {
      _index = i;
      _visitedTabs.add(i);
      _tabOverlayDir = i > old ? 1 : -1;
    });
    _warmTabData(i);
    _tabOverlayController.forward(from: 0);
  }

  final _notif = NotificationService.instance;
  Timer? _deferredRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _warmupCoreData();
    if (DemoMode.instance.enabled) {
      unawaited(NotificationInboxRepository.instance.seedDemoItems());
    }

    _notif.action.addListener(_onNotificationAction);

    _sessionListener = () {
      if (DemoMode.instance.enabled) return;
      if (SessionManager.instance.expired.value) {
        _handleSessionExpired();
      }
    };
    SessionManager.instance.expired.addListener(_sessionListener);
  }

  Future<void> _warmupCoreData() async {
    // На этом этапе только локальный кэш, без сетевых вызовов:
    // это не мешает интро-анимации на главной.
    await Future.wait([
      ScheduleRepository.instance.init(),
      GradesRepository.instance.init(),
      ProfileRepository.instance.init(),
      NotificationInboxRepository.instance.init(),
    ]);

    // Сетевые refresh — только после завершения интро-анимации.
    _deferredRefreshTimer?.cancel();
    _deferredRefreshTimer = Timer(const Duration(milliseconds: 3400), () {
      _warmTabData(_index);
    });
  }

  void _warmTabData(int tabIndex) {
    if (_warmedTabs.contains(tabIndex)) return;
    _warmedTabs.add(tabIndex);

    switch (tabIndex) {
      case 0:
        unawaited(ScheduleRepository.instance.refresh(force: false));
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          unawaited(ProfileRepository.instance.refresh(force: false));
        });
        Future<void>.delayed(const Duration(milliseconds: 850), () {
          unawaited(GradesRepository.instance.refresh(force: false));
        });
        break;
      case 1:
        unawaited(ScheduleRepository.instance.refresh(force: false));
        break;
      case 2:
        unawaited(GradesRepository.instance.refresh(force: false));
        Future<void>.delayed(const Duration(milliseconds: 420), () {
          unawaited(StudyPlanRepository.instance.initAndRefresh(force: false));
        });
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          unawaited(RecordbookRepository.instance.initAndRefresh(force: false));
        });
        break;
      case 3:
        unawaited(ProfileRepository.instance.refresh(force: false));
        break;
    }
  }

  Widget _buildTab(int index) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return DashboardTab(onNavigate: _navigateTo);
      case 1:
        return const ScheduleTab();
      case 2:
        return const GradesTab();
      case 3:
        return const MoreTab();
      default:
        return const SizedBox.shrink();
    }
  }

  void _onNotificationAction() {
    final act = _notif.action.value;
    if (act == null) return;

    switch (act.target) {
      case AppNavTarget.home:
        _navigateTo(0);
        break;
      case AppNavTarget.schedule:
        _navigateTo(1);
        ScheduleRepository.instance.refresh();
        break;
      case AppNavTarget.grades:
        _navigateTo(2);
        break;
      case AppNavTarget.profile:
        _navigateTo(3);
        break;
    }

    _notif.action.value = null;
  }

  @override
  void dispose() {
    _deferredRefreshTimer?.cancel();
    _notif.action.removeListener(_onNotificationAction);
    SessionManager.instance.expired.removeListener(_sessionListener);
    _tabOverlayController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // Назад на любой вкладке -> возвращаем на Главную.
    if (_index != 0) {
      _navigateTo(0);
      return false;
    }

    // На главной: двойное "назад" для выхода.
    final now = DateTime.now();
    final last = _lastBackPress;
    _lastBackPress = now;

    if (last != null && now.difference(last) <= const Duration(seconds: 2)) {
      return true; // закрыть приложение
    }

    // Показываем подсказку.
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Ещё раз назад, чтобы выйти'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = appAccentOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (!context.mounted || !shouldExit) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              IndexedStack(
                index: _index,
                children: List<Widget>.generate(4, _buildTab),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _tabOverlayController,
                    builder: (context, _) {
                      final v = _tabOverlayController.value;
                      if (v <= 0 || v >= 1) return const SizedBox.shrink();
                      final dir = _tabOverlayDir;
                      final dx = (1 - v) * 120 * (dir > 0 ? -1 : 1);
                      return Opacity(
                        opacity: (1 - v) * 0.18,
                        child: Transform.translate(
                          offset: Offset(dx, 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: dir > 0
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                end: dir > 0
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                colors: [
                                  accent.withValues(alpha: 0.42),
                                  accent.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 14,
                child: _GlassBottomNav(
                  index: _index,
                  onTap: _navigateTo,
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final ThemeData theme;

  const _GlassBottomNav({
    required this.index,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = appAccentOf(context);
    final items = const <({String label, IconData icon, IconData activeIcon})>[
      (label: 'Главная', icon: Icons.home_outlined, activeIcon: Icons.home),
      (
        label: 'Расписание',
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today,
      ),
      (label: 'Оценки', icon: Icons.school_outlined, activeIcon: Icons.school),
      (
        label: 'Еще',
        icon: Icons.widgets_outlined,
        activeIcon: Icons.widgets_rounded,
      ),
    ];

    return SizedBox(
      height: 66,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1A1E23).withValues(alpha: 0.78),
                        const Color(0xFF12213E).withValues(alpha: 0.64),
                        const Color(0xFF171B21).withValues(alpha: 0.78),
                      ]
                    : [
                        const Color(0xFFEFF4FF).withValues(alpha: 0.82),
                        const Color(0xFFDDE9FF).withValues(alpha: 0.72),
                        const Color(0xFFF1F5FF).withValues(alpha: 0.82),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : cs.outlineVariant.withValues(alpha: 0.24),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.22)
                      : cs.shadow.withValues(alpha: 0.06),
                  blurRadius: isDark ? 20 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth / items.length;
                final left = width * index;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      left: left + (width - 58) / 2,
                      top: 4,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: 0.56),
                              accent.withValues(alpha: 0.26),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => onTap(i),
                              child: _GlassNavItem(
                                label: items[i].label,
                                icon: i == index
                                    ? items[i].activeIcon
                                    : items[i].icon,
                                selected: i == index,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  const _GlassNavItem({
    required this.label,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = appAccentOf(context);
    final color = selected
        ? accent
        : (isDark
              ? Colors.white.withValues(alpha: 0.78)
              : cs.onSurface.withValues(alpha: 0.72));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: selected ? 24 : 22),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
