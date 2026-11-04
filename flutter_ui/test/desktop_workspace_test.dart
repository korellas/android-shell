// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'file_browser_actions_test.dart' show BrowserFiles, BrowserEngine;

class WorkspaceEngine extends BrowserEngine {
  WorkspaceEngine(super.files);
  int connections = 0;
  @override
  Future<dynamic> invoke(String method, [EngineRecord args = const {}]) async {
    if (method == 'connect') {
      connections++;
      return true;
    }
    return super.invoke(method, args);
  }
}

void main() {
  late WorkspaceEngine engine;
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    final files = BrowserFiles()
      ..nodes['/home'] = SftpFileAttrs(mode: SftpFileMode.value(0x41ed));
    engine = WorkspaceEngine(files)
      ..state = {
        'ready': true,
        'preferences': <String, dynamic>{},
        'hosts': [
          {
            'id': 7,
            'nickname': '개발 서버',
            'protocol': 'ssh',
            'hostname': 'dev.example',
            'username': 'admin',
            'port': 22,
          },
        ],
        'sessions': [
          {'id': 101, 'hostId': 7, 'nickname': '개발 서버', 'open': true},
          {'id': 102, 'hostId': 7, 'nickname': '개발 서버', 'open': true},
        ],
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'forwards') return [];
          if (call.method == 'session.consumeSelection') {
            engine.state['selectedSession'] = null;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null),
  );
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ShellHome(engine: engine)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desktop home shows the selected host details on first open',
    (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('workspace-sidebar')), findsOneWidget);
      expect(find.text('새 터미널'), findsOneWidget);
      expect(find.text('열린 세션'), findsOneWidget);
      expect(find.text('개발 서버 · 1'), findsOneWidget);
      expect(find.text('개발 서버 · 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-tab-home')), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'one terminal view is reused while switching session tabs',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('workspace-tab-session-101')));
      await tester.pumpAndSettle();
      expect(find.byType(TerminalPane), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspace-tab-session-102')));
      await tester.pumpAndSettle();
      expect(find.byType(TerminalPane), findsOneWidget);
      expect(calls.where((call) => call.method == 'connect'), isEmpty);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'sidebar can collapse with Ctrl B without closing sessions',
    (tester) async {
      await open(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-sidebar')), findsNothing);
      expect(engine.list('sessions'), hasLength(2));
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'touch host selection waits for explicit terminal or file choice',
    (tester) async {
      engine.state['sessions'] = [];
      await open(tester);
      await tester.tap(find.text('개발 서버').first);
      await tester.pumpAndSettle();
      expect(find.text('SSH 터미널'), findsNothing);
      expect(engine.connections, 0);
      expect(find.text('파일 전송'), findsOneWidget);
      await tester.tap(find.text('새 터미널'));
      await tester.pumpAndSettle();
      expect(engine.connections, 1);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
  testWidgets(
    'new desktop tab opens host actions without connecting',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('workspace-tab-session-101')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('새 탭 (Ctrl Shift T)'));
      await tester.pumpAndSettle();
      expect(engine.connections, 0);
      expect(find.text('새 터미널'), findsOneWidget);
      expect(find.text('파일 전송'), findsOneWidget);
      expect(engine.list('sessions'), hasLength(2));
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'phone host chooser can select an existing session without connecting',
    (tester) async {
      await open(tester);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.text('개발 서버').last);
      await tester.pumpAndSettle();
      expect(engine.connections, 0);
      expect(find.text('파일 전송'), findsOneWidget);
      await tester.tap(find.text('탭으로 이동').last);
      await tester.pumpAndSettle();
      expect(engine.connections, 0);
      expect(
        tester.widget<TerminalPane>(find.byType(TerminalPane)).terminal,
        same(engine.terminalSession(102)!.terminal),
      );
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}
