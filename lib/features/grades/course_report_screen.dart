import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  String _displayGrade(GradeReportRow r) {
    final g = r.grade.trim();
    if (g.isEmpty || g == '-') return '—';
    return g;
  }

  double? _parseNum(String? raw) {
    if (raw == null) return null;
    final s = raw.replaceAll(' ', '').replaceAll(',', '.');
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  double? _extractMaxFromTitle(String title) {
    final m = RegExp(
      r'максимум\s+можно\s+набрать\s+(\d+(?:[.,]\d+)?)',
      caseSensitive: false,
    ).firstMatch(title);
    if (m == null) return null;
    return _parseNum(m.group(1));
  }

  int _extractOrder(String title) {
    final m = RegExp(r'№\s*(\d+)').firstMatch(title);
    if (m == null) return 0;
    return int.tryParse(m.group(1) ?? '0') ?? 0;
  }

  _ReportAnalytics _analyze(CourseGradeReport report) {
    final aggregateRows = report.rows
        .where((r) => r.type == GradeReportRowType.aggregate)
        .toList();

    final contribution = <_Contribution>[];
    double totalScore = 0;
    double totalMax = 0;

    for (final r in aggregateRows) {
      final score = _parseNum(r.grade);
      final max = _extractMaxFromTitle(r.title);
      if (score == null || max == null || max <= 0) continue;
      contribution.add(_Contribution(title: r.title, score: score, max: max));
      totalScore += score;
      totalMax += max;
    }

    contribution.sort((a, b) => b.max.compareTo(a.max));

    final currentScore = totalScore > 0 ? totalScore : null;
    final maxScore = totalMax > 0 ? totalMax : null;
    final progress = (currentScore != null && maxScore != null)
        ? (currentScore / maxScore).clamp(0.0, 1.0)
        : null;

    final forecast5 = (progress == null)
        ? null
        : (2 + 3 * progress).clamp(2.0, 5.0);

    final itemRows = report.rows
        .where((r) => r.type == GradeReportRowType.item)
        .toList();
    final history = <_HistoryPoint>[];
    for (var i = 0; i < itemRows.length; i++) {
      final r = itemRows[i];
      final v = _parseNum(r.grade);
      if (v == null) continue;
      history.add(
        _HistoryPoint(
          label: r.title,
          shortLabel: _extractOrder(r.title) > 0
              ? '№${_extractOrder(r.title)}'
              : '${i + 1}',
          value: v,
        ),
      );
    }
    history.sort((a, b) {
      final ao = _extractOrder(a.label);
      final bo = _extractOrder(b.label);
      if (ao != bo) return ao.compareTo(bo);
      return 0;
    });

    return _ReportAnalytics(
      currentScore: currentScore,
      maxScore: maxScore,
      progress: progress,
      forecast5: forecast5,
      contribution: contribution.take(5).toList(),
      history: history.take(10).toList(),
    );
  }

  String _fmtNum(double v, {int digits = 1}) {
    final fixed = v.toStringAsFixed(digits);
    if (fixed.endsWith('.0')) {
      return fixed.substring(0, fixed.length - 2).replaceAll('.', ',');
    }
    return fixed.replaceAll('.', ',');
  }

  Widget _kpiTile(
    BuildContext context,
    String title,
    String value, {
    IconData? icon,
  }) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252A34) : const Color(0xFFE7EAF1),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.10),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, size: 14, color: appAccentOf(context)),
                if (icon != null) const SizedBox(width: 6),
                Text(
                  title,
                  style: t.labelMedium?.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : cs.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.96)
                    : cs.onSurface.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights(BuildContext context, _ReportAnalytics a) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final current = (a.currentScore != null && a.maxScore != null)
        ? '${_fmtNum(a.currentScore!)} / ${_fmtNum(a.maxScore!)}'
        : '—';
    final progress = a.progress == null
        ? '—'
        : '${(a.progress! * 100).round()}%';
    final forecast = a.forecast5 == null
        ? '—'
        : '${_fmtNum(a.forecast5!, digits: 2)} / 5';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1A1E23) : const Color(0xFFF1F3F7),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сводка по предмету',
              style: t.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.96)
                    : cs.onSurface.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _kpiTile(context, 'Баллы', current, icon: Icons.score_outlined),
                const SizedBox(width: 8),
                _kpiTile(
                  context,
                  'Прогресс',
                  progress,
                  icon: Icons.timeline_rounded,
                ),
                const SizedBox(width: 8),
                _kpiTile(
                  context,
                  'Прогноз',
                  forecast,
                  icon: Icons.auto_graph_rounded,
                ),
              ],
            ),
            if (a.progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: a.progress,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    appAccentOf(context),
                  ),
                ),
              ),
            ],
            if (a.contribution.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Вклад категорий',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final c in a.contribution) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.84)
                              : cs.onSurface.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_fmtNum(c.score)} / ${_fmtNum(c.max)}',
                      style: t.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (c.score / c.max).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      appAccentOf(context),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            if (a.history.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'История оцененных работ',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: a.history.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final h = a.history[index];
                    return Container(
                      width: 66,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF252A34)
                            : const Color(0xFFE7EAF1),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.10),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            h.shortLabel,
                            style: t.labelSmall?.copyWith(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : cs.onSurface.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _fmtNum(h.value),
                            style: t.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.95)
                                  : cs.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget block({double h = 14, double w = double.infinity}) =>
        ShimmerSkeleton(
          width: w,
          height: h,
          borderRadius: BorderRadius.circular(8),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1A1E23) : const Color(0xFFF1F3F7),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            block(w: 180, h: 16),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: block(h: 56)),
                const SizedBox(width: 8),
                Expanded(child: block(h: 56)),
                const SizedBox(width: 8),
                Expanded(child: block(h: 56)),
              ],
            ),
            const SizedBox(height: 12),
            block(h: 8),
            const SizedBox(height: 14),
            block(w: 140),
            const SizedBox(height: 8),
            block(h: 12),
            const SizedBox(height: 8),
            block(h: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, GradeReportRow row) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSection =
        row.type == GradeReportRowType.category ||
        row.type == GradeReportRowType.course;
    final isAggregate = row.type == GradeReportRowType.aggregate;
    final left = (row.level - 1) * 12.0;

    final gradeColor = isAggregate
        ? appAccentOf(context)
        : (isDark
              ? Colors.white.withValues(alpha: 0.90)
              : cs.onSurface.withValues(alpha: 0.86));

    return Padding(
      padding: EdgeInsets.only(left: left, bottom: 8),
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? const Color(0xFF1A1E23) : const Color(0xFFF1F3F7),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: row.link == null
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _GradeActivityWebViewScreen(
                        title: row.title,
                        url: row.link!,
                      ),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: (isSection ? t.titleSmall : t.bodyLarge)
                            ?.copyWith(
                              fontWeight: isSection
                                  ? FontWeight.w900
                                  : (isAggregate
                                        ? FontWeight.w800
                                        : FontWeight.w700),
                            ),
                      ),
                      if (row.subtitle != null &&
                          row.subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          row.subtitle!,
                          style: t.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.64)
                                : cs.onSurface.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _displayGrade(row),
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: gradeColor,
                  ),
                ),
                if (row.link != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.56)
                        : cs.onSurface.withValues(alpha: 0.52),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final report = _report;
    final analytics = report == null ? null : _analyze(report);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Баллы по дисциплине'),
        backgroundColor: isDark ? const Color(0xFF1A1E23) : Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            Text(
              widget.course.courseName,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _loading
                  ? Padding(
                      key: const ValueKey('loading'),
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        children: [
                          const LoadingSkeletonStrip(),
                          const SizedBox(height: 12),
                          _buildSkeleton(context),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('loaded')),
            ),
            if (_error != null) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? const Color(0xFF1A1E23)
                      : const Color(0xFFF1F3F7),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('Не удалось загрузить отчёт: $_error'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!_loading && analytics != null) ...[
              _buildInsights(context, analytics),
              const SizedBox(height: 10),
            ],
            if (!_loading && report != null && report.rows.isEmpty)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? const Color(0xFF1A1E23)
                      : const Color(0xFFF1F3F7),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Пока нет данных по этому предмету.',
                    style: t.bodyLarge,
                  ),
                ),
              ),
            if (report != null && report.rows.isNotEmpty) ...[
              for (final row in report.rows) _buildRow(context, row),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _Contribution {
  final String title;
  final double score;
  final double max;

  const _Contribution({
    required this.title,
    required this.score,
    required this.max,
  });
}

class _HistoryPoint {
  final String label;
  final String shortLabel;
  final double value;

  const _HistoryPoint({
    required this.label,
    required this.shortLabel,
    required this.value,
  });
}

class _ReportAnalytics {
  final double? currentScore;
  final double? maxScore;
  final double? progress;
  final double? forecast5;
  final List<_Contribution> contribution;
  final List<_HistoryPoint> history;

  const _ReportAnalytics({
    required this.currentScore,
    required this.maxScore,
    required this.progress,
    required this.forecast5,
    required this.contribution,
    required this.history,
  });
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
