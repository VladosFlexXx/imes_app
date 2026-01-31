class UserProfile {
  final String fullName;
  final String? avatarUrl;
  final Map<String, String> fields; // любые найденные поля (ключ -> значение)

  UserProfile({
    required this.fullName,
    required this.fields,
    this.avatarUrl,
  });

  String? pick(List<String> keys) {
    for (final k in keys) {
      final v = fields[k];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  String? get email => pick([
        'Адрес электронной почты',
        'Электронная почта',
        'Email',
        'E-mail',
        'Почта',
      ]);

  String? get profileEdu => pick([
        'Профиль (обучающийся 1)',
        'Профиль (обучающийся 2)',
        'Профиль',
      ]);

  String? get specialty => pick([
        'Направление/Специальность (обучающийся 1)',
        'Направление/Специальность (обучающийся 2)',
        'Направление/Специальность',
        'Направление',
        'Специальность',
      ]);

  /// ✅ Группа
  String? get group => pick([
        'Группа',
        'Учебная группа',
        'Группа (обучающийся 1)',
        'Группа (обучающийся 2)',
      ]);

  String? get level => pick([
        'Уровень подготовки (обучающийся 1)',
        'Уровень подготовки (обучающийся 2)',
        'Уровень подготовки',
      ]);

  String? get eduForm => pick([
        'Форма обучения (обучающийся 1)',
        'Форма обучения (обучающийся 2)',
        'Форма обучения',
      ]);

  String? get recordBook => pick([
        '№ зачетной книжки (обучающийся 1)',
        '№ зачетной книжки (обучающийся 2)',
        '№ зачетной книжки',
        'Зачетная книжка',
      ]);
}
