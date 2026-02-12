import 'package:flutter/material.dart';
import 'package:vuz_app/ui/app_theme.dart';

import 'inbox_repository.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  final _repo = NotificationInboxRepository.instance;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _repo.init();
    await _syncWeb();
  }

  Future<void> _syncWeb() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final added = await _repo.syncFromWeb(maxItems: 30);
      if (!mounted) return;
      if (added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Синхронизировано: +$added уведомл.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось синхронизировать: $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
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
      case 'web':
        return 'ЭИОС';
      case 'push':
      default:
        return 'Изменения';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final accent = appAccentOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF1A1E23), Color(0xFF171B21)]
          : const [Color(0xFFF1F3F7), Color(0xFFE9EDF4)],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Центр уведомлений'),
        actions: [
          IconButton(
            tooltip: 'Синхр. из ЭИОС',
            onPressed: _syncing ? null : _syncWeb,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
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
            return RefreshIndicator(
              onRefresh: _syncWeb,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Center(
                      child: Text(
                        'Пока пусто',
                        style: t.titleMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _syncWeb,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  decoration: BoxDecoration(
                    gradient: cardGradient,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
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
                                        ? const Color(0xFF5E6677)
                                        : accent,
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
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
