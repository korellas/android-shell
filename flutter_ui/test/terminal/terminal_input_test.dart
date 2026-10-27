// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';
import 'package:android_shell_ui/terminal/terminal_input.dart';
import 'package:android_shell_ui/terminal/app_terminal_session.dart';
import 'package:android_shell_ui/terminal/terminal_input_view.dart';

void main() {
  late Terminal terminal;
  late List<String> output;
  late TerminalInputController input;
  late TerminalController controller;
  final viewKey = GlobalKey<TerminalViewState>();

  Widget view({bool enabled = true, bool softKeyboard = true}) => MaterialApp(
    home: Scaffold(
      body: TerminalInputView(
        terminal: terminal,
        controller: controller,
        input: input,
        terminalViewKey: viewKey,
        keyboardEnabled: enabled,
        showSoftKeyboard: softKeyboard,
      ),
    ),
  );

  Future<void> open(WidgetTester tester, {bool softKeyboard = true}) async {
    output = [];
    terminal = Terminal(onOutput: output.add);
    input = TerminalInputController(terminal: terminal);
    controller = TerminalController();
    addTearDown(input.dispose);
    addTearDown(controller.dispose);
    await tester.pumpWidget(view(softKeyboard: softKeyboard));
    await tester.pump();
    await tester.tap(find.byType(TerminalView));
    await tester.pump();
  }

  void edit(WidgetTester tester, String text, {int? composingStart}) {
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

  testWidgets('committed prefix is sent while the next syllable composes', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    expect(output, isEmpty);
    edit(tester, '한ㄱ', composingStart: 1);
    expect(output.join(), '한');
    edit(tester, '한글', composingStart: 1);
    edit(tester, '한글 ');
    expect(output.join(), '한글 ');
  });

  testWidgets('emoji and combining prefixes preserve UTF16 offsets', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '😀e\u0301한', composingStart: 4);
    expect(output.join(), '😀e\u0301');
    edit(tester, '😀e\u0301한');
    expect(output.join(), '😀e\u0301한');
  });

  testWidgets('canceling preedit preserves the committed prefix', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한글', composingStart: 1);
    edit(tester, '한그', composingStart: 1);
    edit(tester, '한');
    expect(output.join(), '한');
  });

  testWidgets('recomposition replaces the committed syllable exactly once', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한ㄱ', composingStart: 1);
    expect(output.join(), '한');
    edit(tester, '하', composingStart: 0);
    expect(output.join(), '한\x7f');
    edit(tester, '하');
    expect(output.join(), '한\x7f하');
  });

  testWidgets('preedit is visible without sending bytes', (tester) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    await tester.pump();
    expect(output, isEmpty);
    expect(find.text('한'), findsOneWidget);
    edit(tester, '');
    await tester.pump();
    expect(find.text('한'), findsNothing);
    expect(output, isEmpty);
    expect(viewKey.currentState!.renderTerminal.hasSize, isTrue);
  });

  testWidgets('canceling an entire IME buffer preserves remote prefix', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한ㄱ', composingStart: 1);
    edit(tester, '');
    expect(output.join(), '한');
    edit(tester, ' ');
    expect(output.join(), '한 ');
  });

  testWidgets('soft backspace deletes at an otherwise empty prompt', (
    tester,
  ) async {
    await open(tester);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    expect(output.join(), '\x7f');
  });

  testWidgets('special key, text and bracketed paste follow composition', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    input.sendKey(TerminalKey.tab);
    expect(output.join(), '한\t');
    edit(tester, '글', composingStart: 0);
    input.sendText('!');
    expect(output.join(), '한\t글!');
    terminal.write('\x1b[?2004h');
    edit(tester, '가', composingStart: 0);
    input.paste('one\ntwo');
    expect(output.join(), '한\t글!가\x1b[200~one\ntwo\x1b[201~');
  });

  testWidgets('IME action commits before Enter', (tester) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    expect(output.join(), '한\r');
  });

  testWidgets('sticky Ctrl applies canonical chords to IME text', (
    tester,
  ) async {
    await open(tester);
    input.setModifiers(ctrl: true);
    edit(tester, 'c');
    edit(tester, 'C');
    edit(tester, '[');
    expect(output.join(), '\x03\x03\x1b');
    input.setModifiers();
    edit(tester, 'c');
    expect(output.join(), '\x03\x03\x1bc');
  });

  testWidgets('sticky Alt preserves IME casing through upstream encoding', (
    tester,
  ) async {
    await open(tester);
    input.setModifiers(alt: true);
    edit(tester, 'x');
    edit(tester, 'X');
    expect(output.join(), '\x1bx\x1bX');
    terminal.write('\x1b[?2004h');
    input.paste('raw');
    expect(output.join(), '\x1bx\x1bX\x1b[200~raw\x1b[201~');
  });

  testWidgets('sticky IME chords honor the negotiated Kitty protocol', (
    tester,
  ) async {
    await open(tester);
    terminal.write('\x1b[>1u');
    input.setModifiers(ctrl: true);
    edit(tester, 'c');
    expect(output.join(), '\x1b[99;5u');
  });

  testWidgets('changing sticky modifiers commits preedit with old modifiers', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    input.setModifiers(ctrl: true);
    edit(tester, 'c');
    expect(output.join(), '한\x03');
  });

  testWidgets('sticky Shift is passed to special key encoding', (tester) async {
    await open(tester);
    input.setModifiers(shift: true);
    input.sendKey(TerminalKey.tab);
    expect(output.join(), '\x1b[Z');
  });

  testWidgets('preedit follows the public terminal cursor coordinates', (
    tester,
  ) async {
    await open(tester);
    terminal.write('hello\r\n  ');
    edit(tester, '한', composingStart: 0);
    await tester.pump();
    await tester.pump();
    final cursor = viewKey.currentState!.globalCursorRect;
    expect(tester.getTopLeft(find.text('한')).dx, closeTo(cursor.left, 1));
    expect(tester.getTopLeft(find.text('한')).dy, closeTo(cursor.top, 1));
  });

  testWidgets('hardware Tab commits preedit before upstream key translation', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(output.join(), '한\t');
  });

  testWidgets('hardware Ctrl, Alt and arrows retain terminal encoding', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(output, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX, character: 'x');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(output.join(), '한\x03\x1b[A\x1bx');
  });

  testWidgets('hardware text is left to the active IME exactly once', (
    tester,
  ) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    expect(output, isEmpty);
    edit(tester, 'a');
    expect(output.join(), 'a');
  });

  testWidgets('hardware printable keys without characters keep preedit local', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(output, isEmpty);
    edit(tester, '한');
    expect(output.join(), '한');
  });

  testWidgets('clearing an entire local composition never sends backspace', (
    tester,
  ) async {
    await open(tester);
    input.sendText('remote');
    edit(tester, '한', composingStart: 0);
    tester.testTextInput.updateEditingValue(TextEditingValue.empty);
    expect(output.join(), 'remote');
  });

  testWidgets('hardware text works with soft keyboard disabled', (
    tester,
  ) async {
    await open(tester, softKeyboard: false);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    expect(output.join(), 'a');
  });

  testWidgets('closing and reopening never replay committed composition', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한ㄱ', composingStart: 1);
    input.closeKeyboard();
    expect(output.join(), '한ㄱ');
    input.requestKeyboard();
    input.finishComposition();
    expect(output.join(), '한ㄱ');
    edit(tester, '글');
    expect(output.join(), '한ㄱ글');
  });

  testWidgets('callbacks from a finished composition client are ignored', (
    tester,
  ) async {
    await open(tester);
    final oldId =
        (tester.testTextInput.log
                .lastWhere((call) => call.method == 'TextInput.setClient')
                .arguments
            as List<dynamic>)[0];
    edit(tester, '한', composingStart: 0);
    input.sendKey(TerminalKey.tab);
    await tester.pump();
    final newId =
        (tester.testTextInput.log
                .lastWhere((call) => call.method == 'TextInput.setClient')
                .arguments
            as List<dynamic>)[0];
    expect(newId, isNot(oldId));
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.updateEditingState', [
          oldId,
          const TextEditingValue(
            text: '  한',
            selection: TextSelection.collapsed(offset: 3),
          ).toJSON(),
        ]),
      ),
      (_) {},
    );
    expect(output.join(), '한\t');
    edit(tester, '글');
    expect(output.join(), '한\t글');
  });

  testWidgets('platform keyboard close commits preedit once before reopening', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한ㄱ', composingStart: 1);
    tester.testTextInput.closeConnection();
    expect(output.join(), '한ㄱ');
    input.requestKeyboard();
    input.finishComposition();
    expect(output.join(), '한ㄱ');
    edit(tester, '글');
    expect(output.join(), '한ㄱ글');
  });

  testWidgets('disabled input rejects IME, buttons and hardware keys', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    await tester.pumpWidget(view(enabled: false));
    await tester.pump();
    input.sendKey(TerminalKey.enter);
    input.sendText('bad');
    input.paste('bad');
    input.finishComposition();
    input.setModifiers(ctrl: true, alt: true, shift: true);
    input.updateEditingValue(const TextEditingValue(text: '  bad'));
    input.requestKeyboard();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    expect(output, isEmpty);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    await tester.pumpWidget(view());
    await tester.pump();
    edit(tester, 'ok');
    expect(output.join(), 'ok');
  });

  testWidgets('disposing drops local preedit and rejects later input', (
    tester,
  ) async {
    await open(tester);
    edit(tester, '한', composingStart: 0);
    input.dispose();
    input.finishComposition();
    input.sendText('bad');
    input.paste('bad');
    input.sendKey(TerminalKey.enter);
    input.requestKeyboard();
    expect(output, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Backspace profile applies to IME, hardware and modified keys', (
    tester,
  ) async {
    await open(tester);
    TerminalSessionOperations.configureInput(terminal, 'backspace');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    expect(output.join(), '\b');
    output.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    input.sendKey(TerminalKey.backspace, ctrl: true);
    expect(output.join(), '\b\x7f\x1b\b\b');
  });

  testWidgets(
    'Backspace profile preserves negotiated keyboard key identities',
    (tester) async {
      await open(tester);
      final reference = Terminal();
      for (final sequence in ['\x1b[>1u', '\x1b[>8u', '\x1b[>4;2m']) {
        terminal.write('\x1bc$sequence');
        reference.write('\x1bc$sequence');
        TerminalSessionOperations.configureInput(terminal, 'backspace');
        final expected = <String>[];
        reference.onOutput = expected.add;
        output.clear();
        for (final key in [TerminalKey.backspace, TerminalKey.delete]) {
          reference.keyInput(key, ctrl: true, alt: true);
          input.sendKey(key, ctrl: true, alt: true);
        }
        reference.keyInput(TerminalKey.keyC, ctrl: true);
        input.sendKey(TerminalKey.keyC, ctrl: true);
        expect(output, expected);
      }
    },
  );
}
