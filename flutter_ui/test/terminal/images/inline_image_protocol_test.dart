/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/terminal/images/inline_images.dart';
import 'package:xterm2/xterm.dart';

String kitty(String header, [String payload = '']) =>
    '\x1b_G$header;$payload\x1b\\';

void main() {
  test('image framing preserves text and non-image escapes at every split', () {
    final wire = 'before\x1b[31m${kitty('a=T,f=24,s=1,v=1,i=9', '/wAA')}after';
    for (var split = 0; split <= wire.length; split++) {
      final protocol = InlineImageProtocol();
      final events = [
        ...protocol.feed(wire.substring(0, split)),
        ...protocol.feed(wire.substring(split)),
      ];
      expect(
        events.whereType<InlineImageText>().map((e) => e.text).join(),
        'before\x1b[31mafter',
        reason: 'split $split',
      );
      final command = events.whereType<InlineImageCommand>().single;
      expect(command.options['i'], '9');
      expect(command.source!.bytesForDecode(), [255, 0, 0]);
      command.dispose();
      protocol.dispose();
    }
  });

  test('RIS cancels uploads preceding it at the protocol boundary', () {
    final protocol = InlineImageProtocol();
    final wire =
        '${kitty('a=t,f=32,s=1,v=1,i=1,m=1', 'AQI=')}\x1bc${kitty('', 'A/8=')}';
    final events = protocol.feed(wire).toList();
    expect(events.whereType<InlineImageCommand>(), isEmpty);
    expect(protocol.budget.encodedUsage, 0);
    protocol.dispose();
  });

  test('chunk continuation defaults the last chunk to m=0', () {
    final protocol = InlineImageProtocol();
    expect(
      protocol.feed(kitty('a=T,f=32,s=1,v=1,i=3,m=1', '/wA=')).toList(),
      isEmpty,
    );
    final command = protocol
        .feed(kitty('', 'AP8='))
        .whereType<InlineImageCommand>()
        .single;
    expect(command.source!.bytesForDecode(), [255, 0, 0, 255]);
    command.dispose();
  });

  test(
    'off consumes image payload but passes unrelated OSC without buffering',
    () {
      final protocol = InlineImageProtocol(policy: InlineImagePolicy.off);
      final events = protocol
          .feed('a${kitty('f=24,s=1,v=1', '/wAA')}\x1b]0;title\x07b')
          .toList();
      expect(events.whereType<InlineImageCommand>(), isEmpty);
      expect(
        events.whereType<InlineImageText>().map((e) => e.text).join(),
        'a\x1b]0;title\x07b',
      );
    },
  );

  test(
    'malformed payload rejects with quiet semantics and releases uploads',
    () {
      final protocol = InlineImageProtocol();
      final error = protocol
          .feed(kitty('i=4,f=24,s=1,v=1', '!!!!'))
          .whereType<InlineImageReply>()
          .single;
      expect(error.text, contains('i=4;EINVAL:'));
      expect(protocol.budget.encodedUsage, 0);
      expect(protocol.feed(kitty('i=4,q=2', '!')).toList(), isEmpty);
      expect(
        protocol.feed('ok').whereType<InlineImageText>().single.text,
        'ok',
      );
    },
  );

  test('ask reserves placement before approval and refuses pixel access', () {
    final replies = <String>[];
    final store = InlineImageStore(onReply: replies.add);
    final protocol = InlineImageProtocol(
      budget: store.budget,
      policy: InlineImagePolicy.ask,
    );
    final command = protocol
        .feed(kitty('a=T,i=1,f=24,s=1,v=1', '/wAA'))
        .whereType<InlineImageCommand>()
        .single;
    final result = store.apply(command, row: 2, col: 3);
    expect(result.rows, 1);
    expect(store.placements.single.top, 2);
    expect(() => command.source!.bytesForDecode(), throwsStateError);
    expect(replies, isEmpty);
    command.source!.decide(false);
    expect(store.assets, isEmpty);
    expect(replies.single, contains('EPERM:'));
    expect(store.budget.encodedUsage, 0);
  });

  test('query does not retain an asset and q=1 suppresses success only', () {
    final replies = <String>[];
    final store = InlineImageStore(onReply: replies.add);
    final protocol = InlineImageProtocol(budget: store.budget);
    final command = protocol
        .feed(kitty('a=q,i=8,f=24,s=1,v=1,q=1', '/wAA'))
        .whereType<InlineImageCommand>()
        .single;
    store.apply(command);
    expect(store.assets, isEmpty);
    expect(replies, isEmpty);
    expect(store.budget.encodedUsage, 0);
  });

  test('iTerm multipart combines arbitrary base64 splits', () {
    final protocol = InlineImageProtocol();
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8/x8AAwMCAO+aSAAAAABJRU5ErkJggg==',
    );
    final encoded = base64Encode(png);
    final wire =
        '\x1b]1337;MultipartFile=inline=1;width=2\x07'
        '\x1b]1337;FilePart=${encoded.substring(0, 7)}\x07'
        '\x1b]1337;FilePart=${encoded.substring(7)}\x07'
        '\x1b]1337;FileEnd\x07';
    final events = <InlineImageEvent>[];
    for (final code in wire.codeUnits) {
      events.addAll(protocol.feed(String.fromCharCode(code)));
    }
    final command = events.whereType<InlineImageCommand>().single;
    expect(command.source!.width, 1);
    expect(command.source!.bytesForDecode(), png);
    command.dispose();
  });

  test('non-image OSC and APC round-trip without nested interpretation', () {
    final values = [
      '\x1b]1337;Other=thing\x1b\\',
      '\x1b]1337;File=inline=1\x07',
      '\x1b]1337;FileEndSuffix\x1b\\',
      '\x1b]0;ordinary title\x07',
      '\x1b_not-graphics\x07text\x1b\\',
    ];
    for (final value in values) {
      for (var split = 0; split <= value.length; split++) {
        final protocol = InlineImageProtocol();
        final events = [
          ...protocol.feed(value.substring(0, split)),
          ...protocol.feed(value.substring(split)),
        ];
        expect(events.whereType<InlineImageCommand>(), isEmpty);
        expect(
          events.whereType<InlineImageText>().map((e) => e.text).join(),
          value,
        );
        protocol.dispose();
      }
    }
  });

  test('capabilities reflects policy and preserves C1 terminators', () {
    final protocol = InlineImageProtocol(policy: InlineImagePolicy.off);
    expect(
      (protocol.feed('\x1b]1337;Capabilities\x9c').single as InlineImageReply)
          .text,
      '\x1b]1337;Capabilities=\x1b\\',
    );
    protocol.policy = InlineImagePolicy.on;
    expect(
      (protocol.feed('\x1b]1337;Capabilities\x07').single as InlineImageReply)
          .text,
      '\x1b]1337;Capabilities=F\x1b\\',
    );
  });

  test('reset releases partial transfers and resumes ordinary text', () {
    final protocol = InlineImageProtocol();
    protocol.feed(kitty('a=t,f=24,s=1,v=1,m=1', '/wAA')).toList();
    expect(protocol.budget.encodedUsage, greaterThan(0));
    protocol.reset();
    expect(protocol.budget.encodedUsage, 0);
    expect((protocol.feed('after').single as InlineImageText).text, 'after');
    protocol.dispose();
  });

  test('oversized headers and payloads reject then recover', () {
    final protocol = InlineImageProtocol(
      limits: const InlineImageLimits(uploadBytes: 8),
    );
    final tooLarge =
        protocol
                .feed(kitty('a=t,i=1,f=100', base64Encode(List.filled(9, 0))))
                .single
            as InlineImageReply;
    expect(tooLarge.text, contains('E2BIG:'));
    expect(protocol.budget.encodedUsage, 0);
    final header =
        protocol.feed(kitty('i=${'1' * 4096}', '')).single as InlineImageReply;
    expect(header.text, contains('E2BIG:'));
    expect((protocol.feed('ok').single as InlineImageText).text, 'ok');
  });

  test('invalid base64 padding and tail bits reject at every chunk split', () {
    for (final payload in ['A', '/x==', '/wA==', '/w=A', '/wAA=', '/wA=AA']) {
      final value = kitty('i=1,f=24,s=1,v=1', payload);
      for (var split = 0; split <= value.length; split++) {
        final protocol = InlineImageProtocol();
        final events = [
          ...protocol.feed(value.substring(0, split)),
          ...protocol.feed(value.substring(split)),
        ];
        expect(
          events.whereType<InlineImageCommand>(),
          isEmpty,
          reason: payload,
        );
        expect(events.whereType<InlineImageReply>().length, 1, reason: payload);
        expect(protocol.budget.encodedUsage, 0);
        protocol.dispose();
      }
    }
  });

  test('CAN and SUB cancel partial images and release upload state', () {
    for (final cancel in ['\x18', '\x1a']) {
      final value = '\x1b_Ga=t,i=1,f=24,s=1,v=1;/wAA${cancel}after';
      for (var split = 0; split <= value.length; split++) {
        final protocol = InlineImageProtocol();
        final events = [
          ...protocol.feed(value.substring(0, split)),
          ...protocol.feed(value.substring(split)),
        ];
        expect(events.whereType<InlineImageCommand>(), isEmpty);
        expect(events.whereType<InlineImageReply>(), isEmpty);
        expect(
          events.whereType<InlineImageText>().map((e) => e.text).join(),
          'after',
        );
        expect(protocol.budget.encodedUsage, 0);
      }
    }
  });

  test('C1 image introducers and terminators are recognized at every split', () {
    final values = [
      '\x9fGa=t,i=1,f=24,s=1,v=1;/wAA\x9c',
      '\x9d1337;File=inline=1:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8/x8AAwMCAO+aSAAAAABJRU5ErkJggg==\x9c',
    ];
    for (final value in values) {
      for (var split = 0; split <= value.length; split++) {
        final protocol = InlineImageProtocol();
        final events = [
          ...protocol.feed(value.substring(0, split)),
          ...protocol.feed(value.substring(split)),
        ];
        final command = events.whereType<InlineImageCommand>().single;
        expect(command.source!.width, 1);
        command.dispose();
      }
    }
  });

  test(
    'interrupted passthrough strings cannot swallow text after an image',
    () {
      for (final start in [
        '\x1bP',
        '\x1bX',
        '\x1b^',
        '\x1b_not-G',
        '\x1b]0;',
        '\x90',
        '\x98',
        '\x9e',
      ]) {
        for (final image in [
          kitty('a=t,f=24,s=1,v=1', '/wAA'),
          '\x9fGa=t,f=24,s=1,v=1;/wAA\x9c',
        ]) {
          final value = '${start}ignored${image}after';
          for (var split = 0; split <= value.length; split++) {
            final protocol = InlineImageProtocol();
            final terminal = Terminal();
            final events = [
              ...protocol.feed(value.substring(0, split)),
              ...protocol.feed(value.substring(split)),
            ];
            for (final event in events) {
              if (event is InlineImageText) terminal.write(event.text);
              if (event is InlineImageCommand) event.dispose();
            }
            expect(events.whereType<InlineImageCommand>().length, 1);
            expect(
              terminal.buffer.getText(),
              contains('after'),
              reason: 'start $start split $split',
            );
          }
        }
      }
    },
  );

  test(
    'an ESC sequence cancels an image and is reparsed as ordinary terminal input',
    () {
      final protocol = InlineImageProtocol();
      final events = protocol
          .feed('\x1b_Ga=t,f=24,s=1,v=1;/wAA\x1b[31mafter')
          .toList();
      expect(events.whereType<InlineImageCommand>(), isEmpty);
      expect(events.whereType<InlineImageReply>(), isEmpty);
      expect(
        events.whereType<InlineImageText>().map((e) => e.text).join(),
        '\x1b[31mafter',
      );
      expect(protocol.budget.encodedUsage, 0);
    },
  );

  test('unsupported graphics action rejects and releases transfer memory', () {
    final protocol = InlineImageProtocol();
    final events = protocol
        .feed(kitty('a=unsupported,i=1,f=24,s=1,v=1', '/wAA'))
        .toList();
    expect(
      events.whereType<InlineImageReply>().single.text,
      contains('ENOTSUP:'),
    );
    expect(protocol.budget.encodedUsage, 0);
  });
}
