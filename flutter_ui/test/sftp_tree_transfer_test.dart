// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:android_shell_ui/files/file_job_queue.dart';
import 'package:android_shell_ui/files/sftp_tree_transfer.dart';
import 'package:android_shell_ui/files/transfer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'sftp_file_operations_test.dart' show FakeFiles;

class TreeFiles extends FakeFiles {
  final links = <String, String>{};
  @override
  Future<void> link(String linkPath, String targetPath) async {
    links[targetPath] = linkPath;
    nodes[targetPath] = SftpFileAttrs(mode: SftpFileMode.value(0xa000));
  }

  @override
  Future<void> rename(
    String oldPath,
    String newPath, {
    bool overwrite = true,
  }) async {
    await super.rename(oldPath, newPath, overwrite: overwrite);
    if (links.containsKey(oldPath)) links[newPath] = links.remove(oldPath)!;
  }

  @override
  Future<String> readlink(String path) async => links[path]!;
}

void main() {
  late Directory temporary;
  late TreeFiles files;
  late SftpTreeTransfer tree;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('tilde-tree-test-');
    files = TreeFiles();
    tree = SftpTreeTransfer(files, () async => files);
  });
  tearDown(() => temporary.delete(recursive: true));

  test(
    'upload plans nested empty folders, binary files and links without following them',
    () async {
      final source = await Directory('${temporary.path}/source').create();
      await Directory('${source.path}/empty').create();
      await File('${source.path}/한글.bin').writeAsBytes([0, 128, 255]);
      if (!Platform.isWindows) await Link('${source.path}/cycle').create('.');
      final plan = await tree.planUpload(
        source.path,
        '/fixed/source',
        TransferControl(),
      );
      expect(plan.first.kind, TreeEntryKind.directory);
      expect(
        plan.any(
          (entry) =>
              entry.destination == '/fixed/source/empty' &&
              entry.kind == TreeEntryKind.directory,
        ),
        isTrue,
      );
      final binary = plan.singleWhere(
        (entry) => entry.destination.endsWith('한글.bin'),
      );
      expect(binary.size, 3);
      if (!Platform.isWindows) {
        final link = plan.singleWhere(
          (entry) => entry.kind == TreeEntryKind.link,
        );
        expect(link.linkTarget, '.');
      }
    },
  );

  test('link upload uses target content and stages before rename', () async {
    final job = FileJob('link', '/target/link', (_) async {}, {});
    await tree.run(
      [
        const TreeEntry(
          'local-link',
          '/target/link',
          TreeEntryKind.link,
          0,
          null,
          linkTarget: '../outside',
        ),
      ],
      upload: true,
      job: job,
      resolve: (_, _) async => null,
      changed: () {},
    );
    expect(files.links['/target/link'], '../outside');
    expect(files.nodes.keys, ['/target/link']);
  });

  test(
    'download plan includes link itself and does not traverse outside source',
    () async {
      files.nodes.addAll({
        '/root': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
        '/root/empty': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
        '/root/link': SftpFileAttrs(mode: SftpFileMode.value(0xa000)),
        '/root/data': SftpFileAttrs(
          mode: SftpFileMode.value(0x8000),
          size: 7,
          modifyTime: 5,
        ),
        '/outside/keep': SftpFileAttrs(size: 99),
      });
      files.links['/root/link'] = '/outside';
      final plan = await tree.planDownload(
        '/root',
        temporary.path,
        TransferControl(),
      );
      expect(plan, hasLength(4));
      expect(
        plan
            .singleWhere((entry) => entry.kind == TreeEntryKind.link)
            .linkTarget,
        '/outside',
      );
      expect(plan.every((entry) => entry.source.startsWith('/root')), isTrue);
    },
  );

  test(
    'directory merge refuses a symlink target and leaves it intact',
    () async {
      final source = await Directory('${temporary.path}/empty').create();
      files.nodes['/target'] = SftpFileAttrs(mode: SftpFileMode.value(0xa000));
      final plan = await tree.planUpload(
        source.path,
        '/target',
        TransferControl(),
      );
      final job = FileJob('upload', '/target', (_) async {}, {});
      await expectLater(
        tree.run(
          plan,
          upload: true,
          job: job,
          resolve: (_, _) async => null,
          changed: () {},
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(files.nodes['/target']!.isSymbolicLink, isTrue);
      expect(files.removed, isEmpty);
    },
  );

  test(
    'skip decisions count once and remain skipped when retrying remaining entries',
    () async {
      final file = await File('${temporary.path}/data').writeAsBytes([1, 2]);
      final plan = await tree.planUpload(
        file.path,
        '/target',
        TransferControl(),
      );
      files.nodes['/target'] = SftpFileAttrs(
        mode: SftpFileMode.value(0x8000),
        size: 8,
      );
      var conflicts = 0;
      final job = FileJob('upload', '/target', (_) async {}, {});
      Future<void> run() => tree.run(
        plan,
        upload: true,
        job: job,
        resolve: (_, _) async {
          conflicts++;
          return null;
        },
        changed: () {},
      );
      await run();
      await file.writeAsString("already handled source changed");
      await run();
      expect(conflicts, 1);
      expect(job.completedFiles, 1);
      expect(job.control.bytes, 2);
      expect(files.nodes['/target']!.size, 8);
    },
  );

  test('changed source fails before replacing the destination', () async {
    final source = await File(
      '${temporary.path}/data',
    ).writeAsString('original');
    final plan = await tree.planUpload(
      source.path,
      '/target',
      TransferControl(),
    );
    await source.writeAsString('changed longer content');
    final job = FileJob('upload', '/target', (_) async {}, {});
    await expectLater(
      tree.run(
        plan,
        upload: true,
        job: job,
        resolve: (_, _) async => throw StateError('must not resolve'),
        changed: () {},
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(files.nodes, isEmpty);
  });
}
