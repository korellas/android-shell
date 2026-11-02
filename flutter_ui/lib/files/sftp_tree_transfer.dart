// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'file_job_queue.dart';
import 'sftp_transfer.dart';
import 'transfer.dart';

enum TreeEntryKind { directory, file, link }

class TreeEntry {
  const TreeEntry(
    this.source,
    this.destination,
    this.kind,
    this.size,
    this.modified, {
    this.linkTarget,
  });
  final String source, destination;
  final TreeEntryKind kind;
  final int? size, modified;
  final String? linkTarget;
}

typedef ConflictResolution = ({String path, bool overwrite});
typedef ResolveFileConflict =
    Future<ConflictResolution?> Function(
      TreeEntry source,
      SftpFileAttrs existing,
    );

class SftpTreeTransfer {
  SftpTreeTransfer(this.files, this.openChannel);
  final SftpClient files;
  final Future<SftpClient> Function() openChannel;
  static const timeout = Duration(seconds: 30);
  Future<List<TreeEntry>> planUpload(
    String source,
    String destination,
    TransferControl control,
  ) async {
    final result = <TreeEntry>[];
    Future<void> visit(String path, String target) async {
      await control.ready;
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.link) {
        result.add(
          TreeEntry(
            path,
            target,
            TreeEntryKind.link,
            0,
            null,
            linkTarget: await Link(path).target(),
          ),
        );
      } else if (type == FileSystemEntityType.directory) {
        result.add(TreeEntry(path, target, TreeEntryKind.directory, 0, null));
        await for (final child in Directory(path).list(followLinks: false)) {
          await visit(child.path, remoteChild(target, fileName(child.path)));
        }
      } else if (type == FileSystemEntityType.file) {
        final stat = await File(path).stat();
        result.add(
          TreeEntry(
            path,
            target,
            TreeEntryKind.file,
            stat.size,
            stat.modified.millisecondsSinceEpoch,
          ),
        );
      } else {
        throw FileSystemException('지원하지 않는 파일 종류입니다.', path);
      }
    }

