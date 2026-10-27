// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';
import '../platform/ssh_keys.dart';
import '../terminal/images/image_terminal.dart';
import '../terminal/images/inline_images.dart';
import '../terminal/terminal_input.dart';
import 'automation.dart';
import '../terminal/app_terminal_session.dart';
import 'ssh_session.dart';
import 'key_agent.dart';
import 'enrollment.dart';

typedef AppSshTransportFactory =
    SshSession Function({
      required List<SshEndpoint> endpoints,
      required void Function(Uint8List) onOutput,
      required void Function(SshSessionState) onState,
      required void Function(Object, StackTrace) onError,
      required bool wantShell,
      required SshPty pty,
    });

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> _maps(Object? value) =>
    value is List ? value.map(_map).toList() : [];

/// Owns a terminal independently of its visible route and transport reconnects.
class AppSshSession implements AppTerminalSession {
  AppSshSession({
    required this.id,
    required this.prepared,
    required this.platform,
    required this.onChanged,
    this.onNotification,
    this.loadStoredIdentities,
    this.loadAgentKeys,
    this.lookupStoredKey,
    this.addAgentKey,
    this.removeAgentKey,
    this.removeAllAgentKeys,
    AppSshTransportFactory? transportFactory,
  }) : _factory = transportFactory ?? SshSession.new {
    terminal = InlineImageTerminal(
      maxLines: (host['scrollbackLines'] as int? ?? 1000).clamp(1, 100000),
      imagePolicy: switch (profile['inlineImages']) {
        'off' => InlineImagePolicy.off,
        'on' => InlineImagePolicy.on,
        _ => InlineImagePolicy.ask,
      },
      onOutput: (text) {
        unawaited(_send(text).catchError(_failed));
      },
      onResize: (width, height, pixelWidth, pixelHeight) {
        _transport?.resize(_pty(width, height, pixelWidth, pixelHeight));
        scheduleMicrotask(_changed);
      },
    );
    TerminalSessionOperations.configureInput(
      terminal,
      profile['delKey'] as String?,
    );
    input = TerminalInputController(terminal: terminal);
    _fontSize = (profile['fontSize'] as num? ?? 14).toDouble();
  }
  @override
  final int id;
  @override
  final Map<String, dynamic> prepared;
  final SshPlatformCall platform;
  final VoidCallback onChanged;
  final void Function(Map<String, dynamic>)? onNotification;
  final AppSshTransportFactory _factory;
  final Future<List<SSHIdentity>> Function({required int id, String? password})?
  loadStoredIdentities;
  final Future<List<SshAgentKey>> Function()? loadAgentKeys;
  final Map<String, dynamic>? Function(int id)? lookupStoredKey;
  final Future<bool> Function(SSHKeyPair key, bool confirmation)? addAgentKey;
  final Future<bool> Function(Uint8List publicKey)? removeAgentKey;
  final Future<bool> Function()? removeAllAgentKeys;
  final _trustedHostKeys = <String, (String, String)>{};
  List<SshEndpoint> _connectedEndpoints = [];
  Map<String, dynamic>? _enrollmentHost;
  @override
  late final InlineImageTerminal terminal;
  @override
  final controller = TerminalController();
  @override
  late final TerminalInputController input;
  @override
  Map<String, dynamic> get host => _map(prepared['host']);
  @override
  Map<String, dynamic> get profile => _map(prepared['profile']);
  SshSession? _transport;
  SshAutomation? _automation;
  SshSessionState _state = SshSessionState.idle;
  int _generation = 0, _promptSerial = 0, _bannerSerial = 0;
  bool _disposed = false, _closing = false;
  String? _error;
  String? _disconnectReason;
  String? _transportCloseReason;
  late double _fontSize;
  final _banners = <Map<String, dynamic>>[];
  final _modifiers = {'ctrl': 'OFF', 'alt': 'OFF', 'shift': 'OFF'};
  Future<void> _output = Future.value(), _input = Future.value();
  Future<void>? _disconnecting;
  Map<String, dynamic>? _prompt;
  Completer<Object?>? _response;
  bool _rejectCancels = true;
  String get _codecId => 'app-ssh-$id-$_generation';
  String get _encoding => profile['encoding'] as String? ?? 'UTF-8';
  @override
  bool get sessionOpen => !_closing && _transport?.sessionOpen == true;
  bool get connected => !_closing && _state == SshSessionState.connected;
  @override
  bool get connecting => !_closing && _state == SshSessionState.connecting;
  @override
  bool get ended => _state == SshSessionState.closed;
  @override
  double get fontSize => _fontSize;
  @override
  List<Map<String, dynamic>> get prompts => [
    if (_prompt != null) {..._prompt!},
  ];
  @override
  Map<String, dynamic> get record {
    final automation = _automation?.state;
    final scheme = _map(prepared['scheme']);
    return {
      'id': id,
      'hostId': host['id'],
      'nickname': host['nickname'],
      'protocol': 'ssh',
      'uri': Uri(
        scheme: 'ssh',
        userInfo: host['username'] as String? ?? '',
        host: host['hostname'] as String?,
        port: host['port'] as int? ?? 22,
      ).toString(),
      'open': sessionOpen,
      'connected': connected,
      'connectionGeneration': _generation,
      'disconnectReason': _disconnectReason,
      'connecting': connecting,
      'ended': ended,
      'awaitingClose': ended,
      'canForward': connected,
      'canEnroll': canEnroll,
      'composeMode': false,
      'columns': terminal.viewWidth,
      'rows': terminal.viewHeight,
      'fontSize': _fontSize,
      'modifiers': {..._modifiers},
      'progress': _error == null
          ? null
          : {'state': 'ERROR', 'value': 0, 'message': _error},
      'automation': {
        'running': automation?.running ?? false,
        'error': automation?.error?.name,
        'step': automation?.step ?? 0,
        'completed': automation?.completed ?? false,
        'failedStep': automation?.failedStep,
      },
      'banners': [
        for (final banner in _banners) {...banner},
      ],
      for (final key in ['foregroundColor', 'backgroundColor', 'cursorColor'])
        if (scheme.containsKey(key)) key: scheme[key],
    };
  }

