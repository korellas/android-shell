// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/files/transfer.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tilde-files-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('downloads arbitrary binary data and reports progress', () async {
    final destination = File('${directory.path}/공백 있는 파일.bin');
    final data = Uint8List.fromList(List.generate(200000, (i) => i % 256));
    final progress = <int>[];
    await receiveFile(
      destination,
      Stream.fromIterable([data.sublist(0, 70000), data.sublist(70000)]),
      control: TransferControl(),
      onProgress: progress.add,
    );
    expect(await destination.readAsBytes(), data);
    expect(progress.last, data.length);
    expect(await directory.list().length, 1);
  });

  test('requires confirmation before replacing an existing file', () async {
    final destination = await File(
      '${directory.path}/existing',
    ).writeAsString('original');
    await expectLater(
      receiveFile(
        destination,
        Stream.value(Uint8List.fromList([1])),
        control: TransferControl(),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await destination.readAsString(), 'original');
  });

  test('cancel leaves original file intact and removes partial data', () async {
    final destination = await File(
      '${directory.path}/existing',
    ).writeAsString('original');
    final control = TransferControl();
    Stream<Uint8List> data() async* {
      yield Uint8List.fromList([1, 2]);
      control.cancel();
      yield Uint8List.fromList([3, 4]);
    }

    await expectLater(
      receiveFile(destination, data(), control: control, overwrite: true),
      throwsA(isA<TransferCancelled>()),
    );
    expect(await destination.readAsString(), 'original');
    expect(await directory.list().length, 1);
  });

  test('source failure preserves original and removes partial data', () async {
    final destination = await File(
      '${directory.path}/existing',
    ).writeAsString('original');
    Stream<Uint8List> data() async* {
      yield Uint8List.fromList([1]);
      throw const SocketException('connection lost');
    }

    await expectLater(
      receiveFile(
        destination,
        data(),
        control: TransferControl(),
        overwrite: true,
      ),
      throwsA(isA<SocketException>()),
    );
    expect(await destination.readAsString(), 'original');
    expect(await directory.list().length, 1);
  });

  test('confirmed overwrite replaces complete contents', () async {
    final destination = await File(
      '${directory.path}/existing',
    ).writeAsString('long original');
    await receiveFile(
      destination,
      Stream.value(Uint8List.fromList([42])),
      control: TransferControl(),
      overwrite: true,
    );
    expect(await destination.readAsBytes(), [42]);
  });

  test('short download does not replace existing file', () async {
    final destination = await File(
      '${directory.path}/existing',
    ).writeAsString('original');
    final control = TransferControl()..total = 10;
    await expectLater(
      receiveFile(
        destination,
        Stream.value(Uint8List.fromList([1, 2])),
        control: control,
        overwrite: true,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await destination.readAsString(), 'original');
    expect(await directory.list().length, 1);
  });

  test('remote names cannot escape the chosen local directory', () {
    for (final name in [
      '',
      '.',
      '..',
      '../escape',
      '/absolute',
      r'..\escape',
      'a/b',
      'a\x00b',
    ]) {
      expect(
        () => localDestination(directory, name),
        throwsArgumentError,
        reason: name,
      );
    }
    final file = localDestination(directory, r'한글 ; $(literal).txt');
    expect(file.parent.path, directory.path);
  });
}
