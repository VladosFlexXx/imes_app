import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeworkItem {
  final String id;
  final String subject;
  final String title;
  final String? note;
  final DateTime? deadline;
  final bool isCompleted;
  final DateTime createdAt;

  const HomeworkItem({
    required this.id,
    required this.subject,
    required this.title,
    this.note,
    this.deadline,
    this.isCompleted = false,
    required this.createdAt,
  });

  HomeworkItem copyWith({
    String? subject,
    String? title,
    String? note,
    DateTime? deadline,
    bool? isCompleted,
  }) {
    return HomeworkItem(
      id: id,
      subject: subject ?? this.subject,
      title: title ?? this.title,
      note: note ?? this.note,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'title': title,
        'note': note,
        'deadline': deadline?.toIso8601String(),
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HomeworkItem.fromJson(Map<String, dynamic> json) {
    return HomeworkItem(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? 'Общее',
      title: json['title'] as String? ?? '',
      note: json['note'] as String?,
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class HomeworkRepository extends ChangeNotifier {
  HomeworkRepository._();
  static final HomeworkRepository instance = HomeworkRepository._();

  static const _kStorageKey = 'student_homework_list_v1';
  final List<HomeworkItem> _items = [];
  bool _loaded = false;

  List<HomeworkItem> get items => List.unmodifiable(_items);

  int get activeCount => _items.where((i) => !i.isCompleted).length;

  List<HomeworkItem> get upcomingDeadlines {
    final active = _items.where((i) => !i.isCompleted && i.deadline != null).toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
    return active;
  }

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _items.clear();
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            _items.add(HomeworkItem.fromJson(entry));
          }
        }
      }
      _loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_items.map((i) => i.toJson()).toList());
      await prefs.setString(_kStorageKey, raw);
    } catch (_) {}
  }

  Future<void> add({
    required String subject,
    required String title,
    String? note,
    DateTime? deadline,
  }) async {
    final item = HomeworkItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      subject: subject.trim().isEmpty ? 'Общее' : subject.trim(),
      title: title.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      deadline: deadline,
      createdAt: DateTime.now(),
    );
    _items.insert(0, item);
    notifyListeners();
    await _save();
  }

  Future<void> toggleComplete(String id) async {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _items[idx];
    _items[idx] = old.copyWith(isCompleted: !old.isCompleted);
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    await _save();
  }
}

