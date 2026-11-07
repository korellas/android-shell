// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:android_shell_ui/terminal/terminal_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

void main() {
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
