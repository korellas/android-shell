// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

void main() {
  late UiEngineFixture engine;
  late List<MethodCall> calls;
  setUp(() {
    engine = UiEngineFixture();
    calls = [];
    engine.state = {
      'ready': true,
      'preferences': {'titlebarhide': true},
      'autoHideDelayMs': 100,
      'hosts': [
        {'id': 7, 'nickname': '개발 서버', 'protocol': 'ssh'},
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
          if (call.method == 'session.consumeSelection') {
            engine.state['selectedSession'] = null;
          }
          if (call.method == 'session.disconnect') {
            engine.state['sessions'] = engine
                .list('sessions')
                .where((s) => s['id'] != (call.arguments as Map)['id'])
                .toList();
          }
          return null;
        });
  });
  tearDown(() {
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(WidgetTester tester, {double width = 840}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    engine.state['selectedSession'] = 101;
    await tester.pumpWidget(AndroidShellApp(engine: engine));
    await tester.pumpAndSettle();
  }

  testWidgets('folding preserves the selected session and exposes a picker', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('session-tab-102')));
    await tester.pumpAndSettle();
    final terminal = engine.terminalSession(102)!;
    final console = tester.state<ConsolePageState>(find.byType(ConsolePage));
    tester.view.physicalSize = const Size(390, 900);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('세션 2'), findsOneWidget);
    expect(tester.state(find.byType(ConsolePage)), same(console));
    expect(
      tester.widget<TerminalPane>(find.byType(TerminalPane)).terminal,
      same(terminal.terminal),
    );
    await tester.tap(find.text('세션 2'));
    await tester.pumpAndSettle();
    expect(find.text('개발 서버 · 1'), findsOneWidget);
    expect(find.text('개발 서버 · 2'), findsOneWidget);
    await tester.tap(find.text('개발 서버 · 1'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(840, 900);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('session-tab-101')))
          .properties
          .selected,
      isTrue,
    );
    expect(
      calls.where(
        (c) => c.method == 'session.disconnect' || c.method == 'connect',
      ),
      isEmpty,
    );
  });
  testWidgets('home and system back retain sessions and expose direct resume', (
    tester,
  ) async {
    await open(tester, width: 390);
    await tester.tap(find.byTooltip('홈'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsolePage), findsNothing);
    expect(find.text('열린 세션'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-session-102')));
    await tester.pumpAndSettle();
    expect(tester.state<ConsolePageState>(find.byType(ConsolePage)).id, 102);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ConsolePage), findsNothing);
    expect(engine.list('sessions'), hasLength(2));
    expect(
      calls.where(
        (c) => c.method == 'session.disconnect' || c.method == 'connect',
      ),
      isEmpty,
    );
  });
  testWidgets(
    'new selections reuse the console and closing a background session preserves selection',
    (tester) async {
      await open(tester, width: 390);
      engine.state['selectedSession'] = 102;
      await engine.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(ConsolePage, skipOffstage: false), findsOneWidget);
      expect(tester.state<ConsolePageState>(find.byType(ConsolePage)).id, 102);
      await tester.tap(find.text('세션 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('session-close-101')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '종료'));
      await tester.pumpAndSettle();
      expect(engine.list('sessions').single['id'], 102);
      expect(tester.state<ConsolePageState>(find.byType(ConsolePage)).id, 102);
      await tester.tap(find.text('세션 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('session-close-102')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '종료'));
      await tester.pumpAndSettle();
      expect(find.byType(ConsolePage), findsNothing);
      expect(engine.list('sessions'), isEmpty);
    },
  );
  testWidgets('tabs use available width and touch sized close controls', (
    tester,
  ) async {
    await open(tester, width: 600);
    expect(find.byKey(const ValueKey('session-tab-101')), findsOneWidget);
    final close = tester.getSize(
      find.byKey(const ValueKey('session-close-101')),
    );
    expect(close.width, greaterThanOrEqualTo(48));
    expect(close.height, greaterThanOrEqualTo(48));
    tester.view.physicalSize = const Size(599, 900);
    await tester.pumpAndSettle();
    expect(find.text('세션 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('session-tab-101')), findsNothing);
  });
  testWidgets('closing selected compact session selects remaining session', (
    tester,
  ) async {
    await open(tester, width: 390);
    await tester.tap(find.text('세션 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('session-close-101')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(tester.state<ConsolePageState>(find.byType(ConsolePage)).id, 101);
    expect(engine.list('sessions'), hasLength(2));
    await tester.tap(find.text('세션 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('session-close-101')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '종료'));
    await tester.pumpAndSettle();
    expect(tester.state<ConsolePageState>(find.byType(ConsolePage)).id, 102);
    expect(engine.list('sessions').single['id'], 102);
  });
  testWidgets('picker refreshes when a background session disappears', (
    tester,
  ) async {
    await open(tester, width: 390);
    await tester.tap(find.text('세션 2'));
    await tester.pumpAndSettle();
    engine.state['sessions'] = engine
        .list('sessions')
        .where((s) => s['id'] != 102)
        .toList();
    await engine.refresh();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-session-102')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-session-101')));
    await tester.pumpAndSettle();
    expect(tester.state<ConsolePageState>(find.byType(ConsolePage)).id, 101);
  });
}
