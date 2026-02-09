import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'inbox_repository.dart';

/// Куда навигируемся после тапа по пушу.
enum AppNavTarget { home, schedule, grades, profile }

class NotificationAction {
  final AppNavTarget target;
  final Map<String, String> data;
  const NotificationAction(this.target, this.data);
}

class PushServerConfig {
  final String baseUrl;
  final String registerSecret;
  const PushServerConfig({required this.baseUrl, required this.registerSecret});

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && registerSecret.trim().isNotEmpty;
}

class PushPingResult {
  final bool ok;
  final String message;
  const PushPingResult(this.ok, this.message);
}

class PushRegisterResult {
  final bool ok;
  final int? statusCode;
  final String message;
  const PushRegisterResult({
    required this.ok,
    required this.message,
    this.statusCode,
  });
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _prefsKeyEnabled = 'push_enabled';
  static const _prefsKeyToken = 'push_fcm_token';

  static const _prefsKeyServerUrl = 'push_server_url';
  static const _prefsKeyRegisterSecret = 'push_register_secret';

  /// Дефолт удобен для эмулятора Android.
  /// На реальном телефоне это НЕ сработает — нужен IP/домен сервера.
  static const String _defaultServerUrl = 'http://192.168.137.1:8080';
  static const String _bootstrapConfigUrl =
      'https://raw.githubusercontent.com/VladosFlexXx/eios/main/vuz_app/config/push_bootstrap.json';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _fcm;

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  final ValueNotifier<String?> token = ValueNotifier<String?>(null);

  /// Текущие настройки сервера.
  final ValueNotifier<PushServerConfig> serverConfig =
      ValueNotifier<PushServerConfig>(
        const PushServerConfig(baseUrl: _defaultServerUrl, registerSecret: ''),
      );

  /// Человекочитаемый статус пушей/регистрации.
  final ValueNotifier<String> status = ValueNotifier<String>(
    'Пуши: не запущены',
  );
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  /// Последний результат проверки /health.
  final ValueNotifier<PushPingResult?> lastPing =
      ValueNotifier<PushPingResult?>(null);

  /// Последний результат регистрации/снятия регистрации.
  final ValueNotifier<PushRegisterResult?> lastRegister =
      ValueNotifier<PushRegisterResult?>(null);

  /// Куда перейти после тапа.
  final ValueNotifier<NotificationAction?> action =
      ValueNotifier<NotificationAction?>(null);

