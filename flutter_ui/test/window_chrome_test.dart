// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/main.dart';
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
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  const channel = MethodChannel('dev.korellas.tilde/windows');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'window.configure') {
            return {'maximized': false, 'active': true, 'fullscreen': false};
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  Future<void> open(WidgetTester tester, {double width = 1280}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = UiEngineFixture()
      ..state = {
        'ready': true,
        'platform': 'windows',
        'hosts': [],
        'sessions': [],
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
