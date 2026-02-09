part of '../../home/tab_profile.dart';

class _AuthAvatar extends StatefulWidget {
  final String? avatarUrl;
  final double radius;

  const _AuthAvatar({required this.avatarUrl, required this.radius});

  @override
  State<_AuthAvatar> createState() => _AuthAvatarState();
}

class _AuthAvatarState extends State<_AuthAvatar> {
  static const _storage = FlutterSecureStorage();
  static const _cacheTtl = Duration(days: 3);
  static final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _loadBytes(widget.avatarUrl);
  }

  @override
  void didUpdateWidget(covariant _AuthAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _bytesFuture = _loadBytes(widget.avatarUrl);
    }
  }

  Future<Uint8List?> _loadBytes(String? rawUrl) async {
    final url = rawUrl?.trim();
    if (url == null || url.isEmpty) return null;

    final mem = _memoryCache[url];
    if (mem != null && mem.isNotEmpty) return mem;

    final disk = await _readDiskCache(url);
    if (disk != null && disk.isNotEmpty) {
      _memoryCache[url] = disk;
      return disk;
    }

    try {
      final cookie = (await _storage.read(key: 'cookie_header')) ?? '';
      final res = await http.get(
        Uri.parse(url),
        headers: {
          if (cookie.isNotEmpty) 'Cookie': cookie,
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          'Referer': 'https://eos.imes.su/',
        },
      );
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          res.bodyBytes.isNotEmpty) {
        _memoryCache[url] = res.bodyBytes;
        await _writeDiskCache(url, res.bodyBytes);
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  String _cacheDataKey(String url) => 'avatar_cache_data::$url';
  String _cacheTsKey(String url) => 'avatar_cache_ts::$url';

  Future<Uint8List?> _readDiskCache(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_cacheTsKey(url));
      final raw = prefs.getString(_cacheDataKey(url));
      if (ts == null || raw == null || raw.isEmpty) return null;

      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheTtl.inMilliseconds) return null;

      final bytes = base64Decode(raw);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(String url, Uint8List bytes) async {
    if (bytes.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheDataKey(url), base64Encode(bytes));
      await prefs.setInt(_cacheTsKey(url), DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          return CircleAvatar(
            radius: widget.radius,
            backgroundImage: MemoryImage(bytes),
          );
        }
        return CircleAvatar(
          radius: widget.radius,
          child: Icon(Icons.person_outline, size: widget.radius + 3),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile? profile;

  const _ProfileHeader({
    required this.profile,
  });

  String _subtitleLine(UserProfile p) {
    final parts = <String>[];
    final group = p.group;
    final level = p.level;
    final eduForm = p.eduForm;

    if (group != null && group.trim().isNotEmpty) parts.add(group.trim());
    if (level != null && level.trim().isNotEmpty) parts.add(level.trim());
    if (eduForm != null && eduForm.trim().isNotEmpty) parts.add(eduForm.trim());

    return parts.isEmpty ? 'Профиль ЭИОС' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (p == null) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: const [
              Row(
                children: [
                  _SkeletonCircle(size: 62),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(width: 240, height: 22),
                        SizedBox(height: 8),
                        _SkeletonLine(width: 180, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              _SkeletonLine(width: double.infinity, height: 10),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AuthAvatar(avatarUrl: p.avatarUrl, radius: 48),
            const SizedBox(height: 12),
            Text(
              p.fullName,
              textAlign: TextAlign.center,
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _subtitleLine(p),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
