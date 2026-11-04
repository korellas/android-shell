// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';
import 'package:android_shell_ui/l10n/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UiEngineFixture engine;
  late List<MethodCall> calls;
  setUp(() {
    engine = UiEngineFixture();
    calls = [];
    engine.state = {
      'ready': true,
      'preferences': {'titlebarhide': false},
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
                .where(
                  (session) => session['id'] != (call.arguments as Map)['id'],
                )
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
  Future<void> open(WidgetTester tester, {int selected = 101}) async {
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: ConsolePage(engine: engine, sessionId: selected),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desktop sessions have distinct names, connection status and close controls',
    (tester) async {
      await open(tester);
      expect(find.text('개발 서버 · 1'), findsOneWidget);
      expect(find.text('개발 서버 · 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('session-close-101')), findsOneWidget);
      expect(find.byKey(const ValueKey('session-close-102')), findsOneWidget);
      expect(find.byTooltip('새 탭'), findsOneWidget);
      expect(find.byTooltip('기기 목록'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Tab'), findsNothing);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'Ctrl Tab switches forward and backward without sending Tab to SSH',
    (tester) async {
      engine.state['sessions'] = [
        ...engine.list('sessions'),
        {'id': 103, 'hostId': 7, 'nickname': '개발 서버', 'open': true},
      ];
      await open(tester);
      final output = <String>[];
      for (final session in engine.list('sessions')) {
        engine.terminalSession(session['id'] as int)!.terminal.onOutput =
            output.add;
      }
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  한',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 2, end: 3),
        ),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('session-tab-102')))
            .properties
            .selected,
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('session-tab-101')))
            .properties
            .selected,
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('session-tab-103')))
            .properties
            .selected,
        isTrue,
      );
      expect(output.join(), '한');
      expect(
        engine.list('sessions').every((session) => session['open'] == true),
        isTrue,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'opening another desktop session keeps a single live terminal view',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      engine.state['selectedSession'] = 101;
      await tester.pumpWidget(AndroidShellApp(engine: engine));
      await tester.pumpAndSettle();
      expect(find.byType(ConsolePage, skipOffstage: false), findsOneWidget);
      engine.state['selectedSession'] = 102;
      await engine.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(ConsolePage, skipOffstage: false), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspace-tab-session-101')));
      await tester.pumpAndSettle();
      await engine.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(TerminalPane, skipOffstage: false), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  한',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 2, end: 3),
        ),
      );
      expect(engine.terminalSession(101)!.input.composingText, '한');
      expect(
        calls.where((call) => call.method == 'session.disconnect'),
        isEmpty,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'a new session selected while a dialog is open becomes active after closing it',
    (tester) async {
      engine.state['selectedSession'] = 101;
      await tester.pumpWidget(AndroidShellApp(engine: engine));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ConsolePage));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: const Text('테스트 창'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      engine.state['selectedSession'] = 102;
      await engine.refresh();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(ConsolePage, skipOffstage: false), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('workspace-tab-session-102')),
            )
            .properties
            .selected,
        isTrue,
      );
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'cancelling a tab close preserves both connections',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('session-close-102')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '취소'));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'session.disconnect'),
        isEmpty,
      );
      expect(engine.list('sessions'), hasLength(2));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'a selected tab is visible when the strip overflows',
    (tester) async {
      engine.state['sessions'] = [
        for (var id = 101; id <= 124; id++)
          {'id': id, 'hostId': 7, 'nickname': '개발 서버', 'open': true},
      ];
      await open(tester, selected: 124);
      final selected = tester.getRect(
        find.byKey(const ValueKey('session-tab-124')),
      );
      expect(selected.left, greaterThanOrEqualTo(0));
      expect(selected.right, lessThanOrEqualTo(1100));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'closing a background tab disconnects only that session',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('session-close-102')));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'session.disconnect'),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(FilledButton, '종료'));
      await tester.pumpAndSettle();
      expect(
        calls
            .singleWhere((call) => call.method == 'session.disconnect')
            .arguments,
        {'id': 102},
      );
      expect(engine.list('sessions').single['id'], 101);
      expect(find.byKey(const ValueKey('session-close-101')), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'closing the selected tab selects the remaining connection',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('session-close-101')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '종료'));
      await tester.pumpAndSettle();
      expect(engine.list('sessions').single['id'], 102);
      expect(find.byKey(const ValueKey('session-close-102')), findsOneWidget);
      expect(
        calls
            .where((call) => call.method == 'session.visibility')
            .last
            .arguments,
        containsPair('id', 102),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
