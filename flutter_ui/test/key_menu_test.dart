/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 * Licensed under the Apache License, Version 2.0
 */
import 'dart:async';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/management.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_engine_fixture.dart';
import 'package:android_shell_ui/l10n/strings.dart';

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

  testWidgets(
    'PRF probe reports native results and prevents overlapping prompts',
    (tester) async {
      engine.state = {
        'generation': {'passkeyAvailable': true},
        'keys': <Object?>[],
      };
      final completion = Completer<Object?>();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidEngine.channel, (call) async {
            if (call.method == 'snapshot') return engine.state;
            calls.add(call.method);
            if (call.method == 'key.storagePrfProbeCreate') {
              return completion.future;
            }
            return {'status': 'verified'};
          });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: KeyPage(engine: engine),
        ),
      );
      await tester.tap(find.byTooltip('패스키 복호화 테스트'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('테스트 파일 만들기'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '테스트 파일 만들기'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '테스트 파일 열기'),
            )
            .onPressed,
        isNull,
      );
      completion.complete({'status': 'unsupported'});
      await tester.pumpAndSettle();
      expect(find.text('선택한 패스키 제공자가 이 환경에서 PRF를 지원하지 않습니다.'), findsOneWidget);
      await tester.tap(find.text('테스트 파일 열기'));
      await tester.pumpAndSettle();
      expect(
        find.text('복호화 성공. 이 환경에서 같은 패스키의 PRF 값을 복구했습니다.'),
        findsOneWidget,
      );
      expect(calls, ['key.storagePrfProbeCreate', 'key.storagePrfProbeVerify']);
    },
  );

  testWidgets(
    'passkey management offers public connection backup and restore',
    (tester) async {
      engine.state = {
        'generation': {'passkeyAvailable': true, 'biometricAvailable': false},
        'keys': [
          {
            'id': 9,
            'nickname': 'work',
            'type': 'PASSKEY',
            'displayType': 'Passkey',
            'passkey': true,
            'supported': true,
            'providerLabel': 'Passkey',
            'publicKey': 'sk-ecdsa-sha2-nistp256@openssh.com AAAA work',
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: KeyPage(engine: engine),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('패스키 연결 복원'), findsOneWidget);
      expect(find.byTooltip('새 패스키'), findsOneWidget);
      await tester.tap(find.byTooltip('work 옵션'));
      await tester.pumpAndSettle();
      expect(find.text('패스키 인증 정보 파일 저장'), findsOneWidget);
      expect(find.text('공개키 복사'), findsOneWidget);
      expect(find.textContaining('비밀키'), findsNothing);
    },
  );

  testWidgets('legacy software keys expose no private-key operations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: KeyPage(engine: engine),
      ),
    );
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
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
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: GenerateKeyPage(engine: engine),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('P-256'), findsOneWidget);
    expect(find.text('RSA'), findsNothing);
    expect(find.text('Ed25519'), findsNothing);
    expect(find.textContaining('내보내기'), findsOneWidget);
  });
}
