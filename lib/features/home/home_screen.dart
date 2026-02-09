import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:vuz_app/core/auth/session_manager.dart';
import 'package:vuz_app/core/demo/demo_mode.dart';
import 'package:vuz_app/core/network/eios_client.dart';
import 'package:vuz_app/features/auth/login_webview.dart';

import '../notifications/notification_service.dart';
import '../notifications/inbox_repository.dart';
import '../schedule/schedule_repository.dart';
import 'tab_dashboard.dart';
import 'tab_grades.dart';
import 'tab_profile.dart';
import 'tab_schedule.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  void _navigateTo(int i) => setState(() => _index = i);

  late final List<Widget> _pages = [
    DashboardTab(onNavigate: _navigateTo),
    const ScheduleTab(),
    const GradesTab(),
    const ProfileTab(),
  ];

  final _notif = NotificationService.instance;

  @override
  void initState() {
    super.initState();

    ScheduleRepository.instance.initAndRefresh();
    NotificationInboxRepository.instance.init();
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
    _notif.action.removeListener(_onNotificationAction);
    SessionManager.instance.expired.removeListener(_sessionListener);
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // Назад на любой вкладке -> возвращаем на Главную.
    if (_index != 0) {
      setState(() => _index = 0);
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              IndexedStack(index: _index, children: _pages),
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
    final items = const <({String label, IconData icon, IconData activeIcon})>[
      (label: 'Главная', icon: Icons.home_outlined, activeIcon: Icons.home),
      (
        label: 'Расписание',
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today,
      ),
      (label: 'Оценки', icon: Icons.school_outlined, activeIcon: Icons.school),
      (label: 'Профиль', icon: Icons.person_outline, activeIcon: Icons.person),
    ];

    return SizedBox(
      height: 66,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF1B2738).withValues(alpha: 0.44),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
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
                              cs.primary.withValues(alpha: 0.30),
                              cs.primary.withValues(alpha: 0.14),
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
    final color = selected ? cs.primary : Colors.white.withValues(alpha: 0.78);

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
