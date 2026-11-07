// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:android_shell_ui/terminal/terminal_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

void main() {
  for (final text in [
    'example.com',
    'www.example.com/docs?q=1#section',
    'dev.example.com:8443/path',
  ]) {
    test('opens bare domain $text with HTTPS', () {
      final terminal = Terminal()..resize(20, 8);
      terminal.write('($text).');
      expect(
        terminalWebLinkAt(terminal, const CellOffset(4, 0)),
        'https://$text',
      );
    });
  }
  test('does not extract domains from email or non-web URLs', () {
    for (final text in ['user@example.com', 'ssh://example.com', 'ordinary']) {
      final terminal = Terminal()..resize(80, 8);
      terminal.write(text);
      for (var x = 0; x < text.length; x++) {
        expect(terminalWebLinkAt(terminal, CellOffset(x, 0)), isNull);
      }
    }
  });

  test(
    'detects wrapped URL after wide text, preserving query and brackets',
    () {
      final terminal = Terminal()..resize(20, 8);
      terminal.write('한글 https://example.test/a(b)?q=1&v=2.');
      expect(
        terminalWebLinkAt(terminal, const CellOffset(2, 1)),
        'https://example.test/a(b)?q=1&v=2',
      );
      expect(terminalWebLinkAt(terminal, const CellOffset(0, 0)), isNull);
    },
  );
  test('does not join hard newlines or open non-web OSC links', () {
    final terminal = Terminal()..resize(60, 8);
    terminal.write('https://example.test\r\nother text');
    expect(
      terminalWebLinkAt(terminal, const CellOffset(3, 0)),
      'https://example.test',
    );
    expect(terminalWebLinkAt(terminal, const CellOffset(3, 1)), isNull);
    terminal.write(
      '\r\n\x1b]8;;file:///tmp/test\x07https://example.test\x1b]8;;\x07',
    );
    expect(terminalWebLinkAt(terminal, const CellOffset(3, 2)), isNull);
  });
  test('requires a host and excludes surrounding punctuation', () {
    final terminal = Terminal()..resize(80, 8);
    terminal.write('(https://example.test/path). https://');
    expect(
      terminalWebLinkAt(terminal, const CellOffset(5, 0)),
      'https://example.test/path',
    );
    expect(terminalWebLinkAt(terminal, const CellOffset(26, 0)), isNull);
    expect(terminalWebLinkAt(terminal, const CellOffset(31, 0)), isNull);
  });
}
