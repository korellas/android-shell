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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';

class TerminalActions extends StatefulWidget {
  const TerminalActions({
    super.key,
    required this.terminal,
    required this.controller,
    required this.terminalViewKey,
    required this.child,
    required this.onEdit,
    required this.onPaste,
    this.onShare,
    this.enabled = true,
    this.inputEnabled = true,
  });

  final Terminal terminal;
  final TerminalController controller;
  final GlobalKey<TerminalViewState> terminalViewKey;
  final Widget child;
  final Future<void> Function(String text) onEdit;
  final void Function(String text) onPaste;
  final void Function(String text)? onShare;
  final bool enabled;
  final bool inputEnabled;

  @override
  State<TerminalActions> createState() => _TerminalActionsState();
}

class _TerminalActionsState extends State<TerminalActions> {
  final _stackKey = GlobalKey();
  ScrollPosition? _scrollPosition;
  CellOffset? _touchedCell;
  bool _overflow = false;
  bool _refreshPending = false;
  bool _forceRefresh = false;
  bool _draggingHandle = false;
  Offset? _handleDragOffset;
  EdgeDraggingAutoScroller? _autoScroller;
  ScrollableState? _autoScrollOwner;
  Offset? _lastHandleGlobal;
  bool _dragExtent = false;
  ({Rect viewport, Offset begin, Offset end, double cellHeight})? _geometry;

