import 'models.dart';

String _norm(String s) => s
    .replaceAll('\u00A0', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

String _normDay(String s) => _norm(s).toUpperCase();

String _normTime(String s) {
  var t = s.trim();
  t = t.replaceAll('–', '-').replaceAll('—', '-');
  t = t.replaceAll(':', '.');
  t = t.replaceAll(RegExp(r'\s+'), '');
  return t;
}

// Ключ: НЕ ТОЛЬКО day+time, иначе перезапись
String _key(Lesson l) =>
    '${_normDay(l.day)}||${_normTime(l.time)}||${_norm(l.subject)}||${_norm(l.type)}||${_norm(l.teacher)}';

int _dayRank(String day) {
  const order = <String, int>{
    'ПОНЕДЕЛЬНИК': 1,
    'ВТОРНИК': 2,
    'СРЕДА': 3,
    'ЧЕТВЕРГ': 4,
    'ПЯТНИЦА': 5,
    'СУББОТА': 6,
    'ВОСКРЕСЕНЬЕ': 7,
  };
  return order[_normDay(day)] ?? 999;
}

int _timeRank(String time) {
  final t = _normTime(time);
  final start = t.split('-').first;
  final parts = start.split('.');
  final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 99 : 99;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 99 : 99;
  return h * 100 + m;
}

bool _looksCancelled(Lesson l) {
  final all = '${l.subject} ${l.type} ${l.teacher} ${l.place}'.toUpperCase();
  return all.contains('ОТМЕН');
}

bool _sameLesson(Lesson a, Lesson b) {
  return a.subject == b.subject &&
      a.place == b.place &&
      a.type == b.type &&
      a.teacher == b.teacher;
}

List<Lesson> mergeSchedule({
  required List<Lesson> base,
  required List<Lesson> changes,
}) {
  final out = <String, Lesson>{};

  for (final b in base) {
    out[_key(b)] = b;
  }

  for (final c in changes) {
    final k = _key(c);

    if (_looksCancelled(c)) {
      final b = out[k];
      if (b != null) {
        out[k] = Lesson(
          day: b.day,
          time: b.time,
          subject: b.subject,
          place: b.place,
          type: b.type,
          teacher: b.teacher,
          status: LessonStatus.cancelled,
          url: b.url ?? c.url,
        );
      } else {
        out[k] = Lesson(
          day: c.day,
          time: c.time,
          subject: c.subject,
          place: c.place,
          type: c.type,
          teacher: c.teacher,
          status: LessonStatus.cancelled,
          url: c.url,
        );
      }
      continue;
    }

    final b = out[k];
    if (b != null) {
      final same = _sameLesson(b, c);
      out[k] = Lesson(
        day: c.day,
        time: c.time,
        subject: c.subject.isNotEmpty ? c.subject : b.subject,
        place: c.place.isNotEmpty ? c.place : b.place,
        type: c.type.isNotEmpty ? c.type : b.type,
        teacher: c.teacher.isNotEmpty ? c.teacher : b.teacher,
        status: same ? b.status : LessonStatus.changed,
        url: c.url ?? b.url,
      );
    } else {
      out[k] = Lesson(
        day: c.day,
        time: c.time,
        subject: c.subject,
        place: c.place,
        type: c.type,
        teacher: c.teacher,
        status: LessonStatus.changed,
        url: c.url,
      );
    }
  }

  final list = out.values.toList();
  list.sort((a, b) {
    final d = _dayRank(a.day).compareTo(_dayRank(b.day));
    if (d != 0) return d;
    final t = _timeRank(a.time).compareTo(_timeRank(b.time));
    if (t != 0) return t;
    final s = _norm(a.subject).compareTo(_norm(b.subject));
    if (s != 0) return s;
    return _norm(a.type).compareTo(_norm(b.type));
  });

  return list;
}
