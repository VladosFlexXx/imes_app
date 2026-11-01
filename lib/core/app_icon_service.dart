import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppIconVariant {
  light,
  dark;

  String get key => name;
  String get title => this == AppIconVariant.light ? 'Светлая' : 'Тёмная';
  String get subtitle =>
      this == AppIconVariant.light ? 'Классика' : 'Dark Edition';
  String get assetPath => this == AppIconVariant.light
      ? 'assets/icon/icon_light.png'
      : 'assets/icon/icon_dark.png';
}

class AppIconService extends ChangeNotifier {
  AppIconService._();
  static final AppIconService instance = AppIconService._();

  static const _channel = MethodChannel('app.icon');
  static const _prefKey = 'app_icon_variant_v1';

  AppIconVariant _current = AppIconVariant.light;
  AppIconVariant get current => _current;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == 'dark') {
        _current = AppIconVariant.dark;
      } else {
        _current = AppIconVariant.light;
      }

      if (!kIsWeb && Platform.isAndroid) {
        final platformIcon = await _channel.invokeMethod<String>('getIcon');
        if (platformIcon == 'dark') {
          _current = AppIconVariant.dark;
        } else if (platformIcon == 'light') {
          _current = AppIconVariant.light;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> setIcon(AppIconVariant variant) async {
    _current = variant;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, variant.key);

      if (!kIsWeb && Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('setIcon', {
          'icon': variant.key,
        });
        return res ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

