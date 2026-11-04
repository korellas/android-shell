/* Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0 */
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/founders_edition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AndroidEngine engine;
  late List<String> calls;
  setUp(() {
    calls = [];
    engine = AndroidEngine()
      ..state = {
        'ready': true,
        'founders': {
          'owned': false,
          'checking': false,
          'ready': true,
          'pending': false,
          'price': '₩2,900',
        },
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });
  tearDown(() {
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FoundersEditionPage(engine: engine)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses the Play price and opens an in-app purchase', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Founders Edition'), findsWidgets);
    expect(find.text('₩2,900에 구매'), findsOneWidget);
    await tester.tap(find.text('₩2,900에 구매'));
    await tester.pumpAndSettle();
    expect(calls, contains('founders.purchase'));
  });

  testWidgets('owned edition shows status and allows restoring purchases', (
    tester,
  ) async {
    (engine.state['founders'] as Map)['owned'] = true;
    await open(tester);
    expect(find.text('Founders Edition 사용 중'), findsOneWidget);
    expect(find.text('₩2,900에 구매'), findsNothing);
    await tester.tap(find.text('구매 복원'));
    await tester.pumpAndSettle();
    expect(calls, contains('founders.restore'));
  });

  testWidgets('unavailable product cannot start a purchase', (tester) async {
    (engine.state['founders'] as Map)['ready'] = false;
    await open(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text('구매 준비 중'), findsOneWidget);
    expect(calls, isNot(contains('founders.purchase')));
  });

  testWidgets('pending payment does not offer a duplicate purchase', (
    tester,
  ) async {
    (engine.state['founders'] as Map)['pending'] = true;
    await open(tester);
    expect(find.text('결제 확인 중'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