    await visit(source, destination);
    return result;
  }

  Future<List<TreeEntry>> planDownload(
    String source,
    String destination,
    TransferControl control,
  ) async {
    final result = <TreeEntry>[];
    Future<void> visit(String path, String target, SftpFileAttrs attrs) async {
      await control.ready;
      if (attrs.isSymbolicLink) {
        result.add(
          TreeEntry(
            path,
            target,
            TreeEntryKind.link,
            0,
            null,
            linkTarget: await files.readlink(path).timeout(timeout),
          ),
        );
      } else if (attrs.isDirectory) {
        result.add(TreeEntry(path, target, TreeEntryKind.directory, 0, null));
        for (final child in await files.listdir(path).timeout(timeout)) {
          if (child.filename == '.' || child.filename == '..') continue;
          await visit(
            remoteChild(path, child.filename),
            localDestination(Directory(target), child.filename).path,
            child.attr,
          );
        }
      } else if (attrs.isFile) {
        result.add(
          TreeEntry(
            path,
            target,
            TreeEntryKind.file,
            attrs.size,
            attrs.modifyTime,
          ),
        );
      } else {
        throw FileSystemException('지원하지 않는 원격 파일 종류입니다.', path);
      }
    }

    await visit(
      source,
      destination,
      await files.stat(source, followLink: false).timeout(timeout),
    );
    return result;
  }

  Future<SftpFileAttrs?> _remoteStat(String path) async {
    try {
      return await files.stat(path, followLink: false).timeout(timeout);
    } on SftpStatusError catch (error) {
      if (error.code == SftpStatusCode.noSuchFile) return null;
      rethrow;
    }
  }

  Future<void> run(
    List<TreeEntry> plan, {
    required bool upload,
    required FileJob job,
    required ResolveFileConflict resolve,
    required void Function() changed,
  }) async {
    final control = job.control;
    job.totalFiles = plan
        .where((entry) => entry.kind != TreeEntryKind.directory)
        .length;
    control.total = plan.any((entry) => entry.size == null)
        ? null
        : plan.fold<int>(0, (sum, entry) => sum + entry.size!);
    var completedBytes = 0;
    job.completedFiles = 0;
    final transfer = SftpTransfer(files: files, openChannel: openChannel);
    for (final entry in plan) {
      await control.ready;
      job.detail = entry.source;
      if (job.completedPaths.contains(entry.destination)) {
        completedBytes += entry.size ?? 0;
        if (entry.kind != TreeEntryKind.directory) job.completedFiles++;
        control.bytes = completedBytes;
        changed();
        continue;
      }
      if (entry.kind == TreeEntryKind.file) {
        final current = upload
            ? null
            : await files
                  .stat(entry.source, followLink: false)
                  .timeout(timeout);
        final local = upload ? await File(entry.source).stat() : null;
        if ((upload ? local!.size : current!.size) != entry.size ||
            (upload
                    ? local!.modified.millisecondsSinceEpoch
                    : current!.modifyTime) !=
                entry.modified) {
          throw FileSystemException(
            '전송 원본이 변경되었습니다. 새 작업으로 다시 전송하세요.',
            entry.source,
          );
        }
      }
      var destination = entry.destination;
      SftpFileAttrs? existing;
      if (upload) {
        existing = await _remoteStat(destination);
      } else {
        final type = await FileSystemEntity.type(
          destination,
          followLinks: false,
        );
        if (type != FileSystemEntityType.notFound) {
          final stat = await File(destination).stat();
          existing = SftpFileAttrs(
            size: stat.size,
            modifyTime: stat.modified.millisecondsSinceEpoch ~/ 1000,
            mode: SftpFileMode.value(
              type == FileSystemEntityType.directory
                  ? 0x4000
                  : type == FileSystemEntityType.link
                  ? 0xa000
                  : 0x8000,
            ),
          );
        }
      }
      if (entry.kind == TreeEntryKind.directory) {
        if (existing != null && !existing.isDirectory) {
          throw FileSystemException('같은 이름의 폴더가 아닌 항목이 있습니다.', destination);
        }
        if (existing == null) {
          if (upload) {
            await files.mkdir(destination).timeout(timeout);
          } else {
            await Directory(destination).create();
          }
        }
      } else {
        var overwrite = false;
        if (existing != null) {
          final choice = await resolve(entry, existing);
          await control.ready;
          if (choice == null) {
            completedBytes += entry.size ?? 0;
            job.completedFiles++;
            job.completedPaths.add(entry.destination);
            control.bytes = completedBytes;
            changed();
            continue;
          }
          destination = choice.path;
          overwrite = choice.overwrite;
          if (existing.isDirectory &&
              overwrite &&
              destination == entry.destination) {
            throw FileSystemException('폴더를 파일로 덮어쓸 수 없습니다.', destination);
          }
        }
        final leaf = TransferControl(parent: control);
        control.interrupt = leaf.cancel;
        try {
          void progress(int bytes) {
            control.bytes = completedBytes + bytes;
            changed();
          }

          if (entry.kind == TreeEntryKind.link) {
            if (upload) {
              final directory = destination.substring(
                0,
                destination.lastIndexOf('/') + 1,
              );
              final staged =
                  '$directory.tilde-link-${DateTime.now().microsecondsSinceEpoch}';
              await files.link(entry.linkTarget!, staged).timeout(timeout);
              try {
                await control.ready;
                await files
                    .rename(staged, destination, overwrite: overwrite)
                    .timeout(timeout);
              } finally {
                if (await _remoteStat(staged) != null) {
                  await files.remove(staged).timeout(timeout);
                }
              }
            } else {
              final temporary = await File(
                destination,
              ).parent.createTemp('.tilde-link-');
              try {
                final staged = await Link(
                  '${temporary.path}${Platform.pathSeparator}link',
                ).create(entry.linkTarget!);
                await control.ready;
                if (!overwrite &&
                    await FileSystemEntity.type(
                          destination,
                          followLinks: false,
                        ) !=
                        FileSystemEntityType.notFound) {
                  throw FileSystemException('같은 이름의 파일이 있습니다.', destination);
                }
                await staged.rename(destination);
              } finally {
                await temporary.delete(recursive: true);
              }
            }
          } else if (upload) {
            await transfer.upload(
              File(entry.source),
              destination,
              control: leaf,
              overwrite: overwrite,
              onProgress: progress,
            );
          } else {
            await transfer.download(
              entry.source,
              File(destination),
              control: leaf,
              overwrite: overwrite,
              onProgress: progress,
            );
          }
          completedBytes += entry.size ?? leaf.bytes;
          job.completedFiles++;
        } finally {
          control.interrupt = null;
        }
      }
      job.completedPaths.add(entry.destination);
      control.bytes = completedBytes;
      changed();
    }
  }
}
