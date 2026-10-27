// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/terminal/images/image_terminal.dart';
import 'package:android_shell_ui/terminal/images/inline_images.dart';

void main() {
  test(
    'terminal preserves text/image order and reserves Kitty cursor rows',
    () async {
      final terminal = InlineImageTerminal(imagePolicy: InlineImagePolicy.on);
      terminal.resize(8, 3);
      terminal.write(
        'a\x1b_Ga=T,f=32,s=1,v=1,i=1,c=2,r=2;${base64Encode([255, 0, 0, 255])}\x1b\\b',
      );
      await terminal.images.drained;
      expect(terminal.images.store.placements.single.left, 1);
      expect(terminal.buffer.cursorY, 1);
      expect(terminal.buffer.cursorX, 4);
      expect(terminal.buffer.lines[1].getCodePoint(3), 'b'.codeUnitAt(0));
      terminal.dispose();
    },
  );
  test(
    'ask retains layout without decoding and disposal stops queued writes',
    () async {
      final terminal = InlineImageTerminal();
      terminal.write(
        '\x1b_Ga=T,f=32,s=1,v=1,i=1;${base64Encode([0, 0, 0, 255])}\x1b\\',
      );
      await terminal.images.drained;
      expect(terminal.images.pendingConsent.length, 1);
      expect(terminal.images.store.budget.decodedUsage, 0);
      terminal.images.decide(terminal.images.pendingConsent.single, false);
      expect(terminal.images.store.assets, isEmpty);
      terminal.write('late');
      terminal.dispose();
      await terminal.images.drained;
      expect(terminal.images.store.budget.encodedUsage, 0);
      expect(terminal.buffer.lines[0].getText(), isNot(contains('late')));
    },
  );
  test(
    'cell metrics are xterm cell pixels and scrolling preserves image anchors',
    () async {
      final terminal = InlineImageTerminal(imagePolicy: InlineImagePolicy.on);
      terminal.resize(8, 3, 10, 20);
      terminal.write(
        '\x1b_Ga=T,f=32,s=1,v=1,i=1,c=2,r=2,C=1;${base64Encode([255, 0, 0, 255])}\x1b\\',
      );
      await terminal.images.drained;
      expect(terminal.images.store.cellWidth, 10);
      expect(terminal.images.store.cellHeight, 20);
      terminal.write('\r\n\r\n\r\n');
      await terminal.images.drained;
      expect(terminal.images.store.placements.single.top, -1);
      terminal.write('\x1b[?1049h');
      await terminal.images.drained;
      expect(terminal.images.store.slices(0), isEmpty);
      terminal.write('\x1b[?1049l');
      await terminal.images.drained;
      expect(terminal.images.store.slices(-1).single.asset.id, 1);
      terminal.dispose();
    },
  );
  test('queued terminal input has a bounded admission limit', () async {
    final terminal = InlineImageTerminal(
      imageLimits: const InlineImageLimits(
        pendingInputBytes: 1024,
        pendingInputChunks: 2,
      ),
    );
    try {
      terminal.write('a' * 400);
      expect(() => terminal.write('b' * 400), throwsStateError);
      await terminal.images.drained;
      terminal.write('ok');
      terminal.write('');
      terminal.write('again');
      expect(() => terminal.write('third'), throwsStateError);
      await terminal.images.drained;
      terminal.write('pending');
    } finally {
      terminal.dispose();
      await terminal.images.drained;
    }
  });
  test('RIS preserves a later partial image across input chunks', () async {
    const wire = '\x1bc\x1b_Ga=T,f=32,s=1,v=1,i=1;AQID/w==\x1b\\tail';
    for (final split in [1, 2, wire.indexOf(';') + 1, wire.indexOf(';') + 3]) {
      final terminal = InlineImageTerminal(imagePolicy: InlineImagePolicy.on);
      try {
        terminal.write(wire.substring(0, split));
        await terminal.images.drained;
        terminal.write(wire.substring(split));
        await terminal.images.drained;
        expect(terminal.images.store.assets.keys, [1], reason: 'split $split');
        expect(terminal.buffer.lines[0].getText(), contains('tail'));
        expect(terminal.buffer.lines[0].getText(), isNot(contains('ID/w')));
      } finally {
        terminal.dispose();
      }
    }
  });
}
