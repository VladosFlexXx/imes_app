import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ui/app_haptics.dart';
import '../../../ui/app_theme.dart';
import '../../profile/repository.dart';
import '../../schedule/models.dart';
import '../../schedule/schedule_repository.dart';
import '../../schedule/ui_parts/lesson_details_sheet.dart';
import '../../schedule/ui_parts/schedule_share_sheet.dart';
import '../../schedule/week_calendar_sheet.dart';
import '../../schedule/week_parity.dart';
import '../../schedule/week_parity_service.dart';
import '../../schedule/week_utils.dart';

class DesktopScheduleView extends StatefulWidget {
  final void Function(int index) onNavigate;

  const DesktopScheduleView({
    super.key,
    required this.onNavigate,
  });

  @override
  State<DesktopScheduleView> createState() => _DesktopScheduleViewState();
}

class _DesktopScheduleViewState extends State<DesktopScheduleView> {
  final repo = ScheduleRepository.instance;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = WeekUtils.weekStart(DateTime.now());
    repo.addListener(_onRepoChanged);
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _goToToday() {
    AppHaptics.mediumImpact();
    setState(() {
      _weekStart = WeekUtils.weekStart(DateTime.now());
    });
  }

  void _prevWeek() {
    AppHaptics.lightImpact();
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
  }

  void _nextWeek() {
    AppHaptics.lightImpact();
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
  }

  void _openCalendar() {
    AppHaptics.lightImpact();
    WeekCalendarSheet.show(
      context,
      selectedDate: _weekStart,
      onSelected: (date) {
        setState(() {
          _weekStart = WeekUtils.weekStart(date);
        });
      },
    );
  }

  void _openShare(Map<int, List<Lesson>> weekLessons, WeekParity parity) {
    AppHaptics.lightImpact();
    final today = DateTime.now();
    final todayLessons = weekLessons[today.weekday] ?? const <Lesson>[];
    showScheduleShareSheet(
      context,
      selectedDate: today,
      selectedDayLessons: todayLessons,
      weekStart: _weekStart,
      weekLessons: weekLessons,
      parity: parity,
    );
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';

  static final List<String> _monthRuGenitive = [
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

  String _formatRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month) {
      return '${start.day} – ${end.day} ${_monthRuGenitive[start.month - 1]}';
    }
    return '${start.day} ${_monthRuGenitive[start.month - 1]} – ${end.day} ${_monthRuGenitive[end.month - 1]}';
  }

