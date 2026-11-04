// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_shell_ui/console.dart' show consoleTerminalTheme;
import 'package:android_shell_ui/terminal/terminal_actions.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';
import '../ui_engine_fixture.dart';
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

  for (final (width, scale) in [(340.0, 1.0), (480.0, 1.2), (340.0, 2.0)]) {
    testWidgets('selection matches reference at $width and text scale $scale', (
      tester,
    ) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final engine = UiEngineFixture();
        final terminal = Terminal();
        final controller = TerminalController();
        final view = GlobalKey<TerminalViewState>();
        final boundary = GlobalKey();
        addTearDown(controller.dispose);
        addTearDown(terminal.dispose);
        final theme = tildeTheme(Brightness.dark, engine);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ko'),
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: Scaffold(
              body: TerminalActions(
                terminal: terminal,
                controller: controller,
                terminalViewKey: view,
                onEdit: (_) async {},
                onPaste: (_) {},
                onShare: (_) {},
                child: TerminalView(
                  terminal,
                  key: view,
                  controller: controller,
                  readOnly: true,
                  hardwareKeyboardOnly: true,
                  theme: consoleTerminalTheme(const {}),
                  textStyle: const TerminalStyle(
                    fontFamily: tildeMono,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
        terminal.write(List.filled(8, 'tmp_uizip  ready\r\n').join());
        await tester.pumpAndSettle();
        final first = (terminal.viewWidth * .4).floor();
        final last = (terminal.viewWidth * .65).floor();
        controller.setSelection(
          terminal.buffer.createAnchor(first, 6),
          terminal.buffer.createAnchor(last, 6),
        );
        await tester.pumpAndSettle();
        final toolbar = find.byKey(const ValueKey('terminal-selection-menu'));
        final more = find.byTooltip('선택 메뉴 더보기');
        final closed = tester.getRect(toolbar);
        expect(closed.right - tester.getRect(more).right, closeTo(4, .01));
        if (scale <= 1.2) {
          expect(closed.height, 44);
          expect(tester.getSize(more), const Size(36, 36));
          final caret = view.currentState!.renderTerminal;
          final bottom = caret
              .localToGlobal(caret.getOffset(CellOffset(last, 7)))
              .dy;
          expect(closed.top - bottom, closeTo(18, .01));
        }
        Future<void> capture(String state) async {
          final directory = Platform.environment['TILDE_AUDIT_SCREENSHOTS'];
          if (directory == null) return;
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('$directory/selection-$width-$scale-$state.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('toolbar');
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(tester.getRect(toolbar), closed);
        final button = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.more_vert),
        );
        final shape =
            button.style!.shape!.resolve({})! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(8));
        final popup = find.byWidgetPredicate(
          (w) =>
              w is Material &&
              w.shape is RoundedRectangleBorder &&
              w.color == theme.colorScheme.surfaceContainerHighest,
        );
        final popupRect = tester.getRect(popup);
        expect(popupRect.width, 212);
        expect(popupRect.right, closeTo(closed.right, .01));
        expect(popupRect.top - closed.bottom, closeTo(6, .01));
        if (scale == 1) expect(popupRect.height, 258);
        expect(find.text('공유'), findsOneWidget);
        await capture('popup');
        expect(tester.takeException(), isNull);
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }
}
