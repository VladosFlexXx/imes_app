import 'dart:io';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static Future<void> shareFile(File file, {String? text}) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: text);
  }
}
