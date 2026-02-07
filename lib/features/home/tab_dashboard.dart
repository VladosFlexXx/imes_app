import 'package:flutter/material.dart';

import '../grades/repository.dart';
import '../profile/repository.dart';
import '../schedule/models.dart';
import '../schedule/schedule_repository.dart';

class DashboardTab extends StatelessWidget {
  final void Function(int index) onNavigate;

  const DashboardTab({
    super.key,
    required this.onNavigate,
  });

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
    return List<DateTime>.generate(
      7,
      (i) => start.add(Duration(days: i)),
    );
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
          for (final day in weekDays) day.weekday: scheduleRepo.lessonsForDate(day).length,
        };
        final totalWeekLessons =
            weekDays.fold<int>(0, (sum, day) => sum + scheduleRepo.lessonsForDate(day).length);
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
          appBar: AppBar(
            title: Text(isLoading ? 'Главная (обновление...)' : 'Главная'),
            bottom: isLoading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Обновить всё',
                onPressed: isLoading ? null : _refreshAll,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
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
                    key: ValueKey(next == null ? 'no-next' : '${next.subject}-${next.time}'),
                    child: _NextLessonCard(
                      lesson: next,
                      subtitle: next == null ? null : _timeToText(next),
                      onOpenSchedule: () => onNavigate(1),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _WeekMoodMapCard(
                  days: weekDays,
                  lessonsByDay: lessonsByDay,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GreetingHero extends StatelessWidget {
  final String? fullName;
  final int lessonsToday;

  const _GreetingHero({
    required this.fullName,
    required this.lessonsToday,
  });

  String _firstName(String? fullName) {
    if (fullName == null) return 'друг';
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'друг';
    // обычно: Фамилия Имя Отчество -> берём Имя
    if (parts.length >= 2) return parts[1];
    return parts.first;
  }

  ({String greeting, _DayPhase phase}) _greetingForNow() {
    final h = DateTime.now().hour;

    if (h >= 5 && h < 12) return (greeting: 'Доброе утро', phase: _DayPhase.morning);
    if (h >= 12 && h < 18) return (greeting: 'Добрый день', phase: _DayPhase.day);
    if (h >= 18 && h < 23) return (greeting: 'Добрый вечер', phase: _DayPhase.evening);
    return (greeting: 'Доброй ночи', phase: _DayPhase.night);
  }

  String _weekdayRu(int wd) {
    switch (wd) {
      case DateTime.monday:
        return 'Понедельник';
      case DateTime.tuesday:
        return 'Вторник';
      case DateTime.wednesday:
        return 'Среда';
      case DateTime.thursday:
        return 'Четверг';
      case DateTime.friday:
        return 'Пятница';
      case DateTime.saturday:
        return 'Суббота';
      case DateTime.sunday:
      default:
        return 'Воскресенье';
    }
  }

  String _monthRu(int m) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  // 🎨 Градиенты под время суток (похоже на твои скрины)
  List<Color> _gradientFor(_DayPhase p) {
    switch (p) {
      case _DayPhase.morning:
        return const [
          Color(0xFFD4CCFF),
          Color(0xFFC5B9FF),
          Color(0xFFBDA8F7),
        ];
      case _DayPhase.day:
        return const [
          Color(0xFFC7CFFF),
          Color(0xFFB9C2FF),
          Color(0xFFA8B0F3),
        ];
      case _DayPhase.evening:
        return const [
          Color(0xFFB8B8E5),
          Color(0xFFA7A3D8),
          Color(0xFF958DCD),
        ];
      case _DayPhase.night:
        return const [
          Color(0xFFA5A6CA),
          Color(0xFF8F8FB9),
          Color(0xFF7F7EA8),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final name = _firstName(fullName);

    final g = _greetingForNow();
    final gradient = _gradientFor(g.phase);

    final cs = Theme.of(context).colorScheme;

    final title = '${_weekdayRu(now.weekday)}, ${now.day} ${_monthRu(now.month)}';
    final subtitle = 'чётная неделя'; // у тебя это уже считается где-то; если хочешь — подключу сервис

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -28,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: DefaultTextStyle(
              style: TextStyle(color: cs.onPrimaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${g.greeting}, $name',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withValues(alpha: 0.72),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withValues(alpha: 0.80),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.60),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          color: Colors.black.withValues(alpha: 0.70)),
                      const SizedBox(width: 10),
                      Text(
                        'Сегодня $lessonsToday пары',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black.withValues(alpha: 0.74),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DayPhase { morning, day, evening, night }

class _WeekProgressStrip extends StatelessWidget {
  final int completed;
  final int total;

  const _WeekProgressStrip({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final safeTotal = total <= 0 ? 1 : total;
    final value = (completed / safeTotal).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Прогресс недели',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  '$completed / $total',
                  style: t.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: value,
                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekMoodMapCard extends StatelessWidget {
  final List<DateTime> days;
  final Map<int, int> lessonsByDay;

  const _WeekMoodMapCard({
    required this.days,
    required this.lessonsByDay,
  });

  String _dayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Пн';
      case DateTime.tuesday:
        return 'Вт';
      case DateTime.wednesday:
        return 'Ср';
      case DateTime.thursday:
        return 'Чт';
      case DateTime.friday:
        return 'Пт';
      case DateTime.saturday:
        return 'Сб';
      case DateTime.sunday:
      default:
        return 'Вс';
    }
  }

  ({Color bg, Color border, Color fg}) _toneFor(
    int count,
    int weekMax,
    int peakDaysCount,
    ColorScheme cs,
  ) {
    if (count <= 0) {
      return (
        bg: const Color(0xFF262938),
        border: cs.outlineVariant.withValues(alpha: 0.30),
        fg: cs.onSurface.withValues(alpha: 0.70),
      );
    }

    if (weekMax <= 0) {
      return (
        bg: const Color(0xFF302D46),
        border: const Color(0xFF595685),
        fg: const Color(0xFFC2BDEA),
      );
    }

    final ratio = count / weekMax;
    final peakIsRare = peakDaysCount <= 2;

    if (ratio >= 0.85 && peakIsRare) {
      return (
        bg: const Color(0xFF5F4DFF),
        border: const Color(0xFFD1CAFF),
        fg: const Color(0xFFFFFFFF),
      );
    }
    if (ratio >= 0.70) {
      final isPeak = count == weekMax;
      return (
        bg: isPeak ? const Color(0xFF4E40D6) : const Color(0xFF4438BE),
        border: isPeak ? const Color(0xFFB0A6FF) : const Color(0xFF978EED),
        fg: const Color(0xFFF1EEFF),
      );
    }
    if (ratio >= 0.45) {
      return (
        bg: const Color(0xFF393162),
        border: const Color(0xFF7067B8),
        fg: const Color(0xFFD8D2FF),
      );
    }
    return (
      bg: const Color(0xFF2F2C46),
      border: const Color(0xFF5B5688),
      fg: const Color(0xFFC1BBEE),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final today = DateTime.now();

    final heaviest = days
        .map((d) => (day: d, count: lessonsByDay[d.weekday] ?? 0))
        .reduce((a, b) => b.count > a.count ? b : a);
    final weekMax = heaviest.count;
    final peakDaysCount = days
        .where((d) => (lessonsByDay[d.weekday] ?? 0) == weekMax && weekMax > 0)
        .length;

    final summary = heaviest.count == 0
        ? 'Неделя выглядит спокойно'
        : 'Пик нагрузки: ${_dayLabel(heaviest.day.weekday)} (${heaviest.count} пар)';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface.withValues(alpha: 0.94),
              cs.surface.withValues(alpha: 0.86),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Карта настроения недели',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                summary,
                style: t.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.64),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (int i = 0; i < days.length; i++) ...[
                    Expanded(
                      child: _MoodDayCell(
                        dayLabel: _dayLabel(days[i].weekday),
                        dayNumber: days[i].day,
                        lessonsCount: lessonsByDay[days[i].weekday] ?? 0,
                        isToday: days[i].year == today.year &&
                            days[i].month == today.month &&
                            days[i].day == today.day,
                        tone: _toneFor(
                          lessonsByDay[days[i].weekday] ?? 0,
                          weekMax,
                          peakDaysCount,
                          cs,
                        ),
                      ),
                    ),
                    if (i != days.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: const [
                    _MoodLegend(text: 'Нет пар', color: Color(0xFF747787)),
                    SizedBox(width: 8),
                    _MoodLegend(text: 'Легкая', color: Color(0xFF7067B8)),
                    SizedBox(width: 8),
                    _MoodLegend(text: 'Средняя', color: Color(0xFF978EED)),
                    SizedBox(width: 8),
                    _MoodLegend(text: 'Высокая', color: Color(0xFFB0A6FF)),
                    SizedBox(width: 8),
                    _MoodLegend(text: 'Пик недели', color: Color(0xFFD1CAFF)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodDayCell extends StatelessWidget {
  final String dayLabel;
  final int dayNumber;
  final int lessonsCount;
  final bool isToday;
  final ({Color bg, Color border, Color fg}) tone;

  const _MoodDayCell({
    required this.dayLabel,
    required this.dayNumber,
    required this.lessonsCount,
    required this.isToday,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday ? tone.fg : tone.border,
          width: isToday ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Text(
            dayLabel,
            style: t.labelMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: tone.fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$dayNumber',
            style: t.labelSmall?.copyWith(
              color: tone.fg.withValues(alpha: 0.88),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$lessonsCount',
            style: t.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: tone.fg,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            lessonsCount == 1 ? 'пара' : 'пар',
            style: t.labelSmall?.copyWith(
              color: tone.fg.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodLegend extends StatelessWidget {
  final String text;
  final Color color;

  const _MoodLegend({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        text,
        style: t.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NextLessonCard extends StatelessWidget {
  final Lesson? lesson;
  final String? subtitle;
  final VoidCallback onOpenSchedule;

  const _NextLessonCard({
    required this.lesson,
    required this.subtitle,
    required this.onOpenSchedule,
  });

  @override
  Widget build(BuildContext context) {
    if (lesson == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.coffee_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ближайших пар нет',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Можно немного выдохнуть или проверить расписание на другие дни.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onOpenSchedule,
                  icon: const Icon(Icons.view_agenda_outlined),
                  label: const Text('Открыть расписание'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface.withValues(alpha: 0.98),
              cs.surface.withValues(alpha: 0.90),
            ],
          ),
          border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ближайшая пара',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: cs.primary.withValues(alpha: 0.14),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lesson!.subject,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900, height: 1.08),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pill(
                    icon: Icons.schedule,
                    text: lesson!.time,
                  ),
                  _Pill(
                    icon: Icons.place_outlined,
                    text: lesson!.place,
                  ),
                  if (lesson!.teacher.trim().isNotEmpty)
                    _Pill(
                      icon: Icons.person_outline,
                      text: lesson!.teacher,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenSchedule,
                  icon: const Icon(Icons.view_agenda_outlined),
                  label: const Text('Открыть расписание'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
