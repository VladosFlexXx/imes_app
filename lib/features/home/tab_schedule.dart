import 'package:flutter/material.dart';

import '../../core/widgets/update_banner.dart';
import '../schedule/models.dart';
import '../schedule/schedule_repository.dart';

// ✅ новое
import '../schedule/schedule_filter.dart';
import '../schedule/week_calendar_sheet.dart';
import '../schedule/week_utils.dart';

enum ScheduleFilter { all, changes, cancelled }

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final repo = ScheduleRepository.instance;

  ScheduleFilter _filter = ScheduleFilter.all;

  // ✅ выбранная “неделя”, относительно которой применяем правила
  DateTime _referenceDate = DateTime.now();

  final Map<String, GlobalKey> _dayKeys = {};
  bool _didAutoScroll = false;

  Future<void> _refresh() => repo.refresh(force: true);

  List<Lesson> _applyFilter(List<Lesson> lessons) {
    switch (_filter) {
      case ScheduleFilter.changes:
        return lessons.where((l) => l.status == LessonStatus.changed).toList();
      case ScheduleFilter.cancelled:
        return lessons.where((l) => l.status == LessonStatus.cancelled).toList();
      case ScheduleFilter.all:
      default:
        return lessons;
    }
  }

  Map<String, List<Lesson>> _groupByDay(List<Lesson> lessons) {
    final map = <String, List<Lesson>>{};
    for (final l in lessons) {
      map.putIfAbsent(l.day, () => <Lesson>[]).add(l);
    }
    return map;
  }

  String _todayDayNameRuUpper() {
    const map = <int, String>{
      1: 'ПОНЕДЕЛЬНИК',
      2: 'ВТОРНИК',
      3: 'СРЕДА',
      4: 'ЧЕТВЕРГ',
      5: 'ПЯТНИЦА',
      6: 'СУББОТА',
      7: 'ВОСКРЕСЕНЬЕ',
    };
    return map[DateTime.now().weekday]!;
  }

  void _tryAutoScrollToToday(Iterable<String> dayKeys) {
    if (_didAutoScroll) return;

    final today = _todayDayNameRuUpper();
    final todayKey = dayKeys.firstWhere(
      (d) => d.toUpperCase().trim() == today,
      orElse: () => '',
    );
    if (todayKey.isEmpty) return;

    final key = _dayKeys[todayKey];
    if (key?.currentContext == null) return;

    _didAutoScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key!.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  String _weekTitle(DateTime ref) {
    final s = WeekUtils.weekStart(ref);
    final e = WeekUtils.weekEnd(ref);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(s.day)}.${two(s.month)} – ${two(e.day)}.${two(e.month)}';
  }

  bool get _isCurrentWeek => WeekUtils.sameWeek(_referenceDate, DateTime.now());

  Future<void> _openWeekPicker() async {
    await WeekCalendarSheet.show(
      context,
      selectedDate: _referenceDate,
      onSelected: (d) => setState(() {
        _referenceDate = d;
        _didAutoScroll = false;
      }),
    );
  }

  void _goToCurrentWeek() {
    setState(() {
      _referenceDate = DateTime.now();
      _didAutoScroll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        // ✅ 1) фильтруем под выбранную неделю (referenceDate)
        final weekRelevant = filterLessonsForCurrentWeek(
          repo.lessons,
          referenceDate: _referenceDate,
        );

        // ✅ 2) затем UI-фильтр "Все/Изменения/Отмены"
        final filtered = _applyFilter(weekRelevant);
        final grouped = _groupByDay(filtered);

        for (final d in grouped.keys) {
          _dayKeys.putIfAbsent(d, () => GlobalKey());
        }
        _tryAutoScrollToToday(grouped.keys);

        final todayUpper = _todayDayNameRuUpper();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repo.loading ? 'Расписание (обновление...)' : 'Расписание'),
                Text(
                  _weekTitle(_referenceDate),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                UpdateBanner(repo: repo),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SegmentedButton<ScheduleFilter>(
                    segments: const [
                      ButtonSegment(
                        value: ScheduleFilter.all,
                        label: Text('Все'),
                        icon: Icon(Icons.view_agenda_outlined),
                      ),
                      ButtonSegment(
                        value: ScheduleFilter.changes,
                        label: Text('Изменения'),
                        icon: Icon(Icons.edit_calendar_outlined),
                      ),
                      ButtonSegment(
                        value: ScheduleFilter.cancelled,
                        label: Text('Отмены'),
                        icon: Icon(Icons.cancel_outlined),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (set) => setState(() => _filter = set.first),
                  ),
                ),

                if (grouped.isEmpty && !repo.loading) ...const [
                  SizedBox(height: 120),
                  Center(child: Text('Расписание пустое')),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final entry in grouped.entries)
                          _DaySection(
                            key: _dayKeys[entry.key],
                            day: entry.key,
                            lessons: entry.value,
                            isToday: entry.key.toUpperCase().trim() == todayUpper,
                          ),
                      ],
                    ),
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

class _DaySection extends StatelessWidget {
  final String day;
  final List<Lesson> lessons;
  final bool isToday;

  const _DaySection({
    super.key,
    required this.day,
    required this.lessons,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Text(
                    'сегодня',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final l in lessons) _LessonCard(lesson: l, isToday: isToday),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final bool isToday;

  const _LessonCard({required this.lesson, required this.isToday});

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

  bool _isOngoingNow() {
    if (!isToday) return false;
    final start = _parseStartToday(lesson.time);
    final end = _parseEndToday(lesson.time);
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return start.isBefore(now) && end.isAfter(now);
  }

  @override
  Widget build(BuildContext context) {
    final ongoing = _isOngoingNow();
    final isCancelled = lesson.status == LessonStatus.cancelled;

    Color bg;
    Color border;
    String? badge;

    if (ongoing) {
      bg = Theme.of(context).colorScheme.tertiaryContainer;
      border = Theme.of(context).colorScheme.tertiary;
      badge = 'Сейчас идёт';
    } else if (lesson.status == LessonStatus.changed) {
      bg = Colors.orange.withOpacity(0.12);
      border = Colors.orange.withOpacity(0.35);
      badge = 'Изменение';
    } else if (lesson.status == LessonStatus.cancelled) {
      bg = Colors.red.withOpacity(0.10);
      border = Colors.red.withOpacity(0.35);
      badge = 'Отмена';
    } else {
      bg = Theme.of(context).colorScheme.surface;
      border = Theme.of(context).colorScheme.outlineVariant;
      badge = null;
    }

    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w800,
          decoration: isCancelled ? TextDecoration.lineThrough : null,
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lesson.time,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isCancelled ? Theme.of(context).disabledColor : null,
                        ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    child: Text(
                      badge,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(lesson.subject, style: titleStyle),
            if (lesson.type.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(lesson.type),
            ],
            if (lesson.place.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Место: ${lesson.place}'),
            ],
            if (lesson.teacher.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Преподаватель: ${lesson.teacher}'),
            ],
          ],
        ),
      ),
    );
  }
}
