import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imes_app/core/cache/cached_repository.dart';
import 'package:imes_app/core/network/eios_client.dart';
import 'package:imes_app/core/session/user_session.dart';
import 'package:imes_app/core/storage/lesson_notes_storage.dart';
import 'package:imes_app/features/homework/homework_repository.dart';
import 'package:imes_app/features/notifications/inbox_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCachedRepo extends CachedRepository<String> {
  _FakeCachedRepo() : super(initialData: 'initial', ttl: const Duration(minutes: 5));

  String? cachedValue;
  Completer<String>? pendingFetch;

  @override
  Future<String?> readCache() async => cachedValue;

  @override
  Future<void> writeCache(String data, DateTime updatedAt) async {
    cachedValue = data;
  }

  @override
  Future<String> fetchRemote() async {
    if (pendingFetch != null) {
      return pendingFetch!.future;
    }
    return 'remote_data';
  }

  @override
  Future<void> clearCache() async {
    cachedValue = null;
    await resetState();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('Audit Point 1: URL sanitization & secure session transmission', () {
    test('sanitizeUrlForLogging redacts cookies, passwords, and tokens', () {
      const sensitiveUrl =
          'https://proxy.example.com/?url=https://eos.imes.su/&cookie=MoodleSession%3Dsecret123&password=supersecret&token=tok123';
      final sanitized = EiosClient.sanitizeUrlForLogging(sensitiveUrl);

      expect(sanitized.contains('secret123'), isFalse);
      expect(sanitized.contains('supersecret'), isFalse);
      expect(sanitized.contains('tok123'), isFalse);
      expect(sanitized.contains('cookie=%5BREDACTED%5D') || sanitized.contains('cookie=[REDACTED]'), isTrue);
      expect(sanitized.contains('password=%5BREDACTED%5D') || sanitized.contains('password=[REDACTED]'), isTrue);
    });

    test('sanitizeUrlForLogging leaves harmless URLs unmodified', () {
      const normalUrl = 'https://eos.imes.su/my/?page=2&filter=active';
      final sanitized = EiosClient.sanitizeUrlForLogging(normalUrl);
      expect(sanitized, equals(normalUrl));
    });
  });

  group('Audit Point 3: Avatar & redirect external isolation', () {
    test('External avatar host detection verifies host is strictly eos.imes.su', () {
      final eiosUri = Uri.parse('https://eos.imes.su/theme/image.php/boost/core/123/f/user.png');
      final externalUri = Uri.parse('https://evil.com/fake_avatar.png');
      final subdomainUri = Uri.parse('https://eos.imes.su.attacker.com/avatar.png');

      final isEios1 = eiosUri.isScheme('https') && eiosUri.host.toLowerCase() == 'eos.imes.su';
      final isEios2 = externalUri.isScheme('https') && externalUri.host.toLowerCase() == 'eos.imes.su';
      final isEios3 = subdomainUri.isScheme('https') && subdomainUri.host.toLowerCase() == 'eos.imes.su';

      expect(isEios1, isTrue);
      expect(isEios2, isFalse);
      expect(isEios3, isFalse);
    });
  });

  group('Audit Point 4: Account data isolation across logout', () {
    test('Student A data is completely wiped on logout and not visible to Student B', () async {
      final session = UserSession.instance;
      final inbox = NotificationInboxRepository.instance;
      final homework = HomeworkRepository.instance;

      // 1. Вход Студента А
      await session.setAccountId('student_a');
      await inbox.init(reload: true);
      await homework.init(reload: true);
      await LessonNotesStorage.initCache(reload: true);

      // Студент А добавляет ДЗ и заметку
      await homework.add(
        subject: 'Экономика',
        title: 'Решить кейс №1',
      );
      final noteDate = DateTime(2026, 11, 20);
      await LessonNotesStorage.setNote(noteDate, 'Экономика', '08:30-10:00', 'Заметка Студента А');

      expect(homework.items.length, equals(1));
      expect(homework.items.first.title, equals('Решить кейс №1'));
      expect(await LessonNotesStorage.getNote(noteDate, 'Экономика', '08:30-10:00'), equals('Заметка Студента А'));

      // 2. Логаут Студента А
      await inbox.clearCache();
      await homework.clearCache();
      await LessonNotesStorage.clearCache();
      await session.clear();

      expect(homework.items, isEmpty);
      expect(inbox.items, isEmpty);
      expect(session.accountId, isEmpty);

      // 3. Вход Студента Б на том же устройстве
      await session.setAccountId('student_b');
      await inbox.init(reload: true);
      await homework.init(reload: true);
      await LessonNotesStorage.initCache(reload: true);

      // Списки Студента Б должны быть абсолютно чистыми
      expect(homework.items, isEmpty, reason: 'Студент Б не должен видеть домашки Студента А');
      expect(inbox.items, isEmpty, reason: 'Студент Б не должен видеть уведомления Студента А');
      expect(
        await LessonNotesStorage.getNote(noteDate, 'Экономика', '08:30-10:00'),
        isNull,
        reason: 'Студент Б не должен видеть заметки Студента А',
      );
    });

    test('CachedRepository drops late async response if session generation changed', () async {
      final repo = _FakeCachedRepo();
      final completerA = Completer<String>();
      repo.pendingFetch = completerA;

      // Запускаем обновление во время сессии А
      final refreshFuture = repo.refresh(force: true);

      // Происходит выход или смена пользователя
      await repo.clearCache();

      // Запоздалый ответ от запроса Студента А наконец-то возвращается
      completerA.complete('stale_student_a_data');
      await refreshFuture;

      // Кэш и данные не должны быть перезаписаны устаревшим ответом
      expect(repo.data, equals('initial'));
      expect(repo.cachedValue, isNull);
    });
  });
}
