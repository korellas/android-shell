// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'app_session_test.dart' show FakeTransport;

void main() {
  late AppSshSession session;
  late FakeTransport transport;
  late List<SSHIdentity> offered;
  AppSshSession create(SshSystemIdentityLoader loader, {bool shell = true}) =>
      AppSshSession(
        id: 1,
        prepared: {
          'host': {
            'hostname': 'example.test',
            'username': 'alice',
            'port': 2222,
            'wantSession': shell,
          },
          'keys': [],
        },
        platform: (_, _) async => null,
        onChanged: () {},
        loadSystemIdentities: loader,
        transportFactory:
            ({
              required endpoints,
              required onOutput,
              required onState,
              required onError,
              required wantShell,
              required pty,
            }) {
              transport =
                  FakeTransport(
                      endpoints: endpoints,
                      onOutput: onOutput,
                      onState: onState,
                      onError: onError,
                      wantShell: wantShell,
                      pty: pty,
                    )
                    ..onConnect = (t) async {
                      offered = await t.endpoints.single.loadIdentities!();
                    };
              return transport;
            },
      );
  tearDown(() async => session.dispose());
  for (final shell in [true, false]) {
    test(
      'system key provider authenticates ${shell ? 'terminal' : 'SFTP'} without a registered key',
      () async {
        final key = SSHKeyPair.fromPem(
          await File(
            'third_party/dartssh2/test/fixtures/ssh-ed25519/id_ed25519',
          ).readAsString(),
        ).single;
        session = create((config, _) async {
          expect(config['host']['username'], 'alice');
          return [key];
        }, shell: shell);
        await session.connect();
        expect(offered, [key]);
        expect(session.connected, isTrue);
        expect(transport.wantShell, shell);
      },
    );
  }
  test(
    'system key passphrase uses the session prompt and is not stored in preparation',
    () async {
      String? entered;
      session = create((_, ask) async {
        entered = await ask('/keys/custom.key');
        return [];
      });
      final connecting = session.connect();
      while (session.prompts.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(session.prompts.single['password'], isTrue);
      expect(session.prompts.single['hint'], 'custom.key');
      session.respond(session.prompts.single['token'] as String, 'test-secret');
      await connecting;
      expect(entered, 'test-secret');
      expect(session.prepared.toString(), isNot(contains('test-secret')));
    },
  );
}
