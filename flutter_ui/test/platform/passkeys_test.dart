// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/digests/sha256.dart';
import 'package:android_shell_ui/platform/passkeys.dart';
import 'package:flutter_test/flutter_test.dart';

const publicKey =
    'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEAR6QO8TsrpSAtAdvEjSUgLj+VamIhqw6LJjcH1JaMTCZHlVQshahtgd3XUfbk7uH/IO0PdO6HmgPp0D3x2+aZQ==';
void main() {
  test('registration extracts only the ES256 public key and credential ID', () {
    final registration = registrationFixture();
    final key = PasskeyConnection.fromRegistration(
      nickname: 'work',
      responseJson: registration,
      challenge: Uint8List.fromList([1, 2, 3]),
      origin: 'android:test',
    );
    expect(key.publicKey, base64Decode(publicKey));
    expect(key.credentialId, 'AQID');
  });

  test(
    'registration rejects changed binding, flags, algorithms and truncated CBOR',
    () {
      for (final registration in [
        registrationFixture(challenge: 'different'),
        registrationFixture(origin: 'android:other'),
        registrationFixture(rpId: 'other.example'),
        registrationFixture(flags: 0x41),
        registrationFixture(flags: 5),
        registrationFixture(algorithm: 0x27),
        registrationFixture(rawId: 'BAUG'),
        registrationFixture(truncate: true),
      ]) {
        expect(
          () => PasskeyConnection.fromRegistration(
            nickname: 'work',
            responseJson: registration,
            challenge: Uint8List.fromList([1, 2, 3]),
            origin: 'android:test',
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('connection export contains public metadata only and round trips', () {
    final connection = PasskeyConnection(
      nickname: 'work',
      credentialId: 'AQID',
      publicKey: base64Decode(publicKey),
    );
    final json = connection.toJson();
    expect(json.keys.toSet(), {
      'format',
      'version',
      'rpId',
      'nickname',
      'credentialId',
      'publicKey',
    });
    expect(json['rpId'], PasskeyConnection.rpId);
    final restored = PasskeyConnection.fromJson(json);
    expect(restored.publicKey, connection.publicKey);
    expect(restored.credentialId, connection.credentialId);
    expect(restored.nickname, 'work');
  });

  test('restore rejects other domains, algorithms, versions and empty IDs', () {
    final data = PasskeyConnection(
      nickname: 'work',
      credentialId: 'AQID',
      publicKey: base64Decode(publicKey),
    ).toJson();
    for (final invalid in [
      {...data, 'rpId': 'other.example'},
      {...data, 'version': 99},
      {...data, 'credentialId': ''},
      {...data, 'credentialId': 'AQID='},
      {...data, 'publicKey': 'AQID'},
    ]) {
      expect(() => PasskeyConnection.fromJson(invalid), throwsFormatException);
    }
  });
}

String registrationFixture({
  String challenge = 'AQID',
  String origin = 'android:test',
  String rpId = PasskeyConnection.rpId,
  int flags = 0x45,
  int algorithm = 0x26,
  String rawId = 'AQID',
  bool truncate = false,
}) {
  final point = base64Decode(publicKey).sublist(26);
  final auth = [
    ...SHA256Digest().process(Uint8List.fromList(utf8.encode(rpId))),
    flags,
    0,
    0,
    0,
    0,
    ...List<int>.filled(16, 0),
    0,
    3,
    1,
    2,
    3,
    0xa5,
    1,
    2,
    3,
    algorithm,
    0x20,
    1,
    0x21,
    0x58,
    0x20,
    ...point.sublist(1, 33),
    0x22,
    0x58,
    0x20,
    ...point.sublist(33),
  ];
  final attestation = [
    0xa3,
    0x63,
    ...utf8.encode('fmt'),
    0x64,
    ...utf8.encode('none'),
    0x67,
    ...utf8.encode('attStmt'),
    0xa0,
    0x68,
    ...utf8.encode('authData'),
    0x59,
    auth.length >> 8,
    auth.length & 255,
    ...auth,
  ];
  return jsonEncode({
    'id': rawId,
    'rawId': rawId,
    'type': 'public-key',
    'response': {
      'clientDataJSON': PasskeyConnection.encode(
        utf8.encode(
          jsonEncode({
            'type': 'webauthn.create',
            'challenge': challenge,
            'origin': origin,
          }),
        ),
      ),
      'attestationObject': PasskeyConnection.encode(
        truncate ? attestation.sublist(0, attestation.length - 1) : attestation,
      ),
    },
  });
}
