// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';
import 'package:android_shell_ui/ssh/app_session.dart';

void main() {
  final configFile = Platform.environment['TILDE_SSH_TEST_CONFIG'];
  test(
    'two shells to one host remain independent and closing one preserves the other',
    () async {
      final config = jsonDecode(await File(configFile!).readAsString()) as Map;
      AppSshSession create(int id) {
        final text = StringBuffer();
        final decoder = utf8.decoder.startChunkedConversion(
          StringConversionSink.fromStringSink(text),
        );
        var trusted = false, codecClosed = false;
        return AppSshSession(
          id: id,
          prepared: {
            'host': {
              'id': 1,
              'protocol': 'ssh',
              'hostname': config['host'],
              'port': config['port'],
              'username': config['username'],
              'wantSession': true,
            },
            'profile': {'encoding': 'UTF-8'},
            'keys': [
              {'id': 7},
            ],
          },
          onChanged: () {},
          loadStoredIdentities: ({required id}) async {
            expect(trusted, isTrue);
            return SSHKeyPair.fromPem(
              await File(config['keyFile'] as String).readAsString(),
            );
          },
          platform: (method, args) async {
            switch (method) {
              case 'ssh.checkHost':
                expect(args['fingerprint'], config['fingerprint']);
                trusted = true;
                return {'status': 'match'};
              case 'ssh.encode':
                return Uint8List.fromList(utf8.encode(args['text'] as String));
              case 'ssh.decode':
                decoder.add((args['bytes'] as List).cast<int>());
                if (args['final'] == true) {
                  decoder.close();
                  codecClosed = true;
                }
                final value = text.toString();
                text.clear();
                return value;
              case 'ssh.closeCodec':
                if (!codecClosed) decoder.close();
                codecClosed = true;
                return null;
              default:
                throw StateError(method);
            }
          },
        );
      }

      Future<void> echo(AppSshSession session, String marker) async {
        session.input.sendText('echo $marker');
        session.input.sendKey(TerminalKey.enter);
        for (var attempt = 0; attempt < 200; attempt++) {
          if (session.terminal.buffer.getText().split(marker).length >= 3) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        fail('The live shell did not echo the test marker.');
      }

      final first = create(1), second = create(2);
      try {
        await first.connect().timeout(const Duration(seconds: 30));
        expect(first.sessionOpen, isTrue);
        await second.connect().timeout(const Duration(seconds: 30));
        expect(first.sessionOpen, isTrue);
        expect(second.sessionOpen, isTrue);
        final nonce = DateTime.now().microsecondsSinceEpoch;
        await echo(first, 'TILDE_A_$nonce');
        await echo(second, 'TILDE_B_$nonce');
        await second.disconnect();
        expect(first.sessionOpen, isTrue);
        await echo(first, 'TILDE_A_AFTER_$nonce');
      } finally {
        await first.dispose();
        await second.dispose();
      }
    },
    skip: configFile == null
        ? 'Set TILDE_SSH_TEST_CONFIG for a live SSH host.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
