// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';
import 'label_layout_test.dart' show capture;
import 'package:flutter/services.dart' show FontLoader, rootBundle;

class SaveEngine extends UiEngineFixture {
  Completer<Object?>? pending;
  @override
  Future<dynamic> invoke(String method, [EngineRecord args = const {}]) async {
    if (method == 'host.save') return pending!.future;
    return null;
  }
}

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
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });
  Future<void> open(
    WidgetTester tester,
    UiEngineFixture engine,
    Widget page, {
    double width = 1280,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: tildeTheme(Brightness.dark, engine), home: page),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desktop first run offers working host and quick connection paths',
    (tester) async {
      final engine = UiEngineFixture()
        ..state = {'ready': true, 'hosts': [], 'sessions': []};
      await open(tester, engine, ShellHome(engine: engine));
      expect(find.text('첫 서버를 연결하세요'), findsOneWidget);
      expect(find.text('아직 호스트가 없습니다'), findsOneWidget);
      await capture(tester, 'polish-home-desktop');
      await tester.tap(find.text('바로 접속'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.tap(find.widgetWithText(ListTile, '새 호스트'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordEditor), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'touch first run opens quick connection and platform key creation',
    (tester) async {
      final engine = UiEngineFixture()
        ..state = {
          'ready': true,
          'hosts': [],
          'sessions': [],
          'platform': 'android',
          'generation': {'biometricAvailable': true},
        };
      await open(tester, engine, ShellHome(engine: engine), width: 360);
      expect(find.text('첫 서버를 연결하세요'), findsOneWidget);
      await capture(tester, 'polish-home-phone');
      await tester.tap(find.text('주소로 바로 접속'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).last)
            .focusNode!
            .hasFocus,
        isTrue,
      );
      tester.testTextInput.hide();
      await tester.tap(find.text('이 기기에 SSH 키 만들기'));
      await tester.pumpAndSettle();
      expect(find.byType(GenerateKeyPage), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
  testWidgets(
    'desktop save bar preserves failures and briefly confirms success',
    (tester) async {
      final engine = SaveEngine();
      const host = {
        'id': 1,
        'protocol': 'ssh',
        'nickname': 'nas',
        'hostname': 'nas.example',
        'username': 'admin',
        'port': 22,
      };
      engine.state = {
        'hosts': [host],
      };
      await open(
        tester,
        engine,
        RecordEditor(engine: engine, kind: RecordKind.host, record: host),
      );
      await tester.enterText(
        find.byKey(const ValueKey('hostname:0')),
        'new.example',
      );
      await tester.pumpAndSettle();
      expect(find.text('서버 주소를 바꿨습니다'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('서버 주소를 바꿨습니다')).dx,
        tester.getTopLeft(find.byType(Form)).dx,
      );
      await capture(tester, 'polish-save-desktop');
      engine.pending = Completer<Object?>();
      await tester.tap(find.widgetWithText(OutlinedButton, '저장'));
      await tester.pump();
      expect(find.text('저장하는 중입니다'), findsOneWidget);
      engine.pending!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('저장하지 못했습니다'), findsWidgets);
      expect(find.text('new.example'), findsWidgets);
      await capture(tester, 'polish-save-error');
      engine.pending = Completer<Object?>();
      await tester.tap(find.widgetWithText(OutlinedButton, '저장'));
      engine.state['hosts'] = [
        {...host, 'hostname': 'new.example'},
      ];
      engine.pending!.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('저장했습니다'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('저장했습니다'), findsNothing);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'save details show previous values and revert restores the draft',
    (tester) async {
      final engine = SaveEngine();
      const host = {
        'id': 1,
        'protocol': 'ssh',
        'nickname': 'nas',
        'hostname': 'old.example',
        'username': 'admin',
        'port': 22,
      };
      engine.state = {
        'hosts': [host],
      };
      await open(
        tester,
        engine,
        RecordEditor(engine: engine, kind: RecordKind.host, record: host),
      );
      await tester.enterText(
        find.byKey(const ValueKey('hostname:0')),
        'new.example',
      );
      await tester.enterText(find.byKey(const ValueKey('port:0')), '2222');
      await tester.pumpAndSettle();
      await tester.tap(find.text('1개 항목'));
      await tester.pumpAndSettle();
      expect(find.text('old.example → new.example'), findsOneWidget);
      expect(find.text('22 → 2222'), findsOneWidget);
      Navigator.of(tester.element(find.text('변경한 항목'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(find.text('old.example'), findsWidgets);
      expect(find.text('new.example'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '저장'), findsNothing);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      'first-run actions fit with large text on $platform',
      (tester) async {
        final engine = UiEngineFixture()
          ..state = {
            'ready': true,
            'hosts': [],
            'sessions': [],
            'platform': platform == TargetPlatform.iOS ? 'ios' : 'android',
          };
        tester.view.physicalSize = Size(
          platform == TargetPlatform.android ? 360 : 1280,
          900,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: tildeTheme(Brightness.dark, engine),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: ShellHome(engine: engine),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('첫 서버를 연결하세요'), findsOneWidget);
        await tester.ensureVisible(
          find.text(
            platform == TargetPlatform.iOS || platform == TargetPlatform.windows
                ? 'SSH 키 가져오기'
                : '이 기기에 SSH 키 만들기',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
