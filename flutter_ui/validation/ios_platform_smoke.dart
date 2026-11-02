// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_shell_ui/console.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/platform/ios_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('iOS SSH smoke test');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var errors = 0;
  FlutterError.onError = (details) {
    errors++;
    FlutterError.presentError(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    errors++;
    debugPrint('TILDE_IOS_SMOKE_ERROR: $error\n$stack');
    return true;
  };
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('iPad SSH 검증 중'))),
    ),
  );
  const native = MethodChannel('dev.korellas.tilde/ios');
  var engine = createIosEngine();
  int? hostId, keyId;
  File? keyFile;
  var passed = false;
  try {
    await engine.start();
    check(engine.ready, 'iOS engine did not start');
    final bytes = Uint8List.fromList(utf8.encode('temporary-smoke-credential'));
    final sealed = await native.invokeMethod<Uint8List>('protect', {
      'bytes': bytes,
    });
    check(
      base64Encode(sealed!) != base64Encode(bytes),
      'Credentials were not sealed',
    );
    final opened = await native.invokeMethod<Uint8List>('unprotect', {
      'bytes': sealed,
    });
    check(
      utf8.decode(opened!) == utf8.decode(bytes),
      'Keychain round trip failed',
    );
    final tampered = Uint8List.fromList(sealed)..[sealed.length - 1] ^= 1;
    try {
      await native.invokeMethod<Uint8List>('unprotect', {'bytes': tampered});
      throw StateError('Modified credentials were accepted');
    } on PlatformException {
      /* Authenticated encryption rejected the modification. */
    }

    keyFile = File(
      (await native.invokeMethod<String>('saveFile', {'name': 'smoke.key'}))!,
    );
    await keyFile.writeAsBytes(
      base64Decode(const String.fromEnvironment('keyPemBase64')),
    );
    final key = row(
      await engine.invoke('key.import', {
        'path': keyFile.path,
        'nickname': 'iPad simulator validation',
      }),
    );
    keyId = key['id'] as int;
    final host = row(
      await engine.invoke('host.save', {
        'nickname': 'iPad simulator validation',
        'hostname': const String.fromEnvironment('host'),
        'port': int.parse(const String.fromEnvironment('port')),
        'username': const String.fromEnvironment('username'),
        'pubkeyId': keyId,
        'password': 'temporary-smoke-credential',
      }),
    );
    hostId = host['id'] as int;
    final directory = (await native.invokeMethod<String>('storageDirectory'))!;
    check(
      !await File('$directory/state.json').readAsString().then(
        (value) => value.contains('temporary-smoke-credential'),
      ),
      'Credentials were stored in plaintext',
    );
    engine.dispose();
    engine = createIosEngine();
    await engine.start();
    check(
      engine.list('hosts').any((host) => host['id'] == hostId),
      'Saved host was not restored',
    );
    final prepared = row(await engine.query('session.prepare', {'id': hostId}));
    check(
      prepared['password'] == 'temporary-smoke-credential',
      'Saved password was not restored',
    );

    final seen = <String>{};
    engine.addListener(() {
      for (final prompt in engine.list('prompts')) {
        final token = prompt['token'] as String;
        if (!seen.add(token)) continue;
        final trusted =
            prompt['type'] == 'boolean' &&
            ('${prompt['message']}'.contains(
                  const String.fromEnvironment('fingerprint'),
                ) ||
                prompt['message'] == 'iPad simulator validation');
        unawaited(
          engine.query('prompt.respond', {
            'sessionId': prompt['sessionId'],
            'token': token,
            'value': trusted,
          }),
        );
      }
    });
    final id = await engine.invoke('connect', {'id': hostId}) as int;
    final session = engine.sshSession(id)!;
    await until(() => session.sessionOpen);
    runApp(
      MaterialApp(
        home: ConsolePage(engine: engine, sessionId: id),
      ),
    );
    await until(() => session.terminal.buffer.getText().contains('READY'));
    session.input.sendText('text 한글 ABC 😀');
    session.input.sendKey(TerminalKey.enter);
    await until(
      () => session.terminal.buffer.getText().contains('TEXT 한글 ABC 😀'),
    );
    final known = rows(await engine.query('ssh.knownHosts', {'id': hostId}));
    check(
      known.any(
        (key) =>
            key['fingerprint'] == const String.fromEnvironment('fingerprint'),
      ),
      'Explicit host trust was not persisted',
    );
    passed = true;
  } catch (error, stack) {
    debugPrint('TILDE_IOS_SMOKE_FAIL: $error\n$stack');
  } finally {
    runApp(const SizedBox.shrink());
    await WidgetsBinding.instance.endOfFrame;
    await engine.query('session.disconnectAll');
    if (hostId != null) {
      for (final known in rows(
        await engine.query('ssh.knownHosts', {'id': hostId}),
      )) {
        await engine.query('knownHost.delete', {'id': known['id']});
      }
      await engine.query('host.delete', {'id': hostId});
    }
    if (keyId != null) await engine.query('key.storageDelete', {'id': keyId});
    if (keyFile != null) await keyFile.parent.delete(recursive: true);
    engine.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    passed = passed && errors == 0;
    debugPrint(passed ? 'TILDE_IOS_SMOKE_PASS' : 'TILDE_IOS_SMOKE_FAIL');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    exit(passed ? 0 : 1);
  }
}
