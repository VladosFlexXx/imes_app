import 'dart:collection';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationInboxItem {
  final String id;
  final String dedupeKey;
  final String source;
  final String title;
  final String body;
  final Map<String, String> data;
  final int createdAtMs;
  final bool isRead;

  const NotificationInboxItem({
    required this.id,
    required this.dedupeKey,
    required this.source,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAtMs,
    required this.isRead,
  });

  NotificationInboxItem copyWith({
    String? id,
    String? dedupeKey,
    String? source,
    String? title,
    String? body,
    Map<String, String>? data,
    int? createdAtMs,
    bool? isRead,
  }) {
    return NotificationInboxItem(
      id: id ?? this.id,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      source: source ?? this.source,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dedupeKey': dedupeKey,
    'source': source,
    'title': title,
    'body': body,
    'data': data,
    'createdAtMs': createdAtMs,
    'isRead': isRead,
  };

  static NotificationInboxItem fromJson(Map<String, dynamic> json) {
    final dataRaw = (json['data'] as Map?) ?? const {};
    return NotificationInboxItem(
      id: (json['id'] ?? '').toString(),
      dedupeKey: (json['dedupeKey'] ?? '').toString(),
      source: (json['source'] ?? 'push').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      data: dataRaw.map((k, v) => MapEntry(k.toString(), v.toString())),
      createdAtMs: (json['createdAtMs'] is int)
          ? json['createdAtMs'] as int
          : int.tryParse((json['createdAtMs'] ?? '0').toString()) ?? 0,
      isRead: json['isRead'] == true,
    );
  }
}

class NotificationInboxRepository extends ChangeNotifier {
  NotificationInboxRepository._();
  static final NotificationInboxRepository instance =
      NotificationInboxRepository._();

  static const String _prefsKey = 'notifications_inbox_v1';
  static const int _maxItems = 120;

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final List<NotificationInboxItem> _items = [];
  bool _initialized = false;

  UnmodifiableListView<NotificationInboxItem> get items =>
      UnmodifiableListView(_items);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      _syncCounters();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _items
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
              (e) => NotificationInboxItem.fromJson(
                e.map((k, v) => MapEntry(k.toString(), v)),
              ),
            ),
          );
      }
    } catch (_) {
      _items.clear();
    }

    _syncCounters();
  }

  Future<void> ingestRemoteMessage(
    RemoteMessage message, {
    bool markRead = false,
  }) async {
    await init();

    final data = <String, String>{};
    message.data.forEach((k, v) => data[k] = v.toString());

    final source = _sourceFromData(data);
    final title = (message.notification?.title ?? 'Уведомление').trim();
    final body = (message.notification?.body ?? '').trim();
    final sentMs =
        message.sentTime?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    final dedupe = _dedupeKey(
      messageId: message.messageId,
      title: title,
      body: body,
      data: data,
      sentMs: sentMs,
    );

    final idx = _items.indexWhere((e) => e.dedupeKey == dedupe);
    if (idx >= 0) {
      if (markRead && !_items[idx].isRead) {
        _items[idx] = _items[idx].copyWith(isRead: true);
        await _persist();
      }
      _syncCounters();
      return;
    }

    final item = NotificationInboxItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_items.length}',
      dedupeKey: dedupe,
      source: source,
      title: title,
      body: body,
      data: data,
      createdAtMs: sentMs,
      isRead: markRead,
    );

    _items.insert(0, item);
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }

    await _persist();
    _syncCounters();
  }

  Future<void> markRead(String id) async {
    await init();
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0 || _items[idx].isRead) return;
    _items[idx] = _items[idx].copyWith(isRead: true);
    await _persist();
    _syncCounters();
  }

  Future<void> markAllRead() async {
    await init();
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (!changed) return;
    await _persist();
    _syncCounters();
  }

  Future<void> seedDemoItems({bool replace = false}) async {
    await init();
    if (!replace && _items.isNotEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final samples = <NotificationInboxItem>[
      NotificationInboxItem(
        id: 'demo_1',
        dedupeKey: 'demo_1',
        source: 'push',
        title: 'Изменения в расписании',
        body: 'На завтра обновились 2 пары по макроэкономике.',
        data: const {'target': 'schedule'},
        createdAtMs: now - const Duration(minutes: 8).inMilliseconds,
        isRead: false,
      ),
      NotificationInboxItem(
        id: 'demo_2',
        dedupeKey: 'demo_2',
        source: 'push',
        title: 'Добавлена оценка',
        body: 'Финансовая аналитика и BI: новая оценка 5,10.',
        data: const {'target': 'grades'},
        createdAtMs: now - const Duration(hours: 1, minutes: 15).inMilliseconds,
        isRead: false,
      ),
      NotificationInboxItem(
        id: 'demo_3',
        dedupeKey: 'demo_3',
        source: 'push',
        title: 'Напоминание',
        body: 'Сегодня дедлайн по мини-кейсу №2 до 23:59.',
        data: const {'target': 'grades'},
        createdAtMs: now - const Duration(hours: 3).inMilliseconds,
        isRead: true,
      ),
      NotificationInboxItem(
        id: 'demo_4',
        dedupeKey: 'demo_4',
        source: 'system',
        title: 'Сервер уведомлений обновлён',
        body: 'Новый адрес push-сервера применён автоматически.',
        data: const {'cmd': 'push_server_update', 'target': 'profile'},
        createdAtMs: now - const Duration(hours: 6).inMilliseconds,
        isRead: true,
      ),
      NotificationInboxItem(
        id: 'demo_5',
        dedupeKey: 'demo_5',
        source: 'push',
        title: 'Расписание на следующую неделю',
        body: 'Появилась дополнительная практика в четверг.',
        data: const {'target': 'schedule'},
        createdAtMs: now - const Duration(hours: 20).inMilliseconds,
        isRead: false,
      ),
      NotificationInboxItem(
        id: 'demo_6',
        dedupeKey: 'demo_6',
        source: 'push',
        title: 'Учебный план обновлён',
        body: 'Добавлена дисциплина: Командная коммуникация и переговоры.',
        data: const {'target': 'grades'},
        createdAtMs: now - const Duration(days: 1, hours: 4).inMilliseconds,
        isRead: true,
      ),
    ];

    _items
      ..clear()
      ..addAll(samples);
    await _persist();
    _syncCounters();
  }

  String _sourceFromData(Map<String, String> data) {
    final cmd = (data['cmd'] ?? '').toLowerCase().trim();
    if (cmd == 'push_server_update') return 'system';
    return 'push';
  }

  String _dedupeKey({
    required String? messageId,
    required String title,
    required String body,
    required Map<String, String> data,
    required int sentMs,
  }) {
    if (messageId != null && messageId.trim().isNotEmpty) {
      return 'mid:$messageId';
    }
    final keys = data.keys.toList()..sort();
    final dataNorm = keys.map((k) => '$k=${data[k]}').join('&');
    return 'h:${Object.hash(title, body, dataNorm, sentMs ~/ 1000)}';
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  void _syncCounters() {
    unreadCount.value = _items.where((e) => !e.isRead).length;
    notifyListeners();
  }
}
