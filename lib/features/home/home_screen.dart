import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:imes_app/app.dart';

import 'package:imes_app/core/auth/session_manager.dart';
import 'package:imes_app/core/demo/demo_mode.dart';
import 'package:imes_app/core/network/eios_client.dart';
import 'package:imes_app/features/auth/login_webview.dart';
import 'package:imes_app/ui/app_haptics.dart';
import 'package:imes_app/ui/app_theme.dart';
import 'package:imes_app/core/updater/app_update_service.dart';

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
import 'desktop/desktop_dashboard.dart';
import 'desktop/desktop_grades_view.dart';
import 'desktop/desktop_scaffold.dart';
import 'desktop/desktop_schedule_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialDataReady = false});

  final bool initialDataReady;

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
  int _previousIndex = 0;
  int _slideDirection = 1;
  DateTime? _lastBackPress;
  final Set<int> _visitedTabs = <int>{0};
  final Set<int> _warmedTabs = <int>{};
  late final AnimationController _tabTransitionController;
  late final CurvedAnimation _tabAnimation;
  bool _dashboardEntranceDone = false;
  final Map<int, Widget> _tabsCache = <int, Widget>{};

  void _navigateTo(int i) {
    if (i == _index) return;
    AppHaptics.selectionClick();
    final oldIndex = _index;
    final isReduced = themeController.reduceAnimations;

    setState(() {
      _slideDirection = i > oldIndex ? 1 : -1;
      _previousIndex = isReduced ? i : oldIndex;
      _index = i;
      _visitedTabs.add(i);
    });
    _warmTabData(i);

    if (isReduced) {
      _tabTransitionController.reset();
    } else {
      _tabTransitionController.forward(from: 0.0);
    }
  }

  final _notif = NotificationService.instance;
  Timer? _deferredRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _tabAnimation = CurvedAnimation(
      parent: _tabTransitionController,
      curve: Curves.easeOutCubic,
    );
    _tabTransitionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _previousIndex = _index;
        });
      }
    });

    if (widget.initialDataReady) {
      _warmedTabs.add(0);
    } else {
      _warmupCoreData();
    }
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

    // Background check for releases
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        AppUpdateService.instance.checkAndPrompt(context);
      }
    });
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

  Widget _getTab(int index) {
    return _tabsCache.putIfAbsent(index, () {
      Widget content;
      switch (index) {
        case 0:
          content = DashboardTab(
            onNavigate: _navigateTo,
            animateEntrance: !_dashboardEntranceDone,
          );
          _dashboardEntranceDone = true;
          break;
        case 1:
          content = const ScheduleTab();
          break;
        case 2:
          content = const GradesTab();
          break;
        case 3:
          content = const MoreTab();
          break;
        default:
          content = const SizedBox.shrink();
          break;
      }
      return KeyedSubtree(
        key: ValueKey<int>(index),
        child: content,
      );
    });
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
    _tabTransitionController.dispose();
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;

    if (isDesktop) {
      return DesktopScaffold(
        currentIndex: _index,
        onNavigate: _navigateTo,
        body: _index == 0
            ? DesktopDashboard(onNavigate: _navigateTo)
            : (_index == 1 ? DesktopScheduleView(onNavigate: _navigateTo) : (_index == 2 ? DesktopGradesView(onNavigate: _navigateTo) : _getTab(_index))),
      );
    }

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
              AnimatedBuilder(
                animation: _tabAnimation,
                builder: (context, _) {
                  final isTransitioning =
                      !themeController.reduceAnimations &&
                          _tabTransitionController.isAnimating &&
                          _previousIndex != _index;
                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: List<Widget>.generate(4, (i) {
                      if (!_visitedTabs.contains(i)) {
                        return const SizedBox.shrink();
                      }
                      final isCurrent = i == _index;
                      final isPrevious = i == _previousIndex && isTransitioning;

                      final offset = isTransitioning
                          ? (isCurrent
                              ? Offset(
                                  _slideDirection * (1.0 - _tabAnimation.value),
                                  0,
                                )
                              : Offset(-_slideDirection * _tabAnimation.value, 0))
                          : Offset.zero;

                      return Offstage(
                        offstage: !isCurrent && !isPrevious,
                        child: FractionalTranslation(
                          translation: offset,
                          child: _getTab(i),
                        ),
                      );
                    }),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 96,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                          theme.scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
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
                  reduceEffects: themeController.reduceEffects,
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
  final bool reduceEffects;

  const _GlassBottomNav({
    required this.index,
    required this.onTap,
    required this.theme,
    this.reduceEffects = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final accent = appAccentOf(context);
    final density = appDensityOf(context);
    final barHeight = density.navBarHeight;
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

    final navContainer = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isAmoled
            ? (reduceEffects
                ? Colors.black
                : Colors.black.withValues(alpha: 0.20))
            : (reduceEffects
                ? (isDark ? const Color(0xFF1B2027) : const Color(0xFFF1F5FB))
                : null),
        gradient: (isAmoled || reduceEffects)
            ? null
            : LinearGradient(
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
          color: isAmoled
              ? accent.withValues(alpha: 0.35)
              : (isDark
                  ? Colors.white.withValues(alpha: reduceEffects ? 0.12 : 0.14)
                  : cs.outlineVariant.withValues(alpha: reduceEffects ? 0.35 : 0.24)),
          width: isAmoled ? 1.2 : 1.0,
        ),
        boxShadow: isAmoled
            ? []
            : [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: reduceEffects ? 0.28 : 0.22)
                      : cs.shadow.withValues(alpha: reduceEffects ? 0.08 : 0.06),
                  blurRadius: isDark
                      ? (reduceEffects ? 12 : 20)
                      : (reduceEffects ? 8 : 10),
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / items.length;
          final left = width * index;
          final glowSize = (constraints.maxHeight - 8).clamp(36.0, 58.0);
          final glowTop = (constraints.maxHeight - glowSize) / 2;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: left + (width - glowSize) / 2,
                top: glowTop,
                child: Container(
                  width: glowSize,
                  height: glowSize,
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
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            AppHaptics.selectionClick();
                            onTap(i);
                          },
                          child: Center(
                            child: _GlassNavItem(
                              label: items[i].label,
                              icon: i == index
                                  ? items[i].activeIcon
                                  : items[i].icon,
                              selected: i == index,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return SizedBox(
      height: barHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: reduceEffects
            ? navContainer
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: navContainer,
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
    final density = appDensityOf(context);
    final color = selected
        ? accent
        : (isDark
              ? Colors.white.withValues(alpha: 0.78)
              : cs.onSurface.withValues(alpha: 0.72));

    final iconSize = (selected ? 24.0 : 22.0) * density.scale.clamp(0.85, 1.15);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: iconSize),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}


