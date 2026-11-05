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

import 'package:asn1lib/asn1lib.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/digests/sha256.dart';
import '../l10n/strings.dart';

typedef SshPlatformCall =
    Future<Object?> Function(String method, Map<String, Object?> arguments);

class SshKeyAuthenticationCancelled implements Exception {
  const SshKeyAuthenticationCancelled();
  @override
  String toString() => 'SSH key authentication cancelled';
}

class SshKeyAdapter {
  SshKeyAdapter(this.call);
  final SshPlatformCall call;

  Future<List<SSHIdentity>> identities({required int id}) async {
    final material = Map<String, Object?>.from(
      (await call('ssh.keyMaterial', {'id': id})) as Map,
    );
    if (material['passkey'] == true) {
      return [_passkeyIdentity(id, material)];
    }
    if (material['biometric'] != true && material['passkeyWrapped'] != true) {
      throw StateError(deviceStrings.onlyAndroidKeystoreSshKeysAreSupported);
    }
    final public = _PublicKey.decode(_bytes(material['publicKey']));
    if (public.type != 'ecdsa-sha2-nistp256') {
      throw StateError(deviceStrings.onlyP256AndroidKeystoreKeysAreSupported);
    }
    return [
      SSHIdentity.custom(
        type: public.type,
        publicKey: SSHRawHostKey(public.wire),
        shouldProbe: true,
        signer: (data) async {
          final reply = Map<String, Object?>.from(
            (await call('ssh.sign', {
                  'id': id,
                  'algorithm': public.type,
                  'data': data,
                }))
                as Map,
          );
          if (reply['authcancel'] == true) {
            throw const SshKeyAuthenticationCancelled();
          }
          final der = _sequence(_bytes(reply['signature']));
          if (der.elements.length != 2) {
            throw FormatException(deviceStrings.invalidEcdsaSignature);
          }
          final r = _integer(der.elements[0]);
          final s = _integer(der.elements[1]);
          if (r <= BigInt.zero || s <= BigInt.zero) {
            throw FormatException(deviceStrings.invalidEcdsaSignatureValues);
          }
          return SSHRawSignature(
            _strings([
              utf8.encode(public.type),
              _strings([_mpint(r), _mpint(s)]),
            ]),
          );
        },
      ),
    ];
  }

  SSHIdentity _passkeyIdentity(int id, Map<String, Object?> material) {
    final rpId = material['rpId'] as String;
    final origin = material['origin'] as String;
    return SSHIdentity.custom(
      type: 'webauthn-sk-ecdsa-sha2-nistp256@openssh.com',
      publicKey: SSHRawHostKey(
        storedPasskeyPublicKey(_bytes(material['publicKey']), rpId),
      ),
      shouldProbe: true,
      signer: (data) async {
        final reply = Map<String, Object?>.from(
          (await call('ssh.sign', {
                'id': id,
                'algorithm': 'webauthn-sk-ecdsa-sha2-nistp256@openssh.com',
                'data': data,
              }))
              as Map,
        );
        if (reply['authcancel'] == true) {
          throw const SshKeyAuthenticationCancelled();
        }
        final auth = _bytes(reply['authenticatorData']);
        final clientBytes = _bytes(reply['clientDataJSON']);
        final client = jsonDecode(utf8.decode(clientBytes)) as Map;
        final rpHash = SHA256Digest().process(
          Uint8List.fromList(utf8.encode(rpId)),
        );
        if (auth.length < 37 ||
            auth[32] & 5 != 5 ||
            auth[32] & 0x40 != 0 ||
            base64.encode(auth.sublist(0, 32)) != base64.encode(rpHash) ||
            (auth[32] & 0x80 == 0 ? auth.length != 37 : auth.length == 37) ||
            client['type'] != 'webauthn.get' ||
            client['origin'] != origin ||
            client['crossOrigin'] == true ||
            client['challenge'] != base64Url.encode(data).replaceAll('=', '')) {
          throw const FormatException('Invalid SSH passkey assertion');
        }
        final der = _sequence(_bytes(reply['signature']));
        if (der.elements.length != 2) {
          throw const FormatException('Invalid passkey signature');
        }
        final r = _integer(der.elements[0]);
        final s = _integer(der.elements[1]);
        if (r <= BigInt.zero || s <= BigInt.zero) {
          throw const FormatException('Invalid passkey signature');
        }
        return SSHRawSignature(
          Uint8List.fromList([
            ..._strings([
              utf8.encode('webauthn-sk-ecdsa-sha2-nistp256@openssh.com'),
              _strings([_mpint(r), _mpint(s)]),
            ]),
            ...auth.sublist(32, 37),
            ..._strings([utf8.encode(origin), clientBytes, auth.sublist(37)]),
          ]),
        );
      },
    );
  }
}

