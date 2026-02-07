import 'package:flutter/material.dart';

import '../schedule/models.dart';
import '../schedule/schedule_filter.dart' as rules_filter;
import '../schedule/schedule_repository.dart';
import '../schedule/week_calendar_sheet.dart';
import '../schedule/week_parity.dart';
import '../schedule/week_parity_service.dart';
import '../schedule/week_utils.dart';

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

  bool get _isCurrentWeekUi => WeekUtils.sameWeek(_uiWeekStart, DateTime.now());

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
          .where((l) =>
              l.status == LessonStatus.changed ||
              l.status == LessonStatus.cancelled)
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
      _weekSlideDir =
          week.isAfter(_uiWeekStart) ? 1 : (week.isBefore(_uiWeekStart) ? -1 : 0);

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
                      style:
                          t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
    final t = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final uiParity = WeekParityService.parityFor(_uiWeekStart);
        final uiParityText =
            uiParity == WeekParity.even ? 'чётная неделя' : 'нечётная неделя';

        final updatedAt = repo.updatedAt;

        final contentWeekLessons = _weekRelevantLessonsFor(_contentWeekStart);
        final contentGrouped = _groupWeekByWeekday(contentWeekLessons);

        final contentDate = _dateForSelected();
        final isToday = WeekUtils.isSameDay(contentDate, DateTime.now());

        final weekday = _selectedIndex + 1;
        final dayLessonsAll = contentGrouped[weekday] ?? const <Lesson>[];
        final dayLessons = _applyUiFilter(dayLessonsAll);

        final next = _nextLesson(dayLessons, contentDate);

        final weekChangesTotal = contentWeekLessons
            .where((l) =>
                l.status == LessonStatus.changed ||
                l.status == LessonStatus.cancelled)
            .length;

        final dayChanges = dayLessonsAll
            .where((l) =>
                l.status == LessonStatus.changed ||
                l.status == LessonStatus.cancelled)
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
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repo.loading ? 'Расписание (обновление...)' : 'Расписание'),
                Text(
                  _weekTitle(_uiWeekStart),
                  style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            bottom: repo.loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Выбрать неделю',
                onPressed: _openWeekPicker,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              if (!_isCurrentWeekUi)
                IconButton(
                  tooltip: 'К текущей неделе',
                  onPressed: _goToToday,
                  icon: const Icon(Icons.today),
                ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: repo.loading ? null : () => repo.refresh(force: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {},
                  onHorizontalDragUpdate: (_) {},
                  onHorizontalDragEnd: (_) {},
                  child: _UnifiedHeaderCard(
                    parityText: uiParityText,
                    rangeText: _weekTitle(_uiWeekStart),
                    updatedText: _updatedAtText(updatedAt),
                    weekChangesTotal: weekChangesTotal,
                    dayChanges: dayChanges,
                    dayTitle: dayTitle,
                    todayLabel: isToday ? 'Сегодня' : 'Вернуться',
                    onTodayTap: _goToToday,
                    changesOnly: _filter == ScheduleUiFilter.changes,
                    onToggleChangesOnly: _toggleChangesOnly,
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
                              child:
                                  FadeTransition(opacity: anim, child: child),
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

class _UnifiedHeaderCard extends StatelessWidget {
  final String parityText;
  final String rangeText;
  final String updatedText;

  final int weekChangesTotal;
  final int dayChanges;

  final String dayTitle;

  final String todayLabel;
  final VoidCallback onTodayTap;

  final bool changesOnly;
  final VoidCallback onToggleChangesOnly;

  const _UnifiedHeaderCard({
    required this.parityText,
    required this.rangeText,
    required this.updatedText,
    required this.weekChangesTotal,
    required this.dayChanges,
    required this.dayTitle,
    required this.todayLabel,
    required this.onTodayTap,
    required this.changesOnly,
    required this.onToggleChangesOnly,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final titleStyle = t.titleMedium?.copyWith(fontWeight: FontWeight.w900);
    final subStyle = t.bodySmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface.withValues(alpha: 0.78),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(icon: Icons.swap_vert_circle_outlined, text: parityText),
                _Pill(icon: Icons.date_range_outlined, text: rangeText),
                if (weekChangesTotal > 0)
                  _Pill(
                    icon: Icons.edit_calendar_outlined,
                    text: 'Изм.: $weekChangesTotal',
                    tone: _PillTone.warn,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.sync, size: 18, color: cs.onSurface.withValues(alpha: 0.75)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Обновлено: $updatedText',
                    style: subStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dayChanges > 0
                  ? 'В выбранный день изменений: $dayChanges'
                  : 'Сегодня изменений нет',
              style: t.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 12),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.35), height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    dayTitle,
                    style: titleStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                _TapPill(
                  icon: Icons.today,
                  text: todayLabel,
                  active: true,
                  onTap: onTodayTap,
                ),
                const SizedBox(width: 8),
                _TapPill(
                  icon: Icons.edit_calendar_outlined,
                  text: 'Изм.',
                  active: changesOnly,
                  onTap: onToggleChangesOnly,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDotsRowAnimated extends StatelessWidget {
  final DateTime weekStart;
  final int slideDir; // -1 / 0 / +1

  /// Заполненный (выбранный) день, или null если UI-неделя != неделя расписания.
  final int? filledSelectedIndex;

  /// Сегодня (обводка), если UI-неделя = текущая.
  final int? todayIndex;

  final List<String> labels;

  final ValueChanged<int> onTap;
  final ValueChanged<int> onSwipeWeek; // -1 / +1

  const _WeekDotsRowAnimated({
    required this.weekStart,
    required this.slideDir,
    required this.filledSelectedIndex,
    required this.todayIndex,
    required this.labels,
    required this.onTap,
    required this.onSwipeWeek,
  });

  @override
  Widget build(BuildContext context) {
    final key = ValueKey('${weekStart.year}-${weekStart.month}-${weekStart.day}');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 250) return;
        if (v < 0) {
          onSwipeWeek(1);
        } else {
          onSwipeWeek(-1);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) {
          final beginX =
              slideDir == 0 ? 0.0 : (slideDir > 0 ? 0.18 : -0.18);

          return ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(beginX, 0),
                end: Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
          );
        },
        child: _WeekDotsRow(
          key: key,
          weekStart: weekStart,
          filledSelectedIndex: filledSelectedIndex,
          todayIndex: todayIndex,
          labels: labels,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// КРУЖКИ:
/// - выбранный: ЗАЛИВКА (filled)
/// - сегодня: ОБВОДКА (outline), но только если сегодня НЕ выбран (иначе и так видно)
/// - никаких точек
class _WeekDotsRow extends StatelessWidget {
  final DateTime weekStart;
  final int? filledSelectedIndex;
  final int? todayIndex;
  final List<String> labels;
  final ValueChanged<int> onTap;

  const _WeekDotsRow({
    super.key,
    required this.weekStart,
    required this.filledSelectedIndex,
    required this.todayIndex,
    required this.labels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final raw = (constraints.maxWidth - gap * 6) / 7;
        final size = raw.clamp(40.0, 54.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(labels.length, (i) {
            final isSelected =
                filledSelectedIndex != null && i == filledSelectedIndex;
            final isToday = todayIndex != null && i == todayIndex;

            final date = weekStart.add(Duration(days: i));
            final dayNum = date.day;

            final bg = isSelected
                ? cs.primary.withValues(alpha: 0.95)
                : cs.surfaceContainerHighest.withValues(alpha: 0.30);

            // сегодня обводим только если НЕ выбран (иначе будет “обводка + заливка”)
            final showTodayOutline = isToday && !isSelected;

            final borderColor = isSelected
                ? cs.primary
                : (showTodayOutline
                    ? cs.primary.withValues(alpha: 0.75)
                    : cs.outlineVariant.withValues(alpha: 0.35));

            final borderWidth = showTodayOutline ? 1.6 : (isSelected ? 0.0 : 1.0);

            final fgMain = isSelected ? cs.onPrimary : cs.onSurface.withValues(alpha: 0.82);
            final fgSub = isSelected
                ? cs.onPrimary.withValues(alpha: 0.85)
                : cs.onSurface.withValues(alpha: 0.45);

            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onTap(i),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bg,
                  border: borderWidth == 0.0
                      ? null
                      : Border.all(color: borderColor, width: borderWidth),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: fgMain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: fgSub,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _DayPage extends StatelessWidget {
  final DateTime date;

  final List<Lesson> lessons;
  final Lesson? nextLesson;

  final bool Function(Lesson l) isOngoing;
  final bool Function(Lesson l) isPast;

  final void Function(Lesson l) onLessonTap;

  const _DayPage({
    required this.date,
    required this.lessons,
    required this.nextLesson,
    required this.isOngoing,
    required this.isPast,
    required this.onLessonTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    if (lessons.isEmpty) {
      return Row(
        children: [
          Icon(Icons.event_busy_outlined, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Нет занятий',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < lessons.length; i++) ...[
          _LessonCard(
            lesson: lessons[i],
            isToday: WeekUtils.isSameDay(date, DateTime.now()),
            isOngoing: isOngoing(lessons[i]),
            isNext: nextLesson != null &&
                nextLesson!.day == lessons[i].day &&
                nextLesson!.time == lessons[i].time &&
                nextLesson!.subject == lessons[i].subject,
            isPast: isPast(lessons[i]),
            onTap: () => onLessonTap(lessons[i]),
          ),
        ],
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;

  final bool isToday;
  final bool isOngoing;
  final bool isNext;
  final bool isPast;

  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.isToday,
    required this.isOngoing,
    required this.isNext,
    required this.isPast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final isCancelled = lesson.status == LessonStatus.cancelled;

    Color bg;
    Color border;
    IconData? badgeIcon;
    String? badgeText;

    if (isOngoing) {
      bg = cs.tertiaryContainer.withValues(alpha: 0.75);
      border = cs.tertiary.withValues(alpha: 0.55);
      badgeIcon = Icons.play_circle_outline;
      badgeText = 'идёт';
    } else if (isNext) {
      bg = cs.primaryContainer.withValues(alpha: 0.55);
      border = cs.primary.withValues(alpha: 0.45);
      badgeIcon = Icons.skip_next_outlined;
      badgeText = 'следующая';
    } else if (lesson.status == LessonStatus.changed) {
      bg = cs.primaryContainer.withValues(alpha: 0.42);
      border = cs.primary.withValues(alpha: 0.40);
      badgeIcon = Icons.edit_calendar_outlined;
      badgeText = 'изменение';
    } else if (lesson.status == LessonStatus.cancelled) {
      bg = cs.errorContainer.withValues(alpha: 0.55);
      border = cs.error.withValues(alpha: 0.45);
      badgeIcon = Icons.cancel_outlined;
      badgeText = 'отмена';
    } else {
      bg = cs.surfaceContainerHighest.withValues(alpha: 0.22);
      border = cs.outlineVariant.withValues(alpha: 0.35);
      badgeIcon = null;
      badgeText = null;
    }

    final faded = isPast && isToday;
    final opacity = faded ? 0.72 : 1.0;

    final titleStyle = t.bodyLarge?.copyWith(
      fontWeight: FontWeight.w900,
      decoration: isCancelled ? TextDecoration.lineThrough : null,
    );

    final timeStyle = t.bodySmall?.copyWith(
      fontWeight: FontWeight.w900,
      color: cs.onSurface.withValues(alpha: 0.80),
      decoration: isCancelled ? TextDecoration.lineThrough : null,
    );

    return Opacity(
      opacity: opacity,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(lesson.time, style: timeStyle),
                  const Spacer(),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badgeIcon != null) ...[
                            Icon(badgeIcon,
                                size: 16,
                                color: cs.onSurface.withValues(alpha: 0.80)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            badgeText,
                            style: t.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(lesson.subject, style: titleStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (lesson.type.trim().isNotEmpty)
                    _InfoChip(icon: Icons.info_outline, text: lesson.type),
                  if (lesson.place.trim().isNotEmpty)
                    _InfoChip(icon: Icons.place_outlined, text: lesson.place),
                  if (lesson.teacher.trim().isNotEmpty)
                    _InfoChip(icon: Icons.person_outline, text: lesson.teacher),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.80)),
          const SizedBox(width: 6),
          Text(
            text,
            style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

enum _PillTone { normal, warn }

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final _PillTone tone;

  const _Pill({
    required this.icon,
    required this.text,
    this.tone = _PillTone.normal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    Color border = cs.outlineVariant.withValues(alpha: 0.35);
    Color bg = cs.surfaceContainerHighest.withValues(alpha: 0.35);
    Color fg = cs.onSurface.withValues(alpha: 0.80);

    if (tone == _PillTone.warn) {
      border = cs.primary.withValues(alpha: 0.40);
      bg = cs.primaryContainer.withValues(alpha: 0.35);
      fg = cs.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style:
                t.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: fg),
          ),
        ],
      ),
    );
  }
}

class _TapPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _TapPill({
    required this.icon,
    required this.text,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final bg = active
        ? cs.primary.withValues(alpha: 0.18)
        : cs.surfaceContainerHighest.withValues(alpha: 0.28);
    final border = active
        ? cs.primary.withValues(alpha: 0.45)
        : cs.outlineVariant.withValues(alpha: 0.35);
    final fg = active ? cs.primary : cs.onSurface.withValues(alpha: 0.78);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              text,
              style:
                  t.labelSmall?.copyWith(fontWeight: FontWeight.w900, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
