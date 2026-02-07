import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'models.dart';

class StudyPlanParser {
  /// Парсит страницу "Учебный план" (local/cdo_education_plan/education_plan.php)
  static List<StudyPlanItem> parse(String html) {
    final doc = html_parser.parse(html);
    final knownIds = doc
        .querySelectorAll('[id]')
        .map((e) => (e.id).trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    // На сайте семестры лежат в tab buttons: <button onclick="openTab(event, 'ID')">Первый семестр</button>
    final buttons = doc.querySelectorAll('button.tablinks');
    final out = <StudyPlanItem>[];

    for (final b in buttons) {
      final title = (b.text).trim();
      final sem = _semesterFromTitle(title);
      if (sem == null) continue;

      final onclick = (b.attributes['onclick'] ?? '').trim();
      final tabId = _extractTabId(onclick, knownIds);
      if (tabId == null || tabId.isEmpty) continue;

      final pane = _findById(doc, tabId);
      if (pane == null) continue;

      final table = pane.querySelector('table');
      if (table == null) continue;

      final headerCells = table.querySelectorAll('thead th');
      final headers = headerCells.map((e) => e.text.trim()).toList();

      final rows = table.querySelectorAll('tbody tr');
      for (final tr in rows) {
        final tds = tr.querySelectorAll('td');
        if (tds.isEmpty) continue;

        String cell(int i) => i < tds.length ? tds[i].text.trim() : '';

        // типичная таблица:
        // 0 №, 1 Код, 2 Дисциплина, 3 Вид контроля, 4 Всего, 5 Лек, 6 Прак, 7 Лаб, 8 СРС
        final code = cell(1);
        final name = cell(2);
        if (name.isEmpty) continue;

        final control = cell(3);

        final cols = <String, String>{};
        for (int i = 0; i < tds.length; i++) {
          final key = (i < headers.length && headers[i].isNotEmpty) ? headers[i] : 'Колонка ${i + 1}';
          cols[key] = tds[i].text.trim().replaceAll(RegExp(r'\s+'), ' ');
        }

        out.add(
          StudyPlanItem(
            semester: sem,
            code: code,
            name: name,
            control: control,
            totalHours: cell(4),
            lectures: cell(5),
            practices: cell(6),
            labs: cell(7),
            selfWork: cell(8),
            columns: cols,
          ),
        );
      }
    }

    return out;
  }

  static String? _extractTabId(String onclick, Set<String> knownIds) {
    // openTab(event, 'TAB_ID') или openTab(event, 'tabcontent', 'TAB_ID')
    // Берём последний строковый аргумент, который реально существует как id на странице.
    final quoted = RegExp(r"""['"]([^'"]+)['"]""")
        .allMatches(onclick)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final candidate in quoted.reversed) {
      if (knownIds.contains(candidate)) return candidate;
    }
    return quoted.isEmpty ? null : quoted.last;
  }

  static Element? _findById(Document doc, String id) {
    for (final e in doc.querySelectorAll('[id]')) {
      if ((e.id).trim() == id) return e;
    }
    return null;
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
