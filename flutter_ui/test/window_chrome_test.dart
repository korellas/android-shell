// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';
import 'label_layout_test.dart' show capture;
import 'package:android_shell_ui/tilde_design.dart';

void main() {
  setUpAll(() async {
    for (final (family, path) in [
      ('Pretendard', 'assets/fonts/Pretendard-Regular.ttf'),
      ('JetBrainsMono', 'assets/fonts/JetBrainsMono-Regular.ttf'),
      ('D2Coding', 'assets/fonts/D2Coding-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  const channel = MethodChannel('dev.korellas.tilde/windows');
  final calls = <MethodCall>[];
  late UiEngineFixture engine;
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'snapshot') return engine.state;
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'window.configure') {
            return {'maximized': false, 'active': true, 'fullscreen': false};
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(
    WidgetTester tester, {
    double width = 1280,
    bool sessions = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    engine = UiEngineFixture(fontFamily: 'D2Coding')
      ..state = {
        'ready': true,
        'platform': 'windows',
        'preferences': <String, dynamic>{},
        'hosts': [
          if (sessions) {'id': 7, 'nickname': 'NAS', 'protocol': 'ssh'},
        ],
        'sessions': [
          if (sessions) ...[
            {'id': 101, 'hostId': 7, 'nickname': 'NAS', 'open': true},
            {'id': 102, 'hostId': 7, 'nickname': 'NAS', 'open': true},
          ],
        ],
      };
    await tester.pumpWidget(
      MaterialApp(
        theme: tildeTheme(Brightness.dark, engine),
        home: ShellHome(engine: engine),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'home and new tab are compact controls and tab closes align at the edge',
    (tester) async {
      await open(tester, sessions: true);
      final home = find.byKey(const ValueKey('workspace-tab-home'));
      expect(tester.getSize(home).width, lessThanOrEqualTo(44));
      expect(find.descendant(of: home, matching: find.text('홈')), findsNothing);
      expect(find.text('새 탭'), findsNothing);
      final tab = find.byKey(const ValueKey('workspace-tab-session-101'));
      await tester.tap(tab);
      await tester.pumpAndSettle();
      await capture(tester, 'windows-tabs-with-sessions');
      final close = find.byTooltip('NAS · 1 탭 닫기');
      expect(
        tester.getRect(tab).right - tester.getRect(close).right,
        inInclusiveRange(0, 8),
      );
      expect(
        tester.getRect(find.byTooltip('터미널 메뉴')).left,
        greaterThan(
          tester.getRect(find.byTooltip('새 탭 (Ctrl Shift T)')).right - 1,
        ),
      );
      expect(find.text('Ctrl K'), findsNothing);
      expect(find.text('검색 또는 ssh user@host'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      for (final id in [102, 101]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Semantics>(
                find.byKey(ValueKey('workspace-tab-session-$id')),
              )
              .properties
              .selected,
          isTrue,
        );
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    'settings keep the window chrome and tabs available',
    (tester) async {
      await open(tester, width: 1440);
      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();
      await capture(tester, 'windows-settings');
      expect(find.byTooltip('창 닫기'), findsOneWidget);
      expect(find.byKey(const ValueKey('workspace-tab-home')), findsOneWidget);
      final navigation = tester.getRect(
        find.byKey(const ValueKey('settings-navigation')),
      );
      final detail = tester.getRect(
        find.byKey(const ValueKey('settings-detail')),
      );
      expect(navigation.width, 320);
      expect(detail.width, lessThanOrEqualTo(640));
      expect(detail.left - navigation.right, inInclusiveRange(16, 25));
      await tester.tap(find.byKey(const ValueKey('workspace-tab-home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-navigation')), findsNothing);
      expect(find.byKey(const ValueKey('workspace-sidebar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  testWidgets(
    'Windows tabs share the top row with caption buttons above the sidebar',
    (tester) async {
      await open(tester);
      await capture(tester, 'windows-tab-titlebar');
      final tab = tester.getRect(
        find.byKey(const ValueKey('workspace-tab-home')),
      );
      final close = tester.getRect(find.byTooltip('창 닫기'));
      expect(tab.top, lessThan(40));
      expect(close.top, 0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('workspace-sidebar'))).dy,
        40,
      );
      expect(
        calls.where((call) => call.method == 'window.configure'),
        isNotEmpty,
      );
      final regions =
          calls
                  .lastWhere((call) => call.method == 'window.hitTestRegions')
                  .arguments
              as Map;
      expect(
        (regions['drag'] as List)[2],
        greaterThan((regions['drag'] as List)[0]),
      );
      expect((regions['maximize'] as List)[2], lessThan(close.left + 1));
      await tester.tap(find.byTooltip('최소화'));
      expect(calls.last.method, 'window.minimize');
      await tester.tap(find.byTooltip('최대화'));
      expect(calls.last.method, 'window.toggleMaximize');
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'native maximization and fullscreen update caption controls',
    (tester) async {
      await open(tester, width: 480);
      Future<void> state(Map<String, Object> value) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('window.state', value),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await state({'maximized': true, 'active': true, 'fullscreen': false});
      expect(find.byTooltip('이전 크기로'), findsOneWidget);
      await state({'maximized': false, 'active': true, 'fullscreen': true});
      expect(find.byTooltip('창 닫기'), findsNothing);
      expect(find.byKey(const ValueKey('workspace-tab-home')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
}
