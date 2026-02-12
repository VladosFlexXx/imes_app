part of '../tab_dashboard.dart';

class _GreetingHero extends StatelessWidget {
  final String? fullName;
  final String? avatarUrl;
  final int lessonsToday;
  final String? group;
  final String? level;
  final bool evenWeek;
  final int progressPercent;
  final double progressValue;
  final double? avgGrade;
  final int? attendance;
  final int? courseNumber;
  final bool skeletonize;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
  final bool hasUnreadNotifications;

  const _GreetingHero({
    required this.fullName,
    required this.avatarUrl,
    required this.lessonsToday,
    required this.group,
    required this.level,
    required this.evenWeek,
    required this.progressPercent,
    required this.progressValue,
    required this.avgGrade,
    required this.attendance,
    required this.courseNumber,
    required this.skeletonize,
    required this.onOpenProfile,
    required this.onOpenNotifications,
    required this.hasUnreadNotifications,
  });

  String _firstName(String? fullName) {
    if (fullName == null) return 'друг';
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'друг';
    if (parts.length >= 2) return parts[1];
    return parts.first;
  }

  String _greetingForNow() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Доброе утро';
    if (h >= 12 && h < 18) return 'Добрый день';
    if (h >= 18 && h < 23) return 'Добрый вечер';
    return 'Доброй ночи';
  }

  String _weekdayRu(int wd) {
    switch (wd) {
      case DateTime.monday:
        return 'Понедельник';
      case DateTime.tuesday:
        return 'Вторник';
      case DateTime.wednesday:
        return 'Среда';
      case DateTime.thursday:
        return 'Четверг';
      case DateTime.friday:
        return 'Пятница';
      case DateTime.saturday:
        return 'Суббота';
      case DateTime.sunday:
      default:
        return 'Воскресенье';
    }
  }

  String _monthRu(int m) {
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

  String _fmtOne(double? v) {
    if (v == null) return '—';
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final baseScale = MediaQuery.textScalerOf(context).scale(1.0);
    final targetScale = (baseScale * 0.94).clamp(0.75, 1.0).toDouble();
    final now = DateTime.now();
    final name = _firstName(fullName);
    final greeting = _greetingForNow();
    final accent = _dashboardAccent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final title =
        '${_weekdayRu(now.weekday)}, ${now.day} ${_monthRu(now.month)}';
    final subtitle = evenWeek ? 'чётная неделя' : 'нечётная неделя';
    final profileLine = [
      if (group != null && group!.trim().isNotEmpty) group!.trim(),
      if (level != null && level!.trim().isNotEmpty) level!.trim(),
    ].join(' · ');

    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(targetScale)),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF1A1A1D), Color(0xFF242426)]
                : [
                    accent.withValues(alpha: 0.92),
                    accent.withValues(alpha: 0.84),
                  ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.34),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : accent.withValues(alpha: 0.22),
              blurRadius: isDark ? 22 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -28,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.13),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onOpenProfile,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.68),
                              ),
                            ),
                            child: ClipOval(
                              child: AuthAvatar(
                                avatarUrl: avatarUrl,
                                radius: 33,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            if (skeletonize)
                              const _DashSkLine(width: 170, height: 26)
                            else
                              Text(
                                name,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            if (profileLine.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              if (skeletonize)
                                const _DashSkLine(width: 150, height: 14)
                              else
                                Text(
                                  profileLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.76,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onOpenNotifications,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  size: 28,
                                ),
                                if (hasUnreadNotifications)
                                  Positioned(
                                    right: 1,
                                    top: 2,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.16 : 0.36,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (skeletonize)
                          const _DashSkLine(width: 220, height: 30)
                        else
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        const SizedBox(height: 4),
                        if (skeletonize)
                          const _DashSkLine(width: 130, height: 18)
                        else
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Прогресс недели',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            if (skeletonize)
                              const _DashSkLine(width: 44, height: 20)
                            else
                              Text(
                                '$progressPercent%',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 9,
                            value: progressValue.clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withValues(
                              alpha: isDark ? 0.18 : 0.36,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatBox(
                        title: 'Пары сегодня',
                        value: '$lessonsToday',
                        skeletonize: skeletonize,
                        accent: accent,
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        title: 'Средний балл',
                        value: _fmtOne(avgGrade),
                        skeletonize: skeletonize,
                        accent: accent,
                        emphasize: true,
                      ),
                      const SizedBox(width: 10),
                      _StatBox(
                        title: attendance != null
                            ? 'Посещаемость'
                            : (courseNumber != null ? 'Курс' : 'Посещаемость'),
                        value: attendance != null
                            ? '$attendance%'
                            : (courseNumber?.toString() ?? '—'),
                        skeletonize: skeletonize,
                        accent: accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final bool skeletonize;
  final Color accent;
  final bool emphasize;

  const _StatBox({
    required this.title,
    required this.value,
    required this.skeletonize,
    required this.accent,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.16),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.34),
          ),
        ),
        child: Column(
          children: [
            if (skeletonize)
              const _DashSkLine(width: 46, height: 26)
            else
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            const SizedBox(height: 4),
            if (skeletonize)
              const _DashSkLine(width: 68, height: 14)
            else
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
