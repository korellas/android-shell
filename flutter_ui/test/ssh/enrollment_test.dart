// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/ssh/enrollment.dart';
import 'package:android_shell_ui/ssh/ssh_session.dart';

void main() {
  test('registration script is idempotent and refuses symlinks', () async {
    final home = await Directory.systemTemp.createTemp('ssh-enrollment-test-');
    try {
      Future<SshCommandResult> execute(String command) async {
        final result = await Process.run(
          'sh',
          ['-c', command],
          environment: {'HOME': home.path},
        );
        return SshCommandResult(
          Uint8List.fromList(utf8.encode(result.stdout as String)),
          Uint8List.fromList(utf8.encode(result.stderr as String)),
          result.exitCode,
        );
      }

      const key = "ssh-ed25519 AAAA test's key";
      expect(await registerEnrollmentPublicKey(execute, key), 'ADDED');
      expect(
        await registerEnrollmentPublicKey(execute, key),
        'ALREADY_PRESENT',
      );
      final file = File('${home.path}/.ssh/authorized_keys');
      expect(await file.readAsString(), '$key\n');
      await file.delete();
      final outside = File('${home.path}/outside')
        ..writeAsStringSync('preserve');
      await Link(file.path).create(outside.path);
      await expectLater(
        registerEnrollmentPublicKey(execute, key),
        throwsStateError,
      );
      expect(await outside.readAsString(), 'preserve');
    } finally {
      await home.delete(recursive: true);
    }
  });

  test(
    'verification failure and address changes never apply login settings',
    () async {
      var currentHost = <String, dynamic>{
        'id': 1,
        'hostname': 'example',
        'port': 22,
        'jumpHostId': 2,
        'identityId': 9,
      };
      final saved = <Map<String, dynamic>>[];
      final controller = SshEnrollmentController(
        onChanged: () {},
        keys: () => [
          {'id': 3, 'nickname': 'key'},
        ],
        biometricAvailable: () => false,
        createBiometricKey: (_) async => throw StateError('unexpected'),
        readHost: (_) async => currentHost,
        saveHost: (host) async {
          saved.add(host);
        },
      );
      Future<void> enroll(String verification) => controller.enroll(
        originalHost: {
          'id': 1,
          'hostname': 'example',
          'port': 22,
          'jumpHostId': 2,
        },
        canEnroll: () => true,
        register: (_) async => 'ADDED',
        verify: (_) async => verification,
        username: 'user',
        keyId: 3,
      );
      controller.begin('key');
      await enroll('INDETERMINATE');
      expect(saved, isEmpty);
      expect(controller.state['stage'], 'FAILED');
      expect(controller.state['error'], contains('additional authentication'));
      controller.begin('key');
      currentHost = {...currentHost, 'jumpHostId': 4};
      await enroll('VERIFIED');
      expect(saved, isEmpty);
      expect(controller.state['error'], contains('address changed'));
      controller.begin('key');
      currentHost = {...currentHost, 'jumpHostId': 2};
      await enroll('VERIFIED');
      expect(controller.state['stage'], 'SUCCESS');
      expect(saved.single, containsPair('pubkeyId', 3));
      expect(saved.single['identityId'], isNull);
      expect(saved.single['username'], 'user');
    },
  );
  test(
    'stale registration and disconnect during host read cannot apply settings',
    () async {
      var valid = true;
      var verified = false;
      var saved = false;
      final reading = Completer<void>();
      final hostResult = Completer<Map<String, dynamic>?>();
      final controller = SshEnrollmentController(
        onChanged: () {},
        keys: () => [
          {'id': 3},
        ],
        biometricAvailable: () => false,
        createBiometricKey: (_) async => throw StateError('unexpected'),
        readHost: (_) {
          reading.complete();
          return hostResult.future;
        },
        saveHost: (_) async {
          saved = true;
        },
      );
      const host = <String, dynamic>{
        'id': 1,
        'hostname': 'example',
        'port': 22,
      };
      controller.begin('key');
      await controller.enroll(
        originalHost: host,
        canEnroll: () => valid,
        register: (_) async {
          valid = false;
          return 'ADDED';
        },
        verify: (_) async {
          verified = true;
          return 'VERIFIED';
        },
        username: 'user',
        keyId: 3,
      );
      expect(verified, isFalse);
      expect(saved, isFalse);
      expect(controller.state['stage'], 'FAILED');
      valid = true;
      controller.begin('key');
      final pending = controller.enroll(
        originalHost: host,
        canEnroll: () => valid,
        register: (_) async => 'ADDED',
        verify: (_) async => 'VERIFIED',
        username: 'user',
        keyId: 3,
      );
      await reading.future;
      valid = false;
      hostResult.complete(host);
      await pending;
      expect(saved, isFalse);
      expect(controller.state['stage'], 'FAILED');
    },
  );
}
