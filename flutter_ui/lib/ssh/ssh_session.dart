// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

enum SshSessionState { idle, connecting, connected, closed }

enum SshIpVersion { any, ipv4, ipv6 }

enum SshForwardType { local, remote, socks5 }

class SshEndpoint {
  SshEndpoint({
    required this.host,
    required this.username,
    required this.verifyHostKey,
    this.port = 22,
    List<SSHIdentity> identities = const [],
    this.onPassword,
    this.loadIdentities,
    this.onInteractive,
    this.onPasswordChange,
    this.onBanner,
    this.preferredAuthMethods,
    this.ipVersion = SshIpVersion.any,
    this.compression = false,
    this.keepAliveInterval = const Duration(seconds: 10),
    this.connectTimeout = const Duration(seconds: 30),
    this.authTimeout = const Duration(minutes: 5),
    this.algorithms = const SSHAlgorithms(),
  }) : identities = List.unmodifiable(identities);

  final String host;
  final int port;
  final String username;
  final List<SSHIdentity> identities;
  final Future<List<SSHIdentity>> Function()? loadIdentities;
  final FutureOr<bool> Function(String, Uint8List) verifyHostKey;
  final SSHPasswordRequestHandler? onPassword;
  final SSHUserInfoRequestHandler? onInteractive;
  final SSHChangePasswordRequestHandler? onPasswordChange;
  final SSHUserauthBannerHandler? onBanner;
  final List<SSHAuthMethod>? preferredAuthMethods;
  final SshIpVersion ipVersion;
  final bool compression;
  final Duration? keepAliveInterval;
  final Duration connectTimeout;
  final Duration authTimeout;
  final SSHAlgorithms algorithms;
}

class SshPty {
  const SshPty({
    this.columns = 80,
    this.rows = 24,
    this.pixelWidth = 0,
    this.pixelHeight = 0,
    this.type = 'xterm-256color',
  });

  final int columns;
  final int rows;
  final int pixelWidth;
  final int pixelHeight;
  final String type;

  SSHPtyConfig _config() {
    if (columns <= 0 || rows <= 0 || pixelWidth < 0 || pixelHeight < 0) {
      throw ArgumentError('Invalid PTY dimensions');
    }
    return SSHPtyConfig(
      type: type,
      width: columns,
      height: rows,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
  }
}

class SshForward {
  const SshForward({
    required this.id,
    required this.type,
    this.bindHost = '127.0.0.1',
    this.bindPort = 0,
    this.targetHost = '',
    this.targetPort = 0,
  });

  final int id;
  final SshForwardType type;
  final String bindHost;
  final int bindPort;
  final String targetHost;
  final int targetPort;
}

class SshActiveForward {
  const SshActiveForward(this.config, this.port);
  final SshForward config;
  final int port;
}

class SshCommandResult {
  const SshCommandResult(this.stdout, this.stderr, this.exitCode);
  final Uint8List stdout;
  final Uint8List stderr;
  final int? exitCode;
}

/// An independent transport lifetime. Endpoints run from the outer hop to target.
/// Credentials and terminal decoding remain with the supplied platform adapter.
class SshSession {
  SshSession({
    required List<SshEndpoint> endpoints,
    required this.onOutput,
    this.onState,
    this.onError,
    this.wantShell = true,
    SshPty pty = const SshPty(),
    this.operationTimeout = const Duration(seconds: 30),
  }) : endpoints = List.unmodifiable(endpoints),
       _pty = pty {
    if (endpoints.isEmpty) throw ArgumentError('SSH target is required');
  }

