// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

import 'terminal_input.dart';

class TerminalInputView extends StatefulWidget {
  const TerminalInputView({
    super.key,
    required this.terminal,
    required this.controller,
    required this.input,
    this.terminalViewKey,
    this.focusNode,
    this.scrollController,
    this.padding = EdgeInsets.zero,
    this.theme = TerminalThemes.defaultTheme,
    this.textStyle = const TerminalStyle(),
    this.keyboardEnabled = true,
    this.showSoftKeyboard = true,
    this.autofocus = true,
    this.autoResize = true,
    this.onKeyEvent,
    this.onRequestKeyboard,
    this.paintExtension,
  });

  final Terminal terminal;
  final TerminalController controller;
  final TerminalInputController input;
  final GlobalKey<TerminalViewState>? terminalViewKey;
  final FocusNode? focusNode;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  final TerminalTheme theme;
  final TerminalStyle textStyle;
  final bool keyboardEnabled;
  final bool showSoftKeyboard;
  final bool autofocus;
  final bool autoResize;
  final FocusOnKeyEventCallback? onKeyEvent;
  final VoidCallback? onRequestKeyboard;
  final TerminalPaintExtension? paintExtension;

  @override
  State<TerminalInputView> createState() => _TerminalInputViewState();
}

class _TerminalInputViewState extends State<TerminalInputView> {
  final _viewKey = GlobalKey<TerminalViewState>();
  late FocusNode _focusNode;
  bool _geometryScheduled = false;
  Rect _cursorRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    assert(identical(widget.terminal, widget.input.terminal));
    _focusNode = widget.focusNode ?? FocusNode();
    widget.input.addListener(_inputChanged);
    widget.terminal.addListener(_scheduleGeometry);
    widget.scrollController?.addListener(_scheduleGeometry);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  void _attach() {
    widget.input.attachView(
      focusNode: _focusNode,
      viewId: View.of(context).viewId,
      enabled: widget.keyboardEnabled,
      showSoftKeyboard: widget.showSoftKeyboard,
    );
  }

  @override
  void didUpdateWidget(TerminalInputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(identical(widget.terminal, widget.input.terminal));
    if (oldWidget.input != widget.input) {
      oldWidget.input.removeListener(_inputChanged);
      oldWidget.input.detachView();
      widget.input.addListener(_inputChanged);
    }
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_scheduleGeometry);
      widget.terminal.addListener(_scheduleGeometry);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_scheduleGeometry);
      widget.scrollController?.addListener(_scheduleGeometry);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      widget.input.detachView();
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
    }
    _attach();
  }

  void _inputChanged() {
    setState(() {});
    _scheduleGeometry();
  }

  void _scheduleGeometry() {
    if (_geometryScheduled) return;
    _geometryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geometryScheduled = false;
      if (!mounted) return;
      final view = (widget.terminalViewKey ?? _viewKey).currentState;
      if (view == null) return;
      final render = view.renderTerminal;
      if (!render.hasSize) return;
      widget.input.setEditableGeometry(
        render.size,
        render.getTransformTo(null),
        view.cursorRect,
      );
      final box = context.findRenderObject()! as RenderBox;
      final globalCaret = view.globalCursorRect;
      final cursor = box.globalToLocal(globalCaret.topLeft) & globalCaret.size;
      if (cursor != _cursorRect) {
        _cursorRect = cursor;
        if (widget.input.composingText.isNotEmpty) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.input.removeListener(_inputChanged);
    widget.input.detachView();
    widget.terminal.removeListener(_scheduleGeometry);
    widget.scrollController?.removeListener(_scheduleGeometry);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleGeometry();
    return Stack(
      fit: StackFit.expand,
      children: [
        // The console owns system insets; xterm also reads ambient padding.
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: TerminalView(
            widget.terminal,
            key: widget.terminalViewKey ?? _viewKey,
            controller: widget.controller,
            focusNode: _focusNode,
            scrollController: widget.scrollController,
            padding: widget.padding,
            theme: widget.theme,
            textStyle: widget.textStyle,
            paintExtension: widget.paintExtension,
            autofocus: widget.autofocus,
            autoResize: widget.autoResize,
            hardwareKeyboardOnly: true,
            onKeyEvent: (node, event) {
              final result = widget.onKeyEvent?.call(node, event);
              return result == KeyEventResult.handled
                  ? result!
                  : widget.input.handleKeyEvent(node, event);
            },
            onPaste: () async {
              // The app's paste path owns composition ordering as well.
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (mounted && data?.text != null) {
                widget.input.paste(data!.text!);
              }
            },
            onTapUp: (_, _) {
              if (widget.keyboardEnabled) {
                if (widget.onRequestKeyboard != null) {
                  widget.onRequestKeyboard!();
                } else {
                  widget.input.requestKeyboard();
                }
              }
            },
          ),
        ),
        if (widget.input.composingText.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomSingleChildLayout(
                delegate: _PreeditLayout(_cursorRect),
                child: ColoredBox(
                  color: widget.theme.background,
                  child: Text(
                    widget.input.composingText,
                    style: widget.textStyle.toTextStyle(
                      color: widget.theme.foreground,
                      underline: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PreeditLayout extends SingleChildLayoutDelegate {
  _PreeditLayout(this.cursor);

  final Rect cursor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    cursor.left.clamp(
      0,
      (size.width - childSize.width).clamp(0, double.infinity),
    ),
    cursor.top.clamp(
      0,
      (size.height - childSize.height).clamp(0, double.infinity),
    ),
  );

  @override
  bool shouldRelayout(_PreeditLayout oldDelegate) =>
      cursor != oldDelegate.cursor;
}
