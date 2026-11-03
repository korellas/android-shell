// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/files/file_browser.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

class FileEntryEngine extends UiEngineFixture {
  int? fileHostId;
  @override
  Future<AppSshSession> createFileConnection(
    int hostId, {
    required VoidCallback onChanged,
  }) async {
    fileHostId = hostId;
    throw const EngineException('File connection test');
  }
}

void main() {
  late FileEntryEngine engine;
  final calls = <String>[];
  setUp(() {
    calls.clear();
    engine = FileEntryEngine()
      ..state = {
        'ready': true,
        'hosts': [
          {
            'id': 1,
            'nickname': 'Test host',
            'protocol': 'ssh',
            'hostname': 'example.test',
            'username': 'alice',
            'port': 22,
          },
        ],
        'sessions': [],
        'preferences': <String, dynamic>{},
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'snapshot') return engine.state;
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });

  testWidgets('touch host tap connects immediately without a mode picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ShellHome(engine: engine)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test host').first);
    await tester.pumpAndSettle();
    expect(find.text('SSH 터미널'), findsNothing);
    expect(find.text('파일 전송 (SFTP)'), findsNothing);
    expect(calls.where((method) => method == 'connect'), hasLength(1));
    expect(calls, isNot(contains('ssh.prepare')));
  });

  testWidgets('file menu opens the selected host without starting a terminal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ShellHome(engine: engine)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Test host 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('파일 전송 (SFTP)'));
    await tester.pumpAndSettle();
    expect(find.byType(FileBrowserPage), findsOneWidget);
    expect(engine.fileHostId, 1);
    expect(calls, isNot(contains('connect')));
    expect(engine.list('sessions'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local shell still connects directly', (tester) async {
    engine.state['hosts'] = [
      {...engine.list('hosts').single, 'protocol': 'local'},
    ];
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ShellHome(engine: engine)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test host').first);
    await tester.pumpAndSettle();
    expect(calls.where((method) => method == 'connect'), hasLength(1));
    expect(find.text('파일 전송 (SFTP)'), findsNothing);
    expect(engine.fileHostId, isNull);
  });
}
