import 'dart:collection';
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int maxLines = 4000;
  final ListQueue<String> _lines = ListQueue(maxLines);

  List<String> snapshot() => List.unmodifiable(_lines);

  void clear() => _lines.clear();

  void i(String msg) => _add('I', msg);
  void w(String msg) => _add('W', msg);
  void e(String msg, [Object? err, StackTrace? st]) {
    final extra = [
      if (err != null) 'err=$err',
      if (st != null) 'st=$st',
    ].join('\n');
    _add('E', extra.isEmpty ? msg : '$msg\n$extra');
  }

  void _add(String level, String msg) {
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts][$level] $msg';

    if (_lines.length == maxLines) _lines.removeFirst();
    _lines.addLast(line);

    if (kDebugMode) {
      // ignore: avoid_print
      print(line);
    }
  }
}
