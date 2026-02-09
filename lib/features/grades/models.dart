class GradeCourse {
  final String courseName;
  final String? courseUrl; // ссылка на подробный отчёт, если найдём
  final Map<String, String>
  columns; // все колонки таблицы (заголовок -> значение)

  GradeCourse({
    required this.courseName,
    required this.columns,
    this.courseUrl,
  });

  String? pick(List<String> keys) {
    for (final k in keys) {
      final v = columns[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  String? get grade =>
      pick(['Оценка', 'Итоговая оценка', 'Итог', 'Grade', 'Final grade']);

  String? get percent => pick(['Процент', 'Percentage']);

  String? get range => pick(['Диапазон', 'Range']);

  String? get feedback => pick(['Отзыв', 'Feedback', 'Комментарий']);
}

enum GradeReportRowType { course, category, aggregate, item }

class GradeReportRow {
  final String id;
  final int level;
  final GradeReportRowType type;
  final String title;
  final String? subtitle;
  final String grade;
  final String? link;

  const GradeReportRow({
    required this.id,
    required this.level,
    required this.type,
    required this.title,
    required this.grade,
    this.subtitle,
    this.link,
  });

  bool get isHeader =>
      type == GradeReportRowType.course || type == GradeReportRowType.category;
}

class CourseGradeReport {
  final String courseName;
  final List<GradeReportRow> rows;

  const CourseGradeReport({required this.courseName, required this.rows});
}
