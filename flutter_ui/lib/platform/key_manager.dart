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
import 'passkeys.dart';
import '../l10n/strings.dart';

/// Manages public SSH key metadata and platform authentication.
///
/// Android private key bytes never cross the platform boundary. Historical
/// Android software keys remain visible for inspection and deletion but are
/// not eligible for authentication or private-key operations.
class KeyManager {
  KeyManager(this.call, {this.identityLoader, this.passkeysAvailable});
  final bool Function()? passkeysAvailable;
  final SshPlatformCall call;
  final Future<List<SSHIdentity>> Function({required int id})? identityLoader;

  Map<String, Object?> get state => const {};
  List<Map<String, Object?>> get pendingStartup => const [];

  Future<List<SSHIdentity>> identities({required int id}) =>
      identityLoader?.call(id: id) ?? SshKeyAdapter(call).identities(id: id);

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
        wire = key['passkey'] == true
            ? storedPasskeyPublicKey(bytes, key['rpId'] as String)
            : key['type'] == 'IMPORTED'
            ? bytes
            : storedSshPublicKey(bytes);
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
    final displayType = key['passkeyPassword'] == true
        ? deviceStrings.password
        : switch (algorithm) {
            'sk-ecdsa-sha2-nistp256@openssh.com' => 'Passkey',
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
            ? deviceStrings.androidKeystoreKeyUnavailable
            : deviceStrings.legacyPrivateKeyDisabled,
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
      case 'key.restorePasskey':
        final text = await call('key.storageReadPasskey', {});
        if (text == null) return null;
        if ((jsonDecode(text as String) as Map)['format'] ==
            'tilde-passkey-credential') {
          return call('key.storageRestoreProtectedPasskey', {'text': text});
        }
        final connection = PasskeyConnection.fromJson(
          Map<String, Object?>.from(jsonDecode(text) as Map),
        );
        return call('key.storageSavePasskey', connection.toWire());
      case 'key.exportPasskey':
        final keys = (await call('key.storageList', {}) as List).map(
          (value) => Map<String, Object?>.from(value as Map),
        );
        final key = keys.firstWhere((value) => value['id'] == id);
        if (key['passkeyWrapped'] == true || key['passkeyPassword'] == true) {
          return call('key.storageExportProtectedPasskey', {'id': id});
        }
        if (key['passkey'] != true) {
          throw const FormatException('Not a passkey');
        }
        final connection = PasskeyConnection(
          nickname: key['nickname'] as String,
          credentialId: key['credentialId'] as String,
          publicKey: Uint8List.fromList(
            (key['publicBytes'] as List).cast<int>(),
          ),
        );
        return call('key.storageWritePasskey', {
          'text': jsonEncode(connection.toJson()),
        });
      case 'key.import':
        return call('key.storageImport', args);
      case 'key.delete':
        return call('key.storageDelete', {'id': id});
      case 'key.generate':
        if (passkeysAvailable?.call() == true) {
          return call('key.storageGenerateProtectedPasskey', {
            'nickname': args['nickname'],
            'kind': args['kind'] ?? 'key',
            if (args['kind'] == 'password') ...{
              'password': args['password'],
              'hostname': args['hostname'],
              'port': args['port'] ?? 22,
              'username': args['username'],
            },
          });
        }
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
          throw UnsupportedError(deviceStrings.privateKeyExportIsNotSupported);
        }
        final keys = (await call('key.storageList', {}) as List).map(
          (value) => Map<String, Object?>.from(value as Map),
        );
        final key = _decorate(keys.firstWhere((value) => value['id'] == id));
        final text = key['publicKey'];
        if (text is! String) {
          throw StateError(deviceStrings.publicKeyIsUnavailable);
        }
        return call(
          method == 'key.copy' ? 'key.storageCopy' : 'key.storageWrite',
          {'text': text, 'name': '${key['nickname']}.pub'},
        );
      default:
        throw UnsupportedError(method);
    }
  }
}
