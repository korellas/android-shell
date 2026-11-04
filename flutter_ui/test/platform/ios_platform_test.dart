// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/management.dart';
import 'package:android_shell_ui/platform/ios_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final calls = <String>[];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tilde-ios-test-');
    calls.clear();
  });
  tearDown(() async => directory.delete(recursive: true));

  Future<Object?> native(String method, Map<String, Object?> args) async {
    calls.add(method);
    return switch (method) {
      'storageDirectory' => directory.path,
      'protect' || 'unprotect' => Uint8List.fromList(
        (args['bytes'] as Uint8List).map((byte) => byte ^ 170).toList(),
      ),
      'saveFile' => '${directory.path}/export.txt',
      'exportFile' => null,
      _ => throw StateError('Unexpected native call: $method'),
    };
  }

  test(
    'iOS starts without Android channels and restores protected hosts',
    () async {
      final engine = createIosEngine(native: native);
      addTearDown(engine.dispose);
      await engine.start();
      expect(engine.ready, isTrue);
      expect(engine.state['platform'], 'ios');
      expect(engine.state['hardwareKeyboard'], isFalse);
      final host = row(
        await engine.invoke('host.save', {
          'nickname': 'work',
          'hostname': 'example.test',
          'username': 'alice',
          'password': 'ios-test-password',
        }),
      );
      await engine.invoke('settings.update', {
        'key': 'themeMode',
        'value': 'LIGHT',
      });
      final reopened = createIosEngine(native: native);
      addTearDown(reopened.dispose);
      await reopened.start();
      expect(reopened.list('hosts').single['id'], host['id']);
      expect(reopened.preferences['themeMode'], 'LIGHT');
      final prepared = row(
        await reopened.query('session.prepare', {'id': host['id']}),
      );
      expect(prepared['password'], 'ios-test-password');
      expect(
        await File('${directory.path}/state.json').readAsString(),
        isNot(contains('ios-test-password')),
      );
      expect(calls, containsAll(['protect', 'unprotect']));
    },
  );

  test('iOS persists explicit server trust and blocks changed keys', () async {
    final engine = createIosEngine(native: native);
    addTearDown(engine.dispose);
    final key = <String, Object?>{
      'hostname': 'example.test',
      'port': 22,
      'algorithm': 'ssh-ed25519',
      'fingerprint': 'SHA256:first',
    };
    expect(row(await engine.query('ssh.checkHost', key))['status'], 'new');
    await engine.query('ssh.saveHost', {...key, 'accept': true});
    final reopened = createIosEngine(native: native);
    addTearDown(reopened.dispose);
    expect(row(await reopened.query('ssh.checkHost', key))['status'], 'match');
    final changed = {...key, 'fingerprint': 'SHA256:changed'};
    expect(
      row(await reopened.query('ssh.checkHost', changed))['status'],
      'changed',
    );
    await expectLater(
      reopened.query('ssh.saveHost', {...changed, 'accept': true}),
      throwsA(isA<EngineException>()),
    );
  });

  test('iOS exports a document after writing its contents', () async {
    final engine = createIosEngine(
      native: (method, args) async {
        if (method == 'exportFile') {
          expect(
            await File(args['path'] as String).readAsString(),
            'host config',
          );
        }
        return native(method, args);
      },
    );
    addTearDown(engine.dispose);
    final uri = await engine.query('document.create', {'name': 'hosts.json'});
    expect(calls, isNot(contains('exportFile')));
    await engine.query('document.write', {'uri': uri, 'text': 'host config'});
    expect(calls.last, 'exportFile');
  });

  test(
    'iOS accepts terminal visibility without an Android foreground service',
    () async {
      final engine = createIosEngine(native: native);
      addTearDown(engine.dispose);
      await engine.query('runtime.visibility', {'id': '1', 'visible': true});
      await engine.query('runtime.visibility', {'id': '1', 'visible': false});
    },
  );

  testWidgets(
    'iPad starts the shared home through its native channel',
    (tester) async {
      const channel = MethodChannel('dev.korellas.tilde/ios');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) => native(
          call.method,
          Map<String, Object?>.from(call.arguments as Map),
        ),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(const AndroidShellApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShellHome), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('iOS offers key import without Android Keystore generation', (
    tester,
  ) async {
    final engine = createIosEngine(native: native);
    addTearDown(engine.dispose);
    await tester.runAsync(engine.start);
    await tester.pumpWidget(MaterialApp(home: KeyPage(engine: engine)));
    await tester.pumpAndSettle();
    expect(find.text('키 파일 추가'), findsOneWidget);
    expect(find.textContaining('Android Keystore'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '키 파일 추가'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('iOS key details describe imported keys accurately', (
    tester,
  ) async {
    final engine = createIosEngine(native: native);
    addTearDown(engine.dispose);
    await tester.runAsync(engine.start);
    await tester.pumpWidget(
      MaterialApp(
        home: RecordEditor(
          engine: engine,
          kind: RecordKind.key,
          record: {
            'id': 7,
            'nickname': 'imported',
            'type': 'IMPORTED',
            'supported': true,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Android Keystore P-256 키'), findsNothing);
    expect(find.text('가져온 개인키'), findsOneWidget);
  });

  testWidgets('iOS host editor offers SSH without Android local shells', (
    tester,
  ) async {
    final engine = createIosEngine(native: native);
    addTearDown(engine.dispose);
    await tester.runAsync(engine.start);
    await tester.pumpWidget(
      MaterialApp(
        home: RecordEditor(engine: engine, kind: RecordKind.host),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SSH'), findsWidgets);
    expect(find.text('로컬'), findsNothing);
  });
}