  final List<SshEndpoint> endpoints;
  final void Function(Uint8List) onOutput;
  final void Function(SshSessionState)? onState;
  final void Function(Object, StackTrace)? onError;
  final bool wantShell;
  final Duration operationTimeout;
  SshPty _pty;
  SshSessionState get state => _state;
  SshSessionState _state = SshSessionState.idle;
  bool get sessionOpen => _state == SshSessionState.connected && _shell != null;
  int? get exitCode => _shell?.exitCode;
  Object? get error => _error;
  Object? _error;
  Future<void> get done => _done.future;
  final _done = Completer<void>();
  bool _closing = false;
  Future<void>? _closeFuture;
  final _clients = <SSHClient>[];
  SSHSession? _shell;
  Future<void>? _stdoutDone;
  Future<void>? _stderrDone;
  final _forwards = <int, _ForwardRuntime>{};
  Future<void> _forwardOperations = Future.value();

  List<SshActiveForward> get forwards => List.unmodifiable(
    _forwards.values.map(
      (runtime) => SshActiveForward(runtime.config, runtime.port),
    ),
  );

  void _setState(SshSessionState state) {
    _state = state;
    onState?.call(state);
  }

  void _checkOpen() {
    if (_closing) throw StateError('SSH session was closed');
  }

  SSHClient get _client {
    _checkOpen();
    if (_state != SshSessionState.connected) {
      throw StateError('SSH session is not connected');
    }
    return _clients.last;
  }

  Future<void> connect() async {
    if (_state != SshSessionState.idle || _closing) {
      throw StateError('SSH sessions cannot be reused');
    }
    _setState(SshSessionState.connecting);
    try {
      for (final endpoint in endpoints) {
        _checkOpen();
        final socket = _clients.isEmpty
            ? await _connectSocket(endpoint)
            : await _connectHop(endpoint);
        if (_closing) {
          socket.destroy();
          throw StateError('SSH session was closed');
        }
        final client = SSHClient(
          socket,
          username: endpoint.username,
          preferredAuthMethods:
              endpoint.preferredAuthMethods ??
              const [
                SSHAuthMethod.none,
                SSHAuthMethod.publicKey,
                SSHAuthMethod.keyboardInteractive,
                SSHAuthMethod.password,
              ],
          maxPasswordAttempts: 3,
          maxKeyboardInteractiveAttempts: 3,
          identities: endpoint.identities,
          onIdentitiesRequest: endpoint.loadIdentities == null
              ? null
              : () async {
                  _checkOpen();
                  final loaded = await endpoint.loadIdentities!();
                  _checkOpen();
                  return loaded;
                },
          algorithms: endpoint.algorithms,
          compression: endpoint.compression,
          onVerifyHostKey: (type, fingerprint) async {
            if (_closing) return false;
            final accepted = await endpoint.verifyHostKey(type, fingerprint);
            return accepted && !_closing;
          },
          onPasswordRequest: endpoint.onPassword == null
              ? null
              : () async {
                  _checkOpen();
                  final password = await endpoint.onPassword!();
                  return _closing ? null : password;
                },
          onUserInfoRequest: endpoint.onInteractive == null
              ? null
              : (request) async {
                  _checkOpen();
                  final responses = await endpoint.onInteractive!(request);
                  return _closing ? null : responses;
                },
          onChangePasswordRequest: endpoint.onPasswordChange,
          onUserauthBanner: endpoint.onBanner,
          keepAliveInterval: endpoint.keepAliveInterval,
          handshakeTimeout: endpoint.connectTimeout,
          authTimeout: endpoint.authTimeout,
        );
        _clients.add(client);
        // Attach error handling before authentication can fail.
        unawaited(_watchClient(client));
        await client.authenticated;
        _checkOpen();
      }
      if (wantShell) {
        final shell = await _openSession(
          _clients.last.shell(pty: _pty._config()),
        );
        _shell = shell;
        if (_closing) {
          shell.channel.destroy();
          throw StateError('SSH session was closed');
        }
        _stdoutDone = _drain(shell.stdout);
        _stderrDone = _drain(shell.stderr);
        _setState(SshSessionState.connected);
        unawaited(_watchShell(shell));
      } else {
        _setState(SshSessionState.connected);
      }
    } catch (error, stack) {
      if (!_closing) _report(error, stack);
      await close();
      rethrow;
    }
  }

