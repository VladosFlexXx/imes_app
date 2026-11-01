import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vuz_app/ui/startup_gate.dart';

const _splashKey = Key('splash');
const _screenKey = Key('screen');

Widget _app(
  Future<void> Function() prepare, {
  WidgetBuilder? builder,
}) => MaterialApp(
  home: StartupGate(
    prepare: prepare,
    builder: builder ?? (_) => const Scaffold(key: _screenKey),
    splash: const ColoredBox(key: _splashKey, color: Colors.orange),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });
  testWidgets('waits for readiness beyond the old six-second delay', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(_app(() => ready.future));
    await tester.pump(const Duration(seconds: 10));
    expect(find.byKey(_splashKey), findsOneWidget);
    expect(find.byKey(_screenKey), findsNothing);

    ready.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(_splashKey), findsNothing);
    expect(find.byKey(_screenKey), findsOneWidget);
  });

  testWidgets('renders under splash and reveals without a minimum wait', (
    tester,
  ) async {
    final ready = Completer<void>();
    var taps = 0;
    await tester.pumpWidget(
      _app(
        () => ready.future,
        builder: (_) => Scaffold(
          key: _screenKey,
          body: Center(
            child: TextButton(
              onPressed: () => taps++,
              child: const Text('Action'),
            ),
          ),
        ),
      ),
    );
    ready.complete();
    // Allow async _prepare() steps to complete and mount destination under splash
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_screenKey), findsOneWidget);
    expect(find.byKey(_splashKey), findsOneWidget);
    await tester.tap(find.text('Action'), warnIfMissed: false);
    expect(taps, 0);

    await tester.pumpAndSettle();
    expect(find.byKey(_splashKey), findsNothing);
    await tester.tap(find.text('Action'));
    expect(taps, 1);
  });

  testWidgets('offers retry if preparation fails', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(() async {
        if (attempts++ == 0) throw StateError('storage unavailable');
      }),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.byKey(_screenKey), findsOneWidget);
    expect(find.byKey(_splashKey), findsNothing);
    expect(attempts, 2);
  });

  testWidgets('ignores late readiness after disposal', (tester) async {
    final ready = Completer<void>();
    await tester.pumpWidget(_app(() => ready.future));
    await tester.pumpWidget(const SizedBox.shrink());
    ready.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
