// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/files/file_browser_listing.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final entries = [
    SftpName(filename: '.secret', longname: '', attr: SftpFileAttrs()),
    SftpName(
      filename: '.config',
      longname: '',
      attr: SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
    ),
    SftpName(
      filename: 'z-folder',
      longname: '',
      attr: SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
    ),
    SftpName(
      filename: 'alpha.txt',
      longname: '',
      attr: SftpFileAttrs(
        size: 900,
        userID: 1000,
        groupID: 100,
        mode: SftpFileMode.value(0x81a4),
        modifyTime: 1700000000,
      ),
    ),
    SftpName(filename: 'beta.txt', longname: '', attr: SftpFileAttrs(size: 20)),
  ];
  Future<void> show(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileBrowserListing(
            entries: entries,
            path: '/home',
            loading: false,
            onOpen: (_) {},
            onDownload: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('parent row navigates without selecting on $platform', (
      tester,
    ) async {
      var ups = 0;
      List<SftpName> selected = [];
      Future<void> showPath(String path, List<SftpName> items) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: FileBrowserListing(
              entries: items,
              path: path,
              loading: false,
              onOpen: (_) {},
              onDownload: (_) {},
              onUp: () => ups++,
              onSelectionChanged: (value) => selected = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await showPath('/home', entries);
      expect(
        tester.getTopLeft(find.text('..')).dy,
        lessThan(tester.getTopLeft(find.text('z-folder')).dy),
      );
      await tester.tap(find.text('..'));
      await tester.pumpAndSettle();
      expect(ups, 1);
      expect(selected, isEmpty);
      expect(find.byTooltip('.. 작업'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'missing');
      await tester.pumpAndSettle();
      expect(find.text('..'), findsOneWidget);
      await showPath('/empty', []);
      expect(find.text('..'), findsOneWidget);
      expect(find.text('표시할 파일이 없습니다.'), findsOneWidget);
      await tester.tap(find.text('..'));
      expect(ups, 2);
      await showPath('/', []);
      expect(find.text('..'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(390, 740), const Size(1400, 900)]) {
    testWidgets('file actions work at $size and folder actions are present', (
      tester,
    ) async {
      SftpName? renamed, deleted;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileBrowserListing(
              entries: entries,
              path: '/home',
              loading: false,
              onOpen: (_) {},
              onDownload: (_) {},
              onRename: (entry) => renamed = entry,
              onDelete: (entry) => deleted = entry,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('alpha.txt 작업'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이름 변경'));
      await tester.pumpAndSettle();
      expect(renamed?.filename, 'alpha.txt');
      await tester.tap(find.byTooltip('z-folder 작업'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(deleted?.filename, 'z-folder');
      await tester.tap(find.byTooltip('alpha.txt 작업'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('정보'));
      await tester.pumpAndSettle();
      expect(find.text('/home/alpha.txt'), findsOneWidget);
      expect(find.textContaining('UID'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'right click opens file actions and disabled operations stay disabled',
    (tester) async {
      await show(tester, const Size(1400, 900));
      await tester.tap(find.text('alpha.txt'), buttons: 2);
      await tester.pumpAndSettle();
      expect(find.text('이름 변경'), findsOneWidget);
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, '이름 변경')).enabled,
        isFalse,
      );
      expect(find.text('정보'), findsOneWidget);
    },
  );

  testWidgets('wide view hides dot entries and shows available metadata', (
    tester,
  ) async {
    await show(tester, const Size(1400, 900));
    expect(find.text('.secret'), findsNothing);
    expect(find.text('.config'), findsNothing);
    expect(find.text('수정일'), findsOneWidget);
    expect(find.text('1000'), findsNothing);
    expect(find.text('100'), findsNothing);
    expect(find.text('rw-r--r--'), findsOneWidget);
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('소유자 UID'));
    await tester.pumpAndSettle();
    expect(find.text('1000'), findsOneWidget);
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('숨김 파일·폴더 표시'));
    await tester.pumpAndSettle();
    expect(find.text('.secret'), findsOneWidget);
    expect(find.text('.config'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search and descending size sorting keep folders first', (
    tester,
  ) async {
    await show(tester, const Size(1400, 900));
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('크기순'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('내림차순'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('z-folder')).dy,
      lessThan(tester.getTopLeft(find.text('alpha.txt')).dy),
    );
    expect(
      tester.getTopLeft(find.text('alpha.txt')).dy,
      lessThan(tester.getTopLeft(find.text('beta.txt')).dy),
    );
    await tester.enterText(find.byType(TextField).first, 'BETA');
    await tester.pumpAndSettle();
    expect(find.text('alpha.txt'), findsNothing);
    expect(find.text('beta.txt'), findsOneWidget);
    expect(find.text('1개 항목 · 4개 숨김/필터'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();
    expect(find.text('조건에 맞는 파일이 없습니다.'), findsOneWidget);
  });

  testWidgets('phone opens controls in sidebar without overflow', (
    tester,
  ) async {
    await show(tester, const Size(390, 740));
    expect(find.text('숨김 파일·폴더 표시'), findsNothing);
    await tester.tap(find.text('보기'));
    await tester.pumpAndSettle();
    expect(find.text('숨김 파일·폴더 표시'), findsOneWidget);
    await tester.tap(find.text('숨김 파일·폴더 표시'));
    await tester.pumpAndSettle();
    expect(find.text('.secret'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
