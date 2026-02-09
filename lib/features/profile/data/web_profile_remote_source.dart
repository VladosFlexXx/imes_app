import 'package:flutter/foundation.dart';

import '../../../core/network/eios_endpoints.dart';
import '../../schedule/schedule_service.dart';
import '../models.dart';
import '../parser.dart';
import 'profile_remote_source.dart';

({String fullName, String? avatarUrl, String? profileUrl, String? editUrl})
_parseMy(String html) => ProfileParser.parseFromMy(html);
String? _parseAvatarFromProfile(String html) =>
    ProfileParser.parseAvatarFromProfilePage(html);

class WebProfileRemoteSource implements ProfileRemoteSource {
  final ScheduleService _service;

  WebProfileRemoteSource({ScheduleService? service})
    : _service = service ?? ScheduleService();

  String _absUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '${EiosEndpoints.base}$url';
    return '${EiosEndpoints.base}/$url';
  }

  String? _normalizeAvatarUrl(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    // Локальные ссылки из сохранённого браузером HTML не годятся для сети.
    if (u.startsWith('./') || u.startsWith('../')) return null;
    return _absUrl(u);
  }

  @override
  Future<UserProfile?> fetchProfile() async {
    final myHtml = await _service.loadPage(EiosEndpoints.my);
    final myParsed = await compute(_parseMy, myHtml);

    final fullName = myParsed.fullName;
    var avatarUrl = _normalizeAvatarUrl(myParsed.avatarUrl);

    // В /my/ часто только инициалы без img.userpicture.
    // Тогда добираем аватар со страницы профиля.
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      final profileUrl = _absUrl(myParsed.profileUrl ?? '/user/profile.php');
      try {
        final profileHtml = await _service.loadPage(profileUrl);
        avatarUrl = _normalizeAvatarUrl(
          await compute(_parseAvatarFromProfile, profileHtml),
        );
      } catch (_) {
        // Не блокируем загрузку профиля, если страница профиля недоступна.
      }
    }

    final editUrl = _absUrl(myParsed.editUrl ?? EiosEndpoints.userEdit);
    final editHtml = await _service.loadPage(editUrl);

    final parsed = ProfileParser.parseEditPage(
      editHtml,
      fallbackFullName: fullName,
      fallbackAvatarUrl: avatarUrl,
    );
    return UserProfile(
      fullName: parsed.fullName,
      avatarUrl: _normalizeAvatarUrl(parsed.avatarUrl),
      fields: parsed.fields,
    );
  }
}
