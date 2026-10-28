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

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'terminal_input.dart';
import 'package:xterm2/xterm.dart';

class TerminalKeyBar extends StatefulWidget {
  const TerminalKeyBar({
    super.key,
    required this.onKey,
    required this.input,
    this.hapticFeedback = false,
    this.showKeyboardToggle = true,
    required this.onToggleKeyboard,
    this.enabled = true,
    this.onModifiersChanged,
    this.order = const [
      'SLASH',
      'COLON',
      'DASH',
      'PIPE',
      'TILDE',
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
  final TerminalInputController input;
  final bool hapticFeedback;
  final bool showKeyboardToggle;
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

class _RepeatingKey extends StatefulWidget {
  const _RepeatingKey({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.builder,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final Widget Function(VoidCallback) builder;

  @override
  State<_RepeatingKey> createState() => _RepeatingKeyState();
}

class _RepeatingKeyState extends State<_RepeatingKey>
    with WidgetsBindingObserver {
  // Android ViewConfiguration key-repeat defaults.
  static const _delay = Duration(milliseconds: 400);
  static const _interval = Duration(milliseconds: 50);
  Timer? _timer;
  Offset? _origin;
  int? _pointer;
  bool _repeated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _pointer = null;
    _origin = null;
  }

  @override
  void didUpdateWidget(_RepeatingKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (_pointer != null) {
        _stop();
        return;
      }
      _repeated = false;
      if (!widget.enabled) return;
      _pointer = event.pointer;
      _origin = event.position;
      _timer = Timer(_delay, () {
        _repeated = true;
        widget.onPressed();
        _timer = Timer.periodic(_interval, (_) => widget.onPressed());
      });
    },
    onPointerMove: (event) {
      if (_origin != null &&
          (event.position - _origin!).distance > kTouchSlop) {
        _stop();
      }
    },
    onPointerUp: (_) => _stop(),
    onPointerCancel: (_) => _stop(),
    child: widget.builder(() {
      if (!_repeated) widget.onPressed();
    }),
  );
}

class _TerminalKeyBarState extends State<TerminalKeyBar> {
  final _scrollController = ScrollController();
  bool get _ctrl => widget.input.ctrl;
  bool get _alt => widget.input.alt;
  bool _functionMode = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _send(TerminalKey key) {
    if (!widget.enabled) return;
    if (widget.hapticFeedback) HapticFeedback.selectionClick();
    widget.onKey(key, _ctrl, _alt, false);
  }

  void _toggleModifier() {
    if (!widget.enabled) return;
    widget.input.setModifiers(ctrl: !_ctrl, alt: _alt);
    widget.onModifiersChanged?.call(_ctrl, _alt, false);
  }

  Widget _button(
    String label,
    VoidCallback onPressed, {
    bool? selected,
    bool locked = false,
    double width = 44,
    Widget? icon,
    bool repeat = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    return _RepeatingKey(
      key: ValueKey(label),
      enabled: widget.enabled && repeat,
      onPressed: onPressed,
      builder: (activate) => MergeSemantics(
        child: Semantics(
          selected: selected,
          label: icon == null ? null : label,
          child: TextButton(
            onPressed: widget.enabled ? activate : null,
            style: TextButton.styleFrom(
              minimumSize: Size(
                math.max(44, width),
                math.max(44, widget.keyHeight + 8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: locked
                  ? colors.onPrimary
                  : selected == true
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
                color: locked
                    ? colors.primary
                    : selected == true
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
    final text = switch (id) {
      'SLASH' => '/',
      'COLON' => ':',
      'DASH' => '-',
      'PIPE' => '|',
      'TILDE' => '~',
      _ => null,
    };
    if (text != null) {
      return _button(text, () {
        if (!widget.enabled) return;
        if (widget.hapticFeedback) HapticFeedback.selectionClick();
        widget.input.sendText(text);
      });
    }
    final entry = switch (id) {
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
      child: _button(entry.$1, () => _send(entry.$3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.order.where((id) => !widget.hidden.contains(id));
    final hasFn = widget.groupFunctionKeys && visible.contains('FUNCTION_KEYS');
    return ListenableBuilder(
      listenable: widget.input,
      builder: (context, _) => ExcludeFocus(
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
                  _toggleModifier,
                  repeat: false,
                  selected: _ctrl,
                  locked: _ctrl && widget.input.stickyModifiers == 'yes',
                ),
                SizedBox(
                  width: 1,
                  height: 22,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
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
                if (widget.showKeyboardToggle)
                  Tooltip(
                    message: '키보드 전환',
                    child: _button(
                      '⌨',
                      widget.onToggleKeyboard,
                      repeat: false,
                      width: 40,
                      icon: const Icon(Icons.keyboard_outlined, size: 20),
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
                    repeat: false,
                    selected: _functionMode,
                    width: 40,
                  ),
                _button('Tab', () => _send(TerminalKey.tab), width: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
