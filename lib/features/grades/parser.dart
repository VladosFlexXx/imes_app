import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'models.dart';

class GradesParser {
  static List<GradeCourse> parseOverview(String html) {
    final doc = html_parser.parse(html);

    // Ищем "правильную" таблицу: по заголовкам (Course/Курс и т.п.)
    final tables = doc.querySelectorAll('table');
    if (tables.isEmpty) return [];

    List<String> normHeaders(List<String> headers) =>
        headers.map((h) => _norm(h)).where((h) => h.isNotEmpty).toList();

    bool looksLikeGradesTable(List<String> headers) {
      final hs = normHeaders(headers);
      final hasCourse = hs.any(
        (h) => h.contains('курс') || h.contains('course'),
      );
      final hasGrade = hs.any((h) => h.contains('оцен') || h.contains('grade'));
      // иногда в overview есть только курс+оценка, иногда больше
      return hasCourse && (hasGrade || hs.length >= 2);
    }

    // 1) пробуем найти таблицу с нужными заголовками
    for (final table in tables) {
      final ths = table.querySelectorAll('thead th');
      final headers = ths.map((e) => e.text.trim()).toList();
      if (headers.isNotEmpty && looksLikeGradesTable(headers)) {
        return _parseTable(table, headers);
      }
    }

    // 2) fallback: берём таблицу с максимальным числом строк и хоть какими-то заголовками
    int bestScore = -1;
    dynamic bestTable;
    List<String> bestHeaders = [];
    for (final table in tables) {
      final ths = table.querySelectorAll('thead th');
      final headers = ths.map((e) => e.text.trim()).toList();
      if (headers.isEmpty) continue;
      final rows = table.querySelectorAll('tbody tr');
      final score = rows.length * 10 + headers.length;
      if (score > bestScore) {
        bestScore = score;
        bestTable = table;
        bestHeaders = headers;
      }
    }
    if (bestTable != null) {
      return _parseTable(bestTable, bestHeaders);
    }

    return [];
  }

  static List<GradeCourse> _parseTable(dynamic table, List<String> headersRaw) {
    final headers = headersRaw.map((h) => h.trim()).toList();

    // На случай, если заголовков меньше/больше, чем колонок — будем жить аккуратно
    final rows = table.querySelectorAll('tbody tr');
    final out = <GradeCourse>[];

    for (final tr in rows) {
      final tds = tr.querySelectorAll('td');
      if (tds.isEmpty) continue;

      // курс обычно в первой ячейке
      final first = tds.first;
      final a = first.querySelector('a');
      final courseName = (a?.text.trim().isNotEmpty == true)
          ? a!.text.trim()
          : first.text.trim();

      if (courseName.isEmpty) continue;

      final courseUrl = a?.attributes['href'];

      final cols = <String, String>{};
      for (int i = 0; i < tds.length; i++) {
        final key = (i < headers.length && headers[i].trim().isNotEmpty)
            ? headers[i].trim()
            : 'Колонка ${i + 1}';
        final val = tds[i].text.trim().replaceAll(RegExp(r'\s+'), ' ');
        cols[key] = val;
      }

      out.add(
        GradeCourse(
          courseName: courseName,
          columns: cols,
          courseUrl: courseUrl,
        ),
      );
    }

    return out;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static CourseGradeReport parseUserReport(
    String html, {
    required String fallbackCourseName,
  }) {
    final doc = html_parser.parse(html);
    final table = doc.querySelector('table.user-grade');

    if (table == null) {
      return CourseGradeReport(courseName: fallbackCourseName, rows: const []);
    }

    final topCourse = _clean(
      table.querySelector('th.level1.category span')?.text ?? '',
    );
    final courseName = topCourse.isNotEmpty ? topCourse : fallbackCourseName;

    final rows = <GradeReportRow>[];

    for (final tr in table.querySelectorAll('tbody tr')) {
      final th = tr.querySelector('th.column-itemname');
      final td = tr.querySelector('td.column-grade');
      if (th == null) continue;

      final title = _extractTitle(th);
      if (title.isEmpty) continue;

      final level = _extractLevel(th.classes);
      final type = _extractRowType(th.classes);
      final grade = _clean(td?.text ?? '');
      final subtitle = _clean(th.querySelector('.dimmed_text')?.text ?? '');
      final link = th.querySelector('.rowtitle a')?.attributes['href'];
      final id = th.id.trim().isNotEmpty
          ? th.id.trim()
          : '${type.name}_${level}_${rows.length}';

      rows.add(
        GradeReportRow(
          id: id,
          level: level,
          type: type,
          title: title,
          subtitle: subtitle.isEmpty ? null : subtitle,
          grade: grade.isEmpty ? '-' : grade,
          link: link,
        ),
      );
    }

    return CourseGradeReport(courseName: courseName, rows: rows);
  }

  static String _extractTitle(dom.Element th) {
    final direct = _clean(
      th.querySelector('.rowtitle .gradeitemheader')?.text ?? '',
    );
    if (direct.isNotEmpty) return direct;
    final span = _clean(
      th.querySelector('.category-content > span')?.text ?? '',
    );
    if (span.isNotEmpty) return span;
    return _clean(th.text);
  }

  static int _extractLevel(Set<String> classes) {
    for (final c in classes) {
      if (c.startsWith('level')) {
        final v = int.tryParse(c.substring('level'.length));
        if (v != null) return v;
      }
    }
    return 1;
  }

  static GradeReportRowType _extractRowType(Set<String> classes) {
    if (classes.contains('category')) return GradeReportRowType.category;
    if (classes.contains('baggb')) return GradeReportRowType.aggregate;
    if (classes.contains('item')) return GradeReportRowType.item;
    return GradeReportRowType.course;
  }

  static String _clean(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').replaceAll('\u00A0', ' ').trim();
}
