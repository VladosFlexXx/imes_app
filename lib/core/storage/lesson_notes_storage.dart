import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LessonNotesStorage {
  LessonNotesStorage._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Set<String> _cachedKeysWithNotes = <String>{};
  static bool _cacheInitialized = false;

  static String key(DateTime date, String subject, String time) {
    final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return 'lesson_note_${d}_${subject.trim().toLowerCase()}_${time.trim()}';
  }

  static Future<void> initCache() async {
    if (_cacheInitialized) return;
    try {
      final sp = await SharedPreferences.getInstance();
      for (final k in sp.getKeys()) {
        if (k.startsWith('lesson_note_')) {
          final val = sp.getString(k);
          if (val != null && val.trim().isNotEmpty) {
            _cachedKeysWithNotes.add(k);
          }
        }
      }
      _cacheInitialized = true;
      revision.value++;
    } catch (_) {}
  }

  static bool hasNoteSync(DateTime date, String subject, String time) {
    final k = key(date, subject, time);
    return _cachedKeysWithNotes.contains(k);
  }

  static Future<String?> getNote(DateTime date, String subject, String time) async {
    final k = key(date, subject, time);
    final sp = await SharedPreferences.getInstance();
    final val = sp.getString(k);
    if (val != null && val.trim().isNotEmpty) {
      _cachedKeysWithNotes.add(k);
      return val.trim();
    }
    _cachedKeysWithNotes.remove(k);
    return null;
  }

  static Future<void> setNote(DateTime date, String subject, String time, String text) async {
    final k = key(date, subject, time);
    final sp = await SharedPreferences.getInstance();
    final clean = text.trim();
    if (clean.isEmpty) {
      await sp.remove(k);
      _cachedKeysWithNotes.remove(k);
    } else {
      await sp.setString(k, clean);
      _cachedKeysWithNotes.add(k);
    }
    revision.value++;
  }

  static Future<void> deleteNote(DateTime date, String subject, String time) async {
    await setNote(date, subject, time, '');
  }
}

