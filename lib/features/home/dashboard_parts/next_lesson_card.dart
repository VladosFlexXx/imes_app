part of '../tab_dashboard.dart';

class _NextLessonCard extends StatelessWidget {
  final Lesson? lesson;
  final DateTime? date;
  final String? subtitle;
  final VoidCallback onOpenSchedule;
  final bool skeletonize;
  final bool areTodayLessonsDone;
  final List<Lesson> tomorrowLessons;
  final DateTime? tomorrowDate;

  const _NextLessonCard({
    required this.lesson,
    this.date,
    required this.subtitle,
    required this.onOpenSchedule,
    required this.skeletonize,
    this.areTodayLessonsDone = false,
    this.tomorrowLessons = const [],
    this.tomorrowDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _dashboardAccent(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final density = appDensityOf(context);

    final cardBg = isAmoled
        ? Colors.black
        : (isDark ? const Color(0xFF111317) : const Color(0xFFEDEEF0));
    final innerBg = isAmoled
        ? const Color(0xFF0B0D12)
        : (isDark ? const Color(0xFF1A1D23) : const Color(0xFFE6E7EA));
    final mainText = isDark ? Colors.white : const Color(0xFF1E2430);
    final subText = isDark
        ? Colors.white.withValues(alpha: 0.76)
        : const Color(0xFF626A78);
    final isOngoing = subtitle != null && subtitle!.startsWith('Идёт сейчас');

    final statusChipBg = isOngoing
        ? const Color(0xFF22C55E).withValues(alpha: isDark ? 0.22 : 0.14)
        : (isDark ? const Color(0xFF0F5A34) : const Color(0xFFDDF8E8));
    final statusChipBorder = isOngoing
        ? const Color(0xFF22C55E).withValues(alpha: 0.55)
        : (isDark ? const Color(0xFF19A864) : const Color(0xFF7EDFA8));
    final statusChipText = isOngoing
        ? const Color(0xFF22C55E)
        : (isDark ? const Color(0xFF74FFB6) : const Color(0xFF0B8F4B));

    if (areTodayLessonsDone && !skeletonize) {
      return _buildEveningCard(
        context,
        theme,
        accent,
        isDark,
        isAmoled,
        density,
        cardBg,
        innerBg,
        mainText,
        subText,
      );
    }

    if (lesson == null) {
      return Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        color: cardBg,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isAmoled
                    ? accent.withValues(alpha: 0.35)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08)),
                width: isAmoled ? 1.2 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.coffee_outlined, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: skeletonize
                          ? const _DashSkLine(width: 180, height: 22)
                          : Text(
                              'Ближайших пар нет',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: mainText,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (skeletonize)
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashSkLine(width: double.infinity, height: 16),
                      SizedBox(height: 6),
                      _DashSkLine(width: 260, height: 16),
                    ],
                  )
                else
                  Text(
                    'Можно немного выдохнуть или проверить расписание на другие дни.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: subText),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenSchedule,
                    icon: const Icon(Icons.view_agenda_outlined),
                    label: const Text('Открыть расписание'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: (skeletonize || lesson == null)
              ? null
              : () {
                  AppHaptics.selectionClick();
                  showLessonDetailsSheet(
                    context,
                    lesson: lesson!,
                    lessonDate: date ?? DateTime.now(),
                  );
                },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isAmoled
                    ? accent.withValues(alpha: 0.35)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.09)),
                width: isAmoled ? 1.2 : 1.0,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(density.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: skeletonize
                            ? const _DashSkLine(width: 160, height: 22)
                            : Text(
                                'Ближайшая пара',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: mainText,
                                ),
                              ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: statusChipBg,
                            border: Border.all(color: statusChipBorder),
                          ),
                          child: skeletonize
                              ? const _DashSkLine(width: 90, height: 14)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isOngoing) ...[
                                      const _NextLessonPulsingDot(size: 6.5),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      subtitle!,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: statusChipText,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: innerBg,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: skeletonize
                                ? const Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _DashSkLine(
                                        width: double.infinity,
                                        height: 28,
                                      ),
                                      SizedBox(height: 8),
                                      _DashSkLine(width: 220, height: 28),
                                    ],
                                  )
                                : Text(
                                    lesson!.subject,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: mainText,
                                          height: 1.12,
                                        ),
                                  ),
                          ),
                          if (lesson!.type.trim().isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _TypeBadge(text: lesson!.type, accent: accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (skeletonize)
                        const _DashSkLine(width: 120, height: 16)
                      else
                        Text(
                          'чётная неделя',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: subText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: LessonNotesStorage.revision,
                        builder: (context, _) {
                          final hasNote = !skeletonize &&
                              date != null &&
                              lesson != null &&
                              LessonNotesStorage.hasNoteSync(
                                date!,
                                lesson!.subject,
                                lesson!.time,
                              );
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Pill(
                                icon: Icons.access_time_rounded,
                                text: lesson!.time,
                                skeletonize: skeletonize,
                                isDark: isDark,
                              ),
                              _Pill(
                                icon: Icons.place_outlined,
                                text: lesson!.place,
                                skeletonize: skeletonize,
                                isDark: isDark,
                                onTap: skeletonize
                                    ? null
                                    : () {
                                        AppHaptics.lightImpact();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => CampusFloorPlanScreen(
                                              initialRoom: lesson!.place,
                                            ),
                                          ),
                                        );
                                      },
                              ),
                              if (hasNote)
                                _Pill(
                                  icon: Icons.edit_note_rounded,
                                  text: 'ДЗ / Заметка',
                                  skeletonize: false,
                                  isDark: isDark,
                                  accentColor: const Color(0xFFEAB308),
                                ),
                            ],
                          );
                        },
                      ),
                      if (lesson!.teacher.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: skeletonize
                                ? null
                                : () {
                                    showLessonDetailsSheet(
                                      context,
                                      lesson: lesson!,
                                      lessonDate: date ?? DateTime.now(),
                                    );
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    color: accent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: skeletonize
                                        ? const _DashSkLine(width: 260, height: 18)
                                        : Text(
                                            lesson!.teacher,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.90)
                                                  : const Color(0xFF4E5663),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpenSchedule,
                        icon: const Icon(Icons.menu_book_outlined),
                        label: const Text('Открыть расписание'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    if (lesson != null && !skeletonize) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Добавить задание / ДЗ',
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.add_task_rounded),
                        onPressed: () {
                          AppHaptics.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HomeworkScreen(
                                initialSubject: lesson!.subject,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  String _pairWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'пара';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'пары';
    }
    return 'пар';
  }

  Widget _buildEveningCard(
    BuildContext context,
    ThemeData theme,
    Color accent,
    bool isDark,
    bool isAmoled,
    AppDensityMetrics density,
    Color cardBg,
    Color innerBg,
    Color mainText,
    Color subText,
  ) {
    final t = theme.textTheme;
    final hasTomorrowLessons = tomorrowLessons.isNotEmpty;

    String startStr = '';
    String endStr = '';
    if (hasTomorrowLessons) {
      startStr = tomorrowLessons.first.time.split('-').first.trim().replaceAll('.', ':');
      final lastTime = tomorrowLessons.last.time;
      final pieces = lastTime.split('-');
      endStr = pieces.length > 1 ? pieces[1].trim().replaceAll('.', ':') : lastTime;
    }

    final cardBorder = isAmoled
        ? accent.withValues(alpha: 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08));

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: cardBg,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: cardBorder,
            width: isAmoled ? 1.2 : 1.0,
          ),
        ),
        padding: EdgeInsets.all(density.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasTomorrowLessons
                      ? Icons.nightlight_round
                      : Icons.weekend_outlined,
                  color: accent,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasTomorrowLessons
                        ? 'Пары на сегодня всё 🎉'
                        : 'Завтра выходной 🏖',
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: mainText,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.40),
                    ),
                  ),
                  child: Text(
                    hasTomorrowLessons ? 'Завтра к $startStr' : 'Отдых',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (hasTomorrowLessons) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _TomorrowChip(
                    icon: Icons.auto_stories_outlined,
                    label: '${tomorrowLessons.length} ${_pairWord(tomorrowLessons.length)}',
                    isDark: isDark,
                  ),
                  _TomorrowChip(
                    icon: Icons.alarm_rounded,
                    label: 'Начало в $startStr',
                    isDark: isDark,
                  ),
                  _TomorrowChip(
                    icon: Icons.flag_outlined,
                    label: 'Домой в $endStr',
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: innerBg,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (int i = 0; i < tomorrowLessons.length; i++) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            AppHaptics.lightImpact();
                            showLessonDetailsSheet(
                              context,
                              lesson: tomorrowLessons[i],
                              lessonDate: tomorrowDate ??
                                  DateTime.now().add(const Duration(days: 1)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: accent.withValues(
                                      alpha: isDark ? 0.20 : 0.12,
                                    ),
                                  ),
                                  child: Text(
                                    tomorrowLessons[i].time.replaceAll('.', ':'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      color: accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tomorrowLessons[i].subject,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: mainText,
                                    ),
                                  ),
                                ),
                                if (tomorrowLessons[i].place.trim().isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    tomorrowLessons[i].place.trim(),
                                    style: t.bodySmall?.copyWith(
                                      color: subText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (i < tomorrowLessons.length - 1)
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenSchedule,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: const Text(
                    'Расписание на завтра',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Завтра пар нет — отличный повод выспаться, отдохнуть или закрыть долги по учебе!',
                style: t.bodyMedium?.copyWith(color: subText),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenSchedule,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: const Text('Посмотреть расписание'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TomorrowChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _TomorrowChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isDark ? const Color(0xFF22262E) : const Color(0xFFE2E6EE),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark
                ? Colors.white.withValues(alpha: 0.70)
                : Colors.black.withValues(alpha: 0.65),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String text;
  final Color accent;

  const _TypeBadge({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: accent.withValues(alpha: 0.18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool skeletonize;
  final bool isDark;
  final VoidCallback? onTap;
  final Color? accentColor;

  const _Pill({
    required this.icon,
    required this.text,
    required this.skeletonize,
    required this.isDark,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = accentColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.95)
            : const Color(0xFF38404D));
    final bgColor = accentColor != null
        ? accentColor!.withValues(alpha: isDark ? 0.22 : 0.12)
        : (isDark ? const Color(0xFF3A3A3D) : const Color(0xFFECEDEF));
    final borderColor = accentColor != null
        ? accentColor!.withValues(alpha: 0.45)
        : (isDark
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.10));
    final iconColor = accentColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.88)
            : const Color(0xFF555D69));

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bgColor,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          if (skeletonize)
            const _DashSkLine(width: 90, height: 16)
          else
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: fgColor,
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}

class _NextLessonPulsingDot extends StatefulWidget {
  final double size;

  const _NextLessonPulsingDot({
    this.size = 7.0,
  });

  static const Color color = Color(0xFF22C55E);

  @override
  State<_NextLessonPulsingDot> createState() => _NextLessonPulsingDotState();
}

class _NextLessonPulsingDotState extends State<_NextLessonPulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (themeController.reduceAnimations) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: _NextLessonPulsingDot.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final scale = 0.82 + (0.32 * _animation.value);
        final alpha = 0.50 + (0.50 * _animation.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _NextLessonPulsingDot.color.withValues(alpha: alpha),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      _NextLessonPulsingDot.color.withValues(alpha: 0.55 * _animation.value),
                  blurRadius: 6 * _animation.value,
                  spreadRadius: 1 * _animation.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
