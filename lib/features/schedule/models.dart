enum LessonStatus {
  normal,
  changed,
  cancelled,
}

class Lesson {
  final String day;
  final String time;
  final String subject;
  final String place;
  final String type;
  final String teacher;

  final LessonStatus status;
  final String? url;

  const Lesson({
    required this.day,
    required this.time,
    required this.subject,
    required this.place,
    required this.type,
    required this.teacher,
    this.status = LessonStatus.normal,
    this.url,
  });

  /// Очищает сырые технические префиксы (ОД., ЭД., ОП.) и суффиксы курсов (_42/28/14).
  static String cleanSubjectName(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(
      RegExp(r'^(?:ОД|ЭД|ОП|ПД|ДВ|УД|МД)[\.\s_-]+', caseSensitive: false),
      '',
    );
    s = s.replaceFirst(RegExp(r'_\d+(?:[\d/_.-]*|\s*)$'), '');
    s = s.replaceFirst(RegExp(r'\s*\(\d+[\d/_.-]*\)$'), '');
    return s.trim();
  }

  String get displaySubject => cleanSubjectName(subject);

  Lesson copyWith({
    String? day,
    String? time,
    String? subject,
    String? place,
    String? type,
    String? teacher,
    LessonStatus? status,
    String? url,
  }) {
    return Lesson(
      day: day ?? this.day,
      time: time ?? this.time,
      subject: subject ?? this.subject,
      place: place ?? this.place,
      type: type ?? this.type,
      teacher: teacher ?? this.teacher,
      status: status ?? this.status,
      url: url ?? this.url,
    );
  }

  @override
  String toString() =>
      '$day | $time | $subject | $place | $type | $teacher | $status | $url';
}
