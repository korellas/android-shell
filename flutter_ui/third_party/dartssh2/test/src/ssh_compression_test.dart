@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:dartssh2/src/ssh_packet.dart';
import 'package:dartssh2/src/utils/ssh_compression_io.dart';
import 'package:test/test.dart';

void main() {
  test('retains the zlib dictionary across SSH packet boundaries', () {
    final encoder = SSHZlib(compress: true);
    final decoder = SSHZlib(compress: false);
    addTearDown(encoder.dispose);
    addTearDown(decoder.dispose);
    final input = Uint8List.fromList(utf8.encode('한글 terminal output ' * 800));
    final first = encoder.process(input);
    final second = encoder.process(input);
    expect(decoder.process(first), input);
    expect(decoder.process(second), input);
    expect(second.length, lessThan(first.length));
  });

  test('bounds expanded data before retaining a large decompressed packet', () {
    final decoder = SSHZlib(compress: false);
    addTearDown(decoder.dispose);
    final bomb = Uint8List.fromList(zlib.encode(
      Uint8List(SSHPacket.maxLength * 32),
    ));
    expect(() => decoder.process(bomb), throwsA(isA<SSHPacketError>()));
    expect(() => decoder.process(Uint8List(0)), throwsStateError);
  });

  test('malformed compressed data fails and invalidates its dictionary', () {
    final decoder = SSHZlib(compress: false);
    addTearDown(decoder.dispose);
    expect(() => decoder.process(Uint8List.fromList([255, 255, 255])),
        throwsA(isA<SSHPacketError>()));
    expect(() => decoder.process(Uint8List(0)), throwsStateError);
  });

  test('new contexts accept a fresh zlib stream after rekey', () {
    final input = Uint8List.fromList(utf8.encode('same payload ' * 500));
    for (var keyExchange = 0; keyExchange < 2; keyExchange++) {
      final encoder = SSHZlib(compress: true);
      final decoder = SSHZlib(compress: false);
      expect(decoder.process(encoder.process(input)), input);
      encoder.dispose();
      decoder.dispose();
    }
  });

  test('disposed contexts reject further use', () {
    final encoder = SSHZlib(compress: true)..dispose();
    encoder.dispose();
    expect(() => encoder.process(Uint8List.fromList([1])), throwsStateError);
  });
}
