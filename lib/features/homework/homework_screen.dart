import 'package:flutter/material.dart';
import '../../ui/app_haptics.dart';
import '../../ui/app_theme.dart';
import '../schedule/schedule_repository.dart';
import 'homework_repository.dart';

class HomeworkScreen extends StatefulWidget {
  final String? initialSubject;

  const HomeworkScreen({super.key, this.initialSubject});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  final _repo = HomeworkRepository.instance;
  int _filterIndex = 0; // 0 = все, 1 = в процессе, 2 = сделано

  @override
  void initState() {
    super.initState();
    _repo.init();
    if (widget.initialSubject != null && widget.initialSubject!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddDialog(initialSubject: widget.initialSubject);
      });
    }
  }

  String _formatDeadline(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dt.year, dt.month, dt.day);
    final diff = deadlineDay.difference(today).inDays;

    if (diff < 0) return 'Просрочено на ${-diff} дн.';
    if (diff == 0) return 'Сдать сегодня!';
    if (diff == 1) return 'Сдать завтра';
    if (diff <= 4) return 'Сдать через $diff дн.';
    return 'Дедлайн: ${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }

  Color _deadlineColor(DateTime dt, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(dt.year, dt.month, dt.day);
    final diff = deadlineDay.difference(today).inDays;

    if (diff < 0) return const Color(0xFFFF5C5C);
    if (diff <= 1) return const Color(0xFFFF9800);
    return isDark ? Colors.white60 : Colors.black54;
  }

  void _showAddDialog({String? initialSubject}) {
    AppHaptics.lightImpact();
    final subjects = <String>{};
    for (final l in ScheduleRepository.instance.lessons) {
      if (l.subject.trim().isNotEmpty) {
        subjects.add(l.subject.trim());
      }
    }

    final subjectController = TextEditingController(text: initialSubject ?? '');
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    DateTime? selectedDeadline = DateTime.now().add(const Duration(days: 2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final accent = appAccentOf(context);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  color: isDark ? const Color(0xFF1C1F26) : Colors.white,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Новое задание / ДЗ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        labelText: 'Предмет',
                        hintText: 'например, Мировая экономика',
                        prefixIcon: const Icon(Icons.school_outlined, size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF262A34) : const Color(0xFFF1F3F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (subjects.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: subjects.take(5).map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(s, style: const TextStyle(fontSize: 12)),
                                onPressed: () {
                                  AppHaptics.selectionClick();
                                  setModalState(() {
                                    subjectController.text = s;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      autofocus: initialSubject != null,
                      decoration: InputDecoration(
                        labelText: 'Что нужно сделать? *',
                        hintText: 'например, Выучить конспект к семинару',
                        prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF262A34) : const Color(0xFFF1F3F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Заметки / Ссылки (необязательно)',
                        hintText: 'номера страниц, вопросы, ссылка...',
                        prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF262A34) : const Color(0xFFF1F3F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          selectedDeadline == null
                              ? 'Без дедлайна'
                              : 'Срок: ${selectedDeadline!.day.toString().padLeft(2, '0')}.${selectedDeadline!.month.toString().padLeft(2, '0')}.${selectedDeadline!.year}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white.withValues(alpha: 0.90) : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDeadline ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 7)),
                              lastDate: DateTime.now().add(const Duration(days: 180)),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDeadline = picked);
                            }
                          },
                          child: const Text('Выбрать дату'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;
                          AppHaptics.mediumImpact();
                          _repo.add(
                            subject: subjectController.text,
                            title: title,
                            note: noteController.text,
                            deadline: selectedDeadline,
                          );
                          Navigator.of(ctx).pop();
                        },
                        child: const Text(
                          'Добавить задание',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = appAccentOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дедлайны и ДЗ'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Задание', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          final all = _repo.items;
          final filtered = all.where((item) {
            if (_filterIndex == 1) return !item.isCompleted;
            if (_filterIndex == 2) return item.isCompleted;
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    _filterChip('Все (${all.length})', 0, accent, isDark),
                    const SizedBox(width: 8),
                    _filterChip('В процессе (${_repo.activeCount})', 1, accent, isDark),
                    const SizedBox(width: 8),
                    _filterChip('Сделано (${all.length - _repo.activeCount})', 2, accent, isDark),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _filterIndex == 2
                                  ? Icons.task_alt_rounded
                                  : Icons.assignment_turned_in_outlined,
                              size: 56,
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _filterIndex == 2
                                  ? 'Пока нет выполненных задач'
                                  : 'Все задания сделаны! Красота.',
                              style: t.bodyMedium?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 84),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5C5C),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              AppHaptics.lightImpact();
                              _repo.delete(item.id);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: isDark ? const Color(0xFF1A1D22) : Colors.white,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.18)
                                        : Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      AppHaptics.selectionClick();
                                      _repo.toggleComplete(item.id);
                                    },
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      margin: const EdgeInsets.only(top: 2, right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: item.isCompleted
                                            ? accent
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: item.isCompleted
                                              ? accent
                                              : (isDark ? Colors.white38 : Colors.black38),
                                          width: 2,
                                        ),
                                      ),
                                      child: item.isCompleted
                                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(6),
                                                color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                                              ),
                                              child: Text(
                                                item.subject,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: accent,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (item.deadline != null) ...[
                                              Text(
                                                _formatDeadline(item.deadline!),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: _deadlineColor(item.deadline!, isDark),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            decoration: item.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color: item.isCompleted
                                                ? (isDark ? Colors.white38 : Colors.black38)
                                                : (isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
                                        if (item.note != null && item.note!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            item.note!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, int index, Color accent, bool isDark) {
    final selected = _filterIndex == index;
    return GestureDetector(
      onTap: () {
        AppHaptics.selectionClick();
        setState(() => _filterIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? accent
              : (isDark ? const Color(0xFF242831) : const Color(0xFFE9EDF4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
