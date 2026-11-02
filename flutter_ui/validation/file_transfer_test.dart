// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/files/sftp_transfer.dart';
import 'package:android_shell_ui/files/transfer.dart';
import 'package:android_shell_ui/ssh/app_session.dart';

void main() {
  final configFile = Platform.environment['TILDE_SSH_TEST_CONFIG'];
  group(
    'file mode through existing Tilde authentication',
    skip: configFile == null
        ? 'Set TILDE_SSH_TEST_CONFIG for a local SFTP fixture.'
        : false,
    () {
      late Directory root, local;
      late AppSshSession session;
      late SftpClient files;
      late SftpTransfer connection;
      setUp(() async {
        final config =
            jsonDecode(await File(configFile!).readAsString())
                as Map<String, dynamic>;
        final key = SSHKeyPair.fromPem(
          await File(config['keyFile'] as String).readAsString(),
        ).single;
        root = await Directory.systemTemp.createTemp('tilde-remote-');
        local = await Directory.systemTemp.createTemp('tilde-local-');
        var trusted = false;
        session = AppSshSession(
          id: 21,
          prepared: {
            'host': {
              'id': 1,
              'protocol': 'ssh',
              'hostname': config['host'],
              'port': config['port'],
              'username': config['username'],
              'wantSession': false,
            },
            'profile': {'encoding': 'UTF-8'},
            'keys': [
              {'id': 7, 'nickname': 'test key'},
            ],
          },
          onChanged: () {},
          loadStoredIdentities: ({required id}) async {
            expect(trusted, isTrue);
            return [key];
          },
          platform: (method, args) async {
            switch (method) {
              case 'ssh.checkHost':
                expect(args['fingerprint'], config['fingerprint']);
                trusted = true;
                return {'status': 'match'};
              case 'ssh.decode':
                return '';
              case 'ssh.encode':
                return Uint8List(0);
              case 'ssh.closeCodec':
                return null;
              default:
                throw StateError(method);
            }
          },
        );
        await session.connect();
        expect(session.connected, isTrue);
        expect(session.sessionOpen, isFalse);
        files = await session.openSftp();
        connection = SftpTransfer(files: files, openChannel: session.openSftp);
      });
      tearDown(() async {
        await session.dispose();
        await root.delete(recursive: true);
        await local.delete(recursive: true);
      });
      Future<List<SftpName>> listFiles() async =>
          (await files.listdir(root.path))
              .where((entry) => entry.filename != '.' && entry.filename != '..')
              .toList();

      test(
        'key login, binary upload, listing, and download round trip',
        () async {
          final bytes = Uint8List.fromList(
            List.generate(1048601, (i) => i % 251),
          );
          final source = await File(
            '${local.path}/한글 공백 ; literal.bin',
          ).writeAsBytes(bytes);
          final remote = '${root.path}/${fileName(source.path)}';
          final uploadProgress = <int>[];
          await connection.upload(
            source,
            remote,
            control: TransferControl(),
            onProgress: uploadProgress.add,
          );
          expect(await File(remote).readAsBytes(), bytes);
          expect(uploadProgress.last, bytes.length);
          final entries = await listFiles();
          expect(entries.single.filename, fileName(source.path));
          final destination = File('${local.path}/received.bin');
          await connection.download(
            remote,
            destination,
            control: TransferControl(),
          );
          expect(await destination.readAsBytes(), bytes);
          expect(await root.list().length, 1);
        },
      );

      test(
        'upload requires overwrite approval and then replaces contents',
        () async {
          final remote = await File(
            '${root.path}/existing',
          ).writeAsString('original');
          final source = await File(
            '${local.path}/source',
          ).writeAsString('replacement');
          await expectLater(
            connection.upload(source, remote.path, control: TransferControl()),
            throwsA(isA<FileSystemException>()),
          );
          expect(await remote.readAsString(), 'original');
          await connection.upload(
            source,
            remote.path,
            control: TransferControl(),
            overwrite: true,
          );
          expect(await remote.readAsString(), 'replacement');
          expect(await root.list().length, 1);
        },
      );

      test('uploads a long valid filename', () async {
        final name = '${List.filled(240, 'a').join()}.bin';
        final source = await File(
          '${local.path}/$name',
        ).writeAsString('complete');
        final destination = '${root.path}/$name';
        await connection.upload(
          source,
          destination,
          control: TransferControl(),
        );
        expect(await File(destination).readAsString(), 'complete');
        expect(await root.list().length, 1);
      });

      test(
        'cancelled upload keeps existing contents and removes staging file',
        () async {
          final remote = await File(
            '${root.path}/existing',
          ).writeAsString('original');
          final source = await File(
            '${local.path}/source',
          ).writeAsBytes(Uint8List(8 * 1024 * 1024));
          final control = TransferControl();
          await expectLater(
            connection.upload(
              source,
              remote.path,
              control: control,
              overwrite: true,
              onProgress: (_) => control.cancel(),
            ),
            throwsA(isA<TransferCancelled>()),
          );
          expect(await remote.readAsString(), 'original');
          expect(await root.list().length, 1);
          expect((await listFiles()).single.filename, 'existing');
        },
      );

      test(
        'cancelled download preserves local destination and connection',
        () async {
          final source = await File(
            '${root.path}/source',
          ).writeAsBytes(Uint8List(8 * 1024 * 1024));
          final destination = await File(
            '${local.path}/existing',
          ).writeAsString('original');
          final control = TransferControl();
          await expectLater(
            connection.download(
              source.path,
              destination,
              control: control,
              overwrite: true,
              onProgress: (_) => control.cancel(),
            ),
            throwsA(isA<TransferCancelled>()),
          );
          expect(await destination.readAsString(), 'original');
          expect(await local.list().length, 1);
          expect((await listFiles()).single.filename, 'source');
        },
      );
    },
  );
}
