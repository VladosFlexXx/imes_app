import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vuz_app/features/campus/contacts_screen.dart';
import 'package:vuz_app/features/campus/floor_plan_screen.dart';
import 'package:vuz_app/features/homework/homework_screen.dart';
import 'package:vuz_app/features/settings/settings_screen.dart';
import 'package:vuz_app/ui/app_haptics.dart';
import 'package:vuz_app/ui/app_theme.dart';
import 'package:vuz_app/app.dart';

class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  static final Uri _tgUri = Uri.parse('https://t.me/t3w11');
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
      if (!mounted) return;
      setState(() {
        _versionText = v;
      });
    } catch (_) {}
  }

  Future<void> _showAbout() async {
    const repoUrl = 'https://github.com/VladosFlexXx/imes_app';
    final repoUri = Uri.parse(repoUrl);
    final version = _versionText.trim().isEmpty ? '—' : _versionText.trim();

    if (!mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Мой ИМЭС',
      applicationVersion: version,
      applicationLegalese: 'Бета-версия.',
      children: [
        const SizedBox(height: 8),
        Text('Версия: $version'),
        const SizedBox(height: 8),
        const Text('Репозиторий (GitHub):'),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final ok = await launchUrl(
              repoUri,
              mode: LaunchMode.externalApplication,
            );
            if (!ok) {
              await Clipboard.setData(const ClipboardData(text: repoUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Не удалось открыть ссылку. URL скопирован')),
              );
            }
          },
          child: Text(
            repoUrl,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              decoration: TextDecoration.underline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.send_rounded, size: 22),
          title: const Text('Telegram'),
          subtitle: const Text('@t3w11'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () async {
            final ok = await launchUrl(
              _tgUri,
              mode: LaunchMode.externalApplication,
            );
            if (!ok) {
              await Clipboard.setData(
                const ClipboardData(text: 'https://t.me/t3w11'),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Не удалось открыть Telegram. Ссылка скопирована',
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        const Text('Credits'),
        const SizedBox(height: 4),
        const Text('Design & Development: Владислав Лобанов'),
        const Text('AI copilot: Codex (GPT-5)'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: repoUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ссылка на GitHub скопирована')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Скопировать ссылку'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final accent = appAccentOf(context);

    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF1A1E23), Color(0xFF171B21)]
          : const [Color(0xFFF1F3F7), Color(0xFFE9EDF4)],
    );

    final cardDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: isAmoled ? Colors.black : null,
      gradient: isAmoled ? null : cardGradient,
      border: Border.all(
        color: isAmoled
            ? accent.withValues(alpha: 0.35)
            : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08)),
        width: isAmoled ? 1.2 : 1.0,
      ),
    );

    final dividerColor = isAmoled
        ? Colors.black
        : (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 106),
          children: [
            Text('Еще', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Container(
              decoration: cardDecoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.contacts_outlined),
                    title: Text(
                      'Контакты ИМЭС',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Деканат, кафедры, часы работы'),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.74)
                          : cs.onSurface.withValues(alpha: 0.72),
                    ),
                    onTap: () {
                      AppHaptics.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CampusContactsScreen()),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: dividerColor,
                  ),
                  ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: Text(
                      'Навигатор по корпусу',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Поиск аудиторий и схема этажей'),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.74)
                          : cs.onSurface.withValues(alpha: 0.72),
                    ),
                    onTap: () {
                      AppHaptics.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CampusFloorPlanScreen()),
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    color: dividerColor,
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(
                      'Дедлайны и ДЗ',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Список задач, домашка и сроки сдачи'),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.74)
                          : cs.onSurface.withValues(alpha: 0.72),
                    ),
                    onTap: () {
                      AppHaptics.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HomeworkScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
            const SizedBox(height: 12),
            Container(
              decoration: cardDecoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Material(
                  color: Colors.transparent,
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
                    color: dividerColor,
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
          ),
        ),
            const SizedBox(height: 14),
            Container(
              decoration: cardDecoration,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Material(
                  color: Colors.transparent,
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
