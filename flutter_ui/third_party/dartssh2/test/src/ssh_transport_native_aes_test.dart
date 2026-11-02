@TestOn('vm')
library;

import 'dart:async';
import 'dart:mirrors';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

void main() {
  final library = reflectClass(SSHTransport).owner as LibraryMirror;
  Symbol symbol(String name) => MirrorSystem.getSymbol(name, library);
  void set(SSHTransport transport, String name, Object? value) =>
      reflect(transport).setField(symbol(name), value);
  Uint8List process(SSHTransport transport, Uint8List input, bool encrypt,
          int sequence) =>
      reflect(transport).invoke(symbol('_processAead'), [], {
        #key: Uint8List(32),
        #iv: Uint8List(12),
        #sequence: sequence,
        #aad: Uint8List.fromList([0, 0, 0, 16]),
        #input: input,
        #forEncryption: encrypt,
      }).reflectee as Uint8List;

  test('backend matches portable packets, nonce counters and tag rejection',
      () async {
    final providers = <TestCipher>[];
    final native = SSHTransport(TestSocket(), aesGcmFactory: (key) {
      final cipher = TestCipher(key);
      providers.add(cipher);
      return cipher;
    });
    final portable = SSHTransport(TestSocket());
    final input = Uint8List.fromList([1, 2, 3]);
    for (final sequence in [0, 1, 256]) {
      final encrypted = process(native, input, true, sequence);
      expect(encrypted, process(portable, input, true, sequence));
      expect(process(native, encrypted, false, sequence), input);
    }
    expect(providers, hasLength(2));
    expect(providers.first.nonces.map((n) => n.last), [0, 1, 0]);
    final bad = process(native, input, true, 257)..[0] ^= 1;
    expect(
        () => process(native, bad, false, 257), throwsA(isA<SSHPacketError>()));
    await native.close();
    await portable.close();
    expect(providers.every((cipher) => cipher.disposed), isTrue);
  });

  test(
      'rekey disposes only that direction and algorithm switch disposes backend',
      () async {
    final transport = SSHTransport(TestSocket(), aesGcmFactory: TestCipher.new);
    set(transport, '_kexType', SSHKexType.x25519);
    set(transport, '_sharedSecret', BigInt.from(21));
    set(transport, '_exchangeHash', Uint8List(32));
    set(transport, '_sessionId', Uint8List(32));
    set(transport, '_clientCipherType', SSHCipherType.aes256gcm);
    set(transport, '_serverCipherType', SSHCipherType.aes256gcm);
    process(transport, Uint8List(0), true, 0);
    final local = reflect(transport).getField(symbol('_localAesGcm')).reflectee
        as TestCipher;
    final remote = TestCipher(Uint8List(32));
    set(transport, '_remoteAesGcm', remote);
    reflect(transport).invoke(symbol('_applyLocalKeys'), []);
    expect(local.disposed, isTrue);
    expect(remote.disposed, isFalse);
    set(transport, '_serverCipherType', SSHCipherType.chacha20poly1305);
    reflect(transport).invoke(symbol('_applyRemoteKeys'), []);
    expect(remote.disposed, isTrue);
    await transport.close();
  });

  test('native failure propagates without portable retry', () async {
    final transport = SSHTransport(TestSocket(),
        aesGcmFactory: (_) => throw StateError('native failure'));
    expect(() => process(transport, Uint8List(0), true, 0), throwsStateError);
    await transport.close();
  });
}

class TestCipher implements SSHAesGcm {
  TestCipher(this.key);
  final Uint8List key;
  final nonces = <Uint8List>[];
  bool disposed = false;
  @override
  Uint8List process(
      {required Uint8List nonce,
      required Uint8List aad,
      required Uint8List input,
      required bool encrypt}) {
    nonces.add(Uint8List.fromList(nonce));
    final cipher = GCMBlockCipher(AESEngine())
      ..init(encrypt, AEADParameters(KeyParameter(key), 128, nonce, aad));
    try {
      return cipher.process(input);
    } on InvalidCipherTextException {
      throw SSHPacketError('AEAD authentication failed');
    }
  }

  @override
  void dispose() => disposed = true;
}

class TestSocket implements SSHSocket {
  final input = StreamController<Uint8List>();
  final output = StreamController<List<int>>()..stream.listen((_) {});
  @override
  Stream<Uint8List> get stream => input.stream;
  @override
  StreamSink<List<int>> get sink => output.sink;
  @override
  Future<void> get done => input.done;
  @override
  Future<void> close() async {
    await input.close();
    await output.close();
  }

  @override
  void destroy() {
    unawaited(close());
  }

  @override
  Future<void> flush() async {}
}
