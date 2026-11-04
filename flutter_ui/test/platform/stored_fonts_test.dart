// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:android_shell_ui/platform/stored_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('tilde-fonts-'),
  );
  tearDown(() async => directory.delete(recursive: true));
  StoredPlatform create(String platform) => StoredPlatform(
    file: File('${directory.path}/state.json'),
    platform: platform,
    native: (_, _) async => null,
    protect: (bytes) async => bytes,
    unprotect: (bytes) async => bytes,
  );
  for (final platform in ['ios', 'windows']) {
    test(
      '$platform defaults to bundled D2Coding and retains JetBrains Mono',
      () async {
        final store = create(platform);
        final snapshot = await store.call('snapshot', {}) as Map;
        expect(snapshot['preferences']['fontFamily'], 'D2CODING');
        expect(
          snapshot['preferences']['fonts'],
          containsAll([
            {'value': 'D2CODING', 'label': 'D2Coding'},
            {'value': 'JETBRAINS_MONO', 'label': 'JetBrains Mono'},
          ]),
        );
        expect(await store.call('font.bytes', {'name': 'D2CODING'}), {
          'family': 'D2Coding',
        });
        expect(await store.call('font.bytes', {'name': 'JETBRAINS_MONO'}), {
          'family': 'JetBrainsMono',
        });
        expect(await store.call('font.bytes', {'name': 'JetBrainsMono'}), {
          'family': 'JetBrainsMono',
        });
      },
    );
    test(
      '$platform font selection persists and reaches new SSH sessions',
      () async {
        final store = create(platform);
        final host =
            await store.call('host.save', {
                  'nickname': 'test',
                  'hostname': 'server.test',
                  'username': 'alice',
                })
                as Map;
        for (final font in ['JETBRAINS_MONO', 'D2CODING']) {
          await store.call('settings.update', {
            'key': 'fontFamily',
            'value': font,
          });
          final reopened = create(platform);
          final prepared =
              await reopened.call('ssh.prepare', {'id': host['id']}) as Map;
          expect(prepared['profile']['fontFamily'], font);
          expect(
            (await reopened.call('snapshot', {})
                as Map)['preferences']['fontFamily'],
            font,
          );
        }
      },
    );
    test(
      '$platform global font does not overwrite an explicit host profile',
      () async {
        final store = create(platform);
        final snapshot = await store.call('snapshot', {}) as Map;
        final profile =
            await store.call('profile.save', {
                  ...Map<String, dynamic>.from(
                    snapshot['defaults']['profile'] as Map,
                  ),
                  'id': null,
                  'name': 'English',
                  'fontFamily': 'JETBRAINS_MONO',
                })
                as Map;
        final host =
            await store.call('host.save', {
                  'nickname': 'test',
                  'hostname': 'server.test',
                  'username': 'alice',
                  'profileId': profile['id'],
                })
                as Map;
        await store.call('settings.update', {
          'key': 'fontFamily',
          'value': 'D2CODING',
        });
        final prepared =
            await store.call('ssh.prepare', {'id': host['id']}) as Map;
        expect(prepared['profile']['fontFamily'], 'JETBRAINS_MONO');
      },
    );
  }
}
