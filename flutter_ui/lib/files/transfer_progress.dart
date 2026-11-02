// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import 'transfer.dart';

class TransferProgress extends StatelessWidget {
  const TransferProgress({
    super.key,
    required this.status,
    required this.control,
    this.startedAt,
  });
  final String status;
  final TransferControl control;
  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final total = control.total;
    final fraction = total == null
        ? null
        : total == 0
        ? 1.0
        : (control.bytes / total).clamp(0.0, 1.0);
    final elapsed = startedAt == null
        ? 0.0
        : DateTime.now().difference(startedAt!).inMilliseconds / 1000;
    final speed = elapsed > 0 ? control.bytes / elapsed : 0.0;
    final remaining = total == null || speed <= 0
        ? null
        : ((total - control.bytes).clamp(0, total) / speed).ceil();
    final timing = remaining == null
        ? '남은 시간 계산 중'
        : remaining >= 60
        ? '${remaining ~/ 60}분 ${remaining % 60}초 남음'
        : '$remaining초 남음';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                control.cancelled ? '$status · 취소 중…' : status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: fraction),
              const SizedBox(height: 10),
              Text(
                '${formatBytes(control.bytes)} / ${total == null ? '크기 확인 중' : formatBytes(total)}${fraction == null ? '' : ' · ${(fraction * 100).floor()}%'}',
              ),
              Text(
                '${speed > 0 ? '${formatBytes(speed.round())}/s' : '속도 계산 중'} · $timing',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
