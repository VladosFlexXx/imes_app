import 'package:flutter/material.dart';

import '../grades/repository.dart';
import '../notifications/inbox_repository.dart';
import '../notifications/notifications_center_screen.dart';
import '../campus/contacts_screen.dart';
import '../campus/floor_plan_screen.dart';
import '../homework/homework_repository.dart';
import '../homework/homework_screen.dart';
import '../profile/repository.dart';
import '../profile/widgets/auth_avatar.dart';
import '../schedule/models.dart';
import '../schedule/schedule_repository.dart';
import '../schedule/lesson_live_status.dart';
import '../schedule/schedule_rule.dart';
import '../schedule/week_parity.dart';
import '../schedule/week_parity_service.dart';
import '../schedule/ui_parts/lesson_details_sheet.dart';
import '../../ui/app_haptics.dart';
import '../../ui/shimmer_skeleton.dart';
import '../../ui/app_theme.dart';
import '../../app.dart';
import '../../core/storage/lesson_notes_storage.dart';
import 'tab_profile.dart';

part 'dashboard_parts/greeting_hero.dart';
part 'dashboard_parts/dashboard_quick_actions.dart';
part 'dashboard_parts/dashboard_deadlines_card.dart';
part 'dashboard_parts/next_lesson_card.dart';

Color _dashboardAccent(BuildContext context) {
  final palette = Theme.of(context).extension<AppAccentPalette>();
  return palette?.accent ?? Theme.of(context).colorScheme.primary;
}

class DashboardTab extends StatelessWidget {
  final void Function(int index) onNavigate;
  final bool animateEntrance;

  /// Сессионный флаг: анимация воспроизводится только 1 раз при запуске.
  static bool hasPlayedEntrance = false;

  const DashboardTab({
    super.key,
    required this.onNavigate,
    this.animateEntrance = true,
  });

  Future<void> _refreshAll() async {
    await Future.wait([
      ScheduleRepository.instance.refresh(force: true),
      GradesRepository.instance.refresh(force: true),
      ProfileRepository.instance.refresh(force: true),
    ]);
  }

  DateTime? _parseStartForDate(String time, DateTime day) {
    final start = time.split('-').first.trim().replaceAll(':', '.');
    final parts = start.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  DateTime? _parseEndForDate(String time, DateTime day) {
    final pieces = time.split('-');
    if (pieces.length < 2) return null;
    final end = pieces[1].trim().replaceAll(':', '.');
    final parts = end.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  _UpcomingLesson? _nextLessonUpcoming(ScheduleRepository repo) {
    final now = DateTime.now();
    _UpcomingLesson? best;

    for (var i = 0; i <= 7; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final lessons = repo.lessonsForDate(day);
      for (final l in lessons) {
        final start = _parseStartForDate(l.time, day);
        if (start == null) continue;

        final end = _parseEndForDate(l.time, day);
        final isOngoing =
            end != null && start.isBefore(now) && end.isAfter(now);
        final isFuture = start.isAfter(now);
        if (!isOngoing && !isFuture) continue;

        final candidate = _UpcomingLesson(lesson: l, start: start, day: day);
        if (best == null) {
          best = candidate;
          continue;
        }

        final bestEnd = _parseEndForDate(best.lesson.time, best.day);
        final bestOngoing =
            bestEnd != null && best.start.isBefore(now) && bestEnd.isAfter(now);

        if (bestOngoing) continue;
        if (isOngoing) {
          best = candidate;
          continue;
        }
        if (start.isBefore(best.start)) {
          best = candidate;
        }
      }
    }
    return best;
  }

  String _timeToText(_UpcomingLesson next) {
    final status = LessonLiveStatus.calculate(
      timeStr: next.lesson.time,
      date: next.day,
    );
    if (status.isOngoing) {
      return 'Идёт сейчас · ${status.remainingMinutes} мин';
    }
    return status.label;
  }

  DateTime _weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> _weekDays(DateTime now) {
    final start = _weekStart(now);
    return List<DateTime>.generate(7, (i) => start.add(Duration(days: i)));
  }

  int _isoWeek(DateTime d) {
    final thursday = d.add(
      Duration(days: 4 - (d.weekday == 7 ? 0 : d.weekday)),
    );
    final firstJan = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(firstJan).inDays) / 7).floor() + 1;
  }

  bool _isEvenWeek(DateTime d) {
    final p = WeekParityService.parityFor(d);
    if (p == WeekParity.unknown) return _isoWeek(d).isEven;
    return p == WeekParity.even;
  }

