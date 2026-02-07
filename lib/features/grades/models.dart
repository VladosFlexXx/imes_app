class GradeCourse {
  final String courseName;
  final String? courseUrl; // ссылка на подробный отчёт, если найдём
  final Map<String, String> columns; // все колонки таблицы (заголовок -> значение)

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

  String? get grade => pick([
        'Оценка',
        'Итоговая оценка',
        'Итог',
        'Grade',
        'Final grade',
      ]);

  String? get percent => pick([
        'Процент',
        'Percentage',
      ]);

  String? get range => pick([
        'Диапазон',
        'Range',
      ]);

  String? get feedback => pick([
        'Отзыв',
        'Feedback',
        'Комментарий',
      ]);
}