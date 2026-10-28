// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'package:android_shell_ui/terminal/terminal_input.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';

void main() {
  late Terminal terminal;
  late TerminalController selection;
  late TerminalInputController input;
  late List<String> output;

  setUp(() {
    output = [];
    terminal = Terminal(onOutput: output.add);
    selection = TerminalController();
    input = TerminalInputController(terminal: terminal);
  });

  tearDown(() {
    input.dispose();
    selection.dispose();
  });

  Widget view({bool enabled = true}) => MaterialApp(
    home: Scaffold(
      body: TerminalPane(
        terminal: terminal,
        controller: selection,
        input: input,
        enabled: enabled,
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(view());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TerminalView));
    await tester.pumpAndSettle();
  }

  testWidgets('ended output remains selectable and scrollable without bytes', (
    tester,
  ) async {
    final key = GlobalKey<TerminalPaneState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalPane(
            key: key,
            terminal: terminal,
            controller: selection,
            input: input,
            enabled: false,
          ),
        ),
      ),
    );
    terminal.write(List.generate(100, (i) => 'line $i\r\n').join());
    terminal.write('\x1b[?1000h\x1b[?1006h');
    await tester.pumpAndSettle();
    final position = tester
        .state<TerminalViewState>(find.byType(TerminalView))
        .scrollableState!
        .position;
    final before = position.pixels;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(TerminalView)),
        scrollDelta: const Offset(0, -120),
      ),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, lessThan(before));
    await key.currentState!.viewAction('selectAll');
    await tester.pumpAndSettle();
    expect(find.text('복사'), findsOneWidget);
    expect(find.text('편집 후 전송'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Tab'), findsNothing);
    await tester.tap(find.byType(TerminalView));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    input.paste('blocked');
    expect(output, isEmpty);
  });

  testWidgets(
    'one-shot modifiers clear after IME and hardware input across remount',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Ctrl'));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TerminalView));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  c',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  c',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      expect(output.join(), '\x03c');
      await tester.tap(find.text('Ctrl'));
      await tester.tap(find.byTooltip('키보드 전환'));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD, character: 'd');
      expect(output.join(), '\x03c\x03d');
    },
  );

  testWidgets('keybar Tab sends pending Hangul before its byte', (
    tester,
  ) async {
    await open(tester);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '  한',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 2, end: 3),
      ),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Tab'));
    expect(output.join(), '한\t');
  });

  testWidgets('editing selection sends only accepted edited text', (
    tester,
  ) async {
    await open(tester);
    terminal.write('original\x1b[?2004h');
    selection.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(8, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('복사'), findsOneWidget);
    await tester.tap(find.text('편집 후 전송'));
    await tester.pumpAndSettle();
    expect(selection.selection, isNull);
    expect(output, isEmpty);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('original'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'edited\ntext');
    await tester.tap(find.text('전송'));
    await tester.pumpAndSettle();
    expect(output.join(), '\x1b[200~edited\ntext\x1b[201~');
    expect(find.text('텍스트 편집'), findsNothing);
  });

  testWidgets('disabled pane blocks mouse, keybar and IME input', (
    tester,
  ) async {
    await open(tester);
    terminal.write('\x1b[?1000h\x1b[?1006h');
    await tester.pumpWidget(view(enabled: false));
    await tester.pumpAndSettle();
    output.clear();
    await tester.tap(find.byType(TerminalView), warnIfMissed: false);
    expect(find.widgetWithText(TextButton, 'Tab'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
    input.sendText('blocked');
    expect(output, isEmpty);
  });

  testWidgets('sticky Ctrl from keybar applies to ordinary IME input', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Ctrl'));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '  c',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    expect(output.join(), '\x03');
  });
  testWidgets(
    'public menu actions select copy paste and resize shared terminal',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final key = GlobalKey<TerminalPaneState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalPane(
              key: key,
              terminal: terminal,
              controller: selection,
              input: input,
              keyOrder: const ['UP'],
              hiddenKeys: const {'UP'},
              keyHeight: 48,
              groupFunctionKeys: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      terminal.write('hello');
      await key.currentState!.viewAction('selectAll');
      await tester.pumpAndSettle();
      expect(selection.selectionFor(terminal.buffer), isNotNull);
      expect(
        find.byKey(const ValueKey('terminal-selection-menu')),
        findsOneWidget,
      );
      await key.currentState!.viewAction('copy');
      expect(
        (await Clipboard.getData(Clipboard.kTextPlain))!.text,
        contains('hello'),
      );
      expect(selection.selection, isNull);
      output.clear();
      terminal.write('\x1b[?2004h');
      await key.currentState!.viewAction('paste');
      expect(output.join(), startsWith('\x1b[200~hello'));
      key.currentState!.resize(rows: 24, columns: 80);
      await tester.pumpAndSettle();
      expect(terminal.viewWidth, 80);
      expect(terminal.viewHeight, 24);
      expect(
        tester.widget<TerminalView>(find.byType(TerminalView)).autoResize,
        isFalse,
      );
      key.currentState!.resize();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TerminalView>(find.byType(TerminalView)).autoResize,
        isTrue,
      );
      expect(find.byKey(const ValueKey('terminal-keycap-↑')), findsNothing);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('terminal-keycap-Tab')))
            .height,
        48,
      );
    },
  );
  testWidgets(
    'shared terminal preserves swipe page gestures and font shortcuts',
    (tester) async {
      final swipes = <int>[];
      final fonts = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalPane(
              terminal: terminal,
              controller: selection,
              input: input,
              pageGesture: true,
              onSwipe: swipes.add,
              onFontSize: fonts.add,
              volumeFont: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(TerminalView));
      await tester.dragFrom(rect.center, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(swipes, [1]);
      output.clear();
      final point = Offset(rect.left + 20, rect.center.dy);
      final gesture = await tester.startGesture(point);
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -150));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(output.join(), contains('\x1b[6~'));
      output.clear();
      final first = await tester.startGesture(point);
      final second = await tester.startGesture(
        point + const Offset(25, 0),
        pointer: 2,
      );
      await first.moveBy(const Offset(0, -150));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(output, isEmpty);
      selection.setSelection(
        terminal.buffer.createAnchor(0, 0),
        terminal.buffer.createAnchor(2, 0),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(point, const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(output, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
      expect(fonts, [true]);
    },
  );
}
