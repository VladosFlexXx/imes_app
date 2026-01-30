import 'dart:io';
import 'package:flutter/services.dart';

class LogExporter {
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<File> exportToTempFile(String reportText) async {
    final dir = Directory.systemTemp;
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/vuz_app_debug_$ts.txt');
    await file.writeAsString(reportText, flush: true);
    return file;
  }
}
