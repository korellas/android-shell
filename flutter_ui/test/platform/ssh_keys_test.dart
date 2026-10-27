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
import 'package:dartssh2/src/hostkey/hostkey_ecdsa.dart';
import 'package:dartssh2/src/hostkey/hostkey_ed25519.dart';
import 'package:dartssh2/src/hostkey/hostkey_rsa.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:android_shell_ui/platform/ssh_keys.dart';

void main() {
  final message = Uint8List.fromList(utf8.encode('SSH signing boundary'));

  test('legacy encrypted EC PEM imports and signs with its password', () async {
    expect(SSHKeyPair.isEncryptedPem(legacyEncryptedEc), isTrue);
    final original = SSHKeyPair.fromPem(legacyPlainEc).single;
    final adapter = SshKeyAdapter(
      (method, args) async => {'biometric': false, 'pem': legacyEncryptedEc},
    );
    final key = (await adapter.identities(
      id: 1,
      password: 'legacy-password',
    )).single;
    expect(key.toPublicKey().encode(), original.toPublicKey().encode());
    expect(
      SSHEcdsaPublicKey.decode(
        key.toPublicKey().encode(),
      ).verify(message, await key.sign(message) as SSHEcdsaSignature),
      isTrue,
    );
    final exported = SSHKeyPair.fromPem((key as SSHKeyPair).toPem()).single;
    expect(exported.toPublicKey().encode(), original.toPublicKey().encode());
  });

  test('legacy encrypted EC PEM rejects absent or incorrect passwords', () {
    expect(() => SSHKeyPair.fromPem(legacyEncryptedEc), throwsArgumentError);
    expect(
      () => SSHKeyPair.fromPem(legacyEncryptedEc, 'incorrect'),
      throwsA(anything),
    );
    expect(
      () => SSHKeyPair.fromPem(
        legacyEncryptedEc.replaceFirst('AES-256-CBC', 'UNKNOWN'),
        'legacy-password',
      ),
      throwsUnsupportedError,
    );
    expect(
      () => SSHKeyPair.fromPem(
        legacyEncryptedEc.replaceFirst('DEK-Info: ', 'DEK-Info: invalid,'),
        'legacy-password',
      ),
      throwsFormatException,
    );
  });

  test('stored PKCS8 RSA signs using SHA2 and preserves SSH public key', () {
    final key = decodeStoredSshKey(
      base64Decode(rsaPrivate),
      base64Decode(rsaPublic),
    );
    expect(key.type, 'rsa-sha2-256');
    final signature = key.sign(message) as SSHRsaSignature;
    expect(
      SSHRsaPublicKey.decode(
        key.toPublicKey().encode(),
      ).verify(message, signature),
      isTrue,
    );
  });

  test(
    'stored PKCS8 EC reuses SEC1 validation and signs a verifiable message',
    () {
      final key = decodeStoredSshKey(
        base64Decode(ecPrivate),
        base64Decode(ecPublic),
      );
      expect(key.type, 'ecdsa-sha2-nistp256');
      expect(
        SSHEcdsaPublicKey.decode(
          key.toPublicKey().encode(),
        ).verify(message, key.sign(message) as SSHEcdsaSignature),
        isTrue,
      );
    },
  );

  test('EC PKCS8 without an embedded point uses the X509 matching check', () {
    final original =
        ASN1Parser(base64Decode(ecPrivate)).nextObject() as ASN1Sequence;
    final inner =
        ASN1Parser(
              (original.elements[2] as ASN1OctetString).octets,
            ).nextObject()
            as ASN1Sequence;
    final minimal = ASN1Sequence()
      ..add(inner.elements[0])
      ..add(inner.elements[1]);
    final outer = ASN1Sequence()
      ..add(original.elements[0])
      ..add(original.elements[1])
      ..add(ASN1OctetString(minimal.encodedBytes));
    final key = decodeStoredSshKey(outer.encodedBytes, base64Decode(ecPublic));
    expect(
      SSHEcdsaPublicKey.decode(
        key.toPublicKey().encode(),
      ).verify(message, key.sign(message) as SSHEcdsaSignature),
      isTrue,
    );
  });

  test('stored Ed25519 seed signs without any native Ed25519 provider', () {
    final key = decodeStoredSshKey(
      base64Decode(edPrivate),
      base64Decode(edPublic),
    );
    expect(key.type, 'ssh-ed25519');
    expect(
      SSHEd25519PublicKey.decode(
        key.toPublicKey().encode(),
      ).verify(message, key.sign(message) as SSHEd25519Signature),
      isTrue,
    );
  });

  test('stored key rejects mismatched algorithms and trailing DER', () {
    expect(
      () =>
          decodeStoredSshKey(base64Decode(rsaPrivate), base64Decode(ecPublic)),
      throwsFormatException,
    );
    expect(
      () => decodeStoredSshKey(
        Uint8List.fromList([...base64Decode(ecPrivate), 0]),
        base64Decode(ecPublic),
      ),
      throwsA(anything),
    );
  });

  test(
    'protected RSA probes before signing and wraps raw signatures',
    () async {
      final calls = <String>[];
      final adapter = SshKeyAdapter((method, args) async {
        calls.add(method);
        if (method == 'ssh.keyMaterial') {
          return {'biometric': true, 'publicKey': base64Decode(rsaPublic)};
        }
        expect(args['id'], 42);
        expect(args['algorithm'], 'rsa-sha2-512');
        expect(args['data'], message);
        return {
          'signature': Uint8List.fromList([0x80, 1, 2]),
        };
      });
      final identities = await adapter.identities(id: 42);
      expect(calls, ['ssh.keyMaterial']);
      expect(identities.map((key) => key.type), [
        'rsa-sha2-512',
        'rsa-sha2-256',
      ]);
      expect(identities.every((key) => key.shouldProbe), isTrue);
      final signature = SSHRsaSignature.decode(
        (await identities.first.sign(message)).encode(),
      );
      expect(signature.type, 'rsa-sha2-512');
      expect(signature.signature, [0x80, 1, 2]);
    },
  );

  test('protected EC converts DER integers into positive SSH mpints', () async {
    final der = ASN1Sequence()
      ..add(ASN1Integer(BigInt.from(128)))
      ..add(ASN1Integer(BigInt.from(255)));
    final adapter = SshKeyAdapter(
      (method, args) async => method == 'ssh.keyMaterial'
          ? {'biometric': true, 'publicKey': base64Decode(ecPublic)}
          : {'signature': der.encodedBytes},
    );
    final identity = (await adapter.identities(id: 7)).single;
    final signature = SSHEcdsaSignature.decode(
      (await identity.sign(message)).encode(),
    );
    expect(signature.type, 'ecdsa-sha2-nistp256');
    expect(signature.r, BigInt.from(128));
    expect(signature.s, BigInt.from(255));
  });

  test(
    'protected key cancellation throws without retrying a weaker signature',
    () async {
      final calls = <String>[];
      final adapter = SshKeyAdapter((method, args) async {
        calls.add(method);
        return method == 'ssh.keyMaterial'
            ? {'biometric': true, 'publicKey': base64Decode(rsaPublic)}
            : {'authcancel': true};
      });
      final identity = (await adapter.identities(id: 7)).first;
      await expectLater(
        identity.sign(message),
        throwsA(isA<SshKeyAuthenticationCancelled>()),
      );
      expect(calls, ['ssh.keyMaterial', 'ssh.sign']);
    },
  );

  test(
    'imported encrypted PEM is decoded by dartssh2 with its password',
    () async {
      final original =
          decodeStoredSshKey(base64Decode(edPrivate), base64Decode(edPublic))
              as OpenSSHEd25519KeyPair;
      final pem = original.toPem(passphrase: 'key password', rounds: 4);
      final adapter = SshKeyAdapter((method, args) async {
        expect(args['password'], 'key password');
        return {'biometric': false, 'pem': pem};
      });
      final key = (await adapter.identities(
        id: 1,
        password: 'key password',
      )).single;
      expect(key.toPublicKey().encode(), original.toPublicKey().encode());
      expect(
        SSHEd25519PublicKey.decode(
          key.toPublicKey().encode(),
        ).verify(message, await key.sign(message) as SSHEd25519Signature),
        isTrue,
      );
    },
  );
}

