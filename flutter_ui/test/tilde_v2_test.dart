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
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'session count badge identifies concurrent connections in $brightness',
      (tester) async {
        engine.state['sessions'] = [
          ...engine.list('sessions'),
          {...engine.list('sessions').single, 'id': 102},
        ];
        await open(tester, ShellHome(engine: engine), brightness: brightness);
        final tile = tester.widget<TildeHostTile>(
          find.byType(TildeHostTile).first,
        );
        expect(tile.sessionCount, 2);
        expect(
          find.descendant(
            of: find.byType(TildeHostTile).first,
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          brightness == Brightness.light
              ? 'polish-home-day'
              : 'polish-home-night',
        );
        await tester.tap(find.byTooltip('home-nas 메뉴'));
        await tester.pumpAndSettle();
        await capture(
          tester,
          brightness == Brightness.light
              ? 'polish-host-menu-day'
              : 'polish-host-menu-night',
        );
      },
    );
  }

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
                .last,
          )
          .height,
      80,
    );
    expect(tester.getTopLeft(find.byType(TextField)).dy, greaterThan(700));
    expect(find.byTooltip('열린 세션'), findsOneWidget);
    expect(find.text('열린 세션'), findsOneWidget);
    await capture(tester, 'home-day');
    await tester.tap(find.byTooltip('home-nas 메뉴'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('새 터미널'), findsOneWidget);
    await capture(tester, 'host-menu-day');
  });
  testWidgets(
    'desktop editor tabs retain drafts and guard closing',
    (tester) async {
      await open(tester, ShellHome(engine: engine), width: 1280);
      expect(find.text('새 터미널'), findsOneWidget);
      await tester.tap(find.text('편집').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nickname:0')),
        'changed',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('workspace-host-8')));
      await tester.pumpAndSettle();
      expect(find.text('변경 사항 버리기'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('workspace-tab-editor-7')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('nickname:0')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'changed',
      );
      await tester.tap(find.byTooltip('home-nas 편집 탭 닫기'));
      await tester.pumpAndSettle();
      expect(find.text('변경 사항 버리기'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('nickname:0')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'changed',
      );
      await tester.tap(find.byTooltip('home-nas 편집 탭 닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('버리기'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditor, skipOffstage: false), findsNothing);
      expect(calls.where((c) => c.method == 'connect'), isEmpty);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
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
  testWidgets('locked modifiers remain visible in the console', (tester) async {
    engine.state['preferences'] = {
      ...engine.preferences,
      'stickymodifiers': 'yes',
      'alwaysvisible': true,
    };
    await open(tester, ConsolePage(engine: engine, sessionId: 101));
    final session = engine.terminalSession(101)!;
    const sample = 'admin@home-nas:~\$ htop';
    session.terminal.writeText(sample, 0, sample.length);
    session.terminal.notifyListeners();
    expect(session.input.stickyModifiers, 'yes');
    session.input.setModifiers(ctrl: true, alt: true);
    await tester.pumpAndSettle();
    await capture(tester, 'polish-console-night');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    engine.dispose();
  });

  testWidgets(
    'pointer terminal menu is anchored and preserves viewport size',
    (tester) async {
      await open(
        tester,
        ConsolePage(engine: engine, sessionId: 101),
        width: 1000,
      );
      final width = tester.getSize(find.byType(TerminalPane)).width;
      await tester.tap(find.byTooltip('터미널 메뉴'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('전체 화면'), findsOneWidget);
      expect(tester.getSize(find.byType(TerminalPane)).width, width);
      await tester.tapAt(const Offset(10, 300));
      await tester.pumpAndSettle();
      expect(find.text('전체 화면'), findsNothing);
      expect(tester.getSize(find.byType(TerminalPane)).width, width);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
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
    'resizing a desktop editor preserves its draft and guards its tab',
    (tester) async {
      await open(tester, ShellHome(engine: engine), width: 1000);
      await tester.tap(find.text('편집').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nickname:0')),
        'retained draft',
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(RecordEditor));
      tester.view.physicalSize = const Size(390, 900);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(RecordEditor)), same(state));
      expect(find.text('retained draft'), findsOneWidget);
      await tester.tap(find.byTooltip('home-nas 편집 탭 닫기'));
      await tester.pumpAndSettle();
      expect(find.text('변경 사항 버리기'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(find.text('retained draft'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'embedded host save keeps a newer favorite snapshot',
    (tester) async {
      await open(tester, ShellHome(engine: engine), width: 1000);
      await tester.tap(find.text('편집').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nickname:0')),
        'renamed',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('workspace-host-7')),
        buttons: 2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('즐겨찾기에 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      final saved =
          calls.singleWhere((c) => c.method == 'host.save').arguments as Map;
      expect(saved['favorite'], true);
      expect(saved['nickname'], 'renamed');
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
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
  testWidgets(
    'display renders portable terminal and font previews without duplicate swatches',
    (tester) async {
      await open(tester, SettingsPage(engine: engine));
      await tester.tap(find.text('화면'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('scheme-swatch-'),
        ),
        findsNothing,
      );
      expect(find.text('JetBrains Mono'), findsWidgets);
      expect(find.textContaining('한글.md'), findsOneWidget);
      expect(calls.where((c) => c.method == 'settings.preview'), isEmpty);
    },
  );
}
