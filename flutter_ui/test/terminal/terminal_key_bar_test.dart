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

import 'package:android_shell_ui/terminal/terminal_key_bar.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Medium.ttf'));
    await font.load();
  });
  testWidgets('tab remains at the right edge after scrolling and Fn', (
    tester,
  ) async {
    final sent = <TerminalKey>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 360,
              child: TerminalKeyBar(
                onKey: (key, ctrl, alt, shift) => sent.add(key),
                onToggleKeyboard: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final tab = find.widgetWithText(TextButton, 'tab');
    final initial = tester.getRect(tab);
    expect(initial.width, greaterThanOrEqualTo(44));
    expect(initial.height, greaterThanOrEqualTo(44));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(tab), initial);
    await tester.tap(find.text('Fn'));
    await tester.pumpAndSettle();
    expect(tester.getRect(tab), initial);
    await tester.tap(tab);
    await tester.tap(find.text('F1'));
    expect(sent, [TerminalKey.tab, TerminalKey.f1]);
  });

  testWidgets('v2 keycaps retain compact visuals and minimum touch targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalKeyBar(onKey: (_, _, _, _) {}, onToggleKeyboard: () {}),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TerminalKeyBar)).height, 44);
    for (final label in ['Esc', 'Ctrl', '↑', 'Fn', 'tab']) {
      final button = find.ancestor(
        of: find.byKey(ValueKey('terminal-keycap-$label')),
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(button).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('terminal-keycap-Esc'))),
      const Size(44, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('terminal-keycap-↑'))),
      const Size(38, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('terminal-keycap-Fn'))),
      const Size(40, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('terminal-keycap-tab'))),
      const Size(56, 36),
    );
  });

  testWidgets('large key labels fit their caps and pinned tab stays visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TerminalKeyBar(
              onKey: (_, _, _, _) {},
              onToggleKeyboard: () {},
            ),
          ),
        ),
      ),
    );
    for (final label in ['Esc', 'Ctrl', 'Alt', 'tab']) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(text.didExceedMaxLines, isFalse, reason: label);
      final painter = TextPainter(
        text: text.text,
        textDirection: TextDirection.ltr,
        textScaler: text.textScaler,
      )..layout();
      expect(
        text.size.width,
        greaterThanOrEqualTo(painter.width),
        reason: '$label must not wrap or clip',
      );
      painter.dispose();
    }
    expect(
      tester.getRect(find.widgetWithText(TextButton, 'tab')).right,
      lessThanOrEqualTo(360),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sticky modifiers are visible and sent with keys', (
    tester,
  ) async {
    final sent = <(TerminalKey, bool, bool, bool)>[];
    final modifiers = <(bool, bool, bool)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalKeyBar(
            onKey: (key, ctrl, alt, shift) => sent.add((key, ctrl, alt, shift)),
            onToggleKeyboard: () {},
            onModifiersChanged: (ctrl, alt, shift) =>
                modifiers.add((ctrl, alt, shift)),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ctrl'));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.widgetWithText(TextButton, 'Ctrl'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.text('Alt'));
    await tester.tap(find.text('tab'));
    await tester.tap(find.text('Esc'));
    expect(sent, [
      (TerminalKey.tab, true, true, false),
      (TerminalKey.escape, true, true, false),
    ]);
    expect(modifiers.last, (true, true, false));
    await tester.tap(find.text('Ctrl'));
    await tester.tap(find.text('tab'));
    expect(sent.last, (TerminalKey.tab, false, true, false));
  });

  testWidgets('disabled bar emits no key, modifier or keyboard callbacks', (
    tester,
  ) async {
    var emissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalKeyBar(
            enabled: false,
            onKey: (_, _, _, _) => emissions++,
            onToggleKeyboard: () => emissions++,
            onModifiersChanged: (_, _, _) => emissions++,
          ),
        ),
      ),
    );
    for (final label in ['Ctrl', 'Alt', 'tab', 'Esc', 'Fn']) {
      await tester.tap(find.text(label));
    }
    await tester.tap(find.byTooltip('키보드 전환'));
    expect(emissions, 0);
  });

  testWidgets('canonical order and hidden preferences configure scroll keys', (
    tester,
  ) async {
    final sent = <TerminalKey>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalKeyBar(
            order: const ['HOME', 'UP', 'FUNCTION_KEYS', 'ALT'],
            hidden: const {'UP', 'ALT'},
            groupFunctionKeys: false,
            onKey: (key, _, _, _) => sent.add(key),
            onToggleKeyboard: () {},
          ),
        ),
      ),
    );
    expect(find.text('Alt'), findsNothing);
    expect(find.byTooltip('Up'), findsNothing);
    expect(find.text('Fn'), findsNothing);
    await tester.tap(find.text('Home'));
    await tester.tap(find.text('F1'));
    expect(sent, [TerminalKey.home, TerminalKey.f1]);
  });
}
