// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import '../tilde_design.dart';
import 'terminal_actions.dart';
import 'terminal_input.dart';
import 'terminal_input_view.dart';
import 'terminal_key_bar.dart';

/// Shared terminal UI; the session owns the terminal and its byte transport.
class TerminalPane extends StatefulWidget {
  const TerminalPane({
    super.key,
    required this.terminal,
    required this.controller,
    required this.input,
    this.focusNode,
    this.enabled = true,
    this.onShare,
    this.onOpenUrl,
    this.onSwipe,
    this.onKeyEvent,
    this.pageGesture = false,
    this.initialRows,
    this.initialColumns,
    this.onFontSize,
    this.volumeFont = false,
    this.alwaysVisibleKeys = true,
    this.keyHideDelay = const Duration(seconds: 3),
    this.onEdit,
    this.keyOrder,
    this.hiddenKeys = const {},
    this.keyHeight = 36,
    this.groupFunctionKeys = true,
    this.stickyModifiers = 'no',
    this.hapticFeedback = false,
    this.showKeyboardToggle = true,
    this.padding = EdgeInsets.zero,
    this.theme = TerminalThemes.defaultTheme,
    this.textStyle = const TerminalStyle(),
  });

  final Terminal terminal;
  final TerminalController controller;
  final TerminalInputController input;
  final FocusNode? focusNode;
  final bool enabled;
  final void Function(String)? onShare;
  final ValueChanged<String>? onOpenUrl;
  final ValueChanged<int>? onSwipe;
  final FocusOnKeyEventCallback? onKeyEvent;
  final bool pageGesture;
  final int? initialRows;
  final int? initialColumns;
  final ValueChanged<bool>? onFontSize;
  final bool volumeFont;
  final bool alwaysVisibleKeys;
  final Duration keyHideDelay;
  final Future<String?> Function(String)? onEdit;
  final List<String>? keyOrder;
  final Set<String> hiddenKeys;
  final double keyHeight;
  final bool groupFunctionKeys;
  final String stickyModifiers;
  final bool hapticFeedback;
  final bool showKeyboardToggle;
  final EdgeInsets padding;
  final TerminalTheme theme;
  final TerminalStyle textStyle;

  @override
  TerminalPaneState createState() => TerminalPaneState();
}

class TerminalPaneState extends State<TerminalPane> {
  bool _autoResize = true;
  Timer? _keyHideTimer;
  bool _keysVisible = true;
  Offset _drag = Offset.zero;
  final Set<int> _pointers = {};
  bool _multiTouch = false;
  bool _cursorDragging = false;

  bool _canDrag() =>
      widget.enabled &&
      widget.controller.selectionFor(widget.terminal.buffer) == null;

