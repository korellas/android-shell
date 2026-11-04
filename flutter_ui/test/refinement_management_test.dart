// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/management.dart';
import 'package:android_shell_ui/tilde_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';
import 'package:android_shell_ui/l10n/strings.dart';

void main() {
  late UiEngineFixture engine;
  setUp(() {
    engine = UiEngineFixture()
      ..state = {
        'preferences': <String, dynamic>{},
        'hosts': [],
        'identities': [
          {'id': 1, 'name': '배포 계정', 'username': 'deployer'},
        ],
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidEngine.channel,
          (call) async => call.method == 'logs'
              ? '12:00 WARN 연결 지연\n12:01 ERROR 인증 실패\n12:02 INFO 다시 연결\n12:03 I Tag: ERROR word in informational message\n12:04 E Tag: rejected'
              : null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null),
  );
  testWidgets('account list uses app bar add and only explains an empty list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: RecordListPage(engine: engine, kind: RecordKind.identity),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('계정 추가'), findsOneWidget);
    expect(find.text('배포 계정'), findsOneWidget);
    expect(find.textContaining('여러 호스트에서'), findsNothing);
    expect(find.textContaining('쓰는 호스트 없음'), findsOneWidget);
    engine.state['identities'] = [];
    engine.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.textContaining('여러 호스트에서'), findsOneWidget);
  });
  testWidgets(
    'diagnostic actions are in overflow and severity filters retain actual counts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: LogsPage(engine: engine),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('새로고침'), findsNothing);
      expect(find.text('네이티브 크래시 기록 저장'), findsNothing);
      await tester.tap(find.text('오류 2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('인증 실패'), findsOneWidget);
      expect(find.textContaining('연결 지연'), findsNothing);
      expect(find.textContaining('informational message'), findsNothing);
      await tester.tap(find.byType(TildeItemMenu<String>));
      await tester.pumpAndSettle();
      expect(find.text('새로고침'), findsOneWidget);
    },
  );
}
