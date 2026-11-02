import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../ui/app_theme.dart';
import '../../core/auth/app_security_service.dart';
import '../../core/auth/auth_settings.dart';
import '../../core/auth/biometric_service.dart';
import '../../core/auth/pin_code_service.dart';
import '../auth/pin_code_screen.dart';
import '../../core/demo/demo_mode.dart';
import '../../core/network/eios_client.dart';
import '../../core/network/eios_endpoints.dart';

// debug/log/share
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_exporter.dart';
import '../../core/logging/share_helper.dart';
import '../debug/debug_report.dart';

import '../auth/login_webview.dart';
import '../grades/repository.dart';
import '../profile/repository.dart';
import '../recordbook/repository.dart';
import '../schedule/schedule_repository.dart';
import '../study_plan/repository.dart';
import '../notifications/notification_service.dart';
import '../schedule/lesson_reminder_service.dart';
import '../../core/app_icon_service.dart';
import '../../core/updater/app_update_service.dart';
import '../../ui/app_haptics.dart';

part 'settings_parts/push_card.dart';

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

  bool _biometricSupported = false;
  bool _biometricEnabled = false;
  bool _pinEnabled = false;
  bool _screenProtectionEnabled = false;
  bool _remindersEnabled = false;
  int _remindersMinutes = 15;
  bool _hapticEnabled = true;
  bool _reduceEffects = false;
  bool _reduceAnimations = false;
  bool _materialYou = false;
  bool _amoledBlack = false;
  bool _appearanceExpanded = false;
  bool _notificationsExpanded = false;
  bool _securityExpanded = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    themeController.addListener(_onThemeChanged);
    _primeCredsStatus();
    _loadExtraSettings();
  }

  Future<void> _loadExtraSettings() async {
    await AppHaptics.init();
    await AppIconService.instance.init();
    final bioSup = await BiometricService.instance.isSupported();
    final bioEn = await BiometricService.instance.isEnabled();
    final pinEn = await PinCodeService.instance.isEnabled();
    final secEn = AppSecurityService.instance.isScreenProtectionEnabled;
    final remEn = await LessonReminderService.instance.isEnabled();
    final remMin = await LessonReminderService.instance.getMinutesBefore();
    if (!mounted) return;
    setState(() {
      _hapticEnabled = AppHaptics.enabled;
      _reduceEffects = themeController.reduceEffects;
      _reduceAnimations = themeController.reduceAnimations;
      _materialYou = themeController.materialYou;
      _amoledBlack = themeController.amoledBlack;
      _biometricSupported = bioSup;
      _biometricEnabled = bioEn;
      _pinEnabled = pinEn;
      _screenProtectionEnabled = secEn;
      _remindersEnabled = remEn;
      _remindersMinutes = remMin;
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {
      _reduceEffects = themeController.reduceEffects;
      _reduceAnimations = themeController.reduceAnimations;
      _materialYou = themeController.materialYou;
      _amoledBlack = themeController.amoledBlack;
    });
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
    await AuthSettings.instance.resetAll();
    await DemoMode.instance.setEnabled(false);
    EiosClient.instance.invalidateCookieCache();
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (_) {}

    await Future.wait([
      ProfileRepository.instance.clearCache(),
      ScheduleRepository.instance.clearCache(),
      GradesRepository.instance.clearCache(),
      RecordbookRepository.instance.clearCache(),
      StudyPlanRepository.instance.clearCache(),
    ]);

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginWebViewScreen()),
      (route) => false,
    );
  }

  Future<void> _openDiagnostics() async {
    final t = Theme.of(context).textTheme;

    try {
      AppLogger.instance.i('[DIAG] build report start');
      final report = await DebugReport.build();
      final file = await LogExporter.exportToTempFile(report);
      AppLogger.instance.i(
        '[DIAG] report ready file=${file.path} bytes=${report.length}',
      );

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
                  Text(
                    'Диагностика',
                    style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
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
                              const SnackBar(
                                content: Text('Отчёт скопирован в буфер'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Копировать'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ShareHelper.shareFile(
                            file,
                            text: 'Отчёт диагностики Мой ИМЭС',
                          );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка диагностики: $e')));
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
          child: Text(
            text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700),
          ),
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

    Future<void> saveAndCheck(
      BuildContext modalContext,
      StateSetter setModalState,
    ) async {
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
          if (modalContext.mounted) {
            Navigator.of(modalContext).pop();
          }
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
                      child: Text(
                        'Логин и пароль',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (inlineMsg != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (inlineIsError ? cs.error : cs.primary)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (inlineIsError ? cs.error : cs.primary)
                                .withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              inlineIsError
                                  ? Icons.error_outline
                                  : Icons.info_outline,
                              color: inlineIsError ? cs.error : cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                inlineMsg!,
                                style: TextStyle(
                                  color: inlineIsError
                                      ? cs.error
                                      : cs.onSurface,
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
                        if (inlineMsg != null)
                          setModalState(() => inlineMsg = null);
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
                          onPressed: () =>
                              setModalState(() => showPass = !showPass),
                          icon: Icon(
                            showPass ? Icons.visibility_off : Icons.visibility,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (inlineMsg != null)
                          setModalState(() => inlineMsg = null);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _checkingCreds
                                ? null
                                : () => saveAndCheck(context, setModalState),
                            icon: _checkingCreds
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
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

  Widget _buildCardContainer({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final accent = appAccentOf(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isAmoled ? Colors.black : null,
        gradient: isAmoled
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF1A1E23), Color(0xFF171B21)]
                    : const [Color(0xFFF1F3F7), Color(0xFFE9EDF4)],
              ),
        border: Border.all(
          color: isAmoled
              ? accent.withValues(alpha: 0.35)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08)),
          width: isAmoled ? 1.2 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      ),
    );
  }

  Widget _buildAuthReloginContent() {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          RadioListTile<AuthReloginMode>(
            value: AuthReloginMode.safeUiLogin,
            groupValue: _auth.mode,
            title: Text(
              'Без хранения пароля',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Если сессия истекла — откроем окно входа, после входа данные обновятся.',
            ),
            onChanged: (v) {
              if (v != null) {
                AppHaptics.selectionClick();
                _auth.setMode(v);
              }
            },
          ),
          const Divider(height: 1),
          RadioListTile<AuthReloginMode>(
            value: AuthReloginMode.silentWithCredentials,
            groupValue: _auth.mode,
            title: Text(
              'Тихий авторелогин (удобно)',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Сохраняет логин/пароль (Secure Storage) и перелогинивается в фоне.',
            ),
            onChanged: (v) {
              if (v != null) {
                AppHaptics.selectionClick();
                _auth.setMode(v);
              }
            },
          ),
          if (_auth.mode == AuthReloginMode.silentWithCredentials) ...[
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline),
              title: Text(
                'Разрешить хранение логина/пароля',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Без этого тихий авторелогин не работает'),
              value: _auth.credsEnabled,
              activeThumbColor: Colors.white,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) async {
                AppHaptics.selectionClick();
                await _auth.setCredsEnabled(v);
                if (!mounted) return;
                setState(() {
                  if (!v) {
                    _credsStatus = _CredsStatus.none;
                    _credsHint = 'Хранение выключено';
                  } else {
                    if (_credsHint == 'Хранение выключено') {
                      _credsHint = 'Не настроено';
                    }
                  }
                });
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(
                'Настроить логин/пароль',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: _statusChip(),
              trailing: const Icon(Icons.chevron_right),
              enabled: _auth.credsEnabled && !_checkingCreds,
              onTap: (_auth.credsEnabled && !_checkingCreds)
                  ? () {
                      AppHaptics.selectionClick();
                      _openCredsSettingsSheet();
                    }
                  : null,
            ),
          ],
        ],
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
        return 'Системная';
    }
  }

  static const List<_PresetAccent> _presetAccents = [
    _PresetAccent('Оранжевый', Color(0xFFEC5C0D)),
    _PresetAccent('Фиолетовый', Color(0xFF8B5CF6)),
    _PresetAccent('Зелёный', Color(0xFF10B981)),
  ];

  static String _accentLabelFromColor(Color color) {
    final target = color.toARGB32();
    for (final p in _presetAccents) {
      if (p.color.toARGB32() == target) return p.label;
    }
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  static void _showColorPickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ColorPickerDialog(
        initialColor: themeController.seedColor,
        onColorSelected: (color) {
          themeController.setSeedColor(color);
        },
      ),
    );
  }

  static void _showAppearanceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return ListenableBuilder(
          listenable: Listenable.merge([themeController, AppIconService.instance]),
          builder: (context, _) {
            final cs = Theme.of(context).colorScheme;
            final t = Theme.of(context).textTheme;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final currentMode = themeController.mode;
            final currentScale = themeController.uiScale;
            final currentIcon = AppIconService.instance.current;
            final currentReduceEffects = themeController.reduceEffects;
            final currentMaterialYou = themeController.materialYou;
            final currentAmoledBlack = themeController.amoledBlack;
            final percent = (currentScale * 100).round();

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Оформление и тема',
                      style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Настройте тему, акцентный цвет и масштаб интерфейса под ваш экран.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // 1. ТЕМА
                    Text(
                      'Тема оформления',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildThemeOption(
                          context: context,
                          label: 'Системная',
                          icon: Icons.brightness_auto_rounded,
                          selected: currentMode == ThemeMode.system,
                          onTap: () {
                            AppHaptics.selectionClick();
                            themeController.setThemeMode(ThemeMode.system);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          context: context,
                          label: 'Светлая',
                          icon: Icons.light_mode_rounded,
                          selected: currentMode == ThemeMode.light,
                          onTap: () {
                            AppHaptics.selectionClick();
                            themeController.setThemeMode(ThemeMode.light);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThemeOption(
                          context: context,
                          label: 'Тёмная',
                          icon: Icons.dark_mode_rounded,
                          selected: currentMode == ThemeMode.dark,
                          onTap: () {
                            AppHaptics.selectionClick();
                            themeController.setThemeMode(ThemeMode.dark);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 2. АКЦЕНТНЫЙ ЦВЕТ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Акцентный цвет',
                          style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (!kIsWeb && currentMaterialYou)
                          Text(
                            'Цвета обоев (Material You)',
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final currentSeed = themeController.seedColor;
                        final isCustomColor = !_presetAccents.any(
                          (p) => p.color.toARGB32() == currentSeed.toARGB32(),
                        );
                        return Opacity(
                          opacity: (!kIsWeb && currentMaterialYou) ? 0.38 : 1.0,
                          child: IgnorePointer(
                            ignoring: !kIsWeb && currentMaterialYou,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  for (final p in _presetAccents) ...[
                                    Builder(
                                      builder: (context) {
                                        final isSelected =
                                            currentSeed.toARGB32() == p.color.toARGB32();
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () {
                                            AppHaptics.selectionClick();
                                            themeController.setSeedColor(p.color);
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? p.color.withValues(alpha: 0.16)
                                                  : (isDark
                                                      ? Colors.white.withValues(alpha: 0.05)
                                                      : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isSelected
                                                    ? p.color
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: p.color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  p.label,
                                                  style: TextStyle(
                                                    fontWeight: isSelected
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                    fontSize: 13,
                                                    color: isSelected
                                                        ? p.color
                                                        : cs.onSurface,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // Свой цвет / Палитра
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      AppHaptics.selectionClick();
                                      _showColorPickerDialog(context);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isCustomColor
                                            ? currentSeed.withValues(alpha: 0.16)
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.05)
                                                : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isCustomColor
                                              ? currentSeed
                                              : (isDark
                                                  ? Colors.white.withValues(alpha: 0.12)
                                                  : Colors.black.withValues(alpha: 0.12)),
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isCustomColor)
                                            Container(
                                              width: 14,
                                              height: 14,
                                              margin: const EdgeInsets.only(right: 8),
                                              decoration: BoxDecoration(
                                                color: currentSeed,
                                                shape: BoxShape.circle,
                                              ),
                                            )
                                          else
                                            ShaderMask(
                                              shaderCallback: (bounds) => const SweepGradient(
                                                colors: [
                                                  Colors.red,
                                                  Colors.amber,
                                                  Colors.green,
                                                  Colors.cyan,
                                                  Colors.blue,
                                                  Colors.purple,
                                                  Colors.red,
                                                ],
                                              ).createShader(bounds),
                                              child: const Icon(
                                                Icons.palette_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isCustomColor
                                                ? _accentLabelFromColor(currentSeed)
                                                : 'Палитра',
                                            style: TextStyle(
                                              fontWeight: isCustomColor
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              fontSize: 13,
                                              color: isCustomColor
                                                  ? currentSeed
                                                  : cs.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // 3. МАСШТАБ ИНТЕРФЕЙСА (50% - 150%)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Масштаб интерфейса',
                          style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$percent%',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.text_fields_rounded, size: 16),
                        Expanded(
                          child: Slider(
                            value: currentScale.clamp(0.5, 1.5),
                            min: 0.5,
                            max: 1.5,
                            divisions: 10,
                            label: '$percent%',
                            onChanged: (val) {
                              final rounded = (val * 10).round() / 10.0;
                              themeController.setUiScale(rounded);
                            },
                          ),
                        ),
                        const Icon(Icons.text_fields_rounded, size: 28),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('50%', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                        Text('100% (стандарт)', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('150%', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                      ],
                    ),

                    if (!kIsWeb) ...[
                      const SizedBox(height: 24),

                      // 4. ИКОНКА ПРИЛОЖЕНИЯ
                      Text(
                        'Иконка приложения',
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _buildIconSelectorRow(
                        context: context,
                        selected: currentIcon,
                        onSelect: (variant) async {
                          AppHaptics.selectionClick();
                          await AppIconService.instance.setIcon(variant);
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 5. ДОПОЛНИТЕЛЬНО
                    Text(
                      'Дополнительно',
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    if (!kIsWeb) ...[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(Icons.auto_awesome_rounded),
                        title: Text(
                          'Material You',
                          style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Использовать цвета обоев системы',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                        value: currentMaterialYou,
                        onChanged: (val) {
                          AppHaptics.selectionClick();
                          themeController.setMaterialYou(val);
                        },
                      ),
                    ],
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.contrast_rounded),
                      title: Text(
                        'AMOLED чёрный',
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'Чистый чёрный фон — экономит заряд на OLED',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      value: currentAmoledBlack,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        themeController.setAmoledBlack(val);
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.blur_on_rounded),
                      title: Text(
                        'Размытие и стекло (Liquid Glass)',
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        'Отключите на слабых устройствах для экономии заряда и максимальной плавности 60/120 FPS',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      value: !currentReduceEffects,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        themeController.setReduceEffects(!val);
                      },
                    ),

                    const SizedBox(height: 24),

                    // КНОПКА ЗАКРЫТЬ / СБРОС
                    Row(
                      children: [
                        if ((currentScale - 1.0).abs() >= 0.01) ...[
                          OutlinedButton(
                            onPressed: () {
                              AppHaptics.selectionClick();
                              themeController.setUiScale(1.0);
                            },
                            child: const Text('Сброс 100%'),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              AppHaptics.selectionClick();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Готово'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildThemeOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.16)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                  color: selected ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildIconSelectorRow({
    required BuildContext context,
    required AppIconVariant selected,
    required ValueChanged<AppIconVariant> onSelect,
  }) {
    return Row(
      children: [
        for (final variant in AppIconVariant.values) ...[
          Expanded(
            child: _buildAppIconCard(
              context: context,
              variant: variant,
              isSelected: selected == variant,
              onTap: () => onSelect(variant),
            ),
          ),
          if (variant != AppIconVariant.values.last) const SizedBox(width: 14),
        ],
      ],
    );
  }

  static Widget _buildAppIconCard({
    required BuildContext context,
    required AppIconVariant variant,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = cs.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.4)),
          border: Border.all(
            color: isSelected
                ? accent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : cs.outlineVariant.withValues(alpha: 0.6)),
            width: isSelected ? 2.2 : 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  variant.assetPath,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              variant.title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 15,
                color: isSelected ? accent : cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              variant.subtitle,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: isSelected
                  ? accent
                  : cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = isDark && themeController.amoledBlack;
    final accent = appAccentOf(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isAmoled ? Colors.black : null,
        gradient: isAmoled
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF1A1E23), Color(0xFF171B21)]
                    : const [Color(0xFFF1F3F7), Color(0xFFE9EDF4)],
              ),
        border: Border.all(
          color: isAmoled
              ? accent.withValues(alpha: 0.35)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08)),
          width: isAmoled ? 1.2 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: Material(
          color: Colors.transparent,
          child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              AppHaptics.selectionClick();
              onToggle();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: t.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.60)
                                : cs.onSurface.withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.65)
                          : cs.onSurface.withValues(alpha: 0.65),
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  color: isAmoled ? Colors.black : null,
                ),
                content,
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 260),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildAppearanceSection(
    TextTheme t,
    ThemeData theme,
    Icon tileChevron,
  ) {
    final accentPart = (!kIsWeb && _materialYou)
        ? 'Material You'
        : _accentLabelFromColor(themeController.seedColor);
    final amoledPart = _amoledBlack ? ' · AMOLED' : '';
    final glassPart = _reduceEffects ? 'Без стекла' : 'Стекло';
    final status = '${_themeLabel(themeController.mode)} · $accentPart$amoledPart · $glassPart';

    return _buildAccordionCard(
      icon: Icons.palette_outlined,
      title: 'Внешний вид и интерфейс',
      subtitle: status,
      isExpanded: _appearanceExpanded,
      onToggle: () => setState(() => _appearanceExpanded = !_appearanceExpanded),
      content: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(
              'Оформление и тема',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${_themeLabel(themeController.mode)}, $accentPart, ${(themeController.uiScale * 100).round()}%',
            ),
            trailing: tileChevron,
            onTap: () {
              AppHaptics.selectionClick();
              _showAppearanceDialog(context);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: Text(
              'Тактильный отклик (Haptic)',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Вибрация при тапах и переключениях'),
            value: _hapticEnabled,
            onChanged: (val) async {
              setState(() => _hapticEnabled = val);
              await AppHaptics.setEnabled(val);
              if (val) AppHaptics.mediumImpact();
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.bolt_rounded),
            title: Text(
              'Упрощённые анимации',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Мгновенные переходы и отключение эффектов'),
            value: _reduceAnimations,
            onChanged: (val) async {
              AppHaptics.selectionClick();
              setState(() => _reduceAnimations = val);
              await themeController.setReduceAnimations(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(
    TextTheme t,
    ThemeData theme,
    Icon tileChevron,
  ) {
    final pushOn = NotificationService.instance.enabled.value;
    final status =
        '${_remindersEnabled ? "Пары за $_remindersMinutes мин" : "Без напоминаний"} · ${pushOn ? "Пуши вкл" : "Пуши выкл"}';

    return _buildAccordionCard(
      icon: Icons.notifications_active_outlined,
      title: 'Уведомления',
      subtitle: status,
      isExpanded: _notificationsExpanded,
      onToggle: () => setState(() => _notificationsExpanded = !_notificationsExpanded),
      content: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(
              'Напоминать о парах',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              _remindersEnabled
                  ? 'За $_remindersMinutes минут до начала пары'
                  : 'Отключено',
            ),
            value: _remindersEnabled,
            onChanged: (val) async {
              AppHaptics.selectionClick();
              setState(() => _remindersEnabled = val);
              await LessonReminderService.instance.setEnabled(val);
            },
          ),
          if (_remindersEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(68, 0, 16, 10),
              child: Row(
                children: [
                  Text('Время: ', style: t.bodySmall),
                  ChoiceChip(
                    label: const Text('За 15 мин'),
                    selected: _remindersMinutes == 15,
                    onSelected: (s) async {
                      if (!s) return;
                      AppHaptics.selectionClick();
                      setState(() => _remindersMinutes = 15);
                      await LessonReminderService.instance.setMinutesBefore(15);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('За 30 мин'),
                    selected: _remindersMinutes == 30,
                    onSelected: (s) async {
                      if (!s) return;
                      AppHaptics.selectionClick();
                      setState(() => _remindersMinutes = 30);
                      await LessonReminderService.instance.setMinutesBefore(30);
                    },
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          const _PushCard(embedded: true),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.volume_up_outlined),
            title: Text(
              'Звуки и оповещения',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Настройка тональностей сигналов'),
            trailing: const _SoonBadge(),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(
    TextTheme t,
    ThemeData theme,
    Icon tileChevron,
  ) {
    final bioText = _biometricSupported
        ? (_biometricEnabled ? 'Биометрия вкл' : 'Биометрия выкл')
        : 'Биометрия недоступна';
    final pinText = _pinEnabled ? 'PIN вкл' : 'PIN выкл';
    final reloginText = _auth.mode == AuthReloginMode.silentWithCredentials
        ? 'Тихий вход'
        : 'Без пароля';
    final status = '$bioText · $pinText · $reloginText';

    return _buildAccordionCard(
      icon: Icons.shield_outlined,
      title: 'Безопасность',
      subtitle: status,
      isExpanded: _securityExpanded,
      onToggle: () => setState(() => _securityExpanded = !_securityExpanded),
      content: Column(
        children: [
          if (_biometricSupported) ...[
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: Text(
                'Вход по биометрии',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Отпечаток пальца / Face ID'),
              value: _biometricEnabled,
              onChanged: (val) async {
                AppHaptics.selectionClick();
                if (val) {
                  final ok = await BiometricService.instance.authenticate(
                    reason: 'Подтвердите включение биометрии',
                  );
                  if (!ok) return;
                }
                setState(() => _biometricEnabled = val);
                await BiometricService.instance.setEnabled(val);
              },
            ),
            const Divider(height: 1),
          ],
          SwitchListTile(
            secondary: const Icon(Icons.pin_outlined),
            title: Text(
              'PIN-код для входа',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              _pinEnabled
                  ? 'Код установлен (4 цифры)'
                  : 'Быстрый доступ и защита данных',
            ),
            value: _pinEnabled,
            onChanged: (val) async {
              AppHaptics.selectionClick();
              if (val) {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const PinCodeScreen(
                      mode: PinScreenMode.create,
                    ),
                  ),
                );
                if (created == true && mounted) {
                  setState(() => _pinEnabled = true);
                }
              } else {
                final verified = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const PinCodeScreen(
                      mode: PinScreenMode.verify,
                    ),
                  ),
                );
                if (verified == true) {
                  await PinCodeService.instance.removePin();
                  if (mounted) {
                    setState(() => _pinEnabled = false);
                  }
                }
              }
            },
          ),
          if (_pinEnabled) ...[
            ListTile(
              contentPadding: const EdgeInsets.only(left: 72, right: 16),
              title: Text(
                'Сменить PIN-код',
                style: t.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: tileChevron,
              onTap: () async {
                AppHaptics.selectionClick();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PinCodeScreen(
                      mode: PinScreenMode.change,
                    ),
                  ),
                );
              },
            ),
          ],
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(
              'Защита от подглядывания',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Скрывать экран в недавних задачах и блокировать скриншоты',
            ),
            value: _screenProtectionEnabled,
            onChanged: (val) async {
              AppHaptics.selectionClick();
              await AppSecurityService.instance.setScreenProtection(val);
              setState(() => _screenProtectionEnabled = val);
            },
          ),
          const Divider(height: 1),
          _buildAuthReloginContent(),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.devices_other_outlined),
            title: Text(
              'Управление сессиями',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Активные входы на устройствах'),
            trailing: const _SoonBadge(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSection(
    TextTheme t,
    ThemeData theme,
    Icon tileChevron,
  ) {
    return _buildCardContainer(
      child: Column(
        children: [
          if (!kIsWeb) ...[
            ListTile(
              leading: const Icon(Icons.system_update_rounded),
              title: Text(
                'Проверить обновления',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Сравнить с последним релизом на GitHub'),
              trailing: tileChevron,
              onTap: () {
                AppHaptics.selectionClick();
                AppUpdateService.instance.checkAndPrompt(context, force: true);
              },
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: const Icon(Icons.public_outlined),
            title: Text(
              kIsWeb ? 'Официальный сайт ЭИОС' : 'Открыть ЭИОС (Web)',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(kIsWeb ? 'Открыть eos.imes.su в новой вкладке' : 'Открыть my/ в WebView'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () async {
              AppHaptics.selectionClick();
              if (kIsWeb) {
                await launchUrl(
                  Uri.parse('https://eos.imes.su/my/'),
                  mode: LaunchMode.externalApplication,
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EiosWebViewScreen(),
                  ),
                );
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(
              'Диагностика',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Собрать отчёт логов'),
            trailing: tileChevron,
            onTap: () {
              AppHaptics.selectionClick();
              _openDiagnostics();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    AppHaptics.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Вы выйдете из текущей сессии. Для повторного входа потребуется авторизоваться заново.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5C5C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileChevron = Icon(
      Icons.chevron_right,
      color: isDark
          ? Colors.white.withValues(alpha: 0.74)
          : cs.onSurface.withValues(alpha: 0.72),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildAppearanceSection(t, theme, tileChevron),
          const SizedBox(height: 12),
          if (!kIsWeb) ...[
            _buildNotificationsSection(t, theme, tileChevron),
            const SizedBox(height: 12),
          ],
          _buildSecuritySection(t, theme, tileChevron),
          const SizedBox(height: 20),
          Text(
            'Сервис',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _buildServiceSection(t, theme, tileChevron),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _confirmLogout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF5C5C),
              side: const BorderSide(color: Color(0xFF5A1313), width: 1.2),
              backgroundColor: isDark
                  ? const Color(0xFF1C0707)
                  : const Color(0xFFFFEAEA),
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
    );
  }
}

class _SoonBadge extends StatelessWidget {
  const _SoonBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        'Скоро',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : cs.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class EiosWebViewScreen extends StatelessWidget {
  const EiosWebViewScreen({super.key});

  static const String _url = EiosEndpoints.my;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ЭИОС (Web)')),
      body: InAppWebView(initialUrlRequest: URLRequest(url: WebUri(_url))),
    );
  }
}

class _PresetAccent {
  final String label;
  final Color color;

  const _PresetAccent(this.label, this.color);
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late final TextEditingController _hexController;
  bool _updatingText = false;

  static const List<Color> _quickSwatches = [
    Color(0xFFEC5C0D), // Оранжевый ИМЭС
    Color(0xFF2868EC), // Синий
    Color(0xFF0EA5E9), // Небесный
    Color(0xFF10B981), // Мятный
    Color(0xFF84CC16), // Лайм
    Color(0xFFF59E0B), // Янтарный
    Color(0xFFEF4444), // Алый
    Color(0xFFEC4899), // Розовый
    Color(0xFFD946EF), // Фуксия
    Color(0xFF8B5CF6), // Фиолетовый
  ];

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation.clamp(0.20, 1.0);
    _value = hsv.value.clamp(0.35, 1.0);
    _hexController = TextEditingController(
      text: _formatHex(widget.initialColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();

  String _formatHex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  void _syncHexFromHsv() {
    if (_updatingText) return;
    _updatingText = true;
    _hexController.text = _formatHex(_currentColor);
    _updatingText = false;
  }

  void _onHexChanged(String input) {
    if (_updatingText) return;
    final cleaned = input.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) {
        final c = Color(0xFF000000 | parsed);
        final hsv = HSVColor.fromColor(c);
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation.clamp(0.20, 1.0);
          _value = hsv.value.clamp(0.35, 1.0);
        });
      }
    }
  }

  void _setSwatch(Color c) {
    AppHaptics.selectionClick();
    final hsv = HSVColor.fromColor(c);
    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation.clamp(0.20, 1.0);
      _value = hsv.value.clamp(0.35, 1.0);
      _syncHexFromHsv();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final current = _currentColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Заголовок
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: current.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.palette_rounded, color: current, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Палитра акцента',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Превью карточки
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: current,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: current.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Мой ИМЭС',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'HEX: #${_formatHex(current)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Превью',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Быстрые оттенки
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final swatch in _quickSwatches)
                    GestureDetector(
                      onTap: () => _setSwatch(swatch),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: swatch,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: swatch.toARGB32() == current.toARGB32()
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Слайдер оттенка (Hue)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Оттенок (Hue)', style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${_hue.round()}°', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 4),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF0000),
                          Color(0xFFFFFF00),
                          Color(0xFF00FF00),
                          Color(0xFF00FFFF),
                          Color(0xFF0000FF),
                          Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: current,
                      overlayColor: current.withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: _hue,
                      min: 0,
                      max: 360,
                      onChanged: (val) {
                        setState(() {
                          _hue = val;
                          _syncHexFromHsv();
                        });
                      },
                    ),
                  ),
                ],
              ),

              // Слайдер насыщенности
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Насыщенность', style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${(_saturation * 100).round()}%', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              Slider(
                value: _saturation,
                min: 0.20,
                max: 1.0,
                activeColor: current,
                onChanged: (val) {
                  setState(() {
                    _saturation = val;
                    _syncHexFromHsv();
                  });
                },
              ),

              // Слайдер яркости
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Яркость', style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${(_value * 100).round()}%', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              Slider(
                value: _value,
                min: 0.35,
                max: 1.0,
                activeColor: current,
                onChanged: (val) {
                  setState(() {
                    _value = val;
                    _syncHexFromHsv();
                  });
                },
              ),
              const SizedBox(height: 6),

              // Поле HEX
              TextField(
                controller: _hexController,
                maxLength: 6,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  prefixText: '# ',
                  prefixStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                  labelText: 'HEX код цвета',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onHexChanged,
              ),
              const SizedBox(height: 18),

              // Кнопка применить
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: current,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  AppHaptics.mediumImpact();
                  widget.onColorSelected(current);
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Применить цвет',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
