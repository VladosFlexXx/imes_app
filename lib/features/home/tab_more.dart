import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:vuz_app/core/auth/session_manager.dart';
import 'package:vuz_app/core/demo/demo_mode.dart';
import 'package:vuz_app/core/network/eios_client.dart';
import 'package:vuz_app/features/auth/login_webview.dart';
import 'package:vuz_app/features/settings/settings_screen.dart';

class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  static const _storage = FlutterSecureStorage();
  String _versionText = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      final b = info.buildNumber.trim();
      if (!mounted) return;
      setState(() {
        _versionText = (v.isNotEmpty && b.isNotEmpty) ? '$v+$b' : v;
      });
    } catch (_) {}
  }

  Future<void> _logout() async {
    await _storage.delete(key: 'cookie_header');
    await DemoMode.instance.setEnabled(false);
    EiosClient.instance.invalidateCookieCache();
    SessionManager.instance.reset();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginWebViewScreen()),
      (_) => false,
    );
  }

  void _showAbout() {
    final t = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'О приложении',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Text(
                  'ЭИОС ИМЭС',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _versionText.isEmpty ? 'Версия: —' : 'Версия: $_versionText',
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF1A1E23), Color(0xFF171B21)]
          : const [Color(0xFFF1F3F7), Color(0xFFE9EDF4)],
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 106),
          children: [
            Text('Еще', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: cardGradient,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(
                      'Настройки',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Параметры приложения'),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.74)
                          : cs.onSurface.withValues(alpha: 0.72),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(
                      'О приложении',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      _versionText.isEmpty ? 'Версия' : 'Версия $_versionText',
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.74)
                          : cs.onSurface.withValues(alpha: 0.72),
                    ),
                    onTap: _showAbout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: cardGradient,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Вузовские активности',
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white.withValues(alpha: 0.96) : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Здесь позже появятся быстрые переходы на опросы, олимпиады и другие активности вуза.',
                      style: t.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.68)
                            : cs.onSurface.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FutureActionChip(icon: Icons.poll_outlined, label: 'Опросы'),
                        _FutureActionChip(icon: Icons.emoji_events_outlined, label: 'Олимпиады'),
                        _FutureActionChip(icon: Icons.campaign_outlined, label: 'Анонсы'),
                        _FutureActionChip(icon: Icons.groups_2_outlined, label: 'Мероприятия'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5C5C),
                side: const BorderSide(color: Color(0xFF5A1313), width: 1.2),
                backgroundColor:
                    isDark ? const Color(0xFF1C0707) : const Color(0xFFFFEAEA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Выйти из аккаунта',
                style: t.titleSmall?.copyWith(
                  color: const Color(0xFFFF5C5C),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FutureActionChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isDark ? const Color(0xFF252A34) : const Color(0xFFE2E6EE),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark
                ? Colors.white.withValues(alpha: 0.82)
                : cs.onSurface.withValues(alpha: 0.76),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: t.labelMedium?.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.82)
                  : cs.onSurface.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
