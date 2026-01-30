import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

/// Простой базовый класс "кеш + автообновление".
///
/// Идея по-человечески:
/// - сначала показываем кеш (если есть)
/// - потом обновляем из сети (если нужно)
/// - если интернет упал — ничего не ломаем, просто сохраняем ошибку
abstract class CachedRepository<T> extends ChangeNotifier {
  CachedRepository({
    required T initialData,
    required Duration ttl,
  })  : _data = initialData,
        _ttl = ttl;

  final Duration _ttl;

  T _data;
  DateTime? _updatedAt;
  bool _loading = false;
  Object? _lastError;

  T get data => _data;
  DateTime? get updatedAt => _updatedAt;
  bool get loading => _loading;
  Object? get lastError => _lastError;
  Duration get ttl => _ttl;

  String get debugName => runtimeType.toString();

  Future<T?> readCache();
  Future<void> writeCache(T data, DateTime updatedAt);
  Future<T> fetchRemote();

  Future<void> init() async {
    await _loadCacheOnly();
  }

  Future<void> initAndRefresh({bool force = true}) async {
    await init();
    await refresh(force: force);
  }

  bool _isStale() {
    final t = _updatedAt;
    if (t == null) return true;
    return DateTime.now().difference(t) >= _ttl;
  }

  Future<void> _loadCacheOnly() async {
    AppLogger.instance.i('[$debugName] cache load start');
    try {
      final cached = await readCache();
      if (cached == null) {
        AppLogger.instance.i('[$debugName] cache empty');
        return;
      }

      _data = cached;
      AppLogger.instance.i('[$debugName] cache loaded');
      notifyListeners();
    } catch (e, st) {
      AppLogger.instance.e('[$debugName] cache load error', e, st);
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;

    if (!force && !_isStale()) {
      AppLogger.instance.i('[$debugName] refresh skipped (fresh)');
      return;
    }

    _loading = true;
    _lastError = null;
    notifyListeners();

    final sw = Stopwatch()..start();
    AppLogger.instance.i('[$debugName] refresh start force=$force');

    try {
      final fresh = await fetchRemote();
      _data = fresh;
      _updatedAt = DateTime.now();
      await writeCache(_data, _updatedAt!);

      sw.stop();
      AppLogger.instance.i(
        '[$debugName] refresh ok (${sw.elapsedMilliseconds}ms) updatedAt=${_updatedAt?.toIso8601String()}',
      );
    } catch (e, st) {
      sw.stop();
      _lastError = e;
      AppLogger.instance.e('[$debugName] refresh error (${sw.elapsedMilliseconds}ms)', e, st);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Если внутри readCache ты восстановил updatedAt — вызови это.
  @protected
  void setUpdatedAtFromCache(DateTime? time) {
    _updatedAt = time;
  }
}
