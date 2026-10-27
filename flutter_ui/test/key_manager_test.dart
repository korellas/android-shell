// Copyright 2026 Kenny Root
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/platform/key_manager.dart';
import 'package:dartssh2/dartssh2.dart';

void main() {
  test(
    'Ed25519 generation persists decryptable encrypted OpenSSH and public wire',
    () async {
      Map<String, Object?>? saved;
      final manager = KeyManager((method, args) async {
        expect(method, 'key.storageSave');
        saved = args;
        return {...args, 'id': 1};
      });
      await manager.operation('key.generate', {
        'nickname': 'ed',
        'type': 'ED25519',
        'password': 'secret',
      });
      expect(saved!['encrypted'], true);
      final pair = SSHKeyPair.fromPem(saved!['pem'] as String, 'secret').single;
      expect(pair.name, 'ssh-ed25519');
      expect(pair.toPublicKey().encode(), saved!['publicKey']);
    },
  );

  test(
    'startup prompts retain failed unlock and cache successful identities',
    () async {
      final pair = OpenSSHEd25519KeyPair(Uint8List(32), Uint8List(64), '');
      var reads = 0;
      final manager = KeyManager((method, args) async {
        expect(method, 'ssh.keyMaterial');
        reads++;
        if (args['password'] != 'secret') throw StateError('wrong password');
        return {'pem': pair.toPem(), 'biometric': false};
      });
      final key = <String, Object?>{
        'id': 1,
        'nickname': 'ed',
        'type': 'IMPORTED',
        'encrypted': true,
        'startup': true,
      };
      await manager.initializeStartup([key]);
      expect(manager.pendingStartup, [key]);
      await expectLater(
        manager.operation('key.startup', {'id': 1, 'password': 'wrong'}),
        throwsStateError,
      );
      expect(manager.pendingStartup, [key]);
      await manager.operation('key.startup', {'id': 1, 'password': 'secret'});
      expect(manager.pendingStartup, isEmpty);
      await manager.identities(id: 1);
      expect(reads, 2);
      final decorated = (manager.decorateKeys([key])).single;
      expect(decorated['loaded'], true);
      expect(decorated['fingerprint'], startsWith('SHA256:'));
      await manager.operation('key.load', {'id': 1});
      expect((manager.decorateKeys([key])).single['loaded'], false);
    },
  );
}
