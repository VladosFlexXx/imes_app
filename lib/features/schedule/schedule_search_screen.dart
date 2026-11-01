import 'package:flutter/material.dart';

import '../../app.dart';
import '../../ui/app_haptics.dart';
import '../../ui/app_theme.dart';
import 'models.dart';
import 'schedule_repository.dart';
import 'ui_parts/lesson_details_sheet.dart';

class _SearchResultItem {
  final DateTime date;
  final Lesson lesson;

  const _SearchResultItem({
    required this.date,
    required this.lesson,
  });
}

class ScheduleSearchScreen extends StatefulWidget {
  const ScheduleSearchScreen({super.key});

  @override
  State<ScheduleSearchScreen> createState() => _ScheduleSearchScreenState();
}

class _ScheduleSearchScreenState extends State<ScheduleSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final _repo = ScheduleRepository.instance;

  String _query = '';
  List<_SearchResultItem> _results = [];
  List<String> _quickSuggestions = [];

  static const List<String> _ruWeekdays = [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];

  static const List<String> _ruMonths = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];

  @override
  void initState() {
    super.initState();
    _initSuggestions();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initSuggestions() {
    final subjects = <String>{};
    for (final l in _repo.lessons) {
      final s = l.subject.trim();
      if (s.isNotEmpty) subjects.add(s);
    }
    setState(() {
      _quickSuggestions = subjects.take(6).toList();
    });
  }

  void _onQueryChanged(String query) {
    setState(() {
      _query = query.trim().toLowerCase();
      _results = _search(_query);
    });
  }

  List<_SearchResultItem> _search(String query) {
    if (query.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = <_SearchResultItem>[];

    // Ищем на ближайшие 45 дней вперёд
    for (var i = 0; i < 45; i++) {
      final date = today.add(Duration(days: i));
      final lessons = _repo.lessonsForDate(date);

      for (final l in lessons) {
        final matchesSubject = l.subject.toLowerCase().contains(query);
        final matchesTeacher = l.teacher.toLowerCase().contains(query);
        final matchesPlace = l.place.toLowerCase().contains(query);
        final matchesType = l.type.toLowerCase().contains(query);

        if (matchesSubject || matchesTeacher || matchesPlace || matchesType) {
          results.add(_SearchResultItem(date: date, lesson: l));
        }
      }
    }
    return results;
  }

  String _formatDate(DateTime d) {
    final wd = _ruWeekdays[d.weekday - 1];
    final m = _ruMonths[d.month - 1];
    return '$wd, ${d.day} $m';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final accent = appAccentOf(context);

    final bg = isAmoled
        ? Colors.black
        : (isDark ? const Color(0xFF14171C) : const Color(0xFFF6F8FC));

    final cardBg = isAmoled
        ? const Color(0xFF0C0E12)
        : (isDark ? const Color(0xFF1E2228) : Colors.white);

    final cardBorder = isAmoled
        ? accent.withValues(alpha: 0.30)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.07));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AppHaptics.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF222731)
                : const Color(0xFFEDF1F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onQueryChanged,
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Предмет, преподаватель, аудитория...',
              hintStyle: t.bodyMedium?.copyWith(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.40),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: accent,
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        AppHaptics.selectionClick();
                        _controller.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _query.isEmpty ? _buildSuggestions(accent, isDark) : _buildResults(cardBg, cardBorder, accent, isDark),
      ),
    );
  }

  Widget _buildSuggestions(Color accent, bool isDark) {
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 18, color: accent),
            const SizedBox(width: 8),
            Text(
              'Предметы вашего расписания',
              style: t.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.70)
                    : Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _quickSuggestions)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  AppHaptics.selectionClick();
                  _controller.text = s;
                  _onQueryChanged(s);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: isDark
                        ? const Color(0xFF1E2228)
                        : const Color(0xFFEDF1F7),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        s,
                        style: t.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildResults(Color cardBg, Color cardBorder, Color accent, bool isDark) {
    final t = Theme.of(context).textTheme;

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 52,
                color: accent.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                'Ничего не найдено',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'По запросу «$_query» пар в ближайшие 45 дней не обнаружено.',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.60)
                      : Colors.black.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _results[index];
        final l = item.lesson;
        final dateStr = _formatDate(item.date);
        final isToday = DateUtils.isSameDay(item.date, DateTime.now());

        return Material(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              AppHaptics.lightImpact();
              showLessonDetailsSheet(
                context,
                lesson: l,
                lessonDate: item.date,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isToday
                              ? accent
                              : (isDark
                                  ? const Color(0xFF282D36)
                                  : const Color(0xFFE2E6EE)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isToday ? 'Сегодня · $dateStr' : dateStr,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isToday
                                ? Colors.white
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.time.replaceAll('.', ':'),
                        style: t.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                      const Spacer(),
                      if (l.type.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l.type.trim(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.subject,
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (l.place.trim().isNotEmpty) ...[
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.65)
                              : Colors.black.withValues(alpha: 0.60),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.place.trim(),
                          style: t.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.70)
                                : Colors.black.withValues(alpha: 0.70),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (l.teacher.trim().isNotEmpty) ...[
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.65)
                              : Colors.black.withValues(alpha: 0.60),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l.teacher.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.70)
                                  : Colors.black.withValues(alpha: 0.70),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
