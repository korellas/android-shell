/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:xterm2/xterm.dart';

class TerminalKeyBar extends StatefulWidget {
  const TerminalKeyBar({
    super.key,
    required this.onKey,
    required this.onToggleKeyboard,
    this.enabled = true,
    this.onModifiersChanged,
    this.order = const [
      'ALT',
      'UP',
      'DOWN',
      'LEFT',
      'RIGHT',
      'HOME',
      'END',
      'PAGE_UP',
      'PAGE_DOWN',
      'INSERT',
      'DELETE',
      'FUNCTION_KEYS',
    ],
    this.hidden = const {},
    this.keyHeight = 36,
    this.groupFunctionKeys = true,
  });

  final void Function(TerminalKey key, bool ctrl, bool alt, bool shift) onKey;
  final VoidCallback onToggleKeyboard;
  final bool enabled;
  final void Function(bool ctrl, bool alt, bool shift)? onModifiersChanged;
  final List<String> order;
  final Set<String> hidden;
  final double keyHeight;
  final bool groupFunctionKeys;

  @override
  State<TerminalKeyBar> createState() => _TerminalKeyBarState();
}

class _TerminalKeyBarState extends State<TerminalKeyBar> {
  final _scrollController = ScrollController();
  bool _ctrl = false;
  bool _alt = false;
  bool _functionMode = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _send(TerminalKey key) {
    if (widget.enabled) widget.onKey(key, _ctrl, _alt, false);
  }

  void _toggleModifier({bool ctrl = false}) {
    if (!widget.enabled) return;
    setState(() {
      if (ctrl) {
        _ctrl = !_ctrl;
      } else {
        _alt = !_alt;
      }
    });
    widget.onModifiersChanged?.call(_ctrl, _alt, false);
  }

  Widget _button(
    String label,
    VoidCallback onPressed, {
    bool? selected,
    double width = 44,
    Widget? icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        label: icon == null ? null : label,
        child: TextButton(
          onPressed: widget.enabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: Size(
              math.max(44, width),
              math.max(44, widget.keyHeight + 8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: selected == true
                ? colors.onPrimaryContainer
                : colors.onSurface,
            textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Ink(
            decoration: BoxDecoration(
              color: selected == true
                  ? colors.primaryContainer
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              key: ValueKey('terminal-keycap-$label'),
              constraints: BoxConstraints(
                minWidth: width,
                minHeight: widget.keyHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: icon ?? Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _functionKeys() sync* {
    for (var i = 0; i < 12; i++) {
      final key = TerminalKey.values[TerminalKey.f1.index + i];
      yield _button('F${i + 1}', () => _send(key));
    }
  }

  Widget? _scrollKey(String id) {
    if (id == 'ALT') {
      return _button('Alt', () => _toggleModifier(), selected: _alt);
    }
    final entry = switch (id) {
      'UP' => ('↑', 'Up', TerminalKey.arrowUp),
      'DOWN' => ('↓', 'Down', TerminalKey.arrowDown),
      'LEFT' => ('←', 'Left', TerminalKey.arrowLeft),
      'RIGHT' => ('→', 'Right', TerminalKey.arrowRight),
      'HOME' => ('Home', 'Home', TerminalKey.home),
      'END' => ('End', 'End', TerminalKey.end),
      'PAGE_UP' => ('PgUp', 'Page up', TerminalKey.pageUp),
      'PAGE_DOWN' => ('PgDn', 'Page down', TerminalKey.pageDown),
      'INSERT' => ('Ins', 'Insert', TerminalKey.insert),
      'DELETE' => ('Del', 'Delete', TerminalKey.delete),
      _ => null,
    };
    if (entry == null) return null;
    return Tooltip(
      message: entry.$2,
      child: _button(
        entry.$1,
        () => _send(entry.$3),
        width: ['UP', 'DOWN', 'LEFT', 'RIGHT'].contains(id) ? 38 : 44,
        icon: switch (id) {
          'UP' => const Icon(Icons.keyboard_arrow_up, size: 20),
          'DOWN' => const Icon(Icons.keyboard_arrow_down, size: 20),
          'LEFT' => const Icon(Icons.keyboard_arrow_left, size: 20),
          'RIGHT' => const Icon(Icons.keyboard_arrow_right, size: 20),
          _ => null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.order.where((id) => !widget.hidden.contains(id));
    final hasFn = widget.groupFunctionKeys && visible.contains('FUNCTION_KEYS');
    return ExcludeFocus(
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            spacing: 4,
            children: [
              _button('Esc', () => _send(TerminalKey.escape)),
              _button(
                'Ctrl',
                () => _toggleModifier(ctrl: true),
                selected: _ctrl,
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 4,
                    children: [
                      if (hasFn && _functionMode)
                        ..._functionKeys()
                      else
                        for (final id in visible)
                          if (id == 'FUNCTION_KEYS') ...[
                            if (!hasFn) ..._functionKeys(),
                          ] else
                            ?_scrollKey(id),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message: '키보드 전환',
                child: _button(
                  '⌨',
                  widget.onToggleKeyboard,
                  width: 40,
                  icon: const Icon(Icons.keyboard_outlined, size: 18),
                ),
              ),
              if (hasFn)
                _button(
                  'Fn',
                  () {
                    setState(() => _functionMode = !_functionMode);
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0);
                    }
                  },
                  selected: _functionMode,
                  width: 40,
                ),
              _button('tab', () => _send(TerminalKey.tab), width: 56),
            ],
          ),
        ),
      ),
    );
  }
}
