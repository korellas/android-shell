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
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'ssh_keys.dart';

/// Manages public metadata for device-bound Android Keystore SSH keys.
///
/// Private key bytes never cross the platform boundary. Historical software
/// keys remain visible so the user can inspect and delete them, but they are
/// not eligible for authentication or private-key operations.
class KeyManager {
  KeyManager(this.call);
  final SshPlatformCall call;

  Map<String, Object?> get state => const {};
  List<Map<String, Object?>> get pendingStartup => const [];

  Future<List<SSHIdentity>> identities({required int id}) =>
      SshKeyAdapter(call).identities(id: id);

  List<Map<String, Object?>> decorateKeys(List<Map<String, Object?>> keys) => [
    for (final key in keys) _decorate(key),
  ];

  Map<String, Object?> _decorate(Map<String, Object?> key) {
    Uint8List? wire;
    try {
      final bytes = Uint8List.fromList(
        (key['publicBytes'] as List).cast<int>(),
      );
      if (bytes.isNotEmpty) {
        wire = key['type'] == 'IMPORTED' ? bytes : storedSshPublicKey(bytes);
      }
    } catch (_) {
      // Historical rows can have missing or malformed public metadata. They
      // remain quarantined and deletable without parsing private material.
    }
    String? algorithm;
    if (wire != null) {
      try {
        algorithm = SSHHostKey.getType(wire);
      } catch (_) {
        wire = null;
      }
    }
    final eligible = key['eligible'] == true;
    final displayType = switch (algorithm) {
      'ecdsa-sha2-nistp256' => 'EC',
      'ssh-rsa' => 'RSA',
      'ssh-ed25519' => 'Ed25519',
      _ => key['type'],
    };
    return {
      ...key,
      'loaded': false,
      'supported': eligible,
      'displayType': displayType,
      if (!eligible)
        'supportMessage': key['biometric'] == true
            ? 'Android Keystore 키를 사용할 수 없음'
            : '기존 개인키 · 사용 중지',
      'publicKey': wire == null
          ? null
          : '${SSHHostKey.getType(wire)} ${base64.encode(wire)} ${key['nickname']}',
      'fingerprint': wire == null
          ? null
          : 'SHA256:${base64.encode(SHA256Digest().process(wire)).replaceAll('=', '')}',
    };
  }

  Future<Object?> operation(String method, Map<String, Object?> args) async {
    final id = (args['id'] as num?)?.toInt();
    switch (method) {
      case 'key.delete':
        return call('key.storageDelete', {'id': id});
      case 'key.generate':
        return call('key.storageGenerate', {
          'nickname': args['nickname'],
          'type': 'EC',
          'bits': 256,
        });
      case 'key.save':
        return call('key.storageSave', {
          'id': id,
          'nickname': args['nickname'],
          'confirmation': args['confirmation'] == true,
        });
      case 'key.copy':
      case 'key.export':
        if ((args['format'] as String? ?? 'public') != 'public') {
          throw UnsupportedError('Private key export is not supported');
        }
        final keys = (await call('key.storageList', {}) as List).map(
          (value) => Map<String, Object?>.from(value as Map),
        );
        final key = _decorate(keys.firstWhere((value) => value['id'] == id));
        final text = key['publicKey'];
        if (text is! String) throw StateError('Public key is unavailable');
        return call(
          method == 'key.copy' ? 'key.storageCopy' : 'key.storageWrite',
          {'text': text, 'name': '${key['nickname']}.pub'},
        );
      default:
        throw UnsupportedError(method);
    }
  }
}
