import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'schedule_repository.dart';

class LessonReminderService {
  LessonReminderService._();
  static final LessonReminderService instance = LessonReminderService._();

  static const _kEnabledKey = 'lesson_reminders_enabled_v1';
  static const _kMinutesBeforeKey = 'lesson_reminders_minutes_v1';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Moscow'));
    } catch (_) {}
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabledKey) ?? false;
  }

  Future<int> getMinutesBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kMinutesBeforeKey) ?? 15;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, enabled);
    if (enabled) {
      await rescheduleAll();
    } else {
      await cancelAll();
    }
  }

  Future<void> setMinutesBefore(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMinutesBeforeKey, minutes);
    final enabled = await isEnabled();
    if (enabled) {
      await rescheduleAll();
    }
  }

  DateTime? _parseStartTime(String time, DateTime day) {
    final start = time.split('-').first.trim().replaceAll(':', '.');
    final parts = start.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  Future<void> rescheduleAll() async {
    await init();
    await cancelAll();

    final enabled = await isEnabled();
    if (!enabled) return;

    final minutesBefore = await getMinutesBefore();
    final now = DateTime.now();
    final repo = ScheduleRepository.instance;

    var notifId = 1000;
    for (var i = 0; i <= 7; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final lessons = repo.lessonsForDate(day);

      for (final l in lessons) {
        final start = _parseStartTime(l.time, day);
        if (start == null) continue;

        final reminderTime = start.subtract(Duration(minutes: minutesBefore));
        if (reminderTime.isBefore(now)) continue;

        try {
          final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

          const androidDetails = AndroidNotificationDetails(
            'lesson_reminders',
            'Напоминания о парах',
            channelDescription: 'Уведомления за 15-30 минут до начала пары',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          );

          await _local.zonedSchedule(
            notifId++,
            'Через $minutesBefore мин: ${l.subject}',
            '${l.place.isNotEmpty ? 'Ауд. ${l.place} · ' : ''}${l.time}${l.teacher.isNotEmpty ? ' · ${l.teacher}' : ''}',
            tzReminderTime,
            const NotificationDetails(android: androidDetails),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: jsonEncode({'target': 'schedule'}),
          );
        } catch (_) {}
      }
    }
  }

  Future<void> cancelAll() async {
    for (var id = 1000; id < 1200; id++) {
      try {
        await _local.cancel(id);
      } catch (_) {}
    }
  }
}
