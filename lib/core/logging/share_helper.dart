import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static Future<void> shareFile(File file, {String? text}) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: text);
  }

  static Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  static Future<void> shareReport({
    required String report,
    File? file,
    String? subject = 'Отчёт диагностики Мой ИМЭС',
  }) async {
    if (!kIsWeb && file != null) {
      await shareFile(file, text: subject);
    } else {
      await shareText(report, subject: subject);
    }
  }
}
