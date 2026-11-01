import 'dart:async';
import 'package:flutter/foundation.dart';

class LessonLiveTicker extends ChangeNotifier {
  LessonLiveTicker._() {
    Timer.periodic(const Duration(seconds: 30), (_) {
      notifyListeners();
    });
  }

  static final LessonLiveTicker instance = LessonLiveTicker._();
}

class LessonLiveStatus {
  final bool isOngoing;
  final bool isUpcoming;
  final bool isFinished;
  final double progress; // 0.0 .. 1.0 (for ongoing)
  final int? remainingMinutes;
  final int? startsInMinutes;
  final String label;
  final DateTime? startDateTime;
  final DateTime? endDateTime;

  const LessonLiveStatus({
    required this.isOngoing,
    required this.isUpcoming,
    required this.isFinished,
    required this.progress,
    required this.remainingMinutes,
    required this.startsInMinutes,
    required this.label,
    required this.startDateTime,
    required this.endDateTime,
  });

  static DateTime? parseStart(String timeStr, DateTime date) {
    final raw = timeStr.split('-').first.trim().replaceAll(':', '.');
    final parts = raw.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  static DateTime? parseEnd(String timeStr, DateTime date) {
    final pieces = timeStr.split('-');
    if (pieces.length < 2) return null;
    final raw = pieces[1].trim().replaceAll(':', '.');
    final parts = raw.split('.');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  static LessonLiveStatus calculate({
    required String timeStr,
    required DateTime date,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final start = parseStart(timeStr, date);
    final end = parseEnd(timeStr, date);

    if (start == null || end == null) {
      return LessonLiveStatus(
        isOngoing: false,
        isUpcoming: false,
        isFinished: false,
        progress: 0.0,
        remainingMinutes: null,
        startsInMinutes: null,
        label: timeStr,
        startDateTime: null,
        endDateTime: null,
      );
    }

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(date.year, date.month, date.day);

    // Past day
    if (targetMidnight.isBefore(todayMidnight)) {
      return LessonLiveStatus(
        isOngoing: false,
        isUpcoming: false,
        isFinished: true,
        progress: 1.0,
        remainingMinutes: null,
        startsInMinutes: null,
        label: 'Завершена',
        startDateTime: start,
        endDateTime: end,
      );
    }

    // Future day
    if (targetMidnight.isAfter(todayMidnight)) {
      final daysDiff = targetMidnight.difference(todayMidnight).inDays;
      final timeFormatted =
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      final label = daysDiff == 1
          ? 'Завтра в $timeFormatted'
          : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} в $timeFormatted';

      return LessonLiveStatus(
        isOngoing: false,
        isUpcoming: true,
        isFinished: false,
        progress: 0.0,
        remainingMinutes: null,
        startsInMinutes: start.difference(now).inMinutes,
        label: label,
        startDateTime: start,
        endDateTime: end,
      );
    }

    // TODAY:
    if (now.isBefore(start)) {
      final diffMins = start.difference(now).inMinutes;
      final String label;
      if (diffMins <= 0) {
        label = 'Начинается';
      } else if (diffMins < 60) {
        label = 'Через $diffMins мин';
      } else if (diffMins < 120) {
        final remM = diffMins % 60;
        label = remM == 0 ? 'Через 1 час' : 'Через 1 ч $remM мин';
      } else {
        label =
            'В ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
      }

      return LessonLiveStatus(
        isOngoing: false,
        isUpcoming: true,
        isFinished: false,
        progress: 0.0,
        remainingMinutes: null,
        startsInMinutes: diffMins,
        label: label,
        startDateTime: start,
        endDateTime: end,
      );
    }

    if (now.isAfter(end)) {
      return LessonLiveStatus(
        isOngoing: false,
        isUpcoming: false,
        isFinished: true,
        progress: 1.0,
        remainingMinutes: null,
        startsInMinutes: null,
        label: 'Завершена',
        startDateTime: start,
        endDateTime: end,
      );
    }

    // ONGOING NOW!
    final totalSec = end.difference(start).inSeconds;
    final elapsedSec = now.difference(start).inSeconds;
    final progress = totalSec > 0 ? (elapsedSec / totalSec).clamp(0.0, 1.0) : 0.0;
    final remMins = end.difference(now).inMinutes + 1;

    return LessonLiveStatus(
      isOngoing: true,
      isUpcoming: false,
      isFinished: false,
      progress: progress,
      remainingMinutes: remMins,
      startsInMinutes: null,
      label: 'Идёт сейчас · $remMins мин',
      startDateTime: start,
      endDateTime: end,
    );
  }
}
