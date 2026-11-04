import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../ui/app_haptics.dart';
import '../../../ui/app_theme.dart';
import '../../../ui/shimmer_skeleton.dart';
import '../../grades/models.dart';
import '../../grades/repository.dart';
import '../../profile/repository.dart';
import '../../recordbook/repository.dart';
import '../../schedule/schedule_repository.dart';
import '../../study_plan/repository.dart';

enum _GradesSection {
  grades, // "Оценки" (Master-Detail БРС)
  recordbook, // "Зачётка"
  studyPlan, // "Учебный план"
}

enum _FilterDisciplineMode {
  all, // Все
  withGrades, // С оценками
  withoutGrades, // Без оценок
}

class DesktopGradesView extends StatefulWidget {
  final void Function(int index) onNavigate;

  const DesktopGradesView({
    super.key,
    required this.onNavigate,
  });

  @override
  State<DesktopGradesView> createState() => _DesktopGradesViewState();
}

class _DesktopGradesViewState extends State<DesktopGradesView> {
  final gradesRepo = GradesRepository.instance;
  final scheduleRepo = ScheduleRepository.instance;
  final recordRepo = RecordbookRepository.instance;
  final planRepo = StudyPlanRepository.instance;

  _GradesSection _section = _GradesSection.grades;
  _FilterDisciplineMode _filterMode = _FilterDisciplineMode.all;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Выбранный курс для правой панели деталей
  GradeCourse? _selectedCourse;

  // In-memory кэш загруженных детальных отчетов по дисциплинам
  final Map<String, CourseGradeReport> _reportCache = {};
  final Set<String> _loadingCourses = {};
  final Map<String, Object> _reportErrors = {};

  // Выбранный семестр для Зачётки и Плана
  int _recordSemester = 1;
  int _planSemester = 1;

