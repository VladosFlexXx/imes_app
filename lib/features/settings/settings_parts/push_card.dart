part of '../settings_screen.dart';

class _PushCard extends StatefulWidget {
  const _PushCard();

  @override
  State<_PushCard> createState() => _PushCardState();
}

class _PushCardState extends State<_PushCard> {
  bool _busy = false;

  Future<void> _openServerSheet(NotificationService ns) async {
    final cfg = ns.serverConfig.value;
    final urlCtl = TextEditingController(text: cfg.baseUrl);
    final secretCtl = TextEditingController(text: cfg.registerSecret);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Push-сервер',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtl,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'http://192.168.1.10:8080',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: secretCtl,
                  decoration: const InputDecoration(
                    labelText: 'Register secret',
                    hintText: 'секрет из REGISTER_SECRET',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await ns.saveServerConfig(
                            baseUrl: urlCtl.text,
                            registerSecret: secretCtl.text,
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    urlCtl.dispose();
    secretCtl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ns = NotificationService.instance;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            ns.enabled,
            ns.status,
            ns.lastError,
            ns.serverConfig,
            ns.lastPing,
            ns.lastRegister,
          ]),
          builder: (context, _) {
            final on = ns.enabled.value;
            final status = ns.status.value;
            final err = ns.lastError.value;
            final cfg = ns.serverConfig.value;

            return Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: Text(
                    'Включить пуши',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(status),
                  value: on,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  onChanged: (v) async {
                    try {
                      await ns.setEnabled(v);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Не удалось изменить настройку пушей: $e',
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Push-сервер'),
                  subtitle: Text(
                    cfg.baseUrl.trim().isEmpty
                        ? 'Не задан'
                        : cfg.baseUrl.trim(),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.74)
                        : cs.onSurface.withValues(alpha: 0.72),
                  ),
                  onTap: () => _openServerSheet(ns),
                ),
                if (err != null && err.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cs.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        err,
                        style: t.bodySmall?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? const Color(0xFFCFD8FF)
                                : cs.primary,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.10),
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    final r = await ns.pingServer();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(r.message)),
                                    );
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          icon: const Icon(Icons.wifi_tethering_outlined),
                          label: const Text('Пинг'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _busy || !on
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    final r = await ns.registerNow();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(r.message)),
                                    );
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          icon: const Icon(Icons.sync),
                          label: const Text('Перерег.'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
