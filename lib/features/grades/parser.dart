import 'package:html/parser.dart' as html_parser;
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
      final hasCourse = hs.any((h) => h.contains('курс') || h.contains('course'));
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

      out.add(GradeCourse(courseName: courseName, columns: cols, courseUrl: courseUrl));
    }

    return out;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}