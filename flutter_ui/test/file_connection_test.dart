// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/ssh/ssh_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FileTransport extends SshSession {
  FileTransport({
    required super.endpoints,
    required super.onOutput,
    required super.onState,
    required super.onError,
    required super.wantShell,
    required super.pty,
  });
  String? password;
  @override
  Future<void> connect() async {
    password = await endpoints.single.onPassword!();
    onState?.call(SshSessionState.connected);
  }

  @override
  Future<void> close() async {
    onState?.call(SshSessionState.closed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'file connection authenticates separately without a terminal or runtime session',
    () async {
      final calls = <String>[];
      FileTransport? transport;
      final engine = AndroidEngine(
        sshTransportFactory:
            ({
              required endpoints,
              required onOutput,
              required onState,
              required onError,
              required wantShell,
              required pty,
            }) => transport = FileTransport(
              endpoints: endpoints,
              onOutput: onOutput,
              onState: onState,
              onError: onError,
              wantShell: wantShell,
              pty: pty,
            ),
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Future<Object?> platform(MethodCall call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'ssh.prepare':
            return {
              'host': {
                'id': 4,
                'protocol': 'ssh',
                'hostname': 'example.test',
                'username': 'alice',
                'port': 22,
                'wantSession': true,
              },
              'password': 'saved credential',
              'keys': [],
              'profile': {'encoding': 'UTF-8'},
            };
          case 'ssh.decode':
            return '';
          case 'ssh.encode':
            return Uint8List.fromList(utf8.encode(''));
          case 'ssh.closeCodec':
            return null;
          default:
            throw StateError('Unexpected call: ${call.method}');
        }
      }

      messenger.setMockMethodCallHandler(AndroidEngine.channel, platform);
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.korellas.androidshell/runtime'),
        platform,
      );
      try {
        final connection = await engine.createFileConnection(
          4,
          onChanged: () {},
        );
        try {
          await connection.connect();
          expect(connection.connected, isTrue);
          expect(transport!.wantShell, isFalse);
          expect(transport!.password, 'saved credential');
          expect(engine.list('sessions'), isEmpty);
          expect(
            calls.where((method) => method == 'ssh.prepare'),
            hasLength(1),
          );
          expect(calls, isNot(contains('session.prepare')));
          expect(calls, isNot(contains('runtime.sessions')));
        } finally {
          await connection.dispose();
        }
      } finally {
        engine.dispose();
        messenger.setMockMethodCallHandler(AndroidEngine.channel, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.korellas.androidshell/runtime'),
          null,
        );
      }
    },
  );
}
