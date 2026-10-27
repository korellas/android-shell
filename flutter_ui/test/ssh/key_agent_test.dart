// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/ssh_message.dart';
import 'package:pinenacl/ed25519.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/ssh/key_agent.dart';

void main() {
  test(
    'uses live loaded roster and confirms only signature requests',
    () async {
      var signed = 0, confirmed = 0;
      var allow = false;
      final public =
          (SSHMessageWriter()
                ..writeUtf8('ssh-ed25519')
                ..writeString(Uint8List(32)))
              .takeBytes();
      final identity = SSHIdentity.custom(
        type: 'ssh-ed25519',
        publicKey: SSHRawHostKey(public),
        signer: (data) {
          signed++;
          return SSHRawSignature(Uint8List.fromList([1]));
        },
      );
      var loaded = [
        SshAgentKey([identity], 'protected', confirmation: true),
      ];
      final agent = AppSshKeyAgent(
        mode: 'confirm',
        loadKeys: () async => loaded,
        confirm: (_) async {
          confirmed++;
          return allow;
        },
      );
      final roster = await agent.handleRequest(
        Uint8List.fromList([SSHAgentProtocol.requestIdentities]),
      );
      final reader = SSHMessageReader(roster);
      expect(reader.readUint8(), SSHAgentProtocol.identitiesAnswer);
      expect(reader.readUint32(), 1);
      expect(confirmed, 0);
      final request =
          (SSHMessageWriter()
                ..writeUint8(SSHAgentProtocol.signRequest)
                ..writeString(public)
                ..writeString(Uint8List.fromList([42]))
                ..writeUint32(0))
              .takeBytes();
      expect(await agent.handleRequest(request), [SSHAgentProtocol.failure]);
      expect(signed, 0);
      allow = true;
      expect(
        (await agent.handleRequest(request)).first,
        SSHAgentProtocol.signResponse,
      );
      expect(signed, 1);
      loaded = [];
      expect(await agent.handleRequest(request), [SSHAgentProtocol.failure]);
      expect(signed, 1);
      expect(await agent.handleRequest(Uint8List.fromList([17])), [
        SSHAgentProtocol.failure,
      ]);
      expect(await agent.handleRequest(Uint8List.fromList([13, 255])), [
        SSHAgentProtocol.failure,
      ]);
    },
  );
  test(
    'ephemeral add/remove and agent lock preserve loaded-key permissions',
    () async {
      var roster = <SshAgentKey>[];
      final pair = ed.SigningKey.fromSeed(
        Uint8List.fromList(List.generate(32, (i) => i)),
      );
      final public = pair.verifyKey.asTypedList;
      final private = Uint8List.fromList([...pair.seed, ...public]);
      var removedAll = false;
      final agent = AppSshKeyAgent(
        mode: 'confirm',
        loadKeys: () async => roster,
        confirm: (_) async => true,
        addKey: (key, confirmation) async {
          roster.add(
            SshAgentKey([key], key.comment ?? '', confirmation: confirmation),
          );
          return true;
        },
        removeKey: (blob) async {
          roster.removeWhere(
            (key) =>
                key.identities.first.toPublicKey().encode().join(',') ==
                blob.join(','),
          );
          return true;
        },
        removeAllKeys: () async {
          removedAll = true;
          roster.clear();
          return true;
        },
      );
      final add =
          (SSHMessageWriter()
                ..writeUint8(25)
                ..writeUtf8('ssh-ed25519')
                ..writeString(public)
                ..writeString(private)
                ..writeUtf8('temporary')
                ..writeUint8(2))
              .takeBytes();
      expect(await agent.handleRequest(Uint8List.fromList([...add, 255])), [5]);
      expect(roster, isEmpty);
      expect(await agent.handleRequest(add), [6]);
      expect(roster.single.confirmation, isTrue);
      final blob = roster.single.identities.first.toPublicKey().encode();
      final sign =
          (SSHMessageWriter()
                ..writeUint8(13)
                ..writeString(blob)
                ..writeString(Uint8List.fromList([1]))
                ..writeUint32(0))
              .takeBytes();
      expect((await agent.handleRequest(sign)).first, 14);
      Uint8List password(int type, String password) =>
          (SSHMessageWriter()
                ..writeUint8(type)
                ..writeUtf8(password))
              .takeBytes();
      expect(await agent.handleRequest(password(22, 'secret')), [6]);
      expect(await agent.handleRequest(sign), [5]);
      expect(await agent.handleRequest(add), [5]);
      final locked = SSHMessageReader(
        await agent.handleRequest(Uint8List.fromList([11])),
      );
      expect(locked.readUint8(), 12);
      expect(locked.readUint32(), 0);
      expect(await agent.handleRequest(password(23, 'wrong')), [5]);
      expect(await agent.handleRequest(password(23, 'secret')), [6]);
      expect(
        await agent.handleRequest(
          (SSHMessageWriter()
                ..writeUint8(18)
                ..writeString(blob))
              .takeBytes(),
        ),
        [6],
      );
      expect(roster, isEmpty);
      expect(await agent.handleRequest(Uint8List.fromList([19])), [6]);
      expect(removedAll, isTrue);
      final malformed =
          (SSHMessageWriter()
                ..writeUint8(17)
                ..writeUtf8('ssh-ed25519')
                ..writeString(Uint8List(1))
                ..writeString(private)
                ..writeUtf8('invalid'))
              .takeBytes();
      expect(await agent.handleRequest(malformed), [5]);
      expect(roster, isEmpty);
    },
  );
}
