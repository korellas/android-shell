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
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as ed25519;
import 'package:pointycastle/digests/sha256.dart';
import 'ssh_keys.dart';

class KeyManager {
  KeyManager(this.call, {this.rememberUnlocked});
  final SshPlatformCall call;
  final bool Function()? rememberUnlocked;
  int _cacheGeneration = 0;
  final Map<int, List<SSHIdentity>> _loaded = {};
  final List<Map<String, Object?>> _startup = [];
  final _ephemeral = <int, Map<String, Object?>>{};
  int _nextAgentId = 0;
  Map<int, List<SSHIdentity>> get loadedIdentities => Map.unmodifiable(_loaded);
  Map<String, Object?>? ephemeralMetadata(int id) => _ephemeral[id];
  void forgetStoredKeys() {
    _cacheGeneration++;
    _loaded.removeWhere((id, _) => id >= 0);
  }

  Future<bool> addAgentKey(SSHKeyPair key, bool confirmation) async {
    final wire = base64.encode(key.toPublicKey().encode());
    for (final entry in _loaded.entries) {
      if (base64.encode(entry.value.first.toPublicKey().encode()) == wire) {
        return true;
      }
    }
    final id = --_nextAgentId;
    _loaded[id] = [key];
    _ephemeral[id] = {
      'id': id,
      'nickname': key.comment ?? '',
      'confirmation': confirmation,
    };
    return true;
  }

  Future<bool> removeAgentKey(Uint8List publicKey) async {
    _cacheGeneration++;
    final wire = base64.encode(publicKey);
    final ids = _loaded.entries
        .where(
          (entry) =>
              base64.encode(entry.value.first.toPublicKey().encode()) == wire,
        )
        .map((entry) => entry.key)
        .toList();
    for (final id in ids) {
      _loaded.remove(id);
      _ephemeral.remove(id);
    }
    return ids.isNotEmpty;
  }

  Future<bool> removeAllAgentKeys() async {
    _cacheGeneration++;
    _loaded.clear();
    _ephemeral.clear();
    return true;
  }

  bool _startupInitialized = false;
  String? _importText;
  String? _importName;
  bool _importEncrypted = false;
  String? _error;
  Map<String, Object?> get state => {
    'error': _error,
    'pendingNickname': _importText != null && !_importEncrypted
        ? _importName
        : null,
    'importPassword': _importText != null && _importEncrypted
        ? {'nickname': _importName, 'type': 'IMPORTED'}
        : null,
    'biometricUnlock': null,
    'nicknameError': null,
  };
  List<Map<String, Object?>> get pendingStartup => List.unmodifiable(_startup);
  Future<List<SSHIdentity>> identities({
    required int id,
    String? password,
  }) async {
    if (_loaded.containsKey(id)) return _loaded[id]!;
    final generation = _cacheGeneration;
    final result = await SshKeyAdapter(
      call,
    ).identities(id: id, password: password);
    if (generation == _cacheGeneration &&
        rememberUnlocked?.call() == true &&
        result.every((identity) => identity is SSHKeyPair)) {
      _loaded[id] = result;
    }
    return result;
  }

  Future<void> initializeStartup(List<Map<String, Object?>> keys) async {
    if (_startupInitialized) return;
    _startupInitialized = true;
    for (final key in keys.where(
      (k) =>
          k['startup'] == true && k['biometric'] != true && k['type'] != 'DSA',
    )) {
      if (key['encrypted'] == true) {
        _startup.add(key);
        continue;
      }
      try {
        _loaded[(key['id'] as num).toInt()] = await identities(
          id: (key['id'] as num).toInt(),
        );
      } catch (e) {
        _error = '$e';
      }
    }
  }

  List<Map<String, Object?>> decorateKeys(List<Map<String, Object?>> keys) {
    return [for (final key in keys) _decorate(key)];
  }

