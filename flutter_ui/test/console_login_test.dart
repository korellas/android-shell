// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'ui_engine_fixture.dart';

void main() {
  for (final hideTitle in [false, true]) {
    testWidgets('login log clears the progress bar (hideTitle=$hideTitle)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
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
        'banners': [
          {'id': 1, 'sourceName': '개발 서버', 'message': 'Authorized users only'},
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
      await tester.pumpWidget(
        MaterialApp(home: ConsolePage(engine: engine, sessionId: 7)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final log = find.text('dev.example:22 연결 중\nSSH 연결 협상 중');
      expect(log, findsOneWidget);
      expect(
        tester.getTopLeft(log).dy,
        greaterThan(
          tester.getBottomLeft(find.byType(LinearProgressIndicator)).dy,
        ),
      );
      expect(tester.getTopLeft(log).dx, greaterThan(0));
      expect(find.byTooltip('배너 닫기'), findsNothing);
      expect(
        tester.getTopLeft(log).dy,
        greaterThan(tester.getBottomLeft(find.byType(AppBar)).dy),
      );

      session['connecting'] = false;
      session['ended'] = true;
      session['progress'] = {'state': 'ERROR', 'message': 'Connection refused'};
      await engine.refresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('SSH 연결 협상 중'), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget);

      session['open'] = true;
      session['ended'] = false;
      session['connectionLog'] = null;
      session['progress'] = null;
      await engine.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
      final view = tester.state<TerminalViewState>(find.byType(TerminalView));
      final bounds = tester.getRect(find.byType(TerminalView));
      expect(view.globalCursorRect.left, greaterThan(bounds.left));
      expect(view.globalCursorRect.top, greaterThan(bounds.top));
      expect(tester.takeException(), isNull);
    });
  }
}
