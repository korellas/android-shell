// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:typed_data';
import 'ssh_errors.dart';

/// Creates an owned AES-GCM context for one SSH direction and key epoch.
typedef SSHAesGcmFactory = SSHAesGcm Function(Uint8List key);

abstract class SSHAesGcm {
  /// Encrypts to ciphertext followed by a 16-byte tag, or authenticates and
  /// decrypts that representation. Decryption must fail with [SSHPacketError]
  /// before returning any plaintext if authentication fails.
  Uint8List process({
    required Uint8List nonce,
    required Uint8List aad,
    required Uint8List input,
    required bool encrypt,
  });

  /// Releases key material and native resources. Must be idempotent.
  void dispose();
}
