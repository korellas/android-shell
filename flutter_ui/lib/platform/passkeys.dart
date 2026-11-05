// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/digests/sha256.dart';
import 'ssh_keys.dart';

/// Portable public metadata; the credential provider retains the private key.
class PasskeyConnection {
  PasskeyConnection({
    required this.nickname,
    required this.credentialId,
    required this.publicKey,
  }) {
    if (nickname.trim().isEmpty ||
        nickname.length > 256 ||
        credentialId.isEmpty ||
        credentialId.length > 1364) {
      throw const FormatException('Invalid passkey connection');
    }
    try {
      final id = base64Url.decode(base64Url.normalize(credentialId));
      if (id.length > 1023 || encode(id) != credentialId) {
        throw const FormatException('Invalid credential ID');
      }
      storedPasskeyPublicKey(publicKey, rpId);
    } catch (_) {
      throw const FormatException('Invalid passkey connection');
    }
  }
  static const rpId = 'korellas.github.io';
  final String nickname;
  final String credentialId;
  final Uint8List publicKey;
  static String encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  factory PasskeyConnection.fromJson(Map<String, Object?> value) {
    try {
      if (value['format'] != 'tilde-passkey' ||
          value['version'] != 1 ||
          value['rpId'] != rpId) {
        throw const FormatException('Invalid passkey connection');
      }
      return PasskeyConnection(
        nickname: value['nickname'] as String,
        credentialId: value['credentialId'] as String,
        publicKey: base64Url.decode(
          base64Url.normalize(value['publicKey'] as String),
        ),
      );
    } catch (_) {
      throw const FormatException('Invalid passkey connection');
    }
  }

  factory PasskeyConnection.fromRegistration({
    required String nickname,
    required String responseJson,
    required Uint8List challenge,
    required String origin,
  }) {
    try {
      if (responseJson.length > 65536) throw const FormatException();
      final credential = jsonDecode(responseJson) as Map;
      final response = credential['response'] as Map;
      final client =
          jsonDecode(utf8.decode(_decode(response['clientDataJSON'] as String)))
              as Map;
      if (credential['type'] != 'public-key' ||
          client['type'] != 'webauthn.create' ||
          client['challenge'] != encode(challenge) ||
          client['origin'] != origin ||
          client['crossOrigin'] == true) {
        throw const FormatException();
      }
      final reader = _RegistrationCbor(
        _decode(response['attestationObject'] as String),
      );
      final attestation = reader.read() as Map;
      if (!reader.done ||
          attestation['fmt'] != 'none' ||
          (attestation['attStmt'] as Map).isNotEmpty) {
        throw const FormatException();
      }
      final auth = attestation['authData'] as Uint8List;
      final hash = SHA256Digest().process(
        Uint8List.fromList(utf8.encode(rpId)),
      );
      if (auth.length < 55 ||
          auth[32] & 0x45 != 0x45 ||
          encode(auth.sublist(0, 32)) != encode(hash)) {
        throw const FormatException();
      }
      final length = ByteData.sublistView(auth).getUint16(53);
      if (length == 0 || length > 1023 || 55 + length >= auth.length) {
        throw const FormatException();
      }
      final credentialId = encode(auth.sublist(55, 55 + length));
      if (credential['rawId'] != credentialId ||
          credential['id'] != credentialId) {
        throw const FormatException();
      }
      final coseReader = _RegistrationCbor(auth.sublist(55 + length));
      final cose = coseReader.read() as Map;
      if (cose[1] != 2 ||
          cose[3] != -7 ||
          cose[-1] != 1 ||
          (cose[-2] as Uint8List).length != 32 ||
          (cose[-3] as Uint8List).length != 32) {
        throw const FormatException();
      }
      if (auth[32] & 0x80 != 0) {
        if (coseReader.read() is! Map) throw const FormatException();
      }
      if (!coseReader.done) throw const FormatException();
      return PasskeyConnection(
        nickname: nickname,
        credentialId: credentialId,
        publicKey: Uint8List.fromList([
          // SubjectPublicKeyInfo for id-ecPublicKey / prime256v1.
          0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86,
          0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
          0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
          4, ...cose[-2] as Uint8List, ...cose[-3] as Uint8List,
        ]),
      );
    } catch (_) {
      throw const FormatException('Invalid passkey registration');
    }
  }

  Map<String, Object?> toJson() => {
    'format': 'tilde-passkey',
    'version': 1,
    'rpId': rpId,
    'nickname': nickname,
    'credentialId': credentialId,
    'publicKey': encode(publicKey),
  };
  Map<String, Object?> toWire() => {
    'rpId': rpId,
    'nickname': nickname,
    'credentialId': credentialId,
    'publicKey': publicKey,
  };
}

Uint8List _decode(String text) => base64Url.decode(base64Url.normalize(text));

// Only the definite-length integers, strings and maps used by the requested
// WebAuthn "none" attestation and ES256 COSE key are accepted.
class _RegistrationCbor {
  _RegistrationCbor(this.bytes) {
    if (bytes.length > 65536) throw const FormatException('CBOR size');
  }
  final Uint8List bytes;
  int offset = 0;
  bool get done => offset == bytes.length;
  Uint8List take(int length) {
    if (length < 0 || offset + length > bytes.length) {
      throw const FormatException('Truncated CBOR');
    }
    final value = bytes.sublist(offset, offset + length);
    offset += length;
    return value;
  }

  Object read([int depth = 0]) {
    if (depth > 4) throw const FormatException('CBOR nesting');
    final header = take(1).single;
    final major = header >> 5;
    final info = header & 31;
    final int value;
    if (info < 24) {
      value = info;
    } else if (info == 24) {
      value = take(1).single;
    } else if (info == 25) {
      value = ByteData.sublistView(take(2)).getUint16(0);
    } else if (info == 26) {
      value = ByteData.sublistView(take(4)).getUint32(0);
    } else {
      throw const FormatException('Unsupported CBOR length');
    }
    switch (major) {
      case 0:
        return value;
      case 1:
        return -1 - value;
      case 2:
        return take(value);
      case 3:
        return utf8.decode(take(value));
      case 5:
        if (value > (bytes.length - offset) ~/ 2) {
          throw const FormatException('CBOR map size');
        }
        final map = <Object, Object>{};
        for (var i = 0; i < value; i++) {
          final key = read(depth + 1);
          if ((key is! int && key is! String) || map.containsKey(key)) {
            throw const FormatException('Invalid CBOR map key');
          }
          map[key] = read(depth + 1);
        }
        return map;
      default:
        throw const FormatException('Unsupported registration CBOR type');
    }
  }
}
