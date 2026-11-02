// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'file_job_queue.dart';
import 'transfer_progress.dart';
import 'transfer.dart';

class FileQueuePanel extends StatefulWidget {
  const FileQueuePanel({super.key, required this.queue});
  final FileJobQueue queue;
  @override
  State<FileQueuePanel> createState() => _FileQueuePanelState();
}

class _FileQueuePanelState extends State<FileQueuePanel> {
  bool? _expanded;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.queue,
    builder: (context, _) {
      final queue = widget.queue;
      final expanded = _expanded ?? MediaQuery.sizeOf(context).height >= 700;
      final active = queue.jobs
          .where((job) => job.state == FileJobState.running)
          .firstOrNull;
      final elapsed = active?.startedAt == null
          ? 0.0
          : DateTime.now().difference(active!.startedAt!).inMilliseconds / 1000;
      if (queue.jobs.isEmpty) return const SizedBox.shrink();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(
              '작업 ${queue.jobs.where((job) => job.state == FileJobState.running || job.state == FileJobState.pending).length}개 진행·대기',
            ),
            subtitle: !expanded && active != null
                ? Text(
                    '${active.label} · ${formatBytes(active.control.bytes)} / ${active.control.total == null ? "크기 확인 중" : formatBytes(active.control.total!)}${elapsed > 0 ? " · ${formatBytes((active.control.bytes / elapsed).round())}/s" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: queue.clearFinished,
                  child: const Text('완료 지우기'),
                ),
                IconButton(
                  tooltip: expanded ? '전송 목록 접기' : '전송 목록 펼치기',
                  onPressed: () => setState(() => _expanded = !expanded),
                  icon: Icon(expanded ? Icons.expand_more : Icons.expand_less),
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
                  : (active.control.bytes / active.control.total!).clamp(
                      0.0,
                      1.0,
                    ),
            ),
          if (expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: queue.jobs.length,
                itemBuilder: (context, index) {
                  final job = queue.jobs[queue.jobs.length - index - 1];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        dense: true,
                        title: Text(
                          '${job.label} · ${switch (job.state) {
                            FileJobState.pending => '대기',
                            FileJobState.running => job.control.paused ? '일시정지' : '진행 중',
                            FileJobState.succeeded => '완료',
                            FileJobState.failed => '실패',
                            FileJobState.cancelled => '취소',
                          }}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${job.target}${job.error == null ? '' : '\n${job.error}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (job.state == FileJobState.running)
                              IconButton(
                                tooltip: job.control.paused ? '계속' : '일시정지',
                                onPressed: () {
                                  job.control.paused
                                      ? job.control.resume()
                                      : job.control.pause();
                                  queue.changed();
                                },
                                icon: Icon(
                                  job.control.paused
                                      ? Icons.play_arrow
                                      : Icons.pause,
                                ),
                              ),
                            if (job.state == FileJobState.running ||
                                job.state == FileJobState.pending)
                              IconButton(
                                tooltip: '작업 취소',
                                onPressed: () => queue.cancel(job),
                                icon: const Icon(Icons.close),
                              ),
                            if (job.retryable &&
                                (job.state == FileJobState.failed ||
                                    job.state == FileJobState.cancelled))
                              IconButton(
                                tooltip: '실패·남은 항목 다시 시도',
                                onPressed: () => queue.retry(job),
                                icon: const Icon(Icons.refresh),
                              ),
                          ],
                        ),
                      ),
                      if (job.state == FileJobState.running &&
                          (job.totalFiles > 0 || job.control.total != null))
                        TransferProgress(
                          status:
                              '${job.completedFiles} / ${job.totalFiles}개 · ${job.detail}',
                          control: job.control,
                          startedAt: job.startedAt,
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}
