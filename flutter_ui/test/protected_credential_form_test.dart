// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

void main() {
  testWidgets('creation has key and server-bound password options', (
    tester,
  ) async {
    final engine = UiEngineFixture()
      ..state = {
        'generation': {'passkeyAvailable': true, 'passkeyOnly': true},
      };
    EngineRecord? created;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'key.generate') created = row(call.arguments);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidEngine.channel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(body: GenerateKeyPage(engine: engine)),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SSH 비밀번호 보관').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(fields.at(0), 'work');
    await tester.enterText(fields.at(1), 'server.example');
    await tester.enterText(fields.at(3), 'alice');
    await tester.enterText(fields.at(4), 'test-secret');
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: fields.at(4), matching: find.byType(TextField)),
          )
          .obscureText,
      isTrue,
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, '패스키 만들기'));
    await tester.tap(find.widgetWithText(FilledButton, '패스키 만들기'));
    await tester.pumpAndSettle();
    expect(created, containsPair('kind', 'password'));
    expect(created, containsPair('hostname', 'server.example'));
    expect(created, containsPair('username', 'alice'));
    expect(created, containsPair('password', 'test-secret'));
    expect(
      tester.widget<TextFormField>(fields.at(4)).controller!.text,
      isEmpty,
    );
  });
}
