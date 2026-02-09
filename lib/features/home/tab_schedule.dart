import 'package:flutter/material.dart';

import '../schedule/models.dart';
import '../schedule/schedule_filter.dart' as rules_filter;
import '../schedule/schedule_repository.dart';
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

  List<Lesson> _weekRelevantLessonsFor(DateTime anyDateInsideWeek) {
    // референс на середину недели
    final ref = anyDateInsideWeek.add(const Duration(days: 2));
    return rules_filter.filterLessonsForCurrentWeek(
      repo.lessons,
      referenceDate: ref,
    );
  }

  Map<int, List<Lesson>> _groupWeekByWeekday(List<Lesson> weekLessons) {
    final map = <int, List<Lesson>>{};
    for (final l in weekLessons) {
      final wd = _weekdayIndexFromLessonDay(l.day);
      if (wd == null) continue;
      map.putIfAbsent(wd, () => <Lesson>[]).add(l);
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
    if (!_isSameDay(day, now)) return false;
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
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    switch (l.status) {
      case LessonStatus.changed:
        statusText = 'Изменение';
        statusIcon = Icons.edit_calendar_outlined;
        statusColor = cs.primary;
        break;
      case LessonStatus.cancelled:
        statusText = 'Отмена';
        statusIcon = Icons.cancel_outlined;
        statusColor = cs.error;
        break;
      case LessonStatus.normal:
        statusText = 'Обычная пара';
        statusIcon = Icons.check_circle_outline;
        statusColor = cs.primary;
        break;
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusText,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.subject,
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _InfoChip(icon: Icons.calendar_today_outlined, text: l.day),
                  _InfoChip(icon: Icons.schedule, text: l.time),
                  if (l.place.trim().isNotEmpty)
                    _InfoChip(icon: Icons.place_outlined, text: l.place),
                  if (l.teacher.trim().isNotEmpty)
                    _InfoChip(icon: Icons.person_outline, text: l.teacher),
                  if (l.type.trim().isNotEmpty)
                    _InfoChip(icon: Icons.info_outline, text: l.type),
                ],
              ),
              const SizedBox(height: 10),
            ],
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

        final contentWeekLessons = _weekRelevantLessonsFor(_contentWeekStart);
        final contentGrouped = _groupWeekByWeekday(contentWeekLessons);

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
                  const LinearProgressIndicator(minHeight: 3),
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
                        child: Card(
                          key: ValueKey(
                            '${_contentWeekStart.year}-${_contentWeekStart.month}-${_contentWeekStart.day}-$_selectedIndex-${_filter.name}',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
