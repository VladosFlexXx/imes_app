import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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

  Widget _buildRow(BuildContext context, GradeReportRow row) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isSection =
        row.type == GradeReportRowType.category ||
        row.type == GradeReportRowType.course;
    final isAggregate = row.type == GradeReportRowType.aggregate;
    final left = (row.level - 1) * 12.0;

    final gradeColor = isAggregate
        ? cs.primary
        : (row.type == GradeReportRowType.item
              ? cs.onSurface
              : cs.onSurfaceVariant);

    return Padding(
      padding: EdgeInsets.only(left: left, bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
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
                            color: cs.onSurface.withValues(alpha: 0.64),
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
                    color: cs.onSurface.withValues(alpha: 0.56),
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
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text('Баллы по дисциплине')),
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
            if (_loading) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 14),
            ],
            if (_error != null) ...[
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('Не удалось загрузить отчёт: $_error'),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (!_loading && report != null && report.rows.isEmpty)
              Card(
                elevation: 0,
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