  Map<String, Object?> _decorate(Map<String, Object?> key) {
    final id = (key['id'] as num).toInt();
    Uint8List? wire;
    try {
      final bytes = Uint8List.fromList(
        (key['publicBytes'] as List).cast<int>(),
      );
      if (bytes.isNotEmpty) {
        wire = key['type'] == 'IMPORTED' ? bytes : storedSshPublicKey(bytes);
      }
    } catch (_) {
      /* Older imported PEM records have no public metadata. */
    }
    wire ??= _loaded[id]?.first.toPublicKey().encode();
    String? algorithm;
    if (wire != null) {
      try {
        algorithm = SSHHostKey.getType(wire);
      } catch (_) {
        wire = null;
      }
    }
    final supported = key['type'] != 'DSA' && algorithm != 'ssh-dss';
    final displayType = switch (algorithm) {
      'ssh-rsa' => 'RSA',
      'ssh-ed25519' => 'Ed25519',
      'ssh-dss' => 'DSA',
      'ecdsa-sha2-nistp256' ||
      'ecdsa-sha2-nistp384' ||
      'ecdsa-sha2-nistp521' => 'EC',
      _ => key['type'],
    };
    return {
      ...key,
      'loaded': _loaded.containsKey(id),
      'supported': supported,
      'displayType': displayType,
      if (!supported) 'supportMessage': 'DSA 로그인 미지원',
      'publicKey': wire == null
          ? null
          : '${SSHHostKey.getType(wire)} ${base64.encode(wire)} ${key['nickname']}',
      'fingerprint': wire == null
          ? null
          : 'SHA256:${base64.encode(SHA256Digest().process(wire)).replaceAll('=', '')}',
    };
  }

