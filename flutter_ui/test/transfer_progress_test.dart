// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/files/transfer.dart';
import 'package:android_shell_ui/files/transfer_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/l10n/strings.dart';

void main() {
  testWidgets('shows amount, percentage, speed and remaining time', (
    tester,
  ) async {
    final control = TransferControl()
      ..bytes = 1024
      ..total = 4096;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(
          body: TransferProgress(
            status: 'test.zip 업로드 중',
            control: control,
            startedAt: DateTime.now().subtract(const Duration(seconds: 2)),
          ),
        ),
      ),
    );
    expect(find.textContaining('test.zip 업로드 중'), findsOneWidget);
    expect(find.text('1.0 KB / 4.0 KB · 25%'), findsOneWidget);
    expect(find.textContaining('/s'), findsOneWidget);
    expect(find.textContaining('남음'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .25,
    );
  });
  testWidgets('unknown total stays indeterminate and zero size is valid', (
    tester,
  ) async {
    final control = TransferControl();
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(
          body: TransferProgress(status: '준비 중', control: control),
        ),
      ),
    );
    await show();
    expect(find.text('0 B / 크기 확인 중'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    control.total = 0;
    await show();
    expect(find.text('0 B / 0 B · 100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
