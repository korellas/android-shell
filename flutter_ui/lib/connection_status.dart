// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'tilde_design.dart';
import 'l10n/strings.dart';

class ConnectionStatusView extends StatelessWidget {
  const ConnectionStatusView({
    super.key,
    required this.record,
    required this.title,
    required this.address,
    required this.finalStage,
    this.failed = false,
    this.cancelled = false,
    this.failureHint,
    this.prompt,
    required this.actions,
  });

  final Map<String, dynamic> record;
  final String title, address, finalStage;
  final bool failed, cancelled;
  final String? failureHint;
  final Widget? prompt;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    const phases = ['server', 'hostKey', 'authentication', 'ready'];
    final index = phases.indexOf(
      record['connectionPhase'] as String? ?? 'server',
    );
    final current = index < 0 ? 0 : index;
    final durations = record['connectionDurations'] as Map? ?? const {};
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                address,
                style: TextStyle(
                  fontFamily: tildeMono,
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (failureHint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(failureHint!),
                ),
              const SizedBox(height: 24),
              if (!cancelled) ...[
                for (final (i, label) in [
                  context.l10n.findServer,
                  context.l10n.verifyServerKey,
                  context.l10n.logIn,
                  finalStage,
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          i < current
                              ? Icons.check_circle_outline
                              : failed && i == current
                              ? Icons.error_outline
                              : Icons.circle_outlined,
                          size: 22,
                          color: i < current
                              ? cs.primary
                              : failed && i == current
                              ? cs.error
                              : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: i == current
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (tildePointer(context) &&
                            durations[phases[i]] is num)
                          Text(
                            context.l10n.seconds(
                              (((durations[phases[i]] as num) / 1000)
                                      .toStringAsFixed(1))
                                  .toString(),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                if (!failed)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(),
                  ),
              ],
              ?prompt,
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