  void _changed() {
    if (!_disposed) onChanged();
  }

  bool _current(int generation) =>
      !_disposed && !_closing && !ended && generation == _generation;
  void _failed(Object error, [StackTrace? stack]) {
    if (_disposed || _closing) return;
    _error = '$error';

    _changed();
    onNotification?.call({
      'type': 'message',
      'message': '$error',
      'sessionId': id,
    });
  }

  SshPty _pty(int width, int height, int pixelWidth, int pixelHeight) => SshPty(
    columns: width,
    rows: height,
    pixelWidth: pixelWidth,
    pixelHeight: pixelHeight,
    type: profile['emulation'] as String? ?? 'xterm-256color',
  );

  Future<Object?> _ask(
    Map<String, dynamic> prompt,
    int generation, {
    bool rejectCancels = true,
  }) async {
    if (!_current(generation)) throw StateError('SSH authentication cancelled');
    if (_response != null) {
      throw StateError('Concurrent SSH authentication prompt');
    }
    final response = Completer<Object?>();
    _rejectCancels = rejectCancels;
    _response = response;
    _prompt = {
      ...prompt,
      'sessionId': id,
      'token': '$id-$generation-${++_promptSerial}',
      'nativePresentation': false,
    };
    _changed();
    final value = await response.future;
    if (!_current(generation)) throw StateError('SSH authentication cancelled');
    return value;
  }

  bool respond(String token, Object? value) {
    if (_prompt?['token'] != token || _response == null || _closing) {
      return false;
    }
    final response = _response!;
    _response = null;
    final cancelled =
        value == null ||
        (value == false && _rejectCancels && _prompt?['type'] != 'string');
    _prompt = null;
    if (cancelled) {
      unawaited(disconnect());
      response.complete(null);
    } else {
      response.complete(value);
      _changed();
    }
    return true;
  }

