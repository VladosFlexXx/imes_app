import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:vuz_app/core/auth/session_manager.dart';
import 'package:vuz_app/core/network/eios_client.dart';
import 'package:vuz_app/features/auth/login_webview.dart';

import '../notifications/notification_service.dart';
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

    _notif.action.addListener(_onNotificationAction);

    _sessionListener = () {
      if (SessionManager.instance.expired.value) {
        _handleSessionExpired();
      }
    };
    SessionManager.instance.expired.addListener(_sessionListener);
  }

  void _onNotificationAction() {
    final act = _notif.action.value;
    if (act == null) return;

    if (act.target == AppNavTarget.schedule) {
      _navigateTo(1);
      ScheduleRepository.instance.refresh();
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
    final bnt = theme.bottomNavigationBarTheme;
    final cs = theme.colorScheme;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _index,
            children: _pages,
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _index,
          onTap: _navigateTo,

          // ✅ ЯВНО: фон/цвета берём из темы
          backgroundColor: bnt.backgroundColor ?? cs.surface,
          selectedItemColor: bnt.selectedItemColor ?? cs.primary,
          unselectedItemColor:
              bnt.unselectedItemColor ?? cs.onSurface.withOpacity(0.7),
          selectedIconTheme:
              bnt.selectedIconTheme ?? IconThemeData(color: cs.primary),
          unselectedIconTheme: bnt.unselectedIconTheme ??
              IconThemeData(color: cs.onSurface.withOpacity(0.7)),
          showUnselectedLabels: bnt.showUnselectedLabels ?? true,

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Главная',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Расписание',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              activeIcon: Icon(Icons.school),
              label: 'Оценки',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}
