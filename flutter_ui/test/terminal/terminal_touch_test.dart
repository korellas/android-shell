// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:android_shell_ui/terminal/terminal_input.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

void main() {
  late Terminal terminal;
  late TerminalController controller;
  late TerminalInputController input;
  late List<String> output;

  setUp(() {
    output = [];
    terminal = Terminal(onOutput: output.add);
    controller = TerminalController();
    input = TerminalInputController(terminal: terminal);
  });
  tearDown(() {
    input.dispose();
    controller.dispose();
  });

  Future<void> mount(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalPane(
            terminal: terminal,
            controller: controller,
            input: input,
            enabled: enabled,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('touch swipes send all arrow directions and stop on release', (
    tester,
  ) async {
    await mount(tester);
    final center = tester.getCenter(find.byType(TerminalView));
    for (final (delta, sequence) in [
      (const Offset(-72, 0), '\x1b[D'),
      (const Offset(72, 0), '\x1b[C'),
      (const Offset(0, -72), '\x1b[A'),
      (const Offset(0, 72), '\x1b[B'),
    ]) {
      output.clear();
      await tester.dragFrom(center, delta);
      await tester.pumpAndSettle();
      expect(output, isNotEmpty);
      expect(output.every((byte) => byte == sequence), isTrue);
      final count = output.length;
      await tester.pump(const Duration(seconds: 1));
      expect(output.length, count);
    }
  });

  testWidgets('tap moves along current line but ignores another row', (
    tester,
  ) async {
    await mount(tester);
    terminal.write('hello');
    await tester.pumpAndSettle();
    final render = tester
        .state<TerminalViewState>(find.byType(TerminalView))
        .renderTerminal;
    await tester.tapAt(
      render.localToGlobal(
        render.getOffset(const CellOffset(2, 0)) +
            render.cellSize.center(Offset.zero),
      ),
    );
    expect(output.join(), '\x1b[D\x1b[D\x1b[D');
    output.clear();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tapAt(
      render.localToGlobal(
        render.getOffset(const CellOffset(2, 2)) +
            render.cellSize.center(Offset.zero),
      ),
    );
    expect(output, isEmpty);
  });

  testWidgets('tap counts wide Hangul characters as single cursor steps', (
    tester,
  ) async {
    await mount(tester);
    terminal.write('가나ab');
    await tester.pumpAndSettle();
    final render = tester
        .state<TerminalViewState>(find.byType(TerminalView))
        .renderTerminal;
    await tester.tapAt(
      render.localToGlobal(
        render.getOffset(const CellOffset(2, 0)) +
            render.cellSize.center(Offset.zero),
      ),
    );
    expect(output.join(), '\x1b[D\x1b[D\x1b[D');
  });

  testWidgets('blank long press offers direct paste without selecting text', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') return {'text': 'pasted'};
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await mount(tester);
    await tester.longPress(find.byType(TerminalView));
    await tester.pumpAndSettle();
    expect(find.text('붙여넣기'), findsOneWidget);
    expect(find.text('복사'), findsNothing);
    await tester.tap(find.text('붙여넣기'));
    await tester.pumpAndSettle();
    expect(output.join(), 'pasted');
    expect(find.text('붙여넣기'), findsNothing);
  });

  testWidgets('symbols replace Alt and arrows and repeat after a delay', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Alt'), findsNothing);
    expect(find.byTooltip('Up'), findsNothing);
    await tester.tap(find.text('/'));
    await tester.tap(find.text(':'));
    expect(output.join(), '/:');
    output.clear();
    final hold = await tester.startGesture(tester.getCenter(find.text('/')));
    await tester.pump(const Duration(milliseconds: 399));
    expect(output.length, lessThanOrEqualTo(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(output, isNotEmpty);
    final count = output.length;
    await tester.pump(const Duration(milliseconds: 50));
    expect(output.length, count + 1);
    await hold.up();
    await tester.pump(const Duration(seconds: 1));
    expect(output.length, count + 1);
  });

  testWidgets('cancel disable and disposal stop key repeat', (tester) async {
    await mount(tester);
    final hold = await tester.startGesture(tester.getCenter(find.text('Tab')));
    await tester.pump(const Duration(milliseconds: 450));
    expect(output, isNotEmpty);
    await hold.cancel();
    final count = output.length;
    await tester.pump(const Duration(seconds: 1));
    expect(output.length, count);
    final next = await tester.startGesture(tester.getCenter(find.text('Tab')));
    await tester.pump(const Duration(milliseconds: 450));
    await mount(tester, enabled: false);
    final disabledCount = output.length;
    await tester.pump(const Duration(seconds: 1));
    expect(output.length, disabledCount);
    await next.up();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('two fingers scroll history without emitting arrows or a menu', (
    tester,
  ) async {
    await mount(tester);
    terminal.write(List.generate(100, (i) => 'line $i\r\n').join());
    await tester.pumpAndSettle();
    final view = tester.state<TerminalViewState>(find.byType(TerminalView));
    final position = view.scrollableState!.position;
    final before = position.pixels;
    final point = tester.getCenter(find.byType(TerminalView));
    final first = await tester.startGesture(point);
    final second = await tester.startGesture(
      point + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('붙여넣기'), findsNothing);
    await first.up();
    await second.up();
    final drag = await tester.startGesture(point);
    final dragSecond = await tester.startGesture(
      point + const Offset(30, 0),
      pointer: 2,
    );
    await drag.moveBy(const Offset(0, 120));
    await dragSecond.moveBy(const Offset(0, 120));
    await drag.up();
    await dragSecond.up();
    await tester.pumpAndSettle();
    expect(position.pixels, lessThan(before));
    expect(output, isEmpty);
  });

  testWidgets('scrolling keycaps cancels repeats and Ctrl never repeats', (
    tester,
  ) async {
    await mount(tester);
    final hold = await tester.startGesture(tester.getCenter(find.text('/')));
    await hold.moveBy(const Offset(-100, 0));
    await tester.pump(const Duration(seconds: 1));
    await hold.up();
    expect(output, isEmpty);
    final ctrl = await tester.startGesture(tester.getCenter(find.text('Ctrl')));
    await tester.pump(const Duration(seconds: 1));
    await ctrl.up();
    await tester.pump();
    expect(input.ctrl, isTrue);
    expect(output, isEmpty);
  });

  testWidgets('mouse tracking taps emit one click and no arrows', (
    tester,
  ) async {
    await mount(tester);
    terminal.write('\x1b[?1000h\x1b[?1006h');
    await tester.tap(find.byType(TerminalView));
    expect(output.join(), contains('M'));
    expect(output.join(), contains('m'));
    expect(output.join(), isNot(contains('\x1b[D')));
  });
}
