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
    this.onSwipe,
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
  final ValueChanged<int>? onSwipe;
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
  final _gestureKey = GlobalKey();
  final Set<int> _pointers = {};
  bool _pageCancelled = false;
  double _pageDrag = 0;

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
  }

  Future<bool> _confirmPaste(String text) async {
    if (!mounted) return false;
    final lines = '\n'.allMatches(text.replaceAll('\r\n', '\n')).length + 1;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위험할 수 있는 내용 붙여넣기'),
            content: Text(
              lines > 1
                  ? '$lines개 줄을 터미널에 붙여넣으면 명령이 즉시 실행될 수 있습니다.'
                  : '제어 문자가 포함되어 있어 터미널 동작이나 명령 실행을 유발할 수 있습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('붙여넣기'),
              ),
            ],
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
          onEdit: _edit,
          onPaste: widget.input.paste,
          onShare: widget.onShare,
          child: GestureDetector(
            onHorizontalDragStart: widget.onSwipe == null
                ? null
                : (_) {
                    _drag = Offset.zero;
                  },
            onHorizontalDragUpdate: widget.onSwipe == null
                ? null
                : (details) {
                    _drag += details.delta;
                  },
            onHorizontalDragEnd: widget.onSwipe == null
                ? null
                : (_) {
                    if (!widget.enabled ||
                        widget.controller.selectionFor(
                              widget.terminal.buffer,
                            ) !=
                            null) {
                      return;
                    }
                    final threshold = math.max(54, context.size!.width * .18);
                    if (_drag.dx.abs() >= threshold &&
                        _drag.dx.abs() >= _drag.dy.abs() * 1.5) {
                      widget.onSwipe!(_drag.dx < 0 ? 1 : -1);
                    }
                  },
            child: Listener(
              onPointerDown: (event) {
                _interaction();
                _pointers.add(event.pointer);
                if (_pointers.length > 1) _pageCancelled = true;
              },
              onPointerUp: (event) => _pointers.remove(event.pointer),
              onPointerCancel: (event) => _pointers.remove(event.pointer),
              onPointerMove: (_) => _interaction(scrolling: true),
              child: RawGestureDetector(
                key: _gestureKey,
                gestures: {
                  if (widget.pageGesture)
                    _PageDragRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _PageDragRecognizer
                        >(() => _PageDragRecognizer(), (recognizer) {
                          recognizer
                            ..canStart = (event) {
                              final box =
                                  _gestureKey.currentContext?.findRenderObject()
                                      as RenderBox?;
                              return widget.enabled &&
                                  box != null &&
                                  _pointers.length <= 1 &&
                                  widget.controller.selectionFor(
                                        widget.terminal.buffer,
                                      ) ==
                                      null &&
                                  box.globalToLocal(event.position).dx <=
                                      box.size.width / 3;
                            }
                            ..dragStartBehavior = DragStartBehavior.down
                            ..onStart = (_) {
                              _pageCancelled = _pointers.length > 1;
                              _pageDrag = 0;
                            }
                            ..onUpdate = (details) {
                              if (_pageCancelled || !widget.enabled) return;
                              _pageDrag -= details.delta.dy;
                              final render =
                                  _terminalKey.currentState?.renderTerminal;
                              if (render == null) return;
                              final step = render.cellSize.height * 5;
                              final pages = (_pageDrag / step).truncate();
                              for (var i = 0; i < pages.abs(); i++) {
                                widget.input.sendKey(
                                  pages > 0
                                      ? TerminalKey.pageDown
                                      : TerminalKey.pageUp,
                                );
                              }
                              _pageDrag -= pages * step;
                            };
                        }),
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
      ),
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
          order:
              widget.keyOrder ??
              const [
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

class _PageDragRecognizer extends VerticalDragGestureRecognizer {
  bool Function(PointerDownEvent)? canStart;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      event is PointerDownEvent &&
      (canStart?.call(event) ?? false) &&
      super.isPointerAllowed(event);
}
