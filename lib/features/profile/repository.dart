import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cached_repository.dart';
import '../schedule/schedule_service.dart';
import 'models.dart';
import 'parser.dart';

const _kProfileCacheKey = 'profile_cache_v5';
const _kProfileUpdatedKey = 'profile_cache_updated_v5';

const _myUrl = 'https://eos.imes.su/my/';
const _editFallbackUrl = 'https://eos.imes.su/user/edit.php';

({String fullName, String? avatarUrl, String? profileUrl, String? editUrl})
    _parseMy(String html) =>
        ProfileParser.parseFromMy(html);

class ProfileRepository extends CachedRepository<UserProfile?> {
  ProfileRepository._()
      : super(
          initialData: null,
          ttl: const Duration(hours: 2), // профиль редко меняется
        );

  static final ProfileRepository instance = ProfileRepository._();

  /// Оставляем старые геттеры, чтобы UI не менять
  UserProfile? get profile => data;

  String _absUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return 'https://eos.imes.su$url';
    return 'https://eos.imes.su/$url';
  }

  @override
  Future<UserProfile?> readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kProfileCacheKey);
      final upd = prefs.getString(_kProfileUpdatedKey);

      if (upd != null && upd.trim().isNotEmpty) {
        setUpdatedAtFromCache(DateTime.tryParse(upd));
      }

      if (raw == null || raw.trim().isEmpty) return null;

      final j = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile(
        fullName: (j['fullName'] ?? 'Студент').toString(),
        avatarUrl: (j['avatarUrl'] as String?)?.toString(),
        fields: ((j['fields'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeCache(UserProfile? data, DateTime updatedAt) async {
    if (data == null) return;

    final prefs = await SharedPreferences.getInstance();

    final raw = jsonEncode({
      'fullName': data.fullName,
      'avatarUrl': data.avatarUrl,
      'fields': data.fields,
    });

    await prefs.setString(_kProfileCacheKey, raw);
    await prefs.setString(_kProfileUpdatedKey, updatedAt.toIso8601String());
  }

  @override
  Future<UserProfile?> fetchRemote() async {
    final service = ScheduleService();

    // 1) /my/ -> имя + аватар + (в идеале) ссылка на edit
    final myHtml = await service.loadPage(_myUrl);
    final myParsed = await compute(_parseMy, myHtml);

    final fullName = myParsed.fullName;
    final avatarUrl = myParsed.avatarUrl;

    // 2) editUrl (самое важное), иначе fallback на /user/edit.php
    final editUrl = _absUrl(myParsed.editUrl ?? _editFallbackUrl);

    final editHtml = await service.loadPage(editUrl);

    // 3) парсим все поля из edit page
    final result = ProfileParser.parseEditPage(
      editHtml,
      fallbackFullName: fullName,
      fallbackAvatarUrl: avatarUrl,
    );

    return result;
  }
}