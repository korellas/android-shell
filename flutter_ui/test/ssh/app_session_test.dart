// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:android_shell_ui/ssh/ssh_session.dart';

class FakeTransport extends SshSession {
  FakeTransport({
    required super.endpoints,
    required super.onOutput,
    required super.onState,
    required super.onError,
    required super.wantShell,
    required super.pty,
  });
  bool opened = false;
  final writes = <List<int>>[];
  Future<void> Function(FakeTransport)? onConnect;
  @override
  bool get sessionOpen => opened;
  @override
  Future<void> connect() async {
    await onConnect?.call(this);
    opened = true;
    onState?.call(SshSessionState.connected);
  }

  @override
  Future<void> write(List<int> bytes) async {
    writes.add(bytes);
  }

  @override
  Future<void> close() async {
    if (opened) onOutput(Uint8List.fromList(utf8.encode('tail')));
    opened = false;
    onState?.call(SshSessionState.closed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSshSession session;
  late List<FakeTransport> transports;
  late List<String> calls;
  late Map<String, dynamic> prepared;
  Future<Object?> platform(String method, Map<String, Object?> args) async {
    calls.add('$method:${args['final']}');
    switch (method) {
      case 'ssh.decode':
        return utf8.decode((args['bytes'] as List).cast<int>());
      case 'ssh.encode':
        return Uint8List.fromList(utf8.encode(args['text'] as String));
      case 'ssh.checkHost':
        expect(args['fingerprint'], 'SHA256:${List.filled(43, 'A').join()}');
        return {'status': 'changed'};
      case 'ssh.saveHost':
        expect(args['replace'], true);
        return {};
      case 'ssh.closeCodec':
        return null;
      default:
        throw StateError(method);
    }
  }

  AppSshSession create({
    Future<void> Function(FakeTransport)? connect,
    Future<List<SSHIdentity>> Function({required int id, String? password})?
    loadIdentities,
  }) => AppSshSession(
    id: 7,
    prepared: prepared,
    platform: platform,
    onChanged: () {},
    loadStoredIdentities: loadIdentities,
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
          )..onConnect = connect;
          transports.add(transport);
          return transport;
        },
  );
  setUp(() {
    transports = [];
    calls = [];
    prepared = {
      'host': {
        'id': 3,
        'hostname': 'localhost',
        'port': 22,
        'username': 'user',
        'nickname': 'test',
        'wantSession': true,
      },
      'profile': {'encoding': 'UTF-8', 'inlineImages': 'off'},
    };
  });
  tearDown(() async {
    await session.dispose();
  });
  test('legacy SOCKS4 startup cannot abort a valid SSH connection', () async {
    prepared['forwards'] = [
      {'id': 8, 'type': 'dynamic4', 'startEnabled': true},
    ];
    session = create();
    await session.connect();
    expect(session.sessionOpen, true);
    expect(session.forwards.single['startEnabled'], true);
    expect(session.forwards.single['enabled'], false);
    await expectLater(session.setForward(8, true), throwsUnsupportedError);
  });
  test(
    'serializes codec work, preserves final output and terminal across reconnect',
    () async {
      session = create();
      await session.connect();
      final terminal = session.terminal;
      transports.single.onOutput(Uint8List.fromList(utf8.encode('first')));
      transports.single.onOutput(Uint8List.fromList(utf8.encode('second')));
      await session.invoke('session.sendText', {'text': 'hello'});
      expect(utf8.decode(transports.single.writes.single), 'hello');
      await session.disconnect();
      expect(terminal.buffer.getText(), contains('firstsecondtail'));
      expect(calls.where((call) => call.startsWith('ssh.decode')).toList(), [
        'ssh.decode:false',
        'ssh.decode:false',
        'ssh.decode:false',
        'ssh.decode:true',
      ]);
      expect(calls.last, 'ssh.closeCodec:null');
      await session.reconnect();
      expect(identical(session.terminal, terminal), true);
      expect(transports.length, 2);
    },
  );
  test(
    'changed trust is not saved until token matched explicit confirmation',
    () async {
      session = create(
        connect: (transport) async {
          expect(
            await transport.endpoints.single.verifyHostKey(
              'ssh-ed25519',
              Uint8List.fromList(
                utf8.encode('SHA256:${List.filled(43, 'A').join()}'),
              ),
            ),
            true,
          );
        },
      );
      final connecting = session.connect();
      while (session.prompts.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(calls.any((call) => call.startsWith('ssh.saveHost')), false);
      expect(session.respond('stale', true), false);
      expect(session.prompts.single['instructions'], contains('변경'));
      session.respond(session.prompts.single['token'] as String, true);
      await connecting;
      expect(calls.any((call) => call.startsWith('ssh.saveHost')), true);
    },
  );
  test(
    'cancel authentication closes entire session and rejects stale answer',
    () async {
      session = create(
        connect: (transport) async {
          await transport.endpoints.single.onPassword!();
        },
      );
      final connecting = session.connect();
      while (session.prompts.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final token = session.prompts.single['token'] as String;
      session.respond(token, null);
      await connecting;
      await session.disconnect();
      expect(session.ended, true);
      expect(session.respond(token, 'late'), false);
    },
  );
  test(
    'scans URLs with native bounded syntax and punctuation trimming',
    () async {
      session = create();
      await session.connect();
      transports.single.onOutput(
        Uint8List.fromList(
          utf8.encode(
            'https://example.org/a. example.org 127.0.0.1:8080/path!',
          ),
        ),
      );
      expect(await session.invoke('session.urls', {}), [
        'https://example.org/a',
        'example.org',
        '127.0.0.1:8080/path',
      ]);
    },
  );
  test(
    'sendText sends literal bytes independently of sticky modifiers',
    () async {
      session = create();
      await session.connect();
      await session.invoke('session.modifier', {'code': 1, 'sticky': true});
      await session.invoke('session.sendText', {'text': 'c'});
      expect(utf8.decode(transports.single.writes.single), 'c');
    },
  );
  test('biometric key loads without an extra app confirmation', () async {
    prepared['host']['pubkeyId'] = 4;
    prepared['keys'] = [
      {'id': 4, 'nickname': 'protected', 'biometric': true},
    ];
    var loaded = false;
    session = create(
      loadIdentities: ({required id, password}) async {
        expect(id, 4);
        expect(password, isNull);
        loaded = true;
        return [];
      },
      connect: (transport) async {
        await transport.endpoints.single.loadIdentities!();
      },
    );
    final connecting = session.connect();
    await Future<void>.delayed(Duration.zero);
    expect(session.prompts, isEmpty);
    await connecting;
    expect(loaded, true);
  });

  test('key confirmation is deferred and denial skips only that key', () async {
    prepared['host']['pubkeyId'] = 4;
    prepared['keys'] = [
      {'id': 4, 'nickname': 'protected', 'confirmation': true},
    ];
    session = create(
      connect: (transport) async {
        expect(session.prompts, isEmpty);
        expect(await transport.endpoints.single.loadIdentities!(), isEmpty);
      },
    );
    final connecting = session.connect();
    while (session.prompts.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    session.respond(session.prompts.single['token'] as String, false);
    await connecting;
    expect(session.connected, true);
    expect(calls.any((call) => call.startsWith('ssh.keyMaterial')), false);
  });
  test(
    'saved password used once across hidden keyboard and password requests',
    () async {
      prepared['password'] = 'saved';
      session = create(
        connect: (transport) async {
          final endpoint = transport.endpoints.single;
          expect(
            await endpoint.onInteractive!(
              SSHUserInfoRequest('', '', [
                SSHUserInfoPrompt('Password:', false),
              ]),
            ),
            ['saved'],
          );
          expect(await endpoint.onPassword!(), 'saved');
          expect(await endpoint.onPassword!(), 'typed');
        },
      );
      final connecting = session.connect();
      while (session.prompts.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      session.respond(session.prompts.single['token'] as String, 'typed');
      await connecting;
    },
  );
  test(
    'direct reuse closes each new transport and refreshes disconnected config',
    () async {
      session = create();
      await session.connect();
      await session.disconnect();
      expect(transports.first.opened, isFalse);
      session.refreshPrepared({
        ...prepared,
        'host': {...prepared['host'] as Map, 'hostname': 'updated'},
      });
      await session.connect();
      expect(transports.last.endpoints.single.host, 'updated');
      expect(() => session.refreshPrepared(prepared), throwsStateError);
      await session.disconnect();
      expect(transports.last.opened, isFalse);
      expect(session.ended, isTrue);
    },
  );
}