  Future<SshEndpoint> _endpoint(
    Map<String, dynamic> config,
    int generation,
  ) async {
    final target = _map(config['host']);
    final savedPassword = config['password'] as String?;
    var passwordSavedTried = false, interactiveSavedTried = false;
    Future<String> askString(
      String instructions, {
      String hint = '',
      bool hidden = true,
    }) async {
      final answer = await _ask({
        'type': 'string',
        'instructions': instructions,
        'hint': hint,
        'password': hidden,
      }, generation);
      if (answer is! String) throw StateError('SSH authentication cancelled');
      return answer;
    }

    Future<String> password() async {
      if (!passwordSavedTried) {
        passwordSavedTried = true;
        if (savedPassword != null) return savedPassword;
      }
      return askString(
        '${target['username']}@${target['hostname']}',
        hint: 'Password',
      );
    }

    Future<List<SSHIdentity>> loadIdentities() async {
      final identities = <SSHIdentity>[];
      for (final key in _maps(config['keys'])) {
        if ((target['pubkeyId'] as int? ?? -1) < 0 && key['loaded'] != true) {
          continue;
        }
        if (!_current(generation)) {
          throw StateError('SSH authentication cancelled');
        }
        if (key['confirmation'] == true || key['biometric'] == true) {
          final accepted = await _ask(
            {
              'type': 'boolean',
              'instructions': 'SSH 키 사용 확인',
              'message': '${key['nickname']}',
            },
            generation,
            rejectCancels: false,
          );
          if (accepted != true) continue;
        }
        final secret = key['encrypted'] == true && key['loaded'] != true
            ? await askString('${key['nickname']}', hint: 'Key password')
            : null;
        final adapter = SshKeyAdapter((method, args) async {
          if (!_current(generation)) {
            throw StateError('SSH authentication cancelled');
          }
          final result = await platform(method, args);
          if (!_current(generation)) {
            throw StateError('SSH authentication cancelled');
          }
          if (_map(result)['authcancel'] == true) {
            unawaited(disconnect());
            throw const SshKeyAuthenticationCancelled();
          }
          return result;
        });
        identities.addAll(
          await (loadStoredIdentities ?? adapter.identities)(
            id: key['id'] as int,
            password: secret,
          ),
        );
      }
      return identities;
    }

    return SshEndpoint(
      host: target['hostname'] as String,
      port: target['port'] as int? ?? 22,
      username: target['username'] as String? ?? '',
      loadIdentities: loadIdentities,
      compression: target['compression'] == true,
      ipVersion: switch (target['ipVersion']) {
        'IPV4_ONLY' => SshIpVersion.ipv4,
        'IPV6_ONLY' => SshIpVersion.ipv6,
        _ => SshIpVersion.any,
      },
      verifyHostKey: (algorithm, fingerprint) async {
        final args = <String, Object?>{
          'id': target['id'],
          'hostname': target['hostname'],
          'port': target['port'] ?? 22,
          'algorithm': algorithm,
          'fingerprint': utf8.decode(fingerprint),
        };
        final check = _map(await platform('ssh.checkHost', args));
        if (!_current(generation)) return false;
        if (check['status'] == 'match') {
          _trustedHostKeys['${target['hostname']}:${target['port'] ?? 22}'] = (
            algorithm,
            utf8.decode(fingerprint),
          );
          return true;
        }
        final changed = check['status'] == 'changed';
        final accepted = await _ask({
          'type': 'boolean',
          'instructions': changed ? '서버 키가 변경되었습니다' : '서버 키 신뢰 확인',
          'message':
              '${target['hostname']}:${target['port'] ?? 22}\n$algorithm\n${args['fingerprint']}\n${changed ? '기존 키를 교체하고 계속할까요?' : '이 서버 키를 신뢰할까요?'}',
        }, generation);
        if (accepted != true || !_current(generation)) return false;
        await platform('ssh.saveHost', {
          ...args,
          'accept': true,
          'replace': changed,
        });
        if (_current(generation)) {
          _trustedHostKeys['${target['hostname']}:${target['port'] ?? 22}'] = (
            algorithm,
            utf8.decode(fingerprint),
          );
        }
        return _current(generation);
      },
      agentHandler:
          target['useAuthAgent'] != 'no' &&
              target['useAuthAgent'] != null &&
              loadAgentKeys != null
          ? AppSshKeyAgent(
              mode: target['useAuthAgent'] as String,
              addKey: (key, confirmation) async =>
                  _current(generation) &&
                  addAgentKey != null &&
                  await addAgentKey!(key, confirmation),
              removeKey: (key) async =>
                  _current(generation) &&
                  removeAgentKey != null &&
                  await removeAgentKey!(key),
              removeAllKeys: () async =>
                  _current(generation) &&
                  removeAllAgentKeys != null &&
                  await removeAllAgentKeys!(),
              loadKeys: () async {
                if (!_current(generation)) return [];
                return loadAgentKeys!();
              },
              confirm: (nickname) async =>
                  await _ask(
                    {
                      'type': 'boolean',
                      'instructions': 'SSH 에이전트 키 사용 확인',
                      'message': nickname,
                    },
                    generation,
                    rejectCancels: false,
                  ) ==
                  true,
            )
          : null,
      onPassword: password,
      onInteractive: (request) async {
        final answers = <String>[];
        for (final prompt in request.prompts) {
          if (!prompt.echo && !interactiveSavedTried && savedPassword != null) {
            interactiveSavedTried = true;
            answers.add(savedPassword);
          } else {
            answers.add(
              await askString(
                request.instruction.isEmpty
                    ? request.name
                    : request.instruction,
                hint: prompt.promptText,
                hidden: !prompt.echo,
              ),
            );
          }
        }
        return answers;
      },
      onPasswordChange: (prompt) async => SSHChangePasswordResponse(
        await askString(prompt, hint: 'Current password'),
        await askString(prompt, hint: 'New password'),
      ),
      onBanner: (message) {
        if (!_current(generation)) return;
        _banners.add({
          'id': ++_bannerSerial,
          'sourceName': target['nickname'] ?? target['hostname'],
          'message': message,
          'urls': <String>[],
        });
        _changed();
      },
    );
  }

