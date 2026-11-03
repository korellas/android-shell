// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'package:android_shell_ui/platform/stored_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tilde-schemes-test-');
  });
  tearDown(() async => directory.delete(recursive: true));
  StoredPlatform create([String platform = 'windows']) => StoredPlatform(
    file: File('${directory.path}/state.json'),
    platform: platform,
    native: (_, _) async => null,
    protect: (bytes) async => bytes,
    unprotect: (bytes) async => bytes,
  );
  for (final platform in ['windows', 'ios']) {
    test(
      '$platform theme edits and selection persist into a new SSH session',
      () async {
        final store = create(platform);
        final host =
            await store.call('host.save', {
                  'nickname': 'host',
                  'hostname': 'server.test',
                  'username': 'alice',
                })
                as Map;
        final id = await store.call('scheme.create', {
          'name': '한글 테마',
          'sourceId': -1,
        });
        await store.call('scheme.color', {
          'id': id,
          'index': 1,
          'color': 0xff123456,
        });
        await store.call('scheme.role', {
          'id': id,
          'role': 'background',
          'color': 0xff102030,
        });
        await store.call('settings.update', {
          'key': 'colorScheme',
          'value': id,
        });
        final reopened = create(platform);
        final snapshot = await reopened.call('snapshot', {}) as Map;
        expect((snapshot['profiles'] as List).single['colorSchemeId'], id);
        final prepared =
            await reopened.call('ssh.prepare', {'id': host['id']}) as Map;
        expect(prepared['scheme']['backgroundColor'], 0xff102030);
        expect(prepared['scheme']['palette'][1], 0xff123456);
        expect(prepared['host']['username'], 'alice');
      },
    );
  }
  test(
    'Android JSON colors and explicit role values survive import and export',
    () async {
      final store = create();
      final text = jsonEncode({
        'name': 'Android export',
        'description': 'interop',
        'version': 1,
        'foreground': 7,
        'background': 0,
        'foregroundColor': '#ABC',
        'backgroundColor': '112233',
        'cursorColor': '#6fd8c4',
        'colors': {
          for (var i = 0; i < 16; i++) '$i': i == 1 ? '#123456' : '#ABC',
        },
      });
      final id = await store.call('scheme.import', {'text': text});
      final exported =
          jsonDecode(await store.call('scheme.export', {'id': id}) as String)
              as Map;
      expect(exported['version'], 1);
      expect(exported['foregroundColor'], '#AABBCC');
      expect(exported['backgroundColor'], '#112233');
      expect(exported['colors']['1'], '#123456');
      final copy = await store.call('scheme.import', {
        'text': jsonEncode(exported),
      });
      final snapshot = await store.call('snapshot', {}) as Map;
      expect(
        (snapshot['schemes'] as List)
            .where((s) => s['id'] == copy)
            .single['name'],
        'Android export (1)',
      );
      expect(
        await store.call('scheme.palette', {'id': copy}),
        await store.call('scheme.palette', {'id': id}),
      );
    },
  );
  test('palette based imported roles keep following ANSI edits', () async {
    final store = create();
    final id = await store.call('scheme.import', {
      'text': jsonEncode({
        'name': 'indexed',
        'colors': {for (var i = 0; i < 16; i++) '$i': '#112233'},
      }),
    });
    await store.call('scheme.color', {
      'id': id,
      'index': 7,
      'color': 0xffabcdef,
    });
    expect(
      (await store.call('scheme.palette', {'id': id})
          as Map)['foregroundColor'],
      0xffabcdef,
    );
  });
  test(
    'duplicates are independent and built in palettes cannot be modified',
    () async {
      final store = create();
      final id = await store.call('scheme.duplicate', {
        'id': -9,
        'name': 'day copy',
      });
      final before = await store.call('scheme.palette', {'id': -9});
      await store.call('scheme.color', {
        'id': id,
        'index': 2,
        'color': 0xff010203,
      });
      await store.call('scheme.rename', {'id': id, 'name': 'renamed'});
      expect(await store.call('scheme.palette', {'id': -9}), before);
      for (final operation in [
        'scheme.delete',
        'scheme.rename',
        'scheme.color',
        'scheme.role',
      ]) {
        await expectLater(
          store.call(operation, {
            'id': -1,
            'name': 'bad',
            'index': 1,
            'role': 'cursor',
            'color': 0xff000000,
          }),
          throwsArgumentError,
        );
      }
    },
  );
  test(
    'invalid theme import changes neither saved settings nor existing themes',
    () async {
      final store = create();
      await store.call('scheme.create', {'name': 'kept', 'sourceId': -1});
      final before = await File('${directory.path}/state.json').readAsString();
      for (final invalid in [
        {
          'name': 'invalid',
          'colors': {'16': '#fff'},
        },
        {
          'name': 'invalid',
          'foreground': 99,
          'colors': {'0': '#fff'},
        },
        {
          'name': 'invalid',
          'colors': {'0': '#nothex'},
        },
        {
          'name': 'invalid',
          'version': 2,
          'colors': {'0': '#fff'},
        },
      ]) {
        await expectLater(
          store.call('scheme.import', {'text': jsonEncode(invalid)}),
          throwsFormatException,
        );
        expect(
          await File('${directory.path}/state.json').readAsString(),
          before,
        );
      }
    },
  );
  test(
    'old state without custom themes remains readable and deleting a used theme repairs profile references',
    () async {
      final store = create();
      final host =
          await store.call('host.save', {
                'nickname': 'kept',
                'hostname': 'server.test',
              })
              as Map;
      final file = File('${directory.path}/state.json');
      final legacy = jsonDecode(await file.readAsString()) as Map;
      legacy.remove('schemes');
      await file.writeAsString(jsonEncode(legacy));
      final reopened = create();
      final snapshot = await reopened.call('snapshot', {}) as Map;
      expect((snapshot['hosts'] as List).single['id'], host['id']);
      final id = await reopened.call('scheme.create', {
        'name': 'temporary',
        'sourceId': -1,
      });
      await reopened.call('settings.update', {
        'key': 'colorScheme',
        'value': id,
      });
      await reopened.call('scheme.delete', {'id': id});
      final prepared =
          await create().call('ssh.prepare', {'id': host['id']}) as Map;
      expect(prepared['profile']['colorSchemeId'], -1);
      expect(prepared['scheme']['id'], -1);
    },
  );
  test('external URL actions only forward permitted URL schemes', () async {
    final calls = <String>[];
    final store = StoredPlatform(
      file: File('${directory.path}/state.json'),
      native: (method, args) async {
        calls.add('${args['url']}');
        return null;
      },
      protect: (bytes) async => bytes,
      unprotect: (bytes) async => bytes,
    );
    await store.call('openUrl', {'url': 'https://example.test/status'});
    await expectLater(
      store.call('openUrl', {'url': 'file:///C:/Windows/System32/cmd.exe'}),
      throwsArgumentError,
    );
    expect(calls, ['https://example.test/status']);
  });
}
