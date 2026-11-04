// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'transfer.dart';
import '../l10n/strings.dart';

class SftpTransfer {
  SftpTransfer({required SftpClient files, required this.openChannel})
    : _files = files;
  final SftpClient _files;
  final Future<SftpClient> Function() openChannel;
  Future<bool> exists(String path) async {
    try {
      await _files
          .stat(path, followLink: false)
          .timeout(const Duration(seconds: 30));
      return true;
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) return false;
      rethrow;
    }
  }

  Future<SftpClient> _transferChannel(TransferControl control) async {
    control.check();
    final channel = await openChannel();
    control.interrupt = () {
      unawaited(channel.close().catchError((Object _) {}));
    };
    if (control.cancelled) {
      await channel.close();
      control.check();
    }
    return channel;
  }

  Stream<Uint8List> _uploadSource(File source, TransferControl control) async* {
    await for (final bytes in source.openRead()) {
      await control.ready;
      yield Uint8List.fromList(bytes);
    }
  }

  Future<void> upload(
    File source,
    String destination, {
    required TransferControl control,
    bool overwrite = false,
    int? permissions,
    void Function(int)? onProgress,
  }) async {
    final stat = await source.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw FileSystemException(deviceStrings.selectARegularFile, source.path);
    }
    control.total = stat.size;
    if (!overwrite && await exists(destination)) {
      throw FileSystemException(
        deviceStrings.aFileWithTheSameNameAlreadyExists,
        destination,
      );
    }
    final channel = await _transferChannel(control);
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final directory = destination.substring(
      0,
      destination.lastIndexOf('/') + 1,
    );
    final temporary = '$directory.tilde-upload-$suffix.part';
    var staged = false;
    try {
      staged = true;
      final file = await channel.open(
        temporary,
        mode:
            SftpFileOpenMode.write |
            SftpFileOpenMode.create |
            SftpFileOpenMode.exclusive,
      );
      final writer = file.write(
        _uploadSource(source, control),
        onProgress: (bytes) {
          control.bytes = bytes;
          onProgress?.call(bytes);
        },
      );
      await writer.done;
      control.check();
      if (permissions != null) {
        await file.setStat(
          SftpFileAttrs(mode: SftpFileMode.value(permissions)),
        );
      }
      await file.close();
      if (control.bytes != stat.size) {
        throw FileSystemException(
          deviceStrings.theSourceFileSizeChangedDuringTransfer,
          source.path,
        );
      }
      if (!overwrite && await exists(destination)) {
        throw FileSystemException(
          deviceStrings.aFileWithTheSameNameAppearedDuringTransfer,
          destination,
        );
      }
      control.check();
      await channel.rename(temporary, destination, overwrite: overwrite);
      staged = false;
    } catch (_) {
      if (control.cancelled) throw TransferCancelled();
      rethrow;
    } finally {
      control.interrupt = null;
      await channel.close();
      if (staged) {
        try {
          await _files.remove(temporary).timeout(const Duration(seconds: 10));
        } on SftpStatusError catch (error) {
          if (error.code != SftpStatusCode.noSuchFile) {
            throw FileSystemException(
              deviceStrings.couldNotRemoveTheTemporaryUploadFileCheckThe(
                (error).toString(),
              ),
              temporary,
            );
          }
        } catch (error) {
          throw FileSystemException(
            deviceStrings.couldNotInspectTheTemporaryUploadFileCheckThe(
              (error).toString(),
            ),
            temporary,
          );
        }
      }
    }
  }

  Future<void> download(
    String source,
    File destination, {
    required TransferControl control,
    bool overwrite = false,
    void Function(int)? onProgress,
  }) async {
    final stat = await _files.stat(source).timeout(const Duration(seconds: 30));
    if (!stat.isFile) {
      throw FileSystemException(deviceStrings.selectARegularFile, source);
    }
    control.total = stat.size;
    final channel = await _transferChannel(control);
    try {
      final file = await channel.open(source);
      await receiveFile(
        destination,
        file.read(),
        control: control,
        overwrite: overwrite,
        onProgress: onProgress,
      );
      await file.close();
    } catch (_) {
      if (control.cancelled) throw TransferCancelled();
      rethrow;
    } finally {
      control.interrupt = null;
      await channel.close();
    }
  }
}
