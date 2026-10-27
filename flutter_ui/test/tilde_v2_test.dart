/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 */
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/settings.dart';
import 'package:android_shell_ui/settings_widgets.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';

import 'ui_engine_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AndroidEngine engine;
  late List<MethodCall> calls;
  final boundary = GlobalKey();
  const host = {
    'id': 7,
    'nickname': 'home-nas',
    'hostname': 'nas.example',
    'username': 'admin',
    'port': 22,
    'protocol': 'ssh',
    'color': '#6FD8C4',
    'connectionState': 'CONNECTED',
  };
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final (family, assets) in [
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
      for (final asset in assets) {
        loader.addFont(rootBundle.load('assets/fonts/$asset'));
      }
      await loader.load();
    }
  });
  setUp(() {
    calls = [];
    engine = UiEngineFixture(fontFamily: 'JetBrainsMono')
      ..state = {
        'ready': true,
        'hosts': [
          host,
          {
            ...host,
            'id': 8,
            'nickname': 'dev-box',
            'hostname': '10.0.4.21',
            'color': '#EBC37A',
            'connectionState': 'UNKNOWN',
          },
          {
            ...host,
            'id': 9,
            'nickname': 'production',
            'hostname': 'prod.example',
            'color': '#FF8577',
            'favorite': true,
            'connectionState': 'UNKNOWN',
          },
        ],
        'sessions': [
          {
            'id': 101,
            'hostId': 7,
            'nickname': 'home-nas',
            'open': true,
            'columns': 80,
            'rows': 24,
            'foregroundColor': 0xffeae9e7,
            'backgroundColor': 0xff13110f,
            'cursorColor': 0xff6fd8c4,
          },
        ],
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
          'themeMode': 'DARK',
          'fontFamily': 'JETBRAINS_MONO',
          'fonts': [
            {'value': 'JETBRAINS_MONO', 'label': 'JetBrains Mono'},
          ],
          'defaultProfileId': 1,
          'terminalBarOrder': [
            'ALT',
            'UP',
            'DOWN',
            'LEFT',
            'RIGHT',
            'HOME',
            'FUNCTION_KEYS',
          ],
          'terminalBarHidden': <String>[],
          'terminalBarHeight': 36,
          'terminalBarHeights': [32, 36, 44],
          'terminalBarFn': true,
          'barKeys': [
            for (final (key, label) in [
              ('ALT', 'Alt'),
              ('UP', '↑'),
              ('DOWN', '↓'),
              ('LEFT', '←'),
              ('RIGHT', '→'),
              ('HOME', 'Home'),
              ('FUNCTION_KEYS', 'Fn'),
            ])
              {'name': key, 'label': label},
          ],
          'swipeSessions': true,
          'swipeTmux': false,
        },
      };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => call.method == 'create'
          ? 0
          : call.method == 'resize'
          ? call.arguments
          : null,
    );
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': 'paste probe'} : null,
    );
    messenger.setMockMethodCallHandler(AndroidEngine.channel, (call) async {
      calls.add(call);
      if (call.method == 'snapshot') return engine.state;
      if (call.method == 'host.favorite') {
        engine.state['hosts'] = [
          for (final h in engine.list('hosts'))
            if (h['id'] == call.arguments['id'])
              {...h, 'favorite': true}
            else
              h,
        ];
      }
      if (call.method == 'settings.update') {
        final p = engine.state['preferences'] as Map;
        if (call.arguments['key'] == 'terminalBar') {
          final v = call.arguments['value'] as Map;
          p['terminalBarOrder'] = v['order'];
          p['terminalBarHidden'] = v['hidden'];
          p['terminalBarHeight'] = v['height'];
          p['terminalBarFn'] = v['groupFunctionKeys'];
        } else {
          p[call.arguments['key']] = call.arguments['value'];
        }
      }
      return null;
    });
  });
  tearDown(() {
    engine.dispose();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidEngine.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> open(
    WidgetTester tester,
    Widget page, {
    double width = 390,
    double scale = 1,
    Brightness brightness = Brightness.dark,
  }) async {
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
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
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
    if (!const bool.fromEnvironment('TILDE_V2_SCREENSHOTS')) return;
    await tester.pump();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '../docs/design/screenshots/v2-$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('custom terminal colors keep mix rules and v2 line strength', () {
    final custom = tildeTheme(
      Brightness.dark,
      engine,
      terminalScheme: {
        'backgroundColor': 0xff112233,
        'foregroundColor': 0xffddeeff,
        'cursorColor': 0xffabcdef,
      },
    );
    expect(custom.colorScheme.surface, const Color(0xff112233));
    expect(custom.colorScheme.primary, const Color(0xffabcdef));
    expect(
      custom.colorScheme.surfaceContainerHigh,
      Color.lerp(const Color(0xff112233), const Color(0xffddeeff), .08),
    );
    expect(
      custom.colorScheme.outlineVariant,
      Color.lerp(const Color(0xff112233), const Color(0xffddeeff), .19),
    );
  });
  testWidgets('canonical Day label and connected status use Tide', (
    tester,
  ) async {
    await open(
      tester,
      const Scaffold(body: TildeHostTile(host: host, size: 56)),
      brightness: Brightness.light,
    );
    final textColor = tester.widget<Text>(find.text('hn')).style!.color!;
    final theme = tildeTheme(Brightness.light, engine);
    expect(textColor, theme.colorScheme.primary);
    final ratio =
        (theme.colorScheme.primaryContainer.computeLuminance() + .05) /
        (textColor.computeLuminance() + .05);
    expect(ratio, greaterThanOrEqualTo(4.5));
    final status = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .singleWhere((d) => d.shape == BoxShape.circle);
    expect(status.color, theme.colorScheme.primary);
  });
  testWidgets('phone home keeps quick connect below flat host rows', (
    tester,
  ) async {
    await open(tester, ShellHome(engine: engine), brightness: Brightness.light);
    expect(find.byType(Card), findsNothing);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('home-nas'),
                  matching: find.byType(ListTile),
                )
                .first,
          )
          .height,
      80,
    );
    expect(tester.getTopLeft(find.byType(TextField)).dy, greaterThan(700));
    expect(find.text('세션 1'), findsNothing);
    await capture(tester, 'home-day');
    await tester.tap(find.byTooltip('home-nas 메뉴'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('새 세션'), findsOneWidget);
    await capture(tester, 'host-menu-day');
  });
  testWidgets(
    'wide home selects without connecting and protects unsaved edits',
    (tester) async {
      await open(tester, ShellHome(engine: engine), width: 1280);
      await tester.tap(find.text('home-nas'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditor), findsOneWidget);
      expect(calls.where((c) => c.method == 'connect'), isEmpty);
      await capture(tester, 'home-wide');
      await tester.tap(
        find
            .descendant(
              of: find.byType(RecordEditor),
              matching: find.text('연결'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nickname:0')),
        'changed',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('dev-box'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('변경 사항 버리기'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(find.text('changed'), findsOneWidget);
      await tester.tap(find.text('dev-box'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('버리기'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(RecordEditor),
          matching: find.text('dev-box'),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('horizontal gesture choice disables the competing action', (
    tester,
  ) async {
    await open(tester, SettingsPage(engine: engine));
    await tester.tap(find.text('제스처'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tmux 창 전환'));
    await tester.pumpAndSettle();
    expect(engine.preferences['swipeSessions'], false);
    expect(engine.preferences['swipeTmux'], true);
    expect(find.text('접두키'), findsOneWidget);
    await capture(tester, 'gesture-night');
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets('settings v2 layout at $width', (tester) async {
      await open(
        tester,
        SettingsPage(engine: engine),
        width: width,
        brightness: Brightness.light,
      );
      await capture(tester, width < 720 ? 'settings-day' : 'settings-wide');
      if (width < 720) {
        await tester.tap(find.text('키보드'));
        await tester.pumpAndSettle();
        await capture(tester, 'keyboard-day');
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'wide console menu stays open while the terminal remains usable',
    (tester) async {
      await open(
        tester,
        ConsolePage(engine: engine, sessionId: 101),
        width: 1000,
      );
      final output = <String>[];
      final terminal = engine.terminalSession(101)!.terminal;
      terminal.onOutput = output.add;
      const sample = 'admin@home-nas:~\$ ';
      terminal.writeText(sample, 0, sample.length);
      final full = tester.getSize(find.byType(TerminalPane)).width;
      await tester.tap(find.byTooltip('터미널 메뉴'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.getSize(find.byType(TerminalPane)).width, full - 360);
      await capture(tester, 'console-side-menu');
      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '  pwd',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pumpAndSettle();
      expect(output.join(), 'pwd');
      expect(find.text('전체 화면'), findsOneWidget);
      expect(find.text('조합 모드'), findsNothing);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TerminalPane)).width, full);
      await tester.pumpWidget(const SizedBox());
      engine.dispose();
    },
  );
  testWidgets('large phone host menu keeps actions reachable', (tester) async {
    await open(tester, ShellHome(engine: engine), width: 320, scale: 2);
    await tester.tap(find.byTooltip('home-nas 메뉴'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('삭제'));
    expect(find.text('삭제').hitTestable(), findsOneWidget);
    await capture(tester, 'host-menu-large-text');
  });
  testWidgets(
    'folding a focused dirty host editor retains its draft and guarded back',
    (tester) async {
      await open(tester, ShellHome(engine: engine), width: 1000);
      await tester.tap(find.text('home-nas'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(RecordEditor),
              matching: find.text('연결'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nickname:0')),
        'retained draft',
      );
      final state = tester.state(find.byType(RecordEditor));
      tester.view.physicalSize = const Size(390, 900);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(RecordEditor)), same(state));
      expect(find.text('retained draft'), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('변경 사항 버리기'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(find.text('retained draft'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('변경 사항 버리기'), findsOneWidget);
      await tester.tap(find.text('버리기'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditor), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    },
  );
  testWidgets('embedded host save keeps a newer favorite snapshot', (
    tester,
  ) async {
    await open(tester, ShellHome(engine: engine), width: 1000);
    await tester.tap(find.text('home-nas'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('home-nas 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(RecordEditor), matching: find.text('연결'))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nickname:0')), 'renamed');
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final saved =
        calls.singleWhere((c) => c.method == 'host.save').arguments as Map;
    expect(saved['favorite'], true);
    expect(saved['nickname'], 'renamed');
  });
  testWidgets(
    'mobile paste restores common terminal ownership after closing the menu',
    (tester) async {
      await open(tester, ConsolePage(engine: engine, sessionId: 101));
      await tester.tap(find.byTooltip('터미널 메뉴'));
      await tester.pumpAndSettle();
      expect(
        calls
            .lastWhere((c) => c.method == 'session.visibility')
            .arguments['visible'],
        false,
      );
      expect(find.text('조합 모드'), findsNothing);
      final output = <String>[];
      engine.terminalSession(101)!.terminal.onOutput = output.add;
      await tester.tap(find.text('붙여넣기'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(output.join(), 'paste probe');
      expect(
        tester.widget<TerminalPane>(find.byType(TerminalPane)).enabled,
        isTrue,
      );
      final owner =
          calls.lastWhere((c) => c.method == 'session.visibility').arguments
              as Map;
      expect(owner['id'], 101);
      expect(owner['visible'], true);
      expect(owner['owner'], isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      engine.dispose();
    },
  );
  for (final switchSession in [false, true]) {
    testWidgets(
      'mobile paste is discarded when its console ${switchSession ? 'switches' : 'closes'} during restoration',
      (tester) async {
        engine.state['sessions'] = [
          ...engine.list('sessions'),
          {'id': 102, 'hostId': 7, 'nickname': 'Second', 'open': true},
        ];
        final restore = Completer<void>();
        var hidden = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
              calls.add(call);
              if (call.method == 'snapshot') return engine.state;
              if (call.method == 'session.visibility') {
                if (call.arguments['visible'] == false) hidden = true;
                if (hidden && call.arguments['visible'] == true) {
                  await restore.future;
                }
              }
              return null;
            });
        await open(tester, ConsolePage(engine: engine, sessionId: 101));
        final output = <String>[];
        engine.terminalSession(101)!.terminal.onOutput = output.add;
        engine.terminalSession(102)!.terminal.onOutput = output.add;
        await tester.tap(find.byTooltip('터미널 메뉴'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('붙여넣기'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        if (switchSession) {
          final owner = calls
              .lastWhere((call) => call.method == 'session.visibility')
              .arguments['owner'];
          engine.sessionSwitch = {'owner': owner, 'id': 102};
          engine.notifyListeners();
          await tester.pump();
        } else {
          await tester.pumpWidget(const SizedBox());
        }
        restore.complete();
        await tester.pumpAndSettle();
        expect(output, isEmpty);
        expect(tester.takeException(), isNull);
        if (switchSession) {
          expect(
            tester.widget<TerminalPane>(find.byType(TerminalPane)).terminal,
            same(engine.terminalSession(102)!.terminal),
          );
          await tester.pumpWidget(const SizedBox());
        }
        engine.dispose();
      },
    );
  }

  testWidgets('custom neutral host labels keep the specified Day lightness', (
    tester,
  ) async {
    await open(
      tester,
      Scaffold(body: TildeHostTile(host: {...host, 'color': '#888888'})),
      brightness: Brightness.light,
    );
    final color = tester.widget<Text>(find.text('hn')).style!.color!;
    expect(math.pow(color.computeLuminance(), 1 / 3), closeTo(.5, .001));
  });
  testWidgets(
    'keycaps reorder and tap to hide or restore without losing preferences',
    (tester) async {
      await open(tester, TerminalBarPage(engine: engine));
      final original = List<String>.from(
        engine.preferences['terminalBarOrder'],
      );
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byKey(const ValueKey('bar-cap-FUNCTION_KEYS')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('bar-cap-UP'))).dx,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('bar-cap-ALT'))).dx,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('bar-cap-UP')));
      await tester.pumpAndSettle();
      expect(engine.preferences['terminalBarHidden'], ['UP']);
      expect(engine.preferences['terminalBarOrder'], original);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bar-hidden-region')),
          matching: find.byKey(const ValueKey('bar-cap-UP')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('bar-cap-UP')));
      await tester.pumpAndSettle();
      expect(engine.preferences['terminalBarHidden'], isEmpty);
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('bar-cap-RIGHT'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await drag.moveTo(
        tester.getCenter(find.byKey(const ValueKey('bar-cap-ALT'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await drag.up();
      await tester.pumpAndSettle();
      expect((engine.preferences['terminalBarOrder'] as List).first, 'RIGHT');
      expect(engine.preferences['terminalBarHidden'], isEmpty);
      expect(engine.preferences['terminalBarHeight'], 36);
      expect(engine.preferences['terminalBarFn'], true);
      await capture(tester, 'keybar-editor');
      tester.view.physicalSize = const Size(320, 600);
      await tester.pumpAndSettle();
      final preview = tester.getRect(find.byType(TerminalBarPreview));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TerminalBarPreview)), preview);
    },
  );
  testWidgets(
    'wide keybar editor stays beside categories with a pinned preview',
    (tester) async {
      await open(tester, SettingsPage(engine: engine), width: 1280);
      await tester.tap(find.text('키보드'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('특수키 바'));
      await tester.pumpAndSettle();
      expect(find.byType(TerminalBarPage), findsOneWidget);
      expect(find.text('보안·백업'), findsOneWidget);
      expect(
        tester.getCenter(find.byType(TerminalBarPreview)).dx,
        greaterThan(320),
      );
      await capture(tester, 'keybar-editor-wide');
    },
  );
  testWidgets('display owns palette swatches and a native font-name preview', (
    tester,
  ) async {
    await open(tester, SettingsPage(engine: engine));
    await tester.tap(find.text('화면'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('scheme-swatch-'),
      ),
      findsWidgets,
    );
    expect(
      calls.where(
        (c) =>
            c.method == 'settings.preview' &&
            c.arguments['sampleText'] == 'JetBrains Mono' &&
            c.arguments['fontFamily'] == 'JETBRAINS_MONO',
      ),
      isNotEmpty,
    );
  });
}