  void _moveCursor(Offset delta, {required bool horizontal}) {
    if (!_canDrag()) return;
    final render = _terminalKey.currentState?.renderTerminal;
    if (render == null) return;
    if (_multiTouch && !horizontal && !widget.pageGesture) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(
          (_scroll.offset - delta.dy).clamp(
            _scroll.position.minScrollExtent,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
      return;
    }
    _drag += delta;
    if (_multiTouch && horizontal) return;
    final step = _multiTouch
        ? render.cellSize.height * 5
        : math.max(
            24.0,
            horizontal ? render.cellSize.width * 2 : render.cellSize.height,
          );
    final distance = horizontal ? _drag.dx : _drag.dy;
    final count = (distance / step).truncate();
    final key = _multiTouch
        ? (count < 0 ? TerminalKey.pageDown : TerminalKey.pageUp)
        : horizontal
        ? (count < 0 ? TerminalKey.arrowLeft : TerminalKey.arrowRight)
        : (count < 0 ? TerminalKey.arrowUp : TerminalKey.arrowDown);
    for (var i = 0; i < count.abs(); i++) {
      widget.input.sendKey(key);
    }
    _drag -= horizontal ? Offset(count * step, 0) : Offset(0, count * step);
  }

  void _interaction({bool scrolling = false}) {
    _keyHideTimer?.cancel();
    if (!_keysVisible) setState(() => _keysVisible = true);
    if (!widget.alwaysVisibleKeys && !scrolling) {
      _keyHideTimer = Timer(widget.keyHideDelay, () {
        if (mounted) setState(() => _keysVisible = false);
      });
    }
  }

  KeyEventResult _keyEvent(FocusNode node, KeyEvent event) {
    _interaction();
    final result = widget.onKeyEvent?.call(node, event);
    if (result != null && result != KeyEventResult.ignored) return result;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final chord = keyboard.isControlPressed && keyboard.isShiftPressed;
    final key = event.logicalKey;
    if (chord && key == LogicalKeyboardKey.keyC) {
      unawaited(viewAction('copy'));
    } else if (widget.enabled && chord && key == LogicalKeyboardKey.keyV) {
      unawaited(viewAction('paste'));
    } else if ((chord && key == LogicalKeyboardKey.equal) ||
        (widget.volumeFont && key == LogicalKeyboardKey.audioVolumeUp)) {
      widget.onFontSize?.call(true);
    } else if ((chord && key == LogicalKeyboardKey.minus) ||
        (widget.volumeFont && key == LogicalKeyboardKey.audioVolumeDown)) {
      widget.onFontSize?.call(false);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    widget.input.stickyModifiers = widget.stickyModifiers;
    widget.input.installPasteGuard(this, _confirmPaste);
    final rows = widget.initialRows;
    final columns = widget.initialColumns;
    if (rows != null && columns != null && rows > 0 && columns > 0) {
      _autoResize = false;
      widget.terminal.resize(columns, rows);
    }
  }

  @override
  void didUpdateWidget(TerminalPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.input, widget.input)) {
      oldWidget.input.removePasteGuard(this);
      widget.input.installPasteGuard(this, _confirmPaste);
    }
    widget.input.stickyModifiers = widget.stickyModifiers;
    if (!widget.enabled ||
        oldWidget.terminal != widget.terminal ||
        oldWidget.controller != widget.controller) {
      _cursorDragging = false;
    }
  }

  void _startCursorDrag() {
    _drag = Offset.zero;
    if (!_multiTouch && _canDrag()) setState(() => _cursorDragging = true);
  }

  void _endCursorDrag() {
    if (_cursorDragging) setState(() => _cursorDragging = false);
  }

