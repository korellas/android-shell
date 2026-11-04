// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:flutter/material.dart';
import 'package:android_shell_ui/l10n/strings.dart';
import 'package:android_shell_ui/files/transfer.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

class _ReadyEngine extends AndroidEngine {
  @override
  Future<void> start() async {
    state = {'ready': true, 'hosts': [], 'sessions': [], 'preferences': {}};
    notifyListeners();
  }
}

void main() {
  test(
    'count messages use locale grammar and preserve placeholder content',
    () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final ko = await AppLocalizations.delegate.load(const Locale('ko'));
      expect(en.items(1), '1 item');
      expect(en.items(2), '2 items');
      expect(ko.items(1), '1개 항목');
      expect(
        en.couldNotConnectTo("server's {name}"),
        "Could not connect to server's {name}",
      );
    },
  );
  testWidgets('multiline prompt uses English singular and plural', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => askText(context, 'Input', multiline: true),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 line ·'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'first\nsecond');
    await tester.pump();
    expect(find.textContaining('2 lines ·'), findsOneWidget);
  });
  testWidgets('additional locales resolve from device region and script', (
    tester,
  ) async {
    final engine = _ReadyEngine();
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final cases = <(Locale, String)>[
      (const Locale('ja', 'JP'), 'ホストを追加'),
      (const Locale('zh', 'CN'), '添加主机'),
      (
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
          countryCode: 'SG',
        ),
        '添加主机',
      ),
      (const Locale('pt', 'BR'), 'Adicionar host'),
      (const Locale('es', 'MX'), 'Añadir host'),
    ];
    tester.platformDispatcher.localesTestValue = [cases.first.$1];
    await tester.pumpWidget(AndroidShellApp(engine: engine));
    for (final (locale, expected) in cases) {
      tester.platformDispatcher.localesTestValue = [locale];
      await tester.pumpAndSettle();
      expect(
        find.byTooltip(expected),
        findsOneWidget,
        reason: locale.toLanguageTag(),
      );
    }
    tester.platformDispatcher.localesTestValue = [const Locale('fr')];
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add host'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('home follows device language and updates while running', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final engine = _ReadyEngine();
    await tester.pumpWidget(AndroidShellApp(engine: engine));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add host'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(
      fileFailureSummary(TimeoutException('network')),
      contains('not responding'),
    );
    tester.platformDispatcher.localesTestValue = [const Locale('ko')];
    await tester.pumpAndSettle();
    expect(find.byTooltip('호스트 추가'), findsOneWidget);
    expect(find.byTooltip('메뉴'), findsOneWidget);
    expect(
      fileFailureSummary(TimeoutException('network')),
      contains('응답하지 않습니다'),
    );
    expect(find.byTooltip('Add host'), findsNothing);
    tester.platformDispatcher.localesTestValue = [const Locale('fr')];
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add host'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