  Future<SSHSocket> _connectSocket(SshEndpoint endpoint) async {
    if (endpoint.ipVersion == SshIpVersion.any) {
      return SSHSocket.connect(
        endpoint.host,
        endpoint.port,
        timeout: endpoint.connectTimeout,
      );
    }
    final family = endpoint.ipVersion == SshIpVersion.ipv4
        ? InternetAddressType.IPv4
        : InternetAddressType.IPv6;
    final addresses = await InternetAddress.lookup(
      endpoint.host,
      type: family,
    ).timeout(endpoint.connectTimeout);
    if (addresses.isEmpty) {
      throw SocketException('No address for requested IP version');
    }
    _checkOpen();
    return SSHSocket.connect(
      addresses.first.address,
      endpoint.port,
      timeout: endpoint.connectTimeout,
    );
  }

  Future<SSHSocket> _connectHop(SshEndpoint endpoint) async {
    // As with the Android transport, the jump server resolves this address.
    return _clients.last
        .forwardLocal(endpoint.host, endpoint.port)
        .timeout(
          endpoint.connectTimeout,
          onTimeout: () {
            throw TimeoutException('SSH hop connection timed out');
          },
        );
  }

  Future<void> _drain(Stream<Uint8List> stream) async {
    try {
      await for (final bytes in stream) {
        onOutput(bytes);
      }
    } catch (error, stack) {
      if (!_closing) {
        _report(error, stack);
        unawaited(close());
      }
    }
  }

  Future<void> _watchShell(SSHSession shell) async {
    try {
      await shell.done;
      await Future.wait([_stdoutDone!, _stderrDone!]);
    } catch (error, stack) {
      if (!_closing) _report(error, stack);
    } finally {
      await close();
    }
  }

  Future<void> _watchClient(SSHClient client) async {
    try {
      await client.done;
    } catch (error, stack) {
      if (!_closing) _report(error, stack);
    }
    if (_state == SshSessionState.connected && !_closing) {
      // Shell completion owns output draining on a normal remote exit.
      if (_shell == null) await close();
    }
  }

  void _report(Object error, StackTrace stack) {
    if (_error != null) return;
    _error = error;
    onError?.call(error, stack);
  }

  Future<void> write(List<int> bytes) async {
    _client;
    final shell = _shell;
    if (shell == null) throw StateError('SSH session has no shell');
    shell.write(Uint8List.fromList(bytes));
    // SSHSession's input stream preserves enqueue order. Its flush reaches the
    // outer native socket, whose flush cannot overlap another hop's packet add.
    // Let the transport drain normally while other channels remain writable.
  }

  void resize(SshPty pty) {
    pty._config();
    _pty = pty;
    if (!_closing) {
      _shell?.resizeTerminal(
        pty.columns,
        pty.rows,
        pty.pixelWidth,
        pty.pixelHeight,
      );
    }
  }

  Future<SshCommandResult> execute(
    String command, {
    int? maxOutputBytes,
  }) async {
    if (maxOutputBytes != null && maxOutputBytes < 0) {
      throw ArgumentError.value(maxOutputBytes, 'maxOutputBytes');
    }
    final channel = await _openSession(_client.execute(command));
    final out = BytesBuilder(copy: false);
    final err = BytesBuilder(copy: false);
    try {
      void collect(BytesBuilder target, Uint8List bytes) {
        final remaining = maxOutputBytes == null
            ? bytes.length
            : maxOutputBytes - target.length;
        if (remaining > 0) {
          target.add(
            bytes.length <= remaining ? bytes : bytes.sublist(0, remaining),
          );
        }
      }

      final drain = Future.wait([
        channel.stdout.forEach((bytes) => collect(out, bytes)),
        channel.stderr.forEach((bytes) => collect(err, bytes)),
      ]);
      await drain.timeout(operationTimeout);
      await channel.done.timeout(operationTimeout);
      return SshCommandResult(
        out.takeBytes(),
        err.takeBytes(),
        channel.exitCode,
      );
    } finally {
      channel.channel.destroy();
    }
  }

