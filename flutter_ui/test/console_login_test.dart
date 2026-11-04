// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/terminal/terminal_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'ui_engine_fixture.dart';

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('Pretendard', 'assets/fonts/Pretendard-Regular.ttf'),
      ('JetBrainsMono', 'assets/fonts/JetBrainsMono-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  for (final size in [const Size(390, 844), const Size(912, 680)]) {
    for (final hideTitle in [false, true]) {
      testWidgets(
        'login stages keep navigation visible at $size (hideTitle=$hideTitle)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final engine = UiEngineFixture();
          final session = <String, dynamic>{
            'id': 7,
            'nickname': '개발 서버',
            'open': false,
            'connecting': true,
            'connectionLog': ['dev.example:22 연결 중', 'SSH 연결 협상 중'],
            'connectionHost': 'admin@dev.example:22',
            'connectionPhase': 'authentication',
            'banners': [
              {
                'id': 1,
                'sourceName': '개발 서버',
                'message': 'Authorized users only',
              },
            ],
          };
          engine.state = {
            'ready': true,
            'sessions': [session],
            'preferences': {
              'fullscreen': true,
              'titlebarhide': hideTitle,
              'terminalMargin': 0,
            },
          };
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(
            AndroidEngine.channel,
            (call) async => call.method == 'snapshot'
                ? {
                    ...engine.state,
                    'sessions': [session],
                  }
                : null,
          );
          messenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (_) async => null,
          );
          addTearDown(() {
            messenger.setMockMethodCallHandler(AndroidEngine.channel, null);
            messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          });
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              builder: (_, child) =>
                  RepaintBoundary(key: boundary, child: child!),
              home: ConsolePage(engine: engine, sessionId: 7),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('개발 서버에 연결하는 중'), findsOneWidget);
          expect(find.text('서버 찾기'), findsOneWidget);
          expect(find.text('서버 키 확인'), findsOneWidget);
          expect(find.text('로그인'), findsOneWidget);
          expect(find.text('터미널 열기'), findsOneWidget);
          expect(find.textContaining('SSH 연결 협상 중'), findsNothing);
          expect(find.byTooltip('배너 닫기'), findsNothing);
          await tester.pump(const Duration(seconds: 4));
          expect(find.byTooltip('홈'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('개발 서버에 연결하는 중')).dy,
            greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
          );
          if (Platform.environment['TILDE_LAYOUT_SCREENSHOTS']
              case final path?) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final platform = Theme.of(
                tester.element(find.byType(ConsolePage)),
              ).platform.name;
              final file = File(
                '$path/terminal-login-${size.width.toInt()}-$platform-$hideTitle.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          engine.state['prompts'] = [
            {
              'sessionId': 7,
              'token': 'password',
              'type': 'string',
              'hint': '비밀번호',
              'password': true,
            },
          ];
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await engine.refresh();
          await tester.pump();
          expect(find.byType(TerminalPromptSurface), findsOneWidget);
          expect(find.byTooltip('홈'), findsOneWidget);
          await tester.ensureVisible(find.text('취소').last);
          expect(tester.takeException(), isNull);
          engine.state['prompts'] = [];
          tester.view.resetViewInsets();

          session['connecting'] = false;
          session['ended'] = true;
          session['progress'] = {
            'state': 'ERROR',
            'message': 'Connection refused',
          };
          await engine.refresh();
          await tester.pumpAndSettle();
          expect(find.text('로그인하지 못했습니다'), findsOneWidget);
          expect(find.textContaining('Connection refused'), findsNothing);
          expect(find.byTooltip('홈'), findsOneWidget);
          expect(find.text('다시 시도'), findsOneWidget);
          await tester.tap(find.text('자세히'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Connection refused'), findsOneWidget);
          Navigator.of(
            tester.element(find.textContaining('Connection refused')),
          ).pop();
          await tester.pumpAndSettle();

          session['open'] = true;
          session['ended'] = false;
          session['connectionLog'] = null;
          session['progress'] = null;
          await engine.refresh();
          await tester.pumpAndSettle();
          expect(find.byType(SelectableText), findsNothing);
          final view = tester.state<TerminalViewState>(
            find.byType(TerminalView),
          );
          final bounds = tester.getRect(find.byType(TerminalView));
          expect(view.globalCursorRect.left, greaterThan(bounds.left));
          expect(view.globalCursorRect.top, greaterThan(bounds.top));
          expect(tester.takeException(), isNull);
        },
        variant: const TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.iOS,
        }),
      );
    }
  }
}
