import 'package:flutter/material.dart';

import '../../core/widgets/update_banner.dart';
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
                  onOpenSchedule: () => onNavigate(1),
                ),
                const SizedBox(height: 12),

                _NextLessonCard(
                  lesson: next,
                  subtitle: next == null ? null : _timeToText(next),
                  onOpenSchedule: () => onNavigate(1),
                ),

                const SizedBox(height: 18),

                Text(
                  'Быстрые действия',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),

                // 2x2, иконка сверху (чтобы не ломался текст)
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionTile(
                        icon: Icons.view_agenda_outlined,
                        title: 'Расписание',
                        subtitle: 'смотреть пары',
                        onTap: () => onNavigate(1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionTile(
                        icon: Icons.school_outlined,
                        title: 'Оценки',
                        subtitle: 'успеваемость',
                        onTap: () => onNavigate(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionTile(
                        icon: Icons.notifications_active_outlined,
                        title: 'Уведомления',
                        subtitle: 'пуши / статус',
                        onTap: () {
                          // пока просто ведём в Профиль/Настройки — как у тебя принято
                          onNavigate(3);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionTile(
                        icon: Icons.person_outline,
                        title: 'Профиль',
                        subtitle: 'настройки',
                        onTap: () => onNavigate(3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ✅ Оставляем блок синхронизации (как ты хотел),
                // а нижний баннер обновления (UpdateBanner) на Главной больше не нужен.
                // Если ты хочешь вообще убрать и это — скажи, удалю.
                UpdateBanner(
                  repo: scheduleRepo,
                  padding: EdgeInsets.zero,
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
  final VoidCallback onOpenSchedule;

  const _GreetingHero({
    required this.fullName,
    required this.lessonsToday,
    required this.onOpenSchedule,
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
          Color(0xFFB6B6FF),
          Color(0xFFB39DDB),
          Color(0xFFB06AB3),
        ];
      case _DayPhase.day:
        return const [
          Color(0xFFB7C6FF),
          Color(0xFF9FA8DA),
          Color(0xFF7986CB),
        ];
      case _DayPhase.evening:
        return const [
          Color(0xFF9FA8DA),
          Color(0xFF7E7BBE),
          Color(0xFF5B5A9A),
        ];
      case _DayPhase.night:
        return const [
          Color(0xFF8E8EAF),
          Color(0xFF6C6A86),
          Color(0xFF3A394A),
        ];
    }
  }

  bool _nightButton(_DayPhase p) => p == _DayPhase.night;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final name = _firstName(fullName);

    final g = _greetingForNow();
    final gradient = _gradientFor(g.phase);

    final cs = Theme.of(context).colorScheme;

    final title = '${_weekdayRu(now.weekday)}, ${now.day} ${_monthRu(now.month)}';
    final subtitle = 'чётная неделя'; // у тебя это уже считается где-то; если хочешь — подключу сервис

    final btnLight = _nightButton(g.phase);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(color: cs.onPrimaryContainer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${g.greeting}, $name',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.black.withOpacity(0.72),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.black.withOpacity(0.80),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black.withOpacity(0.60),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            color: Colors.black.withOpacity(0.70)),
                        const SizedBox(width: 10),
                        Text(
                          'Сегодня $lessonsToday пары',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.black.withOpacity(0.74),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onOpenSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      btnLight ? Colors.white.withOpacity(0.88) : Colors.black.withOpacity(0.25),
                  foregroundColor: btnLight ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text(
                  'Расписание',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DayPhase { morning, day, evening, night }

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(
                  color: t.bodySmall?.color?.withOpacity(0.70),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.free_breakfast_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Ближайших пар нет (или расписание ещё не загружено)'),
              ),
              TextButton(
                onPressed: onOpenSchedule,
                child: const Text('Открыть'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lesson!.subject,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
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
                if ((lesson!.teacher ?? '').trim().isNotEmpty)
                  _Pill(
                    icon: Icons.person_outline,
                    text: lesson!.teacher!,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
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
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.35),
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