  @override
  Future<void> connect() async {
    if (_disposed) throw StateError('Session disposed');
    if (_transport != null || connecting || _closing) {
      throw StateError('Disconnect before reconnecting');
    }
    TerminalSessionOperations.configureInput(
      terminal,
      profile['delKey'] as String?,
    );
    _disconnecting = null;
    final generation = ++_generation;
    _trustedHostKeys.clear();
    _state = SshSessionState.connecting;
    _error = null;
    _disconnectReason = null;
    _transportCloseReason = null;
    _output = Future.value();
    _input = Future.value();
    _changed();
    try {
      final endpoints = <SshEndpoint>[];
      for (final config in [..._maps(prepared['jumps']), prepared]) {
        endpoints.add(await _endpoint(config, generation));
      }
      if (!_current(generation)) return;
      _connectedEndpoints = List.unmodifiable(endpoints);
      _enrollmentHost = Map<String, dynamic>.from(host);
      final transport = _factory(
        endpoints: endpoints,
        onOutput: (bytes) => _receive(bytes, generation),
        onState: (state) {
          if (_current(generation)) {
            if (state == SshSessionState.closed) {
              unawaited(
                _end(
                  _transportCloseReason ??
                      (_transport?.exitCode != null
                          ? 'SESSION_EXIT'
                          : 'IO_ERROR'),
                ),
              );
            } else {
              _state = state;
              _changed();
            }
          }
        },
        onError: (error, stack) {
          if (_current(generation)) {
            _transportCloseReason =
                error is SSHAuthError || error is SshKeyAuthenticationCancelled
                ? 'AUTH_FAIL'
                : 'IO_ERROR';
            _failed(error, stack);
          }
        },
        wantShell: host['wantSession'] != false,
        pty: _pty(terminal.viewWidth, terminal.viewHeight, 0, 0),
      );
      _transport = transport;
      _automation = SshAutomation(
        sessionOpen: () => sessionOpen,
        sendText: _send,
        sendKey: _sendKey,
        setForward: setForward,
        disconnect: disconnect,
        onState: (_) => _changed(),
        matchRegexEnd: (expression, text) async =>
            await platform('ssh.matchRegexEnd', {
                  'expression': expression,
                  'text': text,
                })
                as int?,
      );
      await transport.connect();
      if (!_current(generation)) return;
      for (final forward in _maps(prepared['forwards'])) {
        if (forward['startEnabled'] == true) {
          await setForward(forward['id'] as int, true);
        }
        if (!_current(generation)) return;
      }
      if (sessionOpen) {
        final postLogin = host['postLogin'] as String?;
        if (postLogin != null && postLogin.isNotEmpty) await _send(postLogin);
        final actions = _maps(prepared['automation']);
        if (actions.isNotEmpty) unawaited(runAutomation(actions));
      }
      _changed();
    } catch (error, stack) {
      if (_current(generation)) {
        _failed(error, stack);
        await _end(
          error is SSHAuthError || error is SshKeyAuthenticationCancelled
              ? 'AUTH_FAIL'
              : 'IO_ERROR',
        );
      }
    }
  }

