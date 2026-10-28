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
import 'package:android_shell_ui/terminal/terminal_input.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

void main() {
  late TerminalInputController input;
  setUp(() {
    input = TerminalInputController(terminal: Terminal());
  });
  tearDown(() {
    input.dispose();
  });
  setUpAll(() async {
    final font = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Medium.ttf'));
    await font.load();
  });
  testWidgets(
    'key preferences control haptics and keyboard-toggle visibility',
    (tester) async {
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalKeyBar(
              input: input,
              hapticFeedback: true,
              showKeyboardToggle: false,
              onKey: (_, _, _, _) {},
              onToggleKeyboard: () {},
            ),
          ),
        ),
      );
      expect(find.byTooltip('키보드 전환'), findsNothing);
      await tester.tap(find.text('Esc'));
      expect(haptics.single.arguments, 'HapticFeedbackType.selectionClick');
    },
  );

  testWidgets('one-shot and locked modifiers have distinct keycap states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalKeyBar(
            input: input,
            onKey: (_, _, _, _) {},
            onToggleKeyboard: () {},
          ),
        ),
      ),
    );
    final colors = Theme.of(
      tester.element(find.byType(TerminalKeyBar)),
    ).colorScheme;
    Color cap(String label) =>
        (tester
                    .widget<Ink>(
                      find.ancestor(
                        of: find.byKey(ValueKey('terminal-keycap-$label')),
                        matching: find.byType(Ink),
                      ),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    await tester.tap(find.text('Ctrl'));
    await tester.pump();
    expect(cap('Ctrl'), colors.primaryContainer);
    input.setModifiers(ctrl: false);
    input.stickyModifiers = 'yes';
    await tester.tap(find.text('Ctrl'));
    await tester.pump();
    expect(cap('Ctrl'), colors.primary);
    input.setModifiers(ctrl: false);
    input.stickyModifiers = 'alt';
    await tester.tap(find.text('Ctrl'));
    await tester.pump();
    expect(cap('Ctrl'), colors.primaryContainer);
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
                input: input,
                onKey: (key, ctrl, alt, shift) => sent.add(key),
                onToggleKeyboard: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final tab = find.widgetWithText(TextButton, 'Tab');
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
          body: TerminalKeyBar(
            input: input,
            onKey: (_, _, _, _) {},
            onToggleKeyboard: () {},
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TerminalKeyBar)).height, 44);
    for (final label in ['Esc', 'Ctrl', '/', 'Fn', 'Tab']) {
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
      tester.getSize(find.byKey(const ValueKey('terminal-keycap-/'))),
      const Size(44, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('terminal-keycap-Fn'))),
      const Size(40, 36),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('terminal-keycap-Tab'))),
      const Size(56, 36),
    );
  });

  testWidgets('large key labels fit their caps and pinned tab stays visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
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
              input: input,
              onKey: (_, _, _, _) {},
              onToggleKeyboard: () {},
            ),
          ),
        ),
      ),
    );
    for (final label in ['Esc', 'Ctrl', '/', 'Tab']) {
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
      tester.getRect(find.widgetWithText(TextButton, 'Tab')).right,
      lessThanOrEqualTo(320),
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
            input: input,
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
    await tester.tap(find.text('Tab'));
    await tester.tap(find.text('Esc'));
    expect(sent, [
      (TerminalKey.tab, true, false, false),
      (TerminalKey.escape, true, false, false),
    ]);
    expect(modifiers.last, (true, false, false));
    await tester.tap(find.text('Ctrl'));
    await tester.tap(find.text('Tab'));
    expect(sent.last, (TerminalKey.tab, false, false, false));
  });

  testWidgets('disabled bar emits no key, modifier or keyboard callbacks', (
    tester,
  ) async {
    var emissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalKeyBar(
            input: input,
            enabled: false,
            onKey: (_, _, _, _) => emissions++,
            onToggleKeyboard: () => emissions++,
            onModifiersChanged: (_, _, _) => emissions++,
          ),
        ),
      ),
    );
    for (final label in ['Ctrl', '/', 'Tab', 'Esc', 'Fn']) {
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
            input: input,
            order: const ['HOME', 'SLASH', 'FUNCTION_KEYS', 'COLON'],
            hidden: const {'SLASH', 'COLON'},
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
