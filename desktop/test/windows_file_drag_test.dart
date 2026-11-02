// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:io';
import 'package:android_shell_ui/files/transfer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilde_desktop/windows_file_drag.dart';

class RecordingSink implements EventSink {
  final bytes = <int>[];
  Object? error;
  bool closed = false;
  @override
  void add(dynamic data) => bytes.addAll((data as List).cast<int>());
  @override
  void addError(Object error, [StackTrace? stackTrace]) => this.error = error;
  @override
  void close() => closed = true;
}

void main() {
  final entry = SftpName(
    filename: '한글.zip',
    longname: '',
    attr: SftpFileAttrs(size: 3),
  );
  test(
    'virtual download streams exact bytes then removes staging folder',
    () async {
      final sink = RecordingSink();
      Directory? staging;
      await writeVirtualDownload(
        entry: entry,
        control: TransferControl(),
        sinkProvider: ({required fileSize}) {
          expect(fileSize, 3);
          return sink;
        },
        download: (entry, destination, control) async {
          staging = destination.parent;
          await destination.writeAsBytes([0, 128, 255]);
        },
      );
      expect(sink.bytes, [0, 128, 255]);
      expect(sink.closed, isTrue);
      expect(sink.error, isNull);
      expect(await staging!.exists(), isFalse);
    },
  );
  test('failure signals an error and deletes incomplete data', () async {
    final sink = RecordingSink();
    Directory? staging;
    await writeVirtualDownload(
      entry: entry,
      control: TransferControl(),
      sinkProvider: ({required fileSize}) => sink,
      download: (entry, destination, control) async {
        staging = destination.parent;
        await destination.writeAsBytes([0]);
        throw const FileSystemException('disconnected');
      },
    );
    expect(sink.error, isA<FileSystemException>());
    expect(sink.closed, isFalse);
    expect(sink.bytes, isEmpty);
    expect(await staging!.exists(), isFalse);
  });
  test('receiver cancellation prevents successful export', () async {
    final sink = RecordingSink();
    final control = TransferControl();
    await writeVirtualDownload(
      entry: entry,
      control: control,
      sinkProvider: ({required fileSize}) => sink,
      download: (entry, destination, control) async {
        await destination.writeAsBytes([1, 2, 3]);
        control.cancel();
      },
    );
    expect(sink.error, isA<TransferCancelled>());
    expect(sink.bytes, isEmpty);
    expect(sink.closed, isFalse);
  });
}
