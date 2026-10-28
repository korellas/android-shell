// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';
import 'app_terminal_session.dart';
import 'terminal_input.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

class AppLocalSession implements AppTerminalSession {
  AppLocalSession({
    required this.id,
    required this.prepared,
    required this.platform,
    required this.events,
    required this.onChanged,
    this.onNotification,
  }) {
    terminal = Terminal(
      maxLines: (host['scrollbackLines'] as int? ?? 1000).clamp(1, 100000),
      onClipboardStore: (_, _) {},
      clipboardDecoder: (_, _) => null,
      allowITerm2ClipboardCapture: false,
      allowKittyClipboard: false,
      onClipboardQuery: (_) => null,
      onOutput: (text) => unawaited(_send(text).catchError(_failed)),
      onResize: (width, height, pixelWidth, pixelHeight) {
        if (sessionOpen) {
          unawaited(
            platform('local.resize', {
              'id': _runtimeId,
              ..._size(width, height),
              'pixelWidth': pixelWidth,
              'pixelHeight': pixelHeight,
            }).then<void>((_) {}, onError: _failed),
          );
        }
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
  final TerminalPlatformCall platform;
  final Stream<dynamic> events;
  final VoidCallback onChanged;
  final void Function(Map<String, dynamic>)? onNotification;
  @override
  late final Terminal terminal;
  @override
  final controller = TerminalController();
  @override
  late final TerminalInputController input;
  @override
  Map<String, dynamic> get host => _map(prepared['host']);
  @override
  Map<String, dynamic> get profile => _map(prepared['profile']);
  @override
  double get fontSize => _fontSize;
  late double _fontSize;
  @override
  bool get sessionOpen => _open && !_closing;
  @override
  bool get connecting => _connecting && !_closing;
  @override
  bool get ended => _ended;
  @override
  List<Map<String, dynamic>> get prompts => [];
  bool _open = false,
      _connecting = false,
      _closing = false,
      _ended = false,
      _disposed = false;
  int _generation = 0;
  String get _runtimeId => 'app-local-$id-$_generation';
  String get _encoding => profile['encoding'] as String? ?? 'UTF-8';
  String? _error;
  String? _disconnectReason;
  Future<Object?>? _starting;
  final _modifiers = {'ctrl': 'OFF', 'alt': 'OFF', 'shift': 'OFF'};
  Future<void> _output = Future.value(), _input = Future.value();
  Future<void>? _disconnecting;
  StreamSubscription<dynamic>? _subscription;
  @override
  Map<String, dynamic> get record => {
    'id': id,
    'hostId': host['id'],
    'nickname': host['nickname'],
    'protocol': 'local',
    'uri': 'local://localhost',
    'open': sessionOpen,
    'connected': sessionOpen,
    'connectionGeneration': _generation,
    'disconnectReason': _disconnectReason,
    'connecting': connecting,
    'ended': ended,
    'awaitingClose': ended,
    'canForward': false,
    'canEnroll': false,
    'composeMode': false,
    'columns': terminal.viewWidth,
    'rows': terminal.viewHeight,
    'fontSize': fontSize,
    'modifiers': {..._modifiers},
    'progress': _error == null
        ? null
        : {'state': 'ERROR', 'value': 0, 'message': _error},
    'banners': <Map<String, dynamic>>[],
    for (final key in ['foregroundColor', 'backgroundColor', 'cursorColor'])
      if (_map(prepared['scheme']).containsKey(key))
        key: _map(prepared['scheme'])[key],
  };
  Map<String, Object?> _size(int width, int height) => {
    'columns': width,
    'rows': height,
  };
  void _changed() {
    if (!_disposed) onChanged();
  }

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

  @override
  Future<void> connect() async {
    if (_disposed || _connecting || _open || _closing) {
      throw StateError('Disconnect before reconnecting');
    }
    TerminalSessionOperations.configureInput(
      terminal,
      profile['delKey'] as String?,
    );
    _disconnecting = null;
    _generation++;
    final runtime = _runtimeId;
    _connecting = true;
    _ended = false;
    _error = null;
    _disconnectReason = null;
    _changed();
    _subscription = events.listen(
      (dynamic value) {
        final event = _map(value);
        if (event['id'] != runtime || _disposed || _closing) return;
        if (event['type'] == 'output') {
          final bytes = Uint8List.fromList(
            (event['bytes'] as List).cast<int>(),
          );
          _output = _output
              .then((_) async {
                final text =
                    await platform('ssh.decode', {
                          'sessionId': runtime,
                          'encoding': _encoding,
                          'bytes': bytes,
                          'final': false,
                        })
                        as String;
                if (!_disposed) {
                  terminal.write(text);
                }
              })
              .catchError((Object error, StackTrace stack) {
                _failed(error, stack);
                unawaited(_end('IO_ERROR'));
              });
        } else if (event['type'] == 'exit') {
          unawaited(_end('SESSION_EXIT'));
        }
      },
      onError: (Object error, StackTrace stack) {
        _failed(error, stack);
        unawaited(_end('IO_ERROR'));
      },
    );
    try {
      _starting = platform('local.start', {
        'id': runtime,
        ..._size(terminal.viewWidth, terminal.viewHeight),
        'term': profile['emulation'] as String? ?? 'xterm-256color',
      });
      await _starting;
      if (!_closing && !_ended && !_disposed) {
        _open = true;
      }
    } catch (error, stack) {
      _failed(error, stack);
      await _end('IO_ERROR');
    } finally {
      _connecting = false;
      _changed();
    }
  }

  Future<void> _send(String text) {
    if (!sessionOpen) {
      return Future.error(StateError('Local shell is not open'));
    }
    final runtime = _runtimeId;
    final pending = _input.then<void>((_) async {
      if (!_open || runtime != _runtimeId) return;
      final bytes = await platform('ssh.encode', {
        'sessionId': runtime,
        'encoding': _encoding,
        'text': text,
        'final': false,
      });
      if (_open && runtime == _runtimeId) {
        await platform('local.write', {'id': runtime, 'bytes': bytes});
      }
    });
    _input = pending.catchError(_failed);
    return pending;
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
    input.closeKeyboard();
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _input;
      try {
        await _starting;
      } catch (_) {}
      await platform('local.close', {'id': _runtimeId});
      await _output;
      final text =
          await platform('ssh.decode', {
                'sessionId': _runtimeId,
                'encoding': _encoding,
                'bytes': Uint8List(0),
                'final': true,
              })
              as String;
      if (!_disposed) {
        terminal.write(text);
      }
      await platform('ssh.encode', {
        'sessionId': _runtimeId,
        'encoding': _encoding,
        'text': '',
        'final': true,
      });
    } finally {
      try {
        await platform('ssh.closeCodec', {'sessionId': _runtimeId});
      } finally {
        _open = false;
        _connecting = false;
        _ended = true;
        _closing = false;
        _changed();
      }
    }
  }

  Future<void> reconnect() async {
    await disconnect();
    if (_disposed) return;
    terminal.reset();
    for (final key in _modifiers.keys) {
      _modifiers[key] = 'OFF';
    }
    input.setModifiers();
    await connect();
  }

  Future<void> _sendKey(int key, int modifiers) async {
    if (!sessionOpen) throw StateError('Local shell is not open');
    if (key < 0 && key >= -0x10ffff) {
      terminal.keyInput(
        TerminalKey.none,
        text: String.fromCharCode(-key),
        shift: modifiers & 1 != 0,
        alt: modifiers & 2 != 0,
        ctrl: modifiers & 4 != 0,
      );
    } else {
      input.sendKey(
        TerminalSessionOperations.key(key),
        shift: modifiers & 1 != 0,
        alt: modifiers & 2 != 0,
        ctrl: modifiers & 4 != 0,
      );
    }
    await _input;
  }

  @override
  Future<Object?> invoke(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'session.sendText':
        await _send(args['text'] as String);
      case 'session.paste':
        input.paste(args['text'] as String);
        await _input;
      case 'session.key':
        await _sendKey(args['key'] as int, args['modifiers'] as int? ?? 0);
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
      case 'session.urls':
        await _output;
        return TerminalSessionOperations.scanUrls(terminal);
      case 'session.font':
        _fontSize = (_fontSize + (args['increase'] == true ? 1 : -1)).clamp(
          4,
          72,
        );
        _changed();
      case 'session.disconnect':
        await disconnect();
      case 'session.reconnect':
        await reconnect();
      case 'session.visibility':
        return null;
      case 'session.dismissBanner':
        return null;
      default:
        throw UnsupportedError('Unsupported local terminal operation: $method');
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
