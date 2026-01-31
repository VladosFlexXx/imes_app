import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../profile/models.dart';
import '../profile/repository.dart';
import '../settings/settings_screen.dart';

import 'package:vuz_app/core/network/eios_client.dart';

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
    EiosClient.instance.invalidateCookieCache();
  }

  String _fmtTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
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
          appBar: AppBar(
            title: const Text('Профиль'),
            bottom: repo.loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(3),
                    child: LinearProgressIndicator(minHeight: 3),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: 'Настройки',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings_outlined),
              ),
              IconButton(
                tooltip: 'Обновить',
                onPressed: (repo.loading || authExpired)
                    ? null
                    : () => repo.refresh(force: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              if (authExpired) return;
              await repo.refresh(force: true);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              children: [
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
                            style: t.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
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
                                          'Куки очищены. Открой вход и залогинься заново.'),
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
                _ProfileHeader(
                  profile: p,
                  updatedAt: repo.updatedAt,
                  hasError: repo.lastError != null,
                  loading: repo.loading,
                  fmtTime: _fmtTime,
                ),
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

class _ProfileHeader extends StatelessWidget {
  final UserProfile? profile;

  final DateTime? updatedAt;
  final bool hasError;
  final bool loading;
  final String Function(DateTime dt) fmtTime;

  const _ProfileHeader({
    required this.profile,
    required this.updatedAt,
    required this.hasError,
    required this.loading,
    required this.fmtTime,
  });

  String _subtitleLine(UserProfile p) {
    final parts = <String>[];
    final group = p.group;
    final level = p.level;
    final eduForm = p.eduForm;

    if (group != null && group.trim().isNotEmpty) parts.add(group.trim());
    if (level != null && level.trim().isNotEmpty) parts.add(level.trim());
    if (eduForm != null && eduForm.trim().isNotEmpty) parts.add(eduForm.trim());

    return parts.isEmpty ? 'Профиль ЭИОС' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (p == null) {
      return Card(
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text('Загрузка...'),
        ),
      );
    }

    final updateText = (updatedAt != null) ? fmtTime(updatedAt!) : null;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage:
                      (p.avatarUrl != null) ? NetworkImage(p.avatarUrl!) : null,
                  child: (p.avatarUrl == null)
                      ? const Icon(Icons.person_outline, size: 28)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.fullName,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitleLine(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.78),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // тонкая строка статуса обновления
            if (updateText != null || hasError) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    hasError ? Icons.warning_amber_rounded : Icons.sync,
                    size: 18,
                    color: hasError
                        ? cs.error.withOpacity(0.85)
                        : cs.onSurface.withOpacity(0.75),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasError
                          ? 'Не удалось обновить'
                          : 'Обновлено: $updateText',
                      style: t.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withOpacity(0.78),
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final UserProfile? profile;
  final Future<void> Function(String text) onCopyRecordBook;

  const _ProfileInfoCard({
    required this.profile,
    required this.onCopyRecordBook,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    if (p == null) {
      return Card(
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text('Загрузка...'),
        ),
      );
    }

    if (p.fields.isEmpty) {
      return Card(
        elevation: 0,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text('Нет данных (проверь, открывается ли user/edit.php)'),
        ),
      );
    }

    final email = p.email;

    // Профиль/направление — как раньше, но без лишнего дублирования.
    final prof = p.profileEdu;
    final spec = p.specialty;

    String? profileLine;
    final parts = <String>[];
    if (prof != null && prof.trim().isNotEmpty) parts.add(prof.trim());
    if (spec != null && spec.trim().isNotEmpty) {
      if (parts.isEmpty ||
          parts.first.toLowerCase() != spec.trim().toLowerCase()) {
        parts.add(spec.trim());
      }
    }
    if (parts.isNotEmpty) profileLine = parts.join(' • ');

    // ✅ ТОЛЬКО то, что не дублируется под ФИО
    final recordBook = p.recordBook;

    final items = <Widget>[
      _InfoTile(
        icon: Icons.email_outlined,
        title: 'Почта',
        value: email,
      ),
      _InfoTile(
        icon: Icons.school_outlined,
        title: 'Профиль / направление',
        value: profileLine,
      ),
      _CopyTile(
        icon: Icons.confirmation_number_outlined,
        title: '№ зачётной книжки',
        value: recordBook,
        onCopy: recordBook == null
            ? null
            : () => onCopyRecordBook(recordBook),
      ),
    ].whereType<Widget>().toList();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            ..._withDividers(items, Divider(color: cs.outlineVariant.withOpacity(0.35), height: 1)),
          ],
        ),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> children, Widget divider) {
    final out = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) out.add(divider);
    }
    return out;
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final v = (value ?? '').trim();
    final show = v.isNotEmpty;

    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
      subtitle: Text(
        show ? v : '—',
        style: t.bodyMedium?.copyWith(
          color: cs.onSurface.withOpacity(show ? 0.85 : 0.55),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CopyTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onCopy;

  const _CopyTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final v = (value ?? '').trim();
    final show = v.isNotEmpty && onCopy != null;

    return InkWell(
      onTap: show ? onCopy : null,
      child: ListTile(
        leading: Icon(icon),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (show)
              Icon(Icons.copy_rounded, size: 18, color: cs.onSurface.withOpacity(0.65)),
          ],
        ),
        subtitle: Text(
          (v.isNotEmpty) ? v : '—',
          style: t.bodyMedium?.copyWith(
            color: cs.onSurface.withOpacity(v.isNotEmpty ? 0.85 : 0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