const rsaPrivate =
    'MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC5Q6Aw6WU0Ut34mu9I4Eg1dCLqLkfOPQL0ZzeD9KFlso5fYL7lYpb3W9ajpXhrtC+N7MzTJKI0+2mRzIEptlj4PRjtzgZAYYBVo+YGst4Mf1EfpDKfOVJoWjvUuYlFjJp5kMXytFvpPYhF5YMCKTcmHb+nSrMbBTllF5buZSBvptXr98IX0DEywvEf9eFbHgPVfzomtRgvASKo8wfKLlvI4szK35MB4quvWmrgEAhseagR/9zLLJS9BZDZvgypwSOqqmLRqp+NshBSwCVHOQWo8SwY8cdRsKySY2F3JvTbnuW6jpyTL9Sktx/GTfChHrdA8+lpAxrHDUrM5Big4kvNAgMBAAECggEBAIB7H7sMAb25wmrIuC2oLSu08QnLMs0ajtQESQHgQ5YNsKMAqyLVrrC5Ji+zb8Hx4hDhKmM7wqpPuTT9yI2vAiCV7pXtDXTUqXW7Bqmanle4bAAvlVPLIxVvjpLGYSa0jeTEvCLHZf5pR/qBYsu63Z43f1R7f567jsRHCcsmosoKkQcPKBAVZSnlpTleTSG6zYQNeWutAFITCZXh288JT8YMW/RdlilEiX7sxuG1zUQYJYBlYW7w4YRHOoxqZqiYTZSMTJ3E3F56p0xkqdY5hY6/cZ8dLIKDfW9/ZnSljF+IoeZQfNJLiUaMCIeYxFR4qjvwIhLHy6FIb87DUzULaIECgYEA6TZuBxIxg53Pn2R84LhWkTJBn6RwnZcU0oSbzgaowp8fU7tXSBHfV1n0FiGmh0bq+FHmrYmgyV/B1EtVqmd7VYt3gsbWvxBo0D1QjHD5se8989IJEENrl0P8qaM+li2z28N1hHv6u9h5q/BmbczvhW/AaThhCi8RJQPJVVDbILECgYEAy13QwDguR2N7EaltuSiQaSAE1I00HFUDCWcuCsWZf8w0uKAt4DfbqR4y9pCJY/tcjDeVJaJBYrovuZtYlYVW/qiT32N28FfYqvvgJUY0LQFxKLd6GtryKTHlUNpc0q55yFRKz92SsKDzujjfWCCFw1v2guNx9d3iesBsjETlA90CgYEAy/VSXNTIgPcvcZMMs+wDqZBuXBQQeYJ8L3DSYmjohu1rFGuvddRLo7WEByb+4ShgrzPRrsvC1trsRaJtFU7TSolix/jmLstHH3fATlMvzTIS2H5Edvi/y9clzaZ7QhROTFCxImDbdBVqs7jXnAezItwNRviLxcBMGjcpiXfhbMECgYB+YEBXExJ/Pmy+HwGWbITBLyqRQ2Y8rP+EGmBcRUsMRcQFb1TS3yNbxu54ln0qaouqfufqSRhE19rMhqLX19Kl0fCCg3boCE8WggtaXnQR+7FsUghJJAIUY3NTeT7xlYcMXIVZAyIjLQIImUsBosQ9EKrxz5GD7mzNR0KtMCr46QKBgGEWGEtb++O8mphqXvnYEXuWlS/7TF93cSX0Fp/IeZf6AXN9jpCnekhCeNdvgApM/1WyPuwyNftRxn57V8Tesl8aDvtOaONLV8Ea8NPV7VXngsbDQ7OfgINBO4fzVqo9essYcrtHDwPFPMPfQcC9x4d1vXx8nr7R1EHiQxwHXkls';

