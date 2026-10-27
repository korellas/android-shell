// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';
import 'package:android_shell_ui/terminal/images/image_terminal.dart';
import 'package:android_shell_ui/terminal/images/inline_images.dart';

const redPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADElEQVR4nGP8zwACAAYIAQFazwZIAAAAAElFTkSuQmCC';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iTerm overwrite and erase preserve uncovered image cell ranges',
    () async {
      final t = InlineImageTerminal(imagePolicy: InlineImagePolicy.on)
        ..resize(8, 4, 10, 10);
      t.write(
        '\x1b]1337;File=inline=1;width=4;height=2;preserveAspectRatio=0:$redPng\x07',
      );
      await t.images.drained;
      t.write('\x1b[1;2HX');
      await t.images.drained;
      expect(t.images.store.slices(0).map((s) => (s.left, s.right)), [
        (0, 1),
        (2, 4),
      ]);
      expect(t.images.store.slices(1).map((s) => (s.left, s.right)), [(0, 4)]);
      t.write('\x1b[1;3H\x1b[K');
      await t.images.drained;
      expect(t.images.store.slices(0).map((s) => (s.left, s.right)), [(0, 1)]);
      t.dispose();
    },
  );

  test(
    'paint hook clips cropped image and draws each z pass in native order',
    () async {
      final t = InlineImageTerminal(imagePolicy: InlineImagePolicy.on)
        ..resize(4, 3, 10, 10);
      t.write(
        '\x1b_Ga=T,f=32,s=2,v=1,i=1,c=2,r=1,C=1,z=-2;${base64Encode([255, 0, 0, 255, 0, 0, 255, 255])}\x1b\\',
      );
      await t.images.drained;
      final controller = TerminalController();
      Future<ui.Image> render() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)
          ..drawColor(const ui.Color(0xff000000), ui.BlendMode.src);
        // ignore: invalid_use_of_internal_member
        final context = TerminalPaintContext(
          canvas: canvas,
          viewport: const ui.Rect.fromLTWH(0, 0, 40, 30),
          firstRow: 0,
          endRow: 3,
          cellSize: const ui.Size(10, 10),
          terminal: t,
          controller: controller,
          paintOffset: ui.Offset.zero,
          bufferOffset: ui.Offset.zero,
        );
        final extension = t.images.paintExtension;
        extension.beforeCellBackgrounds!(context);
        extension.beforeCellForegrounds!(context);
        extension.afterCellForegrounds!(context);
        final picture = recorder.endRecording();
        try {
          return await picture.toImage(40, 30);
        } finally {
          picture.dispose();
        }
      }

      final initial = await render();
      initial.dispose();
      await t.images.drained;
      final image = await render();
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      List<int> pixel(int x, int y) =>
          bytes.sublist((y * 40 + x) * 4, (y * 40 + x) * 4 + 4);
      expect(pixel(2, 5), [255, 0, 0, 255]);
      expect(pixel(17, 5), [0, 0, 255, 255]);
      expect(pixel(22, 5), [0, 0, 0, 255]);
      expect(pixel(2, 15), [0, 0, 0, 255]);
      image.dispose();
      t.dispose();
      controller.dispose();
      await t.images.drained;
      expect(t.images.store.budget.decodedUsage, 0);
    },
  );

  test(
    'Kitty placeholders use glyph, inherited marks, foreground and underline IDs',
    () async {
      final t = InlineImageTerminal(imagePolicy: InlineImagePolicy.on)
        ..resize(8, 3, 10, 10);
      t.write(
        '\x1b_Ga=T,f=32,s=1,v=1,i=1,p=2,c=2,r=1,U=1;${base64Encode([255, 0, 0, 255])}\x1b\\',
      );
      t.write(
        '\x1b[38;2;0;0;1m\x1b[58;2;0;0;2m${String.fromCharCode(KittyPlaceholder.codePoint)}\u0305\u0305${String.fromCharCode(KittyPlaceholder.codePoint)}',
      );
      await t.images.drained;
      expect(t.images.store.placeholderAnchors[(1, 2)], {(0, 0)});
      expect(
        t.images.paintExtension.cellForegroundFilter!(t.buffer.lines[0], 0),
        isFalse,
      );
      t.dispose();
    },
  );
  test('iTerm anchors split covered image cells during text reflow', () async {
    final t = InlineImageTerminal(imagePolicy: InlineImagePolicy.on)
      ..resize(8, 4, 10, 10);
    t.write(
      'abcd\x1b]1337;File=inline=1;width=4;height=1;preserveAspectRatio=0:$redPng\x07',
    );
    await t.images.drained;
    t.resize(4, 4, 10, 10);
    expect(
      t.images.store
          .slices(1 - t.buffer.scrollBack)
          .map((s) => (s.left, s.right, s.sourceRow, s.sourceCol)),
      [(0, 4, 0, 0)],
    );
    t.dispose();
  });
  test('selective and ISO protected erases preserve image cell coverage', () async {
    final t = InlineImageTerminal(imagePolicy: InlineImagePolicy.on)
      ..resize(8, 4, 10, 10);
    t.setProtectedMode(true);
    t.write(
      '\x1b]1337;File=inline=1;width=4;height=1;preserveAspectRatio=0:$redPng\x07',
    );
    await t.images.drained;
    t.setProtectedMode(false);
    t.write('\x1b[1;1H\x1b[?2K');
    await t.images.drained;
    expect(t.images.store.slices(0).single.right, 4);
    t.write('\x1b[2K');
    await t.images.drained;
    expect(t.images.store.slices(0), isEmpty);
    t.setIsoProtectedMode(true);
    t.write(
      '\x1b]1337;File=inline=1;width=4;height=1;preserveAspectRatio=0:$redPng\x07',
    );
    await t.images.drained;
    t.setIsoProtectedMode(false);
    t.write('\x1b[1;1H\x1b[2K');
    await t.images.drained;
    expect(t.images.store.slices(0).single.right, 4);
    t.dispose();
  });
}
