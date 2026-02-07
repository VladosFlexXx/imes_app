import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'models.dart';

class RecordbookParser {
  /// Парсит "Электронная зачетная книга" (local/cdo_academic_progress/academic_progress.php)
  static List<RecordbookGradebook> parse(String html) {
    final doc = html_parser.parse(html);

    final gradebookTabs = doc.querySelectorAll('#academic_progress_gradebook a.nav-link');
    if (gradebookTabs.isEmpty) {
      final t = doc.querySelector('table');
      if (t == null) return const [];
      final sem = RecordbookSemester(semester: 1, rows: _parseRowsFromTable(t));
      return [RecordbookGradebook(number: '', semesters: [sem])];
    }

    final out = <RecordbookGradebook>[];

    for (final a in gradebookTabs) {
      final number = a.text.trim();
      final href = (a.attributes['href'] ?? '').trim();
      final gradebookId = _extractFragmentId(href) ?? a.attributes['aria-controls'] ?? '';
      if (gradebookId.isEmpty) continue;

      final gradebookPane = doc.querySelector('#$gradebookId');
      if (gradebookPane == null) continue;

      final semesterTabs = gradebookPane.querySelectorAll('#academic_progress_semesters a.nav-link');
      final semesters = <RecordbookSemester>[];

      for (final sa in semesterTabs) {
        final stitle = sa.text.trim();
        final semNum = _semesterFromTitle(stitle);
        if (semNum == null) continue;

        final shref = (sa.attributes['href'] ?? '').trim();
        final semId = _extractFragmentId(shref) ?? sa.attributes['aria-controls'] ?? '';
        if (semId.isEmpty) continue;

        final semPane = gradebookPane.querySelector('#$semId');
        if (semPane == null) continue;

        final table = semPane.querySelector('table');
        if (table == null) continue;

        final rows = _parseRowsFromTable(table);
        semesters.add(RecordbookSemester(semester: semNum, rows: rows));
      }

      if (semesters.isEmpty) {
        final tables = gradebookPane.querySelectorAll('table');
        if (tables.isNotEmpty) {
          semesters.add(RecordbookSemester(semester: 1, rows: _parseRowsFromTable(tables.first)));
        }
      }

      semesters.sort((a, b) => a.semester.compareTo(b.semester));
      out.add(RecordbookGradebook(number: number, semesters: semesters));
    }

    return out;
  }

  static List<RecordbookRow> _parseRowsFromTable(Element table) {
    final rows = table.querySelectorAll('tbody tr');
    final out = <RecordbookRow>[];

    String clean(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

    for (final tr in rows) {
      final tds = tr.querySelectorAll('td');
      if (tds.isEmpty) continue;

      String cell(int i) => i < tds.length ? clean(tds[i].text) : '';

      final discipline = cell(0);
      if (discipline.isEmpty) continue;

      out.add(
        RecordbookRow(
          discipline: discipline,
          date: cell(1),
          controlType: cell(2),
          mark: cell(3),
          retake: cell(4),
          teacher: cell(5),
        ),
      );
    }

    return out;
  }

  static String? _extractFragmentId(String href) {
    final idx = href.indexOf('#');
    if (idx < 0 || idx == href.length - 1) return null;
    return href.substring(idx + 1).trim();
  }

  static int? _semesterFromTitle(String t) {
    final s = t.toLowerCase();
    if (!s.contains('семестр')) return null;

    if (s.contains('перв')) return 1;
    if (s.contains('втор')) return 2;
    if (s.contains('трет')) return 3;
    if (s.contains('четвер')) return 4;
    if (s.contains('пят')) return 5;
    if (s.contains('шест')) return 6;
    if (s.contains('седь')) return 7;
    if (s.contains('восьм')) return 8;
    final n = RegExp(r'(\d+)').firstMatch(s);
    return n == null ? null : int.tryParse(n.group(1)!);
  }
}