const rsaPublic =
    'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuUOgMOllNFLd+JrvSOBINXQi6i5Hzj0C9Gc3g/ShZbKOX2C+5WKW91vWo6V4a7QvjezM0ySiNPtpkcyBKbZY+D0Y7c4GQGGAVaPmBrLeDH9RH6QynzlSaFo71LmJRYyaeZDF8rRb6T2IReWDAik3Jh2/p0qzGwU5ZReW7mUgb6bV6/fCF9AxMsLxH/XhWx4D1X86JrUYLwEiqPMHyi5byOLMyt+TAeKrr1pq4BAIbHmoEf/cyyyUvQWQ2b4MqcEjqqpi0aqfjbIQUsAlRzkFqPEsGPHHUbCskmNhdyb0257luo6cky/UpLcfxk3woR63QPPpaQMaxw1KzOQYoOJLzQIDAQAB';

const ecPrivate =
    'MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgPMuLi0MZx3tlfkPN1N3sZjTz8kD6kih4iMcAtZKKEpuhRANCAAQBHpA7xOyulIC0B28SNJSAuP5VqYiGrDosmNwfUloxMJkeVVCyFqG2B3ddR9uTu4f8g7Q907oeaA+nQPfHb5pl';

const ecPublic =
    'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEAR6QO8TsrpSAtAdvEjSUgLj+VamIhqw6LJjcH1JaMTCZHlVQshahtgd3XUfbk7uH/IO0PdO6HmgPp0D3x2+aZQ==';

const edPrivate =
    'MC4CAQAwBQYDK2VwBCIEICgYOUSg3pZ/pVYzmlEnY6MmDSzDs/rN/zFj4kM4Ykud';

const edPublic = 'MCowBQYDK2VwAyEASNoQaDvTVBnw1dwVf52jV93/cDed0Z1C4StqNND21t8=';

// OpenSSL SEC1 fixtures, encrypted with AES-256-CBC.
const legacyPlainEc = r'''-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIBtMh7pke0dvrJ4mdLeirI+1ZQu0y/A+wZvjQvAO9TTjoAoGCCqGSM49
AwEHoUQDQgAEjrGgRylP4hAX4oMHnjdJL5pHCZTE8b9Hho++m6C4GLYsRy0oTzSn
BTTK+cTkiloa/6kbk74q+sjzfSnVcXQhnA==
-----END EC PRIVATE KEY-----
''';
const legacyEncryptedEc = r'''-----BEGIN EC PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-256-CBC,ABDCD04704C362E4F6026CF16C35400A

RIFCs3XoRb2eusMKH3GTIWHuwmUhRL1w/kod74/aZAGW1Ck6SeFC8d6XTGA9d1BM
xOStU9AnD8zv4S8QBqIJXmi5zK41/8SSGcSmQy3Yr2ke5pZaxjb2/52oXrhbvQH+
kSnRCX0HVj/OHbGico24Gj8RjSQ6uYe2uhkdyYLb8Z0=
-----END EC PRIVATE KEY-----
''';
