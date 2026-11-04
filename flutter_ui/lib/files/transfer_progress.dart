// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'transfer.dart';
import '../l10n/strings.dart';

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
        ? context.l10n.calculatingTimeRemaining
        : remaining >= 60
        ? context.l10n.minutesSecondsRemaining(
            (remaining ~/ 60).toString(),
            (remaining % 60).toString(),
          )
        : context.l10n.secondsRemaining((remaining).toString());
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [
              if (status.isNotEmpty) status,
              if (control.cancelled) context.l10n.cancellingOperation,
              speed > 0
                  ? '${formatBytes(speed.round())}/s'
                  : context.l10n.calculatingSpeed,
              timing,
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 6),
          Text(
            '${formatBytes(control.bytes)} / ${total == null ? context.l10n.checkingSize : formatBytes(total)}${fraction == null ? '' : ' · ${(fraction * 100).floor()}%'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
