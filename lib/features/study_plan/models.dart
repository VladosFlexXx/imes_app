class StudyPlanItem {
  final int semester;
  final String code;
  final String name;
  final String control;

  final String totalHours;
  final String lectures;
  final String practices;
  final String labs;
  final String selfWork;

  /// Заголовок -> значение (на случай нестандартных колонок).
  final Map<String, String> columns;

  const StudyPlanItem({
    required this.semester,
    required this.code,
    required this.name,
    required this.control,
    required this.totalHours,
    required this.lectures,
    required this.practices,
    required this.labs,
    required this.selfWork,
    required this.columns,
  });
}
