// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:android_shell_ui/files/file_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/l10n/strings.dart';

void main() {
  testWidgets(
    'permission checkboxes and octal input stay synchronized and preserve special bits',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: Scaffold(
            body: FilePermissionsPrompt(
              names: const ['script.sh'],
              initial: 0x9a4,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '4644',
      );
      await tester.tap(find.byKey(const ValueKey('permission-6')));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '4744',
      );
      await tester.enterText(find.byType(TextFormField), '0755');
      await tester.pump();
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('permission-0')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('permission-1')))
            .value,
        isFalse,
      );
    },
  );
  testWidgets(
    'permanent deletion lists file sizes and waits for actual descendant counts',
    (tester) async {
      final counts = Completer<Map<String, int>>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: Scaffold(
            body: FileDeletePrompt(
              entries: [
                SftpName(
                  filename: 'logs',
                  longname: '',
                  attr: SftpFileAttrs(mode: SftpFileMode.value(0x41ed)),
                ),
                SftpName(
                  filename: 'readme.md',
                  longname: '',
                  attr: SftpFileAttrs(size: 286),
                ),
              ],
              counts: counts.future,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '영구 삭제'))
            .onPressed,
        isNull,
      );
      expect(find.text('286 B'), findsOneWidget);
      counts.complete({'logs': 12, 'readme.md': 1});
      await tester.pumpAndSettle();
      expect(find.text('하위 항목 11개'), findsOneWidget);
      expect(find.textContaining('13개 항목'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '영구 삭제'))
            .onPressed,
        isNotNull,
      );
    },
  );
}
