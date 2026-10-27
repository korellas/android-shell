@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/ssh_packet.dart';
import 'package:dartssh2/src/utils/ssh_compression_io.dart';
import 'package:test/test.dart';

final _library = reflectClass(SSHTransport).owner as LibraryMirror;
Symbol _symbol(String name) => MirrorSystem.getSymbol(name, _library);
void _set(SSHTransport transport, String name, Object? value) =>
    reflect(transport).setField(_symbol(name), value);
T _get<T>(SSHTransport transport, String name) =>
    reflect(transport).getField(_symbol(name)).reflectee as T;
dynamic _call(SSHTransport transport, String name,
        [List<Object?> args = const []]) =>
    reflect(transport).invoke(_symbol(name), args).reflectee;
Uint8List _payload(Uint8List packet) => Uint8List.sublistView(
    packet,
    5,
    4 +
        SSHPacket.readPacketLength(packet) -
        SSHPacket.readPaddingLength(packet));

void main() {
  late _Socket socket;
  late SSHTransport transport;
  setUp(() {
    socket = _Socket();
    transport = SSHTransport(socket, compression: true);
    _set(transport, '_kexInProgress', false);
  });
  tearDown(() async => transport.close());

  void negotiate(String name) {
    _set(transport, '_clientCompressionName', name);
    _set(transport, '_serverCompressionName', name);
    _call(transport, '_resetLocalCompression');
    _call(transport, '_resetRemoteCompression');
  }

  final data = Uint8List.fromList([94, ...utf8.encode('한글 압축 😀' * 100)]);

  test('negotiation keeps none default and chooses delayed compression first',
      () async {
    final plain = SSHTransport(_Socket());
    addTearDown(plain.close);
    expect(_get<List<String>>(plain, '_compressionNames'), ['none']);
    expect(
        _call(plain, '_selectCompression', [
          ['zlib', 'none']
        ]),
        'none');
    expect(
        _call(transport, '_selectCompression', [
          ['none', 'zlib', 'zlib@openssh.com']
        ]),
        'zlib@openssh.com');
    expect(
        _call(transport, '_selectCompression', [
          ['zlib']
        ]),
        'zlib');
    expect(
        _call(transport, '_selectCompression', [
          ['none']
        ]),
        'none');
    expect(
        () => _call(transport, '_selectCompression', [
              ['unknown']
            ]),
        throwsA(isA<SSHHandshakeError>()));
  });

  test(
      'delayed compression starts after authentication and keeps its dictionary',
      () {
    negotiate('zlib@openssh.com');
    transport.sendPacket(data);
    expect(_payload(socket.packets.last), data);
    transport.notifyAuthenticated();
    final inflate = SSHZlib(compress: false);
    addTearDown(inflate.dispose);
    transport.sendPacket(data);
    final first = _payload(socket.packets.last);
    expect(inflate.process(first), data);
    transport.notifyAuthenticated();
    transport.sendPacket(data);
    final next = _payload(socket.packets.last);
    expect(inflate.process(next), data);
    expect(next.length, lessThan(first.length));
  });

  test(
      'immediate zlib works before authentication; directional rekey resets only its context',
      () {
    negotiate('zlib');
    final remote = _get<SSHZlib>(transport, '_decompressor');
    final old = _get<SSHZlib>(transport, '_compressor');
    final inflate = SSHZlib(compress: false);
    addTearDown(inflate.dispose);
    transport.sendPacket(data);
    final first = _payload(socket.packets.last);
    expect(inflate.process(first), data);
    _call(transport, '_resetLocalCompression');
    expect(_get<SSHZlib>(transport, '_decompressor'), same(remote));
    expect(() => old.process(data), throwsStateError);
    transport.sendPacket(data);
    expect(_payload(socket.packets.last), first);
    _call(transport, '_resetRemoteCompression');
    expect(() => remote.process(data), throwsStateError);
  });

  test(
      'negotiating none during rekey does not alter the active dictionary until NEWKEYS',
      () {
    negotiate('zlib');
    final inflate = SSHZlib(compress: false);
    addTearDown(inflate.dispose);
    _set(transport, '_clientCompressionName', 'none');
    transport.sendPacket(data);
    expect(inflate.process(_payload(socket.packets.last)), data);
    _call(transport, '_resetLocalCompression');
    transport.sendPacket(data);
    expect(_payload(socket.packets.last), data);
  });

  test(
      'rekey queue retains uncompressed bytes without advancing the dictionary',
      () {
    negotiate('zlib');
    _set(transport, '_kexInProgress', true);
    final before = socket.packets.length;
    transport.sendPacket(data);
    expect(socket.packets.length, before);
    expect(_get<Iterable<Uint8List>>(transport, '_rekeyPendingPackets').single,
        data);
    _set(transport, '_kexInProgress', false);
    transport.sendPacket(data);
    final fresh = SSHZlib(compress: false);
    addTearDown(fresh.dispose);
    expect(fresh.process(_payload(socket.packets.last)), data);
  });

  for (final malformed in [false, true]) {
    test(
        'incoming ${malformed ? 'malformed' : 'oversized'} compressed packet closes before dispatch',
        () async {
      final peer = _Socket();
      final sender = SSHTransport(peer);
      addTearDown(sender.close);
      _set(sender, '_kexInProgress', false);
      var delivered = false;
      final receiverSocket = _Socket();
      final receiver =
          SSHTransport(receiverSocket, compression: true, onMessage: (_) {
        delivered = true;
        return true;
      });
      addTearDown(receiver.close);
      _set(receiver, '_remoteVersion', 'SSH-2.0-test');
      _set(receiver, '_kexInProgress', false);
      _set(receiver, '_serverCompressionName', 'zlib');
      _call(receiver, '_resetRemoteCompression');
      final rejected =
          expectLater(receiver.done, throwsA(isA<SSHPacketError>()));
      final compressed = malformed
          ? [255, 255, 255]
          : zlib.encode(List.filled(SSHPacket.maxLength * 2, 94));
      sender.sendPacket(Uint8List.fromList(compressed));
      receiverSocket.input.add(peer.packets.last);
      await rejected.timeout(const Duration(seconds: 2));
      expect(delivered, isFalse);
      expect(receiver.isClosed, isTrue);
      expect(_get<Object?>(receiver, '_decompressor'), isNull);
    });
  }
}

class _Socket implements SSHSocket {
  final input = StreamController<Uint8List>();
  final completion = Completer<void>();
  final packets = <Uint8List>[];
  @override
  Stream<Uint8List> get stream => input.stream;
  @override
  StreamSink<List<int>> get sink => _Sink(packets);
  @override
  Future<void> get done => completion.future;
  @override
  Future<void> close() async {
    if (!completion.isCompleted) completion.complete();
    await input.close();
  }

  @override
  void destroy() {
    unawaited(close());
  }

  @override
  Future<void> flush() async {}
}

class _Sink implements StreamSink<List<int>> {
  _Sink(this.packets);
  final List<Uint8List> packets;
  @override
  void add(List<int> data) => packets.add(Uint8List.fromList(data));
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> get done async {}
}
