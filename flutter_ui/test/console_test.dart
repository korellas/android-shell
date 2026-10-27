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
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';
import 'package:android_shell_ui/terminal/terminal_key_bar.dart';
import 'package:android_shell_ui/terminal/terminal_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'ui_engine_fixture.dart';

void main() {
  const channel = MethodChannel('dev.korellas.androidshell/engine');
  int? selectedSession;
  bool connected = false;
  bool authenticationPending = true;
  late List<MethodCall> calls;
  setUp(() {
    selectedSession = null;
    connected = false;
    authenticationPending = true;
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
          if (call.method == 'prompt.respond') authenticationPending = false;
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
                if (connected && authenticationPending)
                  {
                    'sessionId': 101,
                    'token': 'password-request',
                    'type': 'string',
                    'password': true,
                    'hint': 'Password',
                    'nativePresentation': false,
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
      'authentication back asks before ending its session (toolbar=$toolbar)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(AndroidShellApp(engine: UiEngineFixture()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Research'));
        await tester.pumpAndSettle();
        if (toolbar) {
          await tester.tap(find.byTooltip('뒤로'));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.text('Research에서 나가기'), findsOneWidget);
        expect(calls.where((c) => c.method == 'session.disconnect'), isEmpty);
        await tester.tap(find.text('세션 종료'));
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
        'back applies the chosen session action (open=$open toolbar=$toolbar)',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final engine = UiEngineFixture();
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
          expect(find.text('Research에서 나가기'), findsOneWidget);
          expect(calls.where((c) => c.method == 'session.disconnect'), isEmpty);
          await tester.tap(find.text(open ? '연결 유지' : '세션 종료'));
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
    'common SSH authentication is inline and responds to its session',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UiEngineFixture();
      await tester.pumpWidget(AndroidShellApp(engine: engine));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(engine.list('prompts').single['token'], 'password-request');
      expect(find.byType(TerminalPrompt), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.labelText,
        'Password',
      );
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        calls.singleWhere((call) => call.method == 'prompt.respond').arguments,
        {'sessionId': 101, 'token': 'password-request', 'value': 'secret'},
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'cancelling inline authentication sends null without navigating',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(AndroidShellApp(engine: UiEngineFixture()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      expect(
        tester.widget<TerminalPane>(find.byType(TerminalPane)).enabled,
        isFalse,
      );
      await tester.tap(find.byTooltip('인증 취소'));
      await tester.pumpAndSettle();
      expect(
        calls.singleWhere((call) => call.method == 'prompt.respond').arguments,
        {'sessionId': 101, 'token': 'password-request', 'value': null},
      );
      expect(find.byType(TerminalPrompt), findsNothing);
      expect(find.byType(ConsolePage), findsOneWidget);
      expect(
        calls.where((call) => call.method == 'session.disconnect'),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('switching sessions leaves background authentication pending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = UiEngineFixture()
      ..state = {
        'ready': true,
        'sessions': [
          {'id': 101, 'nickname': 'First', 'open': true},
          {'id': 102, 'nickname': 'Second', 'open': true},
        ],
        'prompts': [
          {
            'sessionId': 101,
            'token': 'first',
            'type': 'string',
            'hint': 'Password',
            'password': true,
            'nativePresentation': false,
          },
          {
            'sessionId': 102,
            'token': 'second',
            'type': 'string',
            'instructions': 'Verification',
            'hint': 'Code',
            'password': false,
            'nativePresentation': false,
          },
        ],
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'prompt.respond') {
            engine.state['prompts'] = engine
                .list('prompts')
                .where((prompt) => prompt['token'] != call.arguments['token'])
                .toList();
          }
          return null;
        });
    await tester.pumpWidget(
      MaterialApp(home: ConsolePage(engine: engine, sessionId: 101)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'unsent');
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(find.text('Verification'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(calls.where((call) => call.method == 'prompt.respond'), isEmpty);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byTooltip('인증 전송'));
    await tester.pumpAndSettle();
    expect(
      calls.singleWhere((call) => call.method == 'prompt.respond').arguments,
      {'sessionId': 102, 'token': 'second', 'value': '123456'},
    );
    expect(engine.list('prompts').single['token'], 'first');
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(find.byType(TerminalPrompt), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.labelText,
      'Password',
    );
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    engine.dispose();
    await tester.pumpAndSettle();
  });

  for (final accepted in [false, true]) {
    testWidgets('inline trust confirmation responds with $accepted', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UiEngineFixture()
        ..state = {
          'ready': true,
          'sessions': [
            {'id': 101, 'nickname': 'Research', 'open': true},
          ],
          'prompts': [
            {
              'sessionId': 101,
              'token': 'trust',
              'type': 'boolean',
              'instructions': '서버 키 신뢰 확인',
              'message': 'SHA256:example',
              'nativePresentation': false,
            },
          ],
        };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'snapshot') return engine.state;
            if (call.method == 'prompt.respond') engine.state['prompts'] = [];
            return null;
          });
      await tester.pumpWidget(
        MaterialApp(home: ConsolePage(engine: engine, sessionId: 101)),
      );
      await tester.pumpAndSettle();
      expect(find.text('SHA256:example'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.text(accepted ? '예' : '아니요'));
      await tester.pumpAndSettle();
      expect(
        calls.singleWhere((call) => call.method == 'prompt.respond').arguments,
        {'sessionId': 101, 'token': 'trust', 'value': accepted},
      );
      await tester.pumpWidget(const SizedBox());
      engine.dispose();
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'host-key inline prompt keeps fingerprint formats and trust choice',
    (tester) async {
      Object? response;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalPrompt(
              prompt: {
                'type': 'hostKey',
                'hostname': 'server.test',
                'keyType': 'Ed25519',
                'keySize': 256,
                'sha256': 'SHA256:example',
                'md5': 'MD5:example',
                'randomArt': 'random-art',
                'bubblebabble': 'bubble-babble',
              },
              onResponse: (value) async => response = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('server.test 서버 키 확인'), findsOneWidget);
      expect(find.text('SHA256:example'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MD5').last);
      await tester.pumpAndSettle();
      expect(find.text('MD5:example'), findsOneWidget);
      await tester.tap(find.text('서버 키 신뢰'));
      await tester.pumpAndSettle();
      expect(response, isTrue);
      expect(find.byType(Dialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('keeping authentication pending does not disconnect', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AndroidShellApp(engine: UiEngineFixture()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('연결 유지'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsolePage), findsNothing);
    expect(connected, isTrue);
    expect(calls.where((c) => c.method == 'session.disconnect'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('cancelling exit keeps the terminal and connection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AndroidShellApp(engine: UiEngineFixture()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ConsolePage), findsOneWidget);
    expect(connected, isTrue);
    expect(calls.where((c) => c.method == 'session.disconnect'), isEmpty);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ConsolePage), findsOneWidget);
    expect(calls.where((c) => c.method == 'session.disconnect'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'key registration uses the selected session and a readable key name',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UiEngineFixture();
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
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AndroidShellApp(engine: UiEngineFixture()));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Research'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 세션'));
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
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UiEngineFixture();
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
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UiEngineFixture();
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
      await tester.ensureVisible(find.text('Research · 102'));
      await tester.tap(find.text('Research · 102'));
      await tester.pumpAndSettle();
      final consoleView = tester.widget<TerminalPane>(
        find.byType(TerminalPane),
      );
      expect(consoleView.terminal, same(engine.terminalSession(102)!.terminal));
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
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(AndroidShellApp(engine: UiEngineFixture()));
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

  testWidgets('console menu exposes grouped actions in one menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AndroidShellApp(engine: UiEngineFixture()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('터미널 메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('붙여넣기'), findsOneWidget);
    expect(find.text('텍스트 입력'), findsOneWidget);
    expect(find.text('추가 기능'), findsNothing);
    expect(find.text('열×행'), findsOneWidget);
    expect(find.text('조합 모드'), findsNothing);
    await tester.tap(find.text('편집 후 전송'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Clipboard text'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('connection opens console without a modal authentication popup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AndroidShellApp(engine: UiEngineFixture()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    expect(find.byType(ConsolePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'background common authentication stays pending until its console opens',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      connected = true;
      final engine = UiEngineFixture();
      await tester.pumpWidget(AndroidShellApp(engine: engine));
      await tester.pumpAndSettle();
      expect(engine.list('prompts').single['nativePresentation'], isFalse);
      expect(find.byType(ConsolePage), findsNothing);
      expect(find.byType(TerminalPrompt), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(calls.where((call) => call.method == 'prompt.respond'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'fullscreen console uses the cutout area and common terminal controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.padding = const FakeViewPadding(top: 60, bottom: 30);
      addTearDown(tester.view.resetPadding);
      final engine = UiEngineFixture();
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
      final rect = tester.getRect(find.byType(TerminalPane));
      expect(rect.top, 44);
      expect(
        rect.bottom,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
      expect(
        find.descendant(
          of: find.byType(TerminalPane),
          matching: find.byType(TerminalKeyBar),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      engine.dispose();
    },
  );
  for (final fullscreen in [true, false]) {
    testWidgets(
      'common terminal reserves the IME inset during animation (fullscreen=$fullscreen)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.viewPadding = const FakeViewPadding(top: 60, bottom: 30);
        tester.view.padding = const FakeViewPadding(top: 60, bottom: 30);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        final engine = UiEngineFixture();
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
        final viewport = tester.getRect(find.byType(TerminalPane));
        for (final inset in [100.0, 200.0, 300.0, 200.0, 100.0, 0.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          tester.view.padding = FakeViewPadding(
            top: 60,
            bottom: (30 - inset).clamp(0, 30),
          );
          await tester.pump();
          final resized = tester.getRect(find.byType(TerminalPane));
          expect(resized.top, viewport.top);
          expect(
            resized.bottom,
            844 - (fullscreen ? inset : (inset > 30 ? inset : 30)),
          );
          final terminalView = tester.state<TerminalViewState>(
            find.byType(TerminalView),
          );
          final render = terminalView.renderTerminal;
          final terminal = tester
              .widget<TerminalView>(find.byType(TerminalView))
              .terminal;
          expect(
            terminal.viewWidth,
            render.size.width ~/ render.cellSize.width,
          );
          expect(
            terminal.viewHeight,
            render.size.height ~/ render.cellSize.height,
          );
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        engine.dispose();
      },
    );
  }

  testWidgets(
    'auto-hidden title overlays full terminal without changing rows',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UiEngineFixture();
      engine.state = {
        'ready': true,
        'sessions': [
          {'id': 7, 'nickname': 'Research', 'open': true},
        ],
        'preferences': {
          'fullscreen': true,
          'alwaysvisible': true,
          'titlebarhide': true,
        },
      };
      await tester.pumpWidget(
        MaterialApp(home: ConsolePage(engine: engine, sessionId: 7)),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(TerminalPane));
      final terminal = tester
          .widget<TerminalPane>(find.byType(TerminalPane))
          .terminal;
      final beforeRows = terminal.viewHeight;
      expect(before.top, 0);
      expect(before.bottom, 844);
      expect(find.byType(AppBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(AppBar), findsNothing);
      expect(tester.getRect(find.byType(TerminalPane)), before);
      expect(terminal.viewHeight, beforeRows);
      await tester.tap(find.byType(TerminalView));
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.getRect(find.byType(TerminalPane)), before);
      expect(terminal.viewHeight, beforeRows);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      engine.dispose();
    },
  );

  testWidgets('windowed console retains system bar insets', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.viewPadding = const FakeViewPadding(top: 60, bottom: 30);
    addTearDown(tester.view.resetViewPadding);
    tester.view.padding = const FakeViewPadding(top: 60, bottom: 30);
    addTearDown(tester.view.resetPadding);
    final engine = UiEngineFixture();
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
    final rect = tester.getRect(find.byType(TerminalPane));
    expect(rect.top, 44 + 60 / tester.view.devicePixelRatio);
    expect(
      rect.bottom,
      (tester.view.physicalSize.height - 30) / tester.view.devicePixelRatio,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    engine.dispose();
  });
}
