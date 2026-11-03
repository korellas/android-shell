// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import '../main.dart' show showErrorDetails;
import '../tilde_design.dart';
import 'file_job_queue.dart';
import 'transfer_progress.dart';
import 'transfer.dart';

class FileQueuePanel extends StatefulWidget {
  const FileQueuePanel({super.key, required this.queue, this.fullPage = false});
  final FileJobQueue queue;
  final bool fullPage;
  @override
  State<FileQueuePanel> createState() => _FileQueuePanelState();
}

class _FileQueuePanelState extends State<FileQueuePanel> {
  bool _expanded = false;
  FileJobState? _filter;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.queue,
    builder: (context, _) {
      final queue = widget.queue,
          pointer = tildePointer(context),
          expanded = widget.fullPage || _expanded;
      if (queue.jobs.isEmpty && !widget.fullPage) {
        return const SizedBox.shrink();
      }
      final active = queue.jobs
          .where((job) => job.state == FileJobState.running)
          .firstOrNull;
      final pending = queue.jobs
              .where((job) => job.state == FileJobState.pending)
              .length,
          failed = queue.jobs
              .where((job) => job.state == FileJobState.failed)
              .length,
          done = queue.jobs
              .where((job) => job.state == FileJobState.succeeded)
              .length;
      final parts = [
        if (active != null)
          '진행 ${queue.jobs.where((job) => job.state == FileJobState.running).length}',
        if (pending > 0) '대기 $pending',
        if (failed > 0) '실패 $failed',
        if (done > 0) '완료 $done',
        if (queue.jobs.any((job) => job.state == FileJobState.cancelled))
          '취소 ${queue.jobs.where((job) => job.state == FileJobState.cancelled).length}',
      ];
      final summary = parts.isEmpty ? '전송 없음' : parts.join(' · ');
      final jobs = queue.jobs.reversed
          .where((job) => _filter == null || job.state == _filter)
          .toList();
      final rows = ListView.builder(
        shrinkWrap: !widget.fullPage,
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          final job = jobs[index];
          final running = job.state == FileJobState.running;
          final state = switch (job.state) {
            FileJobState.pending => '대기',
            FileJobState.running => job.control.paused ? '일시정지' : '진행 중',
            FileJobState.succeeded => '완료',
            FileJobState.failed => '실패',
            FileJobState.cancelled => '취소',
          };
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${job.label} · $state',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: job.state == FileJobState.failed
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                    if (running)
                      TextButton(
                        onPressed: () {
                          job.control.paused
                              ? job.control.resume()
                              : job.control.pause();
                          queue.changed();
                        },
                        child: Text(job.control.paused ? '계속' : '일시정지'),
                      ),
                    if (running || job.state == FileJobState.pending)
                      IconButton(
                        tooltip: '작업 취소',
                        onPressed: () => queue.cancel(job),
                        icon: const Icon(Icons.close),
                      ),
                    if (job.state == FileJobState.succeeded &&
                        job.reveal != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            await job.reveal!();
                          } catch (error) {
                            if (context.mounted) {
                              await showErrorDetails(context, error);
                            }
                          }
                        },
                        child: const Text('폴더 열기'),
                      ),
                    if (job.retryable &&
                        (job.state == FileJobState.failed ||
                            job.state == FileJobState.cancelled))
                      TextButton(
                        onPressed: () => queue.retry(job),
                        child: const Text('다시 시도'),
                      ),
                  ],
                ),
                Text(
                  job.target,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: tildeMono,
                    fontFamilyFallback: tildeMonoFallback,
                  ),
                ),
                if (job.error != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          fileFailureSummary(job.error!),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => showErrorDetails(context, job.error!),
                        child: const Text('자세히'),
                      ),
                    ],
                  ),
                if (running)
                  TransferProgress(
                    status:
                        '${job.completedFiles} / ${job.totalFiles}개${job.detail.isEmpty ? '' : ' · ${job.detail}'}',
                    control: job.control,
                    startedAt: job.startedAt,
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
            ),
          );
        },
      );
      return Column(
        mainAxisSize: widget.fullPage ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (!widget.fullPage) const Divider(height: 1),
          ListTile(
            dense: pointer,
            title: Text(summary),
            subtitle: !expanded && active != null
                ? Text(
                    '${active.label} · ${formatBytes(active.control.bytes)} / ${active.control.total == null ? '크기 확인 중' : formatBytes(active.control.total!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            onTap: () {
              if (pointer) {
                setState(() => _expanded = !expanded);
              } else {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('전송 목록')),
                      body: FileQueuePanel(queue: queue, fullPage: true),
                    ),
                  ),
                );
              }
            },
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                if (expanded &&
                    queue.jobs.any(
                      (job) =>
                          job.state == FileJobState.succeeded ||
                          job.state == FileJobState.cancelled,
                    ))
                  TextButton(
                    onPressed: queue.clearFinished,
                    child: const Text('완료 지우기'),
                  ),
                if (!widget.fullPage)
                  IconButton(
                    tooltip: expanded ? '전송 목록 접기' : '전송 목록 펼치기',
                    onPressed: () {
                      if (pointer) {
                        setState(() => _expanded = !expanded);
                      } else {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('전송 목록')),
                              body: FileQueuePanel(
                                queue: queue,
                                fullPage: true,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      expanded ? Icons.expand_more : Icons.expand_less,
                    ),
                  ),
              ],
            ),
          ),
          if (!expanded && active != null)
            LinearProgressIndicator(
              value: active.control.total == null
                  ? null
                  : active.control.total == 0
                  ? 1
                  : (active.control.bytes / active.control.total!).clamp(0, 1),
            ),
          if (expanded) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final state in [
                    null,
                    for (final state in FileJobState.values)
                      if (queue.jobs.any((job) => job.state == state) ||
                          _filter == state)
                        state,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        selected: _filter == state,
                        label: Text(
                          '${switch (state) {
                            null => '전체',
                            FileJobState.pending => '대기',
                            FileJobState.running => '진행',
                            FileJobState.succeeded => '완료',
                            FileJobState.failed => '실패',
                            FileJobState.cancelled => '취소',
                          }} ${queue.jobs.where((job) => state == null || job.state == state).length}',
                        ),
                        onSelected: (_) => setState(() => _filter = state),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.fullPage)
              Expanded(child: rows)
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: rows,
              ),
          ],
        ],
      );
    },
  );
}