  bool get canEnroll =>
      connected &&
      _enrollmentHost != null &&
      (_enrollmentHost!['id'] as int? ?? 0) > 0 &&
      loadStoredIdentities != null &&
      _connectedEndpoints.isNotEmpty &&
      _connectedEndpoints.every(
        (endpoint) =>
            _trustedHostKeys.containsKey('${endpoint.host}:${endpoint.port}'),
      );
  Map<String, dynamic> get enrollmentHost =>
      Map<String, dynamic>.from(_enrollmentHost ?? host);
  String get enrollmentUsername => _connectedEndpoints.last.username;

  bool Function() captureEnrollmentValidity() {
    final generation = _generation;
    final transport = _transport;
    return () =>
        _current(generation) && identical(_transport, transport) && canEnroll;
  }

  void refreshPrepared(Map<String, dynamic> configuration) {
    if (_disposed || _transport != null || connecting || _closing) {
      throw StateError('Disconnect before refreshing SSH configuration');
    }
    final fresh = Map<String, dynamic>.from(configuration);
    prepared
      ..clear()
      ..addAll(fresh);
    TerminalSessionOperations.configureInput(
      terminal,
      profile['delKey'] as String?,
    );
    _enrollmentHost = null;
    _connectedEndpoints = [];
    _trustedHostKeys.clear();
    _changed();
  }

  Future<void> synchronizeForwards(
    List<Map<String, dynamic>> configurations, {
    bool activateNewStartEnabled = false,
  }) async {
    final previous = _maps(prepared['forwards']);
    final fresh = [
      for (final row in configurations) Map<String, dynamic>.from(row),
    ];
    prepared['forwards'] = fresh;
    final transport = _transport;
    final generation = _generation;
    if (!connected || transport == null) {
      _changed();
      return;
    }
    final activeIds = transport.forwards
        .map((forward) => forward.config.id)
        .toSet();
    for (final old in previous) {
      final next = fresh.where((row) => row['id'] == old['id']).firstOrNull;
      if (mapEquals(old, next) || !activeIds.contains(old['id'])) continue;
      await transport.disableForward(old['id'] as int);
      if (!_current(generation) || !connected) return;
      if (next != null) await setForward(next['id'] as int, true);
    }
    if (activateNewStartEnabled) {
      for (final next in fresh) {
        if (next['startEnabled'] == true &&
            !previous.any((row) => row['id'] == next['id'])) {
          if (!_current(generation) || !connected) return;
          await setForward(next['id'] as int, true);
        }
      }
    }
    _changed();
  }

  Future<List<SSHIdentity>> _enrollmentIdentities(int keyId) async {
    final generation = _generation;
    final key =
        lookupStoredKey?.call(keyId) ??
        _maps(prepared['keys']).where((key) => key['id'] == keyId).firstOrNull;
    if (key == null) {
      throw StateError('The selected SSH key no longer exists.');
    }
    if (key['confirmation'] == true) {
      if (await _ask(
            {
              'type': 'boolean',
              'instructions': 'SSH 키 사용 확인',
              'message': key['nickname'],
            },
            generation,
            rejectCancels: false,
          ) !=
          true) {
        throw const SshKeyAuthenticationCancelled();
      }
    }
    String? password;
    if (key['encrypted'] == true && key['loaded'] != true) {
      final value = await _ask({
        'type': 'string',
        'instructions': key['nickname'],
        'hint': 'Key password',
        'password': true,
      }, generation);
      if (value is! String) throw const SshKeyAuthenticationCancelled();
      password = value;
    }
    final identities = await loadStoredIdentities!(
      id: keyId,
      password: password,
    );
    if (!_current(generation) || !canEnroll) {
      throw StateError(
        'The original SSH connection is no longer authenticated.',
      );
    }
    if (identities.isEmpty) {
      throw StateError('Could not unlock the selected key.');
    }
    return identities;
  }

