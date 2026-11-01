import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_sheet.dart';

class AppReleaseInfo {
  final String version;
  final String tagName;
  final String title;
  final String changelog;
  final String apkUrl;
  final int apkSize;
  final String apkName;
  final DateTime? publishedAt;

  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.changelog,
    required this.apkUrl,
    required this.apkSize,
    required this.apkName,
    this.publishedAt,
  });

  String get formattedSize {
    if (apkSize <= 0) return '';
    final mb = apkSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ';
  }
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _repoOwner = 'VladosFlexXx';
  static const _repoName = 'imes_app';
  static const _skippedVersionKey = 'update_skipped_version_v1';
  static const _channel = MethodChannel('app.updater');

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  Future<AppReleaseInfo?> checkUpdate({bool force = false}) async {
    if (_isChecking) return null;
    _isChecking = true;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version.trim();

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );

      final res = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'MyIMES-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?)?.trim() ?? '';
      final title = (data['name'] as String?)?.trim() ?? tagName;
      final body = (data['body'] as String?)?.trim() ?? '';

      // Normalize tag version (e.g. "v0.3.7" -> "0.3.7")
      final remoteVersion = tagName.replaceAll(RegExp(r'^[vV]'), '').trim();
      if (remoteVersion.isEmpty) return null;

      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getString(_skippedVersionKey);
        if (skipped == remoteVersion) {
          return null;
        }
      }

      final isNewer = _isVersionGreater(remoteVersion, currentVersion);
      if (!isNewer) return null;

      // Find APK asset
      final assets = (data['assets'] as List<dynamic>?) ?? [];
      Map<String, dynamic>? apkAsset;
      for (final a in assets) {
        final name = (a['name'] as String?)?.toLowerCase() ?? '';
        if (name.endsWith('.apk')) {
          apkAsset = a as Map<String, dynamic>;
          break;
        }
      }

      if (apkAsset == null) return null;

      final apkUrl = apkAsset['browser_download_url'] as String? ?? '';
      if (apkUrl.isEmpty) return null;

      final apkSize = (apkAsset['size'] as num?)?.toInt() ?? 0;
      final apkName = apkAsset['name'] as String? ?? 'app-update.apk';

      DateTime? publishedAt;
      if (data['published_at'] != null) {
        publishedAt = DateTime.tryParse(data['published_at'].toString());
      }

      return AppReleaseInfo(
        version: remoteVersion,
        tagName: tagName,
        title: title.isNotEmpty ? title : 'Обновление $remoteVersion',
        changelog: body,
        apkUrl: apkUrl,
        apkSize: apkSize,
        apkName: apkName,
        publishedAt: publishedAt,
      );
    } catch (_) {
      return null;
    } finally {
      _isChecking = false;
    }
  }

  bool _isVersionGreater(String remote, String current) {
    try {
      final rParts = _parseVersion(remote);
      final cParts = _parseVersion(current);

      final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
      for (var i = 0; i < maxLen; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return remote != current;
    }
  }

  List<int> _parseVersion(String v) {
    final clean = v.split('+').first.replaceAll(RegExp(r'[^\d.]'), '');
    return clean
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
  }

  Future<void> skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skippedVersionKey, version);
    } catch (_) {}
  }

  Future<void> downloadApk({
    required AppReleaseInfo release,
    required void Function(double progress, int received, int total) onProgress,
    required void Function(String filePath) onComplete,
    required void Function(Object error) onError,
  }) async {
    final client = http.Client();
    IOSink? sink;
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/${release.apkName}';
      final file = File(savePath);

      if (await file.exists()) {
        await file.delete();
      }

      final request = http.Request('GET', Uri.parse(release.apkUrl));
      request.headers['User-Agent'] = 'MyIMES-App';

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw HttpException('Ошибка загрузки APK: HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? release.apkSize;
      var received = 0;

      sink = file.openWrite();

      await response.stream
          .timeout(const Duration(seconds: 45))
          .listen((chunk) {
            sink?.add(chunk);
            received += chunk.length;
            final progress =
                total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
            onProgress(progress, received, total);
          })
          .asFuture();

      await sink.flush();
      await sink.close();
      sink = null;

      onComplete(savePath);
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      onError(e);
    } finally {
      client.close();
    }
  }

  Future<bool> installApk(String filePath) async {
    try {
      if (!Platform.isAndroid) return false;
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  void showUpdateModal(BuildContext context, AppReleaseInfo release) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdateSheet(release: release),
    );
  }

  Future<void> checkAndPrompt(BuildContext context, {bool force = false}) async {
    final release = await checkUpdate(force: force);
    if (!context.mounted) return;

    if (release != null) {
      showUpdateModal(context, release);
    } else if (force) {
      final info = await PackageInfo.fromPlatform();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('У вас установлена последняя версия v${info.version}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

