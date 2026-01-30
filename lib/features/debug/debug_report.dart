import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_logger.dart';
import '../schedule/schedule_repository.dart';
import '../grades/repository.dart';
import '../profile/repository.dart';

class DebugReport {
  static const _storage = FlutterSecureStorage();

  static Future<String> build() async {
    final b = StringBuffer();

    // ===== APP INFO =====
    String appName = '';
    String version = '';
    String buildNumber = '';
    String packageName = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appName = info.appName;
      version = info.version;
      buildNumber = info.buildNumber;
      packageName = info.packageName;
    } catch (_) {}

    // ===== HEADER =====
    b.writeln('=== VUZ APP DEBUG REPORT ===');
    b.writeln('time: ${DateTime.now().toIso8601String()}');

    // beta flag (debug always shows badge; in release depends on --dart-define=BETA=true)
    final bool betaDefine = const bool.fromEnvironment('BETA', defaultValue: false);
    b.writeln('mode: ${kReleaseMode ? 'release' : 'debug/profile'}');
    b.writeln('beta_define: $betaDefine');

    if (appName.isNotEmpty) b.writeln('appName: $appName');
    if (packageName.isNotEmpty) b.writeln('packageName: $packageName');
    if (version.isNotEmpty || buildNumber.isNotEmpty) {
      final v = version.isNotEmpty ? version : '?';
      final bn = buildNumber.isNotEmpty ? buildNumber : '?';
      b.writeln('version: $v+$bn');
    }

    try {
      b.writeln('platform: ${Platform.operatingSystem}');
      b.writeln('os_version: ${Platform.operatingSystemVersion}');
      b.writeln('locale: ${Platform.localeName}');
      b.writeln('dart: ${Platform.version}');
    } catch (_) {}

    // ===== AUTH (без утечки cookie) =====
    try {
      final cookie = await _storage.read(key: 'cookie_header');
      final present = cookie != null && cookie.trim().isNotEmpty;
      b.writeln('auth_cookie_present: $present');
      b.writeln('auth_cookie_len: ${cookie?.length ?? 0}');
      if (cookie != null && cookie.isNotEmpty) {
        final sig = base64Url.encode(utf8.encode(cookie));
        b.writeln('auth_cookie_sig: ${sig.substring(0, sig.length < 12 ? sig.length : 12)}');
      }
    } catch (e) {
      b.writeln('auth_cookie_error: $e');
    }

    // ===== REPOS =====
    final sRepo = ScheduleRepository.instance;
    final gRepo = GradesRepository.instance;
    final pRepo = ProfileRepository.instance;

    b.writeln('--- REPOS ---');
    b.writeln('schedule.loading: ${sRepo.loading}');
    b.writeln('schedule.updatedAt: ${sRepo.updatedAt?.toIso8601String()}');
    b.writeln('schedule.ttlMin: ${sRepo.ttl.inMinutes}');
    b.writeln('schedule.lastError: ${sRepo.lastError}');
    b.writeln('schedule.items: ${sRepo.lessons.length}');

    b.writeln('grades.loading: ${gRepo.loading}');
    b.writeln('grades.updatedAt: ${gRepo.updatedAt?.toIso8601String()}');
    b.writeln('grades.ttlMin: ${gRepo.ttl.inMinutes}');
    b.writeln('grades.lastError: ${gRepo.lastError}');
    b.writeln('grades.items: ${gRepo.courses.length}');

    b.writeln('profile.loading: ${pRepo.loading}');
    b.writeln('profile.updatedAt: ${pRepo.updatedAt?.toIso8601String()}');
    b.writeln('profile.ttlMin: ${pRepo.ttl.inMinutes}');
    b.writeln('profile.lastError: ${pRepo.lastError}');
    b.writeln('profile.present: ${pRepo.profile != null}');

    // ===== SharedPreferences cache stats =====
    b.writeln('--- CACHE (SharedPreferences) ---');
    try {
      final sp = await SharedPreferences.getInstance();
      final keys = sp.getKeys().toList()..sort();
      b.writeln('shared_prefs_keys_count: ${keys.length}');

      // schedule
      final schedCache = sp.getString('schedule_cache_v3');
      final schedUpd = sp.getString('schedule_cache_updated_v3');
      b.writeln('schedule_cache_bytes: ${schedCache?.length ?? 0}');
      b.writeln('schedule_cache_updated_raw: $schedUpd');

      // grades (если ключей нет — будет 0/ null, это ок)
      final gradesCache = sp.getString('grades_cache_v1');
      final gradesUpd = sp.getString('grades_cache_updated_v1');
      b.writeln('grades_cache_bytes: ${gradesCache?.length ?? 0}');
      b.writeln('grades_cache_updated_raw: $gradesUpd');

      // profile
      final profCache = sp.getString('profile_cache_v5');
      final profUpd = sp.getString('profile_cache_updated_v5');
      b.writeln('profile_cache_bytes: ${profCache?.length ?? 0}');
      b.writeln('profile_cache_updated_raw: $profUpd');

      final interesting = keys
          .where((k) =>
              k.contains('cache') ||
              k.contains('updated') ||
              k.contains('schedule') ||
              k.contains('grades') ||
              k.contains('profile'))
          .take(120)
          .toList();
      b.writeln('shared_prefs_interesting_keys: ${interesting.join(', ')}');
    } catch (e) {
      b.writeln('shared_prefs_error: $e');
    }

    // ===== LOGS =====
    final logs = AppLogger.instance.snapshot();
    b.writeln('--- LOGS (last ${logs.length}) ---');
    b.writeln(logs.join('\n'));

    b.writeln('=== END ===');
    return b.toString();
  }
}
