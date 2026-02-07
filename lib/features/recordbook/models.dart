class RecordbookGradebook {
  final String number;
  final List<RecordbookSemester> semesters;

  const RecordbookGradebook({
    required this.number,
    required this.semesters,
  });
}

class RecordbookSemester {
  final int semester;
  final List<RecordbookRow> rows;

  const RecordbookSemester({
    required this.semester,
    required this.rows,
  });
}

class RecordbookRow {
  final String discipline;
  final String date;
  final String controlType;
  final String mark;
  final String retake;
  final String teacher;

  const RecordbookRow({
    required this.discipline,
    required this.date,
    required this.controlType,
    required this.mark,
    required this.retake,
    required this.teacher,
  });
}
