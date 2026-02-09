import 'package:flutter/material.dart';

import 'inbox_repository.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  final _repo = NotificationInboxRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.init();
  }

  String _fmtDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'system':
        return 'Система';
      case 'push':
      default:
        return 'Изменения';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Центр уведомлений'),
        actions: [
          IconButton(
            tooltip: 'Прочитать всё',
            onPressed: () => _repo.markAllRead(),
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _repo,
        builder: (context, _) {
          final items = _repo.items;
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Пока пусто',
                style: t.titleMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.70),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _repo.markRead(item.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.isRead
                                    ? cs.outlineVariant
                                    : cs.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _sourceLabel(item.source),
                              style: t.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _fmtDate(item.createdAtMs),
                              style: t.labelSmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.66),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          style: t.titleMedium?.copyWith(
                            fontWeight: item.isRead
                                ? FontWeight.w700
                                : FontWeight.w900,
                          ),
                        ),
                        if (item.body.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.body,
                            style: t.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
