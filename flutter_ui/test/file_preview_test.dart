// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:typed_data';
import 'package:android_shell_ui/files/file_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'text starts read only, edits preserve BOM and failed save retains edits',
    (tester) async {
      Uint8List? saved;
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilePreview(
              path: '/test.txt',
              load: () async =>
                  Uint8List.fromList([239, 187, 191, ...utf8.encode('hello')]),
              save: (bytes) async {
                if (fail) throw StateError('offline');
                saved = bytes;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.tap(find.text('편집'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '수정');
      await tester.tap(find.text('서버에 저장'));
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '수정',
      );
      fail = false;
      await tester.tap(find.text('서버에 저장'));
      await tester.pumpAndSettle();
      expect(saved, [239, 187, 191, ...utf8.encode('수정')]);
      expect(find.text('저장했습니다.'), findsOneWidget);
    },
  );
}
