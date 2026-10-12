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

import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/management.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AndroidEngine engine;
  MethodCall? copied;
  setUp(() {
    engine = AndroidEngine()
      ..state = {
        'keys': [
          {
            'id': 2,
            'nickname': 'Test key',
            'type': 'RSA',
            'biometric': false,
            'encrypted': false,
          },
        ],
      };
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'key.copy') copied = call;
          return null;
        });
  });
  tearDown(() {
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  testWidgets('key creation and editing have no use confirmation option', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: GenerateKeyPage(engine: engine)));
    await tester.pumpAndSettle();
    expect(find.text('사용할 때마다 확인'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: RecordEditor(
          engine: engine,
          kind: RecordKind.key,
          record: {...engine.list('keys').single, 'confirmation': true},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('사용할 때마다 확인'), findsNothing);
  });

  testWidgets('private key formats remain reachable through grouped actions', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: KeyPage(engine: engine)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Test key 옵션'));
    await tester.pumpAndSettle();
    expect(find.text('OpenSSH 비밀키 복사'), findsNothing);
    await tester.tap(find.text('비밀키 복사·저장'));
    await tester.pumpAndSettle();
    expect(find.text('OpenSSH 비밀키'), findsOneWidget);
    await tester.tap(find.text('복사'));
    await tester.pumpAndSettle();
    expect(copied?.arguments, {
      'id': 2,
      'format': 'openssh',
      'password': null,
      'exportPassword': null,
    });
  });
  testWidgets('biometric keys keep only public key export actions', (
    tester,
  ) async {
    engine.state['keys'] = [
      {'id': 2, 'nickname': 'Test key', 'type': 'EC', 'biometric': true},
    ];
    await tester.pumpWidget(MaterialApp(home: KeyPage(engine: engine)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Test key 옵션'));
    await tester.pumpAndSettle();
    expect(find.text('비밀키 복사·저장'), findsNothing);
    expect(find.text('공개키 복사'), findsOneWidget);
  });
}
