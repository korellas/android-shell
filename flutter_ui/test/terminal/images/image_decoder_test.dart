// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/terminal/images/image_decoder.dart';
import 'package:android_shell_ui/terminal/images/inline_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InlineImageStore store;
  late InlineImageProtocol protocol;
  late InlineImageDecoder decoder;
  setUp(() {
    store = InlineImageStore();
    protocol = InlineImageProtocol(budget: store.budget);
    decoder = InlineImageDecoder(store.budget);
  });
  tearDown(() {
    decoder.dispose();
    protocol.dispose();
    store.dispose();
  });
  void send(String options, [List<int>? bytes]) {
    final event = protocol
        .feed(
          '\x1b_G$options${bytes == null ? '' : ';${base64Encode(bytes)}'}\x1b\\',
        )
        .single;
    store.apply(event as InlineImageCommand);
    decoder.retain(store.assets.values.expand((a) => a.frames));
  }

  Future<List<int>> pixels(InlineImageFrame frame) async {
    decoder.imageFor(frame);
    await decoder.drained;
    final image = decoder.imageFor(frame)!;
    return (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List().toList();
  }

  test(
    'raw RGB expands off-isolate and frame graph composes actual pixels',
    () async {
      send('a=t,i=1,f=24,s=2,v=1', [255, 0, 0, 0, 255, 0]);
      expect(await pixels(store.assets[1]!.currentFrame), [
        255,
        0,
        0,
        255,
        0,
        255,
        0,
        255,
      ]);
      send('a=f,i=1,f=32,s=1,v=1,c=1,x=1', [0, 0, 255, 255]);
      expect(await pixels(store.assets[1]!.frames[1]), [
        255,
        0,
        0,
        255,
        0,
        0,
        255,
        255,
      ]);
      send('a=c,i=1,r=2,c=1,x=1,w=1,h=1,X=0,C=1');
      expect(await pixels(store.assets[1]!.frames[0]), [
        0,
        0,
        255,
        255,
        0,
        255,
        0,
        255,
      ]);
      decoder.retain(const []);
      expect(store.budget.decodedUsage, 0);
    },
  );
  test(
    'denial prevents pixels and cancelled decode returns all reservations',
    () async {
      protocol.policy = InlineImagePolicy.ask;
      send('a=t,i=1,f=32,s=1,v=1', [255, 0, 0, 255]);
      final frame = store.assets[1]!.currentFrame;
      expect(decoder.imageFor(frame), isNull);
      await decoder.drained;
      expect(store.budget.decodedUsage, 0);
      frame.source!.decide(true);
      decoder.imageFor(frame);
      decoder.retain(const []);
      store.clear();
      await decoder.drained;
      expect(store.budget.decodedUsage, 0);
      expect(store.budget.encodedUsage, 0);
    },
  );
  for (final encoded in [
    'R0lGODlhAgABAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQABQAAACwAAAAAAgABAAAIBQABAAgIACH5BAEFAAEALAAAAAACAAEAgQAA/wAAAAAAAAAAAAgFAAEACAgAOw==',
    'UklGRoQAAABXRUJQVlA4WAoAAAACAAAAAQAAAAAAQU5JTQYAAAAAAAAAAABBTk1GKAAAAAAAAAAAAAEAAAAAADIAAAJWUDhMDwAAAC8BAAAABxD9j/4HIqL/AQBBTk1GKAAAAAAAAAAAAAEAAAAAADIAAABWUDhMDwAAAC8BAAAABxDR//4HIqL/AQA=',
  ]) {
    test(
      'native animated ${encoded.startsWith('R0') ? 'GIF' : 'WebP'} decodes and advances pixels',
      () async {
        final event = protocol
            .feed('\x1b]1337;File=inline=1:$encoded\x07')
            .single;
        store.apply(event as InlineImageCommand);
        final frame = store.assets.values.single.currentFrame;
        expect(frame.source!.frameCount, 2);
        decoder.retain([frame]);
        expect((await pixels(frame)).take(4), [255, 0, 0, 255]);
        decoder.advance(100);
        decoder.advance(200);
        await decoder.drained;
        expect((await pixels(frame)).take(4), [0, 0, 255, 255]);
        decoder.retain(const []);
        expect(store.budget.decodedUsage, 0);
      },
    );
  }
  test(
    'dispose after decode begins holds leases until cancellation finishes',
    () async {
      send('a=t,i=1,f=32,s=1,v=1', [255, 0, 0, 255]);
      decoder.imageFor(store.assets[1]!.currentFrame);
      await Future<void>.delayed(Duration.zero);
      expect(store.budget.decodedUsage, greaterThan(0));
      decoder.dispose();
      store.clear();
      await decoder.drained;
      expect(store.budget.decodedUsage, 0);
      expect(store.budget.encodedUsage, 0);
    },
  );
  test(
    'encoded PNG produces pixels and malformed codec data releases leases',
    () async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADElEQVR4nGP8zwACAAYIAQFazwZIAAAAAElFTkSuQmCC',
      );
      send('a=t,i=1,f=100', png);
      expect((await pixels(store.assets[1]!.currentFrame)).take(4), [
        255,
        0,
        0,
        255,
      ]);
      send('a=t,i=2,f=100', png.sublist(0, 33));
      final invalid = store.assets[2]!.currentFrame;
      decoder.retain([invalid]);
      decoder.imageFor(invalid);
      await decoder.drained;
      expect(decoder.imageFor(invalid), isNull);
      expect(store.budget.decodedUsage, 0);
      store.clear();
      expect(store.budget.encodedUsage, 0);
    },
  );
  test(
    'Kitty straight RGBA is converted to platform premultiplied pixels',
    () async {
      send('a=t,i=1,f=32,s=1,v=1', [255, 0, 0, 128]);
      expect(await pixels(store.assets[1]!.currentFrame), [128, 0, 0, 128]);
    },
  );
}
