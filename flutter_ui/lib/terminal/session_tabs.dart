// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:flutter/material.dart';
import '../engine.dart';

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
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Expanded(
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
          tooltip: '새 세션',
          onPressed: widget.onNew,
          icon: Icon(Icons.add, color: colors.onSurfaceVariant, size: 20),
        ),
      ],
    );
  }

  Widget _tab(BuildContext context, int index) {
    final session = widget.sessions[index];
    final id = session['id'] as int;
    final selected = id == widget.selectedId;
    final name = '${session['nickname'] ?? '터미널'}';
    final duplicates = widget.sessions
        .where((other) => other['nickname'] == session['nickname'])
        .length;
    final ordinal = widget.sessions
        .take(index + 1)
        .where((other) => other['nickname'] == session['nickname'])
        .length;
    final label = duplicates > 1 ? '$name · $ordinal' : name;
    final connecting = session['connecting'] == true;
    final open = session['open'] == true;
    final status = connecting ? '연결 중' : (open ? '연결됨' : '연결 종료');
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
              height: 46,
              padding: const EdgeInsets.only(left: 12, right: 4, bottom: 4),
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
                      color: open || connecting
                          ? colors.primary
                          : colors.outline,
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
                    tooltip: '$label 닫기',
                    onPressed: () => widget.onClose(id),
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
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
