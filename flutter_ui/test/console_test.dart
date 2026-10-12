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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('dev.korellas.androidshell/engine');
  int? selectedSession;
  bool connected = false;
  late List<MethodCall> calls;
  setUp(() {
    selectedSession = null;
    connected = false;
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.korellas.androidshell/events'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return {'text': 'Clipboard text'};
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') return 0;
          if (call.method == 'resize') return call.arguments;
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'connect') {
            connected = true;
            selectedSession = 101;
            return 101;
          }
          if (call.method == 'session.consumeSelection') selectedSession = null;
          if (call.method == 'session.disconnect') connected = false;
          if (call.method == 'snapshot') {
            return {
              'ready': true,
              'hosts': [
                {
                  'id': 7,
                  'nickname': 'Research',
                  'protocol': 'ssh',
                  'hostname': 'example.test',
                  'port': 22,
                },
              ],
              'selectedSession': selectedSession,
              'sessions': [
                if (connected)
                  {
                    'id': 101,
                    'hostId': 7,
                    'nickname': 'Research',
                    'open': true,
                  },
              ],
              'prompts': [
                if (connected)
                  {
                    'sessionId': 101,
                    'token': 'password-request',
                    'type': 'string',
                    'password': true,
                    'hint': 'Password',
                    'nativePresentation': true,
                  },
              ],
              'preferences': {
                'fullscreen': true,
                'alwaysvisible': true,
                'titlebarhide': false,
              },
            };
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final toolbar in [false, true]) {
    testWidgets(
      'authentication back cancels only its session (toolbar=$toolbar)',
      (tester) async {
        await tester.pumpWidget(const AndroidShellApp());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Research'));
        await tester.pumpAndSettle();
        if (toolbar) {
          await tester.tap(find.byTooltip('뒤로'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(
          calls
              .where((c) => c.method == 'session.disconnect')
              .map((c) => c.arguments),
          [
            {'id': 101},
          ],
        );
        expect(find.byType(ConsolePage), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  for (final open in [false, true]) {
    for (final toolbar in [false, true]) {
      testWidgets(
        'back without a prompt cancels only unfinished connections (open=$open toolbar=$toolbar)',
        (tester) async {
          final engine = AndroidEngine();
          engine.state = {
            'ready': true,
            'hosts': [
              {'id': 7, 'nickname': 'Research'},
            ],
            'sessions': [
              {'id': 101, 'hostId': 7, 'nickname': 'Research', 'open': open},
            ],
            'prompts': [],
            'preferences': {'titlebarhide': false},
          };
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                calls.add(call);
                if (call.method == 'snapshot') return engine.state;
                if (call.method == 'session.disconnect') {
                  engine.state['sessions'] = [];
                }
                if (call.method == 'connect') {
                  engine.state['sessions'] = [
                    {
                      'id': 102,
                      'hostId': 7,
                      'nickname': 'Research',
                      'open': true,
                    },
                  ];
                  engine.state['selectedSession'] = 102;
                  return 102;
                }
                if (call.method == 'session.consumeSelection') {
                  engine.state['selectedSession'] = null;
                }
                return null;
              });
          await tester.pumpWidget(MaterialApp(home: ShellHome(engine: engine)));
          await tester.pumpAndSettle();
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .push(
                MaterialPageRoute<void>(
                  builder: (_) => ConsolePage(engine: engine, sessionId: 101),
                ),
              );
          await tester.pumpAndSettle();
          if (toolbar) {
            await tester.tap(find.byTooltip('뒤로'));
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pumpAndSettle();
          expect(find.byType(ConsolePage), findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          final disconnects = calls
              .where((c) => c.method == 'session.disconnect')
              .toList();
          if (open) {
            expect(disconnects, isEmpty);
            expect(engine.list('sessions').single['id'], 101);
          } else {
            expect(disconnects.map((c) => c.arguments), [
              {'id': 101},
            ]);
            expect(engine.list('sessions'), isEmpty);
            await tester.tap(find.text('Research'));
            await tester.pumpAndSettle();
            expect(
              tester.widget<ConsolePage>(find.byType(ConsolePage)).sessionId,
              102,
            );
            expect(calls.singleWhere((c) => c.method == 'connect').arguments, {
              'id': 7,
            });
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          engine.dispose();
        },
      );
    }
  }

  testWidgets(
    'key registration uses the selected session and a readable key name',
    (tester) async {
      final engine = AndroidEngine();
      engine.state = {
        'ready': true,
        'hosts': [
          {'id': 7, 'nickname': 'mac'},
        ],
        'sessions': [
          {
            'id': 101,
            'hostId': 7,
            'nickname': 'mac · 101',
            'open': true,
            'canEnroll': true,
          },
          {
            'id': 102,
            'hostId': 7,
            'nickname': 'mac · 102',
            'open': true,
            'canEnroll': true,
          },
        ],
        'enrollment': {'biometricAvailable': true},
        'preferences': {'titlebarhide': false},
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'snapshot') return engine.state;
            return null;
          });
      await tester.pumpWidget(
        MaterialApp(
          home: ConsolePage(
            engine: engine,
            sessionId: 102,
            startKeySetup: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('mac SSH 키'), findsOneWidget);
      await tester.tap(find.text('등록 및 검증'));
      await tester.pumpAndSettle();
      expect(calls.singleWhere((c) => c.method == 'key.enroll').arguments, {
        'sessionId': 102,
        'keyId': null,
        'name': 'mac SSH 키',
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      engine.dispose();
    },
  );

  testWidgets(
    'text prompt survives dismissal animation without disposed controller',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => askText(context, '인증', password: true),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'test-only');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('host menu requests a new session without duplicating the host', (
    tester,
  ) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Research 옵션'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 세션으로 연결'));
    await tester.pumpAndSettle();
    final connect = calls.singleWhere((c) => c.method == 'connect');
    expect(connect.arguments, {'id': 7, 'newSession': true});
    expect(tester.widget<ConsolePage>(find.byType(ConsolePage)).sessionId, 101);
    expect(calls.where((c) => c.method == 'host.duplicate'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'reconnecting uses saved host identity rather than session identity',
    (tester) async {
      final engine = AndroidEngine();
      engine.state = {
        'ready': true,
        'sessions': [
          {'id': 101, 'hostId': 7, 'nickname': 'Research', 'open': false},
        ],
        'preferences': {'titlebarhide': false},
      };
      await tester.pumpWidget(
        MaterialApp(home: ConsolePage(engine: engine, sessionId: 101)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('터미널 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다시 연결'));
      await tester.pumpAndSettle();
      expect(calls.singleWhere((c) => c.method == 'connect').arguments, {
        'id': 7,
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      engine.dispose();
    },
  );

  testWidgets(
    'switching and closing same-host sessions targets selected session only',
    (tester) async {
      final engine = AndroidEngine();
      engine.state = {
        'ready': true,
        'sessions': [
          {'id': 101, 'hostId': 7, 'nickname': 'Research · 101', 'open': true},
          {'id': 102, 'hostId': 7, 'nickname': 'Research · 102', 'open': true},
        ],
        'preferences': {'titlebarhide': false},
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'snapshot') return engine.state;
            if (call.method == 'session.disconnect') {
              engine.state['sessions'] = engine
                  .list('sessions')
                  .where((s) => s['id'] != call.arguments['id'])
                  .toList();
            }
            return null;
          });
      await tester.pumpWidget(MaterialApp(home: ShellHome(engine: engine)));
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ConsolePage(engine: engine, sessionId: 101),
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research · 101'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research · 102'));
      await tester.pumpAndSettle();
      final consoleView = tester.widget<AndroidView>(find.byType(AndroidView));
      expect((consoleView.creationParams as Map)['sessionId'], 102);
      await tester.tap(find.byTooltip('터미널 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('연결 끊기'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ConsolePage), findsNothing);
      expect(find.text('다시 연결'), findsNothing);
      expect(engine.list('sessions').map((s) => s['id']), [101]);
      expect(calls.where((c) => c.method == 'connect'), isEmpty);
      expect(
        calls.singleWhere((c) => c.method == 'session.disconnect').arguments,
        {'id': 102},
      );
      expect(calls.where((c) => c.method == 'host.disconnect'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      engine.dispose();
    },
  );

  testWidgets(
    'disconnecting the last session returns to connections immediately',
    (tester) async {
      await tester.pumpWidget(const AndroidShellApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('터미널 메뉴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('연결 끊기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('다시 연결'), findsNothing);
      expect(find.text('세션이 끝났어요'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ConsolePage), findsNothing);
      expect(find.text('다시 연결'), findsNothing);
      expect(find.text('세션이 끝났어요'), findsNothing);
      expect(find.text('Research'), findsOneWidget);
      expect(connected, isFalse);
      expect(calls.where((c) => c.method == 'connect'), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('console menu keeps advanced actions in a secondary menu', (
    tester,
  ) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('터미널 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('붙여넣기'), findsOneWidget);
    expect(find.text('텍스트 입력'), findsOneWidget);
    expect(find.text('터미널 크기 지정'), findsNothing);
    await tester.tap(find.text('추가 기능'));
    await tester.pumpAndSettle();
    expect(find.text('터미널 크기 지정'), findsOneWidget);
    await tester.tap(find.text('텍스트 편집 후 붙여넣기'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Clipboard text'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('connection opens console without a modal authentication popup', (
    tester,
  ) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsolePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('native console authentication is not duplicated by Flutter', (
    tester,
  ) async {
    connected = true;
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'fullscreen console uses the cutout area and native terminal controls',
    (tester) async {
      tester.view.padding = const FakeViewPadding(top: 60, bottom: 30);
      addTearDown(tester.view.resetPadding);
      final engine = AndroidEngine();
      engine.state = {
        'ready': true,
        'sessions': [
          {'id': 7, 'nickname': 'Research', 'open': true},
        ],
        'preferences': {
          'fullscreen': true,
          'alwaysvisible': true,
          'titlebarhide': false,
        },
      };
      await tester.pumpWidget(
        MaterialApp(home: ConsolePage(engine: engine, sessionId: 7)),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(AndroidView));
      expect(rect.top, 36);
      expect(
        rect.bottom,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      engine.dispose();
    },
  );
  for (final fullscreen in [true, false]) {
    testWidgets(
      'native terminal keeps a stable viewport during IME animation (fullscreen=$fullscreen)',
      (tester) async {
        tester.view.viewPadding = const FakeViewPadding(top: 60, bottom: 30);
        tester.view.padding = const FakeViewPadding(top: 60, bottom: 30);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        final engine = AndroidEngine();
        engine.state = {
          'ready': true,
          'sessions': [
            {'id': 7, 'nickname': 'Research', 'open': true},
          ],
          'preferences': {
            'fullscreen': fullscreen,
            'alwaysvisible': true,
            'titlebarhide': false,
          },
        };
        await tester.pumpWidget(
          MaterialApp(home: ConsolePage(engine: engine, sessionId: 7)),
        );
        await tester.pumpAndSettle();
        final viewport = tester.getRect(find.byType(AndroidView));
        tester.view.padding = const FakeViewPadding(top: 60);
        for (final inset in [100.0, 200.0, 300.0, 200.0, 100.0, 0.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pump();
          expect(tester.getRect(find.byType(AndroidView)), viewport);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        engine.dispose();
      },
    );
  }

  testWidgets('windowed console retains system bar insets', (tester) async {
    tester.view.viewPadding = const FakeViewPadding(top: 60, bottom: 30);
    addTearDown(tester.view.resetViewPadding);
    tester.view.padding = const FakeViewPadding(top: 60, bottom: 30);
    addTearDown(tester.view.resetPadding);
    final engine = AndroidEngine();
    engine.state = {
      'ready': true,
      'sessions': [
        {'id': 7, 'nickname': 'Research', 'open': true},
      ],
      'preferences': {
        'fullscreen': false,
        'alwaysvisible': true,
        'titlebarhide': false,
      },
    };
    await tester.pumpWidget(
      MaterialApp(home: ConsolePage(engine: engine, sessionId: 7)),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(AndroidView));
    expect(rect.top, 36 + 60 / tester.view.devicePixelRatio);
    expect(
      rect.bottom,
      (tester.view.physicalSize.height - 30) / tester.view.devicePixelRatio,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    engine.dispose();
  });
}
