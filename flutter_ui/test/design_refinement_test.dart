// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/settings_widgets.dart';
import 'package:android_shell_ui/tilde_controls.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';
import 'package:android_shell_ui/l10n/strings.dart';

void main() {
  late UiEngineFixture engine;
  setUp(() {
    engine = UiEngineFixture()
      ..state = {
        'preferences': {'defaultProfileId': 1},
        'profiles': [
          {'id': 1, 'name': '기본', 'fontSize': 14},
        ],
      };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });

  Future<void> open(
    WidgetTester tester,
    Widget child,
    TargetPlatform platform,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        theme: tildeTheme(Brightness.dark, engine).copyWith(platform: platform),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (platform, width) in [
    (TargetPlatform.windows, 390.0),
    (TargetPlatform.iOS, 1280.0),
  ]) {
    testWidgets('confirmation uses input mode at $platform width $width', (
      tester,
    ) async {
      await open(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showTildeSheet<void>(
              context: context,
              builder: (_) => const Text('확인 내용'),
            ),
            child: const Text('열기'),
          ),
        ),
        platform,
        width,
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(
        find.byType(BottomSheet),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(Dialog),
        platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
      );
    });

    testWidgets(
      'item menu is anchored for pointer and headed for touch at $platform',
      (tester) async {
        await open(
          tester,
          TildeItemMenu<String>(
            title: '업무 서버',
            icon: Icons.dns_outlined,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: TildeMenuLabel('편집', Icons.edit_outlined),
              ),
            ],
          ),
          platform,
          width,
        );
        await tester.tap(find.byTooltip('메뉴'));
        await tester.pumpAndSettle();
        expect(find.text('편집'), findsOneWidget);
        if (platform == TargetPlatform.windows) {
          expect(find.byType(BottomSheet), findsNothing);
          expect(find.text('업무 서버'), findsNothing);
          expect(tester.getTopLeft(find.text('편집')).dx, lessThan(180));
        } else {
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(find.text('업무 서버'), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'short value picker is a sheet without search and returns the chosen value',
    (tester) async {
      (Object?, String)? selected;
      await open(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await pickTildeOption(context, '문자 인코딩', const [
                ('utf8', 'UTF-8'),
                ('kr', 'EUC-KR'),
                ('latin', 'ISO-8859-1'),
              ], 'utf8');
            },
            child: const Text('고르기'),
          ),
        ),
        TargetPlatform.android,
        390,
      );
      await tester.tap(find.text('고르기'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('EUC-KR'));
      await tester.pumpAndSettle();
      expect(selected, ('kr', 'EUC-KR'));
    },
  );

  testWidgets('long value picker searches in place', (tester) async {
    await open(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => pickTildeOption(context, '프로필', [
            for (var i = 1; i <= 9; i++) (i, '프로필 $i'),
          ], 1),
          child: const Text('고르기'),
        ),
      ),
      TargetPlatform.iOS,
      1280,
    );
    await tester.tap(find.text('고르기'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField), '프로필 9');
    await tester.pumpAndSettle();
    expect(find.text('프로필 1'), findsNothing);
    expect(find.widgetWithText(ListTile, '프로필 9'), findsOneWidget);
  });

  testWidgets(
    'terminal preview renders locally when the native preview is absent',
    (tester) async {
      await open(
        tester,
        SizedBox(width: 360, child: TerminalPreview(engine: engine)),
        TargetPlatform.windows,
        600,
      );
      expect(find.text('미리보기를 표시할 수 없어요'), findsNothing);
      expect(find.textContaining('한글.md', findRichText: true), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
