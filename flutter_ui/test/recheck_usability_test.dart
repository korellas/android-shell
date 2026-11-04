// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'dart:typed_data';
import 'package:android_shell_ui/files/file_dialogs.dart';
import 'package:android_shell_ui/files/file_preview.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/settings.dart';
import 'package:android_shell_ui/terminal/terminal_prompt.dart';
import 'package:android_shell_ui/tilde_controls.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

void main() {
  for (final upload in [true, false]) {
    for (final selection in [
      (incoming: false, existing: true, action: 'skip'),
      (incoming: true, existing: false, action: 'replace'),
      (incoming: true, existing: true, action: 'keep'),
      (incoming: false, existing: false, action: 'cancel'),
    ]) {
      testWidgets('conflict $upload selection returns ${selection.action}', (
        t,
      ) async {
        Object? result;
        await t.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (c) => TextButton(
                onPressed: () async {
                  result = await showTildeSheet<Object>(
                    context: c,
                    isScrollControlled: true,
                    builder: (_) => FileConflictPrompt(
                      destination: '/home/file.txt',
                      sourceSize: 20,
                      sourceModified: null,
                      existing: SftpFileAttrs(size: 10),
                      upload: upload,
                      currentFile: 1,
                      totalFiles: 1,
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
        final incoming = find.byKey(const ValueKey('conflict-incoming'));
        final existing = find.byKey(const ValueKey('conflict-existing'));
        expect(t.widget<CheckboxListTile>(incoming).value, isFalse);
        expect(t.widget<CheckboxListTile>(existing).value, isTrue);
        if (selection.incoming) await t.tap(incoming);
        if (!selection.existing) await t.tap(existing);
        await t.pumpAndSettle();
        expect(find.textContaining('남은'), findsNothing);
        await t.tap(
          find.widgetWithText(
            FilledButton,
            selection.action == 'cancel' ? '복사 취소' : '계속',
          ),
        );
        await t.pumpAndSettle();
        expect(result, (action: selection.action, apply: false));
      });
    }
  }
  testWidgets(
    'failed preview retries the same load and hides read-only status',
    (t) async {
      var attempts = 0;
      await t.pumpWidget(
        MaterialApp(
          home: FilePreview(
            path: '/a.txt',
            load: () async {
              if (++attempts == 1) throw const SocketException('offline');
              return Uint8List.fromList('recovered'.codeUnits);
            },
            save: (_) async {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('읽기 전용'), findsNothing);
      await t.tap(find.text('다시 시도'));
      await t.pumpAndSettle();
      expect(find.text('recovered'), findsOneWidget);
      expect(attempts, 2);
    },
  );
  testWidgets('error detail offers a clear close and retry action', (t) async {
    var retries = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => showErrorDetails(
              c,
              const SocketException('offline'),
              summary: 'nas에 연결하지 못했습니다',
              retry: () async {
                retries++;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('닫기'), findsOneWidget);
    await t.tap(find.text('다시 시도'));
    await t.pumpAndSettle();
    expect(retries, 1);
  });
  testWidgets('single fingerprint format does not expose a choice', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalPrompt(
            prompt: const {
              'type': 'hostKey',
              'hostname': 'nas',
              'keyType': 'ED25519',
              'sha256': 'SHA256:abcdefghijklmnop',
            },
            onResponse: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('지문 형식'), findsNothing);
    expect(find.byTooltip('지문 복사'), findsOneWidget);
  });
  testWidgets('large segments use a value picker instead of vertical labels', (
    t,
  ) async {
    final engine = UiEngineFixture();
    await t.pumpWidget(
      MaterialApp(
        theme: tildeTheme(Brightness.dark, engine),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Builder(
              builder: (c) => SizedBox(
                width: 220,
                child: tildeSegments(
                  c,
                  'IP 방식',
                  const [('auto', '자동'), ('v4', 'IPv4'), ('v6', 'IPv6')],
                  'auto',
                  (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SegmentedButton<Object?>), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'settings category navigation preserves an unsaved nested editor',
    (t) async {
      t.view.physicalSize = const Size(1280, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final engine = UiEngineFixture()
        ..state = {
          'ready': true,
          'platform': 'windows',
          'profiles': [
            {
              'id': 1,
              'name': 'test-profile',
              'fontSize': 14,
              'colorSchemeId': -1,
            },
          ],
          'preferences': {'defaultProfileId': 1},
        };
      addTearDown(engine.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: tildeTheme(Brightness.dark, engine),
          home: SettingsPage(engine: engine),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('터미널').first);
      await t.pumpAndSettle();
      await t.tap(find.text('터미널 프로필 관리'));
      await t.pumpAndSettle();
      await t.tap(find.text('test-profile'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('name:0')), 'unsaved');
      await t.pumpAndSettle();
      await t.tap(find.text('보안·백업'));
      await t.pumpAndSettle();
      expect(find.text('변경 사항 버리기'), findsOneWidget);
      await t.tap(find.text('계속 편집'));
      await t.pumpAndSettle();
      expect(find.text('unsaved'), findsOneWidget);
      expect(find.byKey(const ValueKey('name:0')), findsOneWidget);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );
  testWidgets(
    'permission failure saves a copy without marking the original saved',
    (t) async {
      Uint8List? copied;
      await t.pumpWidget(
        MaterialApp(
          home: FilePreview(
            path: '/locked/a.txt',
            load: () async =>
                Uint8List.fromList([239, 187, 191, ...'old'.codeUnits]),
            save: (_) async => throw SftpStatusError(
              SftpStatusCode.permissionDenied,
              'denied',
            ),
            saveCopy: (bytes) async {
              copied = bytes;
              return '/home/copy.txt';
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('편집'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'changed');
      await t.pumpAndSettle();
      await t.tap(find.text('저장'));
      await t.pumpAndSettle();
      await t.tap(find.text('자세히'));
      await t.pumpAndSettle();
      await t.tap(find.text('다른 위치에 저장'));
      await t.pumpAndSettle();
      expect(copied, [239, 187, 191, ...'changed'.codeUnits]);
      expect(find.textContaining('원본은 저장하지 않음'), findsOneWidget);
      expect(
        t.widget<TextButton>(find.widgetWithText(TextButton, '저장')).onPressed,
        isNotNull,
      );
    },
  );
}