  Future<SSHSession> _openSession(Future<SSHSession> pending) {
    var abandoned = false;
    unawaited(
      pending.then<void>((channel) {
        if (abandoned || _closing) channel.channel.destroy();
      }, onError: (Object _, StackTrace _) {}),
    );
    return pending.timeout(
      operationTimeout,
      onTimeout: () {
        abandoned = true;
        throw TimeoutException('SSH session request timed out');
      },
    );
  }

  Future<T> _forwardOperation<T>(Future<T> Function() action) {
    final result = _forwardOperations.then((_) => action());
    _forwardOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<SshActiveForward> enableForward(SshForward config) =>
      _forwardOperation(() async {
        final client = _client;
        final current = _forwards[config.id];
        if (current != null) {
          return SshActiveForward(current.config, current.port);
        }
        final runtime = _ForwardRuntime(client, config, operationTimeout);
        try {
          await runtime.start();
          _checkOpen();
          _forwards[config.id] = runtime;
          return SshActiveForward(config, runtime.port);
        } catch (_) {
          await runtime.close();
          rethrow;
        }
      });

  Future<void> disableForward(int id) => _forwardOperation(() async {
    await _forwards.remove(id)?.close();
  });

  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closing = true;
    return _closeFuture = _close();
  }

  Future<void> _close() async {
    try {
      // Closing clients also fails pending auth, channel opens, and forward requests.
      for (final client in _clients.reversed) {
        try {
          await client.close();
        } catch (_) {
          client.socket.destroy();
        }
      }
      await _forwardOperations;
      for (final forward in _forwards.values) {
        await forward.close();
      }
      _forwards.clear();
      await Future.wait([?_stdoutDone, ?_stderrDone]);
    } finally {
      _setState(SshSessionState.closed);
      if (!_done.isCompleted) _done.complete();
    }
  }
}

class _ForwardRuntime {
  _ForwardRuntime(this.client, this.config, this.timeout);
  final SSHClient client;
  final SshForward config;
  final Duration timeout;
  ServerSocket? _server;
  SSHRemoteForward? _remote;
  SSHDynamicForward? _dynamic;
  StreamSubscription<Object>? _listener;
  final _relays = <_Relay>{};
  final _sockets = <Socket>{};
  final _channels = <SSHForwardChannel>{};
  final _connections = <ConnectionTask<Socket>>{};
  bool _closed = false;
  int get port => _server?.port ?? _remote?.port ?? _dynamic!.port;

  Future<void> start() async {
    if (config.bindPort < 0 || config.bindPort > 65535) {
      throw ArgumentError('Invalid forward bind port');
    }
    if (config.type != SshForwardType.socks5 &&
        (config.targetHost.isEmpty ||
            config.targetPort <= 0 ||
            config.targetPort > 65535)) {
      throw ArgumentError('Invalid forward destination');
    }
    switch (config.type) {
      case SshForwardType.local:
        _server = await ServerSocket.bind(config.bindHost, config.bindPort);
        _listener = _server!.listen(
          (socket) => unawaited(_acceptLocal(socket)),
          onError: (Object _) {},
        );
      case SshForwardType.remote:
        final pending = client.forwardRemote(
          host: config.bindHost,
          port: config.bindPort,
        );
        var abandoned = false;
        unawaited(
          pending.then<void>((remote) async {
            if (remote != null && (abandoned || _closed)) {
              try {
                await _cancelRemote(remote);
              } catch (_) {
                // _cancelRemote terminates the connection if release fails.
              }
            }
          }, onError: (Object _, StackTrace _) {}),
        );
        _remote = await pending.timeout(
          timeout,
          onTimeout: () {
            abandoned = true;
            throw TimeoutException('Remote forwarding request timed out');
          },
        );
        if (_remote == null) throw StateError('Remote forwarding was refused');
        _listener = _remote!.connections.listen(
          (channel) => unawaited(_acceptRemote(channel)),
          onError: (Object _) {},
        );
      case SshForwardType.socks5:
        _dynamic = await client.forwardDynamic(
          bindHost: config.bindHost,
          bindPort: config.bindPort,
        );
    }
  }