  DateTime? _parseStart(String time, DateTime day) {
    final parts = time.split(RegExp(r'[-–—]'));
    if (parts.isEmpty) return null;
    final start = parts[0].trim().replaceAll(':', '.');
    final p = start.split('.');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  DateTime? _parseEnd(String time, DateTime day) {
    final parts = time.split(RegExp(r'[-–—]'));
    if (parts.length < 2) return null;
    final end = parts[1].trim().replaceAll(':', '.');
    final p = end.split('.');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  List<_FreeWindow> _findWindows(List<Lesson> lessons, DateTime day) {
    final valid = <({Lesson lesson, DateTime start, DateTime end})>[];
    for (final l in lessons) {
      final s = _parseStart(l.time, day);
      final e = _parseEnd(l.time, day);
      if (s != null && e != null) {
        valid.add((lesson: l, start: s, end: e));
      }
    }
    valid.sort((a, b) => a.start.compareTo(b.start));

    final windows = <_FreeWindow>[];
    for (var i = 0; i < valid.length - 1; i++) {
      final curEnd = valid[i].end;
      final nextStart = valid[i + 1].start;
      final diff = nextStart.difference(curEnd).inMinutes;
      if (diff >= 20) {
        windows.add(_FreeWindow(start: curEnd, end: nextStart, durationMinutes: diff));
      }
    }
    return windows;
  }

  String _weekdayName(int wd) {
    const names = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];
    return names[(wd - 1).clamp(0, 6)];
  }

  String _pluralLessons(int count) {
    if (count % 10 == 1 && count % 100 != 11) return '$count пара';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return '$count пары';
    }
    return '$count пар';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = appAccentOf(context);

    final cardBg = isDark ? const Color(0xFF141722) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    final now = DateTime.now();
    final isCurrentWeek = WeekUtils.sameWeek(_weekStart, now);
    final parity = WeekParityService.parityFor(_weekStart);
    final parityText = parity == WeekParity.even ? 'чётная неделя' : 'нечётная неделя';

    // Сборка пар по дням недели (1..7)
    final weekLessons = <int, List<Lesson>>{};
    for (var i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      weekLessons[day.weekday] = repo.lessonsForDate(day);
    }

    // Данные для KPI плашек (на сегодня)
    final todayLessons = repo.lessonsForDate(now);
    final todayWindows = _findWindows(todayLessons, now);

    // Расчёт следующей/текущей пары
    Lesson? ongoingLesson;
    Lesson? upcomingLesson;
    int minutesToNext = 0;

    for (final l in todayLessons) {
      final s = _parseStart(l.time, now);
      final e = _parseEnd(l.time, now);
      if (s == null || e == null) continue;

      if (s.isBefore(now) && e.isAfter(now)) {
        ongoingLesson = l;
        break;
      } else if (s.isAfter(now)) {
        if (upcomingLesson == null) {
          upcomingLesson = l;
          minutesToNext = s.difference(now).inMinutes;
        }
      }
    }

    final profile = ProfileRepository.instance.profile;
    final groupName = profile?.group ?? 'ИС-21';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // 1. ВЕРХНИЙ ТУЛБАР (Сегодня, навигация, диапазон, группа)
          // ==========================================
          Row(
            children: [
              // Кнопка "Сегодня"
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _goToToday,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isCurrentWeek
                        ? accent.withValues(alpha: 0.16)
                        : (isDark ? const Color(0xFF1B202B) : const Color(0xFFEAEFF8)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentWeek
                          ? accent.withValues(alpha: 0.5)
                          : borderColor,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Сегодня',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isCurrentWeek ? accent : cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Стрелка влево <
              _NavSquareButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Предыдущая неделя',
                onTap: _prevWeek,
                borderColor: borderColor,
                isDark: isDark,
              ),
              const SizedBox(width: 6),

              // Диапазон дат (клик открывает календарь)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openCalendar,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181C26) : const Color(0xFFF1F4FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        _formatRange(_weekStart),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Стрелка вправо >
              _NavSquareButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Следующая неделя',
                onTap: _nextWeek,
                borderColor: borderColor,
                isDark: isDark,
              ),
              const SizedBox(width: 14),

              // Бейдж группы
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181C26) : const Color(0xFFF1F4FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      groupName,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Чётность недели
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181C26) : const Color(0xFFF1F4FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: parity == WeekParity.even ? const Color(0xFF38BDF8) : const Color(0xFFA78BFA),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      parityText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Кнопка "Поделиться"
              OutlinedButton.icon(
                onPressed: () => _openShare(weekLessons, parity),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_outlined, size: 15),
                label: const Text('Поделиться', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ==========================================
          // 2. РЯД 3-Х KPI КАРТОЧЕК
          // ==========================================
          Row(
            children: [
              // Карточка 1: Сегодня
              Expanded(
                child: _KpiCard(
                  icon: Icons.calendar_today_rounded,
                  iconColor: accent,
                  title: 'Сегодня',
                  subtitle: '${_weekdayName(now.weekday)}, ${now.day} ${_monthRuGenitive[now.month - 1]}',
                  badge: todayLessons.isNotEmpty ? _pluralLessons(todayLessons.length) : 'Выходной',
                  badgeColor: accent,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),

              // Карточка 2: Следующая пара
              Expanded(
                child: _KpiCard(
                  icon: Icons.play_arrow_rounded,
                  iconColor: const Color(0xFFA855F7),
                  title: ongoingLesson != null ? 'Идёт пара' : 'Следующая пара',
                  subtitle: ongoingLesson != null
                      ? '${ongoingLesson.displaySubject} • до ${_parseEnd(ongoingLesson.time, now)?.minute != null ? '${_parseEnd(ongoingLesson.time, now)!.hour}:${_two(_parseEnd(ongoingLesson.time, now)!.minute)}' : ongoingLesson.time}'
                      : (upcomingLesson != null
                          ? '${upcomingLesson.displaySubject} • ${upcomingLesson.time.replaceAll(' ', '')}'
                          : (todayLessons.isEmpty ? 'Сегодня пар нет' : 'Все пары завершены 🎉')),
                  badge: ongoingLesson != null
                      ? 'В процессе'
                      : (upcomingLesson != null ? 'через $minutesToNext мин' : 'Завершено'),
                  badgeColor: const Color(0xFFA855F7),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 14),

              // Карточка 3: Свободные окна
              Expanded(
                child: _KpiCard(
                  icon: Icons.free_breakfast_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Свободные окна',
                  subtitle: todayWindows.isNotEmpty
                      ? 'Сегодня: ${todayWindows.first.label}'
                      : (todayLessons.length <= 1 ? 'Окон нет (мало пар)' : 'Пары идут подряд'),
                  badge: todayWindows.isNotEmpty ? '${todayWindows.length} ${todayWindows.length == 1 ? 'окно' : 'окна'}' : 'Без окон',
                  badgeColor: const Color(0xFF10B981),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ==========================================
          // 3. СЕТКА НЕДЕЛИ: 7 КОЛОНОК (Пн, Вт, Ср, Чт, Пт, Сб, Вс)
          // ==========================================
          LayoutBuilder(
            builder: (context, constraints) {
              const columnCount = 7;
              const spacing = 10.0;
              final totalSpacing = spacing * (columnCount - 1);
              final itemWidth = (constraints.maxWidth - totalSpacing) / columnCount;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(columnCount, (index) {
                  final dayDate = _weekStart.add(Duration(days: index));
                  final weekday = dayDate.weekday;
                  final lessons = weekLessons[weekday] ?? const <Lesson>[];
                  final isToday = WeekUtils.isSameDay(dayDate, now);
                  final windows = _findWindows(lessons, dayDate);

                  return Container(
                    width: itemWidth,
                    margin: EdgeInsets.only(right: index == columnCount - 1 ? 0 : spacing),
                    child: _DesktopDayColumn(
                      dayDate: dayDate,
                      weekdayName: _weekdayName(weekday),
                      lessons: lessons,
                      windows: windows,
                      isToday: isToday,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      accent: accent,
                      isDark: isDark,
                      onLessonTap: (lesson) {
                        showLessonDetailsSheet(
                          context,
                          lesson: lesson,
                          lessonDate: dayDate,
                        );
                      },
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==========================================
// ВСПОМОГАТЕЛЬНЫЙ КЛАСС: СВОБОДНОЕ ОКНО
// ==========================================
class _FreeWindow {
  final DateTime start;
  final DateTime end;
  final int durationMinutes;

  const _FreeWindow({
    required this.start,
    required this.end,
    required this.durationMinutes,
  });

  String get label => '${_fmt(start)} – ${_fmt(end)}';
  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0 && m > 0) return '$h ч $m мин';
    if (h > 0) return '$h ч';
    return '$m мин';
  }

  static String _fmt(DateTime dt) {
    final m = dt.minute < 10 ? '0${dt.minute}' : '${dt.minute}';
    return '${dt.hour}:$m';
  }
}

// ==========================================
// КОМПОНЕНТ: КНОПКА СО СТРЕЛКОЙ < / >
// ==========================================
class _NavSquareButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color borderColor;
  final bool isDark;

  const _NavSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181C26) : const Color(0xFFF1F4FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ==========================================
// КОМПОНЕНТ: KPI-ПЛАШКА
// ==========================================
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color cardBg;
  final Color borderColor;
  final bool isDark;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.cardBg,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.16 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: -0.1),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// КОМПОНЕНТ: КОЛОНКА ОДНОГО ДНЯ НЕДЕЛИ
// ==========================================
class _DesktopDayColumn extends StatelessWidget {
  final DateTime dayDate;
  final String weekdayName;
  final List<Lesson> lessons;
  final List<_FreeWindow> windows;
  final bool isToday;
  final Color cardBg;
  final Color borderColor;
  final Color accent;
  final bool isDark;
  final void Function(Lesson lesson) onLessonTap;

  const _DesktopDayColumn({
    required this.dayDate,
    required this.weekdayName,
    required this.lessons,
    required this.windows,
    required this.isToday,
    required this.cardBg,
    required this.borderColor,
    required this.accent,
    required this.isDark,
    required this.onLessonTap,
  });

  static final List<String> _monthRu = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];

  DateTime? _parseStart(String time) {
    final parts = time.split(RegExp(r'[-–—]'));
    if (parts.isEmpty) return null;
    final start = parts[0].trim().replaceAll(':', '.');
    final p = start.split('.');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return DateTime(dayDate.year, dayDate.month, dayDate.day, h, m);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Собираем упорядоченный список элементов: пары + свободные окна
    final items = <_TimelineItem>[];
    for (final l in lessons) {
      final s = _parseStart(l.time) ?? DateTime(dayDate.year, dayDate.month, dayDate.day, 8, 30);
      items.add(_TimelineItem.lesson(l, s));
    }
    for (final w in windows) {
      items.add(_TimelineItem.window(w, w.start));
    }
    items.sort((a, b) => a.start.compareTo(b.start));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Шапка дня
        Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isToday
                ? accent
                : (isDark ? const Color(0xFF141722) : const Color(0xFFEDF1F8)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isToday ? accent : borderColor,
              width: isToday ? 1.4 : 1.0,
            ),
            boxShadow: [
              if (isToday)
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekdayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: isToday ? Colors.white : cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${dayDate.day} ${_monthRu[dayDate.month - 1]}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isToday
                      ? Colors.white.withValues(alpha: 0.85)
                      : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Список пар и окон
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141722).withValues(alpha: 0.4) : const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.weekend_outlined,
                  size: 24,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 6),
                Text(
                  'Выходной',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Занятий нет',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (final item in items)
                if (item.isLesson)
                  _DesktopLessonCard(
                    lesson: item.lesson!,
                    dayDate: dayDate,
                    isDark: isDark,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    accent: accent,
                    onTap: () => onLessonTap(item.lesson!),
                  )
                else
                  _DesktopWindowCard(
                    window: item.window!,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
            ],
          ),
      ],
    );
  }
}

// ==========================================
// МОДЕЛЬ ТАЙМЛАЙНА (ПАРА ИЛИ ОКНО)
// ==========================================
class _TimelineItem {
  final Lesson? lesson;
  final _FreeWindow? window;
  final DateTime start;

  _TimelineItem.lesson(this.lesson, this.start) : window = null;
  _TimelineItem.window(this.window, this.start) : lesson = null;

  bool get isLesson => lesson != null;
}

// ==========================================
// КАРТОЧКА ПАРЫ ВНУТРИ КОЛОНКИ ДНЯ
// ==========================================
class _DesktopLessonCard extends StatefulWidget {
  final Lesson lesson;
  final DateTime dayDate;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color accent;
  final VoidCallback onTap;

  const _DesktopLessonCard({
    required this.lesson,
    required this.dayDate,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_DesktopLessonCard> createState() => _DesktopLessonCardState();
}

class _DesktopLessonCardState extends State<_DesktopLessonCard> {
  bool _hovered = false;

  ({String label, Color color, Color bg, IconData? icon}) _badgeInfo(String rawType, String place) {
    final t = rawType.toLowerCase();
    final p = place.toLowerCase();
    final isOnline = t.contains('онлайн') ||
        t.contains('дистанц') ||
        p.contains('digital') ||
        p.contains('online') ||
        p.contains('zoom') ||
        p.contains('вебинар');

    if (isOnline) {
      return (
        label: 'Онлайн',
        color: const Color(0xFFA78BFA),
        bg: const Color(0xFFA78BFA).withValues(alpha: widget.isDark ? 0.18 : 0.12),
        icon: Icons.sensors_rounded,
      );
    }

    if (t.contains('практ') || t.contains('семин')) {
      return (
        label: 'Практика',
        color: const Color(0xFF34D399),
        bg: const Color(0xFF34D399).withValues(alpha: widget.isDark ? 0.18 : 0.12),
        icon: null,
      );
    }

    return (
      label: 'Лекция',
      color: const Color(0xFF38BDF8),
      bg: const Color(0xFF38BDF8).withValues(alpha: widget.isDark ? 0.18 : 0.12),
      icon: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = widget.lesson;
    final b = _badgeInfo(l.type, l.place);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: widget.isDark
              ? (_hovered ? const Color(0xFF1E2330) : const Color(0xFF141722))
              : (_hovered ? const Color(0xFFF7F9FD) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? widget.accent.withValues(alpha: 0.45)
                : widget.borderColor,
            width: _hovered ? 1.2 : 1.0,
          ),
          boxShadow: [
            if (!widget.isDark || _hovered)
              BoxShadow(
                color: _hovered
                    ? widget.accent.withValues(alpha: widget.isDark ? 0.16 : 0.10)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _hovered ? 12 : 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              AppHaptics.selectionClick();
              widget.onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Время + Тип
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.time.replaceAll(' ', ''),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: b.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (b.icon != null) ...[
                              Icon(b.icon, size: 10, color: b.color),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              b.label,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: b.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Название предмета
                  Text(
                    l.displaySubject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: widget.isDark ? Colors.white : const Color(0xFF1A1F2C),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Преподаватель
                  if (l.teacher.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l.teacher,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Аудитория / место
                  if (l.place.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l.place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Кнопка ссылки (если есть)
                  if (l.url != null && l.url!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        AppHaptics.selectionClick();
                        final uri = Uri.tryParse(l.url!);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: b.color.withValues(alpha: widget.isDark ? 0.16 : 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: b.color.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 11, color: b.color),
                            const SizedBox(width: 4),
                            Text(
                              'Открыть ссылку',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: b.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// КАРТОЧКА СВОБОДНОГО ОКНА МЕЖДУ ПАРАМИ
// ==========================================
class _DesktopWindowCard extends StatelessWidget {
  final _FreeWindow window;
  final bool isDark;
  final Color borderColor;

  const _DesktopWindowCard({
    required this.window,
    required this.isDark,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141722).withValues(alpha: 0.5) : const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.coffee_outlined, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Свободное окно (${window.durationLabel})',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              Text(
                window.label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
