import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../ui/app_haptics.dart';
import '../../ui/app_theme.dart';
import '../../ui/shimmer_skeleton.dart';

import 'models.dart';
import 'repository.dart';

class CourseGradeReportScreen extends StatefulWidget {
  final GradeCourse course;

  const CourseGradeReportScreen({super.key, required this.course});

  @override
  State<CourseGradeReportScreen> createState() =>
      _CourseGradeReportScreenState();
}

class _CourseGradeReportScreenState extends State<CourseGradeReportScreen> {
  final _repo = GradesRepository.instance;
  CourseGradeReport? _report;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _repo.fetchCourseReport(widget.course);
      if (!mounted) return;
      setState(() => _report = report);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanCourseName(String raw) {
    var s = raw.trim();
    // Убираем префиксы типа "ОД.01", "дисциплина:"
    s = s.replaceAll(
      RegExp(r'^\s*(?:од\s*\.?\s*\d*|дисциплина\s*:?|дисц\s*\.?)\s*', caseSensitive: false),
      '',
    );
    s = s.replaceAll('_', ' ');
    // Убираем скобки типа (нечетная неделя)
    s = s.replaceAll(RegExp(r'\(.*?недел.*?\)', caseSensitive: false), '');
    // Убираем форматы часов типа 28/14/14
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

  double? _extractMax(String title, {String? subtitle}) {
    if (subtitle != null && subtitle.isNotEmpty) {
      final rangeMatch = RegExp(r'(?:0|от\s*0)\s*[-–—]\s*(\d+(?:[.,]\d+)?)').firstMatch(subtitle);
      if (rangeMatch != null) return _parseNum(rangeMatch.group(1));
    }
    final patterns = [
      RegExp(r'максимум\s+можно\s+набрать\s+(\d+(?:[.,]\d+)?)', caseSensitive: false),
      RegExp(r'макс(?:имум)?\.?\s*[:=]?\s*(\d+(?:[.,]\d+)?)', caseSensitive: false),
      RegExp(r'из\s+(\d+(?:[.,]\d+)?)', caseSensitive: false),
      RegExp(r'\(.*?(\d+(?:[.,]\d+)?)\s*б(?:алл(?:а|ов)?)?\)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(title);
      if (m != null) return _parseNum(m.group(1));
    }
    return null;
  }

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  IconData _categoryIcon(String title) {
    final l = title.toLowerCase();
    if (l.contains('тест') || l.contains('квиз') || l.contains('опрос')) {
      return Icons.quiz_outlined;
    }
    if (l.contains('практик') || l.contains('семинар') || l.contains('кейс') || l.contains('лаб')) {
      return Icons.assignment_outlined;
    }
    if (l.contains('посещаем') || l.contains('активност')) {
      return Icons.how_to_reg_outlined;
    }
    if (l.contains('экзамен') || l.contains('зачет') || l.contains('аттестац')) {
      return Icons.school_outlined;
    }
    if (l.contains('контр') || l.contains('точка')) {
      return Icons.track_changes_outlined;
    }
    return Icons.folder_outlined;
  }

  ({String label, String status, Color color, IconData icon}) _brsStatus(
    BuildContext context,
    double score,
    double max,
  ) {
    final pct = max > 0 ? (score / max) * 100 : score;
    if (pct >= 85) {
      return (
        label: 'Отлично / Автомат (5)',
        status: 'Максимальный уровень',
        color: const Color(0xFF00C853),
        icon: Icons.verified_rounded,
      );
    } else if (pct >= 70) {
      return (
        label: 'Хорошо (4)',
        status: 'Уверенный результат',
        color: const Color(0xFF2979FF),
        icon: Icons.thumb_up_alt_rounded,
      );
    } else if (pct >= 50) {
      return (
        label: 'Зачётный минимум (3)',
        status: 'Допуск к зачёту',
        color: const Color(0xFFFFA000),
        icon: Icons.check_circle_outline_rounded,
      );
    } else {
      return (
        label: 'Накопление баллов',
        status: 'Семестр в процессе',
        color: appAccentOf(context),
        icon: Icons.trending_up_rounded,
      );
    }
  }

  _BrsCourseAnalytics _analyzeReport(CourseGradeReport report) {
    final categories = <_BrsCategory>[];
    final standalone = <GradeReportRow>[];

    String? currentCatTitle;
    double? currentCatScore;
    double? currentCatMax;
    final currentCatItems = <GradeReportRow>[];

    double? explicitCourseTotal;
    double? explicitCourseMax;

    for (final row in report.rows) {
      final tLower = row.title.toLowerCase();
      final isCourseTotal = row.type == GradeReportRowType.aggregate &&
          (tLower.contains('курса') ||
              tLower.contains('итоговая оценка за курс') ||
              tLower.contains('всего за курс'));

      if (isCourseTotal) {
        explicitCourseTotal = _parseNum(row.grade);
        explicitCourseMax =
            _extractMax(row.title, subtitle: row.subtitle) ?? 100.0;
        continue;
      }

      if (row.type == GradeReportRowType.category) {
        if (currentCatTitle != null) {
          final catScore = currentCatScore ??
              currentCatItems.fold<double>(
                0.0,
                (sum, it) => sum + (_parseNum(it.grade) ?? 0.0),
              );
          final catMax = currentCatMax ??
              currentCatItems.fold<double>(
                0.0,
                (sum, it) =>
                    sum +
                    (_extractMax(it.title, subtitle: it.subtitle) ?? 0.0),
              );
          categories.add(
            _BrsCategory(
              title: currentCatTitle,
              score: catScore,
              max: catMax > 0 ? catMax : (catScore > 0 ? catScore : 20.0),
              items: List.from(currentCatItems),
            ),
          );
          currentCatItems.clear();
          currentCatScore = null;
          currentCatMax = null;
        }
        currentCatTitle = row.title;
        currentCatMax = _extractMax(row.title, subtitle: row.subtitle);
      } else if (row.type == GradeReportRowType.aggregate) {
        currentCatScore = _parseNum(row.grade);
        final m = _extractMax(row.title, subtitle: row.subtitle);
        if (m != null) currentCatMax = m;
      } else if (row.type == GradeReportRowType.item) {
        if (currentCatTitle != null) {
          currentCatItems.add(row);
        } else {
          standalone.add(row);
        }
      }
    }

    if (currentCatTitle != null) {
      final catScore = currentCatScore ??
          currentCatItems.fold<double>(
            0.0,
            (sum, it) => sum + (_parseNum(it.grade) ?? 0.0),
          );
      final catMax = currentCatMax ??
          currentCatItems.fold<double>(
            0.0,
            (sum, it) =>
                sum + (_extractMax(it.title, subtitle: it.subtitle) ?? 0.0),
          );
      categories.add(
        _BrsCategory(
          title: currentCatTitle,
          score: catScore,
          max: catMax > 0 ? catMax : (catScore > 0 ? catScore : 20.0),
          items: List.from(currentCatItems),
        ),
      );
    }

    if (categories.isEmpty && standalone.isNotEmpty) {
      final sumScore = standalone.fold<double>(
        0.0,
        (sum, it) => sum + (_parseNum(it.grade) ?? 0.0),
      );
      final sumMax = standalone.fold<double>(
        0.0,
        (sum, it) =>
            sum + (_extractMax(it.title, subtitle: it.subtitle) ?? 0.0),
      );
      categories.add(
        _BrsCategory(
          title: 'Контрольные точки',
          score: sumScore,
          max: sumMax > 0 ? sumMax : 100.0,
          items: List.from(standalone),
        ),
      );
      standalone.clear();
    }

    final calcTotal = categories.fold<double>(0.0, (sum, c) => sum + c.score);
    final calcMax = categories.fold<double>(0.0, (sum, c) => sum + c.max);

    final totalScore = explicitCourseTotal ?? calcTotal;
    final totalMax = (explicitCourseMax != null && explicitCourseMax > 0)
        ? explicitCourseMax
        : (calcMax > 0 ? calcMax : 100.0);

    return _BrsCourseAnalytics(
      totalScore: totalScore,
      totalMax: totalMax,
      categories: categories,
      standaloneItems: standalone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final report = _report;
    final analytics = report == null ? null : _analyzeReport(report);
    final cleanName = _cleanCourseName(widget.course.courseName);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          cleanName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.course.courseUrl != null &&
              widget.course.courseUrl!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: 'Открыть в ЭИОС',
              onPressed: () {
                AppHaptics.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _GradeActivityWebViewScreen(
                      title: cleanName,
                      url: widget.course.courseUrl!,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Loading skeleton
            if (_loading) ...[
              _buildSkeleton(context, isDark),
            ] else if (_error != null) ...[
              _buildErrorCard(context, isDark),
            ] else if (analytics != null) ...[
              // Hero Summary Card
              _buildHeroCard(context, analytics, theme, isDark),
              const SizedBox(height: 20),

              // Categories Header
              Text(
                'СТРУКТУРА БАЛЛОВ (БРС)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.black.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 10),

              if (analytics.categories.isEmpty &&
                  analytics.standaloneItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: isDark
                        ? const Color(0xFF1A1E23)
                        : const Color(0xFFF1F3F7),
                  ),
                  child: Center(
                    child: Text(
                      'Пока нет подробных данных по баллам этого предмета.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                )
              else ...[
                for (final cat in analytics.categories)
                  _buildCategoryCard(context, cat, theme, isDark),
                for (final it in analytics.standaloneItems)
                  _buildSingleItemCard(context, it, theme, isDark),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    _BrsCourseAnalytics a,
    ThemeData theme,
    bool isDark,
  ) {
    final status = _brsStatus(context, a.totalScore, a.totalMax);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E232B), Color(0xFF15181E)]
              : const [Color(0xFFFFFFFF), Color(0xFFF3F5F9)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: status.color.withValues(alpha: isDark ? 0.16 : 0.12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, size: 16, color: status.color),
                    const SizedBox(width: 6),
                    Text(
                      status.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                status.status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Score row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmt(a.totalScore),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1B1F26),
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ ${_fmt(a.totalMax)} б.',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              Text(
                '${(a.progress * 100).round()}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: status.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              FractionallySizedBox(
                widthFactor: a.progress,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        status.color.withValues(alpha: 0.7),
                        status.color,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Milestones
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              Text(
                '50 (зачёт)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFA000),
                ),
              ),
              Text(
                '70 (4)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2979FF),
                ),
              ),
              Text(
                '85 (5)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF00C853),
                ),
              ),
              Text(
                '100',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    _BrsCategory cat,
    ThemeData theme,
    bool isDark,
  ) {
    final pct = cat.max > 0 ? (cat.score / cat.max).clamp(0.0, 1.0) : 0.0;
    final icon = _categoryIcon(cat.title);
    final accent = appAccentOf(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1A1E23) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cat.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: (pct >= 0.7
                            ? const Color(0xFF00C853)
                            : (pct >= 0.5
                                ? const Color(0xFFFFA000)
                                : accent))
                        .withValues(alpha: isDark ? 0.20 : 0.12),
                  ),
                  child: Text(
                    '${_fmt(cat.score)} / ${_fmt(cat.max)} б.',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: pct >= 0.7
                          ? const Color(0xFF00C853)
                          : (pct >= 0.5 ? const Color(0xFFFFA000) : accent),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Category progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  pct >= 0.85
                      ? const Color(0xFF00C853)
                      : (pct >= 0.5 ? const Color(0xFFFFA000) : accent),
                ),
              ),
            ),

            // Items inside this category
            if (cat.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              const SizedBox(height: 8),
              for (final it in cat.items)
                _buildItemRow(context, it, theme, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleItemCard(
    BuildContext context,
    GradeReportRow it,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF1A1E23) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: _buildItemRow(context, it, theme, isDark),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    GradeReportRow it,
    ThemeData theme,
    bool isDark,
  ) {
    final numGrade = _parseNum(it.grade);
    final isPending =
        numGrade == null || it.grade.trim() == '-' || it.grade.trim() == '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : const Color(0xFF2C323E),
                  ),
                ),
                if (it.subtitle != null &&
                    it.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    it.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              child: Text(
                'Ожидает',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              '+${_fmt(numGrade)} б.',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: numGrade > 0
                    ? const Color(0xFF00C853)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          if (it.link != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.4),
              onPressed: () {
                AppHaptics.selectionClick();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _GradeActivityWebViewScreen(
                      title: it.title,
                      url: it.link!,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context, bool isDark) {
    Widget block({double h = 14, double w = double.infinity, double r = 8}) =>
        ShimmerSkeleton(
          width: w,
          height: h,
          borderRadius: BorderRadius.circular(r),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LoadingSkeletonStrip(),
        const SizedBox(height: 12),
        // Hero skeleton
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDark ? const Color(0xFF1E232B) : Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  block(h: 24, w: 120, r: 8),
                  block(h: 16, w: 100, r: 6),
                ],
              ),
              const SizedBox(height: 16),
              block(h: 40, w: 160, r: 8),
              const SizedBox(height: 14),
              block(h: 12, r: 999),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (_) => block(h: 10, w: 30, r: 4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        block(h: 16, w: 180, r: 4),
        const SizedBox(height: 12),
        for (var i = 0; i < 3; i++) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isDark ? const Color(0xFF1A1E23) : Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    block(h: 38, w: 38, r: 10),
                    const SizedBox(width: 12),
                    Expanded(child: block(h: 18, w: 140, r: 6)),
                    const SizedBox(width: 8),
                    block(h: 22, w: 60, r: 8),
                  ],
                ),
                const SizedBox(height: 12),
                block(h: 6, r: 999),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1A1E23) : const Color(0xFFF1F3F7),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: Color(0xFFE53935),
          ),
          const SizedBox(height: 12),
          const Text(
            'Не удалось загрузить баллы',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            _friendlyErrorMessage(_error),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              AppHaptics.light();
              _load();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  String _friendlyErrorMessage(Object? error) {
    if (error == null) return 'Неизвестная ошибка';
    final s = error.toString().replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
    if (s.contains('XMLHttpRequest') || s.contains('ClientException') || s.contains('SocketException')) {
      return 'Проблема с подключением к сети или прокси ЭИОС.';
    }
    if (s.contains('TimeoutException') || s.contains('timed out')) {
      return 'Сервер ЭИОС отвечает слишком долго. Попробуйте ещё раз.';
    }
    if (s.contains('SessionExpiredException') || s.contains('auth expired') || s.contains('login page')) {
      return 'Сессия в ЭИОС истекла. Перезайдите в аккаунт через Профиль.';
    }
    return s;
  }
}

class _BrsCategory {
  final String title;
  final double score;
  final double max;
  final List<GradeReportRow> items;

  const _BrsCategory({
    required this.title,
    required this.score,
    required this.max,
    required this.items,
  });
}

class _BrsCourseAnalytics {
  final double totalScore;
  final double totalMax;
  final List<_BrsCategory> categories;
  final List<GradeReportRow> standaloneItems;

  const _BrsCourseAnalytics({
    required this.totalScore,
    required this.totalMax,
    required this.categories,
    required this.standaloneItems,
  });

  double get progress =>
      totalMax > 0 ? (totalScore / totalMax).clamp(0.0, 1.0) : 0.0;
}

class _GradeActivityWebViewScreen extends StatelessWidget {
  final String title;
  final String url;

  const _GradeActivityWebViewScreen({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: InAppWebView(initialUrlRequest: URLRequest(url: WebUri(url))),
    );
  }
}
