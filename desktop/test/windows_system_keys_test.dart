// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilde_desktop/windows_system_keys.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tilde-system-keys-');
  });
  tearDown(() async => directory.delete(recursive: true));
  final config = <String, dynamic>{
    'host': {
      'hostname': 'alias.example',
      'username': 'remote-user',
      'port': 2222,
    },
    'keys': <Map<String, dynamic>>[],
  };
  final fixtureRoot = Directory(
    '../flutter_ui/third_party/dartssh2/test/fixtures',
  );
  Future<File> key(String name, {bool encrypted = false}) async {
    final target = File('${directory.path}/$name');
    await target.parent.create(recursive: true);
    return File(
      '${fixtureRoot.path}/${encrypted ? 'ssh-ed25519-passphrase' : 'ssh-ed25519'}/id_ed25519',
    ).copy(target.path);
  }

  test(
    'OpenSSH config selects a renamed key in the actual user profile',
    () async {
      await key('.ssh/custom login key');
      final calls = <List<String>>[];
      final identities = await loadWindowsSystemKeys(
        config,
        (_) async => fail('Unencrypted key must not prompt'),
        environment: {
          'USERPROFILE': directory.path,
          'USERNAME': 'different-local-user',
        },
        query: (arguments) async {
          calls.add(arguments);
          return ProcessResult(
            1,
            0,
            'hostname actual.example\nuser remote-user\nport 2222\nidentityfile ~/.ssh/custom login key\nidentityfile ~/.ssh/missing\n',
            '',
          );
        },
      );
      expect(calls.single, [
        '-G',
        '-T',
        '-p',
        '2222',
        '-l',
        'remote-user',
        '--',
        'alias.example',
      ]);
      expect(identities.single.type, 'ssh-ed25519');
    },
  );
  test('host tokens resolve using OpenSSH evaluated settings', () async {
    await key('.ssh/actual.example-remote-user-2222');
    final identities = await loadWindowsSystemKeys(
      config,
      (_) async => '',
      environment: {'USERPROFILE': directory.path},
      query: (_) async => ProcessResult(
        1,
        0,
        'hostname actual.example\nuser remote-user\nport 2222\nidentityfile %d/.ssh/%h-%r-%p\n',
        '',
      ),
    );
    expect(identities, hasLength(1));
  });
  test(
    'explicit key choice and keys disabled do not query system identities',
    () async {
      for (final host in [
        {'pubkeyId': -2},
        {'pubkeyId': 11},
        {'useKeys': false},
      ]) {
        final identities = await loadWindowsSystemKeys(
          {
            ...config,
            'host': {...config['host'] as Map, ...host},
          },
          (_) async => '',
          query: (_) async =>
              fail('Must preserve explicit authentication selection'),
        );
        expect(identities, isEmpty);
      }
    },
  );
  test('registered paths are not loaded a second time', () async {
    final existing = await key('registered');
    final identities = await loadWindowsSystemKeys(
      {
        ...config,
        'keys': [
          {'path': existing.path},
        ],
      },
      (_) async => '',
      query: (_) async => ProcessResult(
        1,
        0,
        'identityfile ${existing.path}\nidentityfile ${existing.path}\n',
        '',
      ),
    );
    expect(identities, isEmpty);
  });
  test(
    'encrypted system keys use the existing passphrase prompt without saving files',
    () async {
      final encrypted = await key('encrypted', encrypted: true);
      final before = await encrypted.readAsBytes();
      final password = (await File(
        '${fixtureRoot.path}/ssh-ed25519-passphrase/passphrase',
      ).readAsString()).trim();
      final prompted = <String>[];
      final identities = await loadWindowsSystemKeys(
        config,
        (path) async {
          prompted.add(path);
          return password;
        },
        query: (_) async =>
            ProcessResult(1, 0, 'identityfile ${encrypted.path}\n', ''),
      );
      expect(identities.single, isA<SSHIdentity>());
      expect(prompted, [await encrypted.resolveSymbolicLinks()]);
      expect(await encrypted.readAsBytes(), before);
    },
  );
  test(
    'configuration failure is reported rather than guessing key filenames',
    () async {
      await expectLater(
        loadWindowsSystemKeys(
          config,
          (_) async => '',
          query: (_) async => ProcessResult(1, 255, '', 'bad configuration'),
        ),
        throwsStateError,
      );
    },
  );
}
