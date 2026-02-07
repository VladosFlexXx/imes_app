import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../grades/models.dart';
import '../grades/repository.dart';
import '../schedule/schedule_repository.dart';

import '../recordbook/repository.dart';
import '../recordbook/models.dart';

import '../study_plan/repository.dart';
import '../study_plan/models.dart';

enum StudySection { disciplines, studyPlan, recordbook }

class GradesTab extends StatefulWidget {
  const GradesTab({super.key});

  @override
  State<GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<GradesTab> {
  final gradesRepo = GradesRepository.instance;
  final scheduleRepo = ScheduleRepository.instance;

  final planRepo = StudyPlanRepository.instance;
  final recordRepo = RecordbookRepository.instance;

  StudySection _section = StudySection.disciplines;

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

    gradesRepo.initAndRefresh();
    scheduleRepo.initAndRefresh();

    planRepo.initAndRefresh();
    recordRepo.initAndRefresh();

    _loadCap();
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
  // Switch chips
  // =========================

  Widget _sectionSwitch() {
    Widget chip(StudySection s, String label, IconData icon) {
      final selected = _section == s;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) => setState(() => _section = s),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 8,
        children: [
          chip(StudySection.disciplines, 'Дисциплины', Icons.menu_book_outlined),
          chip(StudySection.studyPlan, 'Учебный план', Icons.view_list_outlined),
          chip(StudySection.recordbook, 'Зачётка', Icons.fact_check_outlined),
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
    x = x.replaceAll(RegExp(r'^\s*(од\.|дисциплина:|дисц\.)\s*', caseSensitive: false), '');

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
          decoration: const InputDecoration(
            hintText: 'например 50 или 60',
          ),
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
      final prevHasFinal = prevGrade.isNotEmpty && prevGrade != '—' && prevGrade != '-';
      final curHasFinal = curGrade.isNotEmpty && curGrade != '—' && curGrade != '-';

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
            Text('Текущие', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final c in currentQ) _CourseCard(course: c, onTap: () {}),
            const SizedBox(height: 12),
          ],
          if (othersQ.isNotEmpty) ...[
            Text('Остальные', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final c in othersQ) _CourseCard(course: c, onTap: () {}),
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
                planRepo.lastError != null ? Icons.warning_amber_rounded : Icons.sync,
                size: 18,
                color: planRepo.lastError != null
                    ? cs.error.withValues(alpha: 0.86)
                    : cs.primary.withValues(alpha: 0.86),
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
    final s = gradebooks.map((e) => e.number).where((x) => x.trim().isNotEmpty).toSet().toList();
    s.sort();
    return s;
  }

  List<int> _availableRecordSemesters(List<RecordbookGradebook> gradebooks, String gradebook) {
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

    final gradebookData = recordRepo.gradebooks;
    final gradebooks = _gradebooks(gradebookData);

    if (_selectedGradebook == null && gradebooks.isNotEmpty) {
      _selectedGradebook = gradebooks.first;
    } else if (_selectedGradebook != null &&
        !gradebooks.contains(_selectedGradebook)) {
      _selectedGradebook = gradebooks.first;
    }

    final gb = _selectedGradebook;

    final semesters =
        gb == null ? <int>[1, 2, 3, 4, 5, 6, 7, 8] : _availableRecordSemesters(gradebookData, gb);
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
                recordRepo.lastError != null ? Icons.warning_amber_rounded : Icons.sync,
                size: 18,
                color: recordRepo.lastError != null
                    ? cs.error.withValues(alpha: 0.86)
                    : cs.primary.withValues(alpha: 0.86),
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
            key: ValueKey('gradebook-dd-${_selectedGradebook ?? ''}-${gradebooks.join('|')}'),
            initialValue: _selectedGradebook,
            items: [
              for (final g in gradebooks)
                DropdownMenuItem(value: g, child: Text('Зачётка № $g')),
            ],
            onChanged: (v) => setState(() {
              _selectedGradebook = v;
            }),
            decoration: const InputDecoration(
              labelText: 'Выбор зачётки',
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

  Future<void> _refreshCurrent() async {
    switch (_section) {
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

  bool _isLoadingCurrent() {
    switch (_section) {
      case StudySection.disciplines:
        return gradesRepo.loading || scheduleRepo.loading;
      case StudySection.studyPlan:
        return planRepo.loading;
      case StudySection.recordbook:
        return recordRepo.loading;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([gradesRepo, scheduleRepo, planRepo, recordRepo]),
      builder: (context, _) {
        final title = switch (_section) {
          StudySection.disciplines => 'Дисциплины',
          StudySection.studyPlan => 'Учебный план',
          StudySection.recordbook => 'Зачётная книжка',
        };

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            bottom: _isLoadingCurrent()
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Обновить',
                onPressed: _isLoadingCurrent() ? null : () => _refreshCurrent(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshCurrent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                _sectionSwitch(),
                const SizedBox(height: 12),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: () {
                    switch (_section) {
                      case StudySection.disciplines:
                        return KeyedSubtree(
                          key: const ValueKey('disciplines'),
                          child: _pageDisciplines(),
                        );
                      case StudySection.studyPlan:
                        return KeyedSubtree(
                          key: const ValueKey('study_plan'),
                          child: _pageStudyPlan(),
                        );
                      case StudySection.recordbook:
                        return KeyedSubtree(
                          key: const ValueKey('recordbook'),
                          child: _pageRecordbook(),
                        );
                    }
                  }(),
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

class _CourseCard extends StatelessWidget {
  final GradeCourse course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  bool _hasGrade() {
    final g = course.grade;
    return g != null && g.trim().isNotEmpty && g.trim() != '—' && g.trim() != '-';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final any = _hasGrade();
    final grade = course.grade?.trim();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    course.courseName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                if (any && grade != null)
                  _Badge(text: grade)
                else
                  Text('—', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyPlanCard extends StatelessWidget {
  final StudyPlanItem item;

  const _StudyPlanCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final chips = <Widget>[];

    if (item.control.trim().isNotEmpty) {
      chips.add(_Chip(text: item.control.trim()));
    }
    if (item.code.trim().isNotEmpty) {
      chips.add(_Chip(text: item.code.trim()));
    }
    if (item.totalHours.trim().isNotEmpty) {
      chips.add(_Chip(text: '${item.totalHours.trim()} ч'));
    }
    if (item.lectures.trim().isNotEmpty && item.lectures.trim() != '0') {
      chips.add(_Chip(text: 'Лек: ${item.lectures.trim()}'));
    }
    if (item.practices.trim().isNotEmpty && item.practices.trim() != '0') {
      chips.add(_Chip(text: 'Практ: ${item.practices.trim()}'));
    }
    if (item.selfWork.trim().isNotEmpty && item.selfWork.trim() != '0') {
      chips.add(_Chip(text: 'СРС: ${item.selfWork.trim()}'));
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (chips.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordbookCard extends StatelessWidget {
  final RecordbookRow row;

  const _RecordbookCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final chips = <Widget>[];
    if (row.controlType.trim().isNotEmpty) chips.add(_Chip(text: row.controlType.trim()));
    if (row.date.trim().isNotEmpty) chips.add(_Chip(text: row.date.trim()));
    if (row.mark.trim().isNotEmpty) chips.add(_Chip(text: row.mark.trim()));
    if (row.retake.trim().isNotEmpty) chips.add(_Chip(text: 'Пересдача: ${row.retake.trim()}'));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.discipline,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (chips.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: chips),
              if (row.teacher.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  row.teacher.trim(),
                  style: t.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =========================
// UI helpers
// =========================

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  double? _scoreRaw(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized);
  }

  double? _scorePercent(String value) {
    final raw = _scoreRaw(value);
    if (raw == null) return null;
    if (raw <= 5.0) return (raw / 5.0) * 100.0;
    if (raw <= 100.0) return raw;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = _scorePercent(text);

    final bool hasScore = p != null;
    final bool low = hasScore && p < 45;
    final bool mid = hasScore && p >= 45 && p < 75;

    final bg = !hasScore
        ? cs.primaryContainer
        : (low
            ? cs.primary.withValues(alpha: 0.16)
            : (mid
                ? cs.primary.withValues(alpha: 0.24)
                : cs.primary.withValues(alpha: 0.34)));
    final fg = !hasScore ? cs.onPrimaryContainer : cs.primary;
    final borderColor = !hasScore
        ? cs.onPrimaryContainer.withValues(alpha: 0.12)
        : cs.primary.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: fg,
              height: 1.0,
            ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
