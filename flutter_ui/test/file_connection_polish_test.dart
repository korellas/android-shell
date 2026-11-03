// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/files/file_browser.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

class PendingFileSession extends AppSshSession {
  PendingFileSession(this.changed)
    : super(
        id: 1,
        prepared: {
          'host': {'id': 1},
        },
        platform: (_, _) async => null,
        onChanged: changed,
      );
  final VoidCallback changed;
  final pending = Completer<void>();
  bool failed = false;
  bool cancelled = false;
  @override
  bool get connected => false;
  @override
  bool get connecting => !failed && !cancelled;
  @override
  List<EngineRecord> get prompts => [];
  @override
  EngineRecord get record => {
    'connectionPhase': 'authentication',
    'connectionDurations': {'server': 20, 'hostKey': 30},
    'connectionLog': ['technical login log'],
  };
  @override
  Future<void> connect() => pending.future;
  @override
  Future<void> dispose() async {
    cancelled = true;
    if (!pending.isCompleted) pending.complete();
  }
}

class PendingFileEngine extends UiEngineFixture {
  final connections = <PendingFileSession>[];
  @override
  Future<AppSshSession> createFileConnection(
    int hostId, {
    required VoidCallback onChanged,
  }) async {
    final session = PendingFileSession(onChanged);
    connections.add(session);
    return session;
  }
}

void main() {
  testWidgets(
    'file login shows stages, hides raw logs, and retries failed sessions',
    (tester) async {
      final engine = PendingFileEngine();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidEngine.channel, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidEngine.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FileBrowserPage(
            engine: engine,
            host: const {
              'id': 1,
              'nickname': 'nas',
              'hostname': 'nas.example',
              'username': 'admin',
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('서버 찾기'), findsOneWidget);
      expect(find.text('서버 키 확인'), findsOneWidget);
      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('technical login log'), findsNothing);
      final first = engine.connections.single;
      first.failed = true;
      first.pending.completeError(StateError('technical error'));
      await tester.pumpAndSettle();
      expect(find.text('로그인하지 못했습니다'), findsOneWidget);
      expect(find.textContaining('technical error'), findsNothing);
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump();
      expect(engine.connections.length, 2);
      expect(first.cancelled, isTrue);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(engine.connections.last.cancelled, isTrue);
    },
  );
}
