// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/files/transfer.dart';
import 'package:android_shell_ui/platform/ssh_keys.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';

const _defaultProfile = <String, Object?>{
  'id': 1,
  'name': '기본 프로필',
  'fontFamily': 'D2CODING',
  'fontSize': 14,
  'encoding': 'UTF-8',
  'emulation': 'xterm-256color',
  'colorSchemeId': -1,
};
const _defaultHost = <String, Object?>{
  'protocol': 'ssh',
  'port': 22,
  'pubkeyId': -1,
  'wantSession': true,
  'useKeys': true,
  'scrollbackLines': 1000,
  'profileId': 1,
};

// Preset IDs match ColorSchemePresets.builtInSchemes on Android.
const _baseSchemes = <EngineRecord>[
  {
    'id': -1,
    'name': 'Tilde Night',
    'description': 'Tilde dark terminal palette',
    'isBuiltIn': true,
    'foreground': 7,
    'background': 0,
    'foregroundColor': 0xffeae9e7,
    'backgroundColor': 0xff13110f,
    'cursorColor': 0xff6fd8c4,
    'palette': [
      0xff262421,
      0xffff8577,
      0xff8fd694,
      0xffebc37a,
      0xff7fb4f0,
      0xffc9a2f2,
      0xff6fd8c4,
      0xffc9c6c1,
      0xff4a4743,
      0xffffa59a,
      0xffade6b0,
      0xfff4d69e,
      0xffa3caf6,
      0xffdabcf7,
      0xff9be6d7,
      0xfff4f3f1,
    ],
  },
  {
    'id': -9,
    'name': 'Tilde Day',
    'description': 'Tilde light terminal palette',
    'isBuiltIn': true,
    'foreground': 0,
    'background': 15,
    'foregroundColor': 0xff2e2b25,
    'backgroundColor': 0xfff6f5f0,
    'cursorColor': 0xff006e5f,
    'palette': [
      0xff2e2b25,
      0xffc2362b,
      0xff357344,
      0xff8a641f,
      0xff2b659c,
      0xff7954a8,
      0xff006e5f,
      0xffd5d4cb,
      0xff67635c,
      0xffd64b40,
      0xff4d925a,
      0xffad812c,
      0xff427eba,
      0xff9971c7,
      0xff259483,
      0xfff6f5f0,
    ],
  },
];

class StoredPlatform {
  StoredPlatform({
    required this.file,
    required this.native,
    required this.protect,
    required this.unprotect,
    this.platform = 'windows',
    this.hardwareKeyboard = true,
    this.exportFile,
  });
  final File file;
  final String platform;
  final bool hardwareKeyboard;
  final Future<void> Function(String path)? exportFile;
  final SshPlatformCall native;
  final Future<Uint8List> Function(Uint8List) protect, unprotect;
  Future<void>? _loaded;
  Future<void> _writes = Future.value();
  int _nextId = DateTime.now().microsecondsSinceEpoch;
  final _decoders = <String, (ByteConversionSink, StringBuffer)>{};
  final _deletedHosts = <String, EngineRecord>{};
  Map<String, dynamic> _passwords = {};
  Map<String, dynamic> _data = {
    'version': 1,
    'hosts': [],
    'identities': [],
    'keys': [],
    'forwards': [],
    'knownHosts': [],
    'schemes': [],
    'profiles': [Map<String, Object?>.of(_defaultProfile)],
    'preferences': {'defaultProfileId': 1, 'themeMode': 'DARK'},
  };

  Future<void> _load() => _loaded ??= _read();
  List<EngineRecord> _records(String name) => rows(_data[name]);
  int _id() => ++_nextId;
  EngineRecord _find(String name, Object? id) =>
      _records(name).firstWhere((record) => record['id'] == id);
  EngineRecord _preferences() => row(_data['preferences']);