/// Encodes an ES256 passkey public key for OpenSSH security-key authentication.
Uint8List storedPasskeyPublicKey(Uint8List x509, String rpId) {
  final key = _PublicKey.decode(x509);
  if (key.type != 'ecdsa-sha2-nistp256') {
    throw const FormatException('SSH passkeys require P-256');
  }
  return _strings([
    utf8.encode('sk-ecdsa-sha2-nistp256@openssh.com'),
    utf8.encode('nistp256'),
    key.bytes,
    utf8.encode(rpId),
  ]);
}

class _PublicKey {
  _PublicKey(this.oid, this.type, this.bytes, this.wire, [this.curve]);
  final String oid;
  final String type;
  final Uint8List bytes;
  final Uint8List wire;
  final String? curve;
  factory _PublicKey.decode(Uint8List x509) {
    final root = _sequence(x509);
    if (root.elements.length != 2) {
      throw FormatException(deviceStrings.invalidX509PublicKey);
    }
    final algorithm = root.elements[0] as ASN1Sequence;
    final oid = (algorithm.elements[0] as ASN1ObjectIdentifier).identifier!;
    final bits = root.elements[1] as ASN1BitString;
    if (bits.unusedbits != 0) {
      throw FormatException(deviceStrings.invalidPublicKeyBitString);
    }
    final bytes = bits.contentBytes();
    switch (oid) {
      case '1.2.840.113549.1.1.1':
        final rsa = _sequence(bytes);
        final n = _integer(rsa.elements[0]);
        final e = _integer(rsa.elements[1]);
        if (n <= BigInt.zero || e <= BigInt.zero) {
          throw FormatException(deviceStrings.invalidRsaPublicKey);
        }
        return _PublicKey(
          oid,
          'ssh-rsa',
          bytes,
          _strings([utf8.encode('ssh-rsa'), _mpint(e), _mpint(n)]),
        );
      case '1.2.840.10045.2.1':
        final curve = _curve(algorithm.elements[1]);
        final expected = switch (curve) {
          'nistp256' => 65,
          'nistp384' => 97,
          'nistp521' => 133,
          _ => throw FormatException(deviceStrings.invalidEcCurve),
        };
        if (bytes.length != expected || bytes.first != 4) {
          throw FormatException(deviceStrings.invalidUncompressedEcPoint);
        }
        final type = 'ecdsa-sha2-$curve';
        return _PublicKey(
          oid,
          type,
          bytes,
          _strings([utf8.encode(type), utf8.encode(curve), bytes]),
          curve,
        );
      case '1.3.101.112':
        if (bytes.length != 32) {
          throw FormatException(deviceStrings.invalidEd25519PublicKey);
        }
        return _PublicKey(
          oid,
          'ssh-ed25519',
          bytes,
          _strings([utf8.encode('ssh-ed25519'), bytes]),
        );
      default:
        throw UnsupportedError(
          deviceStrings.unsupportedSshPublicKeyAlgorithm((oid).toString()),
        );
    }
  }
}

String _curve(ASN1Object object) =>
    switch ((object as ASN1ObjectIdentifier).identifier) {
      '1.2.840.10045.3.1.7' => 'nistp256',
      '1.3.132.0.34' => 'nistp384',
      '1.3.132.0.35' => 'nistp521',
      _ => throw UnsupportedError(deviceStrings.unsupportedSshEcCurve),
    };
ASN1Sequence _sequence(Uint8List data) {
  final parser = ASN1Parser(data);
  final object = parser.nextObject();
  if (object is! ASN1Sequence || parser.hasNext()) {
    throw FormatException(deviceStrings.invalidDerSequence);
  }
  return object;
}

BigInt _integer(ASN1Object object) => (object as ASN1Integer).valueAsBigInteger;
Uint8List _bytes(Object? value) =>
    Uint8List.fromList((value as List).cast<int>());
Uint8List _strings(List<List<int>> values) {
  final builder = BytesBuilder(copy: false);
  for (final value in values) {
    builder.add((ByteData(4)..setUint32(0, value.length)).buffer.asUint8List());
    builder.add(value);
  }
  return builder.takeBytes();
}

Uint8List _mpint(BigInt value) {
  if (value == BigInt.zero) return Uint8List(0);
  var hex = value.toRadixString(16);
  if (hex.length.isOdd) hex = '0$hex';
  final bytes = [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
  return Uint8List.fromList([if (bytes.first & 0x80 != 0) 0, ...bytes]);
}

/// Converts a stored X509 public key to its SSH wire representation.
Uint8List storedSshPublicKey(Uint8List x509) => _PublicKey.decode(x509).wire;
