import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app.dart';
import '../../../ui/app_haptics.dart';
import '../../../ui/app_theme.dart';
import '../models.dart';
import '../schedule_share_service.dart';
import '../week_parity.dart';

enum _ShareScope { day, week }

void showScheduleShareSheet(
  BuildContext context, {
  required DateTime selectedDate,
  required List<Lesson> selectedDayLessons,
  required DateTime weekStart,
  required Map<int, List<Lesson>> weekLessons,
  required WeekParity parity,
}) {
  AppHaptics.lightImpact();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.28),
    builder: (ctx) => _ScheduleShareSheetContent(
      selectedDate: selectedDate,
      selectedDayLessons: selectedDayLessons,
      weekStart: weekStart,
      weekLessons: weekLessons,
      parity: parity,
    ),
  );
}

class _ScheduleShareSheetContent extends StatefulWidget {
  final DateTime selectedDate;
  final List<Lesson> selectedDayLessons;
  final DateTime weekStart;
  final Map<int, List<Lesson>> weekLessons;
  final WeekParity parity;

  const _ScheduleShareSheetContent({
    required this.selectedDate,
    required this.selectedDayLessons,
    required this.weekStart,
    required this.weekLessons,
    required this.parity,
  });

  @override
  State<_ScheduleShareSheetContent> createState() =>
      _ScheduleShareSheetContentState();
}

class _ScheduleShareSheetContentState
    extends State<_ScheduleShareSheetContent> {
  _ShareScope _scope = _ShareScope.day;
  String? _noticeText;

  static const List<String> _shortWeekdays = [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];

  static String _two(int x) => x.toString().padLeft(2, '0');

  String _formatDateShort(DateTime d) => '${_two(d.day)}.${_two(d.month)}';

  String _getText() {
    if (_scope == _ShareScope.day) {
      return ScheduleShareService.formatDay(
        date: widget.selectedDate,
        lessons: widget.selectedDayLessons,
        parity: widget.parity,
      );
    } else {
      return ScheduleShareService.formatWeek(
        weekStart: widget.weekStart,
        weekLessons: widget.weekLessons,
        parity: widget.parity,
      );
    }
  }

  void _setScope(_ShareScope scope) {
    if (_scope == scope) return;
    AppHaptics.selectionClick();
    setState(() {
      _scope = scope;
      _noticeText = null;
    });
  }

  void _showNotice(String text) {
    setState(() => _noticeText = text);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _noticeText = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final accent = appAccentOf(context);

    final text = _getText();

    final dayShort = _shortWeekdays[widget.selectedDate.weekday - 1];
    final dayLabel = '$dayShort, ${_formatDateShort(widget.selectedDate)}';

    final weekEnd = widget.weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${_formatDateShort(widget.weekStart)} – ${_formatDateShort(weekEnd)}';

    final sheetBg = isAmoled
        ? Colors.black
        : (isDark ? const Color(0xFF1E2228) : const Color(0xFFFFFFFF));

    final cardBorder = isAmoled
        ? accent.withValues(alpha: 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08));

    return Container(
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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

              // Шапка шторки
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.share_rounded,
                      size: 20,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Поделиться расписанием',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      AppHaptics.lightImpact();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Переключатель диапазона: День / Неделя
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF14171C)
                      : const Color(0xFFEDF1F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ScopeTab(
                        label: 'День ($dayLabel)',
                        icon: Icons.today_rounded,
                        active: _scope == _ShareScope.day,
                        accent: accent,
                        onTap: () => _setScope(_ShareScope.day),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _ScopeTab(
                        label: 'Неделя ($weekLabel)',
                        icon: Icons.date_range_rounded,
                        active: _scope == _ShareScope.week,
                        accent: accent,
                        onTap: () => _setScope(_ShareScope.week),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Поле предпросмотра
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? const Color(0xFF14171C)
                      : const Color(0xFFF3F6FA),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.45,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.88)
                          : cs.onSurface.withValues(alpha: 0.88),
                    ),
                  ),
                ),
              ),

              if (_noticeText != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _noticeText!,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Кнопки действий: Скопировать и Поделиться
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.black.withValues(alpha: 0.14),
                        ),
                      ),
                      onPressed: () async {
                        AppHaptics.lightImpact();
                        await Clipboard.setData(ClipboardData(text: text));
                        _showNotice('Текст скопирован в буфер!');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text(
                        'Скопировать',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        AppHaptics.mediumImpact();
                        final box = context.findRenderObject() as RenderBox?;
                        final origin = box != null
                            ? box.localToGlobal(Offset.zero) & box.size
                            : null;
                        await Share.share(
                          text,
                          sharePositionOrigin: origin,
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text(
                        'Поделиться',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _ScopeTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context).textTheme;

    return Material(
      color: active
          ? (isDark ? const Color(0xFF282D36) : Colors.white)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      elevation: active ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active
                    ? accent
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.5)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelMedium?.copyWith(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.65)
                            : Colors.black.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
