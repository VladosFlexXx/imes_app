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

class _ScheduleTabState extends State<ScheduleTab> {
  final repo = ScheduleRepository.instance;

  ScheduleUiFilter _filter = ScheduleUiFilter.all;

  /// Якорь для бесконечного PageView (старт понедельника текущей недели).
  late final DateTime _anchorWeekStart;

  /// Большая стартовая страница, чтобы можно было бесконечно ходить в обе стороны.
  static const int _pageBase = 10000;

  /// Текущая страница PageView.
  late int _currentPage;

  /// Любая дата внутри выбранной недели (якорь недели).
  DateTime _weekRef = DateTime.now();

  /// 0..6 (Пн..Вс)
  int _selectedIndex = DateTime.now().weekday - 1;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    _anchorWeekStart = WeekUtils.weekStart(DateTime.now());
    _selectedIndex = DateTime.now().weekday - 1;

    _currentPage = _pageBase + _selectedIndex;
    _pageController = PageController(initialPage: _currentPage);

    // weekRef держим как "любая дата недели" — пусть будет понедельник выбранной недели
    _weekRef = _anchorWeekStart;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => repo.refresh(force: true);

  // =========================
  // helpers: математика индексов (важно для отрицательных)
  // =========================

  int _floorDiv(int a, int b) {
    // floor(a / b) для int, корректно работает с отрицательными
    var q = a ~/ b; // trunc toward zero
    final r = a % b;
    if (r != 0 && ((a < 0) != (b < 0))) q -= 1;
    return q;
  }

  int _mod(int a, int b) {
    var m = a % b;
    if (m < 0) m += b;
    return m;
  }

  int _weekOffsetForPage(int page) {
    final delta = page - _pageBase;
    return _floorDiv(delta, 7);
  }

  int _dayIndexForPage(int page) {
    final delta = page - _pageBase;
    return _mod(delta, 7); // 0..6
  }

  DateTime _weekStartForOffset(int weekOffset) {
    return _anchorWeekStart.add(Duration(days: weekOffset * 7));
  }

  void _syncFromPage(int page) {
    final weekOffset = _weekOffsetForPage(page);
    final dayIndex = _dayIndexForPage(page);

    final weekStart = _weekStartForOffset(weekOffset);

    setState(() {
      _currentPage = page;
      _selectedIndex = dayIndex;
      _weekRef = weekStart; // якорь недели
    });
  }

  // =========================
  // Helpers: даты/форматы
  // =========================

  String _two(int x) => x.toString().padLeft(2, '0');

  DateTime _weekStart() => WeekUtils.weekStart(_weekRef);
  DateTime _weekEnd() => WeekUtils.weekEnd(_weekRef);

  String _weekTitle() {
    final s = _weekStart();
    final e = _weekEnd();
    return '${_two(s.day)}.${_two(s.month)} – ${_two(e.day)}.${_two(e.month)}';
  }

