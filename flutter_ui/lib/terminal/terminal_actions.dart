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
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:xterm2/xterm.dart';
import '../tilde_design.dart';
import '../tilde_controls.dart';
import '../l10n/strings.dart';

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
    this.magnifyCursor = false,
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
  final bool magnifyCursor;

  @override
  State<TerminalActions> createState() => _TerminalActionsState();
}

class _TerminalActionsState extends State<TerminalActions> {
  final _stackKey = GlobalKey();
  Timer? _longPressTimer;
  Offset? _pressOrigin;
  final _pressedPointers = <int>{};
  Offset? _contextPoint;
  ScrollPosition? _scrollPosition;
  CellOffset? _touchedCell;
  final _overflow = MenuController();
  bool _refreshPending = false;
  bool _forceRefresh = false;
  bool _draggingHandle = false;
  bool _blockMode = false;
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
      _overflow.close();
    }
    if (!widget.enabled ||
        !widget.inputEnabled ||
        oldWidget.terminal != widget.terminal ||
        oldWidget.controller != widget.controller ||
        oldWidget.terminalViewKey != widget.terminalViewKey) {
      _stopHandleScroll();
      _draggingHandle = false;
      _handleDragOffset = null;
      _touchedCell = null;
      _overflow.close();
      _geometry = null;
      _longPressTimer?.cancel();
      _contextPoint = null;
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
          _overflow.close();
          _touchedCell = null;
        }
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  ({Rect viewport, Offset begin, Offset end, double cellHeight})?
  _measureGeometry() {
    final selection = _selection;
    final view = widget.terminalViewKey.currentState;
    final render = view?.renderTerminal;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if ((selection == null && !widget.magnifyCursor) ||
        render == null ||
        !render.hasSize ||
        stack == null ||
        !stack.hasSize) {
      return null;
    }
    final origin = render.localToGlobal(Offset.zero, ancestor: stack);
    if (selection == null) {
      final cursor = stack.globalToLocal(view!.globalCursorRect.center);
      return (
        viewport: (origin & render.size).intersect(Offset.zero & stack.size),
        begin: cursor,
        end: cursor,
        cellHeight: render.cellSize.height,
      );
    }
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
    _longPressTimer?.cancel();
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
    setState(() => _contextPoint = null);
    widget.controller.clearSelection();
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _edit() async {
    if (!widget.inputEnabled) return;
    final text = _selectedText();
    if (text == null) return;
    setState(() => _contextPoint = null);
    widget.controller.clearSelection();
    await widget.onEdit(text);
  }

  Future<void> _paste() async {
    if (!widget.enabled || !widget.inputEnabled) return;
    setState(() => _contextPoint = null);
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

  Widget _menu() {
    final selected = _selection != null && !_selection!.isCollapsed;
    final colors = Theme.of(context).colorScheme;
    final actionStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      foregroundColor: colors.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
    Widget action(String label, IconData icon, VoidCallback onPressed) =>
        TextButton(
          onPressed: onPressed,
          style: actionStyle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(icon, size: 18),
              Text(label, maxLines: 1, softWrap: false),
            ],
          ),
        );
    Widget option(
      String label,
      IconData icon,
      VoidCallback onPressed, {
      Widget? trailing,
    }) => MenuItemButton(
      leadingIcon: Icon(icon, size: 20),
      trailingIcon: trailing,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14),
        ),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStatePropertyAll(colors.onSurface),
        iconColor: WidgetStatePropertyAll(colors.onSurfaceVariant),
        textStyle: WidgetStatePropertyAll(
          Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
        ),
      ),
      onPressed: widget.enabled ? onPressed : null,
      child: Text(label),
    );
    return ExcludeFocus(
      child: MenuAnchor(
        controller: _overflow,
        consumeOutsideTap: true,
        crossAxisUnconstrained: false,
        alignmentOffset: const Offset(-212, 6),
        style: MenuStyle(
          alignment: Alignment.bottomRight,
          fixedSize: const WidgetStatePropertyAll(Size.fromWidth(212)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
          backgroundColor: WidgetStatePropertyAll(
            colors.surfaceContainerHighest,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: const WidgetStatePropertyAll(BorderSide.none),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        onOpen: () => setState(() {}),
        onClose: () {
          if (mounted) setState(() {});
        },
        menuChildren: [
          option(context.l10n.selectEntireLine, Icons.segment, _selectLine),
          option(
            context.l10n.selectVisibleScreen,
            Icons.crop_free,
            _selectVisible,
          ),
          option(
            context.l10n.selectAll,
            Icons.select_all,
            () => _selectRows(0, widget.terminal.buffer.height - 1),
          ),
          const Divider(height: 13),
          option(
            context.l10n.blockSelection,
            Icons.view_column_outlined,
            () => widget.controller.setSelectionMode(
              widget.controller.selectionMode == SelectionMode.block
                  ? SelectionMode.line
                  : SelectionMode.block,
            ),
            trailing: widget.controller.selectionMode == SelectionMode.block
                ? Icon(Icons.check, color: colors.primary, size: 18)
                : null,
          ),
          if (widget.onShare != null) ...[
            const Divider(height: 13),
            option(context.l10n.share, Icons.share_outlined, () {
              final text = _selectedText();
              if (text == null) return;
              setState(() => _contextPoint = null);
              widget.controller.clearSelection();
              widget.onShare!(text);
            }),
          ],
        ],
        builder: (context, menu, child) => Material(
          key: const ValueKey('terminal-selection-menu'),
          elevation: 4,
          borderRadius: BorderRadius.circular(selected ? 12 : 20),
          clipBehavior: Clip.antiAlias,
          color: colors.surfaceContainerHighest,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4,
              vertical: selected ? 4 : 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 2,
                      children: [
                        if (widget.inputEnabled)
                          action(
                            context.l10n.paste,
                            Icons.content_paste_outlined,
                            () => unawaited(_paste()),
                          ),
                        if (selected) ...[
                          action(
                            context.l10n.copy2,
                            Icons.content_copy_outlined,
                            () => unawaited(_copy()),
                          ),
                          if (widget.inputEnabled)
                            action(
                              context.l10n.editAndSend,
                              Icons.send_outlined,
                              () => unawaited(_edit()),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (selected) ...[
                  SizedBox(
                    height: 20,
                    child: VerticalDivider(
                      width: 1,
                      color: colors.outlineVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.moreSelectionOptions,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(36, 36),
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: menu.isOpen
                          ? colors.primaryContainer
                          : null,
                      foregroundColor: menu.isOpen
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                    icon: const Icon(Icons.more_vert, size: 20),
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
    const knobSize = 14.0;
    final centerY = extent
        ? point.dy + cellHeight + knobSize / 2
        : point.dy - knobSize / 2;
    final top = centerY - 24;
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
        label: extent ? context.l10n.selectionEnd : context.l10n.selectionStart,
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
            if (widget.enabled) {
              _overflow.close();
              setState(() {
                _dragExtent = extent;
                _draggingHandle = true;
              });
            }
          },
          onPanUpdate: (details) =>
              _updateHandleDrag(extent, details.globalPosition),
          onPanEnd: (_) => _finishHandleDrag(),
          onPanCancel: _finishHandleDrag,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.circle,
                size: knobSize,
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

  Widget _magnifier(Offset focalPoint, Rect viewport) {
    const lens = Size(120, 56);
    final left = (focalPoint.dx - lens.width / 2)
        .clamp(
          viewport.left,
          math.max(viewport.left, viewport.right - lens.width),
        )
        .toDouble();
    final top = (focalPoint.dy - lens.height - 24)
        .clamp(
          viewport.top,
          math.max(viewport.top, viewport.bottom - lens.height),
        )
        .toDouble();
    final center = Offset(left + lens.width / 2, top + lens.height / 2);
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RawMagnifier(
            size: lens,
            magnificationScale: 1.75,
            focalPointOffset: focalPoint - center,
            clipBehavior: Clip.hardEdge,
            decoration: MagnifierDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          onPointerUp: _releasePointer,
          onPointerCancel: _releasePointer,
          child: widget.child,
        ),
        if (!tildePointer(context) &&
            widget.enabled &&
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
                  point: Offset(
                    (geometry.begin.dx + geometry.end.dx) / 2,
                    math.min(geometry.begin.dy, geometry.end.dy),
                  ),
                  cellHeight:
                      (geometry.begin.dy - geometry.end.dy).abs() +
                      geometry.cellHeight,
                ),
                child: _menu(),
              ),
            ),
        ],
        if (!tildePointer(context) &&
            widget.enabled &&
            widget.inputEnabled &&
            (selection == null || selection.isCollapsed) &&
            _contextPoint != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => CustomSingleChildLayout(
                delegate: _SelectionMenuLayout(
                  viewport: Offset.zero & constraints.biggest,
                  point: _contextPoint!,
                  cellHeight: 0,
                ),
                child: _menu(),
              ),
            ),
          ),
        if (widget.enabled &&
            geometry != null &&
            (_draggingHandle || widget.magnifyCursor))
          _magnifier(
            _draggingHandle
                ? (_dragExtent ? geometry.end : geometry.begin) +
                      Offset(0, geometry.cellHeight / 2)
                : geometry.begin,
            geometry.viewport,
          ),
      ],
    );
  }

  void _releasePointer(PointerEvent event) {
    _pressedPointers.remove(event.pointer);
    _longPressTimer?.cancel();
  }

  Future<void> _pointerMenu(Offset position) async {
    final contextStrings = context.l10n;
    final selected = _selection != null && !_selection!.isCollapsed;
    final action = await TildeItemMenu.show<String>(
      context,
      title: '',
      icon: Icons.terminal_outlined,
      position: position,
      itemBuilder: (_) => [
        if (selected)
          PopupMenuItem(
            value: 'copy',
            child: TildeMenuLabel(
              contextStrings.copy2,
              Icons.content_copy_outlined,
              shortcut: 'Ctrl Shift C',
            ),
          ),
        if (widget.inputEnabled)
          PopupMenuItem(
            value: 'paste',
            child: TildeMenuLabel(
              contextStrings.paste,
              Icons.content_paste_outlined,
              shortcut: 'Ctrl Shift V',
            ),
          ),
        if (selected && widget.inputEnabled)
          PopupMenuItem(
            value: 'edit',
            child: TildeMenuLabel(
              contextStrings.editAndSend,
              Icons.edit_note_outlined,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'all',
          child: TildeMenuLabel(contextStrings.selectAll, Icons.select_all),
        ),
        PopupMenuItem(
          value: 'block',
          child: TildeMenuLabel(
            contextStrings.blockSelection,
            Icons.view_column_outlined,
            selected: _blockMode,
            shortcut: contextStrings.altDrag,
          ),
        ),
        if (selected)
          PopupMenuItem(
            value: 'clear',
            child: TildeMenuLabel(
              contextStrings.clearSelection,
              Icons.close,
              shortcut: 'Esc',
            ),
          ),
      ],
    );
    if (!mounted || !widget.enabled) return;
    switch (action) {
      case 'copy':
        await _copy();
      case 'paste':
        await _paste();
      case 'edit':
        await _edit();
      case 'all':
        _selectRows(0, widget.terminal.buffer.height - 1);
      case 'clear':
        widget.controller.clearSelection();
      case 'block':
        _blockMode = !_blockMode;
        widget.controller.setSelectionMode(
          _blockMode ? SelectionMode.block : SelectionMode.line,
        );
    }
  }

  void _recordPointer(PointerEvent event) {
    if (tildePointer(context)) {
      if (event is PointerDownEvent && widget.enabled) {
        if (event.buttons == kSecondaryMouseButton) {
          unawaited(_pointerMenu(event.position));
        }
        if (event.buttons == kPrimaryMouseButton) {
          widget.controller.setSelectionMode(
            _blockMode || HardwareKeyboard.instance.isAltPressed
                ? SelectionMode.block
                : SelectionMode.line,
          );
        }
      }
      return;
    }
    if (event is PointerDownEvent) {
      _pressedPointers.add(event.pointer);
      _longPressTimer?.cancel();
      _pressOrigin = event.position;
      if (_contextPoint != null) setState(() => _contextPoint = null);
      if (widget.enabled &&
          widget.inputEnabled &&
          _pressedPointers.length == 1 &&
          event.buttons == kPrimaryButton) {
        _longPressTimer = Timer(kLongPressTimeout, () {
          if (!mounted) return;
          final box =
              _stackKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          setState(() => _contextPoint = box.globalToLocal(event.position));
        });
      }
    } else if (_pressOrigin != null &&
        (event.position - _pressOrigin!).distance > kTouchSlop) {
      _longPressTimer?.cancel();
    }
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
    final visible = viewport
        .intersect(Offset.zero & constraints.biggest)
        .deflate(8);
    return BoxConstraints.loose(
      Size(math.max(0, visible.width), math.max(0, visible.height)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final visible = viewport.intersect(Offset.zero & size).deflate(8);
    final below = point.dy + cellHeight + 18;
    final above = point.dy - childSize.height - 18;
    final y = below + childSize.height <= visible.bottom ? below : above;
    return Offset(
      (point.dx - childSize.width / 2).clamp(
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
