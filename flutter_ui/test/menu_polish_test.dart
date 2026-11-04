// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/management.dart';
import 'package:android_shell_ui/tilde_controls.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';
import 'package:android_shell_ui/l10n/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, asset) in [
      ('Pretendard', 'assets/fonts/Pretendard-Regular.ttf'),
      ('JetBrainsMono', 'assets/fonts/JetBrainsMono-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });
  late UiEngineFixture engine;
  final boundary = GlobalKey();
  setUp(() {
    engine = UiEngineFixture()
      ..state = {
        'preferences': {'defaultProfileId': 1},
        'profiles': [
          {'id': 1, 'name': '기본 프로필', 'fontSize': 14},
        ],
        'schemes': [
          {'id': -1, 'name': 'Tide Night'},
          {'id': 2, 'name': '작업용 테마'},
        ],
      };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidEngine.channel, (call) async {
      if (call.method == 'snapshot') return engine.state;
      if (call.method == 'forwards') {
        return [
          {
            'id': 1,
            'nickname': 'db 터널',
            'type': 'local',
            'sourceAddr': '127.0.0.1',
            'sourcePort': 5432,
            'destAddr': 'db-2',
            'destPort': 5432,
          },
        ];
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(AndroidEngine.channel, null),
    );
  });

  Future<void> open(WidgetTester tester, Widget page, double scale) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        theme: tildeTheme(Brightness.dark, engine),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: boundary, child: child!),
        ),
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> labels(WidgetTester tester) => tester
      .widgetList<TildeMenuLabel>(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TildeMenuLabel),
        ),
      )
      .map((w) => w.label)
      .toList();

  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['TILDE_AUDIT_SCREENSHOTS'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final scale in [1.0, 2.0]) {
    for (final builtin in [true, false]) {
      testWidgets('theme entry points agree (builtin=$builtin, scale=$scale)', (
        tester,
      ) async {
        await open(tester, SchemesPage(engine: engine), scale);
        final name = builtin ? 'Tide Night' : '작업용 테마';
        await tester.longPress(find.text(name));
        await tester.pumpAndSettle();
        final held = labels(tester);
        expect(held, containsAll(['사용', '복제', '내보내기']));
        expect(held.contains('삭제'), !builtin);
        if (!builtin) {
          expect(held.last, '삭제');
          final label = tester.widget<TildeMenuLabel>(
            find.widgetWithText(TildeMenuLabel, '삭제'),
          );
          expect(label.danger, true);
        }
        await capture(tester, 'theme-menu-$builtin-$scale');
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('$name 옵션'));
        await tester.pumpAndSettle();
        expect(labels(tester), held);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('default profile is checked and cannot be deleted ($scale)', (
      tester,
    ) async {
      await open(
        tester,
        RecordListPage(engine: engine, kind: RecordKind.profile),
        scale,
      );
      await tester.longPress(find.text('기본 프로필'));
      await tester.pumpAndSettle();
      expect(labels(tester), ['편집', '복제']);
      expect(find.text('앱 기본값'), findsNothing);
      expect(find.text('삭제'), findsNothing);
      await capture(tester, 'profile-menu-$scale');
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'forward exposes the same management menu through more ($scale)',
      (tester) async {
        await open(
          tester,
          ForwardsPage(
            engine: engine,
            host: const {'id': 1, 'nickname': 'web-01'},
          ),
          scale,
        );
        await tester.tap(find.byTooltip('db 터널 옵션'));
        await tester.pumpAndSettle();
        final more = labels(tester);
        expect(more, ['편집', '복제', '삭제']);
        await capture(tester, 'forward-menu-$scale');
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
        await tester.longPress(find.text('db 터널'));
        await tester.pumpAndSettle();
        expect(labels(tester), more);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
