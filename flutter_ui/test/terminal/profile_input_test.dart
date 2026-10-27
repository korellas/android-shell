// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:android_shell_ui/terminal/local_session.dart';
import 'package:android_shell_ui/terminal/app_terminal_session.dart';
import '../ssh/app_session_test.dart' show FakeTransport;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final local in [false, true]) {
    test(
      '${local ? 'local' : 'SSH'} applies Delete profile on construction and reused connection',
      () async {
        final prepared = <String, dynamic>{
          'host': {'hostname': 'example', 'username': 'user'},
          'profile': {'delKey': 'backspace'},
        };
        Future<Object?> platform(
          String method,
          Map<String, Object?> args,
        ) async => method == 'ssh.decode' ? '' : null;
        final AppTerminalSession session = local
            ? AppLocalSession(
                id: 1,
                prepared: prepared,
                platform: platform,
                events: const Stream.empty(),
                onChanged: () {},
              )
            : AppSshSession(
                id: 1,
                prepared: prepared,
                platform: platform,
                onChanged: () {},
                transportFactory:
                    ({
                      required endpoints,
                      required onOutput,
                      required onState,
                      required onError,
                      required wantShell,
                      required pty,
                    }) => FakeTransport(
                      endpoints: endpoints,
                      onOutput: onOutput,
                      onState: onState,
                      onError: onError,
                      wantShell: wantShell,
                      pty: pty,
                    ),
              );
        final output = <String>[];
        session.terminal.onOutput = output.add;
        try {
          session.input.sendKey(TerminalKey.backspace);
          session.input.sendKey(TerminalKey.delete);
          expect(output.join(), '\b\x7f');
          await session.connect();
          await session.disconnect();
          if (session is AppSshSession) {
            session.refreshPrepared({
              ...prepared,
              'profile': {'delKey': 'del'},
            });
          } else {
            prepared['profile'] = {'delKey': 'del'};
          }
          await session.connect();
          output.clear();
          session.input.sendKey(TerminalKey.backspace);
          session.input.sendKey(TerminalKey.delete);
          expect(output.join(), '\x7f\x1b[3~');
        } finally {
          await session.dispose();
        }
      },
    );
  }
}
