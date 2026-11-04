// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../main.dart' show showErrorDetails;
import '../tilde_design.dart';
import '../tilde_controls.dart';
import 'file_job_queue.dart';
import 'transfer_progress.dart';
import 'transfer.dart';
import '../l10n/strings.dart';

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
          context.l10n.active(
            (queue.jobs
                    .where((job) => job.state == FileJobState.running)
                    .length)
                .toString(),
          ),
        if (pending > 0) context.l10n.queued((pending).toString()),
        if (failed > 0) context.l10n.failed((failed).toString()),
        if (done > 0) context.l10n.completed((done).toString()),
        if (queue.jobs.any((job) => job.state == FileJobState.cancelled))
          context.l10n.cancelled(
            (queue.jobs
                    .where((job) => job.state == FileJobState.cancelled)
                    .length)
                .toString(),
          ),
      ];
      final summary = parts.isEmpty
          ? context.l10n.noTransfers
          : parts.join(' · ');
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
            FileJobState.pending => context.l10n.queued2,
            FileJobState.running =>
              job.control.paused
                  ? context.l10n.paused
                  : context.l10n.inProgress,
            FileJobState.succeeded => context.l10n.completed2,
            FileJobState.failed => context.l10n.failed2,
            FileJobState.cancelled => context.l10n.cancel,
          };
          final actions = Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              if (running)
                TextButton(
                  onPressed: () {
                    job.control.paused
                        ? job.control.resume()
                        : job.control.pause();
                    queue.changed();
                  },
                  child: Text(
                    job.control.paused
                        ? context.l10n.continueAction
                        : context.l10n.paused,
                  ),
                ),
              if (running || job.state == FileJobState.pending)
                IconButton(
                  tooltip: context.l10n.cancelOperation,
                  onPressed: () => queue.cancel(job),
                  icon: const Icon(Icons.close),
                ),
              if (job.state == FileJobState.succeeded && job.reveal != null)
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
                  child: Text(context.l10n.openFolder),
                ),
              if (job.retryable &&
                  (job.state == FileJobState.failed ||
                      job.state == FileJobState.cancelled))
                TextButton(
                  onPressed: () => queue.retry(job),
                  child: Text(context.l10n.retry),
                ),
              if (job.error != null)
                IconButton(
                  tooltip: context.l10n.errorDetails,
                  icon: const Icon(Icons.info_outline, size: 18),
                  onPressed: () => showErrorDetails(
                    context,
                    job.error!,
                    summary: context.l10n.couldNotComplete(
                      (job.label).toString(),
                    ),
                    target: job.target,
                    retry: job.retryable
                        ? () async {
                            queue.retry(job);
                          }
                        : null,
                  ),
                ),
            ],
          );
          final name = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              tildePathText(
                job.target,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: tildeMono,
                  fontFamilyFallback: tildeMonoFallback,
                ),
              ),
            ],
          );
          final status = Text(
            job.error == null ? state : fileFailureSummary(job.error!),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: job.error == null
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
          );
          final progress = running
              ? TransferProgress(
                  status: context.l10n.items2(
                    (job.completedFiles).toString(),
                    (job.totalFiles).toString(),
                    (job.detail.isEmpty ? '' : ' · ${job.detail}').toString(),
                  ),
                  control: job.control,
                  startedAt: job.startedAt,
                )
              : const SizedBox.shrink();
          return LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  pointer &&
                  constraints.maxWidth >= 800 &&
                  MediaQuery.textScalerOf(context).scale(14) < 22;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    if (compact)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            job.error != null
                                ? Icons.error_outline
                                : job.state == FileJobState.succeeded
                                ? Icons.check_circle_outline
                                : Icons.sync,
                            size: 22,
                            color: job.error != null
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(flex: 3, child: name),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: status),
                          const SizedBox(width: 16),
                          SizedBox(width: 200, child: progress),
                          const SizedBox(width: 12),
                          SizedBox(width: 170, child: actions),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          name,
                          const SizedBox(height: 4),
                          status,
                          actions,
                          progress,
                        ],
                      ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                  ],
                ),
              );
            },
          );
        },
      );
      return Column(
        mainAxisSize: widget.fullPage ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.fullPage) const Divider(height: 1),
          ListTile(
            dense: pointer,
            title: Text(context.l10n.transfer((summary).toString())),
            subtitle: !expanded && active != null
                ? Text(
                    '${active.label} · ${formatBytes(active.control.bytes)} / ${active.control.total == null ? context.l10n.checkingSize : formatBytes(active.control.total!)}',
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
                      appBar: AppBar(title: Text(context.l10n.transferQueue)),
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
                    child: Text(context.l10n.clearCompleted),
                  ),
                if (!widget.fullPage)
                  IconButton(
                    tooltip: expanded
                        ? context.l10n.collapseTransferQueue
                        : context.l10n.expandTransferQueue,
                    onPressed: () {
                      if (pointer) {
                        setState(() => _expanded = !expanded);
                      } else {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: Text(context.l10n.transferQueue),
                              ),
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
                            null => context.l10n.all,
                            FileJobState.pending => context.l10n.queued2,
                            FileJobState.running => context.l10n.progress,
                            FileJobState.succeeded => context.l10n.completed2,
                            FileJobState.failed => context.l10n.failed2,
                            FileJobState.cancelled => context.l10n.cancel,
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
