// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/ssh/ssh_session.dart';

class _EngineTransport extends SshSession {
  _EngineTransport({
    required super.endpoints,
    required super.onOutput,
    required super.onState,
    required super.onError,
    required super.wantShell,
    required super.pty,
  });
  bool opened = false;
  int closeCalls = 0;
  String? password;
  Object? connectError;
  bool failWrite = false;
  @override
  Future<void> write(List<int> bytes) async {
    if (failWrite) throw StateError('recoverable write');
  }

  int? _exitCode;
  @override
  int? get exitCode => _exitCode;
  void remoteEnd([Object? error]) {
    _exitCode = error == null ? 0 : null;
    if (error != null) onError?.call(error, StackTrace.current);
    onState?.call(SshSessionState.closed);
  }

  final active = <int, SshActiveForward>{};
  final disabled = <int>[];
  @override
  bool get sessionOpen => opened && wantShell;
  @override
  List<SshActiveForward> get forwards => active.values.toList();
  @override
  Future<void> connect() async {
    if (connectError != null) throw connectError!;
    password = await endpoints.last.onPassword!();
    opened = true;
    onState?.call(SshSessionState.connected);
  }

  @override
  Future<void> close() async {
    closeCalls++;
    opened = false;
    active.clear();
    onState?.call(SshSessionState.closed);
  }

