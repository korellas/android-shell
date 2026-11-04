// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_shell_ui/files/file_browser.dart';
import 'package:android_shell_ui/files/transfer.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'file_browser_actions_test.dart' show BrowserEngine, BrowserFiles;
import 'package:android_shell_ui/l10n/strings.dart';

void main() {
  setUpAll(() async {
    for (final (family, asset) in [
      ('Pretendard', 'assets/fonts/Pretendard-Regular.ttf'),
      ('JetBrainsMono', 'assets/fonts/JetBrainsMono-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  for (final size in [
    const Size(390, 844),
    const Size(912, 680),
    const Size(840, 1100),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'file navigation and columns align at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final files = BrowserFiles()
          ..nodes.addAll({
            '/home': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
            '/home/folder': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
            '/home/note.txt': SftpFileAttrs(
              size: 4096,
              mode: SftpFileMode.value(0x81a4),
            ),
          });
        final engine = BrowserEngine(files);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ko'),
            theme: tildeTheme(Brightness.dark, engine),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
              ),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FileBrowserPage(
                        engine: engine,
                        host: const {'id': 1, 'nickname': 'test'},
                      ),
                    ),
                  ),
                  child: const Text('파일 전송 열기'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('파일 전송 열기'));
        await tester.pumpAndSettle();
        if (Platform.environment['TILDE_LAYOUT_SCREENSHOTS'] case final path?) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '$path/files-${size.width.toInt()}-${Theme.of(tester.element(find.byType(FileBrowserPage))).platform.name}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        final refresh = find.byTooltip('새로고침');
        expect(
          tester.getRect(find.textContaining('개 항목').last).bottom,
          lessThanOrEqualTo(size.height - 20),
        );
        final icon = find.descendant(
          of: refresh,
          matching: find.byIcon(Icons.refresh),
        );
        final color = IconTheme.of(tester.element(icon)).color;
        final scheme = Theme.of(tester.element(icon)).colorScheme;
        expect(color, scheme.onSurface);
        expect(
          tester.getRect(refresh).right,
          lessThanOrEqualTo(size.width - 24),
        );
        expect(
          tester.getRect(find.byTooltip('뒤로').last).left,
          greaterThanOrEqualTo(24),
        );
        if (size.width - 48 >= 800 ||
            Theme.of(tester.element(find.byType(FileBrowserPage))).platform ==
                TargetPlatform.windows) {
          expect(
            tester.getTopLeft(find.text('이름')).dx,
            closeTo(tester.getTopLeft(find.text('note.txt')).dx, .1),
          );
          expect(
            tester.getTopLeft(find.text('크기')).dx,
            closeTo(tester.getTopLeft(find.text(formatBytes(4096))).dx, .1),
          );
        }
        await tester.tap(find.text('folder'));
        if (Theme.of(tester.element(find.byType(FileBrowserPage))).platform ==
            TargetPlatform.windows) {
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(find.text('folder'));
        }
        await tester.pumpAndSettle();
        final back = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.icon is Icon &&
              widget.tooltip == '뒤로',
        );
        expect(tester.widget<IconButton>(back).onPressed, isNotNull);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.text('note.txt'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('파일 전송 열기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.windows,
      }),
    );
  }
}
