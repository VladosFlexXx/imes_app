import 'package:flutter/material.dart';
import 'dart:async';

import '../grades/repository.dart';
import '../notifications/inbox_repository.dart';
import '../notifications/notifications_center_screen.dart';
import '../profile/repository.dart';
import '../profile/widgets/auth_avatar.dart';
import '../schedule/models.dart';
import '../schedule/schedule_repository.dart';
import '../../ui/shimmer_skeleton.dart';
import '../../ui/app_theme.dart';
import 'tab_profile.dart';

part 'dashboard_parts/greeting_hero.dart';
part 'dashboard_parts/week_progress_strip.dart';
part 'dashboard_parts/week_mood_map_card.dart';
part 'dashboard_parts/next_lesson_card.dart';

final ValueNotifier<bool> _dashboardIntroLoading = ValueNotifier<bool>(true);
bool _dashboardIntroTimerStarted = false;

Color _dashboardAccent(BuildContext context) {
  final palette = Theme.of(context).extension<AppAccentPalette>();
  return palette?.accent ?? Theme.of(context).colorScheme.primary;
}

class DashboardTab extends StatelessWidget {
  final void Function(int index) onNavigate;

  const DashboardTab({super.key, required this.onNavigate});

  void _ensureIntroTimer() {
    if (_dashboardIntroTimerStarted) return;
    _dashboardIntroTimerStarted = true;
    // Чуть длиннее интро, чтобы успевал отрисоваться UI до фоновых обновлений.
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      _dashboardIntroLoading.value = false;
    });
  }

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
    final now = DateTime.now();
    final start = next.start;
    final lesson = next.lesson;

    final end = _parseEndForDate(lesson.time, next.day);
    final isOngoing = end != null && start.isBefore(now) && end.isAfter(now);
    if (isOngoing) return 'уже идёт';

    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfNextDay = startOfToday.add(const Duration(days: 1));
    if (next.day == startOfToday) {
      final diff = start.difference(now);
      final mins = diff.inMinutes;
      if (mins <= 0) return 'скоро';
      if (mins < 60) return 'через $mins мин';

      final hours = diff.inHours;
      final rem = mins - hours * 60;
      if (rem == 0) return 'через $hours ч';
      return 'через $hours ч $rem мин';
    }

    if (next.day == startOfNextDay) {
      return 'завтра в ${lesson.time.split('-').first.trim()}';
    }

    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(next.day.day)}.${two(next.day.month)} в ${lesson.time.split('-').first.trim()}';
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

  bool _isEvenWeek(DateTime d) => _isoWeek(d).isEven;

  double? _parseDecimal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.replaceAll(' ', '').replaceAll(',', '.');
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  double? _avgGrade(List<dynamic> courses) {
    final vals = <double>[];
    for (final c in courses) {
      try {
        final v = _parseDecimal(c.grade as String?);
        if (v == null) continue;
        if (v >= 2 && v <= 10) vals.add(v);
      } catch (_) {}
    }
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  int? _attendancePercent(List<dynamic> courses) {
    final vals = <double>[];
    for (final c in courses) {
      try {
        final v = _parseDecimal(c.percent as String?);
        if (v == null) continue;
        if (v >= 0 && v <= 100) vals.add(v);
      } catch (_) {}
    }
    if (vals.isEmpty) return null;
    return (vals.reduce((a, b) => a + b) / vals.length).round().clamp(0, 100);
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
    _ensureIntroTimer();
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
        _dashboardIntroLoading,
      ]),
      builder: (context, _) {
        final isIntroLoading = _dashboardIntroLoading.value;
        final todayLessons = scheduleRepo.lessonsForDate(DateTime.now());
        final next = _nextLessonUpcoming(scheduleRepo);
        final now = DateTime.now();
        final weekDays = _weekDays(now);
        final lessonsByDay = <int, int>{
          for (final day in weekDays)
            day.weekday: scheduleRepo.lessonsForDate(day).length,
        };
        final totalWeekLessons = weekDays.fold<int>(
          0,
          (sum, day) => sum + scheduleRepo.lessonsForDate(day).length,
        );
        final completedWeekLessons = weekDays.fold<int>(0, (sum, day) {
          var done = 0;
          for (final l in scheduleRepo.lessonsForDate(day)) {
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
        final avgGrade = _avgGrade(gradesRepo.courses);
        final attendance =
            _attendancePercent(gradesRepo.courses) ??
            (totalWeekLessons > 0
                ? ((completedWeekLessons / totalWeekLessons) * 100).round()
                : null);
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
          avgGrade: avgGrade,
          attendance: attendance,
          courseNumber: courseNum,
          next: next,
          subtitleBuilder: _timeToText,
          onOpenSchedule: () => onNavigate(1),
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
          skeletonize: isIntroLoading || isLoading,
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
  final double? avgGrade;
  final int? attendance;
  final int? courseNumber;
  final _UpcomingLesson? next;
  final String Function(_UpcomingLesson) subtitleBuilder;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final bool hasUnreadNotifications;
  final List<DateTime> weekDays;
  final Map<int, int> lessonsByDay;
  final bool skeletonize;

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
    required this.avgGrade,
    required this.attendance,
    required this.courseNumber,
    required this.next,
    required this.subtitleBuilder,
    required this.onOpenSchedule,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.hasUnreadNotifications,
    required this.weekDays,
    required this.lessonsByDay,
    required this.skeletonize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StaggeredSlideBlock(
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
            avgGrade: avgGrade,
            attendance: attendance,
            courseNumber: courseNumber,
            skeletonize: skeletonize,
            onOpenProfile: onOpenProfile,
            onOpenNotifications: onOpenNotifications,
            hasUnreadNotifications: hasUnreadNotifications,
          ),
        ),
        const SizedBox(height: 12),
        _StaggeredSlideBlock(
          index: 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(
                next == null
                    ? 'no-next'
                    : '${next!.lesson.subject}-${next!.lesson.time}-${next!.day.toIso8601String()}',
              ),
              child: _NextLessonCard(
                lesson: next?.lesson,
                subtitle: next == null ? null : subtitleBuilder(next!),
                onOpenSchedule: onOpenSchedule,
                skeletonize: skeletonize,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _StaggeredSlideBlock(
          index: 2,
          child: _WeekMoodMapCard(days: weekDays, lessonsByDay: lessonsByDay),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StaggeredSlideBlock extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredSlideBlock({required this.index, required this.child});

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

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    return ValueListenableBuilder<bool>(
      valueListenable: _dashboardIntroLoading,
      builder: (context, intro, _) {
        if (intro) {
          return Container(
            width: width == double.infinity ? null : width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.14),
            ),
          );
        }
        return ShimmerSkeleton(
          width: width == double.infinity ? double.infinity : width,
          height: height,
          borderRadius: BorderRadius.circular(8),
        );
      },
    );
  }
}
