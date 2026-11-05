// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:typed_data';
import 'package:android_shell_ui/platform/ssh_keys.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'app_session_test.dart' show FakeTransport;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final cancelled in [false, true]) {
    test(
      'protected password unlock requires host trust and has no fallback ($cancelled)',
      () async {
        final calls = <String>[];
        final session = AppSshSession(
          id: 7,
          prepared: {
            'host': {
              'id': 3,
              'hostname': 'example.com',
              'port': 22,
              'username': 'alice',
            },
            'profile': {'encoding': 'UTF-8'},
            'passkeyPasswordId': 9,
            'passkeyOnly': true,
          },
          platform: (method, args) async {
            calls.add(method);
            if (method == 'ssh.checkHost') return {'status': 'match'};
            if (method == 'ssh.unlockPassword') {
              expect(args, {
                'id': 9,
                'hostname': 'example.com',
                'port': 22,
                'username': 'alice',
              });
              return cancelled ? null : 'test-password';
            }
            if (method == 'ssh.closeCodec') return null;
            throw StateError(method);
          },
          onChanged: () {},
          transportFactory:
              ({
                required endpoints,
                required onOutput,
                required onState,
                required onError,
                required wantShell,
                required pty,
              }) =>
                  FakeTransport(
                      endpoints: endpoints,
                      onOutput: onOutput,
                      onState: onState,
                      onError: onError,
                      wantShell: wantShell,
                      pty: pty,
                    )
                    ..onConnect = (transport) async {
                      final endpoint = transport.endpoints.single;
                      expect(endpoint.preferredAuthMethods, [
                        SSHAuthMethod.none,
                        SSHAuthMethod.password,
                      ]);
                      await expectLater(
                        endpoint.onPassword!(),
                        throwsStateError,
                      );
                      expect(calls, isEmpty);
                      expect(
                        await endpoint.verifyHostKey(
                          'ssh-ed25519',
                          Uint8List.fromList('SHA256:test'.codeUnits),
                        ),
                        isTrue,
                      );
                      if (cancelled) {
                        await expectLater(
                          endpoint.onPassword!(),
                          throwsA(isA<SshKeyAuthenticationCancelled>()),
                        );
                      } else {
                        expect(await endpoint.onPassword!(), 'test-password');
                        await expectLater(
                          endpoint.onPassword!(),
                          throwsA(isA<SSHAuthFailError>()),
                        );
                      }
                    },
        );
        try {
          await session.connect();
          expect(
            calls.where((value) => value == 'ssh.unlockPassword').length,
            1,
          );
          expect(session.prompts, isEmpty);
          expect(session.record.toString(), isNot(contains('test-password')));
        } finally {
          await session.dispose();
        }
      },
    );
  }
}
