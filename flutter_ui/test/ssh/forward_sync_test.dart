// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:android_shell_ui/ssh/ssh_session.dart';
import 'app_session_test.dart' show FakeTransport;

class ForwardTransport extends FakeTransport {
  ForwardTransport({
    required super.endpoints,
    required super.onOutput,
    required super.onState,
    required super.onError,
    required super.wantShell,
    required super.pty,
  });
  final active = <int, SshActiveForward>{};
  final closed = <int>[];
  @override
  List<SshActiveForward> get forwards => active.values.toList();
  @override
  Future<SshActiveForward> enableForward(SshForward config) async =>
      active[config.id] = SshActiveForward(config, config.bindPort);
  @override
  Future<void> disableForward(int id) async {
    closed.add(id);
    active.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'live synchronization replaces changed forwards and closes deleted listeners',
    () async {
      late ForwardTransport transport;
      Map<String, dynamic> config(
        int id,
        String target, {
        bool start = false,
      }) => {
        'id': id,
        'type': 'local',
        'sourceAddr': 'localhost',
        'sourcePort': 10000 + id,
        'destAddr': target,
        'destPort': 22,
        'startEnabled': start,
      };
      final session = AppSshSession(
        id: 1,
        prepared: {
          'host': {'id': 1, 'hostname': 'host', 'username': 'user'},
          'forwards': [config(1, 'old'), config(2, 'delete')],
        },
        onChanged: () {},
        platform: (method, args) async => method == 'ssh.decode' ? '' : null,
        transportFactory:
            ({
              required endpoints,
              required onOutput,
              required onState,
              required onError,
              required wantShell,
              required pty,
            }) => transport = ForwardTransport(
              endpoints: endpoints,
              onOutput: onOutput,
              onState: onState,
              onError: onError,
              wantShell: wantShell,
              pty: pty,
            ),
      );
      try {
        await session.connect();
        await session.setForward(1, true);
        await session.setForward(2, true);
        await session.synchronizeForwards([
          config(1, 'new'),
          config(3, 'added', start: true),
        ]);
        expect(transport.closed, [1, 2]);
        expect(transport.active.keys, [1]);
        expect(transport.active[1]!.config.targetHost, 'new');
        expect(session.forwards.map((row) => row['id']), [1, 3]);
        expect(
          session.forwards.every((row) => row['startEnabled'] == false),
          isTrue,
        );
        await session.setForward(3, false);
        await session.synchronizeForwards([
          config(1, 'new'),
          config(3, 'added', start: true),
        ]);
        expect(transport.active.containsKey(3), isFalse);
      } finally {
        await session.dispose();
      }
    },
  );
}
