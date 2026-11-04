// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

String fileFailureSummary(Object error) => switch (error) {
  SftpStatusError() => switch (error.code) {
    SftpStatusCode.permissionDenied => '서버에서 접근 권한을 거부했습니다. 대상 경로의 권한을 확인하세요.',
    SftpStatusCode.noSuchFile => '파일이나 폴더가 더 이상 없습니다.',
    SftpStatusCode.connectionLost ||
    SftpStatusCode.noConnection => '서버 연결이 끊겼습니다.',
    _ => '서버에서 작업을 완료하지 못했습니다.',
  },
  TimeoutException() => '서버가 응답하지 않습니다. 주소와 네트워크를 확인하세요.',
  SSHAuthError() => '서버에서 인증을 받지 않았습니다. 사용자 이름과 키·비밀번호를 확인하세요.',
  SocketException() => switch (error.osError?.errorCode) {
    61 || 111 || 10061 =>
      '서버가 ${error.port == null ? '' : '${error.port}번 포트 '}연결을 거부했습니다. SSH 실행 상태와 포트를 확인하세요.',
    60 || 110 || 10060 => '서버가 응답하지 않습니다. 주소와 네트워크를 확인하세요.',
    _ => '서버 연결을 확인하세요.',
  },
  StateError() => error.message.toString(),
  _ => '예상하지 못한 오류입니다. 아래 기록을 복사해 문의해 주세요.',
};

class TransferCancelled implements Exception {
  @override
  String toString() => '전송을 취소했습니다.';
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
    throw ArgumentError.value(name, 'name', '파일 이름이 올바르지 않습니다.');
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
    throw FileSystemException('같은 이름의 파일이 있습니다.', destination.path);
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
      throw FileSystemException('전송 중 같은 이름의 파일이 생겼습니다.', destination.path);
    }
    if (control.total != null && control.bytes != control.total) {
      throw FileSystemException('파일이 끝까지 도착하지 않았습니다.', destination.path);
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
