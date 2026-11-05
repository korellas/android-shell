// Copyright 2026 Kenny Root
import 'dart:convert';
import 'dart:typed_data';

import 'package:android_shell_ui/platform/key_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final publicWire = Uint8List.fromList([
    ..._sshString(utf8.encode('ecdsa-sha2-nistp256')),
    ..._sshString(utf8.encode('nistp256')),
    ..._sshString([4, ...List<int>.filled(64, 1)]),
  ]);

  test('software private keys stay quarantined and deletable', () async {
    final calls = <String>[];
    final manager = KeyManager((method, args) async {
      calls.add(method);
      return null;
    });
    final key = manager.decorateKeys([
      {
        'id': 7,
        'nickname': 'legacy',
        'type': 'IMPORTED',
        'eligible': false,
        'biometric': false,
        'publicBytes': publicWire,
      },
    ]).single;
    expect(key['supported'], isFalse);
    expect(key['supportMessage'], '기존 개인키 · 사용 중지');
    await manager.operation('key.delete', {'id': 7});
    expect(calls, ['key.storageDelete']);
  });

  test('passkey generation delegates protection to native storage', () async {
    final calls = <String>[];
    final manager = KeyManager((method, args) async {
      calls.add(method);
      expect(method, 'key.storageGenerateProtectedPasskey');
      expect(args, {'nickname': 'work', 'kind': 'key'});
      return {'id': 9};
    }, passkeysAvailable: () => true);
    expect(await manager.operation('key.generate', {'nickname': 'work'}), {
      'id': 9,
    });
    expect(calls, ['key.storageGenerateProtectedPasskey']);
  });

  test(
    'native credential failures do not try another storage mechanism',
    () async {
      final calls = <String>[];
      final manager = KeyManager((method, args) async {
        calls.add(method);
        expect(method, 'key.storageGenerateProtectedPasskey');
        throw const FormatException('Invalid credential');
      }, passkeysAvailable: () => true);
      await expectLater(
        manager.operation('key.generate', {'nickname': 'work'}),
        throwsFormatException,
      );
      expect(calls, ['key.storageGenerateProtectedPasskey']);
    },
  );

  test('cancelled passkey creation writes no metadata', () async {
    final calls = <String>[];
    final manager = KeyManager((method, args) async {
      calls.add(method);
      expect(method, 'key.storageGenerateProtectedPasskey');
      return null;
    }, passkeysAvailable: () => true);
    expect(
      await manager.operation('key.generate', {'nickname': 'work'}),
      isNull,
    );
    expect(calls, ['key.storageGenerateProtectedPasskey']);
  });

  test('generation always requests device-bound P-256', () async {
    Map<String, Object?>? generated;
    final manager = KeyManager((method, args) async {
      expect(method, 'key.storageGenerate');
      generated = args;
      return {'id': 1};
    });
    await manager.operation('key.generate', {
      'nickname': 'work',
      'type': 'RSA',
      'bits': 4096,
    });
    expect(generated, {'nickname': 'work', 'type': 'EC', 'bits': 256});
  });

  test('passkey public metadata retains its OpenSSH security-key type', () {
    final manager = KeyManager((method, args) async => null);
    final key = manager.decorateKeys([
      {
        'id': 8,
        'nickname': 'work',
        'type': 'PASSKEY',
        'passkey': true,
        'rpId': 'korellas.github.io',
        'eligible': true,
        'publicBytes': base64Decode(
          'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEAR6QO8TsrpSAtAdvEjSUgLj+VamIhqw6LJjcH1JaMTCZHlVQshahtgd3XUfbk7uH/IO0PdO6HmgPp0D3x2+aZQ==',
        ),
      },
    ]).single;
    expect(key['publicKey'], startsWith('sk-ecdsa-sha2-nistp256@openssh.com '));
    expect(key['displayType'], 'Passkey');
    expect(key['supported'], isTrue);
  });

  test('private-key copy and export formats are rejected locally', () async {
    final manager = KeyManager((method, args) async => null);
    for (final method in ['key.copy', 'key.export']) {
      await expectLater(
        manager.operation(method, {'id': 1, 'format': 'private'}),
        throwsUnsupportedError,
      );
    }
  });
}

List<int> _sshString(List<int> value) => [
  value.length >> 24,
  value.length >> 16 & 0xff,
  value.length >> 8 & 0xff,
  value.length & 0xff,
  ...value,
];
