// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

void main() {
  late UiEngineFixture engine;
  late List<MethodCall> calls;
  Completer<void>? disconnect;
  bool failDisconnect = false;
  setUp(() {
    engine = UiEngineFixture();
    calls = [];
    disconnect = null;
    failDisconnect = false;
    engine.state = {
      'ready': true,
      'hosts': [
        {'id': 7, 'nickname': 'server', 'protocol': 'ssh'},
      ],
      'sessions': [
        {'id': 101, 'hostId': 7, 'nickname': 'server', 'open': true},
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
            engine.state['sessions'] = <EngineRecord>[];
          }
          if (call.method == 'session.disconnectAll') {
            await disconnect?.future;
            if (failDisconnect) {
              throw PlatformException(code: 'disconnect_failed');
            }
            engine.state['sessions'] = <EngineRecord>[];
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AndroidShellApp(engine: engine));
    await tester.pumpAndSettle();
  }

  Iterable<MethodCall> exits() => calls.where(
    (c) => c.method == 'app.exit' || c.method == 'app.background',
  );
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('last session X stays on home', (tester) async {
    engine.state['selectedSession'] = 101;
    await open(tester);
    await tester.tap(find.byTooltip('홈'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('session-close-101')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '종료'));
    await tester.pumpAndSettle();
    expect(engine.list('sessions'), isEmpty);
    expect(find.byType(ShellHome), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(ConsolePage), findsNothing);
    expect(exits(), isEmpty);
  });
  testWidgets('back retains sessions and backgrounds app', (tester) async {
    await open(tester);
    await back(tester);
    expect(find.text('앱을 종료할까요?'), findsOneWidget);
    expect(exits(), isEmpty);
    await tester.tap(find.text('세션 유지'));
    await tester.pumpAndSettle();
    expect(engine.list('sessions'), hasLength(1));
    expect(calls.where((c) => c.method == 'session.disconnectAll'), isEmpty);
    expect(exits().single.method, 'app.background');
  });
  testWidgets('back waits for all disconnects and ignores repeated back', (
    tester,
  ) async {
    disconnect = Completer<void>();
    engine.state['sessions'] = [
      ...engine.list('sessions'),
      {'id': 102, 'hostId': 7, 'nickname': 'server', 'connecting': true},
    ];
    await open(tester);
    await back(tester);
    await tester.tap(find.text('세션 종료 후 나가기'));
    await tester.pumpAndSettle();
    expect(exits(), isEmpty);
    await back(tester);
    expect(find.text('앱을 종료할까요?'), findsNothing);
    expect(
      calls.where((c) => c.method == 'session.disconnectAll'),
      hasLength(1),
    );
    disconnect!.complete();
    await tester.pumpAndSettle();
    expect(engine.list('sessions'), isEmpty);
    expect(exits().single.method, 'app.exit');
  });
  testWidgets('dismiss and cancel keep sessions and app open', (tester) async {
    await open(tester);
    await back(tester);
    await back(tester);
    expect(find.text('앱을 종료할까요?'), findsNothing);
    expect(engine.list('sessions'), hasLength(1));
    expect(exits(), isEmpty);
    await back(tester);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(exits(), isEmpty);
  });
  testWidgets('disconnect failure leaves app open', (tester) async {
    failDisconnect = true;
    await open(tester);
    await back(tester);
    await tester.tap(find.text('세션 종료 후 나가기'));
    await tester.pumpAndSettle();
    expect(exits(), isEmpty);
    expect(engine.list('sessions'), hasLength(1));
    expect(find.text('연결을 닫지 못했습니다'), findsOneWidget);
  });
  testWidgets('connecting sessions also ask before leaving', (tester) async {
    engine.state['sessions'] = [
      {'id': 101, 'hostId': 7, 'nickname': 'server', 'connecting': true},
    ];
    await open(tester);
    await back(tester);
    expect(find.text('앱을 종료할까요?'), findsOneWidget);
    expect(exits(), isEmpty);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
  });
  testWidgets('ended sessions are removed without an exit question', (
    tester,
  ) async {
    engine.state['sessions'] = [
      {'id': 101, 'hostId': 7, 'nickname': 'server', 'ended': true},
    ];
    await open(tester);
    await back(tester);
    expect(find.text('앱을 종료할까요?'), findsNothing);
    expect(engine.list('sessions'), isEmpty);
    expect(exits().single.method, 'app.exit');
  });
  testWidgets(
    'iOS back does not invoke Android app actions',
    (tester) async {
      await open(tester);
      await back(tester);
      expect(find.text('앱을 종료할까요?'), findsNothing);
      expect(exits(), isEmpty);
      expect(engine.list('sessions'), hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets('back with no sessions exits without asking', (tester) async {
    engine.state['sessions'] = <EngineRecord>[];
    await open(tester);
    await back(tester);
    expect(find.text('앱을 종료할까요?'), findsNothing);
    expect(exits().single.method, 'app.exit');
  });
}
