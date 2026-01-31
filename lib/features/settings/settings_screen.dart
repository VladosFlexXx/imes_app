import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app.dart';
import '../../core/auth/auth_settings.dart';
import '../../core/network/eios_client.dart';

// debug/log/share
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_exporter.dart';
import '../../core/logging/share_helper.dart';
import '../debug/debug_report.dart';

import '../auth/login_webview.dart';
import '../notifications/notification_service.dart';

enum _CredsStatus { none, ok, bad }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _storage = FlutterSecureStorage();
  final _auth = AuthSettings.instance;

  _CredsStatus _credsStatus = _CredsStatus.none;
  String _credsHint = 'Не настроено';
  bool _checkingCreds = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    _primeCredsStatus();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _primeCredsStatus() async {
    final creds = await _auth.getCredentials();
    if (!mounted) return;

    if (creds != null) {
      setState(() {
        _credsStatus = _CredsStatus.ok;
        _credsHint = 'Настроено';
      });
    } else {
      setState(() {
        _credsStatus = _CredsStatus.none;
        _credsHint = 'Не настроено';
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    await _storage.delete(key: 'cookie_header');
    EiosClient.instance.invalidateCookieCache();
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginWebViewScreen()),
    );
  }

  Future<void> _openDiagnostics() async {
    final t = Theme.of(context).textTheme;

    try {
      AppLogger.instance.i('[DIAG] build report start');
      final report = await DebugReport.build();
      final file = await LogExporter.exportToTempFile(report);
      AppLogger.instance.i('[DIAG] report ready file=${file.path} bytes=${report.length}');

      if (!mounted) return;

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
                  Text('Диагностика', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Файл: ${file.path}', style: t.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await LogExporter.copyToClipboard(report);
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Отчёт скопирован в буфер')),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Копировать'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ShareHelper.shareFile(file, text: 'Отчёт диагностики ЭИОС ИМЭС');
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Поделиться'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Пароли в отчёт не пишем.'),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка диагностики: $e')),
      );
    }
  }

  Widget _statusChip() {
    final cs = Theme.of(context).colorScheme;

    IconData icon;
    Color bg;
    Color fg;
    String text;

    switch (_credsStatus) {
      case _CredsStatus.ok:
        icon = Icons.check_circle_outline;
        bg = cs.primary.withOpacity(0.12);
        fg = cs.primary;
        text = 'Настроено';
        break;
      case _CredsStatus.bad:
        icon = Icons.error_outline;
        bg = cs.error.withOpacity(0.12);
        fg = cs.error;
        text = 'Неверный логин/пароль';
        break;
      case _CredsStatus.none:
      default:
        icon = Icons.info_outline;
        bg = cs.surfaceVariant.withOpacity(0.6);
        fg = cs.onSurfaceVariant;
        text = _credsHint;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: fg),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: fg.withOpacity(0.25)),
          ),
          child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<bool> _tryLoginWithCreds({
    required String username,
    required String password,
  }) async {
    // Сейчас это “sanity-check”.
    // Если хочешь — сделаем реальную проверку запросом к ЭИОС через EiosClient.
    return username.trim().isNotEmpty && password.isNotEmpty;
  }

  Future<void> _openCredsSettingsSheet() async {
    final cs = Theme.of(context).colorScheme;

    final loginCtl = TextEditingController();
    final passCtl = TextEditingController();

    final existing = await _auth.getCredentials();
    if (existing != null) {
      loginCtl.text = existing.username;
      passCtl.text = existing.password;
    }

    bool showPass = false;
    String? inlineMsg;
    bool inlineIsError = false;

    Future<void> saveAndCheck(StateSetter setModalState) async {
      final u = loginCtl.text.trim();
      final p = passCtl.text;

      if (u.isEmpty || p.isEmpty) {
        setModalState(() {
          inlineMsg = 'Заполни логин и пароль';
          inlineIsError = true;
        });
        return;
      }

      setState(() => _checkingCreds = true);
      setModalState(() {
        inlineMsg = null;
        inlineIsError = false;
      });

      try {
        final ok = await _tryLoginWithCreds(username: u, password: p);
        if (!mounted) return;

        if (ok) {
          await _auth.setCredentials(username: u, password: p);
          setState(() {
            _credsStatus = _CredsStatus.ok;
            _credsHint = 'Настроено';
          });

          setModalState(() {
            inlineMsg = 'Успешно сохранено';
            inlineIsError = false;
          });

          await Future.delayed(const Duration(milliseconds: 450));
          if (!mounted) return;
          Navigator.of(context).pop();
        } else {
          setState(() {
            _credsStatus = _CredsStatus.bad;
            _credsHint = 'Неверный логин/пароль';
          });
          setModalState(() {
            inlineMsg = 'Неверный логин/пароль';
            inlineIsError = true;
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _credsStatus = _CredsStatus.bad;
          _credsHint = 'Ошибка проверки';
        });
        setModalState(() {
          inlineMsg = 'Ошибка: $e';
          inlineIsError = true;
        });
      } finally {
        if (mounted) setState(() => _checkingCreds = false);
      }
    }

    Future<void> clear(StateSetter setModalState) async {
      await _auth.clearCredentials();
      if (!mounted) return;
      setState(() {
        _credsStatus = _CredsStatus.none;
        _credsHint = 'Не настроено';
      });
      setModalState(() {
        inlineMsg = 'Удалено';
        inlineIsError = false;
      });
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Логин и пароль', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 10),

                    if (inlineMsg != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (inlineIsError ? cs.error : cs.primary).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (inlineIsError ? cs.error : cs.primary).withOpacity(0.35)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(inlineIsError ? Icons.error_outline : Icons.info_outline,
                                color: inlineIsError ? cs.error : cs.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                inlineMsg!,
                                style: TextStyle(
                                  color: inlineIsError ? cs.error : cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    TextField(
                      controller: loginCtl,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (inlineMsg != null) setModalState(() => inlineMsg = null);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passCtl,
                      obscureText: !showPass,
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: const Icon(Icons.key_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setModalState(() => showPass = !showPass),
                          icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      onChanged: (_) {
                        if (inlineMsg != null) setModalState(() => inlineMsg = null);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _checkingCreds ? null : () => saveAndCheck(setModalState),
                            icon: _checkingCreds
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.verified_outlined),
                            label: const Text('Сохранить и проверить'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => clear(setModalState),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Удалить сохранённые'),
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
      },
    );

    loginCtl.dispose();
    passCtl.dispose();
  }

  Widget _buildAuthReloginCard() {
    final t = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            RadioListTile<AuthReloginMode>(
              value: AuthReloginMode.safeUiLogin,
              groupValue: _auth.mode,
              title: Text('Без хранения пароля', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              subtitle: const Text('Если сессия истекла — автоматически откроем вход, после входа всё обновится.'),
              onChanged: (v) => v == null ? null : _auth.setMode(v),
            ),
            const Divider(height: 1),
            RadioListTile<AuthReloginMode>(
              value: AuthReloginMode.silentWithCredentials,
              groupValue: _auth.mode,
              title: Text('Тихий авторелогин (удобно)', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              subtitle: const Text('Сохраняет логин/пароль (Secure Storage) и при протухшей сессии попробует перелогиниться в фоне.'),
              onChanged: (v) => v == null ? null : _auth.setMode(v),
            ),
            if (_auth.mode == AuthReloginMode.silentWithCredentials) ...[
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.lock_outline),
                title: Text('Разрешить хранение логина/пароля', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                subtitle: const Text('Без этого тихий авторелогин не работает'),
                value: _auth.credsEnabled,
                onChanged: (v) async {
                  await _auth.setCredsEnabled(v);
                  if (!mounted) return;
                  setState(() {
                    if (!v) {
                      _credsStatus = _CredsStatus.none;
                      _credsHint = 'Хранение выключено';
                    } else {
                      if (_credsHint == 'Хранение выключено') _credsHint = 'Не настроено';
                    }
                  });
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text('Настроить логин/пароль', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                subtitle: _statusChip(),
                trailing: const Icon(Icons.chevron_right),
                enabled: _auth.credsEnabled && !_checkingCreds,
                onTap: (_auth.credsEnabled && !_checkingCreds) ? _openCredsSettingsSheet : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.dark:
        return 'Тёмная';
      case ThemeMode.system:
      default:
        return 'Системная';
    }
  }

  static void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Тема', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_outlined),
                title: const Text('Светлая'),
                onTap: () {
                  themeController.setMode(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Тёмная'),
                onTap: () {
                  themeController.setMode(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Системная'),
                onTap: () {
                  themeController.setMode(ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    const repoUrl = 'https://github.com/VladosFlexXx/eios';

    String versionLine = 'Версия: —';
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      final b = info.buildNumber.trim();
      versionLine = (v.isNotEmpty && b.isNotEmpty) ? 'Версия: $v+$b' : (v.isNotEmpty ? 'Версия: $v' : 'Версия: —');
    } catch (_) {}

    if (!context.mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'ЭИОС ИМЭС',
      applicationVersion: versionLine.replaceFirst('Версия: ', ''),
      applicationLegalese: 'Бета-версия.',
      children: [
        const SizedBox(height: 8),
        Text(versionLine),
        const SizedBox(height: 8),
        const Text('Репозиторий (GitHub):'),
        const SizedBox(height: 4),
        const SelectableText(repoUrl),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: repoUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка на GitHub скопирована')));
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

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          Text('Авторелогин', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _buildAuthReloginCard(),

          const SizedBox(height: 18),
          Text('Уведомления', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const _PushCard(),

          const SizedBox(height: 18),
          Text('Приложение', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.public_outlined),
                  title: Text('Открыть ЭИОС (Web)', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Открыть my/ в WebView'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EiosWebViewScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text('Тема', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  subtitle: Text(_themeLabel(themeController.mode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemePicker(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text('Диагностика', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Собрать отчёт'),
                  onTap: _openDiagnostics,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('О приложении', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Версия, репозиторий'),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Text('Аккаунт', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: Text('Выйти', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              subtitle: const Text('Очистить сессию и войти заново'),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PushCard extends StatelessWidget {
  const _PushCard();

  @override
  Widget build(BuildContext context) {
    final ns = NotificationService.instance;
    final t = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ValueListenableBuilder<bool>(
          valueListenable: ns.enabled,
          builder: (context, on, _) {
            return SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text('Включить пуши', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              subtitle: const Text('Уведомления об изменениях в расписании'),
              value: on,
              onChanged: (v) async {
                try {
                  await ns.setEnabled(v);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Не удалось изменить настройку пушей: $e')),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

class EiosWebViewScreen extends StatelessWidget {
  const EiosWebViewScreen({super.key});

  static const String _url = 'https://eos.imes.su/my/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ЭИОС (Web)')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_url)),
      ),
    );
  }
}
