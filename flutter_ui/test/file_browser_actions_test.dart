// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/files/file_browser.dart';
import 'package:android_shell_ui/files/file_browser_listing.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'sftp_file_operations_test.dart' show FakeFiles;
import 'ui_engine_fixture.dart';

class BrowserFiles extends FakeFiles {
  @override
  Future<String> absolute(String path) async => path == '.' ? '/home' : path;
}

class BrowserSession extends AppSshSession {
  BrowserSession(this.files, VoidCallback changed)
    : super(
        id: 1,
        prepared: {
          'host': {'id': 1},
          'profile': {},
        },
        platform: (_, _) async => null,
        onChanged: changed,
      );
  final BrowserFiles files;
  @override
  bool get connected => true;
  @override
  Future<void> connect() async {}
  @override
  Future<SftpClient> openSftp() async => files;
}

class BrowserEngine extends UiEngineFixture {
  BrowserEngine(this.files);
  final BrowserFiles files;
  @override
  Future<AppSshSession> createFileConnection(
    int hostId, {
    required VoidCallback onChanged,
  }) async => BrowserSession(files, onChanged);
}

void main() {
  late BrowserFiles files;
  Future<void> show(WidgetTester tester) async {
    files = BrowserFiles()
      ..nodes.addAll({
        '/home': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
        '/home/old.txt': SftpFileAttrs(size: 10),
      });
    await tester.pumpWidget(
      MaterialApp(
        home: FileBrowserPage(
          engine: BrowserEngine(files),
          host: const {'id': 1, 'nickname': 'test'},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> action(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('old.txt 작업'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(PopupMenuItem<FileAction>),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'delete cancel makes no changes; confirmed deletion refreshes listing',
    (tester) async {
      await show(tester);
      await action(tester, '삭제');
      expect(find.text('삭제 확인'), findsOneWidget);
      expect(files.removed, isEmpty);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(files.removed, isEmpty);
      await action(tester, '삭제');
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(files.removed, ['/home/old.txt']);
      expect(find.text('old.txt'), findsNothing);
      expect(find.text('1개 항목을 삭제했습니다.'), findsOneWidget);
    },
  );
  testWidgets(
    'rename validates and refreshes the row; new folder is available',
    (tester) async {
      await show(tester);
      await action(tester, '이름 변경');
      await tester.enterText(find.byType(TextFormField), '../escape');
      await tester.tap(find.byTooltip('이름 변경 적용'));
      await tester.pumpAndSettle();
      expect(files.nodes.containsKey('/home/old.txt'), isTrue);
      expect(find.textContaining('경로 구분자'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '새 이름.txt');
      await tester.tap(find.byTooltip('이름 변경 적용'));
      await tester.pumpAndSettle();
      expect(find.text('새 이름.txt'), findsOneWidget);
      expect(files.allowedOverwrite, isFalse);
      await tester.tap(find.byTooltip('새 폴더'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '새 폴더');
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();
      expect(files.nodes['/home/새 폴더']?.isDirectory, isTrue);
      expect(find.text('새 폴더'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('rename collision reports an error and keeps both files', (
    tester,
  ) async {
    await show(tester);
    files.nodes['/home/taken'] = SftpFileAttrs();
    await action(tester, '이름 변경');
    await tester.enterText(find.byType(TextFormField), 'taken');
    await tester.tap(find.byTooltip('이름 변경 적용'));
    await tester.pumpAndSettle();
    expect(files.nodes.keys, containsAll(['/home/old.txt', '/home/taken']));
    expect(find.textContaining('같은 이름의'), findsWidgets);
  });
}