  @override
  void initState() {
    super.initState();
    gradesRepo.addListener(_onRepoChanged);
    scheduleRepo.addListener(_onRepoChanged);
    recordRepo.addListener(_onRepoChanged);
    planRepo.addListener(_onRepoChanged);

    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (text != _searchQuery) {
        setState(() => _searchQuery = text);
      }
    });

    _autoSelectFirstCourse();
  }

  @override
  void dispose() {
    gradesRepo.removeListener(_onRepoChanged);
    scheduleRepo.removeListener(_onRepoChanged);
    recordRepo.removeListener(_onRepoChanged);
    planRepo.removeListener(_onRepoChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) {
      setState(() {
        _autoSelectFirstCourse();
      });
    }
  }

  void _autoSelectFirstCourse() {
    final courses = _filteredCourses();
    if (courses.isNotEmpty) {
      if (_selectedCourse == null || !courses.any((c) => c.courseName == _selectedCourse!.courseName)) {
        _selectedCourse = courses.first;
        _preloadReport(courses.first);
      }
    }
  }

  void _preloadReport(GradeCourse course) {
    final key = course.courseName;
    if (_reportCache.containsKey(key) || _loadingCourses.contains(key)) return;

    _loadingCourses.add(key);
    gradesRepo.fetchCourseReport(course).then((report) {
      if (mounted) {
        setState(() {
          _reportCache[key] = report;
          _loadingCourses.remove(key);
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _reportErrors[key] = e;
          _loadingCourses.remove(key);
        });
      }
    });
  }

  String _cleanCourseName(String raw) {
    var s = raw.trim();
    s = s.replaceAll(
      RegExp(r'^\s*(?:од\s*\.?\s*\d*|дисциплина\s*:?|дисц\s*\.?)\s*', caseSensitive: false),
      '',
    );
    s = s.replaceAll('_', ' ');
    s = s.replaceAll(RegExp(r'\(.*?недел.*?\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\b\d+\s*/\s*\d+(?:\s*/\s*\d+)?\b'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double? _parseNum(String? raw) {
    if (raw == null) return null;
    final s = raw.replaceAll(' ', '').replaceAll(',', '.');
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  double? _parseScore(GradeCourse c) {
    final g = c.grade;
    if (g != null && g.isNotEmpty && g != '—' && g != '-') {
      final parsed = _parseNum(g);
      if (parsed != null) return parsed;
    }
    final p = c.percent;
    if (p != null) {
      final parsed = _parseNum(p);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String? _resolveTeacher(String courseName) {
    final cleanC = _cleanCourseName(courseName).toLowerCase();
    for (final l in scheduleRepo.lessons) {
      if (l.teacher.trim().isNotEmpty) {
        final cleanL = _cleanCourseName(l.subject).toLowerCase();
        if (cleanC.contains(cleanL) || cleanL.contains(cleanC)) {
          return l.teacher.trim();
        }
      }
    }
    return null;
  }

  List<GradeCourse> _filteredCourses() {
    var list = gradesRepo.courses;

    if (_filterMode == _FilterDisciplineMode.withGrades) {
      list = list.where((c) {
        final s = _parseScore(c);
        return s != null && s > 0;
      }).toList();
    } else if (_filterMode == _FilterDisciplineMode.withoutGrades) {
      list = list.where((c) {
        final s = _parseScore(c);
        return s == null || s == 0;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        final name = _cleanCourseName(c.courseName).toLowerCase();
        final teacher = (_resolveTeacher(c.courseName) ?? '').toLowerCase();
        return name.contains(q) || teacher.contains(q);
      }).toList();
    }

    return list;
  }

  void _onCourseTap(GradeCourse course) {
    AppHaptics.selectionClick();
    setState(() {
      _selectedCourse = course;
    });
    _preloadReport(course);
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

    final profile = ProfileRepository.instance.profile;
    final groupName = profile?.group ?? 'ИС-21';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // 1. ВЕРХНИЙ ТУЛБАР (Сегменты + Фильтры)
          // ==========================================
          Row(
            children: [
              // Сегмент-переключатель: Оценки | Зачётка | Учебный план
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181C26) : const Color(0xFFEAEFF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SegmentTab(
                      label: 'Оценки',
                      icon: Icons.school_outlined,
                      selected: _section == _GradesSection.grades,
                      accent: accent,
                      onTap: () {
                        AppHaptics.selectionClick();
                        setState(() => _section = _GradesSection.grades);
                      },
                    ),
                    const SizedBox(width: 4),
                    _SegmentTab(
                      label: 'Зачётка',
                      icon: Icons.auto_stories_outlined,
                      selected: _section == _GradesSection.recordbook,
                      accent: accent,
                      onTap: () {
                        AppHaptics.selectionClick();
                        setState(() => _section = _GradesSection.recordbook);
                      },
                    ),
                    const SizedBox(width: 4),
                    _SegmentTab(
                      label: 'Учебный план',
                      icon: Icons.list_alt_rounded,
                      selected: _section == _GradesSection.studyPlan,
                      accent: accent,
                      onTap: () {
                        AppHaptics.selectionClick();
                        setState(() => _section = _GradesSection.studyPlan);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Дополнительные контролы в зависимости от выбранного раздела
              if (_section == _GradesSection.grades) ...[
                // Селектор семестра
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
                      Icon(Icons.calendar_month_outlined, size: 15, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        '1 семестр',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

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
                      Icon(Icons.group_outlined, size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        groupName,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Фильтр: Все / С оценками / Без оценок
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181C26) : const Color(0xFFF1F4FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_FilterDisciplineMode>(
                      value: _filterMode,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: cs.onSurfaceVariant),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      dropdownColor: isDark ? const Color(0xFF181C26) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      items: const [
                        DropdownMenuItem(
                          value: _FilterDisciplineMode.all,
                          child: Text('Все дисциплины'),
                        ),
                        DropdownMenuItem(
                          value: _FilterDisciplineMode.withGrades,
                          child: Text('С баллами'),
                        ),
                        DropdownMenuItem(
                          value: _FilterDisciplineMode.withoutGrades,
                          child: Text('Без баллов'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          AppHaptics.selectionClick();
                          setState(() {
                            _filterMode = val;
                            _autoSelectFirstCourse();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Строка живого поиска
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181C26) : const Color(0xFFF1F4FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Поиск по дисциплинам...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 2. ОСНОВНОЙ КОНТЕНТ (В ЗАВИСИМОСТИ ОТ ВКЛАДКИ)
          // ==========================================
          if (_section == _GradesSection.grades)
            _buildMasterDetailGrades(
              cardBg: cardBg,
              borderColor: borderColor,
              accent: accent,
              isDark: isDark,
            )
          else if (_section == _GradesSection.recordbook)
            _buildRecordbookDesktop(
              cardBg: cardBg,
              borderColor: borderColor,
              accent: accent,
              isDark: isDark,
            )
          else
            _buildStudyPlanDesktop(
              cardBg: cardBg,
              borderColor: borderColor,
              accent: accent,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // ВЕРСТКА: ДВУХКОЛОНОЧНЫЙ MASTER-DETAIL (ОЦЕНКИ БРС)
  // ==========================================================
  Widget _buildMasterDetailGrades({
    required Color cardBg,
    required Color borderColor,
    required Color accent,
    required bool isDark,
  }) {
    final courses = _filteredCourses();
    final cs = Theme.of(context).colorScheme;

    if (courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Дисциплины не найдены',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'Попробуйте изменить поисковый запрос или фильтр',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final activeCourse = _selectedCourse != null && courses.any((c) => c.courseName == _selectedCourse!.courseName)
        ? _selectedCourse!
        : courses.first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ЛЕВАЯ ПАНЕЛЬ: СЕТКА КАРТОЧЕК ДИСЦИПЛИН (62% ширины)
        Expanded(
          flex: 62,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 520;
              final crossAxisCount = useTwoColumns ? 2 : 1;
              const spacing = 12.0;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  mainAxisExtent: 96,
                ),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  final isSelected = course.courseName == activeCourse.courseName;
                  final score = _parseScore(course);
                  final teacher = _resolveTeacher(course.courseName) ?? 'Преподаватель не указан';

                  return _DesktopDisciplineCard(
                    course: course,
                    cleanTitle: _cleanCourseName(course.courseName),
                    teacher: teacher,
                    score: score,
                    isSelected: isSelected,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    accent: accent,
                    isDark: isDark,
                    onTap: () => _onCourseTap(course),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(width: 20),

        // ПРАВАЯ ПАНЕЛЬ: ДЕТАЛИ ВЫБРАННОЙ ДИСЦИПЛИНЫ (38% ширины)
        Expanded(
          flex: 38,
          child: _DesktopCourseDetailPane(
            course: activeCourse,
            cleanTitle: _cleanCourseName(activeCourse.courseName),
            teacher: _resolveTeacher(activeCourse.courseName) ?? 'Преподаватель не указан',
            score: _parseScore(activeCourse),
            report: _reportCache[activeCourse.courseName],
            isLoading: _loadingCourses.contains(activeCourse.courseName),
            error: _reportErrors[activeCourse.courseName],
            cardBg: cardBg,
            borderColor: borderColor,
            accent: accent,
            isDark: isDark,
            onRetry: () => _preloadReport(activeCourse),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // ВЕРСТКА: ЗАЧЁТНАЯ КНИЖКА (ДЕСКТОП)
  // ==========================================================
  Widget _buildRecordbookDesktop({
    required Color cardBg,
    required Color borderColor,
    required Color accent,
    required bool isDark,
  }) {
    final gradebooks = recordRepo.gradebooks;
    final cs = Theme.of(context).colorScheme;

    if (gradebooks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.auto_stories_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Зачётная книжка загружается...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
          ],
        ),
      );
    }

    final gb = gradebooks.first;
    final availableSemesters = gb.semesters.map((s) => s.semester).toSet().toList()..sort();
    if (!availableSemesters.contains(_recordSemester) && availableSemesters.isNotEmpty) {
      _recordSemester = availableSemesters.first;
    }

    final currentSemester = gb.semesters.firstWhere(
      (s) => s.semester == _recordSemester,
      orElse: () => gb.semesters.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableSemesters.map((semNum) {
              final isSel = semNum == _recordSemester;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$semNum семестр'),
                  selected: isSel,
                  onSelected: (_) {
                    AppHaptics.selectionClick();
                    setState(() => _recordSemester = semNum);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 88,
          ),
          itemCount: currentSemester.rows.length,
          itemBuilder: (context, index) {
            final item = currentSemester.rows[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.discipline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.controlType}${item.teacher.isNotEmpty ? ' • ${item.teacher}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.mark,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================================
  // ВЕРСТКА: УЧЕБНЫЙ ПЛАН (ДЕСКТОП)
  // ==========================================================
  Widget _buildStudyPlanDesktop({
    required Color cardBg,
    required Color borderColor,
    required Color accent,
    required bool isDark,
  }) {
    final items = planRepo.items;
    final cs = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.list_alt_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'Учебный план загружается...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
          ],
        ),
      );
    }

    final availableSemesters = items.map((d) => d.semester).toSet().toList()..sort();
    if (!availableSemesters.contains(_planSemester) && availableSemesters.isNotEmpty) {
      _planSemester = availableSemesters.first;
    }

    final disciplines = items.where((d) => d.semester == _planSemester).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableSemesters.map((s) {
              final isSel = s == _planSemester;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$s семестр'),
                  selected: isSel,
                  onSelected: (_) {
                    AppHaptics.selectionClick();
                    setState(() => _planSemester = s);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 88,
          ),
          itemCount: disciplines.length,
          itemBuilder: (context, index) {
            final disc = disciplines[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          disc.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${disc.control} • ${disc.totalHours} ч',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ==========================================================
// КОМПОНЕНТ: КАРТОЧКА ДИСЦИПЛИНЫ В ЛЕВОЙ ПАНЕЛИ
// ==========================================================
class _DesktopDisciplineCard extends StatefulWidget {
  final GradeCourse course;
  final String cleanTitle;
  final String teacher;
  final double? score;
  final bool isSelected;
  final Color cardBg;
  final Color borderColor;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _DesktopDisciplineCard({
    required this.course,
    required this.cleanTitle,
    required this.teacher,
    required this.score,
    required this.isSelected,
    required this.cardBg,
    required this.borderColor,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_DesktopDisciplineCard> createState() => _DesktopDisciplineCardState();
}

class _DesktopDisciplineCardState extends State<_DesktopDisciplineCard> {
  bool _hovered = false;

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scoreVal = widget.score ?? 0.0;
    final scoreText = widget.score != null ? '${_fmt(widget.score!)} / 100' : '— / 100';
    final progress = (scoreVal / 100.0).clamp(0.0, 1.0);

    const greenAccent = Color(0xFF34D399);
    final indicatorColor = widget.score != null && widget.score! > 0
        ? greenAccent
        : cs.onSurfaceVariant.withValues(alpha: 0.3);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: widget.isDark
              ? (widget.isSelected
                  ? const Color(0xFF1E2232)
                  : (_hovered ? const Color(0xFF1A1D2B) : const Color(0xFF141722)))
              : (widget.isSelected
                  ? const Color(0xFFF0F4FF)
                  : (_hovered ? const Color(0xFFF7F9FD) : Colors.white)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? widget.accent
                : (_hovered ? widget.accent.withValues(alpha: 0.45) : widget.borderColor),
            width: widget.isSelected ? 1.6 : 1.0,
          ),
          boxShadow: [
            if (widget.isSelected)
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 3),
              )
            else if (_hovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Row(
              children: [
                if (!widget.isSelected)
                  Container(
                    width: 4,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.cleanTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: widget.isDark ? Colors.white : const Color(0xFF1A1F2C),
                          ),
                        ),

                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.teacher,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: greenAccent.withValues(alpha: widget.isDark ? 0.16 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                scoreText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: widget.score != null && widget.score! > 0
                                      ? greenAccent
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ],
                        ),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 6,
                            color: widget.isDark
                                ? const Color(0xFF232838)
                                : const Color(0xFFE5E7EB),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// КОМПОНЕНТ: ПРАВАЯ ПАНЕЛЬ ДЕТАЛЕЙ ДИСЦИПЛИНЫ
// ==========================================================
class _DesktopCourseDetailPane extends StatelessWidget {
  final GradeCourse course;
  final String cleanTitle;
  final String teacher;
  final double? score;
  final CourseGradeReport? report;
  final bool isLoading;
  final Object? error;
  final Color cardBg;
  final Color borderColor;
  final Color accent;
  final bool isDark;
  final VoidCallback onRetry;

  const _DesktopCourseDetailPane({
    required this.course,
    required this.cleanTitle,
    required this.teacher,
    required this.score,
    required this.report,
    required this.isLoading,
    required this.error,
    required this.cardBg,
    required this.borderColor,
    required this.accent,
    required this.isDark,
    required this.onRetry,
  });

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scoreVal = score ?? 0.0;
    final scoreText = score != null ? '${_fmt(score!)} / 100' : '— / 100';
    final progress = (scoreVal / 100.0).clamp(0.0, 1.0);
    const greenAccent = Color(0xFF34D399);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF1A1F2C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 15,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            teacher,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (course.courseUrl != null && course.courseUrl!.isNotEmpty)
                IconButton(
                  tooltip: 'Открыть в ЭИОС',
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  onPressed: () async {
                    AppHaptics.lightImpact();
                    final uri = Uri.tryParse(course.courseUrl!);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Баллы (БРС)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                scoreText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: score != null && score! > 0 ? greenAccent : cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 10,
              color: isDark ? const Color(0xFF232838) : const Color(0xFFE5E7EB),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          Divider(color: borderColor, height: 1),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.article_outlined, size: 17, color: accent),
              const SizedBox(width: 8),
              Text(
                'Детали по дисциплине',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isLoading) ...[
            for (int i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ShimmerSkeleton(
                  height: 38,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ] else if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1E26) : const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Text(
                    'Не удалось загрузить подробные баллы',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Повторить', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ] else if (report == null || report!.rows.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Text(
                'Преподаватель ещё не выставил отдельные контрольные точки',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
              ),
            ),
          ] else ...[
            Builder(
              builder: (context) {
                final displayItems = report!.rows.where((r) {
                  if (r.type == GradeReportRowType.course) return false;
                  final tLower = r.title.toLowerCase();
                  if (tLower.contains('итоговая оценка за курс') || tLower.contains('всего за курс')) {
                    return false;
                  }
                  return true;
                }).toList();

                if (displayItems.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    alignment: Alignment.center,
                    child: Text(
                      'Нет отдельных контрольных точек',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  );
                }

                return Column(
                  children: displayItems.map((item) {
                    final isCategory = item.type == GradeReportRowType.category;
                    final g = item.grade.trim();
                    final hasGrade = g.isNotEmpty && g != '-' && g != '—';

                    if (isCategory) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              item.title.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF181B26) : const Color(0xFFF7F9FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasGrade ? g : 'Ожидает',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: hasGrade ? greenAccent : cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================================
// КОМПОНЕНТ: СЕГМЕНТ ТАБА В ТУЛБАРЕ
// ==========================================================
class _SegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: accent.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? Colors.white
                  : (isDark ? cs.onSurfaceVariant : const Color(0xFF555B6D)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? cs.onSurface : const Color(0xFF2D313F)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
