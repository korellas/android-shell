// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/ssh/ssh_session.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:xterm2/xterm.dart';

void main() {
  final configFile = Platform.environment['TILDE_SSH_TEST_CONFIG'];
  final configured = configFile != null;
  late Map<String, dynamic> config;
  late SSHKeyPair key;

  setUpAll(() async {
    if (!configured) return;
    config =
        jsonDecode(await File(configFile).readAsString())
            as Map<String, dynamic>;
    key = SSHKeyPair.fromPem(
      await File(config['keyFile'] as String).readAsString(),
    ).single;
  });

  Future<SSHClient> connect({
    bool rejectHost = false,
    bool compression = false,
    SSHAlgorithms algorithms = const SSHAlgorithms(),
    void Function(String?)? debug,
    List<SSHIdentity>? identities,
    void Function()? onHostKey,
    void Function()? onAuthenticated,
  }) async {
    return SSHClient(
      await SSHSocket.connect(
        config['host'] as String,
        config['port'] as int,
        timeout: const Duration(seconds: 5),
      ),
      username: config['username'] as String,
      compression: compression,
      algorithms: algorithms,
      printDebug: debug,
      identities: identities ?? [key],
      handshakeTimeout: const Duration(seconds: 5),
      authTimeout: const Duration(seconds: 5),
      onAuthenticated: onAuthenticated,
      onVerifyHostKey: (type, fingerprint) {
        onHostKey?.call();
        return !rejectHost &&
            type == 'ssh-ed25519' &&
            utf8.decode(fingerprint) == config['fingerprint'];
      },
    );
  }

  test(
    'AppSshSession trusts before loading keys, streams terminal IO, and reuses safely',
    () async {
      final authEvents = <String>[];
      final decoders = <String, ByteConversionSink>{};
      final decoded = <String, StringBuffer>{};
      final closedCodecs = <String>[];
      final session = AppSshSession(
        id: 41,
        prepared: {
          'host': {
            'id': 1,
            'hostname': config['host'],
            'port': config['port'],
            'username': config['username'],
            'pubkeyId': 7,
            'compression': true,
          },
          'profile': {'encoding': 'UTF-8'},
          'keys': [
            {'id': 7, 'nickname': 'fixture', 'loaded': true},
          ],
        },
        onChanged: () {},
        loadStoredIdentities: ({required id, password}) async {
          expect(id, 7);
          expect(password, isNull);
          expect(authEvents.last, 'trust');
          authEvents.add('identities');
          return [key];
        },
        platform: (method, args) async {
          switch (method) {
            case 'ssh.checkHost':
              expect(args['hostname'], config['host']);
              expect(args['port'], config['port']);
              expect(args['algorithm'], 'ssh-ed25519');
              expect(args['fingerprint'], config['fingerprint']);
              expect(
                (args['fingerprint'] as String).codeUnits.every(
                  (unit) => unit < 128,
                ),
                isTrue,
              );
              authEvents.add('trust');
              return {'status': 'match'};
            case 'ssh.decode':
              final codec = args['sessionId'] as String;
              final buffer = decoded.putIfAbsent(codec, StringBuffer.new);
              final decoder = decoders.putIfAbsent(
                codec,
                () => utf8.decoder.startChunkedConversion(
                  StringConversionSink.fromStringSink(buffer),
                ),
              );
              decoder.add((args['bytes'] as List).cast<int>());
              if (args['final'] == true) decoder.close();
              final text = buffer.toString();
              buffer.clear();
              return text;
            case 'ssh.encode':
              return Uint8List.fromList(utf8.encode(args['text'] as String));
            case 'ssh.closeCodec':
              final codec = args['sessionId'] as String;
              decoders.remove(codec);
              decoded.remove(codec);
              closedCodecs.add(codec);
              return null;
            default:
              throw StateError('Unexpected platform operation: $method');
          }
        },
      );
      String text() {
        final terminal = session.terminal;
        return terminal.buffer.getText(
          BufferRangeLine(
            CellOffset(0, 0),
            CellOffset(terminal.viewWidth, terminal.buffer.height - 1),
          ),
        );
      }

      Future<void> waitFor(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (!condition()) {
          if (DateTime.now().isAfter(deadline)) {
            fail(
              'App session wait timed out: ${session.record}; terminal: ${text()}',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      try {
        session.terminal.resize(80, 24);
        await session.connect();
        expect(session.connected, isTrue);
        await waitFor(() => text().contains('READY'));
        expect(authEvents, ['trust', 'identities']);
        await session.invoke('session.sendText', {'text': 'size\n'});
        await waitFor(() => text().contains('SIZE 24 80'));
        session.terminal.resize(100, 30);
        await session.invoke('session.sendText', {'text': 'size\n'});
        await waitFor(() => text().contains('SIZE 30 100'));
        for (final input in ['text 한', '글 😀', '\n']) {
          await session.invoke('session.sendText', {'text': input});
        }
        await waitFor(() => text().contains('TEXT 한글 😀'));
        await session.disconnect();
        expect(session.ended, isTrue);
        expect(session.sessionOpen, isFalse);
        expect(decoders, isEmpty);
        await session.connect();
        expect(session.connected, isTrue);
        expect(authEvents, ['trust', 'identities', 'trust', 'identities']);
        await session.invoke('session.sendText', {
          'text': 'text final 재접속 😀\nexit\n',
        });
        await waitFor(() => session.ended);
        expect(text(), contains('TEXT final 재접속 😀'));
        expect(session.sessionOpen, isFalse);
        expect(closedCodecs.toSet().length, 2);
        expect(decoders, isEmpty);
      } finally {
        await session.dispose();
      }
    },
    skip: !configured,
    timeout: const Timeout(Duration(seconds: 30)),
  );

  const cipherCases = <String, SSHAlgorithms>{
    'ChaCha20-Poly1305': SSHAlgorithms(
      cipher: [SSHCipherType.chacha20poly1305],
    ),
    'AES-GCM': SSHAlgorithms(cipher: [SSHCipherType.aes128gcm]),
    'AES-CTR ETM': SSHAlgorithms(
      cipher: [SSHCipherType.aes128ctr],
      mac: [SSHMacType.hmacSha256Etm],
    ),
    'AES-CTR ordinary MAC': SSHAlgorithms(
      cipher: [SSHCipherType.aes128ctr],
      mac: [SSHMacType.hmacSha256],
    ),
  };
  for (final cipher in cipherCases.entries) {
    for (final compression in [false, true]) {
      test(
        '${cipher.key}, compression=$compression: Unicode and queued rekey',
        () async {
          final logs = <String>[];
          final client = await connect(
            compression: compression,
            algorithms: cipher.value,
            debug: (message) {
              if (message != null) logs.add(message);
            },
          );
          final expected = List.generate(
            4096,
            (index) => '$index: 한글 ABC 😀 ${'compressible-' * 16}\n',
          ).join();
          try {
            expect(utf8.decode(await client.run('large')), expected);
            final negotiated =
                compression && config['serverCompression'] == true
                ? 'zlib@openssh.com'
                : 'none';
            expect(
              logs,
              contains('SSH compression client-to-server: $negotiated'),
            );
            expect(
              logs,
              contains('SSH compression server-to-client: $negotiated'),
            );
            final rekey = client.rekey();
            final queued = client.run('large');
            await rekey.timeout(const Duration(seconds: 10));
            expect(utf8.decode(await queued), expected);
            expect(utf8.decode(await client.run('unicode')), '한글 ABC 😀\n');
          } finally {
            await client.close();
          }
        },
        skip: !configured,
        timeout: const Timeout(Duration(seconds: 30)),
      );
    }
  }

  test(
    'a pinned host key and public key authenticate with OpenSSH',
    () async {
      final events = <String>[];
      final client = await connect(
        onHostKey: () => events.add('verified'),
        onAuthenticated: () => events.add('authenticated'),
      );
      try {
        expect(utf8.decode(await client.run('unicode')), '한글 ABC 😀\n');
        expect(events, ['verified', 'authenticated']);
      } finally {
        await client.close();
      }
    },
    skip: !configured,
  );

  test(
    'host key rejection prevents authentication and command execution',
    () async {
      var checked = false;
      var authenticated = false;
      final client = await connect(
        rejectHost: true,
        onHostKey: () => checked = true,
        onAuthenticated: () => authenticated = true,
      );
      try {
        await expectLater(
          client.run('must-not-run'),
          throwsA(isA<SSHAuthAbortError>()),
        );
        expect(checked, isTrue);
        expect(authenticated, isFalse);
        expect(
          File(config['unexpectedExecutionFile'] as String).existsSync(),
          isFalse,
        );
      } finally {
        await client.close();
      }
    },
    skip: !configured,
  );

  test('an asynchronous external signer can authenticate', () async {
    var signs = 0;
    final identity = SSHIdentity.custom(
      type: key.type,
      publicKey: key.toPublicKey(),
      shouldProbe: true,
      signer: (data) async {
        signs++;
        await Future<void>.delayed(Duration.zero);
        return key.sign(data);
      },
    );
    final client = await connect(identities: [identity]);
    try {
      expect(utf8.decode(await client.run('unicode')), '한글 ABC 😀\n');
      expect(signs, greaterThan(0));
    } finally {
      await client.close();
    }
  }, skip: !configured);

  test('PTY size and ordered UTF8 input reach the server', () async {
    final client = await connect();
    StreamSubscription<String>? subscription;
    final output = StringBuffer();
    final changed = StreamController<void>.broadcast();
    Future<void> waitFor(String expected) async {
      if (output.toString().contains(expected)) return;
      await changed.stream
          .firstWhere((_) => output.toString().contains(expected))
          .timeout(const Duration(seconds: 5));
    }

    try {
      final shell = await client.shell(
        pty: SSHPtyConfig(width: 80, height: 24),
      );
      subscription = shell.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen((text) {
            output.write(text);
            changed.add(null);
          });
      await waitFor('READY');
      shell.write(utf8.encode('size\n'));
      await waitFor('SIZE 24 80');
      shell.resizeTerminal(100, 30);
      shell.write(utf8.encode('size\n'));
      await waitFor('SIZE 30 100');
      for (final text in ['text 한', '글 😀', '\n']) {
        shell.write(utf8.encode(text));
      }
      await waitFor('TEXT 한글 😀');
      shell.write(utf8.encode('exit\n'));
      await shell.done.timeout(const Duration(seconds: 5));
    } finally {
      await subscription?.cancel();
      await changed.close();
      await client.close();
    }
  }, skip: !configured);

  test('closing one client leaves another session usable', () async {
    final first = await connect();
    final second = await connect();
    try {
      expect(utf8.decode(await first.run('unicode')), '한글 ABC 😀\n');
      await first.close();
      expect(first.isClosed, isTrue);
      expect(utf8.decode(await second.run('unicode')), '한글 ABC 😀\n');
    } finally {
      await first.close();
      await second.close();
    }
  }, skip: !configured);

  SshEndpoint endpoint({
    bool reject = false,
    bool compression = false,
    List<SSHIdentity>? identities,
    String? hostname,
    SshIpVersion ipVersion = SshIpVersion.any,
  }) => SshEndpoint(
    host: hostname ?? config['host'] as String,
    compression: compression,
    ipVersion: ipVersion,
    port: config['port'] as int,
    username: config['username'] as String,
    identities: identities ?? [key],
    verifyHostKey: (type, fingerprint) async =>
        !reject &&
        type == 'ssh-ed25519' &&
        utf8.decode(fingerprint) == config['fingerprint'],
  );

  test(
    'kernel shell resizes, drains final output, and closes hops',
    () async {
      final output = StringBuffer();
      final changed = StreamController<void>.broadcast();
      final states = <SshSessionState>[];
      final session = SshSession(
        endpoints: [
          endpoint(compression: true),
          endpoint(
            compression: true,
            hostname: 'localhost',
            ipVersion: SshIpVersion.ipv4,
          ),
          endpoint(
            compression: true,
            hostname: 'localhost',
            ipVersion: SshIpVersion.ipv6,
          ),
        ],
        onOutput: (bytes) {
          output.write(utf8.decode(bytes, allowMalformed: true));
          changed.add(null);
        },
        onState: states.add,
      );
      Future<void> waitFor(String text) async {
        if (output.toString().contains(text)) return;
        await changed.stream
            .firstWhere((_) => output.toString().contains(text))
            .timeout(Duration(seconds: 5));
      }

      try {
        await session.connect();
        await waitFor('READY');
        session.resize(SshPty(columns: 99, rows: 33));
        await session.write(utf8.encode('size\n'));
        await waitFor('SIZE 33 99');
        await session.write(utf8.encode('text final 한글\nexit\n'));
        await session.done.timeout(Duration(seconds: 5));
        expect(output.toString(), contains('TEXT final 한글'));
        expect(states, [
          SshSessionState.connecting,
          SshSessionState.connected,
          SshSessionState.closed,
        ]);
      } finally {
        await session.close();
        await changed.close();
      }
    },
    skip: !configured,
  );

  test('kernel rejected host never requests a signature', () async {
    var signed = false;
    final identity = SSHIdentity.custom(
      type: key.type,
      publicKey: key.toPublicKey(),
      signer: (data) {
        signed = true;
        return key.sign(data);
      },
    );
    final session = SshSession(
      endpoints: [
        endpoint(reject: true, identities: [identity]),
      ],
      onOutput: (_) {},
    );
    await expectLater(session.connect(), throwsA(isA<SSHAuthAbortError>()));
    expect(signed, isFalse);
    expect(session.state, SshSessionState.closed);
    await session.done;
  }, skip: !configured);

  test(
    'kernel command drains output and another session survives close',
    () async {
      final first = SshSession(
        endpoints: [endpoint()],
        wantShell: false,
        onOutput: (_) {},
      );
      final second = SshSession(
        endpoints: [endpoint()],
        wantShell: false,
        onOutput: (_) {},
      );
      try {
        await first.connect();
        await second.connect();
        expect(
          utf8.decode((await first.execute('unicode')).stdout),
          '한글 ABC 😀\n',
        );
        await first.close();
        expect(
          utf8.decode((await second.execute('unicode')).stdout),
          '한글 ABC 😀\n',
        );
      } finally {
        await first.close();
        await second.close();
      }
    },
    skip: !configured,
  );

  test(
    'kernel forwards local, remote, SOCKS5 and releases active relays',
    () async {
      final session = SshSession(
        endpoints: [endpoint()],
        wantShell: false,
        onOutput: (_) {},
      );
      final echoPort = config['echoPort'] as int;
      Future<void> echo(int port, {bool socks = false}) async {
        final socket = await Socket.connect('127.0.0.1', port);
        final reader = _SocketReader(socket);
        try {
          if (socks) {
            socket.add([5, 1, 0]);
            expect(await reader.read(2), [5, 0]);
            socket.add([
              5,
              1,
              0,
              1,
              127,
              0,
              0,
              1,
              echoPort >> 8,
              echoPort & 255,
            ]);
            final reply = await reader.read(4);
            expect(reply.sublist(0, 2), [5, 0]);
            final addressLength = switch (reply[3]) {
              1 => 4,
              4 => 16,
              _ => throw StateError('Invalid address type'),
            };
            await reader.read(addressLength + 2);
          }
          final payload = utf8.encode('forwarded 한글 😀');
          socket.add(payload);
          expect(await reader.read(payload.length), payload);
        } finally {
          socket.destroy();
          await reader.cancel();
        }
      }

      try {
        await session.connect();
        for (final type in SshForwardType.values) {
          final forward = await session.enableForward(
            SshForward(
              id: type.index,
              type: type,
              bindHost: type == SshForwardType.remote ? '127.0.0.1' : '0.0.0.0',
              targetHost: '127.0.0.1',
              targetPort: echoPort,
            ),
          );
          await echo(forward.port, socks: type == SshForwardType.socks5);
          await session.disableForward(type.index);
          await expectLater(
            Socket.connect(
              '127.0.0.1',
              forward.port,
              timeout: Duration(seconds: 1),
            ),
            throwsA(isA<SocketException>()),
          );
        }
        final forward = await session.enableForward(
          SshForward(
            id: 20,
            type: SshForwardType.local,
            targetHost: '127.0.0.1',
            targetPort: echoPort,
          ),
        );
        final socket = await Socket.connect('127.0.0.1', forward.port);
        unawaited(
          socket.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
        );
        final drained = socket.drain<void>().then<void>(
          (_) {},
          onError: (Object error) {
            if (error is! SocketException) throw error;
          },
        );
        socket.add([65]);
        await session.close();
        await drained.timeout(Duration(seconds: 2));
        socket.destroy();
        expect(session.forwards, isEmpty);
      } finally {
        await session.close();
      }
    },
    skip: !configured,
  );

  test(
    'closing during asynchronous trust prevents stale authentication',
    () async {
      final trustRequested = Completer<void>();
      final trust = Completer<bool>();
      var signed = false;
      final identity = SSHIdentity.custom(
        type: key.type,
        publicKey: key.toPublicKey(),
        signer: (data) {
          signed = true;
          return key.sign(data);
        },
      );
      final target = SshEndpoint(
        host: config['host'] as String,
        port: config['port'] as int,
        username: config['username'] as String,
        identities: [identity],
        verifyHostKey: (_, _) {
          trustRequested.complete();
          return trust.future;
        },
      );
      final session = SshSession(endpoints: [target], onOutput: (_) {});
      final connecting = session.connect();
      final failed = expectLater(connecting, throwsA(anything));
      await trustRequested.future.timeout(Duration(seconds: 5));
      await session.close().timeout(Duration(seconds: 2));
      trust.complete(true);
      await failed;
      expect(signed, isFalse);
      expect(session.state, SshSessionState.closed);
    },
    skip: !configured,
  );

  test(
    'closing during external signing invalidates the auth attempt',
    () async {
      final requested = Completer<void>();
      final release = Completer<void>();
      final identity = SSHIdentity.custom(
        type: key.type,
        publicKey: key.toPublicKey(),
        shouldProbe: true,
        signer: (data) async {
          requested.complete();
          await release.future;
          return key.sign(data);
        },
      );
      final session = SshSession(
        endpoints: [
          endpoint(identities: [identity]),
        ],
        onOutput: (_) {},
      );
      final failed = expectLater(session.connect(), throwsA(anything));
      await requested.future.timeout(Duration(seconds: 5));
      await session.close().timeout(Duration(seconds: 2));
      release.complete();
      await failed;
      expect(session.state, SshSessionState.closed);
    },
    skip: !configured,
  );

  test(
    'kernel accepts an asynchronous external identity and drains command',
    () async {
      var signed = false;
      final identity = SSHIdentity.custom(
        type: key.type,
        publicKey: key.toPublicKey(),
        shouldProbe: true,
        signer: (data) async {
          await Future<void>.delayed(Duration.zero);
          signed = true;
          return key.sign(data);
        },
      );
      final session = SshSession(
        endpoints: [
          endpoint(identities: [identity]),
        ],
        wantShell: false,
        onOutput: (_) {},
      );
      try {
        await session.connect();
        expect(
          utf8.decode((await session.execute('unicode')).stdout),
          '한글 ABC 😀\n',
        );
        expect(signed, isTrue);
      } finally {
        await session.close();
      }
    },
    skip: !configured,
  );

  test(
    'command timeout closes its channel and leaves transport usable',
    () async {
      final session = SshSession(
        endpoints: [endpoint()],
        wantShell: false,
        onOutput: (_) {},
        operationTimeout: Duration(milliseconds: 500),
      );
      try {
        await session.connect();
        await expectLater(
          session.execute('delayed'),
          throwsA(isA<TimeoutException>()),
        );
        expect(
          utf8.decode((await session.execute('unicode')).stdout),
          '한글 ABC 😀\n',
        );
      } finally {
        await session.close();
      }
    },
    skip: !configured,
  );
}

class _SocketReader {
  _SocketReader(Socket socket) : _iterator = StreamIterator(socket);
  final StreamIterator<List<int>> _iterator;
  final _buffer = <int>[];
  Future<List<int>> read(int count) async {
    while (_buffer.length < count) {
      if (!await _iterator.moveNext().timeout(Duration(seconds: 5))) {
        throw StateError('Unexpected EOF');
      }
      _buffer.addAll(_iterator.current);
    }
    final result = _buffer.sublist(0, count);
    _buffer.removeRange(0, count);
    return result;
  }

  Future<void> cancel() => _iterator.cancel();
}
