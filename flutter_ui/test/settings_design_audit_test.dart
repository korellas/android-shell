/* Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0 */
import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/settings.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AndroidEngine engine;
  late List<MethodCall> calls;
  final boundary = GlobalKey();
  const categories = ['화면', '키보드', '제스처', '터미널', '연결·알림', '보안·백업'];
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final (family, files) in [
      (
        'Pretendard',
        [
          'Pretendard-Regular.ttf',
          'Pretendard-Medium.ttf',
          'Pretendard-SemiBold.ttf',
          'Pretendard-Bold.ttf',
        ],
      ),
      ('JetBrainsMono', ['JetBrainsMono-Regular.ttf']),
    ]) {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });
  setUp(() {
    calls = [];
    engine = UiEngineFixture(fontFamily: 'JetBrainsMono')
      ..state = {
        'ready': true,
        'hardwareKeyboard': true,
        'koreanKeyboard': true,
        'appVersion': 'audit',
        'profiles': [
          {'id': 1, 'name': '기본 터미널', 'colorSchemeId': -1, 'fontSize': 14},
        ],
        'schemes': [
          {
            'id': -1,
            'name': 'Tilde Night',
            'foregroundColor': 0xffeae9e7,
            'backgroundColor': 0xff13110f,
            'cursorColor': 0xff6fd8c4,
          },
        ],
        'preferences': {
          'themeMode': 'SYSTEM',
          'fontFamily': 'JETBRAINS_MONO',
          'fonts': [
            {'value': 'JETBRAINS_MONO', 'label': 'JetBrains Mono'},
            {'value': 'local:한글폰트.ttf', 'label': '사용자 글꼴'},
          ],
          'defaultProfileId': 1,
          'scrollback': '1234',
          'terminalMargin': 7,
          'terminalBarOrder': [
            'ALT',
            'UP',
            'DOWN',
            'LEFT',
            'RIGHT',
            'HOME',
            'END',
            'PAGE_UP',
            'PAGE_DOWN',
            'INSERT',
            'DELETE',
            'FUNCTION_KEYS',
          ],
          'terminalBarHidden': ['INSERT', 'DELETE'],
          'terminalBarHeight': 36,
          'terminalBarHeights': [32, 36, 44],
          'terminalBarFn': true,
          'terminalBarDefaults': {
            'height': 36,
            'order': ['ALT', 'UP', 'DOWN', 'LEFT', 'RIGHT', 'FUNCTION_KEYS'],
            'hidden': <String>[],
            'groupFunctionKeys': true,
          },
          'barKeys': [
            for (final (id, label) in [
              ('ALT', 'Alt'),
              ('UP', '↑'),
              ('DOWN', '↓'),
              ('LEFT', '←'),
              ('RIGHT', '→'),
              ('HOME', 'Home'),
              ('END', 'End'),
              ('PAGE_UP', 'PgUp'),
              ('PAGE_DOWN', 'PgDn'),
              ('INSERT', 'Ins'),
              ('DELETE', 'Del'),
              ('FUNCTION_KEYS', 'Fn'),
            ])
              {'name': id, 'label': label},
          ],
          'swipeTmux': true,
          'bell': true,
          'bellVibrate': true,
          'bellVolume': .75,
          'connectionAlerts': false,
          'notificationsAvailable': false,
          'canAuthenticate': false,
          'customTerminalTypes': ['screen-256color'],
        },
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'logs') return 'SSH 연결 시작\nTerminal ready';
          if (call.method == 'help.document') {
            return '한글 도움말\nCtrl과 Alt 키를 사용할 수 있어요.';
          }
          return null;
        });
  });
  tearDown(() {
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(
    WidgetTester tester,
    String page,
    double width,
    double scale,
    Brightness brightness,
  ) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: tildeTheme(brightness, engine),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: SettingsPage(engine: engine),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> select(String name) async {
      final target = width >= 720 && categories.contains(name)
          ? find.widgetWithText(ListTile, name)
          : find.text(name);
      if (target.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          target,
          240,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    if (page == '도움말' || page == '진단 로그') {
      await select('도움말 및 로그');
      if (page == '진단 로그') await select('진단 로그');
    } else if (categories.contains(page)) {
      await select(page);
    } else if (page == '폰트 관리') {
      await select('화면');
      await select('글꼴');
    } else if (page == '하드웨어 키보드' || page == '특수키 바') {
      await select('키보드');
      await select(page);
    }
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('SETTINGS_AUDIT_SCREENSHOTS')) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(
        '/private/tmp/tilde-settings-audit',
      ).createSync(recursive: true);
      File(
        '/private/tmp/tilde-settings-audit/$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'large text preserves display labels and the selected scheme name',
    (tester) async {
      await open(tester, '화면', 320, 2, Brightness.light);
      final label = tester.renderObject<RenderParagraph>(find.text('앱 테마'));
      expect(label.size.height, lessThan(45));
      final scheme = tester.renderObject<RenderParagraph>(
        find.text('Tilde Night'),
      );
      expect(scheme.didExceedMaxLines, isFalse);
    },
  );
  testWidgets('large text preserves the diagnostic page title', (tester) async {
    await open(tester, '진단 로그', 320, 2, Brightness.light);
    final title = tester.renderObject<RenderParagraph>(find.text('진단 로그'));
    expect(title.didExceedMaxLines, isFalse);
  });
  for (final (page, parent) in [
    ('폰트 관리', '화면'),
    ('하드웨어 키보드', '키보드'),
    ('특수키 바', '키보드'),
  ]) {
    testWidgets('$page keeps its parent category selected on wide screens', (
      tester,
    ) async {
      await open(tester, page, 840, 1, Brightness.light);
      final category = tester.widget<ListTile>(
        find.widgetWithText(ListTile, parent).first,
      );
      expect(category.selected, isTrue);
    });
  }
  testWidgets('vertical gesture setting has one heading', (tester) async {
    await open(tester, '제스처', 840, 1, Brightness.light);
    expect(find.text('위아래로 밀면'), findsOneWidget);
  });
  for (final width in [320.0, 720.0, 840.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final page in [
        '설정',
        ...categories,
        '폰트 관리',
        '하드웨어 키보드',
        '특수키 바',
        '도움말',
        '진단 로그',
      ]) {
        testWidgets('$page fits $width at text scale $scale', (tester) async {
          await open(
            tester,
            page,
            width,
            scale,
            width == 320 || width == 840 ? Brightness.light : Brightness.dark,
          );
          expect(tester.takeException(), isNull);
          await capture(tester, '$page-${width.toInt()}-$scale-top');
          final lists = find.byType(ListView);
          if (lists.evaluate().isNotEmpty) {
            for (var i = 0; i < 5; i++) {
              await tester.drag(lists.last, const Offset(0, -600));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          await capture(tester, '$page-${width.toInt()}-$scale-bottom');
          expect(
            calls.where(
              (c) =>
                  c.method == 'settings.update' ||
                  c.method == 'settings.bellMode',
            ),
            isEmpty,
          );
        });
      }
    }
  }
}
