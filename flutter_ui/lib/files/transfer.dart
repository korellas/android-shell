// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../l10n/strings.dart';

String fileFailureSummary(Object error) => switch (error) {
  SftpStatusError() => switch (error.code) {
    SftpStatusCode.permissionDenied =>
      deviceStrings.theServerDeniedAccessCheckTheDestinationPathPermissions,
    SftpStatusCode.noSuchFile => deviceStrings.theFileOrFolderNoLongerExists,
    SftpStatusCode.connectionLost ||
    SftpStatusCode.noConnection => deviceStrings.serverConnectionLost,
    _ => deviceStrings.theServerCouldNotCompleteTheOperation,
  },
  TimeoutException() =>
    deviceStrings.theServerIsNotRespondingCheckTheAddressAnd,
  SSHAuthError() =>
    deviceStrings.theServerDidNotAuthenticateYouCheckYourUsername,
  SocketException() => switch (error.osError?.errorCode) {
    61 ||
    111 ||
    10061 => deviceStrings.theServerRefusedTheConnectionCheckSshAndPort(
      (error.port == null ? '' : deviceStrings.onPort((error.port).toString()))
          .toString(),
    ),
    60 ||
    110 ||
    10060 => deviceStrings.theServerIsNotRespondingCheckTheAddressAnd,
    _ => deviceStrings.checkTheServerConnection,
  },
  StateError() => error.message.toString(),
  _ => deviceStrings.unexpectedErrorCopyTheDetailsBelowAndContactSupport,
};

class TransferCancelled implements Exception {
  @override
  String toString() => deviceStrings.transferCancelled;
}

class TransferControl {
  TransferControl({this.parent});
  final TransferControl? parent;
  Completer<void>? _pause;
  bool get paused => _pause != null || (parent?.paused ?? false);
  void pause() {
    if (!cancelled) _pause ??= Completer<void>();
  }

  void resume() {
    final gate = _pause;
    _pause = null;
    gate?.complete();
  }

  Future<void> get ready async {
    check();
    await parent?.ready;
    if (_pause != null) await _pause!.future;
    check();
  }

  bool _cancelled = false;
  bool get cancelled => _cancelled || (parent?.cancelled ?? false);
  int bytes = 0;
  int? total;
  void Function()? interrupt;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    resume();
    interrupt?.call();
  }

  void check() {
    if (cancelled) throw TransferCancelled();
  }
}

File localDestination(Directory directory, String name) {
  if (name.isEmpty ||
      name == '.' ||
      name == '..' ||
      name.contains('/') ||
      name.contains(r'\') ||
      name.contains('\x00')) {
    throw ArgumentError.value(name, 'name', deviceStrings.invalidFileName);
  }
  return File('${directory.absolute.path}${Platform.pathSeparator}$name');
}

String remoteChild(String directory, String name) {
  if (name.isEmpty ||
      name == '.' ||
      name == '..' ||
      name.contains('/') ||
      name.contains('\x00')) {
    throw ArgumentError.value(name, 'name');
  }
  return '${directory.endsWith('/') ? directory : '$directory/'}$name';
}

String fileName(String path) => File(path).uri.pathSegments.last;

Future<void> receiveFile(
  File destination,
  Stream<Uint8List> source, {
  required TransferControl control,
  bool overwrite = false,
  void Function(int)? onProgress,
}) async {
  control.check();
  if (!overwrite &&
      await FileSystemEntity.type(destination.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
    throw FileSystemException(
      deviceStrings.aFileWithTheSameNameAlreadyExists,
      destination.path,
    );
  }
  final temporary = await destination.parent.createTemp('.tilde-download-');
  try {
    final staged = File('${temporary.path}${Platform.pathSeparator}data');
    final output = await staged.open(mode: FileMode.writeOnly);
    try {
      await for (final chunk in source) {
        await control.ready;
        await output.writeFrom(chunk);
        control.bytes += chunk.length;
        onProgress?.call(control.bytes);
      }
      control.check();
      await output.flush();
    } finally {
      await output.close();
    }
    control.check();
    if (!overwrite &&
        await FileSystemEntity.type(destination.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
      throw FileSystemException(
        deviceStrings.aFileWithTheSameNameAppearedDuringTransfer,
        destination.path,
      );
    }
    if (control.total != null && control.bytes != control.total) {
      throw FileSystemException(
        deviceStrings.theFileWasNotReceivedCompletely,
        destination.path,
      );
    }
    await staged.rename(destination.path);
  } finally {
    await temporary.delete(recursive: true);
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