  Future<Object?> operation(String method, Map<String, Object?> args) async {
    _error = null;
    final id = (args['id'] as num?)?.toInt();
    switch (method) {
      case 'key.load':
      case 'key.biometricUnlock':
        _cacheGeneration++;
        if (_loaded.remove(id) == null) {
          _loaded[id!] = await identities(
            id: id,
            password: args['password'] as String?,
          );
        }
        return null;
      case 'key.startup':
        if (args['cancel'] != true) {
          _loaded[id!] = await identities(
            id: id,
            password: args['password'] as String?,
          );
        }
        _startup.removeWhere((k) => k['id'] == id);
        return null;
      case 'key.delete':
        _cacheGeneration++;
        await call('key.storageDelete', args);
        _loaded.remove(id);
        _startup.removeWhere((k) => k['id'] == id);
        return null;
      case 'key.generate':
        if (args['biometric'] == true) return call('key.storageGenerate', args);
        SSHKeyPair pair;
        if ((args['type'] ?? 'ED25519') == 'ED25519') {
          pair = await Isolate.run(() {
            final random = Random.secure();
            final seed = Uint8List.fromList(
              List.generate(32, (_) => random.nextInt(256)),
            );
            final key = ed25519.SigningKey.fromSeed(seed);
            return OpenSSHEd25519KeyPair(
              Uint8List.fromList(key.publicKey),
              Uint8List.fromList(key),
              '',
            );
          });
        } else {
          final material = Map<String, Object?>.from(
            await call('key.storageGenerate', args) as Map,
          );
          pair = decodeStoredSshKey(
            _bytes(material['privateKey']),
            _bytes(material['publicKey']),
          );
        }
        final pem = await _encode(pair, args['password'] as String?);
        return call('key.storageSave', {
          ...args,
          'pem': pem,
          'encrypted': (args['password'] as String? ?? '').isNotEmpty,
          'publicKey': pair.toPublicKey().encode(),
        });
      case 'key.save':
        final data = {...args};
        if (args.containsKey('newPassword')) {
          final pair =
              (await identities(
                    id: id!,
                    password: args['oldPassword'] as String?,
                  )).first
                  as SSHKeyPair;
          data.addAll({
            'pem': await _encode(pair, args['newPassword'] as String?),
            'encrypted': (args['newPassword'] as String? ?? '').isNotEmpty,
            'publicKey': pair.toPublicKey().encode(),
          });
        }
        final result = await call('key.storageSave', data);
        if (data['pem'] != null) {
          _cacheGeneration++;
          _loaded.remove(id);
        }
        return result;
      case 'key.import':
        var text = args['text'] as String?;
        var name = args['nickname'] as String?;
        final namedText = text != null && name?.trim().isNotEmpty == true;
        if (text == null) {
          final picked = await call('key.storagePick', args);
          if (picked == null) return null;
          final data = Map<String, Object?>.from(picked as Map);
          text = data['text'] as String;
          name = data['nickname'] as String;
        }
        _importEncrypted = await Isolate.run(
          () => SSHKeyPair.isEncryptedPem(text!),
        );
        if (!_importEncrypted) {
          await Isolate.run(() => SSHKeyPair.fromPem(text!));
        }
        _importText = text;
        _importName = name ?? 'Imported key';
        if (!_importEncrypted && namedText) {
          return operation('key.importName', {'nickname': _importName});
        }
        return null;
      case 'key.importPassword':
      case 'key.importName':
        final text = _importText;
        if (text == null) return null;
        final password = args['password'] as String?;
        final pair = (await Isolate.run(
          () => SSHKeyPair.fromPem(text, _importEncrypted ? password : null),
        )).single;
        final encryptPassword = args['encrypt'] == true
            ? (args['encryptPassword'] as String? ?? password)
            : null;
        final result = await call('key.storageSave', {
          'nickname': args['nickname'] ?? _importName,
          'pem': await _encode(pair, encryptPassword),
          'encrypted': encryptPassword?.isNotEmpty == true,
          'publicKey': pair.toPublicKey().encode(),
        });
        _clearImport();
        return result;
      case 'key.importCancel':
        _clearImport();
        return null;
      case 'key.copy':
      case 'key.export':
        final keys = (await call('key.storageList', {}) as List).map(
          (k) => Map<String, Object?>.from(k as Map),
        );
        final key = keys.firstWhere((k) => k['id'] == id);
        final format = args['format'] as String? ?? 'public';
        String text;
        if (format == 'public') {
          var decorated = _decorate(key);
          if (decorated['publicKey'] == null) {
            final identity = (await identities(
              id: id!,
              password: args['password'] as String?,
            )).first;
            final wire = identity.toPublicKey().encode();
            decorated = _decorate({
              ...key,
              'type': 'IMPORTED',
              'publicBytes': wire,
            });
          }
          text = decorated['publicKey'] as String;
        } else {
          if (key['biometric'] == true) {
            throw StateError('Protected private keys cannot be exported');
          }
          final pair =
              (await identities(
                    id: id!,
                    password: args['password'] as String?,
                  )).first
                  as SSHKeyPair;
          if (format == 'encrypted' &&
              (args['exportPassword'] as String? ?? '').isEmpty) {
            throw ArgumentError('Export password required');
          }
          if (!['pem', 'openssh', 'encrypted'].contains(format)) {
            throw ArgumentError('Unsupported export format');
          }
          text = format == 'pem'
              ? pair.toPem()
              : await _encode(
                  pair,
                  format == 'encrypted'
                      ? args['exportPassword'] as String
                      : null,
                );
        }
        return call(
          method == 'key.copy' ? 'key.storageCopy' : 'key.storageWrite',
          {
            'text': text,
            'name': '${key['nickname']}${format == 'public' ? '.pub' : '.pem'}',
          },
        );
      default:
        throw UnsupportedError(method);
    }
  }

  void _clearImport() {
    _importText = null;
    _importName = null;
    _importEncrypted = false;
  }
}

Uint8List _bytes(Object? value) =>
    Uint8List.fromList((value as List).cast<int>());
Future<String> _encode(SSHKeyPair pair, String? password) => Isolate.run(() {
  final OpenSSHKeyPair open;
  if (pair is OpenSSHKeyPair) {
    open = pair;
  } else if (pair is RsaPrivateKey) {
    open = OpenSSHRsaKeyPair(
      pair.n,
      pair.e,
      pair.d,
      pair.q.modInverse(pair.p),
      pair.p,
      pair.q,
      '',
    );
  } else {
    throw UnsupportedError('Unsupported OpenSSH export algorithm');
  }
  return open.toPem(passphrase: password?.isNotEmpty == true ? password : null);
});
