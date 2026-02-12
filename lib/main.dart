import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'features/notifications/notification_service.dart';

// ✅ новое
import 'core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter framework errors
  FlutterError.onError = (details) {
    AppLogger.instance.e(
      '[FlutterError] ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };

  // Uncaught platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.e('[Uncaught]', error, stack);
    return false;
  };

  // debugPrint -> logger
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message == null) return;
    AppLogger.instance.i(message);
  };

  AppLogger.instance.i('[BOOT] app start');
  runApp(const VuzApp());

  // ✅ стартуем сервис пушей сразу, в фоне
  unawaited(_startPushes());
}

Future<void> _startPushes() async {
  try {
    // Даем UI пройти стартовую анимацию без конкуренции за главный поток.
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    debugPrint('[BOOT] Push ensureStarted()');
    NotificationService.instance.ensureStarted();
    await NotificationService.instance.init();
    debugPrint(
      '[BOOT] Push init finished. status=${NotificationService.instance.status.value}',
    );
  } catch (e, st) {
    AppLogger.instance.e('[BOOT] Push init failed', e, st);
  }
}