  Future<String> registerEnrollmentKey(int keyId) async {
    if (!canEnroll) {
      throw StateError('Log in to this server before registering a key.');
    }
    final identity = (await _enrollmentIdentities(keyId)).first;
    final public = identity.toPublicKey().encode();
    final kind = SSHHostKey.getType(public);
    return registerEnrollmentPublicKey(
      (command) => _transport!.execute(command, maxOutputBytes: 4096),
      '$kind ${base64.encode(public)} android-shell',
    );
  }

  Future<String> verifyEnrollmentKey(int keyId) async {
    if (!canEnroll) {
      throw StateError(
        'The original SSH connection is no longer authenticated.',
      );
    }
    final generation = _generation;
    final identities = await _enrollmentIdentities(keyId);
    final endpoints = <SshEndpoint>[];
    for (var i = 0; i < _connectedEndpoints.length; i++) {
      final original = _connectedEndpoints[i];
      final pin = _trustedHostKeys['${original.host}:${original.port}']!;
      final target = i == _connectedEndpoints.length - 1;
      endpoints.add(
        SshEndpoint(
          host: original.host,
          port: original.port,
          username: original.username,
          verifyHostKey: (algorithm, fingerprint) =>
              _current(generation) &&
              algorithm == pin.$1 &&
              utf8.decode(fingerprint) == pin.$2,
          identities: target ? identities : original.identities,
          loadIdentities: target ? null : original.loadIdentities,
          onPassword: target ? null : original.onPassword,
          onInteractive: target ? null : original.onInteractive,
          onPasswordChange: target ? null : original.onPasswordChange,
          preferredAuthMethods: target
              ? const [SSHAuthMethod.publicKey]
              : original.preferredAuthMethods,
          ipVersion: original.ipVersion,
          compression: original.compression,
          keepAliveInterval: original.keepAliveInterval,
          connectTimeout: original.connectTimeout,
          authTimeout: original.authTimeout,
          algorithms: original.algorithms,
        ),
      );
    }
    final verification = _factory(
      endpoints: endpoints,
      onOutput: (_) {},
      onState: (_) {},
      onError: (_, _) {},
      wantShell: false,
      pty: const SshPty(),
    );
    try {
      await verification.connect();
      if (!_current(generation) || !canEnroll) {
        throw StateError(
          'The original SSH connection is no longer authenticated.',
        );
      }
      return 'VERIFIED';
    } on SSHAuthError {
      // The transport does not expose whether another authentication factor was
      // requested. Never classify that as rejection or apply login settings.
      return 'INDETERMINATE';
    } finally {
      await verification.close();
    }
  }

  void _receive(Uint8List bytes, int generation) {
    if (_disposed || generation != _generation) return;
    final codec = _codecId;
    _output = _output
        .then((_) async {
          final text =
              await platform('ssh.decode', {
                    'sessionId': codec,
                    'encoding': _encoding,
                    'bytes': bytes,
                    'final': false,
                  })
                  as String;
          if (_disposed || generation != _generation) return;
          _automation?.addOutput(text);
          terminal.write(text);
        })
        .catchError((Object error, StackTrace stack) {
          _failed(error, stack);
          unawaited(_end('IO_ERROR'));
        });
  }

  Future<void> _send(String text) {
    if (!sessionOpen) return Future.error(StateError('SSH shell is not open'));
    final transport = _transport!;
    final generation = _generation, codec = _codecId;
    final pending = _input.then<void>((_) async {
      if (!_current(generation)) return;
      final bytes = await platform('ssh.encode', {
        'sessionId': codec,
        'encoding': _encoding,
        'text': text,
        'final': false,
      });
      if (_current(generation)) {
        await transport.write((bytes as List).cast<int>());
      }
    });
    _input = pending.catchError(
      (Object error, StackTrace stack) => _failed(error, stack),
    );
    return pending;
  }

