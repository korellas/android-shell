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
import 'package:android_shell_ui/tilde_design.dart';
import 'package:android_shell_ui/management.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AndroidEngine engine;
  late List<MethodCall> changes;
  bool rejectBar = false;
  const keys = [
    'ALT',
    'UP',
    'DOWN',
    'LEFT',
    'RIGHT',
    'HOME',
    'END',
    'PAGE_UP',
    'PAGE_DOWN',
    'INSERT',
    'DELETE',
    'FUNCTION_KEYS',
  ];
  setUp(() {
    changes = [];
    rejectBar = false;
    engine = AndroidEngine()
      ..state = {
        'ready': true,
        'profiles': [
          {'id': 1, 'name': '기본', 'colorSchemeId': -1},
        ],
        'schemes': [
          {
            'id': -1,
            'name': 'Default',
            'palette': [
              0xff000000,
              0xffcc0000,
              0xff00cc00,
              0xffcccc00,
              0xff0000cc,
              0xffcccccc,
            ],
            'foreground': 5,
            'background': 0,
          },
          {
            'id': -2,
            'name': 'Dracula',
            'palette': [
              0xff282a36,
              0xffff5555,
              0xff50fa7b,
              0xfff1fa8c,
              0xffbd93f9,
              0xfff8f8f2,
            ],
            'foreground': 5,
            'background': 0,
          },
        ],
        'preferences': {
          'themeMode': 'SYSTEM',
          'fontFamily': 'SYSTEM_DEFAULT',
          'fonts': [
            {'value': 'SYSTEM_DEFAULT', 'label': 'Default (Monospace)'},
          ],
          'defaultProfileId': 1,
          'terminalMargin': 7,
          'scrollback': '1234',
          'keepalive': true,
          'alwaysvisible': true,
          'imeTogglekey': true,
          'connectionAlerts': true,
          'bellNotification': false,
          'connectionLostNotification': true,
          'bell': true,
          'bellVolume': .25,
          'terminalBarHeight': 36,
          'terminalBarHeights': [26, 28, 36],
          'terminalBarOrder': keys.reversed.toList(),
          'terminalBarHidden': ['INSERT'],
          'terminalBarFn': false,
          'terminalBarDefaults': {
            'height': 28,
            'order': keys,
            'hidden': <String>[],
            'groupFunctionKeys': true,
          },
          'barKeys': [
            for (final k in keys)
              {'name': k, 'label': k == 'FUNCTION_KEYS' ? 'F1–F12' : k},
          ],
        },
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'font.import') changes.add(call);
          if (call.method == 'settings.update') {
            if (rejectBar && call.arguments['key'] == 'terminalBar') {
              throw PlatformException(code: 'engine_error', message: '저장 실패');
            }
            changes.add(call);
            final p = engine.state['preferences'] as Map<String, dynamic>;
            final args = Map<String, dynamic>.from(call.arguments);
            if (args['key'] == 'terminalBar') {
              final v = args['value'] as Map;
              p['terminalBarHeight'] = v['height'];
              p['terminalBarOrder'] = v['order'];
              p['terminalBarHidden'] = v['hidden'];
              p['terminalBarFn'] = v['groupFunctionKeys'];
            } else if (args['key'] == 'colorScheme') {
              (engine.state['profiles'] as List).first['colorSchemeId'] =
                  args['value'];
            } else {
              p[args['key']] = args['value'];
            }
          }
          return null;
        });
  });
  tearDown(() {
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(WidgetTester tester, [Widget? page]) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: page ?? SettingsPage(engine: engine)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('font import opens picker without a name dialog', (tester) async {
    await open(tester);
    await tester.tap(find.text('화면'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('폰트 관리'));
    await tester.tap(find.text('폰트 관리'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('폰트 파일 가져오기'));
    await tester.tap(find.text('폰트 파일 가져오기'));
    await tester.pumpAndSettle();
    expect(changes.map((c) => c.method), ['font.import']);
    expect(changes.single.arguments, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('font import shows failure and is disabled while busy', (
    tester,
  ) async {
    (engine.state['preferences'] as Map)['fontError'] = 'Failed to import font';
    (engine.state['preferences'] as Map)['fontBusy'] = true;
    await open(tester);
    await tester.tap(find.text('화면'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('폰트 관리'));
    await tester.tap(find.text('폰트 관리'));
    await tester.pump(const Duration(milliseconds: 300));
    final tile = find.widgetWithText(ListTile, '폰트 파일 가져오기');
    expect(tester.widget<ListTile>(tile).onTap, isNull);
    expect(find.byType(TildeProgress), findsOneWidget);
    expect(find.text('Failed to import font'), findsOneWidget);
    expect(changes, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('inactive IME toggle is removed from keyboard settings', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('키보드'));
    await tester.pumpAndSettle();
    expect(find.text('입력 모드 전환 버튼'), findsNothing);
    expect(find.text('특수키 구성'), findsOneWidget);
    expect(engine.preferences['imeTogglekey'], true);
    expect(changes, isEmpty);
  });
  testWidgets('opening terminal preserves custom margin and scrollback', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('터미널'));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsWidgets);
    expect(changes, isEmpty);
    expect(engine.preferences['terminalMargin'], 7);
    expect(engine.preferences['scrollback'], '1234');
  });
  testWidgets('scrollback stepper starts from the saved custom value', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('터미널'));
    await tester.pumpAndSettle();
    expect(find.text('1,234'), findsOneWidget);
    expect(changes, isEmpty);
    await tester.tap(find.byTooltip('스크롤 기록 늘리기'));
    await tester.pumpAndSettle();
    expect(engine.preferences['scrollback'], '1734');
  });
  testWidgets('alert master switch preserves individual alert choices', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('연결·알림'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연결 알림 사용'));
    await tester.pumpAndSettle();
    expect(changes.single.arguments, {
      'key': 'connectionAlerts',
      'value': false,
    });
    expect(engine.preferences['bellNotification'], false);
    expect(engine.preferences['connectionLostNotification'], true);
  });
  testWidgets(
    'bar height applies immediately without changing hidden keys or order',
    (tester) async {
      final order = List<String>.from(engine.preferences['terminalBarOrder']);
      await open(tester, TerminalBarPage(engine: engine));
      expect(find.text('저장'), findsNothing);
      await tester.tap(find.text('작게 26dp'));
      await tester.pumpAndSettle();
      expect(engine.preferences['terminalBarHeight'], 26);
      expect(engine.preferences['terminalBarOrder'], order);
      expect(engine.preferences['terminalBarHidden'], ['INSERT']);
      expect(engine.preferences['terminalBarFn'], false);
    },
  );
  testWidgets('failed immediate bar update leaves the saved layout selected', (
    tester,
  ) async {
    rejectBar = true;
    await open(tester, TerminalBarPage(engine: engine));
    await tester.tap(find.text('작게 26dp'));
    await tester.pumpAndSettle();
    expect(find.text('설정을 저장하지 못했습니다'), findsOneWidget);
    await tester.tap(find.text('자세히'));
    await tester.pumpAndSettle();
    expect(find.textContaining('저장 실패'), findsOneWidget);
    expect(engine.preferences['terminalBarHeight'], 36);
    final selected = tester.widget<SegmentedButton<int>>(
      find.byType(SegmentedButton<int>),
    );
    expect(selected.selected, {36});
  });
  testWidgets('scheme card selects the default profile palette', (
    tester,
  ) async {
    await open(tester, SchemesPage(engine: engine));
    await tester.tap(find.text('Dracula').first);
    await tester.pumpAndSettle();
    expect(changes.single.arguments, {'key': 'colorScheme', 'value': -2});
    expect((engine.state['profiles'] as List).first['colorSchemeId'], -2);
  });
  testWidgets(
    'invalid scrollback input is shown before any setting is written',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('터미널'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1,234'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bad');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      expect(engine.preferences['scrollback'], '1234');
      expect(find.text('0–100000 사이로 입력하세요'), findsOneWidget);
    },
  );
  for (final width in [320.0, 1000.0]) {
    for (final category in ['화면', '키보드', '제스처', '터미널', '연결·알림', '보안·백업']) {
      testWidgets('$category handles large text at width $width', (
        tester,
      ) async {
        await open(tester);
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: SettingsPage(engine: engine),
          ),
        );
        await tester.pumpAndSettle();
        for (
          var i = 0;
          i < 12 && find.text(category).first.hitTestable().evaluate().isEmpty;
          i++
        ) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -220),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text(category).first.hitTestable(), findsOneWidget);
        await tester.tap(find.text(category).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 4; i++) {
          await tester.drag(find.byType(ListView).last, const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(changes, isEmpty);
      });
    }
    testWidgets('bar configuration handles large text at width $width', (
      tester,
    ) async {
      await open(tester, TerminalBarPage(engine: engine));
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: TerminalBarPage(engine: engine),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(changes, isEmpty);
    });
    testWidgets('palette cards handle large text at width $width', (
      tester,
    ) async {
      await open(tester, SchemesPage(engine: engine));
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: SchemesPage(engine: engine),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(changes, isEmpty);
    });
  }
}
