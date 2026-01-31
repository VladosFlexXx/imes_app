import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../grades/models.dart';
import '../grades/repository.dart';

enum GradesFilter { all, noGrade, withGrade }

class GradesTab extends StatefulWidget {
  const GradesTab({super.key});

  @override
  State<GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<GradesTab> {
  final repo = GradesRepository.instance;

  GradesFilter _filter = GradesFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    repo.initAndRefresh();
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  bool _hasGrade(GradeCourse c) {
    final g = c.grade;
    return g != null && g.trim().isNotEmpty;
  }

  bool _matchesFilter(GradeCourse c) {
    switch (_filter) {
      case GradesFilter.noGrade:
        return !_hasGrade(c);
      case GradesFilter.withGrade:
        return _hasGrade(c);
      case GradesFilter.all:
      default:
        return true;
    }
  }

  bool _matchesQuery(GradeCourse c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.courseName.toLowerCase().contains(q);
  }

  List<GradeCourse> _apply(List<GradeCourse> list) {
    final out = list.where(_matchesFilter).where(_matchesQuery).toList();

    // по умолчанию — без оценки сверху
    out.sort((a, b) {
      final aHas = _hasGrade(a);
      final bHas = _hasGrade(b);
      if (aHas == bHas) {
        return a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase());
      }
      return aHas ? 1 : -1;
    });

    return out;
  }

  void _openDetailsSheet(GradeCourse course) {
    final t = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final grade = course.grade?.trim();
        final percent = course.percent?.trim();
        final range = course.range?.trim();
        final feedback = course.feedback?.trim();

        final hasLink =
            course.courseUrl != null && course.courseUrl!.trim().isNotEmpty;

        // показываем все колонки, кроме "Курс/Course" и пустых
        final details = course.columns.entries
            .where((e) => e.value.trim().isNotEmpty)
            .where((e) {
              final k = e.key.trim().toLowerCase();
              return k != 'курс' && k != 'course';
            })
            .toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                course.courseName,
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              if (grade != null && grade.isNotEmpty) ...[
                Row(
                  children: [
                    Text('Итог:', style: t.titleMedium),
                    const SizedBox(width: 10),
                    _GradeBadge(value: grade),
                  ],
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(
                  'Итоговая оценка отсутствует',
                  style: t.titleMedium,
                ),
                const SizedBox(height: 12),
              ],

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (percent != null && percent.isNotEmpty)
                    _Chip(text: 'Процент: $percent'),
                  if (range != null && range.isNotEmpty)
                    _Chip(text: 'Диапазон: $range'),
                ],
              ),

              if (feedback != null && feedback.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Комментарий',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(feedback),
              ],

              if (details.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Детали',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: _withDividers(
                        details
                            .map(
                              (e) => ListTile(
                                dense: true,
                                title: Text(
                                  e.key,
                                  style: t.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(e.value),
                              ),
                            )
                            .toList(),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withOpacity(0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              if (hasLink) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _GradeDetailsWeb(
                          url: course.courseUrl!,
                          title: course.courseName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Открыть подробный отчёт'),
                ),
              ],

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  static List<Widget> _withDividers(List<Widget> children, Widget divider) {
    final out = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) out.add(divider);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final list = _apply(repo.courses);

        return Scaffold(
          appBar: AppBar(
            title: Text(repo.loading ? 'Оценки (обновление...)' : 'Оценки'),
            bottom: repo.loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Обновить',
                onPressed: repo.loading ? null : () => repo.refresh(force: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => repo.refresh(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                // ✅ Тонкая строка статуса (вместо UpdateBanner)
                if (repo.updatedAt != null || repo.lastError != null) ...[
                  Row(
                    children: [
                      Icon(
                        repo.lastError != null
                            ? Icons.warning_amber_rounded
                            : Icons.sync,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          repo.lastError != null
                              ? 'Не удалось обновить · показаны сохранённые данные'
                              : 'Обновлено: ${_fmtTime(repo.updatedAt!)} · данные из ЭИОС',
                          style: t.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // 🔍 Поиск
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Поиск по предметам',
                  ),
                ),
                const SizedBox(height: 10),

                // 🧩 Фильтры
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Все'),
                      selected: _filter == GradesFilter.all,
                      onSelected: (_) => setState(() => _filter = GradesFilter.all),
                    ),
                    ChoiceChip(
                      label: const Text('Без оценки'),
                      selected: _filter == GradesFilter.noGrade,
                      onSelected: (_) => setState(() => _filter = GradesFilter.noGrade),
                    ),
                    ChoiceChip(
                      label: const Text('С оценкой'),
                      selected: _filter == GradesFilter.withGrade,
                      onSelected: (_) => setState(() => _filter = GradesFilter.withGrade),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (repo.courses.isEmpty && !repo.loading) ...const [
                  SizedBox(height: 120),
                  Center(child: Text('Пока нет данных по оценкам')),
                ] else if (list.isEmpty) ...const [
                  SizedBox(height: 60),
                  Center(child: Text('Нет предметов по выбранному фильтру')),
                ] else ...[
                  for (final c in list)
                    _GradeCard(
                      course: c,
                      onTap: () => _openDetailsSheet(c),
                    ),
                ],

                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradeCard extends StatelessWidget {
  final GradeCourse course;
  final VoidCallback onTap;

  const _GradeCard({
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final grade = course.grade?.trim();
    final percent = course.percent?.trim();
    final range = course.range?.trim();

    final hasGrade = grade != null && grade.isNotEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Название слева, оценка справа
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      course.courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  if (hasGrade) ...[
                    const SizedBox(width: 10),
                    _GradeBadge(value: grade),
                  ] else ...[
                    const SizedBox(width: 10),
                    Text(
                      '—',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (percent != null && percent.isNotEmpty)
                    _Chip(text: 'Процент: $percent'),
                  if (range != null && range.isNotEmpty)
                    _Chip(text: 'Диапазон: $range'),
                  if ((percent == null || percent.isEmpty) &&
                      (range == null || range.isEmpty) &&
                      !hasGrade)
                    _Chip(text: 'Нет деталей'),
                ],
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Детали',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final String value;

  const _GradeBadge({required this.value});

  bool _looksNumeric(String s) {
    final v = s.replaceAll(',', '.').trim();
    final n = double.tryParse(v.replaceAll('%', '').trim());
    return n != null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isNumeric = _looksNumeric(value);

    final bg = isNumeric ? cs.primaryContainer : cs.secondaryContainer;
    final fg = isNumeric ? cs.onPrimaryContainer : cs.onSecondaryContainer;

    return Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withOpacity(0.12)),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: fg,
              height: 1.0,
            ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: cs.surfaceVariant.withOpacity(0.35),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _GradeDetailsWeb extends StatelessWidget {
  final String url;
  final String title;

  const _GradeDetailsWeb({
    required this.url,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
      ),
    );
  }
}