  @override
  void initState() {
    super.initState();
    widget.terminal.addListener(_refresh);
    widget.controller.addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(TerminalActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_refresh);
      widget.terminal.addListener(_refresh);
      _touchedCell = null;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      _overflow = false;
    }
    if (!widget.enabled ||
        oldWidget.terminal != widget.terminal ||
        oldWidget.controller != widget.controller ||
        oldWidget.terminalViewKey != widget.terminalViewKey) {
      _stopHandleScroll();
      _draggingHandle = false;
      _handleDragOffset = null;
      _touchedCell = null;
      _overflow = false;
      _geometry = null;
    }
    _refresh();
  }

  void _observeScroll() {
    final position =
        widget.terminalViewKey.currentState?.scrollableState?.position;
    if (identical(_scrollPosition, position)) return;
    _stopHandleScroll();
    _scrollPosition?.removeListener(_refresh);
    _scrollPosition = position;
    position?.addListener(_refresh);
  }

  void _refresh() => _scheduleGeometry(force: true);

  void _scheduleGeometry({bool force = false}) {
    _forceRefresh |= force;
    if (_refreshPending) return;
    _refreshPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPending = false;
      if (!mounted) return;
      _observeScroll();
      final geometry = _measureGeometry();
      final rebuild = _forceRefresh || geometry != _geometry;
      _forceRefresh = false;
      if (!rebuild) return;
      setState(() {
        _geometry = geometry;
        if (_selection == null) {
          _stopHandleScroll();
          _draggingHandle = false;
          _handleDragOffset = null;
          _overflow = false;
          _touchedCell = null;
        }
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  ({Rect viewport, Offset begin, Offset end, double cellHeight})?
  _measureGeometry() {
    final selection = _selection;
    final render = widget.terminalViewKey.currentState?.renderTerminal;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (selection == null ||
        render == null ||
        !render.hasSize ||
        stack == null ||
        !stack.hasSize) {
      return null;
    }
    final origin = render.localToGlobal(Offset.zero, ancestor: stack);
    return (
      viewport: (origin & render.size).intersect(Offset.zero & stack.size),
      begin: render.localToGlobal(
        render.getOffset(selection.begin),
        ancestor: stack,
      ),
      end: render.localToGlobal(
        render.getOffset(selection.end),
        ancestor: stack,
      ),
      cellHeight:
          render.getOffset(CellOffset(0, selection.end.y + 1)).dy -
          render.getOffset(CellOffset(0, selection.end.y)).dy,
    );
  }

  @override
  void dispose() {
    _stopHandleScroll();
    widget.terminal.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    _scrollPosition?.removeListener(_refresh);
    super.dispose();
  }

  BufferRange? get _selection =>
      widget.controller.selectionFor(widget.terminal.buffer);

  String? _selectedText() {
    if (!widget.enabled) return null;
    final selection = _selection;
    return selection == null ? null : widget.terminal.buffer.getText(selection);
  }

  Future<void> _copy() async {
    final text = _selectedText();
    if (text == null) return;
    widget.controller.clearSelection();
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _edit() async {
    if (!widget.inputEnabled) return;
    final text = _selectedText();
    if (text == null) return;
    widget.controller.clearSelection();
    await widget.onEdit(text);
  }

  Future<void> _paste() async {
    if (!widget.enabled || !widget.inputEnabled) return;
    final controller = widget.controller;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted ||
        !widget.enabled ||
        !widget.inputEnabled ||
        controller != widget.controller) {
      return;
    }
    if (data?.text case final text?) {
      controller.clearSelection();
      widget.onPaste(text);
    }
  }

  void _selectRows(int first, int last) {
    final buffer = widget.terminal.buffer;
    widget.controller.setSelection(
      buffer.createAnchor(0, first.clamp(0, buffer.height - 1)),
      buffer.createAnchor(buffer.viewWidth, last.clamp(0, buffer.height - 1)),
      mode: SelectionMode.line,
    );
  }

  void _selectLine() {
    final selection = _selection;
    if (selection == null) return;
    final buffer = widget.terminal.buffer;
    final cell = _touchedCell ?? selection.end;
    final range = buffer.getLineBoundary(
      CellOffset(
        cell.x.clamp(0, buffer.viewWidth - 1),
        cell.y.clamp(0, buffer.height - 1),
      ),
    );
    if (range == null) return;
    widget.controller.setSelection(
      buffer.createAnchorFromOffset(range.begin),
      buffer.createAnchorFromOffset(range.end),
      mode: SelectionMode.line,
    );
  }

  void _selectVisible() {
    final render = widget.terminalViewKey.currentState?.renderTerminal;
    if (render == null || !render.hasSize) return;
    _selectRows(
      render.getCellOffset(Offset.zero).y,
      render.getCellOffset(Offset(0, render.size.height - 0.01)).y,
    );
  }

  Widget _option(String label, VoidCallback action) {
    return TextButton(
      onPressed: () {
        if (!widget.enabled) return;
        setState(() => _overflow = false);
        action();
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        alignment: Alignment.centerLeft,
      ),
      child: Text(label),
    );
  }

  Widget _menu() {
    return ExcludeFocus(
      child: SizedBox(
        key: const ValueKey('terminal-selection-menu'),
        width: 264,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _copy,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        icon: const Icon(Icons.content_copy_outlined, size: 18),
                        label: const Text('복사'),
                      ),
                    ),
                    if (widget.inputEnabled)
                      Expanded(
                        flex: 2,
                        child: TextButton.icon(
                          onPressed: _edit,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('편집 후 전송'),
                        ),
                      ),
                    IconButton(
                      tooltip: '선택 메뉴 더보기',
                      onPressed: () => setState(() => _overflow = !_overflow),
                      icon: Icon(
                        _overflow ? Icons.expand_less : Icons.more_vert,
                      ),
                    ),
                  ],
                ),
                if (_overflow) ...[
                  if (widget.inputEnabled)
                    _option('붙여넣기', () => unawaited(_paste())),
                  if (widget.onShare != null)
                    _option('공유', () {
                      final text = _selectedText();
                      if (text != null) widget.onShare!(text);
                    }),
                  _option('줄 선택', _selectLine),
                  _option(
                    '전체 선택',
                    () => _selectRows(0, widget.terminal.buffer.height - 1),
                  ),
                  _option('보이는 화면 선택', _selectVisible),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('선택 단위'),
                        const SizedBox(height: 8),
                        SegmentedButton<SelectionMode>(
                          segments: const [
                            ButtonSegment(
                              value: SelectionMode.line,
                              label: Text('줄'),
                            ),
                            ButtonSegment(
                              value: SelectionMode.block,
                              label: Text('블록'),
                            ),
                          ],
                          selected: {widget.controller.selectionMode},
                          showSelectedIcon: false,
                          onSelectionChanged: (value) =>
                              widget.controller.setSelectionMode(value.single),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle(bool extent, Offset point, Rect viewport, double cellHeight) {
    final top = extent ? point.dy + cellHeight : point.dy - 48;
    final left = point.dx - 24;
    return Positioned(
      left: left.clamp(
        viewport.left,
        math.max(viewport.left, viewport.right - 48),
      ),
      top: top.clamp(
        viewport.top,
        math.max(viewport.top, viewport.bottom - 48),
      ),
      child: Semantics(
        label: extent ? '선택 끝' : '선택 시작',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) {
            final selection = _selection;
            final render = widget.terminalViewKey.currentState?.renderTerminal;
            if (!widget.enabled || selection == null || render == null) return;
            final cell = extent ? selection.end : selection.begin;
            _handleDragOffset =
                render.globalToLocal(details.globalPosition) -
                render.getOffset(cell);
          },
          onPanStart: (_) {
            if (widget.enabled) setState(() => _draggingHandle = true);
          },
          onPanUpdate: (details) =>
              _updateHandleDrag(extent, details.globalPosition),
          onPanEnd: (_) => _finishHandleDrag(),
          onPanCancel: _finishHandleDrag,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Align(
              alignment: extent ? Alignment.topCenter : Alignment.bottomCenter,
              child: Icon(
                Icons.circle,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateHandleDrag(bool extent, Offset globalPosition) {
    if (!widget.enabled || !_draggingHandle) return;
    _lastHandleGlobal = globalPosition;
    _dragExtent = extent;
    _dragHandle(extent, globalPosition);
    final scrollable = widget.terminalViewKey.currentState?.scrollableState;
    if (scrollable == null) return;
    if (_autoScrollOwner != scrollable) {
      _autoScroller?.stopAutoScroll();
      _autoScrollOwner = scrollable;
      _autoScroller = EdgeDraggingAutoScroller(
        scrollable,
        velocityScalar: 30,
        onScrollViewScrolled: () {
          final position = _lastHandleGlobal;
          if (mounted &&
              widget.enabled &&
              _draggingHandle &&
              position != null) {
            _dragHandle(_dragExtent, position);
          }
        },
      );
    }
    _autoScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: globalPosition, width: 0, height: 0),
    );
  }

  void _stopHandleScroll() {
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    _autoScrollOwner = null;
    _lastHandleGlobal = null;
  }

  void _dragHandle(bool extent, Offset globalPosition) {
    final selection = _selection;
    final render = widget.terminalViewKey.currentState?.renderTerminal;
    final dragOffset = _handleDragOffset;
    if (!widget.enabled ||
        selection == null ||
        render == null ||
        dragOffset == null) {
      return;
    }
    final buffer = widget.terminal.buffer;
    final position = render.getCellOffset(
      render.globalToLocal(globalPosition) - dragOffset,
    );
    final cell = CellOffset(
      position.x.clamp(0, buffer.viewWidth),
      position.y.clamp(0, buffer.height - 1),
    );
    widget.controller.setSelection(
      buffer.createAnchorFromOffset(extent ? selection.begin : cell),
      buffer.createAnchorFromOffset(extent ? cell : selection.end),
      mode: widget.controller.selectionMode,
    );
  }

  void _finishHandleDrag() {
    _stopHandleScroll();
    _handleDragOffset = null;
    if (mounted) setState(() => _draggingHandle = false);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleGeometry();
    final selection = _selection;
    final geometry = _geometry;
    return Stack(
      key: _stackKey,
      fit: StackFit.passthrough,
      children: [
        Listener(
          onPointerDown: _recordPointer,
          onPointerMove: _recordPointer,
          child: widget.child,
        ),
        if (widget.enabled &&
            selection != null &&
            !selection.isCollapsed &&
            geometry != null) ...[
          _handle(
            false,
            geometry.begin,
            geometry.viewport,
            geometry.cellHeight,
          ),
          _handle(true, geometry.end, geometry.viewport, geometry.cellHeight),
          if (!_draggingHandle)
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _SelectionMenuLayout(
                  viewport: geometry.viewport,
                  point: geometry.end,
                  cellHeight: geometry.cellHeight,
                ),
                child: _menu(),
              ),
            ),
        ],
      ],
    );
  }

  void _recordPointer(PointerEvent event) {
    final render = widget.terminalViewKey.currentState?.renderTerminal;
    if (render == null || !render.hasSize) return;
    _touchedCell = render.getCellOffset(render.globalToLocal(event.position));
  }
}

class _SelectionMenuLayout extends SingleChildLayoutDelegate {
  _SelectionMenuLayout({
    required this.viewport,
    required this.point,
    required this.cellHeight,
  });

  final Rect viewport;
  final Offset point;
  final double cellHeight;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final visible = viewport.intersect(Offset.zero & constraints.biggest);
    return BoxConstraints.loose(
      Size(math.max(0, visible.width), math.max(0, visible.height)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final visible = viewport.intersect(Offset.zero & size);
    final below = point.dy + cellHeight + 48 + 8;
    final above = point.dy - childSize.height - 48 - 8;
    final y = below + childSize.height <= visible.bottom ? below : above;
    return Offset(
      point.dx.clamp(
        visible.left,
        math.max(visible.left, visible.right - childSize.width),
      ),
      y.clamp(
        visible.top,
        math.max(visible.top, visible.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_SelectionMenuLayout oldDelegate) =>
      viewport != oldDelegate.viewport ||
      point != oldDelegate.point ||
      cellHeight != oldDelegate.cellHeight;
}