  Future<void> _acceptLocal(Socket socket) async {
    unawaited(
      socket.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    _sockets.add(socket);
    try {
      if (_closed) return socket.destroy();
      final pending = client.forwardLocal(
        config.targetHost,
        config.targetPort,
        localHost: socket.remoteAddress.address,
        localPort: socket.remotePort,
      );
      // A timed-out channel open can still complete. Destroy the late channel.
      var abandoned = false;
      unawaited(
        pending.then<void>((channel) {
          if (abandoned || _closed) channel.destroy();
        }, onError: (Object _, StackTrace _) {}),
      );
      final channel = await pending.timeout(
        timeout,
        onTimeout: () {
          abandoned = true;
          throw TimeoutException('Forward connection timed out');
        },
      );
      if (_closed) {
        channel.destroy();
        socket.destroy();
        return;
      }
      _relay(socket, channel);
    } catch (_) {
      socket.destroy();
    } finally {
      _sockets.remove(socket);
    }
  }

  Future<void> _acceptRemote(SSHForwardChannel channel) async {
    _channels.add(channel);
    ConnectionTask<Socket>? connection;
    try {
      if (_closed) return channel.destroy();
      connection = await Socket.startConnect(
        config.targetHost,
        config.targetPort,
      );
      if (_closed) {
        connection.cancel();
        channel.destroy();
        return;
      }
      _connections.add(connection);
      final socket = await connection.socket.timeout(
        timeout,
        onTimeout: () {
          connection!.cancel();
          throw TimeoutException('Remote forward destination timed out');
        },
      );
      unawaited(
        socket.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      if (_closed) {
        socket.destroy();
        channel.destroy();
        return;
      }
      _relay(socket, channel);
    } catch (_) {
      channel.destroy();
    } finally {
      _channels.remove(channel);
      _connections.remove(connection);
    }
  }

  void _relay(Socket socket, SSHForwardChannel channel) {
    final relay = _Relay(socket, channel);
    _relays.add(relay);
    unawaited(relay.run().whenComplete(() => _relays.remove(relay)));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _listener?.cancel();
    await _server?.close();
    await _dynamic?.close();
    for (final socket in _sockets) {
      socket.destroy();
    }
    for (final channel in _channels) {
      channel.destroy();
    }
    for (final connection in _connections) {
      connection.cancel();
    }
    for (final relay in _relays.toList()) {
      relay.destroy();
    }
    _relays.clear();
    final remote = _remote;
    if (remote != null) await _cancelRemote(remote);
  }

  Future<void> _cancelRemote(SSHRemoteForward remote) async {
    if (client.isClosed) return;
    try {
      if (!await client.cancelForwardRemote(remote).timeout(timeout)) {
        throw StateError('Remote forwarding cancellation was refused');
      }
    } catch (_) {
      // A listener we cannot release must not outlive its owning transport.
      client.socket.destroy();
      rethrow;
    }
  }
}

class _Relay {
  _Relay(this.socket, this.channel);
  final Socket socket;
  final SSHForwardChannel channel;

  Future<void> run() async {
    try {
      await Future.wait([
        socket.addStream(channel.stream).then((_) => socket.close()),
        channel.sink.addStream(socket).then((_) => channel.sink.close()),
      ], eagerError: true);
    } catch (_) {
      // A failed peer terminates this relay without affecting other sessions.
    } finally {
      destroy();
    }
  }

  void destroy() {
    socket.destroy();
    channel.destroy();
  }
}
