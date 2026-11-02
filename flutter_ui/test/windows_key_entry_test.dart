// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/management.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

void main() {
  testWidgets(
    'Windows offers key file import instead of Android key generation',
    (tester) async {
      final engine = UiEngineFixture()
        ..state = {
          'platform': 'windows',
          'keys': [],
          'generation': {'biometricAvailable': false},
        };
      await tester.pumpWidget(MaterialApp(home: KeyPage(engine: engine)));
      await tester.pumpAndSettle();
      final button = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text('키 파일 추가'), findsOneWidget);
      expect(find.textContaining('Android Keystore'), findsNothing);
    },
  );
}
