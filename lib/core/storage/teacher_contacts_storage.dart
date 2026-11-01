import 'package:shared_preferences/shared_preferences.dart';

class TeacherContactsStorage {
  TeacherContactsStorage._();

  static String _key(String teacherName) {
    return 'teacher_email_${teacherName.trim().toLowerCase()}';
  }

  static Future<String?> getEmail(String teacherName) async {
    final name = teacherName.trim();
    if (name.isEmpty) return null;
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_key(name));
    if (v != null && v.trim().isNotEmpty) {
      return v.trim();
    }
    return null;
  }

  static Future<void> setEmail(String teacherName, String email) async {
    final name = teacherName.trim();
    if (name.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final clean = email.trim();
    if (clean.isEmpty) {
      await sp.remove(_key(name));
    } else {
      await sp.setString(_key(name), clean);
    }
  }

  static Future<void> removeEmail(String teacherName) async {
    final name = teacherName.trim();
    if (name.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key(name));
  }
}

