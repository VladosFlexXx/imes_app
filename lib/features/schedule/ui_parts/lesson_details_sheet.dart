import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app.dart';
import '../../../core/storage/lesson_notes_storage.dart';
import '../../../core/storage/teacher_contacts_storage.dart';
import '../../../ui/app_haptics.dart';
import '../../../ui/app_theme.dart';
import '../../campus/floor_plan_screen.dart';
import '../../grades/course_report_screen.dart';
import '../../grades/models.dart';
import '../../notifications/notifications_center_screen.dart';
import '../lesson_live_status.dart';
import '../models.dart';

void showLessonDetailsSheet(
  BuildContext context, {
  required Lesson lesson,
  required DateTime lessonDate,
  GradeCourse? linkedCourse,
  double? score,
  Future<({int attended, int total})>? attendanceFuture,
}) {
  AppHaptics.lightImpact();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.22),
    builder: (ctx) => _LessonDetailsSheetContent(
      lesson: lesson,
      lessonDate: lessonDate,
      linkedCourse: linkedCourse,
      score: score,
      attendanceFuture: attendanceFuture,
    ),
  );
}

class _LessonDetailsSheetContent extends StatefulWidget {
  final Lesson lesson;
  final DateTime lessonDate;
  final GradeCourse? linkedCourse;
  final double? score;
  final Future<({int attended, int total})>? attendanceFuture;

  const _LessonDetailsSheetContent({
    required this.lesson,
    required this.lessonDate,
    this.linkedCourse,
    this.score,
    this.attendanceFuture,
  });

  @override
  State<_LessonDetailsSheetContent> createState() =>
      _LessonDetailsSheetContentState();
}

class _LessonDetailsSheetContentState extends State<_LessonDetailsSheetContent> {
  Timer? _ticker;
  String? _teacherEmail;
  bool _loadingEmail = true;
  bool _editingEmail = false;
  late final TextEditingController _emailController;

  String? _lessonNote;
  bool _loadingNote = true;
  bool _editingNote = false;
  late final TextEditingController _noteController;