  int _daysUntilWeekend(DateTime date) {
    final wd = date.weekday;
    if (wd == DateTime.saturday || wd == DateTime.sunday) return 0;
    return 6 - wd;
  }

  int? _courseFromProfile(ProfileRepository repo) {
    final p = repo.profile;
    if (p == null) return null;
    for (final e in p.fields.entries) {
      final k = e.key.toLowerCase();
      if (!k.contains('курс')) continue;
      final m = RegExp(r'(\d{1,2})').firstMatch(e.value);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > 0 && n <= 12) return n;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheduleRepo = ScheduleRepository.instance;
    final gradesRepo = GradesRepository.instance;
    final profileRepo = ProfileRepository.instance;
    final inboxRepo = NotificationInboxRepository.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([
        scheduleRepo,
        gradesRepo,
        profileRepo,
        inboxRepo.unreadCount,
        LessonLiveTicker.instance,
      ]),
      builder: (context, _) {
        final now = DateTime.now();
        final todayLessons = scheduleRepo.lessonsForDate(now);
        final next = _nextLessonUpcoming(scheduleRepo);

        var areTodayLessonsDone = false;
        if (todayLessons.isEmpty) {
          areTodayLessonsDone = true;
        } else {
          areTodayLessonsDone = todayLessons.every((l) {
            final end = _parseEndForDate(l.time, now);
            return end != null && end.isBefore(now);
          });
        }

        final tomorrowDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        final tomorrowLessons = scheduleRepo.lessonsForDate(tomorrowDate);

        final weekDays = _weekDays(now);
        final weekLessons = <DateTime, List<Lesson>>{
          for (final day in weekDays) day: scheduleRepo.lessonsForDate(day),
        };
        final lessonsByDay = <int, int>{
          for (final entry in weekLessons.entries)
            entry.key.weekday: entry.value.length,
        };
        final totalWeekLessons = weekLessons.values.fold<int>(
          0,
          (sum, list) => sum + list.length,
        );
        final completedWeekLessons = weekDays.fold<int>(0, (sum, day) {
          var done = 0;
          for (final l in (weekLessons[day] ?? const <Lesson>[])) {
            final end = _parseEndForDate(l.time, day);
            if (end != null && end.isBefore(now)) done++;
          }
          return sum + done;
        });

        final isLoading =
            scheduleRepo.loading || gradesRepo.loading || profileRepo.loading;

        final fullName = profileRepo.profile?.fullName;
        final avatarUrl = profileRepo.profile?.avatarUrl;
        final group = profileRepo.profile?.group;
        final level = profileRepo.profile?.level;
        final daysUntilWeekend = _daysUntilWeekend(now);
        final lessonsTomorrow = tomorrowLessons.length;
        final courseNum = _courseFromProfile(profileRepo);
        final progressPct = totalWeekLessons > 0
            ? ((completedWeekLessons / totalWeekLessons) * 100).round()
            : 0;
        final evenWeek = _isEvenWeek(now);
        final hasUnreadNotifications = inboxRepo.unreadCount.value > 0;

        final content = _DashboardContent(
          key: const ValueKey('dashboard_content'),
          fullName: fullName,
          avatarUrl: avatarUrl,
          lessonsToday: todayLessons.length,
          group: group,
          level: level,
          evenWeek: evenWeek,
          progressPercent: progressPct,
          progressValue: totalWeekLessons > 0
              ? (completedWeekLessons / totalWeekLessons).clamp(0.0, 1.0)
              : 0.0,
          lessonsTomorrow: lessonsTomorrow,
          daysUntilWeekend: daysUntilWeekend,
          courseNumber: courseNum,
          next: next,
          subtitleBuilder: _timeToText,
          onOpenSchedule: () => onNavigate(1),
          onNavigate: onNavigate,
          onOpenProfile: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileTab()));
          },
          onOpenNotifications: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsCenterScreen(),
              ),
            );
          },
          hasUnreadNotifications: hasUnreadNotifications,
          weekDays: weekDays,
          lessonsByDay: lessonsByDay,
          skeletonize: isLoading,
          animateEntrance: animateEntrance && !DashboardTab.hasPlayedEntrance,
          areTodayLessonsDone: areTodayLessonsDone,
          tomorrowLessons: tomorrowLessons,
          tomorrowDate: tomorrowDate,
        );

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 106),
              children: [content],
            ),
          ),
        );
      },
    );
  }
}

class _UpcomingLesson {
  final Lesson lesson;
  final DateTime start;
  final DateTime day;

  const _UpcomingLesson({
    required this.lesson,
    required this.start,
    required this.day,
  });
}

