import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui/app_theme.dart';
import '../../ui/shimmer_skeleton.dart';
import '../grades/course_report_screen.dart';
import '../grades/models.dart';
import '../grades/repository.dart';
import '../notifications/notifications_center_screen.dart';

import '../schedule/models.dart';
import '../schedule/schedule_repository.dart';
import '../schedule/schedule_rule.dart';
import '../schedule/week_calendar_sheet.dart';
import '../schedule/week_parity.dart';
import '../schedule/week_parity_service.dart';
import '../schedule/week_utils.dart';

part '../schedule/ui_parts/unified_header_card.dart';
part '../schedule/ui_parts/week_dots_row_animated.dart';
part '../schedule/ui_parts/week_dots_row.dart';
part '../schedule/ui_parts/day_page.dart';
part '../schedule/ui_parts/lesson_card.dart';
part '../schedule/ui_parts/info_chip.dart';
part '../schedule/ui_parts/pill.dart';
part '../schedule/ui_parts/tap_pill.dart';

enum ScheduleUiFilter { all, changes } // changes = changed + cancelled

Color _scheduleAccent(BuildContext context) => appAccentOf(context);

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab>
    with TickerProviderStateMixin {
  final repo = ScheduleRepository.instance;

  ScheduleUiFilter _filter = ScheduleUiFilter.all;

  /// Неделя ряда кружков (UI) — её можно свайпать отдельно, не меняя расписание.
  late DateTime _uiWeekStart;

  /// Неделя, из которой реально показывается расписание.
  late DateTime _contentWeekStart;

  /// 0..6 (Пн..Вс) выбранный день (и в расписании, и как "выбор").
  int _selectedIndex = DateTime.now().weekday - 1;

  /// Для анимации смены дня (один слайд).
  int _lastSelectedIndex = DateTime.now().weekday - 1;

  /// Для анимации ряда кружков при смене недели.
  int _weekSlideDir = 0; // -1 пред., +1 след.

  static const _kAnim = Duration(milliseconds: 260);
  static const _kCurveIn = Curves.easeOutCubic;
  static const _kCurveOut = Curves.easeInCubic;

  /// Плавная анимация изменения высоты контента дня.
  static const _kSizeAnim = Duration(milliseconds: 220);
  static const _kSizeCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = WeekUtils.weekStart(now);

    _uiWeekStart = start;
    _contentWeekStart = start;

    _selectedIndex = now.weekday - 1;
    _lastSelectedIndex = _selectedIndex;
  }

  Future<void> _refresh() => repo.refresh(force: true);

  // =========================
  // Helpers: даты/форматы
  // =========================

  static const List<String> _dots = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  static const List<String> _full = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  String _two(int x) => x.toString().padLeft(2, '0');

  String _weekTitle(DateTime weekStart) {
    final s = weekStart;
    final e = weekStart.add(const Duration(days: 6));
    return '${_two(s.day)}.${_two(s.month)} – ${_two(e.day)}.${_two(e.month)}';
  }

  String _updatedAtText(DateTime? dt) {
    if (dt == null) return '—';
    return '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  DateTime _dateForSelected() =>
      _contentWeekStart.add(Duration(days: _selectedIndex));

  // =========================
  // Нормализация дня недели
  // =========================

  static final Map<String, int> _ruDayToWeekday = {
    'понедельник': 1,
    'вторник': 2,
    'среда': 3,
    'четверг': 4,
    'пятница': 5,
    'суббота': 6,
    'воскресенье': 7,
    'пн': 1,
    'вт': 2,
    'ср': 3,
    'чт': 4,
    'пт': 5,
    'сб': 6,
    'вс': 7,
  };

  int? _weekdayIndexFromLessonDay(String raw) {
    final low = raw.trim().toLowerCase();
    if (low.isEmpty) return null;

    final direct = _ruDayToWeekday[low];
    if (direct != null) return direct;

    final short2 = low.length >= 2 ? low.substring(0, 2) : low;
    return _ruDayToWeekday[short2];
  }

  // =========================
  // Данные/фильтры
  // =========================

  Map<int, List<Lesson>> _groupWeekByWeekday(DateTime weekStart) {
    final map = <int, List<Lesson>>{};
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      map[day.weekday] = repo.lessonsForDate(day);
    }
    return map;
  }

  List<Lesson> _applyUiFilter(List<Lesson> lessons) {
    if (_filter == ScheduleUiFilter.changes) {
      return lessons
          .where(
            (l) =>
                l.status == LessonStatus.changed ||
                l.status == LessonStatus.cancelled,
          )
          .toList();
    }
    return lessons;
  }

  // =========================
  // Время/статусы (идёт/прошло/следующая)
  // =========================

  DateTime? _parseStartForDay(String time, DateTime day) {
    final start = time.split('-').first.trim().replaceAll(':', '.');
    final parts = start.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  DateTime? _parseEndForDay(String time, DateTime day) {
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

  bool _isSameDay(DateTime a, DateTime b) => WeekUtils.isSameDay(a, b);

  bool _isOngoing(Lesson l, DateTime day) {
    final now = DateTime.now();
    if (!_isSameDay(day, now)) return false;
    final s = _parseStartForDay(l.time, day);
    final e = _parseEndForDay(l.time, day);
    if (s == null || e == null) return false;
    return s.isBefore(now) && e.isAfter(now);
  }

  bool _isPast(Lesson l, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(day.year, day.month, day.day);

    if (targetDay.isBefore(today)) return true;
    if (targetDay.isAfter(today)) return false;

    final e = _parseEndForDay(l.time, day);
    if (e == null) return false;
    return e.isBefore(now);
  }

  Lesson? _nextLesson(List<Lesson> lessons, DateTime day) {
    final now = DateTime.now();
    if (!_isSameDay(day, now)) return null;

    Lesson? best;
    DateTime? bestStart;

    for (final l in lessons) {
      final start = _parseStartForDay(l.time, day);
      if (start == null) continue;

      final end = _parseEndForDay(l.time, day);
      final ongoing = end != null && start.isBefore(now) && end.isAfter(now);
      final future = start.isAfter(now);

      if (!ongoing && !future) continue;

      if (best == null) {
        best = l;
        bestStart = start;
        continue;
      }

      final bestEnd = _parseEndForDay(best.time, day);
      final bestOngoing =
          bestEnd != null && bestStart!.isBefore(now) && bestEnd.isAfter(now);

      if (bestOngoing) continue;
      if (ongoing) {
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

  String _normSubjectForLink(String s) {
    var x = s.toLowerCase().trim();
    x = x.replaceAll('_', ' ');
    x = x.replaceAll(
      RegExp(r'^\s*(од\.|дисциплина:|дисц\.)\s*', caseSensitive: false),
      '',
    );
    x = x.replaceAll(RegExp(r'\(.*?недел.*?\)'), '');
    x = x.replaceAll(RegExp(r'\(.*?\)'), '');
    x = x.replaceAll(RegExp(r'\b\d+\s*/\s*\d+\s*/\s*\d+\b'), '');
    x = x.replaceAll(RegExp(r'\b\d+\s*/\s*\d+\b'), '');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    return x;
  }

  double? _parseScoreText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final norm = raw.replaceAll(' ', '').replaceAll(',', '.');
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(norm);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  GradeCourse? _findCourseForLesson(Lesson lesson) {
    final courses = GradesRepository.instance.courses;
    if (courses.isEmpty) return null;

    final subj = _normSubjectForLink(lesson.subject);
    GradeCourse? best;
    var bestRank = -1;

    for (final c in courses) {
      final name = _normSubjectForLink(c.courseName);
      if (name.isEmpty) continue;

      var rank = 0;
      if (name == subj) {
        rank = 4;
      } else if (name.contains(subj) || subj.contains(name)) {
        rank = 3;
      } else {
        final a = name.split(' ').where((e) => e.isNotEmpty).toSet();
        final b = subj.split(' ').where((e) => e.isNotEmpty).toSet();
        final inter = a.intersection(b).length;
        if (inter >= 2) rank = 2;
      }

      if (rank > bestRank) {
        bestRank = rank;
        best = c;
      }
    }

    return bestRank <= 0 ? null : best;
  }

  double? _extractCourseScore(GradeCourse? c) {
    if (c == null) return null;

    final direct = _parseScoreText(c.grade) ?? _parseScoreText(c.percent);
    if (direct != null) return direct;

    double? best;
    for (final v in c.columns.values) {
      final x = _parseScoreText(v.toString());
      if (x == null) continue;
      if (best == null || x > best) best = x;
    }
    return best;
  }

  String _fmtScore(double? v) {
    if (v == null) return '—';
    if ((v - v.round()).abs() < 0.01) return v.round().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  int _countConductedLessonsBySchedule(Lesson lesson, DateTime upToDate) {
    final weekday = _weekdayIndexFromLessonDay(lesson.day);
    if (weekday == null) return 0;

    final semesterStart = DateTime(
      WeekParityService.dateStartWeek1.year,
      WeekParityService.dateStartWeek1.month,
      WeekParityService.dateStartWeek1.day,
    );
    final target = DateTime(upToDate.year, upToDate.month, upToDate.day);
    if (target.isBefore(semesterStart)) return 0;

    final rule = ScheduleRule.parseFromSubject(lesson.subject);
    var weekStart = WeekUtils.weekStart(semesterStart);
    var total = 0;

    while (!weekStart.isAfter(target)) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final parity = WeekParityService.parityFor(weekStart);
      final applies = rule.appliesForWeek(
        parity: parity,
        weekStart: weekStart,
        weekEnd: weekEnd,
      );

      if (applies) {
        final lessonDate = weekStart.add(Duration(days: weekday - 1));
        if (!lessonDate.isAfter(target) &&
            !lessonDate.isBefore(semesterStart)) {
          total++;
        }
      }

      weekStart = weekStart.add(const Duration(days: 7));
    }
    return total;
  }

  int _countMarkedAttendanceRows(CourseGradeReport report) {
    var count = 0;
    for (final r in report.rows) {
      if (r.type != GradeReportRowType.item) continue;
      final g = r.grade.trim();
      if (g.isEmpty || g == '-' || g == '—') continue;
      count++;
    }
    return count;
  }

  Future<({int attended, int total})> _buildAttendanceInfo(
    Lesson lesson,
    DateTime upToDate,
  ) async {
    final total = _countConductedLessonsBySchedule(lesson, upToDate);
    final linkedCourse = _findCourseForLesson(lesson);
    if (linkedCourse == null) {
      return (attended: 0, total: total);
    }

    try {
      final report = await GradesRepository.instance.fetchCourseReport(
        linkedCourse,
      );
      final attended = _countMarkedAttendanceRows(report);
      return (attended: attended, total: total);
    } catch (_) {
      return (attended: 0, total: total);
    }
  }

  // =========================
  // UX действия
  // =========================

  void _toggleChangesOnly() {
    setState(() {
      _filter = _filter == ScheduleUiFilter.all
          ? ScheduleUiFilter.changes
          : ScheduleUiFilter.all;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    final week = WeekUtils.weekStart(now);
    final idx = now.weekday - 1;

    setState(() {
      _weekSlideDir = week.isAfter(_uiWeekStart)
          ? 1
          : (week.isBefore(_uiWeekStart) ? -1 : 0);

      _uiWeekStart = week;
      _contentWeekStart = week;

      _lastSelectedIndex = _selectedIndex;
      _selectedIndex = idx;
    });
  }

  /// Свайп недели (только UI-неделя). НЕ трогаем выбор и НЕ трогаем расписание.
  void _uiSwipeWeek(int dir) {
    setState(() {
      _weekSlideDir = dir;
      _uiWeekStart = _uiWeekStart.add(Duration(days: dir * 7));
    });
  }

  /// Тап по дню в UI-неделе = явный выбор.
  /// Тут мы синхронизируем и расписание, и выбор.
  void _selectDayInUiWeek(int index) {
    setState(() {
      _lastSelectedIndex = _selectedIndex;
      _selectedIndex = index;
      _contentWeekStart = _uiWeekStart;
    });
  }

  /// SYNC свайп дня по расписанию: меняем день и неделю расписания.
  /// Важно: UI-неделю тоже переключаем, чтобы кружки соответствовали расписанию.
  void _swipeDay(int dir) {
    if (dir == 0) return;

    setState(() {
      _lastSelectedIndex = _selectedIndex;

      var newIndex = _selectedIndex + dir;
      var newWeek = _contentWeekStart;

      if (newIndex < 0) {
        newIndex = 6;
        newWeek = newWeek.subtract(const Duration(days: 7));
      } else if (newIndex > 6) {
        newIndex = 0;
        newWeek = newWeek.add(const Duration(days: 7));
      }

      _selectedIndex = newIndex;
      _contentWeekStart = newWeek;

      _weekSlideDir = newWeek.isAfter(_uiWeekStart)
          ? 1
          : (newWeek.isBefore(_uiWeekStart) ? -1 : 0);
      _uiWeekStart = newWeek;
    });
  }

  Future<void> _openWeekPicker() async {
    await WeekCalendarSheet.show(
      context,
      selectedDate: _uiWeekStart,
      onSelected: (d) {
        final week = WeekUtils.weekStart(d);
        final idx = d.weekday - 1;

        setState(() {
          _weekSlideDir = week.isAfter(_uiWeekStart)
              ? 1
              : (week.isBefore(_uiWeekStart) ? -1 : 0);

          _uiWeekStart = week;
          _contentWeekStart = week;

          _lastSelectedIndex = _selectedIndex;
          _selectedIndex = idx;
        });
      },
    );
  }

  // =========================
  // Детали пары
  // =========================

  void _openLessonDetails(Lesson l) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayDate = _dateForSelected();
    final grouped = _groupWeekByWeekday(_contentWeekStart);
    final dayLessonsAll = grouped[dayDate.weekday] ?? const <Lesson>[];
    final dayLessonsFiltered = _applyUiFilter(dayLessonsAll);
    final dayLessonsCount = dayLessonsFiltered.length;
    final dayChangesCount = dayLessonsAll
        .where(
          (x) =>
              x.status == LessonStatus.changed ||
              x.status == LessonStatus.cancelled,
        )
        .length;
    final maxDayLoad = grouped.values.fold<int>(
      1,
      (m, list) => list.length > m ? list.length : m,
    );

    final linkedCourse = _findCourseForLesson(l);
    final score = _extractCourseScore(linkedCourse);
    final scoreProgress = score == null
        ? 0.0
        : ((score <= 5 ? score / 5 : score / 100).clamp(0.0, 1.0));
    final attendanceFuture = _buildAttendanceInfo(l, dayDate);

    final statusText = _isOngoing(l, dayDate)
        ? 'Пара идёт сейчас'
        : (_isPast(l, dayDate) ? 'Пара завершена' : 'Пара запланирована');

    void showInfoSnack(String text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }

    Future<void> openCourseReport() async {
      if (linkedCourse == null) {
        showInfoSnack('По этой паре пока нет карточки дисциплины');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseGradeReportScreen(course: linkedCourse),
        ),
      );
    }

    Future<void> openDayLoadDetails(BuildContext sheetContext) async {
      await showModalBottomSheet(
        context: sheetContext,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Нагрузка по дню',
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_full[_selectedIndex]} · всего пар: $dayLessonsCount · изменений: $dayChangesCount',
                    style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  if (dayLessonsFiltered.isEmpty)
                    const Text('В выбранном фильтре пары не найдены')
                  else
                    ...dayLessonsFiltered.map(
                      (x) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 86,
                              child: Text(
                                x.time.replaceAll('.', ':'),
                                style: t.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                x.subject,
                                style: t.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    Future<void> copyEmailDraft() async {
      final teacher = l.teacher.trim().isEmpty
          ? 'Преподаватель'
          : l.teacher.trim();
      final draft =
          'Тема: Вопрос по дисциплине "${l.subject}"\n\n'
          'Здравствуйте, $teacher!\n'
          'Пишу по занятию ${l.day}, ${l.time.replaceAll('.', ':')}.\n\n'
          'Вопрос:\n'
          '- ...\n\n'
          'С уважением,';
      await Clipboard.setData(ClipboardData(text: draft));
      if (!mounted) return;
      showInfoSnack('Черновик письма скопирован в буфер');
    }

    Future<void> openNotificationsCenter() async {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
      );
    }

    Widget statCard({
      required IconData icon,
      required Color iconBg,
      required String value,
      required String title,
      required Color progressColor,
      required double progress,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isDark ? const Color(0xFF33445F) : const Color(0xFFE2E8F4),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: iconBg,
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: t.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.96)
                      : cs.onSurface.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: t.bodyMedium?.copyWith(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.74)
                      : cs.onSurface.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation(progressColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget infoItem({
      required IconData icon,
      required Color iconBg,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: iconBg,
                  ),
                  child: Icon(icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.94)
                              : cs.onSurface.withValues(alpha: 0.90),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: t.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.64)
                              : cs.onSurface.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.56)
                      : cs.onSurface.withValues(alpha: 0.54),
                ),
              ],
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) {
        const minSheet = 0.52;
        const maxSheet = 0.88;
        var closingSheet = false;

        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            if (closingSheet) return true;
            // Если стянули до минимума — закрываем.
            if (n.extent <= (minSheet + 0.005)) {
              closingSheet = true;
              Navigator.of(ctx).pop();
              return true;
            }
            return false;
          },
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: maxSheet,
            minChildSize: minSheet,
            maxChildSize: maxSheet,
            snap: true,
            snapSizes: const [minSheet, maxSheet],
            builder: (context, scrollController) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 6,
                  bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? const [Color(0xFF243654), Color(0xFF1A2436)]
                          : const [Color(0xFFF1F4FA), Color(0xFFE8EDF7)],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.28 : 0.10,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.subject,
                            style: t.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.97)
                                  : cs.onSurface.withValues(alpha: 0.93),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoChip(
                                icon: Icons.calendar_today_outlined,
                                text: l.day,
                              ),
                              _InfoChip(icon: Icons.schedule, text: l.time),
                              if (l.type.trim().isNotEmpty)
                                _InfoChip(
                                  icon: Icons.info_outline,
                                  text: l.type,
                                ),
                              if (l.place.trim().isNotEmpty)
                                _InfoChip(
                                  icon: Icons.place_outlined,
                                  text: l.place,
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              statCard(
                                icon: Icons.assignment_outlined,
                                iconBg: _scheduleAccent(context),
                                value: _fmtScore(score),
                                title: 'Текущий балл',
                                progressColor: _scheduleAccent(context),
                                progress: scoreProgress,
                              ),
                              const SizedBox(width: 10),
                              FutureBuilder<({int attended, int total})>(
                                future: attendanceFuture,
                                builder: (context, snap) {
                                  final isLoading =
                                      snap.connectionState ==
                                      ConnectionState.waiting;
                                  final attended = snap.data?.attended ?? 0;
                                  final total = snap.data?.total ?? 0;
                                  final progress = total == 0
                                      ? 0.0
                                      : (attended / total).clamp(0.0, 1.0);

                                  return statCard(
                                    icon: Icons.event_available_outlined,
                                    iconBg: const Color(0xFF1A8B71),
                                    value: isLoading
                                        ? '...'
                                        : '$attended/$total',
                                    title: 'Посещаемость',
                                    progressColor: const Color(0xFF36E3AE),
                                    progress: progress,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ИНФОРМАЦИЯ',
                            style: t.labelMedium?.copyWith(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.42)
                                  : cs.onSurface.withValues(alpha: 0.46),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 8),
                          infoItem(
                            icon: Icons.info_outline,
                            iconBg: _scheduleAccent(context),
                            title: 'О дисциплине',
                            subtitle:
                                linkedCourse?.courseName ??
                                'Дисциплина из расписания',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              openCourseReport();
                            },
                          ),
                          infoItem(
                            icon: Icons.event_note_outlined,
                            iconBg: const Color(0xFF1A8B71),
                            title: 'Нагрузка по дню',
                            subtitle:
                                '${_full[_selectedIndex]} · пар: $dayLessonsCount (макс $maxDayLoad), изм: $dayChangesCount',
                            onTap: () => openDayLoadDetails(ctx),
                          ),
                          infoItem(
                            icon: Icons.auto_graph_outlined,
                            iconBg: _scheduleAccent(context),
                            title: 'Оценки и рейтинг',
                            subtitle: score == null
                                ? 'Пока без данных по баллам'
                                : 'Текущий балл: ${_fmtScore(score)}',
                            onTap: () {
                              Navigator.of(ctx).pop();
                              openCourseReport();
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'ПРЕПОДАВАТЕЛЬ',
                            style: t.labelMedium?.copyWith(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.42)
                                  : cs.onSurface.withValues(alpha: 0.46),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: isDark
                                  ? const Color(0xFF2B4268)
                                  : const Color(0xFFD8E4FA),
                              border: Border.all(
                                color: _scheduleAccent(
                                  context,
                                ).withValues(alpha: 0.55),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: _scheduleAccent(context),
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l.teacher.trim().isEmpty
                                            ? 'Преподаватель не указан'
                                            : l.teacher.trim(),
                                        style: t.titleSmall?.copyWith(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.95,
                                                )
                                              : cs.onSurface.withValues(
                                                  alpha: 0.92,
                                                ),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        statusText,
                                        style: t.bodySmall?.copyWith(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.66,
                                                )
                                              : cs.onSurface.withValues(
                                                  alpha: 0.62,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: copyEmailDraft,
                                  icon: const Icon(Icons.email_outlined),
                                  label: const Text('Email'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.82)
                                        : const Color(0xFF3D4654),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF2C374A)
                                        : const Color(0xFFE6E8ED),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    openNotificationsCenter();
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('Чат'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.82)
                                        : const Color(0xFF3D4654),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                    ),
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF2C374A)
                                        : const Color(0xFFE6E8ED),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final uiParity = WeekParityService.parityFor(_uiWeekStart);
        final uiParityText = uiParity == WeekParity.even
            ? 'чётная неделя'
            : 'нечётная неделя';

        final updatedAt = repo.updatedAt;

        final contentGrouped = _groupWeekByWeekday(_contentWeekStart);

        final contentDate = _dateForSelected();
        final isToday = WeekUtils.isSameDay(contentDate, DateTime.now());

        final weekday = _selectedIndex + 1;
        final dayLessonsAll = contentGrouped[weekday] ?? const <Lesson>[];
        final dayLessons = _applyUiFilter(dayLessonsAll);

        final next = _nextLesson(dayLessons, contentDate);

        final dayChanges = dayLessonsAll
            .where(
              (l) =>
                  l.status == LessonStatus.changed ||
                  l.status == LessonStatus.cancelled,
            )
            .length;

        final dayTitle =
            '${_full[_selectedIndex]} • ${_two(contentDate.day)}.${_two(contentDate.month)}';

        final daySlideDir = (_selectedIndex == _lastSelectedIndex)
            ? 0
            : (_selectedIndex > _lastSelectedIndex ? 1 : -1);

        final screenH = MediaQuery.of(context).size.height;
        final swipeAreaMinHeight = (screenH * 0.52).clamp(260.0, 520.0);

        // Сегодня индекс (0..6) ТОЛЬКО если UI-неделя = текущая неделя.
        int? todayIndexInUiWeek;
        if (WeekUtils.sameWeek(_uiWeekStart, DateTime.now())) {
          todayIndexInUiWeek = DateTime.now().weekday - 1;
        }

        // ВАЖНО: заливку выбранного показываем только если UI-неделя совпадает с неделей расписания.
        // Иначе — пользователь "листает неделю", но расписание остаётся прежним => не нужно вводить в заблуждение.
        final int? filledSelectedIndex =
            WeekUtils.sameWeek(_uiWeekStart, _contentWeekStart)
            ? _selectedIndex
            : null;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 106),
              children: [
                if (repo.loading) ...[
                  const LoadingSkeletonStrip(),
                  const SizedBox(height: 12),
                ],
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {},
                  onHorizontalDragUpdate: (_) {},
                  onHorizontalDragEnd: (_) {},
                  child: _UnifiedHeaderCard(
                    parityText: uiParityText,
                    rangeText: _weekTitle(_uiWeekStart),
                    updatedText: _updatedAtText(updatedAt),
                    dayChanges: dayChanges,
                    dayTitle: dayTitle,
                    todayLabel: isToday ? 'Сегодня' : 'Вернуться',
                    onTodayTap: _goToToday,
                    changesOnly: _filter == ScheduleUiFilter.changes,
                    onToggleChangesOnly: _toggleChangesOnly,
                    onOpenWeekPicker: _openWeekPicker,
                  ),
                ),
                const SizedBox(height: 12),

                _WeekDotsRowAnimated(
                  weekStart: _uiWeekStart,
                  slideDir: _weekSlideDir,
                  filledSelectedIndex: filledSelectedIndex, // заливка
                  todayIndex: todayIndexInUiWeek, // обводка (если не выбран)
                  labels: _dots,
                  onTap: _selectDayInUiWeek,
                  onSwipeWeek: _uiSwipeWeek,
                ),
                const SizedBox(height: 12),

                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: swipeAreaMinHeight),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v.abs() < 250) return;
                      if (v < 0) {
                        _swipeDay(1);
                      } else {
                        _swipeDay(-1);
                      }
                    },
                    child: AnimatedSize(
                      duration: _kSizeAnim,
                      curve: _kSizeCurve,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: _kAnim,
                        switchInCurve: _kCurveIn,
                        switchOutCurve: _kCurveOut,
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: <Widget>[
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          );
                        },
                        transitionBuilder: (child, anim) {
                          final beginX = daySlideDir == 0
                              ? 0.0
                              : (daySlideDir > 0 ? 0.10 : -0.10);

                          return ClipRect(
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(beginX, 0),
                                end: Offset.zero,
                              ).animate(anim),
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(
                            '${_contentWeekStart.year}-${_contentWeekStart.month}-${_contentWeekStart.day}-$_selectedIndex-${_filter.name}',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
                            child: _DayPage(
                              date: contentDate,
                              lessons: dayLessons,
                              nextLesson: next,
                              isOngoing: (l) => _isOngoing(l, contentDate),
                              isPast: (l) => _isPast(l, contentDate),
                              onLessonTap: _openLessonDetails,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
