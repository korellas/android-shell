/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('progress fits a narrow action button without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 24, child: TildeProgress())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TildeProgress)).width,
      lessThanOrEqualTo(24),
    );
    await tester.pumpWidget(const SizedBox());
  });

  test('custom theme colors survive display name changes', () {
    final engine = AndroidEngine()
      ..state = {
        'preferences': {'defaultProfileId': 1},
        'profiles': [
          {'id': 1, 'colorSchemeId': 42},
        ],
        'schemes': [
          {
            'id': 42,
            'name': 'Default',
            'backgroundColor': 0xff112233,
            'foregroundColor': 0xffddeeff,
            'cursorColor': 0xffabcdef,
          },
        ],
      };
    for (final name in ['Default', 'Tilde Night', 'Tilde Day', 'My theme']) {
      engine.state['schemes'][0]['name'] = name;
      final theme = tildeTheme(Brightness.dark, engine);
      expect(theme.colorScheme.surface, const Color(0xff112233));
      expect(theme.colorScheme.primary, const Color(0xffabcdef));
    }
    engine.dispose();
  });

  testWidgets('Tilde uses the supplied brand and night/day surfaces', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dev.korellas.androidshell/engine');
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'snapshot'
          ? {
              'ready': true,
              'preferences': {'themeMode': 'DARK'},
              'hosts': [],
              'sessions': [],
              'prompts': [],
            }
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.korellas.androidshell/events'),
      (_) async => null,
    );
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Tilde');
    expect(app.darkTheme!.colorScheme.surface, const Color(0xff0e1216));
    expect(app.darkTheme!.colorScheme.primary, const Color(0xff6fd8c4));
    expect(app.theme!.colorScheme.surface, const Color(0xfff6f5f0));
    expect(app.theme!.textTheme.bodyMedium!.fontFamily, 'Pretendard');
    expect(find.text('Android Shell'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    messenger.setMockMethodCallHandler(channel, null);
  });
}
