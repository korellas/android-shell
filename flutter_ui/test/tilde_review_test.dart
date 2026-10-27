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

import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/management.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:android_shell_ui/terminal/terminal_pane.dart';

import 'ui_engine_fixture.dart';

void main() {
  late AndroidEngine engine;
  late List<MethodCall> calls;
  const session = {
    'id': 101,
    'hostId': 7,
    'nickname': 'home-nas',
    'open': true,
    'foregroundColor': 0xffe4e8eb,
    'backgroundColor': 0xff0e1216,
    'cursorColor': 0xff6fd8c4,
  };
  const host = {
    'id': 7,
    'nickname': 'home-nas',
    'protocol': 'ssh',
    'username': 'admin',
    'hostname': 'nas.test',
    'port': 22,
  };
  setUp(() {
    calls = [];
    engine = UiEngineFixture()
      ..state = {
        'ready': true,
        'sessions': [session],
        'hosts': [host],
        'prompts': [],
        'preferences': {'themeMode': 'LIGHT', 'fullscreen': false},
      };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') return 0;
      if (call.method == 'resize') return call.arguments;
      return null;
    });
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(AndroidEngine.channel, (call) async {
      calls.add(call);
      if (call.method == 'snapshot') return engine.state;
      if (call.method == 'host.delete') {
        engine.state['hosts'] = [];
        return 'undo-token';
      }
      if (call.method == 'host.restore') engine.state['hosts'] = [host];
      return null;
    });
  });
  tearDown(() {
    engine.dispose();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidEngine.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: tildeTheme(Brightness.light, engine), home: page),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('console chrome follows session colors in a light app', (
    tester,
  ) async {
    await open(tester, ConsolePage(engine: engine, sessionId: 101));
    final context = tester.element(find.byType(TerminalPane));
    expect(Theme.of(context).colorScheme.surface, const Color(0xff0e1216));
    expect(Theme.of(context).colorScheme.onSurface, const Color(0xffe4e8eb));
    await tester.pumpWidget(const SizedBox());
    engine.dispose();
  });
  testWidgets('banner, progress and hidden title do not resize terminal', (
    tester,
  ) async {
    await open(tester, ConsolePage(engine: engine, sessionId: 101));
    final size = tester.getSize(find.byType(TerminalPane));
    engine.state['sessions'] = [
      {
        ...session,
        'banners': [
          {'id': 1, 'sourceName': 'Ubuntu', 'message': 'Welcome'},
        ],
        'automation': {'running': true},
      },
    ];
    engine.notifyListeners();
    await tester.pump();
    expect(tester.getSize(find.byType(TerminalPane)), size);
    engine.state['preferences'] = {'titlebarhide': true};
    engine.notifyListeners();
    await tester.pump();
    final overlaySize = tester.getSize(find.byType(TerminalPane));
    expect(overlaySize.height, size.height + 44);
    await tester.tap(find.byType(TerminalPane));
    await tester.pump(const Duration(seconds: 4));
    expect(tester.getSize(find.byType(TerminalPane)), overlaySize);
    await tester.pumpWidget(const SizedBox());
    engine.dispose();
  });
  testWidgets(
    'ended session keeps terminal and shows reconnect at the bottom',
    (tester) async {
      engine.state['sessions'] = [
        {...session, 'open': false, 'connecting': false, 'ended': true},
      ];
      await open(tester, ConsolePage(engine: engine, sessionId: 101));
      expect(find.byType(TerminalPane), findsOneWidget);
      expect(find.text('연결이 끊겼습니다'), findsOneWidget);
      expect(find.text('다시 연결'), findsOneWidget);
      expect(tester.getTopLeft(find.text('다시 연결')).dy, greaterThan(400));
      await tester.pumpWidget(const SizedBox());
      engine.dispose();
    },
  );
  testWidgets('host deletion has undo and restores the same saved record', (
    tester,
  ) async {
    await open(tester, ShellHome(engine: engine));
    await tester.longPress(find.text('home-nas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls.singleWhere((c) => c.method == 'host.delete').arguments, {
      'id': 7,
      'undo': true,
    });
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(calls.singleWhere((c) => c.method == 'host.restore').arguments, {
      'token': 'undo-token',
    });
    expect(find.text('home-nas'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    engine.dispose();
  });
  testWidgets('failure shows human summary and preserves raw details', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'connect') {
            throw PlatformException(
              code: 'ECONNREFUSED',
              message: 'connect failed: nas.test:22',
            );
          }
          if (call.method == 'snapshot') return engine.state;
          return null;
        });
    await open(tester, ShellHome(engine: engine));
    await tester.tap(find.text('home-nas').first);
    await tester.pumpAndSettle();
    expect(find.text('home-nas에 연결하지 못했습니다'), findsOneWidget);
    expect(find.textContaining('connect failed:'), findsNothing);
    await tester.tap(find.text('자세히'));
    await tester.pumpAndSettle();
    expect(find.textContaining('connect failed:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    engine.dispose();
  });
  testWidgets('loaded protected key uses unlocked icon', (tester) async {
    engine.state['keys'] = [
      {
        'id': 2,
        'nickname': 'work',
        'type': 'ED25519',
        'encrypted': true,
        'loaded': true,
      },
    ];
    await open(tester, KeyPage(engine: engine));
    expect(find.byIcon(Icons.lock_open_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await tester.pumpWidget(const SizedBox());
    engine.dispose();
  });
  testWidgets('console input dialog keeps session theme', (tester) async {
    await open(tester, ConsolePage(engine: engine, sessionId: 101));
    await tester.tap(find.byTooltip('터미널 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('텍스트 입력'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(TextFormField))).colorScheme.surface,
      const Color(0xff0e1216),
    );
    await tester.pumpWidget(const SizedBox());
    engine.dispose();
  });
}
