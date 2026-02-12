import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../ui/app_theme.dart';
import '../../ui/shimmer_skeleton.dart';

import '../grades/models.dart';
import '../grades/repository.dart';
import '../grades/course_report_screen.dart';
import '../schedule/schedule_repository.dart';

import '../recordbook/repository.dart';
import '../recordbook/models.dart';

import '../study_plan/repository.dart';
import '../study_plan/models.dart';

part '../grades/ui_parts/course_card.dart';
part '../grades/ui_parts/study_plan_card.dart';
part '../grades/ui_parts/recordbook_card.dart';
part '../grades/ui_parts/badge.dart';
part '../grades/ui_parts/chip.dart';

enum StudySection { disciplines, studyPlan, recordbook }

Color _gradesAccent(BuildContext context) => appAccentOf(context);

class GradesTab extends StatefulWidget {
  const GradesTab({super.key});

  @override
  State<GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<GradesTab>
    with SingleTickerProviderStateMixin {
  final gradesRepo = GradesRepository.instance;
  final scheduleRepo = ScheduleRepository.instance;

  final planRepo = StudyPlanRepository.instance;
  final recordRepo = RecordbookRepository.instance;

  late final TabController _tabController;

  String _query = '';

  // дисциплины
  int _cap = 50;

  // учебный план
  int _planSemester = 1;

  // зачётка
  String? _selectedGradebook;
  int _recordSemester = 1;

  static const _kGradesCapKey = 'grades_current_cap_v1';

  @override
  void initState() {
    super.initState();

    unawaited(gradesRepo.init());
    unawaited(scheduleRepo.init());
    unawaited(planRepo.init());
    unawaited(recordRepo.init());

    // Ленивая догрузка второстепенных вкладок без стартового "шторма".
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      unawaited(gradesRepo.refresh(force: false));
    });
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      unawaited(planRepo.refresh(force: false));
    });
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      unawaited(recordRepo.refresh(force: false));
    });

    _tabController = TabController(
      length: 3,
      vsync: this,
      animationDuration: const Duration(milliseconds: 220),
    );

    _loadCap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCap() async {
    final prefs = await SharedPreferences.getInstance();
    final cap = prefs.getInt(_kGradesCapKey);
    if (cap != null && cap >= 0 && cap <= 200) {
      setState(() => _cap = cap);
    }
  }

  Future<void> _setCap(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGradesCapKey, v);
    setState(() => _cap = v);
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // =========================
  // Tabs
  // =========================

  Widget _sectionTabs() {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1A1E23), Color(0xFF171B21)]
              : const [Color(0xFFF1F3F7), Color(0xFFE9EDF4)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _gradesAccent(context),
          border: Border.all(color: _gradesAccent(context)),
        ),
        labelColor: isDark ? Colors.white : cs.onPrimary,
        unselectedLabelColor: isDark
            ? Colors.white.withValues(alpha: 0.74)
            : cs.onSurface.withValues(alpha: 0.74),
        indicatorPadding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: 2,
        ),
        labelStyle: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        unselectedLabelStyle: t.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        onTap: (idx) {
          if (idx == _tabController.index) return;
          _tabController.animateTo(
            idx,
            duration: const Duration(milliseconds: 220),
          );
        },
        tabs: const [
          Tab(text: 'Дисциплины'),
          Tab(text: 'План'),
          Tab(text: 'Зачётка'),
        ],
      ),
    );
  }

  // =========================
  // Helpers: disciplines filter
  // =========================

  int? _subjectPart(String s) {
    final x = s.toLowerCase();
    final m = RegExp(r'(?:ч\.?|част[ья])\s*[-.]?\s*(\d{1,2})').firstMatch(x);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  String _normSubject(String s) {
    var x = s.toLowerCase().trim();
    final part = _subjectPart(x);

    // Приводим к "базовому" названию дисциплины, чтобы матчиться с расписанием.
    x = x.replaceAll('_', ' ');

    // Убираем префиксы типа "ОД." / "дисциплина:" и т.п.
    x = x.replaceAll(
      RegExp(r'^\s*(од\.|дисциплина:|дисц\.)\s*', caseSensitive: false),
      '',
    );

    // Убираем популярные хвосты/скобки
    x = x.replaceAll(RegExp(r'\(.*?недел.*?\)'), ''); // (нечетная неделя)
    x = x.replaceAll(RegExp(r'\(.*?\)'), ''); // прочие скобки (опционально)

    // Убираем "28/0/28" / "42/28/14" и подобные хвосты (обычно после подчёркивания)
    x = x.replaceAll(RegExp(r'\b\d+\s*/\s*\d+\s*/\s*\d+\b'), '');
    x = x.replaceAll(RegExp(r'\b\d+\s*/\s*\d+\b'), '');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (part != null) x = '$x [part:$part]';
    return x.trim();
  }

  String _normSubjectBase(String s) {
    var x = _normSubject(s);
    x = x.replaceAll(RegExp(r'\s*\[part:\d+\]\s*$'), '');
    return x.trim();
  }

  Set<String> _scheduleSubjectsNorm() {
    final set = <String>{};
    for (final l in scheduleRepo.lessons) {
      final n = _normSubject(l.subject);
      if (n.isNotEmpty) set.add(n);
    }
    return set;
  }

  bool _inSchedule(
    GradeCourse c, {
    required Set<String> scheduleNorm,
    required Set<String> scheduleBase,
  }) {
    final exact = _normSubject(c.courseName);
    final base = _normSubjectBase(c.courseName);
    return scheduleNorm.contains(exact) || scheduleBase.contains(base);
  }

  int? _extractPoints(GradeCourse c) {
    final preferredKeys = <String>[
      'балл',
      'рейтинг',
      'итог',
      'итого',
      'score',
      'points',
      'result',
      'total',
      'процент',
      'percentage',
    ];

    int? pickBest(String raw) {
      int? best;
      for (final m in RegExp(r'(\d{1,3})(?:[.,](\d{1,2}))?').allMatches(raw)) {
        final whole = m.group(1);
        if (whole == null) continue;
        final n = int.tryParse(whole);
        if (n == null) continue;
        if (n < 0 || n > 100) continue;
        if (best == null || n > best) best = n;
      }
      return best;
    }

    // 1) Явные поля модели.
    final fromGrade = pickBest(c.grade ?? '');
    if (fromGrade != null) return fromGrade;
    final fromPercent = pickBest(c.percent ?? '');
    if (fromPercent != null) return fromPercent;

    // 2) Только релевантные колонки по ключам.
    int? bestPreferred;
    for (final e in c.columns.entries) {
      final key = e.key.toLowerCase();
      final isPreferred = preferredKeys.any((k) => key.contains(k));
      if (!isPreferred) continue;
      final v = pickBest(e.value.toString());
      if (v == null) continue;
      if (bestPreferred == null || v > bestPreferred) bestPreferred = v;
    }

    return bestPreferred;
  }

  List<GradeCourse> _applyQuery(List<GradeCourse> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) => c.courseName.toLowerCase().contains(q)).toList();
  }

  // =========================
  // Page: disciplines
  // =========================

  Future<void> _openCapDialog() async {
    final controller = TextEditingController(text: _cap.toString());
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Кап баллов для “текущих”'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'например 50 или 60'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v == null) return;
              Navigator.pop(ctx, v.clamp(0, 200));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (res != null) {
      await _setCap(res);
    }
  }

  Widget _pageDisciplines() {
    final t = Theme.of(context).textTheme;

    final all = gradesRepo.courses;

    // нормализованные предметы из расписания
    final scheduleNorm = _scheduleSubjectsNorm();
    final scheduleBase = scheduleNorm.map(_normSubjectBase).toSet();

    // 1) Текущие по твоему правилу: есть в расписании И баллы < cap
    bool isCurrent(GradeCourse c) {
      // Текущие = есть в расписании И баллы меньше капа.
      final inSchedule = _inSchedule(
        c,
        scheduleNorm: scheduleNorm,
        scheduleBase: scheduleBase,
      );
      if (!inSchedule) return false;

      final pts = _extractPoints(c);

      // В начале семестра баллов может не быть: считаем такую дисциплину "текущей",
      // если она есть в расписании.
      if (pts == null) return true;

      return pts <= _cap;
    }

    final current = all.where(isCurrent).toList();

    // Если в "текущих" оказалось несколько частей одной дисциплины (ч.1/ч.2),
    // оставляем наиболее вероятно актуальную запись.
    final dedup = <String, GradeCourse>{};
    for (final c in current) {
      final key = _normSubjectBase(c.courseName);
      final prev = dedup[key];
      if (prev == null) {
        dedup[key] = c;
        continue;
      }

      final prevGrade = prev.grade?.trim() ?? '';
      final curGrade = c.grade?.trim() ?? '';
      final prevHasFinal =
          prevGrade.isNotEmpty && prevGrade != '—' && prevGrade != '-';
      final curHasFinal =
          curGrade.isNotEmpty && curGrade != '—' && curGrade != '-';

      if (prevHasFinal && !curHasFinal) {
        dedup[key] = c;
        continue;
      }
      if (!prevHasFinal && !curHasFinal) {
        final prevExact = scheduleNorm.contains(_normSubject(prev.courseName));
        final curExact = scheduleNorm.contains(_normSubject(c.courseName));
        if (!prevExact && curExact) {
          dedup[key] = c;
          continue;
        }
      }
      if (prevHasFinal == curHasFinal) {
        final prevPts = _extractPoints(prev) ?? 999;
        final curPts = _extractPoints(c) ?? 999;
        if (curPts < prevPts) {
          dedup[key] = c;
          continue;
        }
        if (curPts == prevPts) {
          final prevPart = _subjectPart(prev.courseName) ?? 0;
          final curPart = _subjectPart(c.courseName) ?? 0;
          if (curPart > prevPart) dedup[key] = c;
        }
      }
    }
    final currentUnique = dedup.values.toList();
    final others = all.where((c) => !currentUnique.contains(c)).toList();

    // Защита от пустоты: если текущих 0 (из-за несовпадений названий) —
    // делаем мягче: просто "есть в расписании"
    if (currentUnique.isEmpty && scheduleNorm.isNotEmpty) {
      final softCurrent = all
          .where(
            (c) => _inSchedule(
              c,
              scheduleNorm: scheduleNorm,
              scheduleBase: scheduleBase,
            ),
          )
          .toList();
      if (softCurrent.isNotEmpty) {
        currentUnique
          ..clear()
          ..addAll(softCurrent);
        others
          ..clear()
          ..addAll(all.where((c) => !softCurrent.contains(c)));
      }
    }

    final currentQ = _applyQuery(currentUnique);
    final othersQ = _applyQuery(others);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Поиск по дисциплинам',
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Text(
              'Текущие: кап $_cap',
              style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: _openCapDialog,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Изменить'),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (!gradesRepo.loading && all.isEmpty) ...[
          const SizedBox(height: 80),
          Center(
            child: Text(
              'Нет данных по дисциплинам',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ] else ...[
          if (currentQ.isNotEmpty) ...[
            Text(
              'Текущие',
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final c in currentQ)
              _CourseCard(
                course: c,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseGradeReportScreen(course: c),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
          if (othersQ.isNotEmpty) ...[
            Text(
              'Остальные',
              style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final c in othersQ)
              _CourseCard(
                course: c,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseGradeReportScreen(course: c),
                    ),
                  );
                },
              ),
          ],
        ],

        const SizedBox(height: 60),
      ],
    );
  }

  // =========================
  // Page: study plan (семестры)
  // =========================

  List<int> _availablePlanSemesters(List<StudyPlanItem> items) {
    final s = items.map((e) => e.semester).where((x) => x > 0).toSet().toList();
    s.sort();
    return s.isEmpty ? [1, 2, 3, 4, 5, 6, 7, 8] : s;
  }

  Widget _semesterChips({
    required List<int> semesters,
    required int selected,
    required ValueChanged<int> onSelect,
  }) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String label(int sem) {
      const map = {
        1: '1',
        2: '2',
        3: '3',
        4: '4',
        5: '5',
        6: '6',
        7: '7',
        8: '8',
      };
      return '${map[sem] ?? sem} сем';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 8,
        children: [
          for (final sem in semesters)
            ChoiceChip(
              label: Text(label(sem)),
              selected: sem == selected,
              showCheckmark: false,
              selectedColor: _gradesAccent(context),
              backgroundColor: isDark
                  ? const Color(0xFF252A34)
                  : const Color(0xFFE7EAF1),
              side: BorderSide(
                color: sem == selected
                    ? _gradesAccent(context)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.10)),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              labelStyle: t.labelLarge?.copyWith(
                color: sem == selected
                    ? Colors.white
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.96)
                          : cs.onSurface),
                fontWeight: FontWeight.w800,
              ),
              onSelected: (_) => onSelect(sem),
            ),
        ],
      ),
    );
  }

  Widget _pageStudyPlan() {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final items = planRepo.items;
    final semesters = _availablePlanSemesters(items);
    if (!semesters.contains(_planSemester)) {
      _planSemester = semesters.first;
    }

    final list = items.where((e) => e.semester == _planSemester).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (planRepo.updatedAt != null || planRepo.lastError != null) ...[
          Row(
            children: [
              Icon(
                planRepo.lastError != null
                    ? Icons.warning_amber_rounded
                    : Icons.sync,
                size: 18,
                color: planRepo.lastError != null
                    ? cs.error.withValues(alpha: 0.86)
                    : _gradesAccent(context).withValues(alpha: 0.86),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  planRepo.lastError != null
                      ? 'Не удалось обновить · показаны сохранённые данные'
                      : 'Обновлено: ${_fmtTime(planRepo.updatedAt!)}',
                  style: t.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        _semesterChips(
          semesters: semesters,
          selected: _planSemester,
          onSelect: (v) => setState(() => _planSemester = v),
        ),
        const SizedBox(height: 12),

        if (!planRepo.loading && items.isEmpty) ...[
          const SizedBox(height: 80),
          Center(
            child: Text(
              'Учебный план не найден в ЭИОС',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ] else ...[
          if (list.isEmpty && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Center(
                child: Text(
                  'В этом семестре нет строк',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            )
          else
            for (final it in list) _StudyPlanCard(item: it),
        ],

        const SizedBox(height: 60),
      ],
    );
  }

  // =========================
  // Page: recordbook (несколько зачёток + семестры)
  // =========================

  List<String> _gradebooks(List<RecordbookGradebook> gradebooks) {
    final s = gradebooks
        .map((e) => e.number)
        .where((x) => x.trim().isNotEmpty)
        .toSet()
        .toList();
    s.sort();
    return s;
  }

  List<int> _availableRecordSemesters(
    List<RecordbookGradebook> gradebooks,
    String gradebook,
  ) {
    final selected = gradebooks.where((g) => g.number == gradebook).toList();
    final s = selected
        .expand((g) => g.semesters)
        .map((e) => e.semester)
        .where((x) => x > 0)
        .toSet()
        .toList();
    s.sort();
    return s.isEmpty ? [1, 2, 3, 4, 5, 6, 7, 8] : s;
  }

  Widget _pageRecordbook() {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradebookData = recordRepo.gradebooks;
    final gradebooks = _gradebooks(gradebookData);

    if (_selectedGradebook == null && gradebooks.isNotEmpty) {
      _selectedGradebook = gradebooks.first;
    } else if (_selectedGradebook != null &&
        !gradebooks.contains(_selectedGradebook)) {
      _selectedGradebook = gradebooks.first;
    }

    final gb = _selectedGradebook;

    final semesters = gb == null
        ? <int>[1, 2, 3, 4, 5, 6, 7, 8]
        : _availableRecordSemesters(gradebookData, gb);
    if (!semesters.contains(_recordSemester)) {
      _recordSemester = semesters.first;
    }

    final selected = gb == null
        ? null
        : gradebookData.cast<RecordbookGradebook?>().firstWhere(
            (g) => g?.number == gb,
            orElse: () => null,
          );
    final visible = selected == null
        ? const <RecordbookRow>[]
        : selected.semesters
              .where((s) => s.semester == _recordSemester)
              .expand((s) => s.rows)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recordRepo.updatedAt != null || recordRepo.lastError != null) ...[
          Row(
            children: [
              Icon(
                recordRepo.lastError != null
                    ? Icons.warning_amber_rounded
                    : Icons.sync,
                size: 18,
                color: recordRepo.lastError != null
                    ? cs.error.withValues(alpha: 0.86)
                    : _gradesAccent(context).withValues(alpha: 0.86),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recordRepo.lastError != null
                      ? 'Не удалось обновить · показаны сохранённые данные'
                      : 'Обновлено: ${_fmtTime(recordRepo.updatedAt!)}',
                  style: t.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (gradebooks.length > 1) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(
              'gradebook-dd-${_selectedGradebook ?? ''}-${gradebooks.join('|')}',
            ),
            initialValue: _selectedGradebook,
            dropdownColor: isDark
                ? const Color(0xFF1A1E23)
                : const Color(0xFFFFFFFF),
            iconEnabledColor: isDark
                ? Colors.white.withValues(alpha: 0.86)
                : cs.onSurface.withValues(alpha: 0.86),
            style: t.bodyMedium?.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.94)
                  : cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
            items: [
              for (final g in gradebooks)
                DropdownMenuItem(value: g, child: Text('Зачётка № $g')),
            ],
            onChanged: (v) => setState(() {
              _selectedGradebook = v;
            }),
            decoration: InputDecoration(
              labelText: 'Выбор зачётки',
              labelStyle: t.bodyMedium?.copyWith(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.78)
                    : cs.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF1A1E23)
                  : const Color(0xFFFFFFFF),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.10),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _gradesAccent(context),
                  width: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else if (gradebooks.length == 1) ...[
          Text(
            'Зачётка № ${gradebooks.first}',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
        ],

        _semesterChips(
          semesters: semesters,
          selected: _recordSemester,
          onSelect: (v) => setState(() => _recordSemester = v),
        ),
        const SizedBox(height: 12),

        if (!recordRepo.loading && gradebookData.isEmpty) ...[
          const SizedBox(height: 80),
          Center(
            child: Text(
              'Зачётная книжка не найдена в ЭИОС',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ] else ...[
          if (visible.isEmpty && gradebookData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Center(
                child: Text(
                  'В этом семестре нет строк',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            )
          else
            for (final r in visible) _RecordbookCard(row: r),
        ],

        const SizedBox(height: 60),
      ],
    );
  }

  // =========================
  // refresh
  // =========================

  Future<void> _refreshSection(StudySection section) async {
    switch (section) {
      case StudySection.disciplines:
        await gradesRepo.refresh(force: true);
        await scheduleRepo.refresh(force: true);
        return;
      case StudySection.studyPlan:
        await planRepo.refresh(force: true);
        return;
      case StudySection.recordbook:
        await recordRepo.refresh(force: true);
        return;
    }
  }

  bool _isLoadingSection(StudySection section) {
    switch (section) {
      case StudySection.disciplines:
        return gradesRepo.loading || scheduleRepo.loading;
      case StudySection.studyPlan:
        return planRepo.loading;
      case StudySection.recordbook:
        return recordRepo.loading;
    }
  }

  bool _hasDataSection(StudySection section) {
    switch (section) {
      case StudySection.disciplines:
        return gradesRepo.courses.isNotEmpty;
      case StudySection.studyPlan:
        return planRepo.items.isNotEmpty;
      case StudySection.recordbook:
        return recordRepo.gradebooks.isNotEmpty;
    }
  }

  Widget _skeletonBlock(double h, {double radius = 14}) {
    return ShimmerSkeleton(
      width: double.infinity,
      height: h,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  Widget _sectionSkeleton(StudySection section) {
    switch (section) {
      case StudySection.disciplines:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _skeletonBlock(54),
            const SizedBox(height: 12),
            _skeletonBlock(18, radius: 8),
            const SizedBox(height: 10),
            for (var i = 0; i < 6; i++) ...[
              _skeletonBlock(104, radius: 18),
              const SizedBox(height: 10),
            ],
          ],
        );
      case StudySection.studyPlan:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _skeletonBlock(40, radius: 999),
            const SizedBox(height: 12),
            for (var i = 0; i < 8; i++) ...[
              _skeletonBlock(80, radius: 16),
              const SizedBox(height: 10),
            ],
          ],
        );
      case StudySection.recordbook:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _skeletonBlock(52),
            const SizedBox(height: 12),
            _skeletonBlock(40, radius: 999),
            const SizedBox(height: 12),
            for (var i = 0; i < 7; i++) ...[
              _skeletonBlock(84, radius: 16),
              const SizedBox(height: 10),
            ],
          ],
        );
    }
  }

  Widget _sectionPage(StudySection section, Widget child) {
    final isLoading = _isLoadingSection(section);
    final hasData = _hasDataSection(section);
    final showSkeleton = isLoading && !hasData;
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: showSkeleton
          ? KeyedSubtree(
              key: ValueKey('skeleton_${section.name}'),
              child: _sectionSkeleton(section),
            )
          : TweenAnimationBuilder<double>(
              key: ValueKey(
                'content_${section.name}_${isLoading ? 'loading' : 'ready'}',
              ),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, v, w) {
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, (1 - v) * 10),
                    child: w,
                  ),
                );
              },
              child: child,
            ),
    );

    return RefreshIndicator(
      onRefresh: () => _refreshSection(section),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 106),
        children: [
          if (isLoading) ...[
            const LoadingSkeletonStrip(),
            const SizedBox(height: 12),
          ],
          content,
        ],
      ),
    );
  }

  void _swipeSection(int dir) {
    if (dir == 0) return;
    final next = (_tabController.index + dir).clamp(0, 2);
    if (next == _tabController.index) return;
    _tabController.animateTo(next, duration: const Duration(milliseconds: 220));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        gradesRepo,
        scheduleRepo,
        planRepo,
        recordRepo,
      ]),
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _sectionTabs(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v.abs() < 250) return;
                      if (v < 0) {
                        _swipeSection(1);
                      } else {
                        _swipeSection(-1);
                      }
                    },
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        RepaintBoundary(
                          child: _sectionPage(
                            StudySection.disciplines,
                            KeyedSubtree(
                              key: const ValueKey('disciplines'),
                              child: _pageDisciplines(),
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: _sectionPage(
                            StudySection.studyPlan,
                            KeyedSubtree(
                              key: const ValueKey('study_plan'),
                              child: _pageStudyPlan(),
                            ),
                          ),
                        ),
                        RepaintBoundary(
                          child: _sectionPage(
                            StudySection.recordbook,
                            KeyedSubtree(
                              key: const ValueKey('recordbook'),
                              child: _pageRecordbook(),
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
}

// =========================
// Cards
// =========================
