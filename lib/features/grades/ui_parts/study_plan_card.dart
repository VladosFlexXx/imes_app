part of '../../home/tab_grades.dart';

class _StudyPlanCard extends StatelessWidget {
  final StudyPlanItem item;

  const _StudyPlanCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chips = <Widget>[];

    if (item.control.trim().isNotEmpty) {
      chips.add(_Chip(text: item.control.trim()));
    }
    if (item.code.trim().isNotEmpty) {
      chips.add(_Chip(text: item.code.trim()));
    }
    if (item.totalHours.trim().isNotEmpty) {
      chips.add(_Chip(text: '${item.totalHours.trim()} ч'));
    }
    if (item.lectures.trim().isNotEmpty && item.lectures.trim() != '0') {
      chips.add(_Chip(text: 'Лек: ${item.lectures.trim()}'));
    }
    if (item.practices.trim().isNotEmpty && item.practices.trim() != '0') {
      chips.add(_Chip(text: 'Практ: ${item.practices.trim()}'));
    }
    if (item.selfWork.trim().isNotEmpty && item.selfWork.trim() != '0') {
      chips.add(_Chip(text: 'СРС: ${item.selfWork.trim()}'));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1A1E23), Color(0xFF171B21)]
              : const [Color(0xFFF1F3F7), Color(0xFFE9EDF4)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.95)
                      : cs.onSurface.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 8),
              if (chips.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        ),
      ),
    );
  }
}
