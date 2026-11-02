// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:android_shell_ui/files/file_job_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('jobs retain targets, run in order and retry failures only', () async {
    final queue = FileJobQueue();
    addTearDown(queue.dispose);
    final gate = Completer<void>();
    final ran = <String>[];
    final first = queue.add('first', '/A/file', (job) async {
      await gate.future;
      ran.add(job.target);
    });
    var attempts = 0;
    final second = queue.add('second', '/B/file', (job) async {
      if (++attempts == 1) throw StateError('offline');
      ran.add(job.target);
    });
    await Future<void>.delayed(Duration.zero);
    expect(first.state, FileJobState.running);
    expect(second.state, FileJobState.pending);
    expect(queue.locks('/A'), isTrue);
    gate.complete();
    await queue.drained;
    expect(first.state, FileJobState.succeeded);
    expect(second.state, FileJobState.failed);
    queue.retry(second);
    await queue.drained;
    expect(ran, ['/A/file', '/B/file']);
    expect(attempts, 2);
  });
  test(
    'pending cancellation does not run and pause gates active work',
    () async {
      final queue = FileJobQueue();
      addTearDown(queue.dispose);
      var didRun = false;
      final gate = Completer<void>();
      final first = queue.add('first', '/A', (job) async {
        await gate.future;
        await job.control.ready;
      });
      final second = queue.add('second', '/B', (_) async {
        didRun = true;
      });
      queue.cancel(second);
      await Future<void>.delayed(Duration.zero);
      first.control.pause();
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(first.state, FileJobState.running);
      first.control.cancel();
      await queue.drained;
      expect(first.state, FileJobState.cancelled);
      expect(didRun, isFalse);
    },
  );
}