  String _updatedAtText(DateTime? dt) {
    if (dt == null) return '—';
    return '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  DateTime _dateForSelectedIndex() => _weekStart().add(Duration(days: _selectedIndex));

  bool get _isCurrentWeek => WeekUtils.sameWeek(_weekRef, DateTime.now());

  // =========================
  // Нормализация дня недели из lesson.day -> 1..7
  // =========================

  static final Map<String, int> _ruDayToWeekday = {
    'понедельник': 1,
    'вторник': 2,
    'среда': 3,
    'четверг': 4,
    'пятница': 5,
    'суббота': 6,
    'воскресенье': 7,
    'ПОНЕДЕЛЬНИК': 1,
    'ВТОРНИК': 2,
    'СРЕДА': 3,
    'ЧЕТВЕРГ': 4,
    'ПЯТНИЦА': 5,
    'СУББОТА': 6,
    'ВОСКРЕСЕНЬЕ': 7,
    'пн': 1,
    'вт': 2,
    'ср': 3,
    'чт': 4,
    'пт': 5,
    'сб': 6,
    'вс': 7,
  };

  int? _weekdayIndexFromLessonDay(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final direct = _ruDayToWeekday[s];
    if (direct != null) return direct;

    final low = s.toLowerCase();
    final lowHit = _ruDayToWeekday[low];
    if (lowHit != null) return lowHit;

    final short2 = low.length >= 2 ? low.substring(0, 2) : low;
    return _ruDayToWeekday[short2];
  }

  // =========================
  // Фильтры
  // =========================

  List<Lesson> _applyUiFilter(List<Lesson> lessons) {
    switch (_filter) {
      case ScheduleUiFilter.changes:
        return lessons
            .where((l) =>
                l.status == LessonStatus.changed ||
                l.status == LessonStatus.cancelled)
            .toList();
      case ScheduleUiFilter.all:
      default:
        return lessons;
    }
  }

  /// Уроки для выбранной недели с учётом правил/чётности.
  List<Lesson> _weekRelevantLessons() {
    return rules_filter.filterLessonsForCurrentWeek(
      repo.lessons,
      referenceDate: _weekRef,
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

  // =========================
  // “Сейчас/следующая/прошла”
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
        statusColor = Colors.orange;
        break;
      case LessonStatus.cancelled:
        statusText = 'Отмена';
        statusIcon = Icons.cancel_outlined;
        statusColor = cs.error;
        break;
      case LessonStatus.normal:
      default:
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
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
              const SizedBox(height: 12),
              Text(
                'Если это изменение/отмена — детали зависят от того, как ЭИОС отдаёт расписание.',
                style: t.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.72)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // Week picker / navigation
  // =========================

  int _weekOffsetBetween(DateTime fromWeekStart, DateTime toWeekStart) {
    final diffDays = toWeekStart.difference(fromWeekStart).inDays;
    return _floorDiv(diffDays, 7);
  }

  Future<void> _openWeekPicker() async {
    await WeekCalendarSheet.show(
      context,
      selectedDate: _weekRef,
      onSelected: (d) {
        final selectedWeekStart = WeekUtils.weekStart(d);
        final offset = _weekOffsetBetween(_anchorWeekStart, selectedWeekStart);

        final targetDayIndex = WeekUtils.sameWeek(d, DateTime.now())
            ? (DateTime.now().weekday - 1)
            : 0;

        final targetPage = _pageBase + offset * 7 + targetDayIndex;

        _pageController.jumpToPage(targetPage);
        _syncFromPage(targetPage);
      },
    );
  }

  void _goToCurrentWeek() {
    final todayIndex = DateTime.now().weekday - 1;
    final targetPage = _pageBase + todayIndex;
    _pageController.jumpToPage(targetPage);
    _syncFromPage(targetPage);
  }

  // =========================
  // UI
  // =========================

  static const List<String> _dots = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];
  static const List<String> _full = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final weekRelevant = _weekRelevantLessons();
        final grouped = _groupWeekByWeekday(weekRelevant);

        final parity = WeekParityService.parityFor(_weekRef);
        final parityText =
            parity == WeekParity.even ? 'чётная неделя' : 'нечётная неделя';

        final updatedAt = repo.updatedAt;

        final dayDate = _dateForSelectedIndex();
        final isToday = WeekUtils.isSameDay(dayDate, DateTime.now());

        final weekday = _selectedIndex + 1;
        final dayLessonsAll = grouped[weekday] ?? const <Lesson>[];
        final dayLessons = _applyUiFilter(dayLessonsAll);

        final next = _nextLesson(dayLessons, dayDate);

        final weekChanged =
            weekRelevant.where((l) => l.status == LessonStatus.changed).length;
        final weekCancelled =
            weekRelevant.where((l) => l.status == LessonStatus.cancelled).length;

        final dayChanges = dayLessonsAll
            .where((l) =>
                l.status == LessonStatus.changed ||
                l.status == LessonStatus.cancelled)
            .length;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repo.loading ? 'Расписание (обновление...)' : 'Расписание'),
                Text(
                  _weekTitle(),
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
              if (!_isCurrentWeek)
                IconButton(
                  tooltip: 'К текущей неделе',
                  onPressed: _goToCurrentWeek,
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
                _UnifiedHeaderCard(
                  parityText: parityText,
                  rangeText: _weekTitle(),
                  updatedText: _updatedAtText(updatedAt),
                  weekChanged: weekChanged,
                  weekCancelled: weekCancelled,
                  dayChanges: dayChanges,
                  dayTitle:
                      '${_full[_selectedIndex]} • ${_two(dayDate.day)}.${_two(dayDate.month)}',
                  showTodayPill: isToday,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 12),

                _WeekDotsRow(
                  selectedIndex: _selectedIndex,
                  labels: _dots,
                  onTap: (i) {
                    // остаёмся в той же неделе, меняем только день
                    final currentDayIndex = _dayIndexForPage(_currentPage);
                    final baseWeekPage = _currentPage - currentDayIndex;
                    final target = baseWeekPage + i;

                    _pageController.animateToPage(
                      target,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                    _syncFromPage(target);
                  },
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 520,
                  child: PageView.builder(
                    controller: _pageController,
                    // itemCount = null => бесконечно
                    onPageChanged: (page) => _syncFromPage(page),
                    itemBuilder: (context, page) {
                      final weekOffset = _weekOffsetForPage(page);
                      final dayIndex = _dayIndexForPage(page);

                      final weekStart = _weekStartForOffset(weekOffset);
                      final date = weekStart.add(Duration(days: dayIndex));

                      final weekRefForThisPage = weekStart;

                      final weekRelevantForThisPage =
                          rules_filter.filterLessonsForCurrentWeek(
                        repo.lessons,
                        referenceDate: weekRefForThisPage,
                      );
                      final groupedForThisPage =
                          _groupWeekByWeekday(weekRelevantForThisPage);

                      final wd = dayIndex + 1;
                      final all = groupedForThisPage[wd] ?? const <Lesson>[];
                      final filtered = _applyUiFilter(all);
                      final n = _nextLesson(filtered, date);

                      return _DayPage(
                        date: date,
                        lessons: filtered,
                        nextLesson: n,
                        isOngoing: (l) => _isOngoing(l, date),
                        isPast: (l) => _isPast(l, date),
                        onLessonTap: _openLessonDetails,
                      );
                    },
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

  final int weekChanged;
  final int weekCancelled;
  final int dayChanges;

  final String dayTitle;
  final bool showTodayPill;

  final ScheduleUiFilter filter;
  final ValueChanged<ScheduleUiFilter> onFilterChanged;

  const _UnifiedHeaderCard({
    required this.parityText,
    required this.rangeText,
    required this.updatedText,
    required this.weekChanged,
    required this.weekCancelled,
    required this.dayChanges,
    required this.dayTitle,
    required this.showTodayPill,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pill(icon: Icons.swap_vert_circle_outlined, text: parityText),
                const SizedBox(width: 8),
                _Pill(icon: Icons.date_range_outlined, text: rangeText),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Icon(Icons.sync, size: 18, color: cs.onSurface.withOpacity(0.75)),
                const SizedBox(width: 8),
                Text(
                  'Обновлено: $updatedText',
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withOpacity(0.78),
                  ),
                ),
                const Spacer(),
                if (weekChanged > 0)
                  _CountBadge(
                    icon: Icons.edit_calendar_outlined,
                    text: '$weekChanged',
                    tone: _BadgeTone.warn,
                  ),
                if (weekChanged > 0) const SizedBox(width: 8),
                if (weekCancelled > 0)
                  _CountBadge(
                    icon: Icons.cancel_outlined,
                    text: '$weekCancelled',
                    tone: _BadgeTone.danger,
                  ),
              ],
            ),

            if (dayChanges > 0) ...[
              const SizedBox(height: 10),
              Text(
                'В выбранный день изменений: $dayChanges',
                style: t.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.72)),
              ),
            ],

            const SizedBox(height: 12),
            Divider(color: cs.outlineVariant.withOpacity(0.35), height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    dayTitle,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                Visibility(
                  visible: showTodayPill,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: _Pill(icon: Icons.today, text: 'сегодня'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            SegmentedButton<ScheduleUiFilter>(
              segments: const [
                ButtonSegment(
                  value: ScheduleUiFilter.all,
                  label: Text('Все'),
                  icon: Icon(Icons.view_agenda_outlined),
                ),
                ButtonSegment(
                  value: ScheduleUiFilter.changes,
                  label: Text('Изменения'),
                  icon: Icon(Icons.edit_calendar_outlined),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (set) => onFilterChanged(set.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDotsRow extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onTap;

  const _WeekDotsRow({
    required this.selectedIndex,
    required this.labels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(labels.length, (i) {
        final selected = i == selectedIndex;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onTap(i),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? cs.primary.withOpacity(0.12)
                      : cs.surfaceVariant.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? cs.primary.withOpacity(0.70)
                        : cs.outlineVariant.withOpacity(0.35),
                    width: selected ? 1.6 : 1.0,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: selected ? cs.primary : cs.onSurface.withOpacity(0.78),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.inbox_outlined, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Нет занятий',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final l in lessons)
                    _LessonCard(
                      lesson: l,
                      isToday: WeekUtils.isSameDay(date, DateTime.now()),
                      isOngoing: isOngoing(l),
                      isNext: nextLesson != null &&
                          nextLesson!.day == l.day &&
                          nextLesson!.time == l.time &&
                          nextLesson!.subject == l.subject,
                      isPast: isPast(l),
                      onTap: () => onLessonTap(l),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      bg = cs.tertiaryContainer.withOpacity(0.75);
      border = cs.tertiary.withOpacity(0.55);
      badgeIcon = Icons.play_circle_outline;
      badgeText = 'идёт';
    } else if (isNext) {
      bg = cs.primaryContainer.withOpacity(0.55);
      border = cs.primary.withOpacity(0.45);
      badgeIcon = Icons.skip_next_outlined;
      badgeText = 'следующая';
    } else if (lesson.status == LessonStatus.changed) {
      bg = Colors.orange.withOpacity(0.10);
      border = Colors.orange.withOpacity(0.35);
      badgeIcon = Icons.edit_calendar_outlined;
      badgeText = 'изменение';
    } else if (lesson.status == LessonStatus.cancelled) {
      bg = cs.errorContainer.withOpacity(0.55);
      border = cs.error.withOpacity(0.45);
      badgeIcon = Icons.cancel_outlined;
      badgeText = 'отмена';
    } else {
      bg = cs.surfaceVariant.withOpacity(0.22);
      border = cs.outlineVariant.withOpacity(0.35);
      badgeIcon = null;
      badgeText = null;
    }

    final faded = isPast && isToday;
    final opacity = faded ? 0.72 : 1.0;

    final titleStyle = t.titleSmall?.copyWith(
      fontWeight: FontWeight.w900,
      decoration: isCancelled ? TextDecoration.lineThrough : null,
    );

    final timeStyle = t.bodyMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface.withOpacity(0.80),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface.withOpacity(0.70),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badgeIcon != null) ...[
                            Icon(badgeIcon, size: 16, color: cs.onSurface.withOpacity(0.80)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            badgeText!,
                            style: t.labelSmall?.copyWith(fontWeight: FontWeight.w900),
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
        color: cs.surface.withOpacity(0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withOpacity(0.80)),
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({
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
        color: cs.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withOpacity(0.80)),
          const SizedBox(width: 6),
          Text(
            text,
            style: t.labelSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

enum _BadgeTone { warn, danger }

class _CountBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final _BadgeTone tone;

  const _CountBadge({
    required this.icon,
    required this.text,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    Color fg;
    Color bg;
    Color border;

    switch (tone) {
      case _BadgeTone.danger:
        fg = Colors.red;
        bg = Colors.red.withOpacity(0.10);
        border = Colors.red.withOpacity(0.25);
        break;
      case _BadgeTone.warn:
      default:
        fg = Colors.orange;
        bg = Colors.orange.withOpacity(0.10);
        border = Colors.orange.withOpacity(0.25);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            style: t.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
