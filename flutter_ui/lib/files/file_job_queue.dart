// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'transfer.dart';

enum FileJobState { pending, running, succeeded, failed, cancelled }

class FileJob {
  FileJob(this.label, this.target, this.run, this.paths, {this.reveal});
  final Future<void> Function()? reveal;
  bool retryable = true;
  final String label, target;
  final Future<void> Function(FileJob) run;
  final Set<String> paths;
  FileJobState state = FileJobState.pending;
  TransferControl control = TransferControl();
  DateTime? startedAt;
  Object? error;
  String detail = '';
  int completedFiles = 0, totalFiles = 0;
  final Set<String> completedPaths = {};
  Completer<void> _completion = Completer<void>();
  Future<void> wait() async {
    await _completion.future;
    if (error != null) throw error!;
    if (state == FileJobState.cancelled) throw TransferCancelled();
  }
}

class FileJobQueue extends ChangeNotifier {
  final jobs = <FileJob>[];
  Future<void>? _pump;
  bool _disposed = false;
  FileJob add(
    String label,
    String target,
    Future<void> Function(FileJob) run, {
    Set<String> paths = const {},
    bool retryable = true,
    Future<void> Function()? reveal,
  }) {
    final job = FileJob(label, target, run, {...paths, target}, reveal: reveal);
    job.retryable = retryable;
    jobs.add(job);
    changed();
    _start();
    return job;
  }

  bool get busy => jobs.any(
    (job) =>
        job.state == FileJobState.pending || job.state == FileJobState.running,
  );
  bool locks(String path) => jobs
      .where(
        (job) =>
            job.state == FileJobState.pending ||
            job.state == FileJobState.running,
      )
      .any(
        (job) => job.paths.any(
          (other) =>
              path == other ||
              path.startsWith('$other/') ||
              other.startsWith(path.endsWith('/') ? path : '$path/'),
        ),
      );
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void _start() {
    _pump ??= Future<void>.microtask(_drain).whenComplete(() {
      _pump = null;
      if (!_disposed && busy) _start();
    });
  }

  Future<void> _drain() async {
    while (!_disposed) {
      final pending = jobs.where((job) => job.state == FileJobState.pending);
      if (pending.isEmpty) break;
      final job = pending.first;
      job.state = FileJobState.running;
      job.startedAt = DateTime.now();
      changed();
      try {
        await job.run(job);
        job.state = FileJobState.succeeded;
      } on TransferCancelled {
        job.state = FileJobState.cancelled;
      } catch (error) {
        job.error = error;
        job.state = FileJobState.failed;
      }
      if (!job._completion.isCompleted) job._completion.complete();
      changed();
    }
  }

  Future<void> get drained async {
    while (_pump != null) {
      await _pump;
    }
  }

  void cancel(FileJob job) {
    job.control.cancel();
    if (job.state == FileJobState.pending) {
      job.state = FileJobState.cancelled;
      job._completion.complete();
    }
    changed();
  }

  void retry(FileJob job) {
    if (!job.retryable ||
        (job.state != FileJobState.failed &&
            job.state != FileJobState.cancelled)) {
      return;
    }
    job.error = null;
    job.control = TransferControl();
    job._completion = Completer<void>();
    job.state = FileJobState.pending;
    changed();
    _start();
  }

  void clearFinished() {
    jobs.removeWhere((job) => job.state == FileJobState.succeeded);
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final job in jobs) {
      cancel(job);
    }
    super.dispose();
  }
}
