import '../../features/grades/models.dart';
import '../../features/profile/models.dart';
import '../../features/recordbook/models.dart';
import '../../features/schedule/models.dart';
import '../../features/study_plan/models.dart';

class DemoData {
  static List<Lesson> schedule() {
    return const [
      Lesson(
        day: 'ПОНЕДЕЛЬНИК',
        time: '09.00-10.20',
        subject: 'ОД. Аналитика данных для бизнеса_42/28/14',
        place: 'Live Digital',
        type: 'Лекция',
        teacher: 'Крылова Анна Дмитриевна',
      ),
      Lesson(
        day: 'ПОНЕДЕЛЬНИК',
        time: '10.30-11.50',
        subject: 'ОД. Визуализация и сторителлинг в данных_20/0/20',
        place: 'Ауд. 407',
        type: 'Практика',
        teacher: 'Емельянов Павел Сергеевич',
      ),
      Lesson(
        day: 'ВТОРНИК',
        time: '14.00-15.20',
        subject: 'ОД. Эконометрика и прогнозирование_42/28/14',
        place: 'Live Digital',
        type: 'Лекция',
        teacher: 'Кузнецов Игорь Викторович',
      ),
      Lesson(
        day: 'ВТОРНИК',
        time: '15.30-16.50',
        subject: 'ОД. Эконометрика и прогнозирование_42/28/14',
        place: 'Ауд. 212',
        type: 'Семинар',
        teacher: 'Кузнецов Игорь Викторович',
      ),
      Lesson(
        day: 'ВТОРНИК',
        time: '17.00-18.20',
        subject: 'ОД. Английский язык для аналитиков (ч. 2)_28/0/28',
        place: 'Онлайн',
        type: 'Практика',
        teacher: 'Романова Юлия Игоревна',
      ),
      Lesson(
        day: 'СРЕДА',
        time: '10.30-11.50',
        subject: 'ОД. Проектный практикум: цифровой продукт_20/0/20',
        place: 'Проектная лаборатория',
        type: 'Практика',
        teacher: 'Зуева Мария Олеговна',
      ),
      Lesson(
        day: 'ЧЕТВЕРГ',
        time: '10.30-11.50',
        subject: 'ОД. Финансовая аналитика и BI_20/14/6',
        place: 'Live Digital',
        type: 'Лекция',
        teacher: 'Филатов Денис Андреевич',
      ),
      Lesson(
        day: 'ЧЕТВЕРГ',
        time: '12.00-13.20',
        subject: 'ОД. Финансовая аналитика и BI_20/14/6',
        place: 'Ауд. 319',
        type: 'Семинар',
        teacher: 'Филатов Денис Андреевич',
      ),
      Lesson(
        day: 'СУББОТА',
        time: '10.30-11.50',
        subject: 'ОД. Информационная безопасность для аналитиков_20/14/6',
        place: 'Ауд. 215',
        type: 'Лекция',
        teacher: 'Кузнецова Ольга Игоревна',
      ),
      Lesson(
        day: 'СУББОТА',
        time: '12.00-13.20',
        subject: 'ОД. Информационная безопасность для аналитиков_20/14/6',
        place: 'Live Digital',
        type: 'Практика',
        teacher: 'Кузнецова Ольга Игоревна',
      ),
      Lesson(
        day: 'СУББОТА',
        time: '14.00-15.20',
        subject: 'ОД. Командная коммуникация и переговоры_20/14/6',
        place: 'Ауд. 108',
        type: 'Семинар',
        teacher: 'Орлова Елена Анатольевна',
        status: LessonStatus.changed,
      ),
    ];
  }

  static List<GradeCourse> grades() {
    return [
      GradeCourse(
        courseName: 'ОД. Аналитика данных для бизнеса_42/28/14',
        columns: const {'Итоговая оценка': '6,40', 'Процент': '88%'},
      ),
      GradeCourse(
        courseName: 'ОД. Визуализация и сторителлинг в данных_20/0/20',
        columns: const {'Итоговая оценка': '4,90', 'Процент': '79%'},
      ),
      GradeCourse(
        courseName: 'ОД. Эконометрика и прогнозирование_42/28/14',
        columns: const {'Итоговая оценка': '5,70', 'Процент': '84%'},
      ),
      GradeCourse(
        courseName: 'ОД. Английский язык для аналитиков (ч. 2)_28/0/28',
        columns: const {'Итоговая оценка': '4,20', 'Процент': '76%'},
      ),
      GradeCourse(
        courseName: 'ОД. Проектный практикум: цифровой продукт_20/0/20',
        columns: const {'Итоговая оценка': '—', 'Процент': '0%'},
      ),
      GradeCourse(
        courseName: 'ОД. Финансовая аналитика и BI_20/14/6',
        columns: const {'Итоговая оценка': '5,10', 'Процент': '81%'},
      ),
      GradeCourse(
        courseName: 'ОД. Информационная безопасность для аналитиков_20/14/6',
        columns: const {'Итоговая оценка': '3,60', 'Процент': '67%'},
      ),
      GradeCourse(
        courseName: 'ОД. Командная коммуникация и переговоры_20/14/6',
        columns: const {'Итоговая оценка': '4,80', 'Процент': '77%'},
      ),
    ];
  }

