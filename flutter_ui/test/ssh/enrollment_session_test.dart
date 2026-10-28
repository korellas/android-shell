// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'app_session_test.dart' show FakeTransport;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'verification pins trust and preserves jumps with selected key only',
    () async {
      final transports = <FakeTransport>[];
      final pin = Uint8List.fromList(utf8.encode('SHA256:pinned'));
      final selected = SSHIdentity.custom(
        type: 'ssh-ed25519',
        publicKey: SSHRawHostKey(Uint8List.fromList([1])),
        signer: (_) => SSHRawSignature(Uint8List(0)),
      );
      final session = AppSshSession(
        id: 1,
        prepared: {
          'host': {
            'id': 1,
            'hostname': 'target',
            'port': 22,
            'username': 'user',
            'jumpHostId': 2,
          },
          'jumps': [
            {
              'host': {
                'id': 2,
                'hostname': 'jump',
                'port': 2222,
                'username': 'jump-user',
              },
            },
          ],
        },
        onChanged: () {},
        loadStoredIdentities: ({required id}) async {
          expect(id, 3);
          return [selected];
        },
        lookupStoredKey: (_) => {'id': 3},
        platform: (method, args) async {
          switch (method) {
            case 'ssh.checkHost':
              return {'status': 'match'};
            case 'ssh.decode':
              return '';
            default:
              return null;
          }
        },
        transportFactory:
            ({
              required endpoints,
              required onOutput,
              required onState,
              required onError,
              required wantShell,
              required pty,
            }) {
              final transport = FakeTransport(
                endpoints: endpoints,
                onOutput: onOutput,
                onState: onState,
                onError: onError,
                wantShell: wantShell,
                pty: pty,
              );
              transport.onConnect = (_) async {
                for (final endpoint in endpoints) {
                  expect(
                    await endpoint.verifyHostKey('ssh-ed25519', pin),
                    isTrue,
                  );
                }
              };
              transports.add(transport);
              return transport;
            },
      );
      try {
        await session.connect();
        expect(session.canEnroll, isTrue);
        final valid = session.captureEnrollmentValidity();
        expect(valid(), isTrue);
        expect(await session.verifyEnrollmentKey(3), 'VERIFIED');
        final verification = transports.last;
        expect(verification.wantShell, isFalse);
        expect(verification.endpoints.map((endpoint) => endpoint.host), [
          'jump',
          'target',
        ]);
        final target = verification.endpoints.last;
        expect(target.identities, [selected]);
        expect(target.preferredAuthMethods, [SSHAuthMethod.publicKey]);
        expect(target.loadIdentities, isNull);
        expect(target.onPassword, isNull);
        expect(target.onInteractive, isNull);
        expect(target.onPasswordChange, isNull);
        expect(await target.verifyHostKey('ssh-rsa', pin), isFalse);
        expect(
          await target.verifyHostKey('ssh-ed25519', Uint8List.fromList([1])),
          isFalse,
        );
        await session.disconnect();
        expect(valid(), isFalse);
        await session.connect();
        expect(session.canEnroll, isTrue);
        expect(valid(), isFalse);
      } finally {
        await session.dispose();
      }
    },
  );
}
