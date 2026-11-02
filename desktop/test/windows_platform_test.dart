// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilde_desktop/windows_platform.dart';

void main() {
  late Directory directory;
  late File settings;
  String? chosenPath;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tilde-desktop-test-');
    settings = File('${directory.path}/state.json');
    chosenPath = null;
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  WindowsPlatform create() => WindowsPlatform(
    file: settings,
    native: (_, _) async => chosenPath,
    protect: (bytes) async =>
        Uint8List.fromList(bytes.map((byte) => byte ^ 170).toList()),
    unprotect: (bytes) async =>
        Uint8List.fromList(bytes.map((byte) => byte ^ 170).toList()),
  );

  test(
    'persists host credentials protected and reopens the shared connection contract',
    () async {
      final platform = create();
      final saved =
          await platform.call('host.save', {
                'nickname': 'work',
                'hostname': 'example.test',
                'username': 'alice',
                'port': 22,
                'password': 'test-password-not-plaintext',
              })
              as Map;
      final reopened = create();
      final prepared =
          await reopened.call('ssh.prepare', {'id': saved['id']}) as Map;
      expect((prepared['host'] as Map)['hostname'], 'example.test');
      expect(prepared['password'], 'test-password-not-plaintext');
      expect(
        await settings.readAsString(),
        isNot(contains('test-password-not-plaintext')),
      );
    },
  );

  test('changed server keys remain blocked until explicitly removed', () async {
    final platform = create();
    final args = <String, Object?>{
      'hostname': 'example.test',
      'port': 22,
      'algorithm': 'ssh-ed25519',
      'fingerprint': 'SHA256:first',
    };
    expect(
      (await platform.call('ssh.checkHost', args) as Map)['status'],
      'new',
    );
    await platform.call('ssh.saveHost', {...args, 'accept': true});
    expect(
      (await create().call('ssh.checkHost', args) as Map)['status'],
      'match',
    );
    final changed = {...args, 'fingerprint': 'SHA256:second'};
    expect(
      (await platform.call('ssh.checkHost', changed) as Map)['status'],
      'changed',
    );
    await expectLater(
      platform.call('ssh.saveHost', {...changed, 'accept': true}),
      throwsStateError,
    );
  });

  test('editing host metadata keeps its login configuration', () async {
    final platform = create();
    final saved =
        await platform.call('host.save', {
              'nickname': 'before',
              'hostname': 'example.test',
              'username': 'alice',
              'pubkeyId': -2,
              'password': 'kept',
            })
            as Map;
    await platform.call('host.save', {'id': saved['id'], 'nickname': 'after'});
    final prepared =
        await platform.call('ssh.prepare', {'id': saved['id']}) as Map;
    expect((prepared['host'] as Map)['username'], 'alice');
    expect((prepared['host'] as Map)['pubkeyId'], -2);
    expect(prepared['password'], 'kept');
  });

  test('new profile defaults do not identify an existing profile', () async {
    final state = await create().call('snapshot', {}) as Map;
    expect(((state['defaults'] as Map)['profile'] as Map)['id'], 0);
  });

  test('settings use the shared key-value contract', () async {
    final platform = create();
    await platform.call('settings.update', {
      'key': 'themeMode',
      'value': 'LIGHT',
    });
    final state = await platform.call('snapshot', {}) as Map;
    expect((state['preferences'] as Map)['themeMode'], 'LIGHT');
  });

  test('transfer cleanup rejects arbitrary local files', () async {
    final important = await File(
      '${directory.path}/important',
    ).writeAsString('original');
    await expectLater(
      create().call('file.finishTransfer', {'path': important.path}),
      throwsStateError,
    );
    expect(await important.readAsString(), 'original');
  });

  test('cancelled download keeps the chosen existing file', () async {
    final destination = await File(
      '${directory.path}/existing',
    ).writeAsString('original');
    chosenPath = destination.path;
    final platform = create();
    final staged =
        await platform.call('file.prepareDownload', {'name': 'remote.bin'})
            as Map;
    final local = File(staged['path'] as String);
    await local.writeAsString('partial');
    await platform.call('file.finishTransfer', {
      ...Map<String, Object?>.from(staged),
      'save': false,
    });
    expect(await destination.readAsString(), 'original');
    expect(await local.exists(), isFalse);
  });
}
