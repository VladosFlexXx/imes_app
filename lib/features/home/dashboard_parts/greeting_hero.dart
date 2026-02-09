part of '../tab_dashboard.dart';

class _GreetingHero extends StatelessWidget {
  final String? fullName;
  final int lessonsToday;

  const _GreetingHero({required this.fullName, required this.lessonsToday});

  String _firstName(String? fullName) {
    if (fullName == null) return 'друг';
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'друг';
    if (parts.length >= 2) return parts[1];
    return parts.first;
  }

  ({String greeting, _DayPhase phase}) _greetingForNow() {
    final h = DateTime.now().hour;

    if (h >= 5 && h < 12) {
      return (greeting: 'Доброе утро', phase: _DayPhase.morning);
    }
    if (h >= 12 && h < 18) {
      return (greeting: 'Добрый день', phase: _DayPhase.day);
    }
    if (h >= 18 && h < 23) {
      return (greeting: 'Добрый вечер', phase: _DayPhase.evening);
    }
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

  List<Color> _gradientFor(_DayPhase p) {
    switch (p) {
      case _DayPhase.morning:
        return const [Color(0xFFD4CCFF), Color(0xFFC5B9FF), Color(0xFFBDA8F7)];
      case _DayPhase.day:
        return const [Color(0xFFC7CFFF), Color(0xFFB9C2FF), Color(0xFFA8B0F3)];
      case _DayPhase.evening:
        return const [Color(0xFFB8B8E5), Color(0xFFA7A3D8), Color(0xFF958DCD)];
      case _DayPhase.night:
        return const [Color(0xFFA5A6CA), Color(0xFF8F8FB9), Color(0xFF7F7EA8)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final name = _firstName(fullName);

    final g = _greetingForNow();
    final gradient = _gradientFor(g.phase);

    final cs = Theme.of(context).colorScheme;

    final title =
        '${_weekdayRu(now.weekday)}, ${now.day} ${_monthRu(now.month)}';
    final subtitle = 'чётная неделя';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
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
                      Icon(
                        Icons.calendar_month_outlined,
                        color: Colors.black.withValues(alpha: 0.70),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Сегодня $lessonsToday пары',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
