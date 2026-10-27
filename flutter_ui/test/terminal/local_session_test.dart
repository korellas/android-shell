// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/terminal/local_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'drains output before final codec close and ignores old generation',
    () async {
      final events = StreamController<dynamic>.broadcast(sync: true);
      final calls = <String>[];
      final runtimeIds = <String>[];
      final blocked = Completer<void>();
      var first = true;
      final session = AppLocalSession(
        id: 7,
        prepared: {'host': {}, 'profile': {}},
        events: events.stream,
        onChanged: () {},
        platform: (method, args) async {
          calls.add(method);
          if (method == 'local.start') runtimeIds.add(args['id'] as String);
          if (method == 'ssh.decode') {
            if (first && args['final'] == false) {
              first = false;
              await blocked.future;
            }
            return utf8.decode((args['bytes'] as List).cast<int>());
          }
          if (method == 'ssh.encode') {
            return Uint8List.fromList(utf8.encode(args['text'] as String));
          }
          return null;
        },
      );
      await session.connect();
      final terminal = session.terminal;
      events.add({
        'id': runtimeIds.last,
        'type': 'output',
        'bytes': utf8.encode('https://example.com'),
      });
      events.add({'id': runtimeIds.last, 'type': 'exit', 'exitCode': 0});
      await Future<void>.delayed(Duration.zero);
      expect(calls.where((call) => call == 'ssh.closeCodec'), isEmpty);
      blocked.complete();
      await session.disconnect();
      expect(session.ended, isTrue);
      expect(await session.invoke('session.urls', {}), ['https://example.com']);
      await session.reconnect();
      expect(identical(terminal, session.terminal), isTrue);
      expect(runtimeIds[0], isNot(runtimeIds[1]));
      events.add({
        'id': runtimeIds.first,
        'type': 'output',
        'bytes': utf8.encode('https://stale.com'),
      });
      expect(await session.invoke('session.urls', {}), isEmpty);
      await session.dispose();
      await events.close();
    },
  );
  test(
    'encodes text in input order and starts configured local automation',
    () async {
      final events = StreamController<dynamic>.broadcast();
      final writes = <String>[];
      final session = AppLocalSession(
        id: 1,
        prepared: {
          'host': {'postLogin': 'login'},
          'profile': {},
          'automation': [
            {'type': 'SEND_TEXT', 'text': 'auto'},
          ],
        },
        events: events.stream,
        onChanged: () {},
        platform: (method, args) async {
          if (method == 'ssh.encode') {
            return Uint8List.fromList(utf8.encode(args['text'] as String));
          }
          if (method == 'ssh.decode') return '';
          if (method == 'local.write') {
            writes.add(utf8.decode((args['bytes'] as List).cast<int>()));
          }
          return null;
        },
      );
      await session.connect();
      await Future<void>.delayed(Duration.zero);
      await Future.wait([
        session.invoke('session.sendText', {'text': 'one'}),
        session.invoke('session.sendText', {'text': 'two'}),
      ]);
      expect(writes, ['login', 'auto', 'one', 'two']);
      await session.dispose();
      await events.close();
    },
  );
}