  static UserProfile profile() {
    return UserProfile(
      fullName: 'TEST',
      avatarUrl: null,
      fields: const {
        'Почта': 'test@imes-demo.local',
        'Группа': 'TEST-01',
        'Профиль': 'Тестовый профиль',
        'Направление/Специальность': 'Бизнес-аналитика и цифровая экономика',
        'Уровень подготовки': 'Бакалавриат',
        'Форма обучения': 'Очная',
        '№ зачетной книжки': '000000',
      },
    );
  }

  static List<StudyPlanItem> studyPlan() {
    return const [
      StudyPlanItem(
        semester: 1,
        code: 'AN-201',
        name: 'Аналитика данных для бизнеса',
        control: 'Экзамен',
        totalHours: '144',
        lectures: '42',
        practices: '28',
        labs: '0',
        selfWork: '74',
        columns: {},
      ),
      StudyPlanItem(
        semester: 1,
        code: 'AN-202',
        name: 'Эконометрика и прогнозирование',
        control: 'Экзамен',
        totalHours: '144',
        lectures: '42',
        practices: '28',
        labs: '0',
        selfWork: '74',
        columns: {},
      ),
      StudyPlanItem(
        semester: 1,
        code: 'AN-203',
        name: 'Визуализация и сторителлинг в данных',
        control: 'Зачет',
        totalHours: '108',
        lectures: '20',
        practices: '0',
        labs: '20',
        selfWork: '68',
        columns: {},
      ),
      StudyPlanItem(
        semester: 2,
        code: 'AN-204',
        name: 'Финансовая аналитика и BI',
        control: 'Экзамен',
        totalHours: '108',
        lectures: '20',
        practices: '14',
        labs: '6',
        selfWork: '68',
        columns: {},
      ),
      StudyPlanItem(
        semester: 2,
        code: 'AN-205',
        name: 'Информационная безопасность для аналитиков',
        control: 'Экзамен',
        totalHours: '108',
        lectures: '20',
        practices: '14',
        labs: '6',
        selfWork: '68',
        columns: {},
      ),
      StudyPlanItem(
        semester: 2,
        code: 'AN-206',
        name: 'Командная коммуникация и переговоры',
        control: 'Зачет',
        totalHours: '72',
        lectures: '20',
        practices: '14',
        labs: '0',
        selfWork: '38',
        columns: {},
      ),
    ];
  }

  static List<RecordbookGradebook> recordbook() {
    return const [
      RecordbookGradebook(
        number: '000000',
        semesters: [
          RecordbookSemester(
            semester: 1,
            rows: [
              RecordbookRow(
                discipline: 'Аналитика данных для бизнеса',
                date: '20.01.2026',
                controlType: 'Экзамен',
                mark: 'Отлично',
                retake: '',
                teacher: 'Крылова А.Д.',
              ),
              RecordbookRow(
                discipline: 'Эконометрика и прогнозирование',
                date: '18.01.2026',
                controlType: 'Экзамен',
                mark: 'Хорошо',
                retake: '',
                teacher: 'Кузнецов И.В.',
              ),
              RecordbookRow(
                discipline: 'Визуализация и сторителлинг в данных',
                date: '15.01.2026',
                controlType: 'Зачет',
                mark: 'Зачтено',
                retake: '',
                teacher: 'Емельянов П.С.',
              ),
            ],
          ),
          RecordbookSemester(
            semester: 2,
            rows: [
              RecordbookRow(
                discipline: 'Финансовая аналитика и BI',
                date: '15.06.2026',
                controlType: 'Экзамен',
                mark: 'Хорошо',
                retake: '',
                teacher: 'Филатов Д.А.',
              ),
              RecordbookRow(
                discipline: 'Информационная безопасность для аналитиков',
                date: '10.06.2026',
                controlType: 'Экзамен',
                mark: 'Удовлетворительно',
                retake: '',
                teacher: 'Кузнецова О.И.',
              ),
              RecordbookRow(
                discipline: 'Командная коммуникация и переговоры',
                date: '08.06.2026',
                controlType: 'Зачет',
                mark: 'Зачтено',
                retake: '',
                teacher: 'Орлова Е.А.',
              ),
            ],
          ),
        ],
      ),
    ];
  }
}
