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

import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/management.dart';
import 'package:android_shell_ui/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

void main() {
  late AndroidEngine engine;
  late List<MethodCall> calls;
  const host = {
    'id': 7,
    'nickname': 'Current SSH',
    'protocol': 'ssh',
    'hostname': 'server.test',
    'port': 22,
  };
  const legacyForward = {
    'id': 3,
    'hostId': 7,
    'nickname': 'Legacy proxy',
    'type': 'dynamic4',
    'sourceAddr': 'localhost',
    'sourcePort': 1080,
    'startEnabled': true,
  };
  setUp(() {
    calls = [];
    engine = UiEngineFixture()
      ..state = {
        'defaults': {'host': host},
        'hosts': [
          host,
          {...host, 'id': 8, 'nickname': 'Other SSH'},
          {...host, 'id': 9, 'nickname': 'Local host', 'protocol': 'local'},
          {...host, 'id': 10, 'nickname': 'Old Mosh', 'protocol': 'mosh'},
        ],
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'forwards') return [legacyForward];
          return null;
        });
  });
  tearDown(() {
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(
    WidgetTester tester,
    Widget child, {
    double width = 1100,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  testWidgets('new hosts offer SSH and local only', (tester) async {
    await open(tester, RecordEditor(engine: engine, kind: RecordKind.host));
    expect(find.text('Mosh'), findsNothing);
    expect(find.text('Telnet'), findsNothing);
    expect(find.text('SSH'), findsOneWidget);
    expect(find.text('로컬'), findsOneWidget);
  });
  testWidgets('jump choices exclude self and non SSH records', (tester) async {
    await open(
      tester,
      RecordEditor(engine: engine, kind: RecordKind.host, record: host),
    );
    await tester.tap(find.text('점프 호스트'));
    await tester.pumpAndSettle();
    expect(find.text('Other SSH'), findsOneWidget);
    expect(find.text('Current SSH'), findsNothing);
    expect(find.text('Local host'), findsNothing);
    expect(find.text('Old Mosh'), findsNothing);
  });
  testWidgets('SOCKS4 cannot enable auto start in editor', (tester) async {
    await open(
      tester,
      RecordEditor(
        engine: engine,
        kind: RecordKind.forward,
        hostId: 7,
        record: legacyForward,
      ),
    );
    expect(find.widgetWithText(SwitchListTile, '접속할 때 자동 활성화'), findsNothing);
    expect(find.textContaining('SOCKS4는 실행할 수 없습니다'), findsOneWidget);
  });
  testWidgets('SOCKS4 cannot start from forwarding list', (tester) async {
    await open(tester, ForwardsPage(engine: engine, host: host));
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.textContaining('SOCKS4 미지원'), findsOneWidget);
  });
  testWidgets('local automation offers no forwarding actions', (tester) async {
    await open(
      tester,
      AutomationStepPage(engine: engine, host: {...host, 'protocol': 'local'}),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('포워딩 활성화'), findsNothing);
    expect(find.text('포워딩 비활성화'), findsNothing);
  });
  testWidgets('existing local forwarding step remains visible as unsupported', (
    tester,
  ) async {
    await open(
      tester,
      AutomationStepPage(
        engine: engine,
        host: {...host, 'protocol': 'local'},
        action: const {'type': 'ENABLE_FORWARD', 'forwardId': 3},
      ),
    );
    expect(find.textContaining('포워딩 활성화 · 미지원'), findsOneWidget);
    expect(find.textContaining('로컬 연결은 포워딩 동작을 지원하지 않습니다'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
  });
  testWidgets('unsupported host stays editable without a connect action', (
    tester,
  ) async {
    await open(
      tester,
      RecordEditor(
        engine: engine,
        kind: RecordKind.host,
        record: {...host, 'protocol': 'mosh'},
      ),
    );
    expect(find.textContaining('mosh 연결은 지원하지 않습니다'), findsOneWidget);
    expect(find.text('새 세션'), findsNothing);
    expect(find.text('복제'), findsNothing);
    expect(find.text('홈 화면'), findsNothing);
    expect(find.text('SSH'), findsOneWidget);
  });
  testWidgets('unsupported home row stays visible and opens editor on phone', (
    tester,
  ) async {
    engine.state['ready'] = true;
    engine.state['hosts'] = [
      {...host, 'protocol': 'mosh'},
    ];
    await open(tester, ShellHome(engine: engine), width: 390);
    expect(find.textContaining('mosh 미지원'), findsOneWidget);
    await tester.tap(find.text('Current SSH'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditor), findsOneWidget);
    expect(
      calls.where(
        (call) => call.method == 'connect' || call.method == 'shortcut',
      ),
      isEmpty,
    );
  });
  testWidgets(
    'unsupported home menu offers edit without executable shortcuts',
    (tester) async {
      engine.state['ready'] = true;
      engine.state['hosts'] = [
        {...host, 'protocol': 'telnet'},
      ];
      await open(tester, ShellHome(engine: engine));
      await tester.tap(find.byTooltip('Current SSH 메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('편집'), findsOneWidget);
      expect(find.text('새 세션'), findsNothing);
      expect(find.text('복제'), findsNothing);
      expect(find.text('홈 화면에 추가'), findsNothing);
    },
  );
  for (final type in ['WAIT_FOR_TEXT', 'DELAY']) {
    testWidgets('$type requires a positive duration', (tester) async {
      await open(
        tester,
        AutomationStepPage(
          engine: engine,
          host: host,
          action: {'type': type, 'durationMs': 0},
        ),
      );
      expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
      await tester.pump();
      expect(find.text('0보다 큰 정수를 입력하세요.'), findsOneWidget);
    });
  }
  testWidgets(
    'imported software keys permit password change and confirmation opt in',
    (tester) async {
      await open(
        tester,
        RecordEditor(
          engine: engine,
          kind: RecordKind.key,
          record: const {
            'id': 2,
            'nickname': 'Imported key',
            'type': 'IMPORTED',
            'encrypted': true,
            'loaded': true,
          },
        ),
      );
      expect(find.text('사용할 때 확인'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, '사용할 때 확인'),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.text('키 암호 변경'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '기존 암호'), findsNothing);
      expect(find.widgetWithText(TextFormField, '새 암호'), findsOneWidget);
    },
  );
}
