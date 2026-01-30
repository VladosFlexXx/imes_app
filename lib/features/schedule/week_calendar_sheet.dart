import 'package:flutter/material.dart';
import 'week_utils.dart';

class WeekCalendarSheet extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  const WeekCalendarSheet({
    super.key,
    required this.selectedDate,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime selectedDate,
    required ValueChanged<DateTime> onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WeekCalendarSheet(
        selectedDate: selectedDate,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<WeekCalendarSheet> createState() => _WeekCalendarSheetState();
}

class _WeekCalendarSheetState extends State<WeekCalendarSheet> {
  late DateTime _displayMonth; // 1-е число месяца
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = WeekUtils.dateOnly(widget.selectedDate);
    _displayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
    });
  }

  List<DateTime> _buildGridDays(DateTime monthFirst) {
    final first = DateTime(monthFirst.year, monthFirst.month, 1);
    final start = first.subtract(Duration(days: first.weekday - DateTime.monday));
    return List.generate(42, (i) => start.add(Duration(days: i)));
  }

  String _monthTitle(DateTime d) {
    const months = [
      'Январь','Февраль','Март','Апрель','Май','Июнь',
      'Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentWeekStart = WeekUtils.weekStart(now);
    final currentWeekEnd = WeekUtils.weekEnd(now);

    final selectedWeekStart = WeekUtils.weekStart(_selectedDate);
    final selectedWeekEnd = WeekUtils.weekEnd(_selectedDate);

    final days = _buildGridDays(_displayMonth);

    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(
                    _monthTitle(_displayMonth),
                    textAlign: TextAlign.center,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ],
            ),

            const SizedBox(height: 8),

            // Weekday row
            Row(
              children: const [
                _W('ПН'), _W('ВТ'), _W('СР'), _W('ЧТ'), _W('ПТ'), _W('СБ'), _W('ВС'),
              ],
            ),
            const SizedBox(height: 8),

            // Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, i) {
                final d = days[i];
                final isInMonth = d.month == _displayMonth.month;

                final isInSelectedWeek =
                    WeekUtils.inRange(d, selectedWeekStart, selectedWeekEnd);
                final isInCurrentWeek =
                    WeekUtils.inRange(d, currentWeekStart, currentWeekEnd);

                // приоритет цвета: и текущая и выбранная → tertiary
                Color? bg;
                Color? fg = isInMonth ? null : Theme.of(context).disabledColor;

                if (isInSelectedWeek && isInCurrentWeek) {
                  bg = cs.tertiaryContainer;
                  fg = cs.onTertiaryContainer;
                } else if (isInSelectedWeek) {
                  bg = cs.primaryContainer;
                  fg = cs.onPrimaryContainer;
                } else if (isInCurrentWeek) {
                  bg = cs.secondaryContainer;
                  fg = cs.onSecondaryContainer;
                }

                final isSelectedDay = WeekUtils.isSameDay(d, _selectedDate);

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedDate = WeekUtils.dateOnly(d)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelectedDay
                          ? Border.all(color: cs.primary, width: 2)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${d.day}',
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Footer buttons
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDate = WeekUtils.dateOnly(DateTime.now());
                      _displayMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
                    });
                  },
                  icon: const Icon(Icons.today),
                  label: const Text('Текущая неделя'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    widget.onSelected(_selectedDate);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Показать'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _W extends StatelessWidget {
  final String t;
  const _W(this.t);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          t,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}
