// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:typed_data';
import 'package:android_shell_ui/platform/key_manager.dart';
import 'package:android_shell_ui/platform/ssh_keys.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('password creation stays native and returns metadata only', () async {
    final manager = KeyManager((method, args) async {
      expect(method, 'key.storageGenerateProtectedPasskey');
      expect(args['kind'], 'password');
      expect(args['hostname'], 'example.com');
      return {'id': 10, 'passkeyPassword': true};
    }, passkeysAvailable: () => true);
    expect(
      await manager.operation('key.generate', {
        'nickname': 'login',
        'kind': 'password',
        'hostname': 'example.com',
        'port': 22,
        'username': 'alice',
        'password': 'test-input',
      }),
      {'id': 10, 'passkeyPassword': true},
    );
  });

  test('encrypted credential restore requires native verification', () async {
    final calls = <String>[];
    final manager = KeyManager((method, args) async {
      calls.add(method);
      if (method == 'key.storageReadPasskey') {
        return '{"format":"tilde-passkey-credential"}';
      }
      expect(args, {'text': '{"format":"tilde-passkey-credential"}'});
      return {'id': 12};
    });
    expect(await manager.operation('key.restorePasskey', {}), {'id': 12});
    expect(calls, [
      'key.storageReadPasskey',
      'key.storageRestoreProtectedPasskey',
    ]);
  });

  test('passkey-unlocked SSH key uses a standard signature', () async {
    final der = ASN1Sequence()
      ..add(ASN1Integer(BigInt.from(128)))
      ..add(ASN1Integer(BigInt.from(255)));
    final adapter = SshKeyAdapter((method, args) async {
      if (method == 'ssh.keyMaterial') {
        return {
          'passkeyWrapped': true,
          'publicKey': base64Decode(
            'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEAR6QO8TsrpSAtAdvEjSUgLj+VamIhqw6LJjcH1JaMTCZHlVQshahtgd3XUfbk7uH/IO0PdO6HmgPp0D3x2+aZQ==',
          ),
        };
      }
      expect(args['algorithm'], 'ecdsa-sha2-nistp256');
      return {'signature': der.encodedBytes};
    });
    final identity = (await adapter.identities(id: 7)).single;
    expect(identity.type, 'ecdsa-sha2-nistp256');
    final encoded = (await identity.sign(
      Uint8List.fromList([1, 2, 3]),
    )).encode();
    final length = ByteData.sublistView(encoded).getUint32(0);
    expect(utf8.decode(encoded.sublist(4, 4 + length)), 'ecdsa-sha2-nistp256');
  });
}
