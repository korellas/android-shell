// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:dartssh2/dartssh2.dart';
import 'transfer.dart';
import '../l10n/strings.dart';

String? remoteNameError(String? name) {
  if (name == null || name.trim().isEmpty) return deviceStrings.enterAName;
  if (name == '.' ||
      name == '..' ||
      name.contains('/') ||
      name.contains(r'\') ||
      name.contains('\x00')) {
    return deviceStrings.namesCannotContainPathSeparatorsOrBeOr;
  }
  return null;
}

class SftpFileOperations {
  SftpFileOperations(this.files);
  final SftpClient files;
  static const _timeout = Duration(seconds: 30);

  String _namedPath(String directory, String name) {
    final error = remoteNameError(name);
    if (error != null) throw ArgumentError(error);
    return remoteChild(directory, name);
  }

  Future<void> _ensureAvailable(String path) async {
    try {
      await files.stat(path, followLink: false).timeout(_timeout);
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) return;
      rethrow;
    }
    throw StateError(deviceStrings.aFileOrFolderWithTheSameNameAlready);
  }

  Future<void> rename(String directory, String oldName, String newName) async {
    if (oldName == newName) return;
    final destination = _namedPath(directory, newName);
    await _ensureAvailable(destination);
    await files
        .rename(remoteChild(directory, oldName), destination, overwrite: false)
        .timeout(_timeout);
  }

  Future<void> move(String source, String destination) async {
    if (destination == source || destination.startsWith('$source/')) {
      throw StateError(
        deviceStrings.cannotMoveAFolderIntoItselfOrItsDescendants,
      );
    }
    await _ensureAvailable(destination);
    await files.rename(source, destination, overwrite: false).timeout(_timeout);
  }

  Future<void> createDirectory(String directory, String name) async {
    final path = _namedPath(directory, name);
    await _ensureAvailable(path);
    await files.mkdir(path).timeout(_timeout);
  }

  Future<int> delete(
    String path, {
    required TransferControl control,
    void Function(int)? onDeleted,
  }) async {
    if (path.isEmpty || path == '/') {
      throw ArgumentError(deviceStrings.cannotDeleteTheRootFolder);
    }
    var deleted = 0;
    Future<void> remove(String path) async {
      await control.ready;
      final attrs = await files.stat(path, followLink: false).timeout(_timeout);
      control.check();
      if (attrs.isDirectory) {
        final entries = await files.listdir(path).timeout(_timeout);
        for (final entry in entries) {
          if (entry.filename == '.' || entry.filename == '..') continue;
          await remove(remoteChild(path, entry.filename));
        }
        control.check();
        await files.rmdir(path).timeout(_timeout);
      } else {
        await files.remove(path).timeout(_timeout);
      }
      deleted++;
      onDeleted?.call(deleted);
    }

    await remove(path);
    return deleted;
  }
}

String remotePermissions(int? mode) {
  if (mode == null) return '—';
  final bits = [
    for (var bit = 8; bit >= 0; bit--)
      (mode & (1 << bit)) != 0 ? 'rwx'[(8 - bit) % 3] : '-',
  ];
  if ((mode & 0x800) != 0) bits[2] = bits[2] == 'x' ? 's' : 'S';
  if ((mode & 0x400) != 0) bits[5] = bits[5] == 'x' ? 's' : 'S';
  if ((mode & 0x200) != 0) bits[8] = bits[8] == 'x' ? 't' : 'T';
  return bits.join();
}
