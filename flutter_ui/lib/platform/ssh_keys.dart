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

  Future<List<SSHIdentity>> identities({
    required int id,
    String? password,
  }) async {
    final material = Map<String, Object?>.from(
      (await call('ssh.keyMaterial', {'id': id, 'password': password})) as Map,
    );
    if (material['biometric'] == true) {
      final public = _PublicKey.decode(_bytes(material['publicKey']));
      final algorithms = public.type == 'ssh-rsa'
          ? ['rsa-sha2-512', 'rsa-sha2-256']
          : [public.type];
      return [
        for (final algorithm in algorithms)
          SSHIdentity.custom(
            type: algorithm,
            publicKey: SSHRawHostKey(public.wire),
            shouldProbe: true,
            signer: (data) async {
              final reply = Map<String, Object?>.from(
                (await call('ssh.sign', {
                      'id': id,
                      'algorithm': algorithm,
                      'data': data,
                    }))
                    as Map,
              );
              if (reply['authcancel'] == true) {
                throw const SshKeyAuthenticationCancelled();
              }
              final signature = _bytes(reply['signature']);
              if (public.type == 'ssh-rsa') {
                return SSHRawSignature(
                  _strings([utf8.encode(algorithm), signature]),
                );
              }
              final der = _sequence(signature);
              if (der.elements.length != 2) {
                throw const FormatException('Invalid ECDSA signature');
              }
              final r = _integer(der.elements[0]);
              final s = _integer(der.elements[1]);
              if (r <= BigInt.zero || s <= BigInt.zero) {
                throw const FormatException('Invalid ECDSA signature values');
              }
              return SSHRawSignature(
                _strings([
                  utf8.encode(algorithm),
                  _strings([_mpint(r), _mpint(s)]),
                ]),
              );
            },
          ),
      ];
    }
    final pem = material['pem'];
    if (pem is String) {
      return SSHKeyPair.fromPem(
        pem,
        SSHKeyPair.isEncryptedPem(pem) ? password : null,
      );
    }
    return [
      decodeStoredSshKey(
        _bytes(material['privateKey']),
        _bytes(material['publicKey']),
      ),
    ];
  }
}

SSHKeyPair decodeStoredSshKey(Uint8List pkcs8, Uint8List x509) {
  final container = _sequence(pkcs8);
  if (container.elements.length < 3 ||
      _integer(container.elements[0]) != BigInt.zero) {
    throw const FormatException('Invalid PKCS8 private key');
  }
  final algorithm = container.elements[1] as ASN1Sequence;
  final privateBytes = (container.elements[2] as ASN1OctetString).octets;
  final public = _PublicKey.decode(x509);
  final oid = (algorithm.elements[0] as ASN1ObjectIdentifier).identifier;
  if (oid != public.oid) {
    throw const FormatException('Private and public key algorithms differ');
  }
  switch (oid) {
    case '1.2.840.113549.1.1.1':
      final key = RsaPrivateKey.decode(privateBytes);
      if (!_equal(key.toPublicKey().encode(), public.wire)) {
        throw const FormatException('RSA public key does not match');
      }
      return key;
    case '1.2.840.10045.2.1':
      if (_curve(algorithm.elements[1]) != public.curve) {
        throw const FormatException('EC curves differ');
      }
      // Reuse the library's SEC1 decoder, including public-point validation.
      final sec1 = _sequence(privateBytes);
      if (!sec1.elements.any((element) => element.tag == 0xa0)) {
        sec1.add(
          ASN1Object.fromBytes(
            Uint8List.fromList([
              0xa0,
              algorithm.elements[1].encodedBytes.length,
              ...algorithm.elements[1].encodedBytes,
            ]),
          ),
        );
      }
      final key = EcKeyPair(null, sec1.encodedBytes).getPrivateKeys();
      if (!_equal(key.toPublicKey().encode(), public.wire)) {
        throw const FormatException('EC public key does not match');
      }
      return key;
    case '1.3.101.112':
      final seed =
          (ASN1Parser(privateBytes).nextObject() as ASN1OctetString).octets;
      if (seed.length != 32 || public.bytes.length != 32) {
        throw const FormatException('Invalid Ed25519 key length');
      }
      return OpenSSHEd25519KeyPair(
        public.bytes,
        Uint8List.fromList([...seed, ...public.bytes]),
        '',
      );
    default:
      throw UnsupportedError('Unsupported stored SSH key algorithm: $oid');
  }
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
      throw const FormatException('Invalid X509 public key');
    }
    final algorithm = root.elements[0] as ASN1Sequence;
    final oid = (algorithm.elements[0] as ASN1ObjectIdentifier).identifier!;
    final bits = root.elements[1] as ASN1BitString;
    if (bits.unusedbits != 0) {
      throw const FormatException('Invalid public key bit string');
    }
    final bytes = bits.contentBytes();
    switch (oid) {
      case '1.2.840.113549.1.1.1':
        final rsa = _sequence(bytes);
        final n = _integer(rsa.elements[0]);
        final e = _integer(rsa.elements[1]);
        if (n <= BigInt.zero || e <= BigInt.zero) {
          throw const FormatException('Invalid RSA public key');
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
          _ => throw const FormatException('Invalid EC curve'),
        };
        if (bytes.length != expected || bytes.first != 4) {
          throw const FormatException('Invalid uncompressed EC point');
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
          throw const FormatException('Invalid Ed25519 public key');
        }
        return _PublicKey(
          oid,
          'ssh-ed25519',
          bytes,
          _strings([utf8.encode('ssh-ed25519'), bytes]),
        );
      default:
        throw UnsupportedError('Unsupported SSH public key algorithm: $oid');
    }
  }
}

String _curve(ASN1Object object) =>
    switch ((object as ASN1ObjectIdentifier).identifier) {
      '1.2.840.10045.3.1.7' => 'nistp256',
      '1.3.132.0.34' => 'nistp384',
      '1.3.132.0.35' => 'nistp521',
      _ => throw UnsupportedError('Unsupported SSH EC curve'),
    };
ASN1Sequence _sequence(Uint8List data) {
  final parser = ASN1Parser(data);
  final object = parser.nextObject();
  if (object is! ASN1Sequence || parser.hasNext()) {
    throw const FormatException('Invalid DER sequence');
  }
  return object;
}

BigInt _integer(ASN1Object object) => (object as ASN1Integer).valueAsBigInteger;
Uint8List _bytes(Object? value) =>
    Uint8List.fromList((value as List).cast<int>());
bool _equal(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
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
