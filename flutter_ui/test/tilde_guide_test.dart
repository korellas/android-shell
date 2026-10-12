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
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/management.dart';
import 'package:android_shell_ui/tilde_controls.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AndroidEngine engine;
  late List<MethodCall> calls;
  const host = {
    'id': 7,
    'nickname': 'Test host',
    'hostname': 'server.test',
    'protocol': 'ssh',
    'username': 'alice',
    'port': 22,
    'pubkeyId': -1,
    'useAuthAgent': 'no',
  };
  const forward = {
    'id': 3,
    'hostId': 7,
    'nickname': 'Database',
    'type': 'local',
    'sourceAddr': 'localhost',
    'sourcePort': 5432,
    'destAddr': 'localhost',
    'destPort': 5432,
    'enabled': true,
    'startEnabled': false,
  };
  setUp(() {
    calls = [];
    engine = AndroidEngine()
      ..state = {
        'hosts': [host],
        'sessions': [
          {'id': 101, 'hostId': 7, 'nickname': 'First', 'open': true},
          {'id': 102, 'hostId': 7, 'nickname': 'Second', 'open': true},
        ],
        'keys': [],
        'profiles': [],
        'schemes': [],
        'preferences': {'fontFamily': 'JETBRAINS_MONO'},
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'forwards') return [forward];
          if (call.method == 'automation') {
            return [
              {
                'id': 'test-step',
                'type': 'SEND_TEXT',
                'text': 'pwd\n',
                'position': 0,
              },
            ];
          }
          if (call.method == 'automation.trial') return 103;
          if (call.method == 'scheme.palette') {
            return {
              'colors': List.filled(16, 0xff1b2229),
              'foregroundColor': 0xffe4e8eb,
              'backgroundColor': 0xff0e1216,
              'cursorColor': 0xff6fd8c4,
            };
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
    WidgetTester tester,
    Widget page, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: tildeTheme(Brightness.dark, engine),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('forward switch targets the selected session only', (
    tester,
  ) async {
    await open(
      tester,
      ForwardsPage(engine: engine, host: host, sessionId: 102),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(calls.singleWhere((c) => c.method == 'forward.toggle').arguments, {
      'hostId': 7,
      'sessionId': 102,
      'id': 3,
      'enabled': false,
    });
  });
  testWidgets('offline forward switch changes its next connection setting', (
    tester,
  ) async {
    engine.state['sessions'] = [];
    await open(tester, ForwardsPage(engine: engine, host: host));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'forward.toggle'), isEmpty);
    expect(
      calls
          .singleWhere((c) => c.method == 'forward.start')
          .arguments['enabled'],
      true,
    );
  });
  testWidgets('local hosts hide network fields and SSH-only categories', (
    tester,
  ) async {
    await open(
      tester,
      RecordEditor(
        engine: engine,
        kind: RecordKind.host,
        record: {
          ...host,
          'protocol': 'local',
          'hostname': '',
          'username': '',
          'port': 0,
        },
      ),
    );
    expect(find.text('인증'), findsNothing);
    expect(find.text('포트 포워딩'), findsNothing);
    await tester.tap(find.text('연결').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hostname:0')), findsNothing);
    expect(find.byKey(const ValueKey('port:0')), findsNothing);
  });
  testWidgets(
    'pasting SSH address splits username host and port before saving',
    (tester) async {
      await open(
        tester,
        RecordEditor(engine: engine, kind: RecordKind.host, record: host),
        width: 1000,
      );
      await tester.enterText(
        find.byKey(const ValueKey('hostname:0')),
        'bob@new.test:2202',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      final saved = calls.singleWhere((c) => c.method == 'host.save').arguments;
      expect(saved['hostname'], 'new.test');
      expect(saved['username'], 'bob');
      expect(saved['port'], 2202);
    },
  );
  testWidgets(
    'automation trial keeps the staged actions separate from saved actions',
    (tester) async {
      await open(tester, AutomationPage(engine: engine, host: host));
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('시험 실행'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'automation.save'), isEmpty);
      expect(
        calls
            .singleWhere((c) => c.method == 'automation.trial')
            .arguments['actions']
            .single['text'],
        'pwd\n',
      );
      expect(find.text('시험 세션 · 103'), findsOneWidget);
    },
  );
  testWidgets('color wheel previews and cancellation performs no save', (
    tester,
  ) async {
    await open(
      tester,
      PalettePage(engine: engine, scheme: {'id': 1, 'name': 'Custom'}),
    );
    await tester.tap(find.text('커서 · 앱 강조색'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, '112233');
    await tester.pump();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'scheme.role'), isEmpty);
    expect(find.text('#6FD8C4'), findsOneWidget);
    await tester.tap(find.text('커서 · 앱 강조색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '112233');
    await tester.pump();
    await tester.tap(find.text('사용'));
    await tester.pumpAndSettle();
    expect(calls.singleWhere((c) => c.method == 'scheme.role').arguments, {
      'id': 1,
      'role': 'cursor',
      'color': 0xff112233,
    });
  });
  testWidgets('new key choices omit DSA and use supported RSA strengths', (
    tester,
  ) async {
    await open(tester, GenerateKeyPage(engine: engine));
    expect(find.text('DSA'), findsNothing);
    await tester.tap(find.text('RSA'));
    await tester.pumpAndSettle();
    expect(find.text('2048'), findsOneWidget);
    expect(find.text('3072'), findsOneWidget);
    expect(find.text('4096'), findsOneWidget);
  });
  testWidgets('key generation shows progress without overflow', (tester) async {
    final pending = Completer<dynamic>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'key.generate') return pending.future;
          if (call.method == 'snapshot') return engine.state;
          return null;
        });
    await open(tester, GenerateKeyPage(engine: engine));
    await tester.enterText(find.byType(TextFormField).first, 'Test key');
    await tester.tap(find.text('만들기'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(TildeProgress), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.complete({'id': 2});
    await tester.pumpAndSettle();
  });
  testWidgets('background key enrollment cannot clear another hosts password', (
    tester,
  ) async {
    engine.state['hosts'] = [
      host,
      {'id': 8, 'nickname': 'Other', 'hasPassword': true},
    ];
    engine.state['enrollment'] = {
      'hostId': 7,
      'stage': 'SUCCESS',
      'busy': false,
    };
    await open(
      tester,
      EnrollmentPage(
        engine: engine,
        host: {'id': 8, 'nickname': 'Other', 'hasPassword': true},
        sessionId: 102,
      ),
    );
    expect(find.text('이 호스트의 등록 준비'), findsOneWidget);
    expect(find.text('이 호스트의 저장된 비밀번호 지우기'), findsNothing);
    expect(calls.where((c) => c.method == 'host.save'), isEmpty);
  });
  for (final width in [320.0, 1024.0]) {
    testWidgets('editors and sheets handle large type at $width', (
      tester,
    ) async {
      for (final kind in [
        RecordKind.host,
        RecordKind.profile,
        RecordKind.identity,
        RecordKind.forward,
        RecordKind.key,
      ]) {
        await open(
          tester,
          RecordEditor(
            key: ValueKey(kind),
            engine: engine,
            kind: kind,
            hostId: 7,
          ),
          width: width,
          scale: 2,
        );
        final fields = find.byType(TextFormField);
        if (fields.evaluate().isNotEmpty) {
          await tester.enterText(fields.first, 'Name');
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: kind.name);
      }
      await open(
        tester,
        const Scaffold(
          body: TildeColorSheet(initial: Color(0xff6fd8c4), title: '색상 선택'),
        ),
        width: width,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
