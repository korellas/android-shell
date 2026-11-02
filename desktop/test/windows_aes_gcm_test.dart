// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilde_desktop/windows_aes_gcm.dart';

Uint8List hex(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);
void main() {
  group('Windows CNG AES-GCM', () {
    for (final vector in [
      (16, '0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf'),
      (32, 'cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919'),
    ]) {
      test('matches NIST zero-key vector for ${vector.$1 * 8} bits', () {
        final cipher = WindowsAesGcm(Uint8List(vector.$1));
        addTearDown(cipher.dispose);
        final encrypted = cipher.process(
          nonce: Uint8List(12),
          aad: Uint8List(0),
          input: Uint8List(16),
          encrypt: true,
        );
        expect(encrypted, hex(vector.$2));
        expect(
          cipher.process(
            nonce: Uint8List(12),
            aad: Uint8List(0),
            input: encrypted,
            encrypt: false,
          ),
          Uint8List(16),
        );
      });
    }
    test(
      'authenticates packet length, nonce and tag before returning plaintext',
      () {
        final cipher = WindowsAesGcm(Uint8List(32));
        addTearDown(cipher.dispose);
        final nonce = Uint8List(12);
        final aad = Uint8List.fromList([0, 0, 128, 0]);
        final plain = Uint8List.fromList(List.generate(32768, (i) => i % 251));
        final encrypted = cipher.process(
          nonce: nonce,
          aad: aad,
          input: plain,
          encrypt: true,
        );
        expect(
          cipher.process(
            nonce: nonce,
            aad: aad,
            input: encrypted,
            encrypt: false,
          ),
          plain,
        );
        for (final corrupt in ['nonce', 'aad', 'tag', 'ciphertext']) {
          final n = Uint8List.fromList(nonce),
              a = Uint8List.fromList(aad),
              c = Uint8List.fromList(encrypted);
          if (corrupt == 'nonce') n[0] ^= 1;
          if (corrupt == 'aad') a[0] ^= 1;
          if (corrupt == 'tag') c[c.length - 1] ^= 1;
          if (corrupt == 'ciphertext') c[0] ^= 1;
          expect(
            () => cipher.process(nonce: n, aad: a, input: c, encrypt: false),
            throwsA(isA<SSHPacketError>()),
          );
        }
        // A failed authentication must not poison the next packet.
        expect(
          cipher.process(
            nonce: nonce,
            aad: aad,
            input: encrypted,
            encrypt: false,
          ),
          plain,
        );
      },
    );
    test('supports empty packets, buffer growth and repeated disposal', () {
      final cipher = WindowsAesGcm(Uint8List(16));
      for (final size in [0, 16, 65536, 3]) {
        final plain = Uint8List(size);
        final encrypted = cipher.process(
          nonce: Uint8List(12)..[11] = size % 255,
          aad: Uint8List(4),
          input: plain,
          encrypt: true,
        );
        expect(
          cipher.process(
            nonce: Uint8List(12)..[11] = size % 255,
            aad: Uint8List(4),
            input: encrypted,
            encrypt: false,
          ),
          plain,
        );
      }
      cipher.dispose();
      cipher.dispose();
      expect(
        () => cipher.process(
          nonce: Uint8List(12),
          aad: Uint8List(4),
          input: Uint8List(0),
          encrypt: true,
        ),
        throwsStateError,
      );
    });
  }, skip: !Platform.isWindows);
}
