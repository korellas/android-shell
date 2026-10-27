/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ssh/app_session.dart';
import 'ssh/enrollment.dart';
import 'ssh/key_agent.dart';
import 'platform/key_manager.dart';
import 'terminal/app_terminal_session.dart';
import 'terminal/local_session.dart';

typedef EngineRecord = Map<String, dynamic>;
EngineRecord row(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<EngineRecord> rows(Object? value) =>
    value is List ? value.map(row).toList() : [];

class AndroidEngine extends ChangeNotifier {
  AndroidEngine({AppSshTransportFactory? sshTransportFactory})
    : _sshTransportFactory = sshTransportFactory;
  final AppSshTransportFactory? _sshTransportFactory;
  static const channel = MethodChannel('dev.korellas.androidshell/engine');
  static const events = EventChannel('dev.korellas.androidshell/events');
  EngineRecord state = {};
  EngineRecord _nativeState = {};
  late final KeyManager _keys = KeyManager(_platformQuery);
  late final SshEnrollmentController _enrollment = SshEnrollmentController(
    onChanged: _sessionChanged,
    keys: () => list('keys').where((key) => key['supported'] != false).toList(),
    biometricAvailable: () =>
        row(_nativeState['generation'])['biometricAvailable'] == true,
    createBiometricKey: (name) async {
      final created = row(
        await _keys.operation('key.generate', {
          'nickname': name,
          'type': 'EC',
          'bits': 256,
          'biometric': true,
        }),
      );
      await refresh();
      return created;
    },
    readHost: (id) async {
      final fresh = row(await _platformQuery('snapshot'));
      return rows(fresh['hosts']).where((host) => host['id'] == id).firstOrNull;
    },
    saveHost: (host) async {
      await _platformQuery('host.save', host);
      await refresh();
    },
  );
  Future<List<SshAgentKey>> _agentKeys() async => [
    for (final entry in _keys.loadedIdentities.entries)
      if ((_keys.ephemeralMetadata(entry.key) ??
              list('keys').where((key) => key['id'] == entry.key).firstOrNull)
          case final metadata?)
        SshAgentKey(
          entry.value,
          '${metadata['nickname'] ?? ''}',
          confirmation: metadata['confirmation'] == true,
        ),
  ];
  bool _keyBusy = false;
  bool _sessionChangeQueued = false;
  final Map<int, AppTerminalSession> _sessions = {};
  AppTerminalSession? terminalSession(int id) => _sessions[id];
  AppSshSession? sshSession(int id) =>
      _sessions[id] is AppSshSession ? _sessions[id] as AppSshSession : null;
  final _localEvents = const EventChannel(
    'dev.korellas.androidshell/local_pty_events',
  ).receiveBroadcastStream();
  int _nextSessionId = DateTime.now().microsecondsSinceEpoch;
  int? _selectedSession;
  final _fontLoads = <String, Future<String>>{};
  Future<String> terminalFont(String name) =>
      _fontLoads.putIfAbsent(name, () async {
        final data = row(await _platformQuery('font.bytes', {'name': name}));
        if (data['bytes'] case final Uint8List bytes) {
          final family = 'terminal:$name';
          await (FontLoader(
            family,
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          return family;
        }
        return data['family'] as String? ?? 'monospace';
      });
  final _endedGenerations = <int, int>{};
  final _pendingReconnect = <int>{};
  final _attemptedReconnect = <int>{};
  bool _networkAvailable = true;
  Future<void> _runtimeUpdates = Future.value();
  Future<void> _forwardUpdates = Future.value();
  static const _runtime = MethodChannel('dev.korellas.androidshell/runtime');

  void _sessionChanged() {
    if (_closed || _sessionChangeQueued) return;
    _sessionChangeQueued = true;
    scheduleMicrotask(() {
      _sessionChangeQueued = false;
      if (!_closed) _publishSessions();
    });
  }

  void _publishSessions() {
    if (_closed) return;
    _mergeState();
    notifyListeners();
    final sessions = _runtimeRows();
    _runtimeUpdates = _runtimeUpdates
        .then((_) async {
          if (!_closed) {
            await _platformQuery('runtime.sessions', {'sessions': sessions});
            for (final record in sessions) {
              final id = record['id'] as int;
              final generation = record['connectionGeneration'] as int? ?? 0;
              if (record['ended'] == true &&
                  _endedGenerations[id] != generation) {
                _endedGenerations[id] = generation;
                await _sessionEnded(id, record);
              }
            }
          }
        })
        .catchError((Object failure) {
          if (!_closed) {
            error = '$failure';
            notifyListeners();
          }
        });
  }

  List<EngineRecord> _runtimeRows() => [
    for (final session in _sessions.values)
      {
        ...session.record,
        'host': session.host,
        if (_pendingReconnect.contains(session.id)) 'connecting': true,
      },
  ];

  Future<void> _runtimeHook(String method, EngineRecord args) {
    _publishSessions();
    final operation = _runtimeUpdates.then((_) async {
      if (!_closed) await _platformQuery(method, args);
    });
    _runtimeUpdates = operation.catchError((Object failure) {
      if (!_closed) {
        error = '$failure';
        notifyListeners();
      }
    });
    return operation;
  }

  Future<void> _removeSession(AppTerminalSession session) async {
    _pendingReconnect.remove(session.id);
    _attemptedReconnect.remove(session.id);
    _endedGenerations.remove(session.id);
    _sessions.remove(session.id);
    if (_selectedSession == session.id) _selectedSession = null;
    await session.dispose();
    _sessionChanged();
  }

  Future<void> _sessionEnded(int id, EngineRecord record) async {
    final session = _sessions[id];
    if (session == null || _closed) return;
    final reason = record['disconnectReason'] as String? ?? 'IO_ERROR';
    await _platformQuery('runtime.sessionEnded', {
      'id': '$id',
      'reason': reason,
    });
    if (!session.ended ||
        session.record['connectionGeneration'] !=
            record['connectionGeneration']) {
      return;
    }
    if (reason == 'USER_REQUESTED' || session.host['quickDisconnect'] == true) {
      await _removeSession(session);
      return;
    }
    if (reason != 'IO_ERROR' || session.host['stayConnected'] != true) {
      _pendingReconnect.remove(id);
      _sessionChanged();
      return;
    }
    _pendingReconnect.add(id);
    _mergeState();
    notifyListeners();
    // Keep the foreground/network lifetime before attempting background auth.
    await _platformQuery('runtime.sessions', {'sessions': _runtimeRows()});
    if (session is AppSshSession) {
      _networkAvailable =
          await _platformQuery('runtime.networkAvailable') == true;
      if (_networkAvailable) unawaited(_attemptReconnect(id));
    } else {
      unawaited(_attemptReconnect(id));
    }
  }

  Future<void> _attemptReconnect(int id) async {
    final session = _sessions[id];
    if (_closed ||
        session == null ||
        !session.ended ||
        !_pendingReconnect.contains(id) ||
        !_attemptedReconnect.add(id)) {
      return;
    }
    try {
      await session.connect();
    } catch (failure) {
      if (!_closed) {
        error = '$failure';
      }
    }
    if (session.record['connected'] == true) {
      _pendingReconnect.remove(id);
      _attemptedReconnect.remove(id);
    }
    if (session is AppLocalSession && session.ended) {
      _pendingReconnect.remove(id);
    }
    _sessionChanged();
  }

  void _networkChanged(bool available) {
    final restored = available && !_networkAvailable;
    _networkAvailable = available;
    if (!restored) return;
    for (final id in _pendingReconnect.toList()) {
      _attemptedReconnect.remove(id);
      unawaited(_attemptReconnect(id));
    }
  }

  void _mergeState() {
    final common = _sessions.values.toList();
    state = {
      ..._nativeState,
      'keyState': _keys.state,
      'keys': _keys.decorateKeys(rows(_nativeState['keys'])),
      'enrollment': _enrollment.state,
      'startupKeys': _keys.pendingStartup,
      'generation': {...row(_nativeState['generation']), 'busy': _keyBusy},
      'sessions': [
        ...rows(_nativeState['sessions']),
        for (final s in common)
          {
            ...s.record,
            if (_pendingReconnect.contains(s.id)) 'connecting': true,
          },
      ],
      'prompts': [
        ...rows(_nativeState['prompts']),
        for (final s in common) ...s.prompts,
      ],
      'selectedSession': _selectedSession ?? _nativeState['selectedSession'],
      'hosts': [
        for (final host in rows(_nativeState['hosts']))
          {
            ...host,
            if (common.any((s) => s.host['id'] == host['id']))
              'connectionState':
                  common.any(
                    (s) =>
                        s.host['id'] == host['id'] &&
                        (s.sessionOpen || s.record['connected'] == true),
                  )
                  ? 'CONNECTED'
                  : common.any(
                      (s) =>
                          s.host['id'] == host['id'] &&
                          (s.connecting || _pendingReconnect.contains(s.id)),
                    )
                  ? 'CONNECTING'
                  : 'DISCONNECTED',
          },
      ],
    };
  }

  Future<int?> _connectTerminal(EngineRecord args) async {
    final prepared = row(await _platformQuery('session.prepare', args));
    final jumps = rows(prepared['jumps']);
    prepared['jumps'] = jumps;
    for (final config in [prepared, ...jumps]) {
      config['keys'] = _keys.decorateKeys(rows(config['keys']));
    }
    if (args.containsKey('actions')) {
      prepared['automation'] = rows(args['actions']);
    }
    final host = row(prepared['host']);
    AppTerminalSession? existing;
    if (args['newSession'] != true) {
      for (final session in _sessions.values) {
        if (session.host['hostname'] == host['hostname'] &&
            session.host['port'] == host['port'] &&
            session.host['username'] == host['username'] &&
            session.host['id'] == host['id']) {
          existing = session;
          break;
        }
      }
    }
    if (existing != null && existing.ended && !existing.connecting) {
      await existing.disconnect();
      if (existing is AppSshSession) {
        existing.refreshPrepared(prepared);
      } else {
        existing.prepared
          ..clear()
          ..addAll(prepared);
      }
    }
    void notify(EngineRecord value) {
      if (_closed) return;
      notification = value;
      notifyListeners();
    }

    final session =
        existing ??
        (host['protocol'] == 'local'
            ? AppLocalSession(
                id: ++_nextSessionId,
                prepared: prepared,
                platform: _platformQuery,
                events: _localEvents,
                onChanged: _sessionChanged,
                onNotification: notify,
              )
            : AppSshSession(
                transportFactory: _sshTransportFactory,
                id: ++_nextSessionId,
                prepared: prepared,
                platform: _platformQuery,
                onChanged: _sessionChanged,
                onNotification: notify,
                loadStoredIdentities: _keys.identities,
                lookupStoredKey: (id) =>
                    list('keys').where((key) => key['id'] == id).firstOrNull,
                loadAgentKeys: _agentKeys,
                addAgentKey: (key, confirmation) async {
                  final result = await _keys.addAgentKey(key, confirmation);
                  _sessionChanged();
                  return result;
                },
                removeAgentKey: (key) async {
                  final result = await _keys.removeAgentKey(key);
                  _sessionChanged();
                  return result;
                },
                removeAllAgentKeys: () async {
                  final result = await _keys.removeAllAgentKeys();
                  _sessionChanged();
                  return result;
                },
              ));
    _pendingReconnect.remove(session.id);
    _attemptedReconnect.remove(session.id);
    _sessions[session.id] = session;
    session.terminal.onBell = () {
      unawaited(_runtimeHook('runtime.bell', {'id': '${session.id}'}));
    };
    _selectedSession = session.id;
    _sessionChanged();
    if (!session.sessionOpen &&
        session.record['connected'] != true &&
        !session.connecting) {
      unawaited(session.connect());
    }
    return session.id;
  }

  String? error;
  EngineRecord? sessionSwitch;
  EngineRecord? textInput;
  EngineRecord? notification;
  bool get isDisposed => _closed;
  StreamSubscription<dynamic>? _subscription;
  bool _refreshing = false;
  Completer<void>? _refreshCompletion;
  bool _again = false;
  bool _closed = false;
  List<EngineRecord> list(String key) => rows(state[key]);
  EngineRecord get preferences => row(state['preferences']);
  bool get ready => state['ready'] == true;
  Future<void> start() async {
    _runtime.setMethodCallHandler((call) async {
      if (call.method == 'disconnectAll') await query('session.disconnectAll');
    });
    _subscription = events.receiveBroadcastStream().listen(
      (event) {
        final data = row(event);
        if (_closed) return;
        if (data['type'] == 'networkChanged') {
          _networkChanged(data['available'] == true);
        }
        if (data['type'] == 'connect') {
          unawaited(_connectIntent(data));
        }
        if (data['type'] == 'textInput') {
          textInput = data;
          notifyListeners();
        }
        if (data['type'] == 'switchSession') {
          sessionSwitch = data;
          notifyListeners();
        }
        if (data['type'] == 'message') {
          notification = data;
          notifyListeners();
        }
        refresh();
      },
      onError: (Object e) {
        if (_closed) return;
        error = '$e';
        notifyListeners();
      },
    );
    await refresh();
  }

  Future<void> _connectIntent(EngineRecord data) async {
    try {
      final existing = _sessions[data['id']];
      if (existing != null) {
        _selectedSession = existing.id;
        if (data['reconnect'] == true && existing.ended) {
          await _connectTerminal({
            if ((existing.host['id'] as int? ?? -1) > 0)
              'id': existing.host['id']
            else
              'uri': existing.record['uri'],
          });
        }
        _sessionChanged();
      } else if (data['uri'] is String) {
        await _connectTerminal({'uri': data['uri']});
      }
    } catch (failure) {
      if (_closed) return;
      notification = {'type': 'message', 'message': '$failure'};
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_closed) return;
    if (_refreshing) {
      _again = true;
      return _refreshCompletion!.future;
    }
    _refreshing = true;
    final completion = _refreshCompletion = Completer<void>();
    try {
      do {
        _again = false;
        final snapshot = row(await channel.invokeMethod<Object?>('snapshot'));
        if (_closed) return;
        _nativeState = snapshot;
        if (_nativeState['ready'] == true) {
          final keys = rows(_nativeState['keys']);
          await _keys.initializeStartup(keys);
          _nativeState['keys'] = _keys.decorateKeys(keys);
        }
        _mergeState();
        if (!_closed) notifyListeners();
      } while (_again && !_closed);
    } on PlatformException catch (e) {
      error = e.message ?? e.code;
      if (!_closed) notifyListeners();
    } finally {
      _refreshing = false;
      _refreshCompletion = null;
      completion.complete();
    }
  }

  Future<dynamic> query(String method, [EngineRecord args = const {}]) async {
    if (method == 'key.enrollmentBegin') {
      _enrollment.begin(args['name'] as String? ?? '');
      return null;
    }
    if (method == 'key.enroll') {
      final session = sshSession(args['sessionId'] as int);
      if (session == null || !session.canEnroll) {
        throw const EngineException('연결된 SSH 세션에서 키를 등록해 주세요.');
      }
      return _enrollment.enroll(
        originalHost: session.enrollmentHost,
        canEnroll: session.captureEnrollmentValidity(),
        register: session.registerEnrollmentKey,
        verify: session.verifyEnrollmentKey,
        username: session.enrollmentUsername,
        keyId: args['keyId'] as int?,
        name: args['name'] as String? ?? '',
      );
    }
    if (method.startsWith('key.') &&
        !method.startsWith('key.enroll') &&
        !method.startsWith('key.storage')) {
      _keyBusy = true;
      _mergeState();
      notifyListeners();
      try {
        return await _keys.operation(method, args);
      } finally {
        _keyBusy = false;
        await refresh();
      }
    }
    if (method == 'connect') {
      final host = list(
        'hosts',
      ).where((h) => h['id'] == args['id']).firstOrNull;
      final uri = args['uri'] as String?;
      final protocol =
          host?['protocol'] ??
          (uri != null && Uri.tryParse(uri)?.hasScheme == true
              ? Uri.parse(uri).scheme
              : 'ssh');
      if ((protocol == 'ssh' || protocol == 'local') &&
          state['entryAction'] != 'android.intent.action.PICK') {
        return _connectTerminal(args);
      }
    }
    if (const {
      'forward.save',
      'forward.delete',
      'forward.start',
    }.contains(method)) {
      final operation = _forwardUpdates.then((_) async {
        final affected = _sessions.values
            .whereType<AppSshSession>()
            .where(
              (session) =>
                  session.host['id'] == args['hostId'] ||
                  session.forwards.any(
                    (forward) => forward['id'] == args['id'],
                  ),
            )
            .toList();
        final result = await _platformQuery(method, args);
        for (final session in affected) {
          final configurations = rows(
            await _platformQuery('forwards', {'hostId': session.host['id']}),
          );
          await session.synchronizeForwards(
            configurations,
            activateNewStartEnabled:
                method == 'forward.save' && args['sessionId'] == session.id,
          );
        }
        return result;
      });
      _forwardUpdates = operation.then<void>((_) {}, onError: (Object _) {});
      return operation;
    }
    if (method == 'automation.trial') {
      return _connectTerminal({
        'id': args['hostId'],
        'newSession': true,
        'actions': args['actions'],
      });
    }
    if (method == 'session.consumeSelection') {
      _selectedSession = null;
      _sessionChanged();
      return null;
    }
    if (method == 'session.select' && _sessions.containsKey(args['id'])) {
      _selectedSession = args['id'] as int;
      _sessionChanged();
      return null;
    }
    if (method == 'session.disconnectAll' || method == 'host.disconnect') {
      for (final session in _sessions.values.toList()) {
        if ((method == 'session.disconnectAll' &&
                !(args['excludeLocal'] == true &&
                    session.host['protocol'] == 'local')) ||
            (method == 'host.disconnect' && session.host['id'] == args['id'])) {
          if (session.ended || _pendingReconnect.contains(session.id)) {
            _endedGenerations[session.id] =
                session.record['connectionGeneration'] as int? ?? 0;
            _attemptedReconnect.add(session.id);
            _pendingReconnect.remove(session.id);
            await session.disconnect();
            await _runtimeHook('runtime.sessionEnded', {
              'id': '${session.id}',
              'reason': 'USER_REQUESTED',
            });
            await _removeSession(session);
          } else {
            await session.disconnect();
          }
        }
      }
    }
    if (method == 'session.disconnectAll' || method == 'host.disconnect') {
      return null;
    }
    final id = args['sessionId'] ?? args['id'];
    final session = _sessions[id];
    if (session != null) {
      if (method == 'session.disconnect' &&
          (session.ended || _pendingReconnect.contains(session.id))) {
        _endedGenerations[session.id] =
            session.record['connectionGeneration'] as int? ?? 0;
        _attemptedReconnect.add(session.id);
        _pendingReconnect.remove(session.id);
        await session.disconnect();
        await _runtimeHook('runtime.sessionEnded', {
          'id': '${session.id}',
          'reason': 'USER_REQUESTED',
        });
        await _removeSession(session);
        return null;
      }
      if (method == 'forwards' && session is AppSshSession) {
        return session.forwards;
      }
      if (method == 'forward.toggle' && session is AppSshSession) {
        final forward = session.forwards
            .where((f) => f['id'] == args['id'])
            .first;
        await session.setForward(
          args['id'] as int,
          args['enabled'] as bool? ?? (forward['enabled'] != true),
        );
        return null;
      }
      if (method.startsWith('session.') && method != 'session.visibility' ||
          method == 'prompt.respond') {
        return session.invoke(method, args);
      }
    }
    if (method == 'session.visibility') {
      if (session == null) return null;
      await _runtimeHook('runtime.visibility', {
        'id': '${session.id}',
        'visible': args['visible'] == true,
      });
      return _platformQuery(method, {...args, 'open': session.sessionOpen});
    }
    return _platformQuery(method, args);
  }

  Future<dynamic> _platformQuery(
    String method, [
    Map<String, Object?> args = const {},
  ]) async {
    try {
      final runtimeMethod =
          method.startsWith('local.') ||
          method.startsWith('runtime.') ||
          const {'ssh.decode', 'ssh.encode', 'ssh.closeCodec'}.contains(method);
      return await (runtimeMethod ? _runtime : channel).invokeMethod<dynamic>(
        method,
        args,
      );
    } on PlatformException catch (e) {
      throw EngineException(e.message ?? e.code, details: e.toString());
    }
  }

  Future<dynamic> invoke(String method, [EngineRecord args = const {}]) async {
    try {
      final result = await query(method, args);
      await refresh();
      return result;
    } on PlatformException catch (e) {
      throw EngineException(e.message ?? e.code, details: e.toString());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _subscription?.cancel();
    _runtime.setMethodCallHandler(null);
    for (final session in _sessions.values) {
      unawaited(session.dispose());
    }
    _sessions.clear();
    super.dispose();
  }
}

class EngineException implements Exception {
  final String message;
  final String? details;
  const EngineException(this.message, {this.details});
  @override
  String toString() => message;
}
