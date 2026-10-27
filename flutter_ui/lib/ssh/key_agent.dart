// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
// Agent wire codecs are pinned with the app-local dartssh2 copy.
// ignore_for_file: implementation_imports

import 'dart:typed_data';
import 'package:dartssh2/src/hostkey/hostkey_rsa.dart';
import 'package:dartssh2/src/hostkey/hostkey_ed25519.dart';
import 'package:dartssh2/src/hostkey/hostkey_ecdsa.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/ssh_message.dart';

class SshAgentKey {
  const SshAgentKey(
    this.identities,
    this.nickname, {
    this.confirmation = false,
  });
  final List<SSHIdentity> identities;
  final String nickname;
  final bool confirmation;
}

/// Reads the live loaded-key roster without exporting protected private keys.
class AppSshKeyAgent implements SSHAgentHandler {
  AppSshKeyAgent({
    required this.loadKeys,
    required this.confirm,
    required this.mode,
    this.addKey,
    this.removeKey,
    this.removeAllKeys,
  });
  final Future<List<SshAgentKey>> Function() loadKeys;
  final Future<bool> Function(String nickname) confirm;
  final String mode;
  final Future<bool> Function(SSHKeyPair key, bool confirmation)? addKey;
  final Future<bool> Function(Uint8List publicKey)? removeKey;
  final Future<bool> Function()? removeAllKeys;
  String? _lockPassphrase;
  Uint8List _status(bool success) =>
      Uint8List.fromList([success ? 6 : SSHAgentProtocol.failure]);
  Uint8List get _failure => Uint8List.fromList([SSHAgentProtocol.failure]);

