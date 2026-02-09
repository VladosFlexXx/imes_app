import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoMode extends ChangeNotifier {
  DemoMode._();

  static final DemoMode instance = DemoMode._();
  static const _prefsKey = 'demo_mode_enabled_v1';

  bool _enabled = false;
  bool get enabled => _enabled;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      _enabled = false;
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
    notifyListeners();
  }
}
