// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:xterm2/xterm.dart';
import 'images/image_terminal.dart';
import 'terminal_input.dart';
import '../ssh/automation.dart';

typedef TerminalPlatformCall =
    Future<Object?> Function(String method, Map<String, Object?> arguments);

abstract interface class AppTerminalSession {
  int get id;
  Map<String, dynamic> get prepared;
  Map<String, dynamic> get host;
  Map<String, dynamic> get profile;
  Map<String, dynamic> get record;
  InlineImageTerminal get terminal;
  TerminalController get controller;
  TerminalInputController get input;
  double get fontSize;
  bool get sessionOpen;
  bool get connecting;
  bool get ended;
  List<Map<String, dynamic>> get prompts;
  Future<void> connect();
  Future<void> disconnect();
  Future<void> dispose();
  Future<Object?> invoke(String method, Map<String, dynamic> args);
}

class TerminalSessionOperations {
  static void configureInput(Terminal terminal, String? delKey) {
    terminal.inputHandler = delKey == 'backspace'
        ? const _ProfileBackspaceInputHandler()
        : defaultInputHandler;
  }

  static List<SshAutomationStep> automationSteps(
    List<Map<String, dynamic>> actions,
  ) => [
    for (final action in actions)
      SshAutomationStep(
        type: switch (action['type']) {
          'WAIT_FOR_TEXT' => SshAutomationType.waitForText,
          'SEND_TEXT' => SshAutomationType.sendText,
          'SEND_KEY' => SshAutomationType.sendKey,
          'DELAY' => SshAutomationType.delay,
          'DISCONNECT' => SshAutomationType.disconnect,
          'ENABLE_FORWARD' => SshAutomationType.enableForward,
          'DISABLE_FORWARD' => SshAutomationType.disableForward,
          _ => throw UnsupportedError('Unsupported automation action'),
        },
        text: action['text'] as String? ?? '',
        regex: action['regex'] == true,
        duration: Duration(milliseconds: action['durationMs'] as int? ?? 30000),
        key: action['key'] as int? ?? 2,
        modifiers: action['modifiers'] as int? ?? 0,
        forwardId: action['forwardId'] as int?,
        continueOnFailure: action['failurePolicy'] == 'CONTINUE',
      ),
  ];
  static TerminalKey key(int key) {
    return key >= 257 && key <= 280
        ? TerminalKey.values[TerminalKey.f1.index + key - 257]
        : switch (key) {
            1 => TerminalKey.enter,
            2 => TerminalKey.tab,
            3 => TerminalKey.backspace,
            4 => TerminalKey.escape,
            5 => TerminalKey.arrowUp,
            6 => TerminalKey.arrowDown,
            7 => TerminalKey.arrowLeft,
            8 => TerminalKey.arrowRight,
            9 => TerminalKey.insert,
            10 => TerminalKey.delete,
            11 => TerminalKey.home,
            12 => TerminalKey.end,
            13 => TerminalKey.pageUp,
            14 => TerminalKey.pageDown,
            _ => throw UnsupportedError('Unsupported terminal key: $key'),
          };
  }

  // Same bounded URL syntax as TerminalLine.URL_REGEX and trimDetectedUrl.
  static final _urls = RegExp(
    r'(?:https?://|ftp://)[^\s<>"{}|\\^`\[\]]+'
    r'|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+'
    r'(?:com|org|net|edu|gov|io|dev|co|uk|de|fr|jp|ru|br|au|us|info|biz|me|tv)'
    r'(?![a-zA-Z0-9-]|\.[a-zA-Z0-9])(?::\d{1,5})?'
    r'(?:/[^\s<>"{}|\\^`\[\]]*)?'
    r'|(?:\d{1,3}\.){3}\d{1,3}:\d{1,5}(?:/[^\s<>"{}|\\^`\[\]]*)?',
  );
  static List<String> scanUrls(InlineImageTerminal terminal) {
    final buffer = terminal.buffer;
    final text = buffer.getText(
      BufferRangeLine(
        CellOffset(0, buffer.scrollBack),
        CellOffset(terminal.viewWidth, buffer.height - 1),
      ),
    );
    return _urls
        .allMatches(text)
        .map((match) {
          var url = match.group(0)!;
          while (url.isNotEmpty) {
            final last = url[url.length - 1];
            final unbalanced =
                (last == ')' &&
                    '('.allMatches(url).length < ')'.allMatches(url).length) ||
                (last == ']' &&
                    '['.allMatches(url).length < ']'.allMatches(url).length);
            if (!'.,;:!'.contains(last) && !unbalanced) break;
            url = url.substring(0, url.length - 1);
          }
          return url;
        })
        .toSet()
        .toList();
  }
}

class _ProfileBackspaceInputHandler implements TerminalInputHandler {
  const _ProfileBackspaceInputHandler();
  @override
  String? call(TerminalKeyboardEvent event) {
    if (event.key != TerminalKey.backspace && event.key != TerminalKey.delete) {
      return defaultInputHandler.call(event);
    }
    // Negotiated protocols also encode functional keys through the keytab.
    if (event.state.kittyKeyboardMode != 0 ||
        event.state.modifyOtherKeysMode != 0) {
      return defaultInputHandler.call(event);
    }
    if (event.key == TerminalKey.delete) {
      return defaultInputHandler.call(
        event.copyWith(key: TerminalKey.backspace),
      );
    }
    final legacy = defaultInputHandler.call(event);
    return switch (legacy) {
      '\x7f' || '\b' => '\b',
      '\x1b\x7f' || '\x1b\b' => '\x1b\b',
      _ => legacy,
    };
  }
}
