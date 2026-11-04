import 'package:imes_app/core/network/eios_client.dart';

/// Исторически этот класс использовался как "HTTP + cookies".
/// Оставляем его как тонкий фасад, чтобы не переписывать все репозитории.
class ScheduleService {
  final EiosClient _client;

  ScheduleService({EiosClient? client}) : _client = client ?? EiosClient.instance;

  Future<String> loadPage(String url) => _client.getHtml(url);
}