  Future<void> _sendKey(int key, int modifiers) async {
    if (!sessionOpen) throw StateError('SSH shell is not open');
    if (key < 0 && key >= -0x10ffff) {
      terminal.keyInput(
        TerminalKey.none,
        text: String.fromCharCode(-key),
        shift: modifiers & 1 != 0,
        alt: modifiers & 2 != 0,
        ctrl: modifiers & 4 != 0,
      );
      await _input;
      return;
    }
    final terminalKey = key >= 257 && key <= 280
        ? TerminalKey.values[TerminalKey.f1.index + key - 257]
        : switch (key) {
            1 => TerminalKey.enter,
            2 => TerminalKey.tab,
            3 => TerminalKey.backspace,
            4 => TerminalKey.escape,
            5 => TerminalKey.arrowUp,
            6 => TerminalKey.arrowDown,
            7 => TerminalKey.arrowLeft,
            8 => TerminalKey.arrowRight,
            9 => TerminalKey.insert,
            10 => TerminalKey.delete,
            11 => TerminalKey.home,
            12 => TerminalKey.end,
            13 => TerminalKey.pageUp,
            14 => TerminalKey.pageDown,
            _ => throw UnsupportedError('Unsupported terminal key: $key'),
          };
    if (!sessionOpen) throw StateError('SSH shell is not open');
    input.sendKey(
      terminalKey,
      shift: modifiers & 1 != 0,
      alt: modifiers & 2 != 0,
      ctrl: modifiers & 4 != 0,
    );
    await _input;
  }

  List<Map<String, dynamic>> get forwards => [
    for (final row in _maps(prepared['forwards']))
      {
        ...row,
        'enabled':
            _transport?.forwards.any(
              (active) => active.config.id == row['id'],
            ) ??
            false,
      },
  ];
  Future<void> setForward(int forwardId, bool enabled) async {
    final transport = _transport;
    if (!connected || transport == null) {
      throw StateError('SSH is not connected');
    }
    if (!enabled) {
      await transport.disableForward(forwardId);
      _changed();
      return;
    }
    final config = _maps(
      prepared['forwards'],
    ).where((row) => row['id'] == forwardId).firstOrNull;
    if (config == null) throw SshAutomationError.forwardMissing;
    await transport.enableForward(
      SshForward(
        id: forwardId,
        type: switch (config['type']) {
          'local' => SshForwardType.local,
          'remote' => SshForwardType.remote,
          'dynamic5' => SshForwardType.socks5,
          _ => throw UnsupportedError('Unsupported SSH forward type'),
        },
        bindHost: config['sourceAddr'] as String? ?? 'localhost',
        bindPort: config['sourcePort'] as int,
        targetHost: config['destAddr'] as String? ?? '',
        targetPort: config['destPort'] as int? ?? 0,
      ),
    );
    _changed();
  }

  Future<void> runAutomation(List<Map<String, dynamic>> actions) async {
    final automation = _automation;
    if (automation == null) throw StateError('SSH is not connected');
    await automation.run([
      for (final action in actions)
        SshAutomationStep(
          type: switch (action['type']) {
            'WAIT_FOR_TEXT' => SshAutomationType.waitForText,
            'SEND_TEXT' => SshAutomationType.sendText,
            'SEND_KEY' => SshAutomationType.sendKey,
            'DELAY' => SshAutomationType.delay,
            'DISCONNECT' => SshAutomationType.disconnect,
            'ENABLE_FORWARD' => SshAutomationType.enableForward,
            'DISABLE_FORWARD' => SshAutomationType.disableForward,
            _ => throw UnsupportedError('Unsupported automation action'),
          },
          text: action['text'] as String? ?? '',
          regex: action['regex'] == true,
          duration: Duration(
            milliseconds: action['durationMs'] as int? ?? 30000,
          ),
          key: action['key'] as int? ?? 2,
          modifiers: action['modifiers'] as int? ?? 0,
          forwardId: action['forwardId'] as int?,
          continueOnFailure: action['failurePolicy'] == 'CONTINUE',
        ),
    ]);
  }

  @override
  Future<void> disconnect() => _end('USER_REQUESTED');
  Future<void> _end(String reason) {
    if (_disconnecting != null) return _disconnecting!;
    _disconnectReason = reason;
    return _disconnecting = _disconnect();
  }

