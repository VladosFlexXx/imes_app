import 'package:flutter/material.dart';

import '../../../ui/app_haptics.dart';
import '../../campus/floor_plan_screen.dart';
import '../../grades/course_report_screen.dart';
import '../../grades/repository.dart';
import '../../homework/homework_screen.dart';
import '../../profile/repository.dart';
import '../../schedule/models.dart';
import '../../schedule/schedule_repository.dart';

class DesktopDashboard extends StatelessWidget {
  final void Function(int index) onNavigate;

  const DesktopDashboard({
    super.key,
    required this.onNavigate,
  });

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

  String _greetingForNow() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Доброе утро';
    if (h >= 12 && h < 18) return 'Добрый день';
    if (h >= 18 && h < 23) return 'Добрый вечер';
    return 'Доброй ночи';
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

  int _daysUntilWeekend(DateTime date) {
    final wd = date.weekday;
    if (wd == DateTime.saturday || wd == DateTime.sunday) return 0;
    return 6 - wd;
  }

  int _isoWeek(DateTime d) {
    final thursday = d.add(
      Duration(days: 4 - (d.weekday == 7 ? 0 : d.weekday)),
    );
    final firstJan = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(firstJan).inDays) / 7).floor() + 1;
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

  Lesson? _findUpcomingLesson(List<Lesson> lessons, DateTime now) {
    for (final l in lessons) {
      final end = _parseEndForDate(l.time, now);
      if (end != null && end.isAfter(now)) {
        return l;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheduleRepo = ScheduleRepository.instance;
    final gradesRepo = GradesRepository.instance;
    final profileRepo = ProfileRepository.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([scheduleRepo, gradesRepo, profileRepo]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final t = theme.textTheme;
        final isDark = theme.brightness == Brightness.dark;
        final accent = cs.primary;

        final cardBg = isDark ? const Color(0xFF141722) : Colors.white;
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08);

        final now = DateTime.now();
        final profile = profileRepo.profile;
        final fullName = profile?.fullName;
        final name = _firstName(fullName);
        final greeting = _greetingForNow();
        final group = profile?.group ?? 'Студент';
        final level = profile?.level ?? 'Бакалавриат';

        final todayLessons = scheduleRepo.lessonsForDate(now);
        final upcomingLesson = _findUpcomingLesson(todayLessons, now);

        final tomorrowDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        final tomorrowLessons = scheduleRepo.lessonsForDate(tomorrowDate);

        final daysUntilWeekend = _daysUntilWeekend(now);
        final isEven = _isoWeek(now).isEven;

        // Расчёт прогресса недели (пн-пт)
        final dayOfWeek = now.weekday.clamp(1, 5);
        final progressPercent = (dayOfWeek / 5 * 100).round();

        // Оценки
        final coursesWithGrades = gradesRepo.courses.where((c) => c.grade != null && c.grade!.isNotEmpty).toList();
        final displayGrades = coursesWithGrades.isNotEmpty
            ? coursesWithGrades.take(3).toList()
            : gradesRepo.courses.take(3).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =========================
              // ЛЕВАЯ КОЛОНКА (62%)
              // =========================
              Expanded(
                flex: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. ПРИВЕТСТВЕННЫЙ HERO-БАННЕР
                    Container(
                      height: 180,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.38),
                            accent.withValues(alpha: 0.08),
                            cardBg,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.15),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$greeting,',
                                  style: t.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  '$name 👋',
                                  style: t.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.black,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.25),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.person_outline_rounded,
                                        size: 14,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$group · $level',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Правая часть баннера с неоновым кампусом ИМЭС
                          _DesktopCampusBanner(accent: accent),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. КАРТОЧКА БЛИЖАЙШЕЙ ПАРЫ
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: upcomingLesson != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.school_rounded, size: 18, color: accent),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ближайшая пара',
                                      style: t.labelLarge?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  upcomingLesson.displaySubject,
                                  style: t.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    // Время
                                    _DesktopTag(
                                      icon: Icons.access_time_rounded,
                                      label: upcomingLesson.time,
                                      color: isDark ? Colors.white12 : Colors.black12,
                                    ),
                                    const SizedBox(width: 8),
                                    // Тип
                                    _DesktopTag(
                                      label: upcomingLesson.type.isNotEmpty
                                          ? upcomingLesson.type
                                          : 'Занятие',
                                      color: accent.withValues(alpha: 0.2),
                                      textColor: accent,
                                    ),
                                    const SizedBox(width: 8),
                                    // Аудитория / Платформа
                                    _DesktopTag(
                                      icon: upcomingLesson.place.toLowerCase().contains('live')
                                          ? Icons.computer_rounded
                                          : Icons.location_on_rounded,
                                      label: upcomingLesson.place,
                                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                      textColor: const Color(0xFF10B981),
                                    ),
                                    const Spacer(),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            accent,
                                            accent.withValues(alpha: 0.82),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(alpha: 0.35),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                        onPressed: () {
                                          AppHaptics.selectionClick();
                                          onNavigate(1);
                                        },
                                        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                                        label: const Text(
                                          'Открыть расписание →',
                                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (upcomingLesson.teacher.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.person_rounded, size: 16, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 6),
                                      Text(
                                        upcomingLesson.teacher,
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.done_all_rounded,
                                    color: Color(0xFF10B981),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        todayLessons.isEmpty
                                            ? 'Сегодня занятий нет 🎉'
                                            : 'На сегодня все пары закончились 🎉',
                                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      Text(
                                        'Отличная работа! Можно отдохнуть или заглянуть в расписание на завтра.',
                                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () {
                                    AppHaptics.selectionClick();
                                    onNavigate(1);
                                  },
                                  child: const Text('В расписание'),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),

                    // 3. РАСПИСАНИЕ НА СЕГОДНЯ (ТАЙМЛАЙН)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 20, color: accent),
                              const SizedBox(width: 10),
                              Text(
                                'Расписание на сегодня',
                                style: t.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_weekdayRu(now.weekday)}, ${now.day} ${_monthRu(now.month)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (todayLessons.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.beach_access_rounded,
                                      size: 44,
                                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'В этот день пар нет — свободный день!',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: todayLessons.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final l = todayLessons[i];
                                final end = _parseEndForDate(l.time, now);
                                final isDone = end != null && end.isBefore(now);
                                final isLast = i == todayLessons.length - 1;

                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Время слева
                                      SizedBox(
                                        width: 95,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 14),
                                          child: Text(
                                            l.time,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: isDone
                                                  ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                                                  : cs.onSurface,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Вертикальный маркер / линия
                                      SizedBox(
                                        width: 24,
                                        child: Column(
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(top: 18),
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: isDone
                                                    ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                                                    : accent,
                                                shape: BoxShape.circle,
                                                boxShadow: isDone
                                                    ? null
                                                    : [
                                                        BoxShadow(
                                                          color: accent.withValues(alpha: 0.4),
                                                          blurRadius: 8,
                                                        ),
                                                      ],
                                              ),
                                            ),
                                            if (!isLast)
                                              Expanded(
                                                child: Container(
                                                  width: 2,
                                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                                  color: accent.withValues(alpha: 0.25),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Карточка пары
                                      Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.04)
                                              : Colors.black.withValues(alpha: 0.03),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isDone
                                                ? Colors.transparent
                                                : borderColor,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l.displaySubject,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                                color: isDone
                                                    ? cs.onSurfaceVariant
                                                    : cs.onSurface,
                                                decoration: isDone ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (l.type.isNotEmpty) ...[
                                                  _DesktopTag(
                                                    label: l.type,
                                                    color: accent.withValues(alpha: 0.14),
                                                    textColor: accent,
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (l.place.isNotEmpty) ...[
                                                  _DesktopTag(
                                                    icon: l.place.toLowerCase().contains('live')
                                                        ? Icons.computer_rounded
                                                        : Icons.location_on_rounded,
                                                    label: l.place,
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                                    textColor: const Color(0xFF10B981),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (l.teacher.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.person_rounded,
                                                    size: 14,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      l.teacher,
                                                      style: TextStyle(
                                                        color: cs.onSurfaceVariant,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 22),

              // =========================
              // ПРАВАЯ КОЛОНКА (38%)
              // =========================
              Expanded(
                flex: 38,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. ИНДИКАТОР НЕДЕЛИ И ПРОГРЕСС
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_month_rounded, size: 20, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                '${_weekdayRu(now.weekday)}, ${now.day} ${_monthRu(now.month)}',
                                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.layers_rounded, size: 14, color: Color(0xFF10B981)),
                                    const SizedBox(width: 5),
                                    Text(
                                      isEven ? 'Чётная неделя' : 'Нечётная неделя',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Прогресс недели',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '$dayOfWeek из 5 дней · $progressPercent%',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: (dayOfWeek / 5).clamp(0.0, 1.0),
                              backgroundColor: isDark ? Colors.white10 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. 3 KPI ПЛАШКИ (ПАPЫ СЕГОДНЯ / ПАPЫ ЗАВТРА / ДО ВЫХОДНЫХ)
                    Row(
                      children: [
                        // Пары сегодня
                        Expanded(
                          child: _DesktopKpiCard(
                            icon: Icons.calendar_today_rounded,
                            title: 'Пары сегодня',
                            value: '${todayLessons.length}',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            accent: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Пары завтра
                        Expanded(
                          child: _DesktopKpiCard(
                            icon: Icons.event_available_rounded,
                            title: 'Пары завтра',
                            value: tomorrowLessons.isEmpty ? 'Отдых' : '${tomorrowLessons.length}',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            accent: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // До выходных
                        Expanded(
                          child: _DesktopKpiCard(
                            icon: Icons.weekend_rounded,
                            title: 'До выходных',
                            value: daysUntilWeekend == 0
                                ? '🎉'
                                : '$daysUntilWeekend дн.',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            accent: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 3. БЛОК ОЦЕНОК
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.school_rounded, size: 20, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                'Оценки',
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () {
                                  AppHaptics.selectionClick();
                                  onNavigate(2);
                                },
                                child: Text(
                                  'Все оценки →',
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (displayGrades.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Оценки пока не выставлены',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: displayGrades.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final course = displayGrades[i];
                                final grade = course.grade ?? '—';

                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    AppHaptics.selectionClick();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CourseGradeReportScreen(course: course),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            Lesson.cleanSubjectName(course.courseName),
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            grade,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 4. БЫСТРЫЕ ДЕЙСТВИЯ
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 20, color: accent),
                              const SizedBox(width: 8),
                              Text(
                                'Быстрые действия',
                                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _DesktopActionTile(
                                  icon: Icons.calendar_month_rounded,
                                  label: 'Расписание',
                                  onTap: () {
                                    AppHaptics.selectionClick();
                                    onNavigate(1);
                                  },
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DesktopActionTile(
                                  icon: Icons.school_rounded,
                                  label: 'Оценки',
                                  onTap: () {
                                    AppHaptics.selectionClick();
                                    onNavigate(2);
                                  },
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DesktopActionTile(
                                  icon: Icons.assignment_outlined,
                                  label: 'Дедлайны',
                                  onTap: () {
                                    AppHaptics.selectionClick();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const HomeworkScreen()),
                                    );
                                  },
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  accent: accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DesktopActionTile(
                                  icon: Icons.map_outlined,
                                  label: 'Навигатор',
                                  onTap: () {
                                    AppHaptics.selectionClick();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const CampusFloorPlanScreen()),
                                    );
                                  },
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  accent: accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopTag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final Color? textColor;

  const _DesktopTag({
    this.icon,
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor ?? Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopKpiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color cardBg;
  final Color borderColor;
  final Color accent;

  const _DesktopKpiCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.cardBg,
    required this.borderColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: Color(0xFF34D399),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color cardBg;
  final Color borderColor;
  final Color accent;

  const _DesktopActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cardBg,
    required this.borderColor,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopCampusBanner extends StatelessWidget {
  final Color accent;

  const _DesktopCampusBanner({required this.accent});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 260,
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF161826),
              const Color(0xFF0F111C),
              accent.withValues(alpha: 0.15),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: CustomPaint(
          painter: _CampusBuildingPainter(accent: accent),
        ),
      ),
    );
  }
}

class _CampusBuildingPainter extends CustomPainter {
  final Color accent;

  _CampusBuildingPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Perspective facade polygon
    final buildingPath = Path()
      ..moveTo(w * 0.28, h * 0.18)
      ..lineTo(w * 0.98, h * 0.05)
      ..lineTo(w * 0.98, h)
      ..lineTo(w * 0.28, h)
      ..close();

    final buildingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1E2135),
          const Color(0xFF10121F),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(buildingPath, buildingPaint);

    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(buildingPath, edgePaint);

    // 2. Window grid
    final windowPaint = Paint()..style = PaintingStyle.fill;
    const cols = 6;
    const rows = 4;
    final startX = w * 0.35;
    final endX = w * 0.92;
    final colWidth = (endX - startX) / cols;

    for (var r = 0; r < rows; r++) {
      final yProgress = (r + 1) / (rows + 1);
      const winH = 10.0;
      final winY = h * 0.28 + yProgress * (h * 0.62);

      for (var c = 0; c < cols; c++) {
        final winX = startX + c * colWidth + 4;
        final winW = colWidth - 8;

        final isLit = ((r * 3 + c * 2) % 3) != 0;
        if (isLit) {
          windowPaint.color = (c % 2 == 0)
              ? const Color(0xFF60A5FA).withValues(alpha: 0.35)
              : const Color(0xFFFBBF24).withValues(alpha: 0.30);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(winX, winY, winW, winH),
              const Radius.circular(2.5),
            ),
            windowPaint,
          );
        }
      }
    }

    // 3. Neon sign on rooftop: "И М Э С"
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'И М Э С',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.2,
          shadows: [
            Shadow(
              color: accent,
              blurRadius: 16,
            ),
            Shadow(
              color: accent.withValues(alpha: 0.8),
              blurRadius: 6,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.44, h * 0.08));

    // 4. Subtle left fade gradient so text doesn't clash
    final fadePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF141722).withValues(alpha: 0.9),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), fadePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
