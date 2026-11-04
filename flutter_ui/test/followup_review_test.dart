// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/files/file_dialogs.dart';
import 'package:android_shell_ui/files/file_preview.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/management.dart';
import 'package:flutter/services.dart';
import 'package:android_shell_ui/tilde_controls.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:android_shell_ui/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';
import 'file_browser_actions_test.dart' show BrowserFiles;

void main() {
  setUpAll(() async {
    final font = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      font.addFont(rootBundle.load('assets/fonts/Pretendard-$weight.ttf'));
    }
    await font.load();
  });
  test('display timestamps use minutes and enough date context', () {
    final now = DateTime(2026, 11, 4, 15, 45);
    expect(
      formatTildeTimestamp(DateTime(2026, 11, 4, 9, 5, 59), now: now),
      '09:05',
    );
    expect(
      formatTildeTimestamp(DateTime(2026, 11, 3, 9, 5), now: now),
      '11-03 09:05',
    );
    expect(
      formatTildeTimestamp(DateTime(2025, 11, 3, 9, 5), now: now),
      '2025-11-03 09:05',
    );
  });
  testWidgets(
    'conflict action names follow selection without changing cancel semantics',
    (t) async {
      Object? result;
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () async {
                result = await showTildeSheet<Object>(
                  context: c,
                  isScrollControlled: true,
                  builder: (_) => FileConflictPrompt(
                    destination: '/home/a.txt',
                    sourceSize: 20,
                    sourceModified: null,
                    existing: SftpFileAttrs(size: 10),
                    upload: true,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, '건너뛰기'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('conflict-incoming')));
      await t.pump();
      expect(find.widgetWithText(FilledButton, '둘 다 보관'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('conflict-existing')));
      await t.pump();
      expect(find.widgetWithText(FilledButton, '덮어쓰기'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('conflict-incoming')));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, '복사 취소'));
      await t.pumpAndSettle();
      expect(result, (action: 'cancel', apply: false));
    },
  );
  testWidgets('permission recovery prioritizes saving a copy', (t) async {
    var copied = false;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => showErrorDetails(
              c,
              SftpStatusError(
                SftpStatusCode.permissionDenied,
                'Permission denied',
              ),
              retry: () async {},
              saveElsewhere: () async {
                copied = true;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, '다시 시도'), findsNothing);
    await t.tap(find.widgetWithText(FilledButton, '다른 위치에 저장'));
    await t.pumpAndSettle();
    expect(copied, isTrue);
  });
  testWidgets(
    'help route selects help and clears the previous category',
    (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final engine = UiEngineFixture();
      addTearDown(engine.dispose);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: tildeTheme(Brightness.dark, engine),
          home: SettingsPage(engine: engine),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('도움말 및 로그'));
      await t.pumpAndSettle();
      expect(
        t.widget<ListTile>(find.widgetWithText(ListTile, '도움말 및 로그')).selected,
        isTrue,
      );
      final nav = find.byKey(const ValueKey('settings-navigation'));
      final selected = t
          .widgetList<ListTile>(
            find.descendant(of: nav, matching: find.byType(ListTile)),
          )
          .where((tile) => tile.selected);
      expect(selected.length, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets('unsupported preview has no read-only footer', (t) async {
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FilePreview(
          path: '/binary.bin',
          load: () async => Uint8List.fromList([0, 255, 2]),
          save: (_) async {},
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    expect(find.text('이 파일 형식은 미리보기를 지원하지 않습니다.'), findsOneWidget);
    expect(find.text('읽기 전용'), findsNothing);
  });
  testWidgets('authentication failure opens authentication settings directly', (
    t,
  ) async {
    final engine = UiEngineFixture();
    engine.state = {
      'ready': true,
      'hosts': [
        {
          'id': 7,
          'nickname': 'nas',
          'hostname': 'nas.example',
          'protocol': 'ssh',
          'username': 'admin',
          'port': 22,
        },
      ],
      'sessions': [
        {
          'id': 101,
          'hostId': 7,
          'nickname': 'nas',
          'open': false,
          'ended': true,
          'connectionPhase': 'authentication',
          'connectionLog': ['Permission denied'],
          'progress': {'state': 'ERROR', 'message': 'Permission denied'},
        },
      ],
      'preferences': <String, dynamic>{},
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      AndroidEngine.channel,
      (call) async => call.method == 'snapshot' ? engine.state : null,
    );
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(AndroidEngine.channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConsolePage(engine: engine, sessionId: 101),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('자세히'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(OutlinedButton, '인증 편집').last);
    await t.pumpAndSettle();
    expect(find.byType(RecordEditor), findsOneWidget);
    expect(find.text('로그인 키'), findsOneWidget);
    expect(find.byKey(const ValueKey('hostname:0')), findsNothing);
  });
  testWidgets(
    'large forward dialog keeps actions visible while fields scroll',
    (t) async {
      t.view.physicalSize = const Size(1280, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final engine = UiEngineFixture();
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: tildeTheme(Brightness.dark, engine),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showForwardEditor(c, engine, {'id': 7}),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, '저장');
      final before = t.getRect(save);
      expect(before.bottom, lessThanOrEqualTo(844));
      final firstPort = t.getRect(find.byKey(const ValueKey('sourcePort:0')));
      final viewport = t.getRect(
        find.byWidgetPredicate(
          (w) => w is Scrollbar && w.thumbVisibility == true,
        ),
      );
      expect(
        firstPort.intersect(viewport).height,
        greaterThanOrEqualTo(firstPort.height / 2),
      );
      final port = find.byKey(const ValueKey('destPort:0'));
      await t.ensureVisible(port);
      await t.pumpAndSettle();
      expect(t.getRect(port).bottom, lessThanOrEqualTo(before.top));
      expect(t.getRect(save), before);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  for (final language in ['ko', 'en']) {
    testWidgets(
      'destination picker initializes after localization ($language)',
      (t) async {
        final files = BrowserFiles()
          ..nodes['/home'] = SftpFileAttrs(mode: SftpFileMode.value(0x4000));
        await t.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RemoteFolderPicker(files: files, path: '/home'),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text(language == 'ko' ? '이동할 폴더' : 'Destination folder'),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
