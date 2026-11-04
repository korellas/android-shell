// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../engine.dart';
import '../main.dart' show confirm, hostAddress, showEngineFailure;
import '../tilde_design.dart';
import '../tilde_controls.dart';
import '../l10n/strings.dart';

const sessionTabsMinWidth = 600.0;
const sessionTabsHeight = 40.0;

class SessionSwitcherButton extends StatelessWidget {
  const SessionSwitcherButton({
    super.key,
    required this.count,
    required this.onPressed,
  });
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.openSessions,
    onPressed: onPressed,
    icon: Badge.count(count: count, child: const Icon(Icons.tab_outlined)),
  );
}

String sessionLabel(List<EngineRecord> sessions, EngineRecord session) {
  final name = '${session['nickname'] ?? deviceStrings.terminal}';
  final siblings = sessions
      .where((s) => s['nickname'] == session['nickname'])
      .toList();
  return siblings.length > 1
      ? '$name · ${siblings.indexWhere((s) => s['id'] == session['id']) + 1}'
      : name;
}

Future<bool> closeTildeSession(
  BuildContext context,
  AndroidEngine engine,
  int id,
) async {
  final contextStrings = context.l10n;
  final session = engine
      .list('sessions')
      .where((s) => s['id'] == id)
      .firstOrNull;
  if (session == null) return false;
  if ((session['open'] == true || session['connecting'] == true) &&
      !await confirm(
        context,
        contextStrings.endSession,
        contextStrings.disconnectFrom(
          (sessionLabel(engine.list('sessions'), session)).toString(),
        ),
        action: contextStrings.end,
      )) {
    return false;
  }
  if (!context.mounted) return false;
  try {
    await engine.invoke('session.disconnect', {'id': id});
    return true;
  } catch (error) {
    if (context.mounted) {
      showEngineFailure(
        context,
        error,
        summary: contextStrings.couldNotCloseConnection,
      );
    }
    return false;
  }
}

Future<(int, bool)?> showTildeSessions(
  BuildContext context,
  AndroidEngine engine, {
  int? selectedId,
}) => showTildeSheet<(int, bool)>(
  context: context,
  isScrollControlled: true,
  builder: (c) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ListenableBuilder(
        listenable: engine,
        builder: (_, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.openSessions,
              style: Theme.of(c).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SessionList(
              engine: engine,
              selectedId: selectedId,
              onSelect: (id) => Navigator.pop(c, (id, false)),
              onClose: (id) => Navigator.pop(c, (id, true)),
            ),
            if (engine.list('sessions').isEmpty)
              Text(context.l10n.noOpenSessions),
          ],
        ),
      ),
    ),
  ),
);

class SessionList extends StatelessWidget {
  const SessionList({
    super.key,
    required this.engine,
    required this.onSelect,
    required this.onClose,
    this.selectedId,
  });
  final AndroidEngine engine;
  final ValueChanged<int> onSelect, onClose;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final sessions = engine.list('sessions');
    return Column(
      children: [
        for (final session in sessions)
          ListTile(
            key: ValueKey('open-session-${session['id']}'),
            selected: session['id'] == selectedId,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              session['connecting'] == true ? Icons.more_horiz : Icons.circle,
              size: 12,
              color: session['open'] == true || session['connecting'] == true
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text(sessionLabel(sessions, session)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session['connecting'] == true
                      ? context.l10n.connecting
                      : session['open'] == true
                      ? context.l10n.connected
                      : context.l10n.disconnected2(
                          (session['endedAt'] == null
                                  ? ''
                                  : ' · ${DateTime.tryParse('${session['endedAt']}')?.toLocal().toString().substring(11, 16) ?? ''}')
                              .toString(),
                        ),
                ),
                if (session['uri'] != null)
                  tildePathText('${session['uri']}')
                else if (engine
                        .list('hosts')
                        .where((h) => h['id'] == session['hostId'])
                        .firstOrNull
                    case final host?)
                  tildePathText(hostAddress(host)),
              ],
            ),
            onTap: () => onSelect(session['id'] as int),
            trailing: IconButton(
              key: ValueKey('session-close-${session['id']}'),
              tooltip: context.l10n.end2(
                (sessionLabel(sessions, session)).toString(),
              ),
              onPressed: () => onClose(session['id'] as int),
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    );
  }
}

class DesktopSessionTabs extends StatefulWidget {
  const DesktopSessionTabs({
    super.key,
    required this.sessions,
    required this.selectedId,
    required this.onSelect,
    required this.onClose,
    required this.onNew,
  });
  final List<EngineRecord> sessions;
  final int selectedId;
  final ValueChanged<int> onSelect, onClose;
  final VoidCallback onNew;

  @override
  State<DesktopSessionTabs> createState() => _DesktopSessionTabsState();
}

class _DesktopSessionTabsState extends State<DesktopSessionTabs> {
  final _scroll = ScrollController();
  final _active = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(DesktopSessionTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != oldWidget.selectedId ||
        widget.sessions.length != oldWidget.sessions.length) {
      _revealSelected();
    }
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active.currentContext != null) {
        Scrollable.ensureVisible(_active.currentContext!, alignment: 0.5);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.sizeOf(context);
    _revealSelected();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          SizedBox(
            width: math.min(
              widget.sessions.length * 200.0,
              math.max(0.0, constraints.maxWidth - 40),
            ),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < widget.sessions.length; index++)
                      _tab(context, index),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.newTab,
            onPressed: widget.onNew,
            constraints: const BoxConstraints.tightFor(
              width: 40,
              height: sessionTabsHeight,
            ),
            padding: EdgeInsets.zero,
            icon: Icon(Icons.add, color: colors.onSurfaceVariant, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int index) {
    final session = widget.sessions[index];
    final id = session['id'] as int;
    final selected = id == widget.selectedId;
    final label = sessionLabel(widget.sessions, session);
    final connecting = session['connecting'] == true;
    final open = session['open'] == true;
    final status = connecting
        ? context.l10n.connecting
        : (open ? context.l10n.connected : context.l10n.disconnected);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: ValueKey('session-tab-$id'),
      selected: selected,
      child: Tooltip(
        message: [
          label,
          if (session['uri'] != null) '${session['uri']}',
          status,
        ].join('\n'),
        child: Material(
          key: selected ? _active : null,
          color: selected ? colors.surfaceContainerHigh : colors.surface,
          child: InkWell(
            onTap: () => widget.onSelect(id),
            child: Container(
              width: 200,
              height: tildePointer(context) ? 46 : sessionTabsHeight,
              padding: EdgeInsets.only(
                left: 12,
                right: 4,
                bottom: tildePointer(context) ? 4 : 0,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    width: 2,
                    color: selected ? colors.primary : Colors.transparent,
                  ),
                  right: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Semantics(
                    label: status,
                    child: Icon(
                      connecting ? Icons.more_horiz : Icons.circle,
                      size: 8,
                      color: open || connecting ? colors.primary : colors.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('session-close-$id'),
                    tooltip: context.l10n.close((label).toString()),
                    onPressed: () => widget.onClose(id),
                    constraints: BoxConstraints.tightFor(
                      width: tildePointer(context) ? 28 : 32,
                      height: tildePointer(context) ? 28 : 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