  Future<bool> _confirmPaste(String text) async {
    if (!mounted) return false;
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = math.max(
      1,
      normalized.split('\n').length - (normalized.endsWith('\n') ? 1 : 0),
    );
    return await showTildeSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (c) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$lines줄을 붙여 넣을까요?',
                  style: Theme.of(c).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  lines > 1
                      ? '$lines개 줄을 터미널에 붙여넣으면 명령이 즉시 실행될 수 있습니다.'
                      : '제어 문자가 포함되어 있어 터미널 동작이나 명령 실행을 유발할 수 있습니다.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(c).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        for (final (index, line)
                            in normalized.split('\n').take(6).indexed) ...[
                          TextSpan(text: line),
                          if (index < normalized.split('\n').length - 1)
                            TextSpan(
                              text: '⏎\n',
                              style: TextStyle(
                                color: Theme.of(c).colorScheme.tertiary,
                              ),
                            ),
                        ],
                      ],
                    ),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: tildeMono,
                      fontFamilyFallback: tildeMonoFallback,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text('$lines줄 붙여넣기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void resize({int? rows, int? columns}) {
    if (!widget.enabled) return;
    setState(() => _autoResize = rows == null || columns == null);
    if (!_autoResize) widget.terminal.resize(columns!, rows!);
  }

  Future<void> viewAction(String action) async {
    if (!widget.enabled &&
        const {'keyboard', 'compose', 'paste'}.contains(action)) {
      return;
    }
    final buffer = widget.terminal.buffer;
    final selection = widget.controller.selectionFor(buffer);
    void selectRows(int first, int last) => widget.controller.setSelection(
      buffer.createAnchor(0, first.clamp(0, buffer.height - 1)),
      buffer.createAnchor(buffer.viewWidth, last.clamp(0, buffer.height - 1)),
      mode: SelectionMode.line,
    );
    switch (action) {
      case 'keyboard':
        toggleKeyboard();
      case 'compose':
        await _edit(selection == null ? '' : buffer.getText(selection));
      case 'select':
        selectRows(
          buffer.height - buffer.viewHeight + buffer.cursorY,
          buffer.height - buffer.viewHeight + buffer.cursorY,
        );
      case 'selectAll':
        selectRows(0, buffer.height - 1);
      case 'selectVisible':
        final render = _terminalKey.currentState?.renderTerminal;
        if (render != null && render.hasSize) {
          selectRows(
            render.getCellOffset(Offset.zero).y,
            render.getCellOffset(Offset(0, render.size.height - .01)).y,
          );
        }
      case 'copy':
        if (selection != null) {
          await Clipboard.setData(
            ClipboardData(text: buffer.getText(selection)),
          );
          if (mounted) widget.controller.clearSelection();
        }
      case 'clearSelection':
        widget.controller.clearSelection();
      case 'paste':
        final input = widget.input;
        final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        if (mounted &&
            widget.enabled &&
            input == widget.input &&
            text != null) {
          widget.controller.clearSelection();
          input.paste(text);
        }
      case 'selectionMode':
        widget.controller.setSelectionMode(
          widget.controller.selectionMode == SelectionMode.line
              ? SelectionMode.block
              : SelectionMode.line,
        );
      case 'selectionUp':
      case 'selectionDown':
      case 'selectionLeft':
      case 'selectionRight':
        if (selection == null) return;
        final end = selection.end;
        final dx = action == 'selectionLeft'
            ? -1
            : action == 'selectionRight'
            ? 1
            : 0;
        final dy = action == 'selectionUp'
            ? -1
            : action == 'selectionDown'
            ? 1
            : 0;
        widget.controller.setSelection(
          buffer.createAnchorFromOffset(selection.begin),
          buffer.createAnchor(
            (end.x + dx).clamp(0, buffer.viewWidth),
            (end.y + dy).clamp(0, buffer.height - 1),
          ),
          mode: widget.controller.selectionMode,
        );
    }
  }

  final _terminalKey = GlobalKey<TerminalViewState>();
  final _scroll = ScrollController();
  bool _keyboardVisible = true;

  Future<void> _edit(String selected) async {
    final input = widget.input;
    input.finishComposition();
    final editContext = context;
    final edit = widget.onEdit;
    final Future<String?> result;
    if (edit != null) {
      result = edit(selected);
    } else {
      result = showTildeSheet<String>(
        context: editContext,
        isScrollControlled: true,
        builder: (_) => _SelectionEditor(initial: selected),
      );
    }
    final text = await result;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !widget.enabled || input != widget.input) return;
    if (text != null) input.pasteConfirmed(text);
    if (_keyboardVisible) input.requestKeyboard();
  }

  void toggleKeyboard() {
    if (!widget.enabled) return;
    if (_keyboardVisible) widget.input.closeKeyboard();
    setState(() => _keyboardVisible = !_keyboardVisible);
    if (_keyboardVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) widget.input.requestKeyboard();
      });
    }
  }

  @override
  void dispose() {
    _keyHideTimer?.cancel();
    widget.input.removePasteGuard(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: TerminalActions(
          terminal: widget.terminal,
          controller: widget.controller,
          terminalViewKey: _terminalKey,
          inputEnabled: widget.enabled,
          magnifyCursor: _cursorDragging && !_multiTouch,
          onEdit: _edit,
          onPaste: widget.input.paste,
          onShare: widget.onShare,
          child: Listener(
            onPointerDown: (event) {
              _interaction();
              if (_pointers.isEmpty) _multiTouch = false;
              _pointers.add(event.pointer);
              if (_pointers.length > 1) {
                _multiTouch = true;
                _endCursorDrag();
                _drag = Offset.zero;
              }
            },
            onPointerUp: (event) {
              _pointers.remove(event.pointer);
              if (_pointers.isEmpty) _endCursorDrag();
            },
            onPointerCancel: (event) {
              _pointers.remove(event.pointer);
              _endCursorDrag();
            },
            onPointerMove: (_) => _interaction(scrolling: true),
            child: RawGestureDetector(
              gestures: {
                _CursorHorizontalDrag:
                    GestureRecognizerFactoryWithHandlers<_CursorHorizontalDrag>(
                      () => _CursorHorizontalDrag(),
                      (recognizer) => recognizer
                        ..canStart = _canDrag
                        ..multitouchDragStrategy =
                            MultitouchDragStrategy.averageBoundaryPointers
                        ..dragStartBehavior = DragStartBehavior.down
                        ..onStart = (_) {
                          _startCursorDrag();
                        }
                        ..onUpdate = (details) {
                          _moveCursor(details.delta, horizontal: true);
                        }
                        ..onCancel = _endCursorDrag
                        ..onEnd = (_) {
                          _endCursorDrag();
                          if (!_canDrag() ||
                              !_multiTouch ||
                              widget.onSwipe == null) {
                            return;
                          }
                          final threshold = math.max(
                            54,
                            context.size!.width * .18,
                          );
                          if (_drag.dx.abs() >= threshold) {
                            widget.onSwipe!(_drag.dx < 0 ? 1 : -1);
                          }
                        },
                    ),
                _CursorVerticalDrag:
                    GestureRecognizerFactoryWithHandlers<_CursorVerticalDrag>(
                      () => _CursorVerticalDrag(),
                      (recognizer) => recognizer
                        ..canStart = _canDrag
                        ..multitouchDragStrategy =
                            MultitouchDragStrategy.averageBoundaryPointers
                        ..dragStartBehavior = DragStartBehavior.down
                        ..onStart = (_) {
                          _startCursorDrag();
                        }
                        ..onUpdate = (details) {
                          _moveCursor(details.delta, horizontal: false);
                        }
                        ..onEnd = (_) {
                          _endCursorDrag();
                        }
                        ..onCancel = _endCursorDrag,
                    ),
              },
              child: TerminalInputView(
                terminal: widget.terminal,
                controller: widget.controller,
                input: widget.input,
                terminalViewKey: _terminalKey,
                focusNode: widget.focusNode,
                scrollController: _scroll,
                keyboardEnabled: widget.enabled,
                autoResize: _autoResize,
                onKeyEvent: _keyEvent,
                onOpenUrl: widget.onOpenUrl,
                onRequestKeyboard: () {
                  if (!_keyboardVisible) {
                    toggleKeyboard();
                  } else {
                    widget.input.requestKeyboard();
                  }
                },
                padding: widget.padding,
                showSoftKeyboard: _keyboardVisible,
                theme: widget.theme,
                textStyle: widget.textStyle,
              ),
            ),
          ),
        ),
      ),
      if (!tildePointer(context))
        Visibility(
          visible: widget.enabled && (_keysVisible || widget.alwaysVisibleKeys),
          maintainState: true,
          child: TerminalKeyBar(
            key: ObjectKey(widget.input),
            input: widget.input,
            hapticFeedback: widget.hapticFeedback,
            showKeyboardToggle: widget.showKeyboardToggle,
            enabled: widget.enabled,
            onToggleKeyboard: () {
              _interaction();
              toggleKeyboard();
            },
            order: widget.keyOrder ?? TerminalKeyBar.defaultOrder,
            hidden: widget.hiddenKeys,
            keyHeight: widget.keyHeight,
            groupFunctionKeys: widget.groupFunctionKeys,
            onKey: (key, ctrl, alt, shift) {
              _interaction();
              widget.input.sendKey(key, ctrl: ctrl, alt: alt, shift: shift);
            },
          ),
        ),
    ],
  );
}

class _SelectionEditor extends StatefulWidget {
  const _SelectionEditor({required this.initial});
  final String initial;

  @override
  State<_SelectionEditor> createState() => _SelectionEditorState();
}

class _SelectionEditorState extends State<_SelectionEditor> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('텍스트 편집', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 10,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: '전송할 텍스트'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _text.text),
              child: const Text('전송'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _CursorHorizontalDrag extends HorizontalDragGestureRecognizer {
  _CursorHorizontalDrag()
    : super(
        supportedDevices: {PointerDeviceKind.touch, PointerDeviceKind.stylus},
      );
  bool Function()? canStart;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (canStart?.call() ?? false) && super.isPointerAllowed(event);
}

class _CursorVerticalDrag extends VerticalDragGestureRecognizer {
  _CursorVerticalDrag()
    : super(
        supportedDevices: {PointerDeviceKind.touch, PointerDeviceKind.stylus},
      );
  bool Function()? canStart;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      (canStart?.call() ?? false) && super.isPointerAllowed(event);
}
