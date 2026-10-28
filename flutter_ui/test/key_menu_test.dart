/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 * Licensed under the Apache License, Version 2.0
 */
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/management.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_engine_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AndroidEngine engine;
  MethodCall? copied;

  setUp(() {
    engine = UiEngineFixture()
      ..state = {
        'keys': [
          {
            'id': 2,
            'nickname': 'Legacy key',
            'type': 'IMPORTED',
            'biometric': false,
            'supported': false,
            'supportMessage': '기존 개인키 · 사용 중지',
            'publicKey': 'ssh-ed25519 AAAA legacy',
          },
        ],
        'generation': {'biometricAvailable': true},
      };
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
          if (call.method == 'snapshot') return engine.state;
          if (call.method == 'key.copy') copied = call;
          return null;
        });
  });

  tearDown(() {
    engine.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEngine.channel, null);
  });

  testWidgets('legacy software keys expose no private-key operations', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: KeyPage(engine: engine)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Legacy key 옵션'));
    await tester.pumpAndSettle();
    expect(find.text('공개키 복사'), findsOneWidget);
    expect(find.textContaining('비밀키'), findsNothing);
    expect(find.text('가져오기'), findsNothing);
    await tester.tap(find.text('공개키 복사'));
    await tester.pumpAndSettle();
    expect(copied?.arguments, {'id': 2, 'format': 'public'});
  });

  testWidgets('quarantined key editor has no signing or password controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordEditor(
          engine: engine,
          kind: RecordKind.key,
          record: engine.list('keys').single,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('사용 중지된 기존 개인키'), findsOneWidget);
    expect(find.text('사용할 때 확인'), findsNothing);
    expect(find.textContaining('암호 변경'), findsNothing);
  });

  testWidgets('new key UI offers only Android Keystore P-256 generation', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: GenerateKeyPage(engine: engine)));
    await tester.pumpAndSettle();
    expect(find.textContaining('P-256'), findsOneWidget);
    expect(find.text('RSA'), findsNothing);
    expect(find.text('Ed25519'), findsNothing);
    expect(find.textContaining('내보내기'), findsOneWidget);
  });
}
