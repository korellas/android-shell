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

void main() {
  final message = Uint8List.fromList(utf8.encode('SSH signing boundary'));

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
