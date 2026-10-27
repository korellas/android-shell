// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/terminal/terminal_prompt.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, asset) in [
      ('Pretendard', 'assets/fonts/Pretendard-Regular.ttf'),
      ('JetBrainsMono', 'assets/fonts/JetBrainsMono-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  for (final (size, scale) in [
    (const Size(360, 800), 1.0),
    (const Size(360, 800), 2.0),
    (const Size(800, 360), 1.0),
    (const Size(840, 1100), 1.0),
  ]) {
    for (final surface in [
      'console',
      'menu',
      'exit',
      'password',
      'hostKey',
      'ended',
    ]) {
      testWidgets('$surface ${size.width}x${size.height} scale$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final engine = UiEngineFixture(fontFamily: 'JetBrainsMono');
        engine.state = {
          'ready': true,
          'sessions': [
            {
              'id': 7,
              'hostId': 7,
              'nickname': '개발 서버',
              'open': surface != 'ended',
              'ended': surface == 'ended',
              'canForward': true,
              'backgroundColor': 0xff13110f,
              'foregroundColor': 0xffeae9e7,
              'cursorColor': 0xff6fd8c4,
            },
          ],
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
          'preferences': {
            'fullscreen': true,
            'alwaysvisible': true,
            'titlebarhide': false,
          },
          'prompts': [
            if (surface == 'password' || surface == 'hostKey')
              {
                'sessionId': 7,
                'token': 'test',
                'type': surface == 'password' ? 'string' : 'hostKey',
                'password': true,
                'hint': '비밀번호',
                'hostname': 'dev.example',
                'algorithm': 'ssh-ed25519',
                'keyType': 'ssh-ed25519',
                'keySize': 256,
                'sha256': 'SHA256:abcdefghijklmnopqrstuvwxyz0123456789abcdefg',
                'instructions': '서버에 로그인',
              },
          ],
        };
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          AndroidEngine.channel,
          (call) async => call.method == 'snapshot' ? engine.state : null,
        );
        messenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (_) async => null,
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(AndroidEngine.channel, null);
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          engine.dispose();
        });
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: tildeTheme(Brightness.dark, engine),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: ConsolePage(engine: engine, sessionId: 7),
          ),
        );
        await tester.pumpAndSettle();
        if (surface == 'menu') {
          await tester.tap(find.byTooltip('터미널 메뉴'));
          await tester.pumpAndSettle();
          if (scale > 1) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text('텍스트 입력'),
            );
            final painter = TextPainter(
              text: paragraph.text,
              textDirection: TextDirection.ltr,
              textScaler: paragraph.textScaler,
            )..layout(maxWidth: paragraph.size.width);
            expect(painter.computeLineMetrics(), hasLength(1));
            painter.dispose();
          }
        } else if (surface == 'exit') {
          await tester.tap(find.byTooltip('뒤로'));
          await tester.pumpAndSettle();
        } else if (surface == 'password' || surface == 'hostKey') {
          expect(find.byType(TerminalPrompt), findsOneWidget);
        }
        expect(find.byType(TerminalPane), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (Platform.environment['TILDE_AUDIT_SCREENSHOTS'] case final path?) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '$path/$surface-${size.width.toInt()}-${size.height.toInt()}-$scale.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        engine.dispose();
      });
    }
  }
}
