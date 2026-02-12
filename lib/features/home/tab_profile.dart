import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../ui/app_theme.dart';
import '../../ui/shimmer_skeleton.dart';

import '../profile/models.dart';
import '../profile/repository.dart';
import '../profile/widgets/auth_avatar.dart';

import 'package:vuz_app/core/network/eios_client.dart';
import 'package:vuz_app/core/demo/demo_mode.dart';

part '../profile/ui_parts/profile_header.dart';
part '../profile/ui_parts/profile_info_card.dart';
part '../profile/ui_parts/info_tile.dart';
part '../profile/ui_parts/copy_tile.dart';
part '../profile/ui_parts/skeleton_tile.dart';
part '../profile/ui_parts/skeleton_circle.dart';
part '../profile/ui_parts/skeleton_line.dart';

Color _profileAccent(BuildContext context) => appAccentOf(context);

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
    unawaited(repo.init());
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      unawaited(repo.refresh(force: false));
    });
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

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final p = repo.profile;
        final authExpired = _isAuthExpiredError(repo.lastError);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                if (authExpired) return;
                await repo.refresh(force: true);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 106),
                children: [
                  if (repo.loading) ...[
                    const LoadingSkeletonStrip(),
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
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
