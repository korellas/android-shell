/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/terminal/images/inline_images.dart';

String wire(String options, [String? data]) =>
    '\x1b_G$options${data == null ? '' : ';$data'}\x1b\\';

void main() {
  late InlineImageStore store;
  late InlineImageProtocol protocol;
  late List<String> replies;
  setUp(() {
    replies = [];
    store = InlineImageStore(onReply: replies.add);
    protocol = InlineImageProtocol(budget: store.budget);
  });
  tearDown(() {
    protocol.dispose();
    store.dispose();
  });
  InlineImageResult send(
    String options, [
    String? data,
    int row = 0,
    int col = 0,
  ]) {
    final event = protocol.feed(wire(options, data)).single;
    if (event is InlineImageReply) {
      replies.add(event.text);
      return const InlineImageResult();
    }
    return store.apply(event as InlineImageCommand, row: row, col: col);
  }

  test('placements crop, replace, resolve relative origins and delete', () {
    send('a=t,i=7,f=24,s=2,v=1', '/wAAAP8A');
    send('a=p,i=7,p=1,c=4,r=2,x=1,w=9,C=1', null, 3, 4);
    expect(store.placements.single.crop.width, 1);
    send('a=p,i=7,p=2,P=7,Q=1,H=2,V=-1,C=1');
    expect(store.origins(store.placements.last), [(2, 6)]);
    send('a=p,i=7,p=1,c=2,r=1', null, 8, 9);
    expect(store.placements.length, 2);
    expect(store.origins(store.placements.first), [(7, 11)]);
    send('a=d,d=i,i=7,p=1');
    expect(store.placements.single.id, 2);
    expect(store.assets, contains(7));
    send('a=d,d=I,i=7');
    expect(store.assets, isEmpty);
    expect(store.budget.encodedUsage, 0);
  });

  test(
    'image numbers resolve the most recent upload and IDs are allocated',
    () {
      send('a=t,I=3,f=24,s=1,v=1', '/wAA');
      final first = store.assets.values.single.id;
      send('a=t,I=3,f=24,s=1,v=1', 'AP8A');
      expect(store.assets.length, 2);
      send('a=p,I=3');
      expect(store.placements.single.asset.id, isNot(first));
      expect(replies.last, contains('I=3;OK'));
    },
  );

  test('frame graph supports upload, composition, animation and deletion', () {
    send('a=t,i=5,f=24,s=2,v=1', '/wAAAP8A');
    send('a=f,i=5,f=24,s=1,v=1,x=1,z=20', 'AAD/');
    final asset = store.assets[5]!;
    expect(asset.frames.length, 2);
    expect(asset.frames.last.foreground!.source!.bytesForDecode(), [0, 0, 255]);
    expect(asset.gaps, [0, 20]);
    send('a=c,i=5,r=1,c=2,w=1,h=1,X=1,C=1');
    expect(asset.frames.last.sourceRect!.width, 1);
    expect(asset.frames.last.replace, isTrue);
    send('a=a,i=5,s=3,c=1');
    store.advanceAnimations(100);
    expect(asset.frameIndex, 1);
    send('a=d,d=f,i=5,r=2');
    expect(asset.frames.length, 1);
    expect(asset.frameIndex, 0);
  });

  test('overlapping frame composition is rejected without replacing frame', () {
    send('a=t,i=5,f=24,s=2,v=1', '/wAAAP8A');
    final frame = store.assets[5]!.frames.single;
    send('a=c,i=5,r=1,c=1,w=1,h=1');
    expect(store.assets[5]!.frames.single, same(frame));
    expect(replies.last, contains('EINVAL:overlapping'));
  });

  test('only direct transport and supported raw formats are accepted', () {
    for (final options in ['t=f', 't=s', 'f=16', 'o=x']) {
      send('a=t,i=8,$options', '/wAA');
      expect(replies.last, contains('ENOTSUP:'));
      expect(store.assets, isEmpty);
      expect(store.budget.encodedUsage, 0);
    }
  });

  test('zlib raw payload validates expanded length before storage', () {
    send(
      'a=t,i=8,f=32,s=1,v=1,o=z',
      base64Encode(zlib.encode([255, 0, 0, 255])),
    );
    expect(store.assets[8]!.frames.single.source!.bytesForDecode(), [
      255,
      0,
      0,
      255,
    ]);
    send('a=t,i=9,f=32,s=1,v=1,o=z', base64Encode(zlib.encode([0, 1, 2])));
    expect(replies.last, contains('EINVAL:short pixel'));
    expect(store.assets, isNot(contains(9)));
    send(
      'a=t,i=9,f=32,s=1,v=1,o=z',
      base64Encode(zlib.encode(List.filled(4096, 0))),
    );
    expect(replies.last, contains('EINVAL:excess pixel data'));
  });

  test('decoded leases include temporary data and release explicitly', () {
    send('a=t,i=8,f=24,s=1,v=1', '/wAA');
    final source = store.assets[8]!.frames.single.source!;
    final lease = source.openDecode();
    final pixels = store.budget.reserveDecoded(4);
    expect(store.budget.decodedUsage, 7);
    lease.dispose();
    pixels.dispose();
    pixels.dispose();
    expect(store.budget.decodedUsage, 0);
  });

  test('pending query consent reservations are cancelled on store clear', () {
    protocol.policy = InlineImagePolicy.ask;
    final command =
        protocol.feed(wire('a=q,i=2,f=24,s=1,v=1', '/wAA')).single
            as InlineImageCommand;
    store.apply(command);
    expect(store.budget.encodedUsage, greaterThan(0));
    store.clear();
    expect(store.budget.encodedUsage, 0);
    command.source!.decide(true);
    expect(replies, isEmpty);
  });

  test('pending frame and delete obey consent command ordering', () {
    send('a=t,i=1,f=24,s=1,v=1', '/wAA');
    protocol.policy = InlineImagePolicy.ask;
    final frame =
        protocol.feed(wire('a=f,i=1,f=24,s=1,v=1', 'AP8A')).single
            as InlineImageCommand;
    store.apply(frame);
    send('a=d,d=I,i=1');
    expect(store.assets, contains(1));
    expect(replies.length, 1);
    frame.source!.decide(false);
    expect(store.assets, isEmpty);
    expect(replies[1], contains('EPERM:'));
    expect(replies[2], contains('OK'));
    expect(store.budget.encodedUsage, 0);
  });

  test(
    'protocol table preserves canonical first, last and invalid mark indices',
    () {
      expect(KittyPlaceholder.index(0x0305), 0);
      expect(KittyPlaceholder.index(0x1d244), greaterThan(255));
      expect(KittyPlaceholder.index(0x0300), -1);
    },
  );

  test('iTerm cell coverage erases, scrolls and keeps source offsets', () {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8/x8AAwMCAO+aSAAAAABJRU5ErkJggg==';
    final command =
        protocol
                .feed(
                  '\x1b]1337;File=inline=1;width=4;height=2;preserveAspectRatio=0:$png\x07',
                )
                .single
            as InlineImageCommand;
    store.apply(command, row: 2, col: 3);
    expect(store.assets.length, 1);
    expect(store.slices(2).single.left, 3);
    store.edit(const InlineImageRect(4, 2, 6, 3));
    expect(store.slices(2).map((s) => (s.left, s.right)).toList(), [
      (3, 4),
      (6, 7),
    ]);
    store.scroll(const InlineImageRect(4, 2, 7, 5), 0, 1);
    expect(
      store.slices(2).map((s) => (s.left, s.right)).toList(),
      contains((5, 6)),
    );
    final fragment = store.placements.last;
    expect(fragment.sourceCol, greaterThan(0));
    store.clearScreen();
    expect(store.assets, isEmpty);
    expect(store.budget.encodedUsage, 0);
  });

  test(
    'visible images prevent eviction but unplaced uploads can be evicted',
    () {
      protocol.dispose();
      store.dispose();
      store = InlineImageStore(
        limits: const InlineImageLimits(encodedBytes: 4096),
        onReply: replies.add,
      );
      protocol = InlineImageProtocol(budget: store.budget);
      send('a=t,i=1,f=24,s=1,v=1', '/wAA');
      send('a=t,i=2,f=24,s=1,v=1', 'AP8A');
      expect(store.assets.keys.toList(), [2]);
      send('a=p,i=2');
      send('a=t,i=3,f=24,s=1,v=1', 'AAD/');
      expect(replies.last, contains('ENOSPC:'));
      expect(store.assets.keys.toList(), [2]);
      expect(store.budget.encodedUsage, 4096);
    },
  );

  test('aborting a compressor does not evict existing unplaced assets', () {
    protocol.dispose();
    store.dispose();
    store = InlineImageStore(
      limits: const InlineImageLimits(encodedBytes: 4096),
      onReply: replies.add,
    );
    protocol = InlineImageProtocol(budget: store.budget);
    send('a=t,i=1,f=24,s=1,v=1', '/wAA');
    protocol.feed('\x1b_Ga=t,i=2,f=24,s=1,v=1;/wAA').toList();
    protocol.reset();
    expect(store.assets.keys.toList(), [1]);
    expect(store.budget.encodedUsage, 4096);
  });

  test('pending consent requests obey native placement bound', () {
    protocol.dispose();
    store.dispose();
    store = InlineImageStore(
      limits: const InlineImageLimits(maxPlacements: 1),
      onReply: replies.add,
    );
    protocol = InlineImageProtocol(
      budget: store.budget,
      policy: InlineImagePolicy.ask,
    );
    send('a=q,i=1,f=24,s=1,v=1', '/wAA');
    send('a=q,i=2,f=24,s=1,v=1', 'AP8A');
    expect(replies.single, contains('ENOSPC:too many pending image requests'));
    store.clear();
    expect(store.budget.encodedUsage, 0);
  });

  test('wire IDs are decimal and invalid IDs do not allocate images', () {
    for (final value in ['0x10', ' 1', '-1', '4294967296']) {
      send('a=t,i=$value,f=24,s=1,v=1', '/wAA');
      expect(replies.last, contains('EINVAL:invalid i'));
      expect(store.assets, isEmpty);
      expect(store.budget.encodedUsage, 0);
    }
  });

  test('iTerm accepts GIF while Kitty f=100 requires PNG', () {
    const gif = 'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
    final command =
        protocol.feed('\x1b]1337;File=inline=1:$gif\x1b\\').single
            as InlineImageCommand;
    expect(command.source!.mime, 'image/gif');
    expect(command.source!.frameCount, 1);
    store.apply(command);
    send('a=t,i=3,f=100', gif);
    expect(replies.last, contains('Kitty f=100 requires PNG'));
    expect(store.assets.length, 1);
  });
}