class _DashboardContent extends StatelessWidget {
  final String? fullName;
  final String? avatarUrl;
  final int lessonsToday;
  final String? group;
  final String? level;
  final bool evenWeek;
  final int progressPercent;
  final double progressValue;
  final int lessonsTomorrow;
  final int daysUntilWeekend;
  final int? courseNumber;
  final _UpcomingLesson? next;
  final String Function(_UpcomingLesson) subtitleBuilder;
  final VoidCallback onOpenSchedule;
  final void Function(int index) onNavigate;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final bool hasUnreadNotifications;
  final List<DateTime> weekDays;
  final Map<int, int> lessonsByDay;
  final bool skeletonize;
  final bool animateEntrance;
  final bool areTodayLessonsDone;
  final List<Lesson> tomorrowLessons;
  final DateTime tomorrowDate;

  const _DashboardContent({
    super.key,
    required this.fullName,
    required this.avatarUrl,
    required this.lessonsToday,
    required this.group,
    required this.level,
    required this.evenWeek,
    required this.progressPercent,
    required this.progressValue,
    required this.lessonsTomorrow,
    required this.daysUntilWeekend,
    required this.courseNumber,
    required this.next,
    required this.subtitleBuilder,
    required this.onOpenSchedule,
    required this.onNavigate,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.hasUnreadNotifications,
    required this.weekDays,
    required this.lessonsByDay,
    required this.skeletonize,
    required this.animateEntrance,
    required this.areTodayLessonsDone,
    required this.tomorrowLessons,
    required this.tomorrowDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StaggeredSlideBlock(
          animate: animateEntrance,
          index: 0,
          child: _GreetingHero(
            fullName: fullName,
            avatarUrl: avatarUrl,
            lessonsToday: lessonsToday,
            group: group,
            level: level,
            evenWeek: evenWeek,
            progressPercent: progressPercent,
            progressValue: progressValue,
            lessonsTomorrow: lessonsTomorrow,
            daysUntilWeekend: daysUntilWeekend,
            courseNumber: courseNumber,
            skeletonize: skeletonize,
            onOpenProfile: onOpenProfile,
            onOpenNotifications: onOpenNotifications,
            hasUnreadNotifications: hasUnreadNotifications,
          ),
        ),
        const SizedBox(height: 12),
        _StaggeredSlideBlock(
          animate: animateEntrance,
          index: 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(
                areTodayLessonsDone
                    ? 'evening-tomorrow-${tomorrowLessons.length}-${tomorrowDate.toIso8601String()}'
                    : (next == null
                        ? 'no-next'
                        : '${next!.lesson.subject}-${next!.lesson.time}-${next!.day.toIso8601String()}'),
              ),
              child: _NextLessonCard(
                lesson: next?.lesson,
                date: next?.day,
                subtitle: next == null ? null : subtitleBuilder(next!),
                onOpenSchedule: onOpenSchedule,
                skeletonize: skeletonize,
                areTodayLessonsDone: areTodayLessonsDone,
                tomorrowLessons: tomorrowLessons,
                tomorrowDate: tomorrowDate,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _StaggeredSlideBlock(
          animate: animateEntrance,
          index: 2,
          child: _DashboardQuickActions(onNavigate: onNavigate),
        ),
        const SizedBox(height: 14),
        _StaggeredSlideBlock(
          animate: animateEntrance,
          index: 3,
          child: const _DashboardDeadlinesCard(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StaggeredSlideBlock extends StatefulWidget {
  final int index;
  final Widget child;
  final bool animate;

  const _StaggeredSlideBlock({
    required this.index,
    required this.child,
    required this.animate,
  });

  @override
  State<_StaggeredSlideBlock> createState() => _StaggeredSlideBlockState();
}

class _StaggeredSlideBlockState extends State<_StaggeredSlideBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    final shouldAnimate = widget.animate &&
        !DashboardTab.hasPlayedEntrance &&
        !themeController.reduceAnimations;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: shouldAnimate ? 0 : 1,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 1.0, curve: Curves.easeOut),
      ),
    );
    if (!shouldAnimate) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DashboardTab.hasPlayedEntrance = true;
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (mounted) {
          _controller.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final startFromBottom = mq.size.height * 0.70;
        final slideOffset = startFromBottom * _slideAnimation.value;
        final spreadEase =
            1.0 - Curves.easeOutCubic.transform(_controller.value);
        final spreadOffset = widget.index * 72.0 * spreadEase;
        final offset = slideOffset + spreadOffset;

        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(offset: Offset(0, offset), child: child),
        );
      },
    );
  }
}

class _DashSkLine extends StatelessWidget {
  final double width;
  final double height;

  const _DashSkLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(8),
    );
  }
}