  Future<void> _read() async {
    if (!await file.exists()) return;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['preferences'] is! Map) {
      throw const FormatException('저장된 접속 설정이 올바르지 않습니다.');
    }
    for (final field in [
      'hosts',
      'identities',
      'keys',
      'forwards',
      'knownHosts',
      'profiles',
    ]) {
      if (decoded[field] is! List ||
          (decoded[field] as List).any((value) => value is! Map)) {
        throw FormatException('저장된 $field 설정이 올바르지 않습니다.');
      }
    }
    if (decoded['schemes'] != null &&
        (decoded['schemes'] is! List ||
            (decoded['schemes'] as List).any(
              (value) =>
                  value is! Map ||
                  value['palette'] is! List ||
                  (value['palette'] as List).length != 16 ||
                  (value['palette'] as List).any((color) => color is! int),
            ))) {
      throw const FormatException('저장된 색상 테마가 올바르지 않습니다.');
    }
    _data = {...decoded, 'schemes': decoded['schemes'] ?? []};
    final sealed = _data['secrets'] as String?;
    if (sealed != null) {
      _passwords = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(await unprotect(base64Decode(sealed)))) as Map,
      );
    }
    for (final field in [
      'hosts',
      'identities',
      'keys',
      'forwards',
      'knownHosts',
      'profiles',
      'schemes',
    ]) {
      for (final record in _records(field)) {
        final id = record['id'];
        if (id is int && id >= _nextId) _nextId = id + 1;
      }
    }
  }

  Future<void> _save() {
    final operation = _writes.then((_) async {
      final snapshot = Map<String, dynamic>.from(_data);
      if (_passwords.isEmpty) {
        snapshot.remove('secrets');
      } else {
        snapshot['secrets'] = base64Encode(
          await protect(
            Uint8List.fromList(utf8.encode(jsonEncode(_passwords))),
          ),
        );
      }
      await file.parent.create(recursive: true);
      final staging = await file.parent.createTemp('.state-');
      try {
        final temporary = File('${staging.path}/state.json');
        await temporary.writeAsString(jsonEncode(snapshot), flush: true);
        await temporary.rename(file.path);
      } finally {
        await staging.delete(recursive: true);
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  EngineRecord _upsert(String table, Map<String, Object?> args) {
    final records = _records(table);
    final previous = records
        .where((record) => record['id'] == args['id'])
        .firstOrNull;
    final record = {...?previous, ...args, 'id': previous?['id'] ?? _id()}
      ..remove('password')
      ..remove('clearPassword');
    records.removeWhere((value) => value['id'] == record['id']);
    records.add(record);
    _data[table] = records;
    return record;
  }

  void _remove(String table, Object? id) {
    _data[table] = _records(table)..removeWhere((record) => record['id'] == id);
  }

  void _updatePassword(String key, Map<String, Object?> args) {
    if (args['clearPassword'] == true) _passwords.remove(key);
    final password = args['password'];
    if (password is String && password.isNotEmpty) _passwords[key] = password;
  }

  EngineRecord _snapshot() {
    final hosts = _records('hosts')
      ..sort((a, b) => '${a['nickname']}'.compareTo('${b['nickname']}'));
    return {
      ..._data,
      'secrets': null,
      'platform': platform,
      'ready': true,
      'hardwareKeyboard': hardwareKeyboard,
      'preferences': {
        ..._preferences(),
        'fontFamily': _preferences()['fontFamily'] ?? 'D2CODING',
        'fonts': const [
          {'value': 'D2CODING', 'label': 'D2Coding'},
          {'value': 'JETBRAINS_MONO', 'label': 'JetBrains Mono'},
        ],
      },
      'terminalTypes': ['xterm-256color'],
      'encodings': ['UTF-8'],
      'defaults': {
        'host': _defaultHost,
        'profile': {..._defaultProfile, 'id': 0, 'name': ''},
      },
      'hosts': [
        for (final host in hosts)
          {
            ...host,
            'hasPassword': _passwords.containsKey('host:${host['id']}'),
          },
      ],
      'identities': [
        for (final identity in _records('identities'))
          {
            ...identity,
            'hasPassword': _passwords.containsKey('identity:${identity['id']}'),
          },
      ],
      'schemes': [for (final scheme in _schemes) _scheme(scheme['id'])],
      'generation': {'biometricAvailable': false},
      'sessions': [],
      'prompts': [],
    };
  }

  EngineRecord _prepare(Map<String, Object?> args) {
    EngineRecord host;
    if (args['id'] is int) {
      host = _find('hosts', args['id']);
    } else {
      final text = args['uri'] as String;
      final uri = Uri.parse(text.contains('://') ? text : 'ssh://$text');
      if (uri.scheme != 'ssh' ||
          uri.host.isEmpty ||
          uri.userInfo.contains(':')) {
        throw const FormatException('SSH 주소를 확인하세요.');
      }
      host = {
        ..._defaultHost,
        'id': -1,
        'hostname': uri.host,
        'port': uri.hasPort ? uri.port : 22,
        'username': uri.userInfo,
        'nickname': uri.host,
      };
    }
    if (host['protocol'] != 'ssh') {
      throw UnsupportedError('SSH 호스트를 사용하세요.');
    }
    final profile = _find(
      'profiles',
      host['profileId'] ?? _preferences()['defaultProfileId'],
    );
    if (profile['encoding'] != 'UTF-8') {
      throw UnsupportedError('이 터미널은 UTF-8을 사용합니다.');
    }
    final identityId = host['identityId'];
    final identity = identityId == null
        ? null
        : _find('identities', identityId);
    if (identity != null) {
      host = {
        ...host,
        'username': identity['username'],
        'pubkeyId': identity['pubkeyId'],
      };
    }
    final pubkeyId = host['pubkeyId'] ?? -1;
    return {
      'host': host,
      'profile': profile,
      'scheme': _scheme(
        _schemes.any((scheme) => scheme['id'] == profile['colorSchemeId'])
            ? profile['colorSchemeId']
            : -1,
      ),
      'password':
          _passwords[identityId == null
              ? 'host:${host['id']}'
              : 'identity:$identityId'],
      'keys': host['useKeys'] == false || pubkeyId == -2
          ? []
          : _records(
              'keys',
            ).where((key) => pubkeyId == -1 || key['id'] == pubkeyId).toList(),
      'forwards': _records(
        'forwards',
      ).where((forward) => forward['hostId'] == host['id']).toList(),
    };
  }

  List<EngineRecord> get _schemes => [..._baseSchemes, ..._records('schemes')];
  EngineRecord _scheme(Object? id) {
    final value = _schemes.where((scheme) => scheme['id'] == id).firstOrNull;
    if (value == null) throw ArgumentError('색상 테마를 찾을 수 없습니다.');
    final palette = List<int>.from(value['palette'] as List);
    final foreground =
        value['foregroundColor'] ?? palette[value['foreground'] as int? ?? 7];
    return {
      ...value,
      'palette': palette,
      'foregroundColor': foreground,
      'backgroundColor':
          value['backgroundColor'] ?? palette[value['background'] as int? ?? 0],
      'cursorColor': value['cursorColor'] ?? foreground,
    };
  }

  String _schemeName(Object? value, {Object? except}) {
    if (value is! String || value.trim().isEmpty) {
      throw ArgumentError('테마 이름을 입력하세요.');
    }
    final name = value.trim();
    if (_schemes.any(
      (scheme) =>
          scheme['id'] != except &&
          '${scheme['name']}'.toLowerCase() == name.toLowerCase(),
    )) {
      throw ArgumentError('같은 이름의 테마가 있습니다.');
    }
    return name;
  }

  int _hexColor(Object? value) {
    if (value is! String ||
        !RegExp(r'^#?(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(value)) {
      throw const FormatException('색상은 3자리 또는 6자리 16진수여야 합니다.');
    }
    var hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length == 3) {
      hex = hex.split('').map((digit) => '$digit$digit').join();
    }
    return 0xff000000 | int.parse(hex, radix: 16);
  }

  Future<Object?> _schemeOperation(
    String method,
    Map<String, Object?> args,
  ) async {
    final id = args['id'];
    if (method == 'scheme.import') {
      final decoded = jsonDecode(args['text'] as String);
      if (decoded is! Map<String, dynamic> ||
          decoded['name'] is! String ||
          (decoded['name'] as String).trim().isEmpty ||
          decoded['colors'] is! Map ||
          (decoded['version'] ?? 1) != 1) {
        throw const FormatException('색상 테마 파일 형식이 올바르지 않습니다.');
      }
      final foreground = decoded['foreground'] ?? 7,
          background = decoded['background'] ?? 0;
      if (foreground is! int ||
          foreground < 0 ||
          foreground > 15 ||
          background is! int ||
          background < 0 ||
          background > 15) {
        throw const FormatException('기본 색상 번호는 0–15여야 합니다.');
      }
      final palette = List<int>.filled(16, 0);
      for (final entry in (decoded['colors'] as Map).entries) {
        final index = int.tryParse('${entry.key}');
        if (index == null || index < 0 || index > 15) {
          throw const FormatException('ANSI 색상 번호는 0–15여야 합니다.');
        }
        palette[index] = _hexColor(entry.value);
      }
      final roles = <String, int>{};
      for (final role in [
        'foregroundColor',
        'backgroundColor',
        'cursorColor',
      ]) {
        if (decoded[role] != null) roles[role] = _hexColor(decoded[role]);
      }
      if (decoded['description'] != null && decoded['description'] is! String) {
        throw const FormatException('테마 설명 형식이 올바르지 않습니다.');
      }
      final requested = (decoded['name'] as String).trim();
      var name = requested, suffix = 1;
      while (_schemes.any(
        (scheme) => '${scheme['name']}'.toLowerCase() == name.toLowerCase(),
      )) {
        name = '$requested (${suffix++})';
      }
      final record = _upsert('schemes', {
        'name': name,
        'description': decoded['description'] ?? '',
        'foreground': foreground,
        'background': background,
        'palette': palette,
        ...roles,
      });
      await _save();
      return record['id'];
    }
    if (method == 'scheme.create' || method == 'scheme.duplicate') {
      final source = _scheme(
        method == 'scheme.create' ? args['sourceId'] ?? -1 : id,
      );
      final record = _upsert('schemes', {
        ...source,
        'id': null,
        'name': _schemeName(args['name']),
        'description': args['description'] ?? '',
        'isBuiltIn': false,
      });
      await _save();
      return record['id'];
    }
    final scheme = _scheme(id);
    if (method == 'scheme.palette') {
      return {
        'colors': scheme['palette'],
        'foregroundColor': scheme['foregroundColor'],
        'backgroundColor': scheme['backgroundColor'],
        'cursorColor': scheme['cursorColor'],
      };
    }
    if (method == 'scheme.export') {
      String hex(int value) =>
          '#${(value & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      return const JsonEncoder.withIndent('  ').convert({
        'name': scheme['name'],
        'description': scheme['description'] ?? '',
        'version': 1,
        'foreground': scheme['foreground'] ?? 7,
        'background': scheme['background'] ?? 0,
        for (final role in [
          'foregroundColor',
          'backgroundColor',
          'cursorColor',
        ])
          role: hex(scheme[role] as int),
        'colors': {
          for (final (index, color) in (scheme['palette'] as List<int>).indexed)
            '$index': hex(color),
        },
      });
    }
    if (id is! int || id < 0) throw ArgumentError('기본 테마는 복제한 뒤 편집하세요.');
    final stored = _records(
      'schemes',
    ).firstWhere((record) => record['id'] == id);
    for (final role in ['foregroundColor', 'backgroundColor', 'cursorColor']) {
      if (stored[role] == null) scheme.remove(role);
    }
    switch (method) {
      case 'scheme.rename':
        scheme['name'] = _schemeName(args['name'], except: id);
      case 'scheme.role':
        final role = args['role'];
        if (!const {'foreground', 'background', 'cursor'}.contains(role) ||
            args['color'] is! int) {
          throw ArgumentError('색상 역할을 확인하세요.');
        }
        scheme['${role}Color'] = (args['color'] as int) & 0xffffffff;
      case 'scheme.color':
        final index = args['index'];
        if (index is! int || index < 0 || index > 15 || args['color'] is! int) {
          throw ArgumentError('ANSI 색상 번호는 0–15여야 합니다.');
        }
        (scheme['palette'] as List<int>)[index] =
            (args['color'] as int) & 0xffffffff;
      case 'scheme.delete':
        _remove('schemes', id);
        _data['profiles'] = [
          for (final profile in _records('profiles'))
            {
              ...profile,
              if (profile['colorSchemeId'] == id) 'colorSchemeId': -1,
            },
        ];
        if (_preferences()['colorScheme'] == id) {
          _data['preferences'] = {..._preferences(), 'colorScheme': -1};
        }
        await _save();
        return null;
      default:
        throw UnsupportedError('지원하지 않는 테마 작업입니다.');
    }
    _upsert('schemes', scheme);
    await _save();
    return null;
  }

  String _canonicalAlgorithm(Object? algorithm) => switch (algorithm) {
    'rsa-sha2-256' || 'rsa-sha2-512' => 'ssh-rsa',
    _ => '$algorithm',
  };
  Future<EngineRecord> _trust(String method, Map<String, Object?> args) async {
    final known = _records('knownHosts')
        .where(
          (record) =>
              record['hostname'] == args['hostname'] &&
              record['port'] == args['port'],
        )
        .toList();
    final match = known.any(
      (record) =>
          _canonicalAlgorithm(record['algorithm']) ==
              _canonicalAlgorithm(args['algorithm']) &&
          record['fingerprint'] == args['fingerprint'],
    );
    final status = match
        ? 'match'
        : known.isEmpty
        ? 'new'
        : 'changed';
    if (method == 'ssh.saveHost') {
      if (args['accept'] != true || status == 'changed') {
        throw StateError('명시적으로 확인한 새 서버 키만 저장할 수 있습니다.');
      }
      if (!match) {
        _upsert('knownHosts', {
          ...args,
          'id': null,
          'hostId': args['id'],
          'algorithm': _canonicalAlgorithm(args['algorithm']),
        });
        await _save();
      }
    }
    return {'status': status, 'known': known};
  }

  Future<File> _stage() async {
    final cache = Directory('${file.parent.path}/cache');
    await cache.create(recursive: true);
    final folder = await cache.createTemp('transfer-');
    return File('${folder.path}/data').create();
  }

  Future<File> _stagedFile(String path) async {
    final staged = File(await File(path).resolveSymbolicLinks());
    final cacheDirectory = Directory('${file.parent.path}/cache');
    if (!await cacheDirectory.exists()) {
      throw StateError('전송 임시 파일만 처리할 수 있습니다.');
    }
    final cache = await cacheDirectory.resolveSymbolicLinks();
    final parent = await staged.parent.parent.resolveSymbolicLinks();
    if (parent != cache || fileName(staged.path) != 'data') {
      throw StateError('전송 임시 파일만 처리할 수 있습니다.');
    }
    return staged;
  }

  Future<Object?> _fileOperation(
    String method,
    Map<String, Object?> args,
  ) async {
    if (method == 'file.finishTransfer') {
      final staged = await _stagedFile(args['path'] as String);
      try {
        if (args['save'] == true && args['uri'] is String) {
          await receiveFile(
            File(args['uri'] as String),
            staged.openRead().map(Uint8List.fromList),
            control: TransferControl()..total = await staged.length(),
            overwrite: true,
          );
          await exportFile?.call(args['uri'] as String);
        }
      } finally {
        await staged.parent.delete(recursive: true);
      }
      return null;
    }
    final chosen = await native(
      method == 'file.pickUpload' ? 'openFile' : 'saveFile',
      {'name': args['name']},
    );
    if (chosen is! String) return null;
    final staged = await _stage();
    if (method == 'file.prepareDownload') {
      return {'path': staged.path, 'uri': chosen};
    }
    try {
      await File(chosen).openRead().pipe(staged.openWrite());
      return {
        'path': staged.path,
        'name': fileName(chosen),
        'size': await staged.length(),
      };
    } catch (_) {
      await staged.parent.delete(recursive: true);
      rethrow;
    }
  }

  Future<List<SSHIdentity>> identities({required int id}) async {
    await _load();
    final key = _find('keys', id);
    final pem = await File(key['path'] as String).readAsString();
    final passphrase = _passwords['key:$id'] as String?;
    return Isolate.run(() => SSHKeyPair.fromPem(pem, passphrase));
  }

  Future<Object?> call(String method, Map<String, Object?> args) async {
    await _load();
    if (method.startsWith('scheme.')) return _schemeOperation(method, args);
    switch (method) {
      case 'snapshot':
        return _snapshot();
      case 'ssh.prepare':
      case 'session.prepare':
        final prepared = _prepare(args);
        final seen = <int>{prepared['host']['id'] as int};
        final jumps = <EngineRecord>[];
        var next = prepared['host']['jumpHostId'];
        while (next != null) {
          if (next is! int || !seen.add(next) || seen.length > 32) {
            throw StateError('SSH 점프 호스트 연결을 확인하세요.');
          }
          final jump = _prepare({'id': next});
          jumps.insert(0, jump);
          next = jump['host']['jumpHostId'];
        }
        return {...prepared, 'jumps': jumps};
      case 'ssh.checkHost':
      case 'ssh.saveHost':
        return _trust(method, args);
      case 'ssh.knownHosts':
        return _records(
          'knownHosts',
        ).where((record) => record['hostId'] == args['id']).toList();
      case 'knownHost.delete':
        _remove('knownHosts', args['id']);
        await _save();
        return null;
      case 'ssh.decode':
        if (args['encoding'] != 'UTF-8') {
          throw UnsupportedError('이 터미널은 UTF-8을 사용합니다.');
        }
        final id = args['sessionId'] as String;
        final decoder = _decoders.putIfAbsent(id, () {
          final output = StringBuffer();
          return (
            utf8.decoder.startChunkedConversion(
              StringConversionSink.fromStringSink(output),
            ),
            output,
          );
        });
        decoder.$1.add((args['bytes'] as List).cast<int>());
        if (args['final'] == true) {
          decoder.$1.close();
          _decoders.remove(id);
        }
        final text = decoder.$2.toString();
        decoder.$2.clear();
        return text;
      case 'ssh.encode':
        return Uint8List.fromList(utf8.encode(args['text'] as String));
      case 'ssh.closeCodec':
        _decoders.remove(args['sessionId'])?.$1.close();
        return null;
      case 'host.save':
        final previous = _records(
          'hosts',
        ).where((host) => host['id'] == args['id']).firstOrNull;
        final configured = {..._defaultHost, ...?previous, ...args};
        if ((configured['hostname'] as String? ?? '').trim().isEmpty) {
          throw StateError('서버 주소를 입력하세요.');
        }
        if (configured['protocol'] != 'ssh') {
          throw UnsupportedError('SSH 호스트를 사용하세요.');
        }
        final saved = _upsert('hosts', configured);
        _updatePassword('host:${saved['id']}', args);
        await _save();
        return saved;
      case 'host.favorite':
        final host = _find('hosts', args['id']);
        _upsert('hosts', {...host, 'favorite': host['favorite'] != true});
        await _save();
        return null;
      case 'host.duplicate':
        final copy = _upsert('hosts', {
          ..._find('hosts', args['id']),
          'id': null,
          'nickname': args['nickname'],
        });
        await _save();
        return copy;
      case 'host.delete':
        final host = _find('hosts', args['id']);
        final token = '${_id()}';
        if (args['undo'] == true) {
          _deletedHosts[token] = {
            'host': host,
            'password': _passwords['host:${host['id']}'],
          };
        }
        _remove('hosts', args['id']);
        _passwords.remove('host:${host['id']}');
        await _save();
        return args['undo'] == true ? token : null;
      case 'host.restore':
        final saved = _deletedHosts.remove(args['token']);
        if (saved == null) throw StateError('복구할 호스트가 없습니다.');
        final host = row(saved['host']);
        _data['hosts'] = [..._records('hosts'), host];
        if (saved['password'] != null) {
          _passwords['host:${host['id']}'] = saved['password'];
        }
        await _save();
        return null;
      case 'host.deleteFinish':
        _deletedHosts.remove(args['token']);
        return null;
      case 'host.sort':
        _data['sortedByColor'] = _data['sortedByColor'] != true;
        await _save();
        return null;
      case 'identity.save':
        final saved = _upsert('identities', args);
        _updatePassword('identity:${saved['id']}', args);
        await _save();
        return saved['id'];
      case 'identity.delete':
        _remove('identities', args['id']);
        _passwords.remove('identity:${args['id']}');
        await _save();
        return null;
      case 'profile.save':
        final saved = _upsert('profiles', args);
        await _save();
        return saved;
      case 'profile.delete':
        if (args['id'] == _preferences()['defaultProfileId'] ||
            _records('hosts').any((host) => host['profileId'] == args['id'])) {
          throw StateError('사용 중인 프로필입니다.');
        }
        _remove('profiles', args['id']);
        await _save();
        return null;
      case 'profile.duplicate':
        final saved = _upsert('profiles', {
          ..._find('profiles', args['id']),
          'id': null,
          'name': args['name'],
        });
        await _save();
        return saved;
      case 'forwards':
        return _records(
          'forwards',
        ).where((record) => record['hostId'] == args['hostId']).toList();
      case 'forward.save':
        final saved = _upsert('forwards', args);
        await _save();
        return saved;
      case 'forward.delete':
        _remove('forwards', args['id']);
        await _save();
        return null;
      case 'settings.update':
        if (platform == 'windows' && args['key'] == 'fullscreen') {
          await native('setFullscreen', {'enabled': args['value'] == true});
        }
        if (args['key'] == 'colorScheme') {
          _scheme(args['value']);
          final profile = _find('profiles', _preferences()['defaultProfileId']);
          _upsert('profiles', {...profile, 'colorSchemeId': args['value']});
        }
        if (args['key'] == 'fontFamily') {
          final profile = _find('profiles', _preferences()['defaultProfileId']);
          _upsert('profiles', {...profile, 'fontFamily': args['value']});
        }
        _data['preferences'] = {
          ..._preferences(),
          args['key'] as String: args['value'],
        };
        await _save();
        return null;
      case 'settings.preview':
        return const <String, Object?>{};
      case 'font.bytes':
        return {
          'family': '${args['name']}'.toUpperCase() == 'D2CODING'
              ? 'D2Coding'
              : 'JetBrainsMono',
        };
      case 'file.pickUpload':
      case 'file.prepareDownload':
      case 'file.finishTransfer':
        return _fileOperation(method, args);
      case 'openUrl':
        final uri = Uri.tryParse(args['url'] as String? ?? '');
        if (uri == null ||
            !const {'https', 'http', 'mailto'}.contains(uri.scheme)) {
          throw ArgumentError('지원하지 않는 링크입니다.');
        }
        return native('openUrl', {'url': uri.toString()});
      case 'document.pick':
        return native('openFile', {});
      case 'document.create':
        return native('saveFile', {'name': args['name']});
      case 'document.read':
        return File(args['uri'] as String).readAsString();
      case 'document.write':
        await File(args['uri'] as String).writeAsString(args['text'] as String);
        await exportFile?.call(args['uri'] as String);
        return null;
      case 'key.storageList':
        return _records('keys');
      case 'key.storageImport':
        final path = args['path'] as String;
        final pem = await File(path).readAsString();
        final passphrase = args['password'] as String?;
        final key = (await Isolate.run(
          () => SSHKeyPair.fromPem(pem, passphrase),
        )).single;
        final public = key.toPublicKey().encode();
        final saved = _upsert('keys', {
          'nickname': args['nickname'] ?? fileName(path),
          'path': path,
          'type': 'IMPORTED',
          'publicBytes': public.toList(),
          'eligible': true,
          'providerLabel': '키 파일',
          'confirmation': true,
        });
        if (passphrase != null && passphrase.isNotEmpty) {
          _passwords['key:${saved['id']}'] = passphrase;
        }
        await _save();
        return saved;
      case 'key.storageSave':
        final saved = _upsert('keys', args);
        await _save();
        return saved;
      case 'key.storageDelete':
        _remove('keys', args['id']);
        _passwords.remove('key:${args['id']}');
        await _save();
        return null;
      case 'key.storageCopy':
        await Clipboard.setData(ClipboardData(text: args['text'] as String));
        return null;
      case 'key.storageWrite':
        final target = await native('saveFile', {'name': args['name']});
        if (target is String) {
          await File(target).writeAsString(args['text'] as String);
          await exportFile?.call(target);
        }
        return null;
      case 'runtime.networkAvailable':
        return true;
      case 'session.consumeSelection':
      case 'session.visibility':
      case 'runtime.sessions':
      case 'runtime.visibility':
      case 'runtime.sessionEnded':
      case 'runtime.bell':
        return null;
      default:
        throw UnsupportedError('지원하지 않는 작업입니다: $method');
    }
  }
}