  @override
  Future<SshActiveForward> enableForward(SshForward config) async =>
      active[config.id] = SshActiveForward(config, config.bindPort);
  @override
  Future<void> disableForward(int id) async {
    disabled.add(id);
    active.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const runtime = MethodChannel('dev.korellas.androidshell/runtime');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AndroidEngine engine;
  late List<_EngineTransport> transports;
  late List<Map<String, dynamic>> forwards;
  late String storedPassword;
  late Future<Object?> Function()? snapshotOverride;
  late List<Map<String, dynamic>> runtimeRows;
  late List<String> endedReasons;
  late List<String> hooks;
  late bool network;
  Object? nextConnectError;
  Future<void> settle(bool Function() condition) async {
    for (var i = 0; i < 200; i++) {
      if (condition()) return;
      await Future<void>.delayed(Duration.zero);
    }
    fail('Lifecycle did not settle: ${engine.state}');
  }

  Future<void> networkEvent(bool available) async {
    await messenger.handlePlatformMessage(
      AndroidEngine.events.name,
      const StandardMethodCodec().encodeSuccessEnvelope({
        'type': 'networkChanged',
        'available': available,
      }),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  final host = <String, dynamic>{
    'id': 1,
    'hostname': 'example',
    'port': 22,
    'username': 'user',
    'nickname': 'host',
    'protocol': 'ssh',
  };
  Map<String, dynamic> snapshot() => {
    'ready': true,
    'hosts': [host],
    'keys': [],
  };
  Future<void> waitConnected(int id) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (engine.sshSession(id)!.connected) return;
      await Future<void>.delayed(Duration.zero);
    }
    fail('SSH session did not connect: ${engine.sshSession(id)!.record}');
  }

  setUp(() {
    transports = [];
    runtimeRows = [];
    endedReasons = [];
    hooks = [];
    network = true;
    nextConnectError = null;
    host.remove('quickDisconnect');
    host.remove('stayConnected');
    host.remove('wantSession');
    messenger.setMockMethodCallHandler(
      MethodChannel(AndroidEngine.events.name),
      (_) async => null,
    );
    forwards = [];
    storedPassword = 'first-password';
    snapshotOverride = null;
    messenger.setMockMethodCallHandler(AndroidEngine.channel, (call) async {
      final args = call.arguments == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(call.arguments as Map);
      switch (call.method) {
        case 'session.visibility':
          return null;
        case 'snapshot':
          return snapshotOverride == null
              ? snapshot()
              : await snapshotOverride!();
        case 'session.prepare':
          return {
            'host': host,
            'password': storedPassword,
            'keys': [],
            'forwards': forwards,
          };
        case 'forwards':
          return forwards;
        case 'forward.save':
          final saved = <String, dynamic>{
            ...args,
            'id': args['id'] == null || args['id'] == 0 ? 11 : args['id'],
          };
          forwards.removeWhere((row) => row['id'] == saved['id']);
          forwards.add(saved);
          return saved;
        case 'forward.delete':
          forwards.removeWhere((row) => row['id'] == args['id']);
          return null;
        default:
          throw StateError('Unexpected engine method ${call.method}');
      }
    });
    messenger.setMockMethodCallHandler(runtime, (call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      switch (call.method) {
        case 'runtime.sessions':
          runtimeRows = rows(args['sessions']);
          return null;
        case 'runtime.networkAvailable':
          return network;
        case 'runtime.sessionEnded':
          expect(
            runtimeRows.any(
              (row) => '${row['id']}' == args['id'] && row['ended'] == true,
            ),
            isTrue,
          );
          endedReasons.add(args['reason'] as String);
          return null;
        case 'runtime.visibility':
        case 'runtime.bell':
          expect(
            runtimeRows.any((row) => '${row['id']}' == args['id']),
            isTrue,
          );
          hooks.add(call.method);
          return null;
        case 'ssh.decode':
          return utf8.decode((args['bytes'] as List).cast<int>());
        case 'ssh.encode':
          return Uint8List.fromList(utf8.encode(args['text'] as String));
        case 'ssh.closeCodec':
          return null;
        default:
          throw StateError('Unexpected runtime method ${call.method}');
      }
    });
    engine = AndroidEngine(
      sshTransportFactory:
          ({
            required endpoints,
            required onOutput,
            required onState,
            required onError,
            required wantShell,
            required pty,
          }) {
            final transport = _EngineTransport(
              endpoints: endpoints,
              onOutput: onOutput,
              onState: onState,
              onError: onError,
              wantShell: wantShell,
              pty: pty,
            );
            transport.connectError = nextConnectError;
            nextConnectError = null;
            transports.add(transport);
            return transport;
          },
    );
  });
  tearDown(() async {
    await engine.query('session.disconnectAll');
    engine.dispose();
    await Future<void>.delayed(Duration.zero);
    messenger.setMockMethodCallHandler(AndroidEngine.channel, null);
    messenger.setMockMethodCallHandler(runtime, null);
  });
  test(
    'concurrent refresh awaits merged in-flight and queued snapshots',
    () async {
      final entered = Completer<void>();
      final release = Completer<Object?>();
      var snapshots = 0;
      snapshotOverride = () {
        snapshots++;
        if (snapshots == 1) {
          entered.complete();
          return release.future;
        }
        return Future.value({...snapshot(), 'revision': 'fresh'});
      };
      final first = engine.refresh();
      await entered.future;
      var secondCompleted = false;
      final second = engine.refresh().then((_) => secondCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(secondCompleted, isFalse);
      release.complete({...snapshot(), 'revision': 'old'});
      await Future.wait([first, second]);
      expect(snapshots, 2);
      expect(engine.state['revision'], 'fresh');
      expect(secondCompleted, isTrue);
    },
  );
  test(
    'ended terminal reuse reloads stored password and closes every transport',
    () async {
      await engine.refresh();
      final id = await engine.query('connect', {'id': 1}) as int;
      await waitConnected(id);
      final session = engine.sshSession(id)!;
      final terminal = session.terminal;
      expect(transports.single.password, 'first-password');
      for (final password in ['updated-password', 'latest-password']) {
        await engine.query('session.disconnect', {'id': id});
        expect(transports.last.opened, isFalse);
        storedPassword = password;
        expect(await engine.query('connect', {'id': 1}), id);
        await waitConnected(id);
        expect(identical(engine.sshSession(id), session), isTrue);
        expect(identical(engine.sshSession(id)!.terminal, terminal), isTrue);
        expect(transports.last.password, password);
      }
      await engine.query('session.disconnect', {'id': id});
      expect(
        transports.every(
          (transport) => !transport.opened && transport.closeCalls == 1,
        ),
        isTrue,
      );
    },
  );
  test(
    'forward CRUD synchronizes live rows and listeners through engine routing',
    () async {
      await engine.refresh();
      final id = await engine.query('connect', {'id': 1}) as int;
      await waitConnected(id);
      final saved = row(
        await engine.invoke('forward.save', {
          'id': 0,
          'hostId': 1,
          'sessionId': id,
          'nickname': 'forward',
          'type': 'local',
          'sourceAddr': 'localhost',
          'sourcePort': 11011,
          'destAddr': 'old',
          'destPort': 22,
          'startEnabled': true,
        }),
      );
      final transport = transports.single;
      expect(transport.active[11]!.config.targetHost, 'old');
      expect(
        rows(
          await engine.query('forwards', {'hostId': 1, 'sessionId': id}),
        ).single['enabled'],
        isTrue,
      );
      await engine.invoke('forward.save', {...saved, 'destAddr': 'new'});
      expect(transport.disabled, [11]);
      expect(transport.active[11]!.config.targetHost, 'new');
      expect(engine.sshSession(id)!.forwards.single['destAddr'], 'new');
      await engine.invoke('forward.delete', {'id': 11});
      expect(transport.disabled, [11, 11]);
      expect(transport.active, isEmpty);
      expect(
        await engine.query('forwards', {'hostId': 1, 'sessionId': id}),
        isEmpty,
      );
      expect(engine.sshSession(id)!.prepared['forwards'], isEmpty);
    },
  );
  test(
    'runtime hooks follow snapshots and quick exit removes the terminal',
    () async {
      host['quickDisconnect'] = true;
      await engine.refresh();
      final id = await engine.query('connect', {'id': 1}) as int;
      await waitConnected(id);
      await engine.query('session.visibility', {'id': id, 'visible': true});
      engine.sshSession(id)!.terminal.onBell!();
      await settle(() => hooks.contains('runtime.bell'));
      transports.last.remoteEnd();
      await settle(() => engine.terminalSession(id) == null);
      expect(endedReasons, ['SESSION_EXIT']);
      expect(transports.last.closeCalls, 1);
    },
  );
  test('user close removes while auth failure never auto reconnects', () async {
    host['stayConnected'] = true;
    await engine.refresh();
    var id = await engine.query('connect', {'id': 1}) as int;
    await waitConnected(id);
    transports.last.remoteEnd(SSHAuthFailError('rejected'));
    await settle(() => endedReasons.contains('AUTH_FAIL'));
    expect(transports.length, 1);
    expect(engine.sshSession(id)!.ended, isTrue);
    id = await engine.query('connect', {'id': 1}) as int;
    await waitConnected(id);
    await engine.query('session.disconnect', {'id': id});
    await settle(() => engine.terminalSession(id) == null);
    expect(endedReasons.last, 'USER_REQUESTED');
  });
  test(
    'forward-only reuse stays connected without restarting its transport',
    () async {
      host['wantSession'] = false;
      await engine.refresh();
      final id = await engine.query('connect', {'id': 1}) as int;
      await waitConnected(id);
      expect(engine.sshSession(id)!.sessionOpen, isFalse);
      expect(await engine.query('connect', {'id': 1}), id);
      expect(transports.length, 1);
      expect(transports.single.closeCalls, 0);
      await settle(
        () => runtimeRows.any(
          (row) => row['id'] == id && row['connected'] == true,
        ),
      );
    },
  );
  test(
    'failed automatic reconnect waits for network restoration without looping',
    () async {
      host['stayConnected'] = true;
      await engine.start();
      final id = await engine.query('connect', {'id': 1}) as int;
      await waitConnected(id);
      final terminal = engine.sshSession(id)!.terminal;
      nextConnectError = const SocketException('unavailable');
      transports.last.remoteEnd(const SocketException('lost'));
      await settle(() => transports.length == 2 && endedReasons.length == 2);
      expect(engine.state['sessions'].single['connecting'], isTrue);
      expect(identical(engine.sshSession(id)!.terminal, terminal), isTrue);
      await networkEvent(true);
      await Future<void>.delayed(Duration.zero);
      expect(transports.length, 2);
      network = false;
      await networkEvent(false);
      network = true;
      await networkEvent(true);
      await settle(
        () => transports.length == 3 && engine.sshSession(id)!.connected,
      );
      expect(identical(engine.sshSession(id)!.terminal, terminal), isTrue);
      expect(transports.last.password, 'first-password');
    },
  );
  test(
    'offline reconnect remains foreground and user disconnect cancels pending work',
    () async {
      host['stayConnected'] = true;
      network = false;
      await engine.start();
      final id = await engine.query('connect', {'id': 1}) as int;
      await waitConnected(id);
      transports.last.remoteEnd(const SocketException('offline'));
      await settle(
        () =>
            endedReasons.isNotEmpty &&
            engine.state['sessions'].single['connecting'] == true,
      );
      expect(transports.length, 1);
      expect(runtimeRows.single['connecting'], isTrue);
      await engine.query('session.disconnect', {'id': id});
      await settle(() => engine.terminalSession(id) == null);
      expect(endedReasons, ['IO_ERROR', 'USER_REQUESTED']);
      network = true;
      await networkEvent(true);
      expect(transports.length, 1);
    },
  );
  test('automatic auth prompt can be cancelled without answering it', () async {
    host['stayConnected'] = true;
    await engine.refresh();
    final id = await engine.query('connect', {'id': 1}) as int;
    await waitConnected(id);
    final session = engine.sshSession(id)!;
    session.prepared['password'] = null;
    transports.last.remoteEnd(const SocketException('lost'));
    await settle(() => session.prompts.isNotEmpty);
    await engine
        .query('session.disconnect', {'id': id})
        .timeout(const Duration(seconds: 2));
    await settle(() => engine.terminalSession(id) == null);
    expect(session.prompts, isEmpty);
  });
  test(
    'user closes a retained remote exit without leaving a stale tab',
    () async {
      await engine.refresh();
      final id = await engine.query('connect', {'id': 1}) as int;
      await waitConnected(id);
      transports.last.remoteEnd();
      await settle(() => endedReasons.contains('SESSION_EXIT'));
      expect(engine.terminalSession(id), isNotNull);
      await engine.query('session.disconnect', {'id': id});
      expect(engine.terminalSession(id), isNull);
      expect(endedReasons.last, 'USER_REQUESTED');
    },
  );
  test(
    'nonfatal reporting does not poison a later normal remote exit',
    () async {
      host['stayConnected'] = true;
      await engine.refresh();
      final id = await engine.query('connect', {'id': 1}) as int;
      await waitConnected(id);
      transports.last.failWrite = true;
      await expectLater(
        engine.query('session.sendText', {'id': id, 'text': 'test'}),
        throwsStateError,
      );
      transports.last.failWrite = false;
      transports.last.remoteEnd();
      await settle(() => endedReasons.isNotEmpty);
      expect(endedReasons.single, 'SESSION_EXIT');
      expect(transports.length, 1);
    },
  );
}
