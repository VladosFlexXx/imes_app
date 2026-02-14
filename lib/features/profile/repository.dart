import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/cache/cached_repository.dart';
import '../../core/data_source/app_data_source.dart';
import '../../core/demo/demo_data.dart';
import '../../core/demo/demo_mode.dart';
import 'data/api_profile_remote_source.dart';
import 'data/profile_remote_source.dart';
import 'data/web_profile_remote_source.dart';
import 'models.dart';

const _kProfileCacheKey = 'profile_cache_v5';
const _kProfileUpdatedKey = 'profile_cache_updated_v5';

class ProfileRepository extends CachedRepository<UserProfile?> {
  final ProfileRemoteSource _remoteSource;

  ProfileRepository._({ProfileRemoteSource? remoteSource})
    : _remoteSource =
          remoteSource ??
          selectDataSource<ProfileRemoteSource>(
            web: WebProfileRemoteSource(),
            api: ApiProfileRemoteSource(),
          ),
      super(
        initialData: null,
        ttl: const Duration(hours: 2), // профиль редко меняется
      );

  static final ProfileRepository instance = ProfileRepository._();

  /// Оставляем старые геттеры, чтобы UI не менять
  UserProfile? get profile => data;

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
        fields: ((j['fields'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
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
    if (DemoMode.instance.enabled) {
      return DemoData.profile();
    }
    return _remoteSource.fetchProfile();
  }
}