  Future<void> _disconnect() async {
    _closing = true;
    final response = _response;
    _response = null;
    _prompt = null;
    response?.complete(null);
    _automation?.cancel();
    input.closeKeyboard();
    final transport = _transport;
    await _input;
    await transport?.close();
    await _output;
    try {
      final text =
          await platform('ssh.decode', {
                'sessionId': _codecId,
                'encoding': _encoding,
                'bytes': Uint8List(0),
                'final': true,
              })
              as String;
      if (!_disposed) {
        terminal.write(text);
        await terminal.images.drained;
      }
      await platform('ssh.encode', {
        'sessionId': _codecId,
        'encoding': _encoding,
        'text': '',
        'final': true,
      });
    } catch (error, stack) {
      _failed(error, stack);
    } finally {
      try {
        await platform('ssh.closeCodec', {'sessionId': _codecId});
      } catch (error, stack) {
        _failed(error, stack);
      }
    }
    _transport = null;
    _state = SshSessionState.closed;
    _closing = false;
    _changed();
  }

  Future<void> reconnect() async {
    await disconnect();
    if (_disposed) return;
    _disconnecting = null;
    terminal.reset();
    _banners.clear();
    for (final modifier in _modifiers.keys) {
      _modifiers[modifier] = 'OFF';
    }
    input.setModifiers();
    await connect();
  }

  // Same bounded URL syntax as TerminalLine.URL_REGEX and trimDetectedUrl.
  static final _urls = RegExp(
    r'(?:https?://|ftp://)[^\s<>"{}|\\^`\[\]]+'
    r'|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+'
    r'(?:com|org|net|edu|gov|io|dev|co|uk|de|fr|jp|ru|br|au|us|info|biz|me|tv)'
    r'(?![a-zA-Z0-9-]|\.[a-zA-Z0-9])(?::\d{1,5})?'
    r'(?:/[^\s<>"{}|\\^`\[\]]*)?'
    r'|(?:\d{1,3}\.){3}\d{1,3}:\d{1,5}(?:/[^\s<>"{}|\\^`\[\]]*)?',
  );
  List<String> scanUrls() {
    final buffer = terminal.buffer;
    final text = buffer.getText(
      BufferRangeLine(
        CellOffset(0, buffer.scrollBack),
        CellOffset(terminal.viewWidth, buffer.height - 1),
      ),
    );
    return _urls
        .allMatches(text)
        .map((match) {
          var url = match.group(0)!;
          while (url.isNotEmpty) {
            final last = url[url.length - 1];
            final unbalanced =
                (last == ')' &&
                    '('.allMatches(url).length < ')'.allMatches(url).length) ||
                (last == ']' &&
                    '['.allMatches(url).length < ']'.allMatches(url).length);
            if (!'.,;:!'.contains(last) && !unbalanced) break;
            url = url.substring(0, url.length - 1);
          }
          return url;
        })
        .toSet()
        .toList();
  }

  @override
  Future<Object?> invoke(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'session.urls':
        await _output;
        await terminal.images.drained;
        return scanUrls();
      case 'prompt.respond':
        return respond(args['token'] as String, args['value']);
      case 'session.sendText':
        await _send(args['text'] as String);
      case 'session.paste':
        input.paste(args['text'] as String);
        await _input;
      case 'session.modifier':
        final name = switch (args['code']) {
          1 => 'ctrl',
          4 => 'alt',
          16 => 'shift',
          _ => throw ArgumentError('Unknown modifier'),
        };
        _modifiers[name] = switch (_modifiers[name]) {
          'OFF' => 'TRANSIENT',
          'TRANSIENT' => 'LOCKED',
          _ => 'OFF',
        };
        input.setModifiers(
          ctrl: _modifiers['ctrl'] != 'OFF',
          alt: _modifiers['alt'] != 'OFF',
          shift: _modifiers['shift'] != 'OFF',
        );
        _changed();
      case 'session.key':
        await _sendKey(args['key'] as int, args['modifiers'] as int? ?? 0);
      case 'session.disconnect':
        await disconnect();
      case 'session.reconnect':
        await reconnect();
      case 'session.cancelAutomation':
        _automation?.cancel();
      case 'session.dismissBanner':
        _banners.removeWhere((banner) => banner['id'] == args['bannerId']);
        _changed();
      case 'forward.toggle':
        await setForward(args['id'] as int, args['enabled'] == true);
      case 'session.font':
        _fontSize = (_fontSize + (args['increase'] == true ? 1 : -1)).clamp(
          4,
          72,
        );
        _changed();
      case 'session.visibility':
        return null;
      default:
        throw UnsupportedError('Unsupported app SSH operation: $method');
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    input.dispose();
    controller.dispose();
    terminal.dispose();
  }
}