  String? _inlineNotice;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _noteController = TextEditingController();
    _loadTeacherEmail();
    _loadLessonNote();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _noticeTimer?.cancel();
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showNotice(String text) {
    _noticeTimer?.cancel();
    if (!mounted) return;
    setState(() => _inlineNotice = text);
    _noticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _inlineNotice = null);
    });
  }

  Future<void> _loadLessonNote() async {
    final note = await LessonNotesStorage.getNote(
      widget.lessonDate,
      widget.lesson.subject,
      widget.lesson.time,
    );
    if (!mounted) return;
    setState(() {
      _lessonNote = note;
      _noteController.text = note ?? '';
      _loadingNote = false;
    });
  }

  Future<void> _saveNote() async {
    AppHaptics.selectionClick();
    final clean = _noteController.text.trim();
    await LessonNotesStorage.setNote(
      widget.lessonDate,
      widget.lesson.subject,
      widget.lesson.time,
      clean,
    );
    if (!mounted) return;
    setState(() {
      _lessonNote = clean.isEmpty ? null : clean;
      _editingNote = false;
    });
    _showNotice(clean.isEmpty ? 'Заметка удалена' : 'Заметка сохранена');
  }

  Future<void> _deleteNote() async {
    AppHaptics.selectionClick();
    await LessonNotesStorage.deleteNote(
      widget.lessonDate,
      widget.lesson.subject,
      widget.lesson.time,
    );
    if (!mounted) return;
    setState(() {
      _lessonNote = null;
      _noteController.clear();
      _editingNote = false;
    });
    _showNotice('Заметка удалена');
  }

  static String _weekdayRu(int w) {
    const days = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];
    return days[(w - 1).clamp(0, 6)];
  }

  static String _monthRu(int m) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  Future<void> _shareLesson() async {
    AppHaptics.lightImpact();
    final l = widget.lesson;
    final dateStr = '${_weekdayRu(widget.lessonDate.weekday)}, ${widget.lessonDate.day} ${_monthRu(widget.lessonDate.month)}';
    final timeStr = l.time.replaceAll('.', ':');
    final teacher = l.teacher.trim().isNotEmpty ? l.teacher.trim() : 'Не указан';
    final place = l.place.trim().isNotEmpty ? l.place.trim() : 'Не указано';
    final type = l.type.trim().isNotEmpty ? ' (${l.type.trim()})' : '';

    final buffer = StringBuffer();
    buffer.writeln('📚 ${l.subject}$type');
    buffer.writeln('⏰ $dateStr · $timeStr');
    buffer.writeln('📍 $place');
    buffer.writeln('👨‍🏫 $teacher');

    if (_lessonNote != null && _lessonNote!.trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📝 Заметка / ДЗ:');
      buffer.writeln(_lessonNote!.trim());
    }

    await Share.share(buffer.toString().trim());
  }

  bool _isOnlinePlace(String place) {
    final lower = place.toLowerCase();
    return lower.contains('live') ||
        lower.contains('digital') ||
        lower.contains('дистант') ||
        lower.contains('онлайн') ||
        lower.contains('вебинар') ||
        lower.contains('moodle') ||
        lower.contains('zoom') ||
        lower.contains('teams') ||
        lower.contains('сферум') ||
        lower.contains('sferum');
  }

  Future<void> _copyPlaceUrl(String place) async {
    AppHaptics.mediumImpact();
    String? targetUrl = widget.lesson.url?.trim();
    if (targetUrl != null && targetUrl.isNotEmpty) {
      if (targetUrl.startsWith('/')) {
        targetUrl = 'https://eos.imes.su$targetUrl';
      }
    }
    if (targetUrl == null || targetUrl.isEmpty) {
      targetUrl = 'https://eos.imes.su/my/';
    }
    await Clipboard.setData(ClipboardData(text: targetUrl));
    _showNotice('Ссылка скопирована!');
  }

  Future<void> _openPlace(String place) async {
    AppHaptics.lightImpact();
    if (_isOnlinePlace(place)) {
      // 1. Приоритет: прямая ссылка из расписания (l.url)
      String? targetUrl = widget.lesson.url?.trim();

      // 2. Если ссылка относительная, добавляем домен ЭИОС
      if (targetUrl != null && targetUrl.isNotEmpty) {
        if (targetUrl.startsWith('/')) {
          targetUrl = 'https://eos.imes.su$targetUrl';
        }
      }

      // 3. Запасной вариант: личный кабинет ЭИОС
      if (targetUrl == null || targetUrl.isEmpty) {
        targetUrl = 'https://eos.imes.su/my/';
      }

      final uri = Uri.parse(targetUrl);
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok) {
          await Clipboard.setData(ClipboardData(text: targetUrl));
          _showNotice('Ссылка скопирована');
        }
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: targetUrl));
        _showNotice('Ссылка скопирована');
      }
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CampusFloorPlanScreen(initialRoom: place),
        ),
      );
    }
  }

  Future<void> _loadTeacherEmail() async {
    final email = await TeacherContactsStorage.getEmail(widget.lesson.teacher);
    if (!mounted) return;
    setState(() {
      _teacherEmail = email;
      _emailController.text = email ?? '';
      _loadingEmail = false;
    });
  }

  Future<void> _saveEmail() async {
    AppHaptics.selectionClick();
    final clean = _emailController.text.trim();
    if (clean.isEmpty) {
      await TeacherContactsStorage.removeEmail(widget.lesson.teacher);
      if (!mounted) return;
      setState(() {
        _teacherEmail = null;
        _editingEmail = false;
      });
      _showNotice('Email удалён');
    } else {
      await TeacherContactsStorage.setEmail(widget.lesson.teacher, clean);
      if (!mounted) return;
      setState(() {
        _teacherEmail = clean;
        _editingEmail = false;
      });
      _showNotice('Email сохранён');
    }
  }

  Future<void> _deleteEmail() async {
    AppHaptics.selectionClick();
    await TeacherContactsStorage.removeEmail(widget.lesson.teacher);
    if (!mounted) return;
    setState(() {
      _teacherEmail = null;
      _emailController.clear();
      _editingEmail = false;
    });
    _showNotice('Email удалён');
  }

  Future<void> _copyTeacherName() async {
    AppHaptics.selectionClick();
    final name = widget.lesson.teacher.trim();
    if (name.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: name));
      _showNotice('ФИО скопировано');
    }
  }

  Future<void> _copyEmailDraft() async {
    AppHaptics.selectionClick();
    final teacher = widget.lesson.teacher.trim().isEmpty
        ? 'Преподаватель'
        : widget.lesson.teacher.trim();
    final time = widget.lesson.time.replaceAll('.', ':');
    final draft =
        'Тема: Вопрос по дисциплине "${widget.lesson.subject}"\n\n'
        'Здравствуйте, $teacher!\n'
        'Пишу по занятию (${widget.lesson.day}, $time).\n\n'
        'Вопрос:\n'
        '- ...\n\n'
        'С уважением,';
    await Clipboard.setData(ClipboardData(text: draft));
    _showNotice('Черновик скопирован!');
  }

  Future<void> _launchEmail(String email) async {
    AppHaptics.lightImpact();
    final subject = Uri.encodeComponent('Вопрос по предмету: ${widget.lesson.subject}');
    final uri = Uri.parse('mailto:$email?subject=$subject');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await Clipboard.setData(ClipboardData(text: email));
        _showNotice('Email скопирован в буфер');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: email));
      _showNotice('Email скопирован в буфер');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final reduceEffects = themeController.reduceEffects;
    final accent = appAccentOf(context);

    final liveStatus = LessonLiveStatus.calculate(
      timeStr: widget.lesson.time,
      date: widget.lessonDate,
    );

    final cardBorder = reduceEffects
        ? (isAmoled
            ? accent.withValues(alpha: 0.35)
            : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08)))
        : (isAmoled
            ? accent.withValues(alpha: 0.32)
            : (isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.10)));

    final cardBg = reduceEffects
        ? (isAmoled
            ? Colors.black
            : (isDark ? const Color(0xFF1B2028) : const Color(0xFFF2F5FA)))
        : (isAmoled
            ? Colors.white.withValues(alpha: 0.05)
            : (isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.65)));

    final sheetBg = reduceEffects
        ? (isAmoled
            ? Colors.black
            : (isDark ? const Color(0xFF16191E) : Colors.white))
        : (isAmoled
            ? Colors.black.withValues(alpha: 0.45)
            : (isDark
                ? const Color(0xFF12161E).withValues(alpha: 0.65)
                : Colors.white.withValues(alpha: 0.75)));

    final l = widget.lesson;

    final sheetContainer = Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        color: sheetBg,
        border: Border.all(
          color: cardBorder,
          width: isAmoled ? 1.2 : 1.0,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ручка шторки
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 2, bottom: 12),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.28)
                        : Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),

              // 1. НАЗВАНИЕ ПРЕДМЕТА + КНОПКА «ПОДЕЛИТЬСЯ»
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l.subject,
                      style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : cs.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _shareLesson,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.share_rounded,
                          size: 20,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 2. ЧИПЫ (ТИП, КАБИНЕТ)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (l.type.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        l.type.trim(),
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  if (l.place.trim().isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final place = l.place.trim();
                        final isOnline = _isOnlinePlace(place);
                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openPlace(place),
                            onLongPress: isOnline ? () => _copyPlaceUrl(place) : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.20 : 0.12)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isOnline
                                      ? const Color(0xFF0EA5E9).withValues(alpha: 0.45)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.14)
                                          : Colors.black.withValues(alpha: 0.12)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOnline ? Icons.language_rounded : Icons.place_outlined,
                                    size: 15,
                                    color: isOnline
                                        ? const Color(0xFF0EA5E9)
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    place,
                                    style: TextStyle(
                                      color: isOnline
                                          ? const Color(0xFF0EA5E9)
                                          : (isDark ? Colors.white : Colors.black87),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    isOnline ? Icons.open_in_new_rounded : Icons.arrow_forward_ios_rounded,
                                    size: 11,
                                    color: isOnline
                                        ? const Color(0xFF0EA5E9).withValues(alpha: 0.8)
                                        : (isDark ? Colors.white38 : Colors.black38),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // 3. ЖИВОЙ ТАЙМЕР И СТАТУС ВРЕМЕНИ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, width: isAmoled ? 1.2 : 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          liveStatus.isOngoing
                              ? Icons.play_circle_fill_rounded
                              : (liveStatus.isUpcoming
                                  ? Icons.access_time_rounded
                                  : Icons.check_circle_outline_rounded),
                          color: liveStatus.isOngoing
                              ? const Color(0xFF22C55E)
                              : (liveStatus.isUpcoming ? accent : cs.outline),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            liveStatus.isOngoing
                                ? 'Идёт сейчас · осталось ${liveStatus.remainingMinutes} мин'
                                : (liveStatus.isUpcoming
                                    ? liveStatus.label
                                    : 'Пара завершена'),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: liveStatus.isOngoing
                                  ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                                  : (isDark ? Colors.white : cs.onSurface),
                            ),
                          ),
                        ),
                        Text(
                          l.time,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    if (liveStatus.isOngoing) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: liveStatus.progress,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF22C55E)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3.5. ЗАМЕТКА К ПАРЕ / ДЗ
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lessonNote != null
                        ? const Color(0xFFEAB308).withValues(alpha: isAmoled ? 0.45 : 0.35)
                        : cardBorder,
                    width: isAmoled ? 1.2 : 1.0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 18,
                                color: _lessonNote != null
                                    ? const Color(0xFFEAB308)
                                    : (isDark ? Colors.white60 : Colors.black54),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ЗАМЕТКА К ПАРЕ / ДЗ',
                                style: t.labelSmall?.copyWith(
                                  color: _lessonNote != null
                                      ? const Color(0xFFEAB308)
                                      : (isDark ? Colors.white38 : Colors.black45),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              if (_lessonNote != null && !_editingNote)
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  tooltip: 'Редактировать заметку',
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => setState(() => _editingNote = true),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_loadingNote)
                            const SizedBox(height: 20)
                          else if (_editingNote) ...[
                            TextField(
                              controller: _noteController,
                              maxLines: 4,
                              minLines: 2,
                              autofocus: true,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark ? Colors.white : cs.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Например: сдать реферат к 14:00, стр. 42...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white30 : Colors.black38,
                                  fontSize: 13,
                                ),
                                contentPadding: const EdgeInsets.all(10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: const Color(0xFFEAB308).withValues(alpha: 0.4),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEAB308),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (_lessonNote != null && _lessonNote!.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: _deleteNote,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: Color(0xFFFF5C5C),
                                    ),
                                    label: const Text(
                                      'Удалить',
                                      style: TextStyle(color: Color(0xFFFF5C5C), fontSize: 12.5),
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _editingNote = false;
                                      _noteController.text = _lessonNote ?? '';
                                    });
                                  },
                                  child: Text(
                                    'Отмена',
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                FilledButton.icon(
                                  onPressed: _saveNote,
                                  icon: const Icon(Icons.check_rounded, size: 16),
                                  label: const Text(
                                    'Сохранить',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFEAB308),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (_lessonNote != null && _lessonNote!.isNotEmpty) ...[
                            SelectableText(
                              _lessonNote!,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: isDark ? Colors.white.withValues(alpha: 0.92) : cs.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(() => _editingNote = true),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 16,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Добавить заметку или домашку',
                                      style: TextStyle(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, width: isAmoled ? 1.2 : 1.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'ПРЕПОДАВАТЕЛЬ',
                                style: t.labelSmall?.copyWith(
                                  color: isDark ? Colors.white38 : Colors.black45,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              if (_inlineNotice != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _inlineNotice!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'тап — скопировать',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // ТАП ПО ФИО КОПИРУЕТ
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _copyTeacherName,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.person, color: accent, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l.teacher.trim().isEmpty
                                          ? 'Преподаватель не указан'
                                          : l.teacher.trim(),
                                      style: t.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : cs.onSurface,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 16,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                          Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.08),
                          ),
                          const SizedBox(height: 8),

                          // ПОЧТА ПРЕПОДАВАТЕЛЯ (ИНЛАЙН)
                          if (_loadingEmail)
                            const SizedBox(height: 24)
                          else if (_editingEmail)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      autofocus: true,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: isDark ? Colors.white : cs.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'ivanov@imes.su',
                                        prefixIcon: Icon(
                                          Icons.mail_outline_rounded,
                                          size: 18,
                                          color: accent,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                            color: accent.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: accent, width: 1.5),
                                        ),
                                      ),
                                      onSubmitted: (_) => _saveEmail(),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.check_rounded, color: accent, size: 20),
                                    tooltip: 'Сохранить',
                                    onPressed: _saveEmail,
                                  ),
                                  if (_teacherEmail != null && _teacherEmail!.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFFF5C5C),
                                        size: 20,
                                      ),
                                      tooltip: 'Удалить',
                                      onPressed: _deleteEmail,
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                      size: 20,
                                    ),
                                    tooltip: 'Отмена',
                                    onPressed: () {
                                      setState(() {
                                        _editingEmail = false;
                                        _emailController.text = _teacherEmail ?? '';
                                      });
                                    },
                                  ),
                                ],
                              ),
                            )
                          else if (_teacherEmail != null && _teacherEmail!.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _launchEmail(_teacherEmail!),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.mail_outline_rounded,
                                            size: 16,
                                            color: accent,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _teacherEmail!,
                                              style: TextStyle(
                                                color: accent,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                decoration: TextDecoration.underline,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  tooltip: 'Редактировать email',
                                  color: isDark ? Colors.white54 : Colors.black54,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() => _editingEmail = true);
                                  },
                                ),
                              ],
                            )
                          else
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                setState(() => _editingEmail = true);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 16,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Добавить email преподавателя',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // КНОПКИ БЫСТРОГО ДЕЙСТВИЯ (ЧЕРНОВИК И ЧАТ)
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copyEmailDraft,
                                  icon: const Icon(Icons.description_outlined, size: 16),
                                  label: const Text(
                                    'Черновик',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white70 : cs.onSurface,
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.12),
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.black.withValues(alpha: 0.03),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    AppHaptics.selectionClick();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const NotificationsCenterScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                  label: const Text(
                                    'Чат вуза',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white70 : cs.onSurface,
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.12),
                                    ),
                                    backgroundColor: isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.black.withValues(alpha: 0.03),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 5. УСПЕВАЕМОСТЬ (ТЕКУЩИЙ БАЛЛ И ПОСЕЩАЕМОСТЬ)
              if (widget.linkedCourse != null || widget.score != null)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder, width: isAmoled ? 1.2 : 1.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          AppHaptics.selectionClick();
                          if (widget.linkedCourse != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CourseGradeReportScreen(
                                  course: widget.linkedCourse!,
                                ),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'УСПЕВАЕМОСТЬ',
                                    style: t.labelSmall?.copyWith(
                                      color: isDark ? Colors.white38 : Colors.black45,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.linkedCourse != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'В зачётку',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(Icons.chevron_right, size: 16, color: accent),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  // БАЛЛ
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.score != null
                                              ? widget.score!.toStringAsFixed(1).replaceAll('.0', '')
                                              : (widget.linkedCourse?.grade ?? '—'),
                                          style: t.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: accent,
                                          ),
                                        ),
                                        Text(
                                          'Текущий балл',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ПОСЕЩАЕМОСТЬ
                                  if (widget.attendanceFuture != null)
                                    Expanded(
                                      child: FutureBuilder<({int attended, int total})>(
                                        future: widget.attendanceFuture,
                                        builder: (context, snap) {
                                          final attended = snap.data?.attended ?? 0;
                                          final total = snap.data?.total ?? 0;
                                          final text = total > 0 ? '$attended/$total' : '—';
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                text,
                                                style: t.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: const Color(0xFF22C55E),
                                                ),
                                              ),
                                              Text(
                                                'Посещаемость',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDark ? Colors.white60 : Colors.black54,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: reduceEffects
          ? sheetContainer
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: sheetContainer,
            ),
    );
  }
}