  @override
  Future<Uint8List> handleRequest(Uint8List request) async {
    if (mode == 'no' || request.isEmpty) return _failure;
    try {
      final reader = SSHMessageReader(request);
      final type = reader.readUint8();
      // OpenSSH agent protocol operations also supported by AuthAgentCallback.
      if (type == 23) {
        final passphrase = reader.readUtf8();
        if (!reader.isDone ||
            _lockPassphrase == null ||
            passphrase != _lockPassphrase) {
          return _failure;
        }
        _lockPassphrase = null;
        return _status(true);
      }
      if (_lockPassphrase != null) {
        if (type == SSHAgentProtocol.requestIdentities && reader.isDone) {
          return (SSHMessageWriter()
                ..writeUint8(SSHAgentProtocol.identitiesAnswer)
                ..writeUint32(0))
              .takeBytes();
        }
        return _failure;
      }
      if (type == 22) {
        final passphrase = reader.readUtf8();
        if (!reader.isDone) return _failure;
        _lockPassphrase = passphrase;
        return _status(true);
      }
      if (type == 18) {
        final publicKey = reader.readString();
        if (!reader.isDone || removeKey == null) return _failure;
        return _status(await removeKey!(publicKey));
      }
      if (type == 19) {
        if (!reader.isDone || removeAllKeys == null) return _failure;
        return _status(await removeAllKeys!());
      }
      if (type == 17 || type == 25) {
        if (addKey == null) return _failure;
        final algorithm = reader.readUtf8();
        final SSHKeyPair key;
        switch (algorithm) {
          case 'ssh-rsa':
            key = OpenSSHRsaKeyPair.readFrom(reader);
          case 'ssh-ed25519':
            key = OpenSSHEd25519KeyPair.readFrom(reader);
          case 'ecdsa-sha2-nistp256':
          case 'ecdsa-sha2-nistp384':
          case 'ecdsa-sha2-nistp521':
            key = OpenSSHEcdsaKeyPair.readFrom(reader);
            if (key.name != algorithm) return _failure;
          default:
            return _failure;
        }
        var confirmation = false;
        if (type == 25) {
          while (!reader.isDone) {
            switch (reader.readUint8()) {
              case 1:
                reader.readUint32(); // Lifetime was not enforced by native.
              case 2:
                confirmation = true;
              default:
                return _failure;
            }
          }
        }
        if (!reader.isDone || !_validPair(key)) return _failure;
        return _status(await addKey!(key, confirmation));
      }
      if (type != SSHAgentProtocol.requestIdentities &&
          type != SSHAgentProtocol.signRequest) {
        return _failure;
      }
      final keys = await loadKeys();
      if (type == SSHAgentProtocol.requestIdentities) {
        if (!reader.isDone) return _failure;
        final unique = <String, (SSHIdentity, String)>{};
        for (final key in keys) {
          for (final identity in key.identities) {
            final blob = identity.toPublicKey().encode();
            unique.putIfAbsent(blob.join(','), () => (identity, key.nickname));
          }
        }
        final writer = SSHMessageWriter()
          ..writeUint8(SSHAgentProtocol.identitiesAnswer)
          ..writeUint32(unique.length);
        for (final entry in unique.values) {
          writer.writeString(entry.$1.toPublicKey().encode());
          writer.writeUtf8(entry.$2);
        }
        return writer.takeBytes();
      }
      final blob = reader.readString();
      final data = reader.readString();
      final flags = reader.readUint32();
      if (!reader.isDone || flags & ~6 != 0) return _failure;
      for (final key in keys) {
        final matching = key.identities
            .where((identity) => _equal(identity.toPublicKey().encode(), blob))
            .toList();
        if (matching.isEmpty) continue;
        if (mode == 'confirm' &&
            key.confirmation &&
            !await confirm(key.nickname)) {
          return _failure;
        }
        if (_lockPassphrase != null) return _failure;
        final stillLoaded = await loadKeys();
        if (!stillLoaded.any(
          (key) => key.identities.any(
            (identity) => identical(identity, matching.first),
          ),
        )) {
          return _failure;
        }
        if (_lockPassphrase != null) return _failure;
        if (matching.first is SSHKeyPair) {
          return SSHKeyPairAgent([
            matching.first as SSHKeyPair,
          ]).handleRequest(request);
        }
        final algorithm = flags & SSHAgentProtocol.rsaSha2_512 != 0
            ? 'rsa-sha2-512'
            : flags & SSHAgentProtocol.rsaSha2_256 != 0
            ? 'rsa-sha2-256'
            : 'ssh-rsa';
        final identity =
            matching
                .where((identity) => identity.type == algorithm)
                .firstOrNull ??
            matching.first;
        final publicReader = SSHMessageReader(blob);
        if (publicReader.readUtf8() == 'ssh-rsa' &&
            identity.type != algorithm) {
          return _failure;
        }
        final signature = await identity.sign(data);
        return (SSHMessageWriter()
              ..writeUint8(SSHAgentProtocol.signResponse)
              ..writeString(signature.encode()))
            .takeBytes();
      }
    } catch (_) {
      return _failure;
    }
    return _failure;
  }
}

bool _equal(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

// Validate imported agent material using the library's existing sign/verify APIs.
bool _validPair(SSHKeyPair key) {
  if (key is OpenSSHRsaKeyPair &&
      (key.e <= BigInt.one ||
          key.d <= BigInt.zero ||
          key.p <= BigInt.one ||
          key.q <= BigInt.one ||
          key.p * key.q != key.n)) {
    return false;
  }
  if (key is OpenSSHEd25519KeyPair &&
      (key.publicKey.length != 32 || key.privateKey.length != 64)) {
    return false;
  }
  final probe = Uint8List.fromList([83, 83, 72, 45, 97, 103, 101, 110, 116]);
  final signature = key.sign(probe);
  final public = key.toPublicKey();
  if (public is SSHRsaPublicKey && signature is SSHRsaSignature) {
    return public.verify(probe, signature);
  }
  if (public is SSHEd25519PublicKey && signature is SSHEd25519Signature) {
    return public.verify(probe, signature);
  }
  if (public is SSHEcdsaPublicKey && signature is SSHEcdsaSignature) {
    return public.verify(probe, signature);
  }
  return false;
}
