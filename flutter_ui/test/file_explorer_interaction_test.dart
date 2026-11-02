// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/files/file_browser_listing.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'empty folder accepts paste keys and regains focus after search',
    (tester) async {
      var pastes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: FileBrowserListing(
              entries: const [],
              path: '/empty',
              loading: false,
              onOpen: (_) {},
              onDownload: (_) {},
              onPaste: () => pastes++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> paste() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
      }

      await paste();
      expect(pastes, 1);
      await tester.tap(find.byType(TextField).first);
      await paste();
      expect(pastes, 1);
      await tester.tap(find.text('표시할 파일이 없습니다.'));
      await paste();
      expect(pastes, 2);
    },
  );
  testWidgets(
    'desktop selects without downloading, supports Ctrl/Shift and focus-scoped keys',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entries = [
        for (final name in ['file1', 'file2', 'file11'])
          SftpName(filename: name, longname: '', attr: SftpFileAttrs(size: 1)),
      ];
      var opens = 0, downloads = 0;
      List<SftpName> selection = [], deleted = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: FileBrowserListing(
              entries: entries,
              path: '/A',
              loading: false,
              onOpen: (_) => opens++,
              onDownload: (_) => downloads++,
              onSelectionChanged: (value) => selection = value,
              onDeleteMany: (value) => deleted = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('file1'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(selection.map((entry) => entry.filename), ['file1']);
      expect(opens, 0);
      expect(downloads, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('file2'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(selection, hasLength(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(deleted, hasLength(2));
      await tester.tap(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'file');
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(deleted, hasLength(2));
      await tester.tap(find.text('file1'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('file11'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(selection, hasLength(3));
      expect(
        tester.getTopLeft(find.text('file2')).dy,
        lessThan(tester.getTopLeft(find.text('file11')).dy),
      );
    },
  );
}
