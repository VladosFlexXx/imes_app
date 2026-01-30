import 'package:html/parser.dart' as html;

import 'models.dart';

List<Lesson> lessonsFromHtml(String htmlText) {
  final document = html.parse(htmlText);

  // В твоём HTML таблица одна, но на всякий случай:
  final table = document.querySelector('table');
  if (table == null) return [];

  final lessons = <Lesson>[];

  String currentDay = '';
  String currentTime = '';
  String currentSubject = '';
  String currentPlace = '';

  final rows = table.querySelectorAll('tr');

  for (final row in rows) {
    // Берём td/th
    final cells = row.querySelectorAll('td,th');
    if (cells.isEmpty) continue;

    // Пропускаем заголовок
    final firstText = _clean(cells.first.text);
    if (firstText.toUpperCase() == 'ДНИ НЕДЕЛИ') continue;

    // Тексты ячеек
    final texts = cells.map((c) => _clean(c.text)).toList();

    int idx = 0;

    // 1) День (иногда есть, иногда нет)
    if (idx < texts.length && _looksLikeDay(texts[idx])) {
      currentDay = texts[idx];
      idx++;
    }

    // 2) Время (иногда есть, иногда нет)
    if (idx < texts.length && _looksLikeTime(texts[idx])) {
      currentTime = texts[idx];
      idx++;
    }

    // Если нет контекста — строка бесполезна
    if (currentDay.isEmpty || currentTime.isEmpty) continue;

    // Остаток может быть:
    // A) subject, place, type, teacher (4)
    // B) time, subject, place, type, teacher (мы time уже сняли) => (4)
    // C) subject отсутствует из-за rowspan: place, type, teacher (3)
    // D) subject+place отсутствуют (редко): type, teacher (2) — пропускаем

    final remaining = texts.sublist(idx);

    String subject = '';
    String place = '';
    String type = '';
    String teacher = '';

    // Флаг: строка "укороченная" из-за rowspan (нет subject/time в row)
    bool inheritedSubject = false;

    if (remaining.length >= 4) {
      // Нормальный полный ряд: subject/place/type/teacher
      subject = remaining[0];
      place = remaining[1];
      type = remaining[2];
      teacher = remaining[3];

      if (subject.isNotEmpty) currentSubject = subject;
      if (place.isNotEmpty) currentPlace = place;
    } else if (remaining.length == 3) {
      // Укороченный ряд: place/type/teacher, subject наследуем
      place = remaining[0];
      type = remaining[1];
      teacher = remaining[2];

      subject = currentSubject;
      inheritedSubject = true;

      if (place.isNotEmpty) currentPlace = place;
      if (place.isEmpty) place = currentPlace;
    } else {
      continue;
    }

    // Иногда subject может быть пустым — пропускаем
    if (subject.trim().isEmpty) continue;

    final newLesson = Lesson(
      day: currentDay,
      time: currentTime,
      subject: subject,
      place: place,
      type: type,
      teacher: teacher,
      status: LessonStatus.normal,
    );

    // === FIX ДУБЛЕЙ ИЗ-ЗА ROWSPAN (подгруппы) ===
    // Если предмет/время унаследованы (remaining == 3),
    // то чаще всего это "та же пара", но другая подгруппа/препод.
    // Склеиваем преподавателей в одну карточку вместо дубля.
    if (inheritedSubject && lessons.isNotEmpty) {
      final last = lessons.last;

      final sameSlot = last.day == newLesson.day &&
          last.time == newLesson.time &&
          last.subject == newLesson.subject &&
          last.type == newLesson.type &&
          last.status == newLesson.status;

      if (sameSlot) {
        final t1 = last.teacher.trim();
        final t2 = newLesson.teacher.trim();

        // не добавляем одинакового препода дважды
        if (t2.isNotEmpty && !_teacherAlreadyListed(t1, t2)) {
          final mergedTeacher = t1.isEmpty ? t2 : '$t1\n$t2';
          lessons[lessons.length - 1] = last.copyWith(
            teacher: mergedTeacher,
            // place оставляем как у последнего/первого — обычно одинаковый (Live Digital)
          );
        }
        continue; // не добавляем новый урок
      }
    }

    lessons.add(newLesson);
  }

  return lessons;
}

bool _teacherAlreadyListed(String existing, String candidate) {
  final ex = existing
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return ex.contains(candidate.trim());
}

bool _looksLikeDay(String text) {
  final t = text.toUpperCase();
  return t.contains('ПОНЕДЕЛЬНИК') ||
      t.contains('ВТОРНИК') ||
      t.contains('СРЕДА') ||
      t.contains('ЧЕТВЕРГ') ||
      t.contains('ПЯТНИЦА') ||
      t.contains('СУББОТА') ||
      t.contains('ВОСКРЕСЕНЬЕ');
}

bool _looksLikeTime(String text) {
  final t = text.trim();
  return RegExp(r'\d{1,2}[:.]\d{2}\s*[-–—]\s*\d{1,2}[:.]\d{2}').hasMatch(t);
}

String _clean(String s) {
  return s
      .replaceAll('\u00A0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
