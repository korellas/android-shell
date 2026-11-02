// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:android_shell_ui/engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'desktop platform uses the shared engine without Android channels',
    () async {
      final calls = <String>[];
      final engine = AndroidEngine(
        platformCall: (method, arguments) async {
          calls.add(method);
          if (method == 'snapshot') {
            return {'ready': true, 'hosts': [], 'keys': [], 'sessions': []};
          }
          return null;
        },
      );
      try {
        expect(await engine.query('snapshot'), containsPair('ready', true));
        await engine.start();
        expect(engine.ready, isTrue);
        await engine.invoke('host.save', {'hostname': 'example.test'});
        expect(calls, contains('host.save'));
      } finally {
        engine.dispose();
      }
    },
  );
}
