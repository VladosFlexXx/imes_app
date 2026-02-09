import 'package:flutter/material.dart';

import '../grades/repository.dart';
import '../profile/repository.dart';
import '../schedule/models.dart';
import '../schedule/schedule_repository.dart';

part 'dashboard_parts/greeting_hero.dart';
part 'dashboard_parts/week_progress_strip.dart';
part 'dashboard_parts/week_mood_map_card.dart';
part 'dashboard_parts/next_lesson_card.dart';

class DashboardTab extends StatelessWidget {
  final void Function(int index) onNavigate;

  const DashboardTab({super.key, required this.onNavigate});

  Future<void> _refreshAll() async {
    await Future.wait([
      ScheduleRepository.instance.refresh(force: true),
      GradesRepository.instance.refresh(force: true),
      ProfileRepository.instance.refresh(force: true),
    ]);
  }

  DateTime? _parseStartToday(String time) {
    final start = time.split('-').first.trim();
    final parts = start.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
  }

  DateTime? _parseEndToday(String time) {
    final pieces = time.split('-');
    if (pieces.length < 2) return null;
    final end = pieces[1].trim();
    final parts = end.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
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

  Lesson? _nextLessonToday(List<Lesson> todayLessons) {
    final now = DateTime.now();
    Lesson? best;
    DateTime? bestStart;

    for (final l in todayLessons) {
      final start = _parseStartToday(l.time);
      if (start == null) continue;

      final end = _parseEndToday(l.time);
      final isOngoing = end != null && start.isBefore(now) && end.isAfter(now);
      final isFuture = start.isAfter(now);

      if (!isOngoing && !isFuture) continue;

      if (best == null) {
        best = l;
        bestStart = start;
        continue;
      }

      final bestEnd = _parseEndToday(best.time);
      final bestOngoing =
          bestEnd != null && bestStart!.isBefore(now) && bestEnd.isAfter(now);

      if (bestOngoing) continue;
      if (isOngoing) {
        best = l;
        bestStart = start;
        continue;
      }

      if (start.isBefore(bestStart!)) {
        best = l;
        bestStart = start;
      }
    }

    return best;
  }

  String _timeToText(Lesson lesson) {
    final now = DateTime.now();
    final start = _parseStartToday(lesson.time);
    if (start == null) return '';

    final end = _parseEndToday(lesson.time);
    final isOngoing = end != null && start.isBefore(now) && end.isAfter(now);
    if (isOngoing) return 'уже идёт';

    final diff = start.difference(now);
    final mins = diff.inMinutes;

    if (mins <= 0) return 'скоро';
    if (mins < 60) return 'через $mins мин';

    final hours = diff.inHours;
    final rem = mins - hours * 60;
    if (rem == 0) return 'через $hours ч';
    return 'через $hours ч $rem мин';
  }

  DateTime _weekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> _weekDays(DateTime now) {
    final start = _weekStart(now);
    return List<DateTime>.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final scheduleRepo = ScheduleRepository.instance;
    final gradesRepo = GradesRepository.instance;
    final profileRepo = ProfileRepository.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([scheduleRepo, gradesRepo, profileRepo]),
      builder: (context, _) {
        final todayLessons = scheduleRepo.lessonsForDate(DateTime.now());
        final next = _nextLessonToday(todayLessons);
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

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 106),
              children: [
                if (isLoading) ...[
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 12),
                ],
                _GreetingHero(
                  fullName: fullName,
                  lessonsToday: todayLessons.length,
                ),
                const SizedBox(height: 12),
                _WeekProgressStrip(
                  completed: completedWeekLessons,
                  total: totalWeekLessons,
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(
                      next == null ? 'no-next' : '${next.subject}-${next.time}',
                    ),
                    child: _NextLessonCard(
                      lesson: next,
                      subtitle: next == null ? null : _timeToText(next),
                      onOpenSchedule: () => onNavigate(1),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _WeekMoodMapCard(days: weekDays, lessonsByDay: lessonsByDay),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
