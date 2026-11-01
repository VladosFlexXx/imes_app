import '../profile/repository.dart';
import 'models.dart';
import 'week_parity.dart';

class ScheduleShareService {
  static const List<String> _weekdays = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  static const List<String> _numEmojis = [
    '1️⃣',
    '2️⃣',
    '3️⃣',
    '4️⃣',
    '5️⃣',
    '6️⃣',
    '7️⃣',
    '8️⃣',
    '9️⃣',
  ];

  static String _two(int x) => x.toString().padLeft(2, '0');

  static String _formatDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}';

  static String _formatTime(String time) {
    return time
        .replaceAll('.', ':')
        .replaceAll('-', ' – ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _parityLabel(WeekParity parity) =>
      parity == WeekParity.even ? 'Чётная неделя' : 'Нечётная неделя';

  /// Очищает название предмета от мусорных скобок и префиксов ЭИОС
  static String cleanSubject(String raw) {
    var s = raw.trim();
    s = s.replaceAll(
      RegExp(
        r'^\s*(?:од\s*\.?\s*\d*|дисциплина\s*:?|дисц\s*\.?)\s*',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll('_', ' ');
    s = s.replaceAll(
      RegExp(
        r'\(\s*(?:четная|нечетная|чётная|нечётная)\s*неделя\s*\)',
        caseSensitive: false,
      ),
      '',
    );
    s = s.replaceAll(RegExp(r'\b\d+\s*/\s*\d+(?:\s*/\s*\d+)?\b'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.endsWith('.')) {
      s = s.substring(0, s.length - 1).trim();
    }
    return s;
  }

  /// Сокращает «Мансурова Алина Анатольевна» -> «Мансурова А.А.»
  static String shortenTeacher(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3) {
      final last = parts[0];
      final f = parts[1][0].toUpperCase();
      final m = parts[2][0].toUpperCase();
      return '$last $f.$m.';
    } else if (parts.length == 2) {
      final last = parts[0];
      final f = parts[1][0].toUpperCase();
      return '$last $f.';
    }
    return trimmed;
  }

  /// Форматирует расписание на один день для отправки в чаты.
  static String formatDay({
    required DateTime date,
    required List<Lesson> lessons,
    required WeekParity parity,
    String? customGroupName,
  }) {
    final buffer = StringBuffer();
    final dayName = _weekdays[date.weekday - 1];
    final dateStr = _formatDate(date);
    final group = customGroupName ?? ProfileRepository.instance.profile?.group;

    buffer.writeln('📅 $dayName, $dateStr • ${_parityLabel(parity)}');
    if (group != null && group.trim().isNotEmpty) {
      buffer.writeln('👥 Группа: ${group.trim()}');
    }
    buffer.writeln();

    if (lessons.isEmpty) {
      buffer.writeln('▫️ Занятий нет 🎉');
    } else {
      for (var i = 0; i < lessons.length; i++) {
        final l = lessons[i];
        final numEmoji = i < _numEmojis.length ? _numEmojis[i] : '${i + 1}.';
        final timeStr = _formatTime(l.time);
        final subj = cleanSubject(l.subject);
        final typeStr =
            l.type.trim().isNotEmpty ? ' (${l.type.trim()})' : '';

        var statusPrefix = '';
        if (l.status == LessonStatus.cancelled) {
          statusPrefix = '❌ [ОТМЕНЕНА] ';
        } else if (l.status == LessonStatus.changed) {
          statusPrefix = '⚠️ [ИЗМЕНЕНИЕ] ';
        }

        buffer.writeln('$numEmoji $timeStr • $statusPrefix$subj$typeStr');

        final details = <String>[];
        if (l.place.trim().isNotEmpty) details.add(l.place.trim());
        final teacher = shortenTeacher(l.teacher);
        if (teacher.isNotEmpty) details.add(teacher);

        if (details.isNotEmpty) {
          buffer.writeln('📍 ${details.join(' • ')}');
        }

        if (i < lessons.length - 1) {
          buffer.writeln();
        }
      }
    }

    return buffer.toString().trimRight();
  }

  /// Форматирует расписание на всю неделю в компактном и красивом виде.
  static String formatWeek({
    required DateTime weekStart,
    required Map<int, List<Lesson>> weekLessons,
    required WeekParity parity,
    String? customGroupName,
  }) {
    final buffer = StringBuffer();
    final weekEnd = weekStart.add(const Duration(days: 6));
    final rangeStr = '${_formatDate(weekStart)} – ${_formatDate(weekEnd)}';
    final group = customGroupName ?? ProfileRepository.instance.profile?.group;

    buffer.writeln('🗓 Расписание: $rangeStr • ${_parityLabel(parity)}');
    if (group != null && group.trim().isNotEmpty) {
      buffer.writeln('👥 Группа: ${group.trim()}');
    }
    buffer.writeln();

    var hasAnyLessonInWeek = false;

    for (var i = 0; i < 7; i++) {
      final dayDate = weekStart.add(Duration(days: i));
      final dayWeekday = dayDate.weekday;
      final dayName = _weekdays[dayWeekday - 1];
      final dayDateStr = _formatDate(dayDate);
      final lessons = weekLessons[dayWeekday] ?? const <Lesson>[];

      // Пропускаем воскресенье, если в нём нет занятий
      if (dayWeekday == 7 && lessons.isEmpty) {
        continue;
      }

      buffer.writeln('📌 $dayName, $dayDateStr:');
      if (lessons.isEmpty) {
        buffer.writeln('▫️ Занятий нет 🎉');
      } else {
        hasAnyLessonInWeek = true;
        for (var j = 0; j < lessons.length; j++) {
          final l = lessons[j];
          final numEmoji = j < _numEmojis.length ? _numEmojis[j] : '${j + 1}.';
          final timeStr = _formatTime(l.time);
          final subj = cleanSubject(l.subject);
          final typeStr =
              l.type.trim().isNotEmpty ? ' (${l.type.trim()})' : '';

          var statusPrefix = '';
          if (l.status == LessonStatus.cancelled) {
            statusPrefix = '❌ [ОТМЕНЕНА] ';
          } else if (l.status == LessonStatus.changed) {
            statusPrefix = '⚠️ ';
          }

          buffer.writeln('$numEmoji $timeStr • $statusPrefix$subj$typeStr');

          final details = <String>[];
          if (l.place.trim().isNotEmpty) details.add(l.place.trim());
          final teacher = shortenTeacher(l.teacher);
          if (teacher.isNotEmpty) details.add(teacher);

          if (details.isNotEmpty) {
            buffer.writeln('📍 ${details.join(' • ')}');
          }

          if (j < lessons.length - 1) {
            buffer.writeln();
          }
        }
      }
      buffer.writeln();
    }

    if (!hasAnyLessonInWeek) {
      buffer.writeln('🎉 На этой неделе пар нет!');
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }
}
