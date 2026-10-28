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
