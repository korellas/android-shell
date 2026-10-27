/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 */
import 'dart:ui' as ui;
import 'dart:io';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:android_shell_ui/tilde_controls.dart';
import 'package:android_shell_ui/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('TILDE_LABEL_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('/private/tmp/tilde-label-audit')
      ..createSync(recursive: true);
    const stage = String.fromEnvironment(
      'TILDE_LABEL_CAPTURE_STAGE',
      defaultValue: 'after',
    );
    File(
      '${directory.path}/$stage-$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await font.load();
    await (FontLoader('JetBrainsMono')
          ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('host validation preserves input corners at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UiEngineFixture()
        ..state = {
          'defaults': {
            'host': {'protocol': 'ssh', 'port': 22},
          },
        };
      final boundary = GlobalKey();
      final theme = tildeTheme(Brightness.dark, engine);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: RecordEditor(engine: engine, kind: RecordKind.host),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField).first;
      final decorator = find.descendant(
        of: field,
        matching: find.byType(InputDecorator),
      );
      final origin =
          tester.getTopLeft(decorator) -
          tester.getTopLeft(find.byKey(boundary));
      final width = tester.getSize(decorator).width;
      Future<Color> corner() async => (await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final x = (origin.dx + width - 3).floor();
        final y = (origin.dy + 2).floor();
        final offset = (y * image.width + x) * 4;
        final color = Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
        image.dispose();
        return color;
      }))!;
      final normalCorner = await corner();
      if (scale == 2) await capture(tester, 'host-normal-360-2');
      tester.state<FormState>(find.byType(Form)).validate();
      await tester.pumpAndSettle();
      if (scale == 2) await capture(tester, 'host-error-360-2');
      expect(
        await corner(),
        normalCorner,
        reason:
            'An error should change the border color, keeping its 10dp outline.',
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final kind in [
    RecordKind.forward,
    RecordKind.profile,
    RecordKind.identity,
    RecordKind.key,
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('$kind labels fit at 360px with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final engine = UiEngineFixture()
          ..state = {
            'defaults': {
              'profile': {
                'name': '기본 터미널',
                'forceSizeColumns': 80,
                'forceSizeRows': 24,
              },
            },
          };
        await tester.pumpWidget(
          MaterialApp(
            theme: tildeTheme(Brightness.dark, engine),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RecordEditor(engine: engine, kind: kind),
          ),
        );
        await tester.pumpAndSettle();
        tester.state<FormState>(find.byType(Form)).validate();
        await tester.pumpAndSettle();
        for (final text
            in find
                .descendant(
                  of: find.byType(InputDecorator),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final render = text.findRenderObject()! as RenderParagraph;
          expect(
            render.didExceedMaxLines,
            isFalse,
            reason: render.text.toPlainText(),
          );
        }
        if (kind == RecordKind.profile && scale == 2) {
          await capture(tester, 'profile-360-2');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('save bar and stepper fit at 360px with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UiEngineFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: tildeTheme(Brightness.dark, engine),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: TildeStepper(
              title: '스크롤 기록',
              value: 100000,
              unit: '줄',
              onChanged: (_) {},
            ),
            bottomNavigationBar: TildeSaveBar(
              changes: 100,
              busy: false,
              cancel: () {},
              save: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in find.byType(RichText).evaluate()) {
        final render = text.findRenderObject()! as RenderParagraph;
        expect(
          render.didExceedMaxLines,
          isFalse,
          reason: render.text.toPlainText(),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'compact preview retains full keycaps without shrinking the bar',
    (tester) async {
      final engine = UiEngineFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: tildeTheme(Brightness.dark, engine),
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: TerminalBarPreview(
                order: const ['UP', 'FUNCTION_KEYS'],
                hidden: const {},
                height: 36,
                group: true,
                keys: const [
                  {'name': 'UP', 'label': '↑'},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cap = find
          .ancestor(of: find.text('Ctrl'), matching: find.byType(Material))
          .first;
      final render = tester.renderObject<RenderBox>(cap);
      final paintedWidth =
          render.localToGlobal(Offset(render.size.width, 0)).dx -
          render.localToGlobal(Offset.zero).dx;
      expect(paintedWidth, greaterThanOrEqualTo(44));
    },
  );
  testWidgets(
    'compact unavailable preview keeps its status text inside the card',
    (tester) async {
      final engine = UiEngineFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: tildeTheme(Brightness.dark, engine),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 80,
              height: 52,
              child: TerminalPreview(engine: engine, framed: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final status = tester.renderObject<RenderParagraph>(
        find.byType(RichText),
      );
      final boxes = status.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: status.text.toPlainText().length,
        ),
      );
      expect(
        boxes.map((box) => box.bottom).reduce((a, b) => a > b ? a : b),
        lessThanOrEqualTo(status.size.height),
      );
    },
  );
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'key and choice controls fit at 360px / $scale / $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(360, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final engine = UiEngineFixture();
          Future<void> open(Widget page) async {
            await tester.pumpWidget(
              MaterialApp(
                key: UniqueKey(),
                theme: tildeTheme(brightness, engine),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: page,
              ),
            );
            await tester.pumpAndSettle();
          }

          void check() {
            for (final element in find.byType(RichText).evaluate()) {
              final render = element.findRenderObject()! as RenderParagraph;
              expect(
                render.didExceedMaxLines,
                isFalse,
                reason: render.text.toPlainText(),
              );
            }
            expect(tester.takeException(), isNull);
          }

          await open(GenerateKeyPage(engine: engine));
          check();
          await tester.tap(find.text('RSA'));
          await tester.pumpAndSettle();
          check();
          tester.state<FormState>(find.byType(Form)).validate();
          await tester.pumpAndSettle();
          check();
          await tester.tap(find.byType(TextFormField).first);
          await tester.enterText(find.byType(TextFormField).first, '서버 로그인 키');
          await tester.pumpAndSettle();
          check();
          if (scale == 2 && brightness == Brightness.light) {
            await capture(tester, 'new-key-360-2');
          }
          await open(const Scaffold(body: KeyPasswordSheet()));
          await tester.enterText(find.byType(TextFormField).at(1), 'secret');
          tester.state<FormState>(find.byType(Form)).validate();
          await tester.pumpAndSettle();
          check();
          if (scale == 2 && brightness == Brightness.light) {
            await capture(tester, 'key-password-360-2');
          }
          await open(
            const TildeChoicePage(
              title: '문자 인코딩',
              values: [
                ('UTF-8', '유니코드 · 여러 언어와 한글을 사용하는 서버'),
                ('EUC-KR', '한국어 · EUC-KR'),
              ],
              current: 'UTF-8',
            ),
          );
          check();
          await tester.enterText(find.byType(TextField), '한국어');
          await tester.pumpAndSettle();
          expect(find.text('유니코드 · 여러 언어와 한글을 사용하는 서버'), findsNothing);
          check();
          await open(
            const Scaffold(
              body: TildeColorSheet(initial: tildeTide, title: '색상 선택'),
            ),
          );
          check();
          await tester.enterText(find.byType(TextField), 'bad');
          await tester.tap(find.text('사용'));
          await tester.pumpAndSettle();
          check();
        },
      );
    }
  }
  testWidgets('large text host details preserve complete summary values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = UiEngineFixture();
    await tester.pumpWidget(
      MaterialApp(
        theme: tildeTheme(Brightness.dark, engine),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: RecordEditor(
          engine: engine,
          kind: RecordKind.host,
          record: const {
            'id': 7,
            'nickname': 'home-nas',
            'protocol': 'ssh',
            'hostname': 'nas.example',
            'username': 'admin',
            'port': 22,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'host-summary-1280-2');
    final summary = find.text('ssh · nas.example:22');
    expect(summary, findsOneWidget);
    final richText = find.descendant(
      of: summary,
      matching: find.byType(RichText),
    );
    expect(
      tester.renderObject<RenderParagraph>(richText).didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
