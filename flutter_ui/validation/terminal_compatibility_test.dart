// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'package:android_shell_ui/terminal/terminal_input.dart';
import 'package:android_shell_ui/terminal/terminal_input_view.dart';

void main() {
  late Terminal terminal;
  late List<String> output;
  late TerminalInputController adapter;

  Future<void> open(WidgetTester tester) async {
    output = [];
    terminal = Terminal(onOutput: output.add);
    adapter = TerminalInputController(terminal: terminal);
    final controller = TerminalController();
    addTearDown(adapter.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalInputView(
            terminal: terminal,
            controller: controller,
            input: adapter,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TerminalView));
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);
  }

  void input(WidgetTester tester, String text, {int? composingStart}) {
    final value = '  $text';
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: composingStart == null
            ? TextRange.empty
            : TextRange(start: composingStart + 2, end: value.length),
      ),
    );
  }

  testWidgets('composition is local until a syllable is committed', (
    tester,
  ) async {
    await open(tester);
    input(tester, 'ㅎ', composingStart: 0);
    input(tester, '하', composingStart: 0);
    input(tester, '한', composingStart: 0);
    expect(output, isEmpty);
    input(tester, '한');
    expect(output.join(), '한');
  });

  testWidgets('committed Hangul reaches the server before the next syllable', (
    tester,
  ) async {
    await open(tester);
    input(tester, '한', composingStart: 0);
    input(tester, '한ㄱ', composingStart: 1);
    expect(output.join(), '한');
    input(tester, '한글', composingStart: 1);
    input(tester, '한글 ');
    expect(output.join(), '한글 ');
  });

  testWidgets('an emoji prefix uses UTF16 composition offsets', (tester) async {
    await open(tester);
    input(tester, '😀한', composingStart: 2);
    expect(output.join(), '😀');
    input(tester, '😀한');
    expect(output.join(), '😀한');
  });

  testWidgets('canceling preedit does not delete remote text', (tester) async {
    await open(tester);
    input(tester, '한', composingStart: 0);
    input(tester, '하', composingStart: 0);
    input(tester, '', composingStart: null);
    expect(output.join(), isEmpty);
  });

  testWidgets('hardware control and arrow keys preserve terminal bytes', (
    tester,
  ) async {
    await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(output.join(), '\x03\x1b[A');
  });

  testWidgets('paste honors bracketed paste mode', (tester) async {
    await open(tester);
    terminal.write('\x1b[?2004h');
    adapter.paste('한글\nsecond line');
    expect(output.join(), '\x1b[200~한글\nsecond line\x1b[201~');
  });

  testWidgets('a special key must follow the committed composition', (
    tester,
  ) async {
    await open(tester);
    input(tester, '한', composingStart: 0);
    adapter.sendKey(TerminalKey.tab);
    expect(output.join(), '한\t');
  });
}
