// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/l10n/strings.dart';

class PackagedAssets extends CachingAssetBundle {
  PackagedAssets(this.prefix);
  final String prefix;
  final requested = <String>[];

  @override
  Future<ByteData> load(String key) {
    requested.add(key);
    if (!key.startsWith(prefix)) {
      throw StateError('Asset is outside the host package: $key');
    }
    return rootBundle.load(key.substring(prefix.length));
  }
}

void main() {
  for (final platform in ['android', 'ios', 'windows']) {
    testWidgets(
      '$platform opens bundled notices without a native document call',
      (tester) async {
        final nativeCalls = <String>[];
        final engine = AndroidEngine(
          platformCall: (method, args) async {
            nativeCalls.add(method);
            throw UnsupportedError(method);
          },
        )..state = {'platform': platform};
        addTearDown(engine.dispose);
        final prefix = platform == 'windows'
            ? 'packages/android_shell_ui/'
            : '';
        final assets = PackagedAssets(prefix);
        await tester.runAsync(() async {
          for (final path in [
            'assets/licenses/THIRD_PARTY_NOTICES.txt',
            'assets/fonts/Pretendard-LICENSE.txt',
            'assets/fonts/JetBrainsMono-OFL.txt',
            'assets/fonts/D2Coding-OFL.txt',
          ]) {
            await assets.loadString('$prefix$path');
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ko'),
            home: DefaultAssetBundle(
              bundle: assets,
              child: HelpPage(engine: engine),
            ),
          ),
        );
        await tester.runAsync(() async {
          await tester.tap(find.text('라이선스 및 이용 조건'));
          await Future<void>(() {});
        });
        await tester.pumpAndSettle();
        expect(find.text('Flutter 라이브러리 라이선스'), findsOneWidget);
        expect(nativeCalls, isEmpty);
        final text = tester
            .widget<SelectableText>(find.byType(SelectableText))
            .data!;
        expect(text, contains('Apache License'));
        expect(text, contains('Apache Harmony'));
        expect(text, contains('Austin Bonander'));
        expect(text, contains('JetBrains Mono'));
        expect(text, contains('Pretendard'));
        expect(text, contains('D2Coding'));
        expect(
          assets.requested,
          contains('${prefix}assets/fonts/D2Coding-OFL.txt'),
        );
        await tester.tap(find.byTooltip('뒤로'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, '도움말'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
