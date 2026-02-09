import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../profile/models.dart';
import '../profile/repository.dart';
import '../settings/settings_screen.dart';
import '../notifications/inbox_repository.dart';
import '../notifications/notifications_center_screen.dart';

import 'package:vuz_app/core/network/eios_client.dart';
import 'package:vuz_app/core/demo/demo_mode.dart';

part '../profile/ui_parts/profile_header.dart';
part '../profile/ui_parts/profile_info_card.dart';
part '../profile/ui_parts/info_tile.dart';
part '../profile/ui_parts/copy_tile.dart';
part '../profile/ui_parts/skeleton_tile.dart';
part '../profile/ui_parts/skeleton_circle.dart';
part '../profile/ui_parts/skeleton_line.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final repo = ProfileRepository.instance;
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    repo.initAndRefresh();
  }

  static bool _isAuthExpiredError(Object? err) {
    if (err == null) return false;
    final s = err.toString().toLowerCase();
    // Moodle обычно редиректит на login/index.php?loginredirect=1
    return s.contains('loginredirect=1') ||
        s.contains('/login/index.php') ||
        s.contains('redirect loop detected');
  }

  Future<void> _logoutCookieOnly() async {
    // На экране профиля мы просто чистим куки/кэш.
    // Переход на экран логина делается глобально (HomeScreen ловит SessionManager),
    // но если пользователь нажмёт «Войти заново» — это отработает через WebView входа там же.
    await _storage.delete(key: 'cookie_header');
    await DemoMode.instance.setEnabled(false);
    EiosClient.instance.invalidateCookieCache();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final inbox = NotificationInboxRepository.instance;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final p = repo.profile;
        final authExpired = _isAuthExpiredError(repo.lastError);

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              if (authExpired) return;
              await repo.refresh(force: true);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 106),
              children: [
                if (repo.loading) ...[
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 12),
                ],
                if (authExpired) ...[
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сессия истекла',
                            style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Похоже, ЭИОС разлогинила тебя. Поэтому данные не обновляются и показывается старый кэш.',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () async {
                                  await _logoutCookieOnly();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Куки очищены. Открой вход и залогинься заново.',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.login),
                                label: const Text('Очистить куки'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ✅ Хедер профиля + тонкая строка "обновлено" (без жирного баннера)
                _ProfileHeader(profile: p),
                const SizedBox(height: 14),

                Text(
                  'Данные',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),

                _ProfileInfoCard(
                  profile: p,
                  onCopyRecordBook: (text) async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('№ зачётной скопирован'),
                        duration: Duration(milliseconds: 900),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Сервисы',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: inbox.unreadCount,
                        builder: (context, unread, _) {
                          return ListTile(
                            leading: const Icon(Icons.notifications_outlined),
                            title: Text(
                              'Центр уведомлений',
                              style: t.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              unread > 0
                                  ? 'Непрочитанных: $unread'
                                  : 'Последние уведомления по приложению',
                            ),
                            trailing: unread > 0
                                ? Badge(
                                    label: Text(
                                      unread > 99 ? '99+' : '$unread',
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationsCenterScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: Text(
                          'Настройки',
                          style: t.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: const Text(
                          'Автовход, пуши, тема и параметры приложения',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ✅ оставляем место внизу под будущие штуки
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}
