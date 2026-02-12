import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthAvatar extends StatefulWidget {
  final String? avatarUrl;
  final double radius;

  const AuthAvatar({super.key, required this.avatarUrl, required this.radius});

  @override
  State<AuthAvatar> createState() => _AuthAvatarState();
}

class _AuthAvatarState extends State<AuthAvatar> {
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
  void didUpdateWidget(covariant AuthAvatar oldWidget) {
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
      await prefs.setInt(
        _cacheTsKey(url),
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          final size = widget.radius * 2;
          return SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
            ),
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
