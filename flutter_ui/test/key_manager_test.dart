// Copyright 2026 Kenny Root
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/platform/key_manager.dart';
import 'package:dartssh2/dartssh2.dart';

void main() {
  test('named pasted key is saved without asking for its name again', () async {
    final pair = OpenSSHEd25519KeyPair(Uint8List(32), Uint8List(64), '');
    Map<String, Object?>? saved;
    final manager = KeyManager((method, args) async {
      expect(method, 'key.storageSave');
      saved = args;
      return {...args, 'id': 1};
    });
    await manager.operation('key.import', {
      'text': pair.toPem(),
      'nickname': 'work',
    });
    expect(saved?['nickname'], 'work');
    expect(manager.state['pendingNickname'], isNull);
    expect(manager.state['importPassword'], isNull);
  });

  test('picked key still allows choosing its name once', () async {
    final pair = OpenSSHEd25519KeyPair(Uint8List(32), Uint8List(64), '');
    final manager = KeyManager((method, args) async {
      expect(method, 'key.storagePick');
      return {'text': pair.toPem(), 'nickname': 'id_ed25519'};
    });
    await manager.operation('key.import', {});
    expect(manager.state['pendingNickname'], 'id_ed25519');
    await manager.operation('key.importCancel', {});
    expect(manager.state['pendingNickname'], isNull);
  });

  test('successful connection unlock follows the memory preference', () async {
    final pair = OpenSSHEd25519KeyPair(Uint8List(32), Uint8List(64), '');
    var remember = false;
    var reads = 0;
    final manager = KeyManager((method, args) async {
      expect(method, 'ssh.keyMaterial');
      reads++;
      if (args['password'] != 'secret') throw StateError('wrong password');
      return {'pem': pair.toPem(), 'biometric': false};
    }, rememberUnlocked: () => remember);
    await manager.identities(id: 1, password: 'secret');
    expect(manager.loadedIdentities, isEmpty);
    remember = true;
    await expectLater(
      manager.identities(id: 1, password: 'wrong'),
      throwsStateError,
    );
    expect(manager.loadedIdentities, isEmpty);
    final unlocked = await manager.identities(id: 1, password: 'secret');
    expect(identical(await manager.identities(id: 1), unlocked), true);
    expect(reads, 3);
    manager.forgetStoredKeys();
    expect(manager.loadedIdentities, isEmpty);
  });

  test(
    'forgetting keys invalidates a pending unlock but keeps agent keys',
    () async {
      final pair = OpenSSHEd25519KeyPair(Uint8List(32), Uint8List(64), '');
      final material = Completer<Object?>();
      final manager = KeyManager(
        (method, args) => material.future,
        rememberUnlocked: () => true,
      );
      await manager.addAgentKey(pair, false);
      final pending = manager.identities(id: 1);
      manager.forgetStoredKeys();
      material.complete({'pem': pair.toPem(), 'biometric': false});
      await pending;
      expect(manager.loadedIdentities.keys, everyElement(lessThan(0)));
      expect(manager.loadedIdentities, hasLength(1));
    },
  );

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

  test('saving key metadata preserves the unlocked identity', () async {
    final pair = OpenSSHEd25519KeyPair(Uint8List(32), Uint8List(64), '');
    var reads = 0;
    final manager = KeyManager((method, args) async {
      if (method == 'ssh.keyMaterial') {
        reads++;
        expect(args['password'], 'secret');
        return {'pem': pair.toPem(), 'biometric': false};
      }
      expect(method, 'key.storageSave');
      expect(args.containsKey('pem'), false);
      return args;
    });
    await manager.operation('key.load', {'id': 1, 'password': 'secret'});
    final unlocked = await manager.identities(id: 1);
    final saved = Map<String, Object?>.from(
      await manager.operation('key.save', {
            'id': 1,
            'nickname': 'renamed',
            'confirmation': true,
          })
          as Map,
    );
    expect(manager.decorateKeys([saved]).single['loaded'], true);
    expect(manager.decorateKeys([saved]).single['confirmation'], true);
    expect(identical(await manager.identities(id: 1), unlocked), true);
    expect(reads, 1);
  });

  test(
    'replacing stored key material still clears its unlocked copy',
    () async {
      final pair = OpenSSHEd25519KeyPair(Uint8List(32), Uint8List(64), '');
      final manager = KeyManager((method, args) async {
        if (method == 'ssh.keyMaterial') {
          return {'pem': pair.toPem(), 'biometric': false};
        }
        expect(method, 'key.storageSave');
        expect(args['pem'], isA<String>());
        return args;
      });
      await manager.operation('key.load', {'id': 1});
      await manager.operation('key.save', {'id': 1, 'newPassword': ''});
      expect(manager.loadedIdentities, isEmpty);
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