  bool _started = false;
  bool _ready = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'schedule_changes',
    'Изменения расписания',
    description: 'Уведомления об изменениях в расписании',
    importance: Importance.high,
  );

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {}

  bool get isReady => _ready;

  void ensureStarted() {
    if (_started) return;
    _started = true;
    _start();
  }

  Future<void> init() async {
    ensureStarted();
    for (int i = 0; i < 200; i++) {
      if (_ready) return;
      await Future.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<void> _start() async {
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _initLocalNotifications();
      await _restoreState();
      await _refreshServerConfigFromBootstrap();
      await NotificationInboxRepository.instance.init();

      FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteTap);
      final initial = await _fcm!.getInitialMessage();
      if (initial != null) _handleRemoteTap(initial);

      FirebaseMessaging.onMessage.listen((message) async {
        await NotificationInboxRepository.instance.ingestRemoteMessage(message);
        await _maybeApplyRemoteServerConfigFromData(message.data);
        await _showLocalFromRemote(message);
      });

      _fcm!.onTokenRefresh.listen((t) async {
        token.value = t;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKeyToken, t);
        if (enabled.value) {
          await registerNow();
        }
      });

      _ready = true;

      if (enabled.value) {
        await _enableInternal();
      }
    } catch (e) {
      lastError.value = e.toString();
      status.value = 'Ошибка пушей';
    }
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();

    enabled.value = prefs.getBool(_prefsKeyEnabled) ?? false;
    token.value = prefs.getString(_prefsKeyToken);

    final savedUrl = (prefs.getString(_prefsKeyServerUrl) ?? '').trim();
    final savedSecret = (prefs.getString(_prefsKeyRegisterSecret) ?? '').trim();

    serverConfig.value = PushServerConfig(
      baseUrl: savedUrl.isNotEmpty ? savedUrl : _defaultServerUrl,
      registerSecret: savedSecret,
    );
  }

  Future<void> _refreshServerConfigFromBootstrap() async {
    try {
      final resp = await http
          .get(Uri.parse(_bootstrapConfigUrl))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return;

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return;

      final url = (decoded['push_base_url'] ?? '').toString().trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) return;

      final secret = (decoded['register_secret'] ?? '').toString().trim();
      final current = serverConfig.value;
      if (current.baseUrl.trim() == url &&
          current.registerSecret.trim() == secret) {
        return;
      }

      await saveServerConfig(baseUrl: url, registerSecret: secret);
      status.value = 'Пуши: сервер обновлён из bootstrap';
      lastError.value = null;

      if (enabled.value) {
        await registerNow();
      }
    } catch (_) {
      // bootstrap optional: ignore network errors
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload != null) {
          unawaited(_handlePayloadString(resp.payload!));
        }
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _fcm!.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Сохранить настройки сервера в SharedPreferences.
  /// Если пуши включены и токен уже есть — сразу попробуем зарегистрироваться.
  Future<void> saveServerConfig({
    required String baseUrl,
    required String registerSecret,
  }) async {
    final url = baseUrl.trim();
    final secret = registerSecret.trim();

    serverConfig.value = PushServerConfig(baseUrl: url, registerSecret: secret);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyServerUrl, url);
    await prefs.setString(_prefsKeyRegisterSecret, secret);

    lastError.value = null;

    if (enabled.value) {
      await registerNow();
    }
  }

  /// Быстрая проверка /health.
  Future<PushPingResult> pingServer() async {
    final cfg = serverConfig.value;
    final url = cfg.baseUrl.trim();

    if (url.isEmpty) {
      final r = const PushPingResult(false, 'Не задан адрес push-сервера');
      lastPing.value = r;
      return r;
    }

    try {
      final resp = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final r = const PushPingResult(true, 'Соединение OK');
        lastPing.value = r;
        return r;
      }

      final r = PushPingResult(
        false,
        'Ошибка /health: HTTP ${resp.statusCode}',
      );
      lastPing.value = r;
      return r;
    } catch (e) {
      final r = PushPingResult(false, 'Не удалось подключиться: $e');
      lastPing.value = r;
      return r;
    }
  }

  Future<void> setEnabled(bool value) async {
    ensureStarted();

    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyEnabled, value);

    if (!value) {
      final t = token.value;
      if (t != null) {
        await _unregisterTokenOnServer(t);
      }
      await _fcm?.deleteToken();
      token.value = null;
      await prefs.remove(_prefsKeyToken);
      status.value = 'Пуши: выключены';
      return;
    }

    if (_ready) {
      await _enableInternal();
    }
  }

  Future<void> _enableInternal() async {
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      lastError.value = 'Нет разрешения на уведомления';
      status.value = 'Пуши: нет разрешения';
      return;
    }

    final t = await _fcm!.getToken();
    if (t == null) {
      lastError.value = 'Не удалось получить FCM token';
      return;
    }

    token.value = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyToken, t);

    final reg = await registerNow();
    if (!reg.ok) {
      lastError.value = reg.message;
      status.value = 'Пуши: токен есть, но сервер не принял регистрацию';
      return;
    }

    status.value = 'Пуши: включены';
  }

  /// Явная регистрация текущего токена на сервере (удобно для кнопки в UI).
  Future<PushRegisterResult> registerNow() async {
    final t = token.value;
    if (t == null || t.trim().isEmpty) {
      final r = const PushRegisterResult(
        ok: false,
        message: 'Нет токена (включи пуши)',
      );
      lastRegister.value = r;
      return r;
    }

    final cfg = serverConfig.value;
    if (!cfg.isConfigured) {
      final r = const PushRegisterResult(
        ok: false,
        message: 'Не настроен push-сервер: укажи URL и секрет',
      );
      lastRegister.value = r;
      return r;
    }

    final r = await _registerTokenOnServer(t);
    lastRegister.value = r;
    if (r.ok) {
      lastError.value = null;
      status.value = 'Пуши: включены';
    } else {
      lastError.value = r.message;
      status.value = 'Пуши: ошибка регистрации';
    }
    return r;
  }

  Future<PushRegisterResult> _registerTokenOnServer(String token) async {
    final cfg = serverConfig.value;

    try {
      final resp = await http
          .post(
            Uri.parse('${cfg.baseUrl}/register'),
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              'X-Register-Secret': cfg.registerSecret,
            },
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        return const PushRegisterResult(
          ok: true,
          message: 'Токен зарегистрирован',
        );
      }

      String details = resp.body;
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded['error'] != null) {
          details = decoded['error'].toString();
        }
      } catch (_) {}

      return PushRegisterResult(
        ok: false,
        statusCode: resp.statusCode,
        message: 'Ошибка регистрации: HTTP ${resp.statusCode} ($details)',
      );
    } catch (e) {
      debugPrint('[PUSH] register error: $e');
      return PushRegisterResult(ok: false, message: 'Ошибка сети: $e');
    }
  }

  Future<void> _unregisterTokenOnServer(String token) async {
    final cfg = serverConfig.value;
    if (!cfg.isConfigured) return;

    try {
      await http
          .post(
            Uri.parse('${cfg.baseUrl}/unregister'),
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              'X-Register-Secret': cfg.registerSecret,
            },
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> _showLocalFromRemote(RemoteMessage message) async {
    final title = message.notification?.title ?? 'ЭИОС';
    final body = message.notification?.body ?? '';
    final payload = message.data.isNotEmpty ? jsonEncode(message.data) : '';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  AppNavTarget _targetFromData(Map<String, String> data) {
    final raw = (data['target'] ?? '').trim().toLowerCase();
    switch (raw) {
      case 'home':
        return AppNavTarget.home;
      case 'grades':
        return AppNavTarget.grades;
      case 'profile':
        return AppNavTarget.profile;
      case 'schedule':
      default:
        return AppNavTarget.schedule;
    }
  }

  Future<void> _maybeApplyRemoteServerConfigFromData(
    Map<String, dynamic> raw,
  ) async {
    final data = <String, String>{};
    raw.forEach((k, v) => data[k.toString()] = v.toString());

    final cmd = (data['cmd'] ?? '').trim().toLowerCase();
    final newUrl = (data['server_url'] ?? '').trim();
    final maybeSecret = (data['server_secret'] ?? '').trim();

    final shouldApply = cmd == 'push_server_update' || newUrl.isNotEmpty;
    if (!shouldApply) return;
    if (!newUrl.startsWith('http://') && !newUrl.startsWith('https://')) return;

    final current = serverConfig.value;
    final secret = maybeSecret.isNotEmpty
        ? maybeSecret
        : current.registerSecret;

    if (current.baseUrl.trim() == newUrl &&
        current.registerSecret.trim() == secret) {
      return;
    }

    await saveServerConfig(baseUrl: newUrl, registerSecret: secret);
    status.value = 'Пуши: сервер обновлён командой';
    lastError.value = null;
  }

  Future<void> _handleRemoteTap(RemoteMessage message) async {
    await NotificationInboxRepository.instance.ingestRemoteMessage(
      message,
      markRead: true,
    );
    await _maybeApplyRemoteServerConfigFromData(message.data);
    final data = <String, String>{};
    message.data.forEach((k, v) => data[k] = v.toString());
    action.value = NotificationAction(_targetFromData(data), data);
  }

  Future<void> _handlePayloadString(String payload) async {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      await _maybeApplyRemoteServerConfigFromData(
        decoded.map((k, v) => MapEntry(k.toString(), v)),
      );
      final data = <String, String>{};
      decoded.forEach((k, v) => data[k.toString()] = v.toString());
      action.value = NotificationAction(_targetFromData(data), data);
    }
  }
}
