import 'package:html/parser.dart' as html_parser;
import 'models.dart';

class ScheduleParser {
  static List<Lesson> parseLessonsFromHtml(String html) {
    final doc = html_parser.parse(html);

    // Ищем нужную таблицу по заголовкам (как в твоём TABLE SNIPPET)
    final tables = doc.querySelectorAll('table');
    dynamic scheduleTable;

    for (final t in tables) {
      final up = _norm(t.text);
      if (up.contains('ДНИ НЕДЕЛИ') &&
          up.contains('ВРЕМЯ') &&
          up.contains('ДИСЦИПЛИНА') &&
          up.contains('ПРЕПОДАВАТЕЛЬ')) {
        scheduleTable = t;
        break;
      }
    }

    if (scheduleTable == null) return [];

    final rows = scheduleTable.querySelectorAll('tr');
    if (rows.length < 2) return [];

    String currentDay = '';
    final out = <Lesson>[];

    for (final row in rows.skip(1)) {
      final cells = row.querySelectorAll('td');
      if (cells.isEmpty) continue;

      // Форматы из-за rowspan:
      // 6 td: day | time | subject | place | type | teacher
      // 5 td: time | subject | place | type | teacher
      if (cells.length == 6) {
        currentDay = _clean(cells[0].text);
        final time = _clean(cells[1].text);
        final subject = _clean(cells[2].text);
        final placeCell = cells[3];
        final place = _clean(placeCell.text);
        final link = placeCell.querySelector('a')?.attributes['href']?.trim();
        final type = _clean(cells[4].text);
        final teacher = _clean(cells[5].text);

        if (_looksLikeTime(time) && subject.isNotEmpty) {
          out.add(Lesson(
            day: currentDay,
            time: time,
            subject: subject,
            place: place,
            type: type,
            teacher: teacher,
            url: link != null && link.isNotEmpty ? link : null,
          ));
        }
      } else if (cells.length == 5) {
        final time = _clean(cells[0].text);
        final subject = _clean(cells[1].text);
        final placeCell = cells[2];
        final place = _clean(placeCell.text);
        final link = placeCell.querySelector('a')?.attributes['href']?.trim();
        final type = _clean(cells[3].text);
        final teacher = _clean(cells[4].text);

        if (currentDay.isNotEmpty && _looksLikeTime(time) && subject.isNotEmpty) {
          out.add(Lesson(
            day: currentDay,
            time: time,
            subject: subject,
            place: place,
            type: type,
            teacher: teacher,
            url: link != null && link.isNotEmpty ? link : null,
          ));
        }
      }
    }

    return out;
  }

  static bool _looksLikeTime(String s) {
    final t = s.replaceAll(' ', '');
    return RegExp(r'^\d{2}\.\d{2}-\d{2}\.\d{2}$').hasMatch(t);
  }

  static String _norm(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _clean(String s) =>
      s.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
