/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AndroidEngine engine;
  Map<dynamic, dynamic>? saved;
  setUp(() {
    engine = AndroidEngine()
      ..state = {
        'identities': [
          {
            'id': 3,
            'name': 'Shared',
            'username': 'shared-user',
            'pubkeyId': -2,
          },
        ],
        'keys': [],
      };
    saved = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'snapshot') return engine.state;
          if (call.method.endsWith('.save')) {
            saved = Map.of(call.arguments as Map);
          }
          return null;
        });
  });
  tearDown(() {
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(
    WidgetTester tester, {
    int? identityId,
    bool hasPassword = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: RecordEditor(
          engine: engine,
          kind: RecordKind.host,
          record: {
            'id': 7,
            'nickname': 'test',
            'protocol': 'ssh',
            'hostname': 'example.test',
            'username': 'alice',
            'pubkeyId': -1,
            'useAuthAgent': 'no',
            'identityId': identityId,
            'hasPassword': hasPassword,
          },
        ),
      ),
    );
    await tester.tap(find.text('인증').first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'host authentication uses the original controls and key choices',
    (tester) async {
      await open(tester);
      expect(find.text('공용 로그인 계정'), findsOneWidget);
      expect(find.text('SSH 키 인증 사용'), findsNothing);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(find.text('SSH 인증 에이전트 사용'), findsNothing);
      await tester.tap(find.text('고급 인증 설정'));
      await tester.pumpAndSettle();
      expect(find.text('SSH 인증 에이전트 사용'), findsOneWidget);
      expect(find.text('확인 필요'), findsNothing);
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('확인 필요'), findsOneWidget);
      await tester.tap(find.text('잠금이 풀린 키들을 사용').first);
      await tester.pumpAndSettle();
      expect(find.text('키 사용 안함'), findsOneWidget);
      await tester.tap(find.text('키 사용 안함'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('저장'));
      await tester.pumpAndSettle();
      expect(saved?['pubkeyId'], -2);
    },
  );
  testWidgets('shared account selection disables per-host credentials', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('이 호스트만의 인증정보').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shared').last);
    await tester.pumpAndSettle();
    final username = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(username.enabled, false);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'shared-user',
    );
    expect(find.text('비밀번호'), findsNothing);
    expect(find.text('로그인에 사용할 SSH 키'), findsNothing);
  });
  testWidgets(
    'existing password stays blank and clear is applied only on save',
    (tester) async {
      await open(tester, hasPassword: true);
      expect(find.text('비밀번호 (변경 없음)'), findsOneWidget);
      final field = tester.widget<TextFormField>(
        find.byType(TextFormField).last,
      );
      expect(field.initialValue, '');
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        true,
      );
      await tester.tap(find.text('저장된 비밀번호 삭제'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await tester.tap(find.byTooltip('저장'));
      await tester.pumpAndSettle();
      expect(saved?['clearPassword'], true);
    },
  );
  testWidgets('shared account editor retains password without reading it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordEditor(
          engine: engine,
          kind: RecordKind.identity,
          record: {
            'id': 3,
            'name': 'Shared',
            'username': 'alice',
            'pubkeyId': -1,
            'hasPassword': true,
          },
        ),
      ),
    );
    expect(find.text('비밀번호 (변경 없음)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('이 기기에 암호화'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('이 기기에 암호화'), findsOneWidget);
  });
}
