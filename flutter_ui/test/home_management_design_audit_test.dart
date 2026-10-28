/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy at http://www.apache.org/licenses/LICENSE-2.0
 */
import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/management.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

const host = {
  'id': 1,
  'nickname': 'home-nas',
  'hostname': 'nas.example',
  'username': 'admin',
  'port': 22,
  'protocol': 'ssh',
};
const scheme = {
  'id': 1,
  'name': '개인 터미널 테마',
  'foregroundColor': 0xffeae9e7,
  'backgroundColor': 0xff13110f,
  'cursorColor': 0xff6fd8c4,
};
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
  setUp(() {
    engine = UiEngineFixture(fontFamily: 'JetBrainsMono')
      ..state = {
        'ready': true,
        'hosts': [host],
        'sessions': [
          {'id': 7, 'hostId': 1, 'open': true},
        ],
        'profiles': [
          {'id': 1, 'name': '작업용 터미널', 'fontSize': 14, 'colorSchemeId': 1},
        ],
        'identities': [
          {'id': 1, 'name': '공용 관리자 계정', 'username': 'administrator'},
        ],
        'keys': [
          {
            'id': 1,
            'nickname': '업무용 서버 인증 키',
            'type': 'ED25519',
            'encrypted': true,
            'loaded': false,
          },
        ],
        'knownHosts': [
          {
            'id': 1,
            'hostId': 1,
            'hostname': 'nas.example',
            'port': 22,
            'algorithm': 'ssh-ed25519',
            'fingerprint': 'SHA256:abcdefghijklmnopqrstuvwxyz0123456789ABCDE',
          },
        ],
        'generation': {'biometricAvailable': true},
        'schemes': [scheme],
        'preferences': {
          'defaultProfileId': 1,
          'enterKey': 13,
          'keyModifiers': {'Ctrl': 1, 'Alt': 2},
        },
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'forwards') {
            return [
              {
                'id': 1,
                'nickname': '작업용 웹 서버',
                'type': 'local',
                'sourceAddr': '127.0.0.1',
                'sourcePort': 8080,
                'destAddr': '127.0.0.1',
                'destPort': 80,
              },
            ];
          }
          if (call.method == 'scheme.palette') {
            return {...scheme, 'colors': List.filled(16, 0xff312f2b)};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidEngine.channel, null),
    );
  });
  final boundary = GlobalKey();
  Future<void> open(
    WidgetTester tester,
    Widget page,
    double width,
    double scale,
  ) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tildeTheme(Brightness.dark, engine),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('HOME_MANAGEMENT_SCREENSHOTS')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('/private/tmp/home-management-audit')
        ..createSync(recursive: true);
      File(
        '${directory.path}/$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final (width, scale) in [
    (360.0, 1.0),
    (360.0, 1.5),
    (360.0, 2.0),
    (900.0, 1.0),
    (1280.0, 2.0),
  ]) {
    for (final name in [
      'home',
      'keys',
      'profiles',
      'accounts',
      'known-hosts',
      'themes',
      'palette',
      'forwards',
    ]) {
      testWidgets('$name fits ${width.toInt()} at $scale text', (tester) async {
        final page = switch (name) {
          'home' => ShellHome(engine: engine),
          'keys' => KeyPage(engine: engine),
          'profiles' => RecordListPage(
            engine: engine,
            kind: RecordKind.profile,
          ),
          'accounts' => RecordListPage(
            engine: engine,
            kind: RecordKind.identity,
          ),
          'known-hosts' => KnownHostsPage(engine: engine),
          'themes' => SchemesPage(engine: engine),
          'palette' => PalettePage(engine: engine, scheme: scheme),
          'forwards' => ForwardsPage(engine: engine, host: host),
          _ => throw StateError(name),
        };
        await open(tester, page, width, scale);
        await capture(tester, '$name-${width.toInt()}-$scale');
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('host menu actions fit narrow text $scale', (tester) async {
      await open(tester, ShellHome(engine: engine), 360, scale);
      await tester.tap(find.byTooltip('home-nas 메뉴'));
      await tester.pumpAndSettle();
      await capture(tester, 'host-menu-360-$scale');
      expect(tester.takeException(), isNull);
      expect(find.text('저장된 서버 키 삭제'), findsNothing);
      for (final label in ['새 세션', '편집', '즐겨찾기', '연결 끊기', '삭제']) {
        for (final element
            in find
                .descendant(
                  of: find.text(label),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final paragraph = element.findRenderObject()! as RenderParagraph;
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          if (scale == 2 && ['새 세션', '편집', '즐겨찾기'].contains(label)) {
            expect(
              paragraph
                  .getBoxesForSelection(
                    TextSelection(baseOffset: 0, extentOffset: label.length),
                  )
                  .map((box) => box.top)
                  .toSet(),
              hasLength(1),
              reason: label,
            );
          }
        }
      }
    });
  }
  for (final width in [360.0, 900.0]) {
    testWidgets('empty home has usable add and quick connect at $width', (
      tester,
    ) async {
      engine.state['hosts'] = [];
      await open(tester, ShellHome(engine: engine), width, 2);
      await capture(tester, 'home-empty-${width.toInt()}-2.0');
      expect(find.text('호스트 추가'), findsOneWidget);
      expect(find.byTooltip('빠른 연결'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('key create sheet fits at $width and large text', (
      tester,
    ) async {
      await open(tester, KeyPage(engine: engine), width, 2);
      await tester.tap(find.text('새 키'));
      await tester.pumpAndSettle();
      await capture(tester, 'key-create-${width.toInt()}-2.0');
      expect(find.byType(GenerateKeyPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('account edit sheet fits at $width and large text', (
      tester,
    ) async {
      await open(
        tester,
        RecordListPage(engine: engine, kind: RecordKind.identity),
        width,
        2,
      );
      await tester.tap(find.text('administrator'));
      await tester.pumpAndSettle();
      await capture(tester, 'account-edit-${width.toInt()}-2.0');
      expect(find.byType(RecordEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('key edit fits at $width and large text', (tester) async {
      await open(tester, KeyPage(engine: engine), width, 2);
      await tester.tap(find.text('업무용 서버 인증 키'));
      await tester.pumpAndSettle();
      await capture(tester, 'key-edit-${width.toInt()}-2.0');
      expect(find.byType(RecordEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('wide home selected detail retains list and editor', (
    tester,
  ) async {
    await open(tester, ShellHome(engine: engine), 1280, 2);
    await tester.tap(find.text('home-nas'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await capture(tester, 'home-detail-1280-2.0');
    expect(find.byType(RecordEditor), findsOneWidget);
    expect(find.byTooltip('home-nas 메뉴'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
