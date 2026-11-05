/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 * Licensed under the Apache License, Version 2.0
 */
import 'dart:convert';
import 'dart:typed_data';

import 'package:android_shell_ui/platform/ssh_keys.dart';
import 'package:asn1lib/asn1lib.dart';
import 'package:dartssh2/src/hostkey/hostkey_ecdsa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/digests/sha256.dart';

void main() {
  final message = Uint8List.fromList(utf8.encode('SSH signing boundary'));

  test('passkey identity wraps WebAuthn assertions for OpenSSH', () async {
    final der = ASN1Sequence()
      ..add(ASN1Integer(BigInt.from(128)))
      ..add(ASN1Integer(BigInt.from(255)));
    final authData = Uint8List(37)
      ..setRange(
        0,
        32,
        SHA256Digest().process(
          Uint8List.fromList(utf8.encode('korellas.github.io')),
        ),
      )
      ..[32] = 5
      ..[36] = 7;
    final clientData = utf8.encode(
      jsonEncode({
        'type': 'webauthn.get',
        'challenge': base64Url.encode(message).replaceAll('=', ''),
        'origin': 'android:apk-key-hash:test',
        'crossOrigin': false,
      }),
    );
    final adapter = SshKeyAdapter((method, args) async {
      if (method == 'ssh.keyMaterial') {
        return {
          'passkey': true,
          'publicKey': base64Decode(ecPublic),
          'rpId': 'korellas.github.io',
          'origin': 'android:apk-key-hash:test',
        };
      }
      expect(args['data'], message);
      return {
        'signature': der.encodedBytes,
        'authenticatorData': authData,
        'clientDataJSON': clientData,
      };
    });
    final identity = (await adapter.identities(id: 7)).single;
    expect(identity.type, 'webauthn-sk-ecdsa-sha2-nistp256@openssh.com');
    expect(identity.shouldProbe, isTrue);
    expect(
      utf8.decode(_readStrings(identity.toPublicKey().encode()).first),
      'sk-ecdsa-sha2-nistp256@openssh.com',
    );
    final signed = (await identity.sign(message)).encode();
    final typeLength = ByteData.sublistView(signed).getUint32(0);
    expect(utf8.decode(signed.sublist(4, 4 + typeLength)), identity.type);
    final rsStart = 4 + typeLength;
    final rsLength = ByteData.sublistView(signed).getUint32(rsStart);
    final flagsOffset = rsStart + 4 + rsLength;
    expect(signed[flagsOffset], 5);
    expect(ByteData.sublistView(signed).getUint32(flagsOffset + 1), 7);
    final tail = _readStrings(signed.sublist(flagsOffset + 5));
    expect(utf8.decode(tail[0]), 'android:apk-key-hash:test');
    expect(tail[1], clientData);
    expect(tail[2], isEmpty);
  });

  test('passkey cancellation does not request a second signer', () async {
    var calls = 0;
    final adapter = SshKeyAdapter((method, args) async {
      calls++;
      return method == 'ssh.keyMaterial'
          ? {
              'passkey': true,
              'publicKey': base64Decode(ecPublic),
              'rpId': 'korellas.github.io',
              'origin': 'android:apk-key-hash:test',
            }
          : {'authcancel': true};
    });
    final identity = (await adapter.identities(id: 7)).single;
    await expectLater(
      identity.sign(message),
      throwsA(isA<SshKeyAuthenticationCancelled>()),
    );
    expect(calls, 2);
  });

  test('software key material is rejected before parsing', () async {
    final adapter = SshKeyAdapter(
      (method, args) async => {'biometric': false, 'pem': 'private'},
    );
    await expectLater(adapter.identities(id: 1), throwsA(isA<StateError>()));
  });

  test('non-P-256 Keystore keys are rejected', () async {
    final adapter = SshKeyAdapter(
      (method, args) async => {
        'biometric': true,
        'publicKey': base64Decode(rsaPublic),
      },
    );
    await expectLater(adapter.identities(id: 1), throwsA(isA<StateError>()));
  });

  test('P-256 signatures stay behind the biometric native boundary', () async {
    final der = ASN1Sequence()
      ..add(ASN1Integer(BigInt.from(128)))
      ..add(ASN1Integer(BigInt.from(255)));
    final calls = <String>[];
    final adapter = SshKeyAdapter((method, args) async {
      calls.add(method);
      return method == 'ssh.keyMaterial'
          ? {'biometric': true, 'publicKey': base64Decode(ecPublic)}
          : {'signature': der.encodedBytes};
    });
    final identity = (await adapter.identities(id: 7)).single;
    expect(identity.type, 'ecdsa-sha2-nistp256');
    final signature = SSHEcdsaSignature.decode(
      (await identity.sign(message)).encode(),
    );
    expect(signature.r, BigInt.from(128));
    expect(signature.s, BigInt.from(255));
    expect(calls, ['ssh.keyMaterial', 'ssh.sign']);
  });

  test('biometric cancellation never falls back to software signing', () async {
    final calls = <String>[];
    final adapter = SshKeyAdapter((method, args) async {
      calls.add(method);
      return method == 'ssh.keyMaterial'
          ? {'biometric': true, 'publicKey': base64Decode(ecPublic)}
          : {'authcancel': true};
    });
    final identity = (await adapter.identities(id: 7)).single;
    await expectLater(
      identity.sign(message),
      throwsA(isA<SshKeyAuthenticationCancelled>()),
    );
    expect(calls, ['ssh.keyMaterial', 'ssh.sign']);
  });
}

const rsaPublic =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuUOgMOllNFLd+JrvSOBINXQi6i5Hzj0C9Gc3g/ShZbKOX2C+5WKW91vWo6V4a7QvjezM0ySiNPtpkcyBKbZY+D0Y7c4GQGGAVaPmBrLeDH9RH6QynzlSaFo71LmJRYyaeZDF8rRb6T2IReWDAik3Jh2/p0qzGwU5ZReW7mUgb6bV6/fCF9AxMsLxH/XhWx4D1X86JrUYLwEiqPMHyi5byOLMyt+TAeKrr1pq4BAIbHmoEf/cyyyUvQWQ2b4MqcEjqqpi0aqfjbIQUsAlRzkFqPEsGPHHUbCskmNhdyb0257luo6cky/UpLcfxk3woR63QPPpaQMaxw1KzOQYoOJLzQIDAQAB';
const ecPublic =
    'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEAR6QO8TsrpSAtAdvEjSUgLj+VamIhqw6LJjcH1JaMTCZHlVQshahtgd3XUfbk7uH/IO0PdO6HmgPp0D3x2+aZQ==';

List<Uint8List> _readStrings(Uint8List bytes) {
  final result = <Uint8List>[];
  var offset = 0;
  while (offset < bytes.length) {
    final length = ByteData.sublistView(bytes).getUint32(offset);
    offset += 4;
    result.add(bytes.sublist(offset, offset + length));
    offset += length;
  }
  return result;
}
