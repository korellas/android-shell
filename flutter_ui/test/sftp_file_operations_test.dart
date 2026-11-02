// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/files/sftp_file_operations.dart';
import 'package:android_shell_ui/files/transfer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFiles implements SftpClient {
  final nodes = <String, SftpFileAttrs>{};
  final removed = <String>[];
  bool? followedLink;
  String? denied;
  bool? allowedOverwrite;
  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) async {
    followedLink = followLink;
    final node = nodes[path];
    if (node == null) {
      throw SftpStatusError(SftpStatusCode.noSuchFile, 'missing');
    }
    return node;
  }

  @override
  Future<List<SftpName>> listdir(String path) async => [
    SftpName(filename: '.', longname: '', attr: SftpFileAttrs()),
    SftpName(filename: '..', longname: '', attr: SftpFileAttrs()),
    for (final node in nodes.entries)
      if (node.key.startsWith('$path/') &&
          !node.key.substring(path.length + 1).contains('/'))
        SftpName(
          filename: node.key.substring(path.length + 1),
          longname: '',
          attr: node.value,
        ),
  ];
  @override
  Future<void> remove(String path) async {
    if (path == denied) throw StateError('permission denied');
    removed.add(path);
    nodes.remove(path);
  }

  @override
  Future<void> rmdir(String path) => remove(path);
  @override
  Future<void> rename(
    String oldPath,
    String newPath, {
    bool overwrite = true,
  }) async {
    allowedOverwrite = overwrite;
    nodes[newPath] = nodes.remove(oldPath)!;
  }

  @override
  Future<void> mkdir(String path, [SftpFileAttrs? attrs]) async {
    nodes[path] = SftpFileAttrs(mode: SftpFileMode.value(0x4000));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFiles files;
  late SftpFileOperations operations;
  setUp(() {
    files = FakeFiles();
    operations = SftpFileOperations(files);
  });
  test('rename refuses existing names including dangling links', () async {
    files.nodes['/home/old'] = SftpFileAttrs();
    files.nodes['/home/taken'] = SftpFileAttrs(
      mode: SftpFileMode.value(0xa000),
    );
    await expectLater(
      operations.rename('/home', 'old', 'taken'),
      throwsStateError,
    );
    expect(files.nodes.keys, containsAll(['/home/old', '/home/taken']));
    expect(files.followedLink, isFalse);
    await operations.rename('/home', 'old', '한글 새 이름');
    expect(files.nodes.keys, contains('/home/한글 새 이름'));
    expect(files.allowedOverwrite, isFalse);
  });
  test(
    'move preserves contents and refuses existing or descendant targets',
    () async {
      files.nodes['/source'] = SftpFileAttrs(size: 12);
      files.nodes['/taken'] = SftpFileAttrs(size: 99);
      await expectLater(
        operations.move('/source', '/source/child'),
        throwsStateError,
      );
      await expectLater(operations.move('/source', '/taken'), throwsStateError);
      await operations.move('/source', '/destination');
      expect(files.nodes['/destination']!.size, 12);
      expect(files.nodes['/taken']!.size, 99);
      expect(files.allowedOverwrite, isFalse);
    },
  );
  test('invalid names fail before making requests', () async {
    for (final name in ['', '.', '..', 'a/b', r'a\b', '\x00']) {
      expect(remoteNameError(name), isNotNull);
      await expectLater(
        operations.createDirectory('/home', name),
        throwsArgumentError,
      );
    }
    expect(files.nodes, isEmpty);
    await operations.createDirectory('/home', '새 폴더');
    expect(files.nodes['/home/새 폴더']!.isDirectory, isTrue);
  });
  test(
    'recursive delete removes children first and unlinks symlinks only',
    () async {
      files.nodes.addAll({
        '/home/folder': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
        '/home/folder/sub': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
        '/home/folder/sub/data': SftpFileAttrs(),
        '/home/folder/link': SftpFileAttrs(mode: SftpFileMode.value(0xa000)),
        '/outside/keep': SftpFileAttrs(),
      });
      final counts = <int>[];
      await operations.delete(
        '/home/folder',
        control: TransferControl(),
        onDeleted: counts.add,
      );
      expect(
        files.removed.indexOf('/home/folder/sub/data'),
        lessThan(files.removed.indexOf('/home/folder/sub')),
      );
      expect(files.removed.last, '/home/folder');
      expect(files.nodes.keys, ['/outside/keep']);
      expect(counts, [1, 2, 3, 4]);
      expect(files.followedLink, isFalse);
    },
  );
  test('delete returns the count without a progress callback', () async {
    files.nodes['/folder'] = SftpFileAttrs(mode: SftpFileMode.value(0x4000));
    expect(await operations.delete('/folder', control: TransferControl()), 1);
  });
  test('cancellation stops before deleting further entries', () async {
    files.nodes.addAll({
      '/folder': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
      '/folder/a': SftpFileAttrs(),
      '/folder/b': SftpFileAttrs(),
    });
    final control = TransferControl();
    await expectLater(
      operations.delete(
        '/folder',
        control: control,
        onDeleted: (_) => control.cancel(),
      ),
      throwsA(isA<TransferCancelled>()),
    );
    expect(files.removed, ['/folder/a']);
    expect(files.nodes.keys, containsAll(['/folder', '/folder/b']));
  });
  test('permission error preserves the containing directory', () async {
    files.nodes.addAll({
      '/folder': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
      '/folder/a': SftpFileAttrs(),
    });
    files.denied = '/folder/a';
    await expectLater(
      operations.delete('/folder', control: TransferControl()),
      throwsStateError,
    );
    expect(files.nodes.keys, containsAll(['/folder', '/folder/a']));
  });
}
