// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:xterm2/xterm.dart';
import 'image_decoder.dart';
import 'inline_images.dart';

class InlineImageTerminal extends Terminal {
  InlineImageTerminal({
    super.maxLines,
    super.onOutput,
    super.onResize,
    super.platform,
    super.reflowEnabled,
    super.reflowWithHiddenCursor,
    InlineImagePolicy imagePolicy = InlineImagePolicy.ask,
    InlineImageLimits imageLimits = const InlineImageLimits(),
  }) {
    images = InlineImageRuntime(this, imagePolicy, imageLimits);
  }
  late final InlineImageRuntime images;
  bool _reserving = false, _isoProtection = false, _writingText = false;
  static final _widthCell = BufferLine(1);

  /// Queues ordered input; throws StateError when pending input exceeds limits.
  @override
  void write(String data) => images.write(data);
  void _writeText(String data) {
    _writingText = true;
    try {
      super.write(data);
      images.synchronize();
    } finally {
      _writingText = false;
    }
  }

  @override
  void writeText(String text, int start, int end) {
    if (!_reserving &&
        images.store.placements.any(
          (p) => !p.virtual && p.alternate == isUsingAltBuffer,
        )) {
      for (var i = start; i < end; i++) {
        writeChar(text.codeUnitAt(i));
      }
    } else {
      super.writeText(text, start, end);
    }
  }

  @override
  void writeChar(int char) {
    final x = buffer.cursorX;
    final y = buffer.absoluteCursorY;
    _widthCell.setCodePoint(0, char);
    final width = _widthCell.getWidth(0);
    final inMargin =
        buffer.isInVerticalMargin && buffer.isInHorizontalMarginOrPendingWrap;
    final top = inMargin ? buffer.marginTop : 0;
    final bottom = inMargin ? buffer.marginBottom + 1 : viewHeight;
    final firstLine = buffer.lines[top + buffer.scrollBack];
    final pushed = buffer.lines.pushCount;
    super.writeChar(char);
    if (firstLine != buffer.lines[top + buffer.scrollBack] ||
        pushed != buffer.lines.pushCount) {
      images.store.scroll(
        InlineImageRect(
          inMargin ? buffer.marginLeft : 0,
          top,
          inMargin ? buffer.marginRight + 1 : viewWidth,
          bottom,
        ),
        1,
        0,
      );
      images.releaseAnchors();
    }
    if (_reserving || width == 0) return;
    images.synchronize();
    final start = buffer.absoluteCursorY != y || buffer.cursorX < x
        ? math.max(buffer.marginLeft, buffer.cursorX - width)
        : x;
    images.edit(
      InlineImageRect(start, buffer.cursorY, start + width, buffer.cursorY + 1),
    );
  }

  void _reserve(InlineImageResult result) {
    if (result.rows == 0) return;
    _reserving = true;
    final x = buffer.cursorX;
    try {
      for (var row = 0; row < result.rows; row++) {
        if (result.iterm) {
          for (
            var col = x;
            col < math.min(viewWidth, x + result.columns);
            col++
          ) {
            buffer.currentLine.setCell(col, 32, 1, cursor);
          }
        }
        if (row + 1 < result.rows) {
          index();
          images.synchronize();
        }
      }
      buffer.setCursorX(math.min(viewWidth - 1, x + result.columns));
    } finally {
      _reserving = false;
    }
  }

  void _erase(
    int left,
    int top,
    int right,
    int bottom, {
    bool selective = false,
    bool protection = true,
  }) {
    if (!selective && (!protection || !_isoProtection)) {
      images.edit(InlineImageRect(left, top, right, bottom));
      return;
    }
    for (var y = math.max(0, top); y < math.min(viewHeight, bottom); y++) {
      final line = buffer.lines[y + buffer.scrollBack];
      var x = math.max(0, left);
      while (x < math.min(viewWidth, right)) {
        if (line.isProtected(x)) {
          x++;
          continue;
        }
        final first = x++;
        while (x < math.min(viewWidth, right) && !line.isProtected(x)) {
          x++;
        }
        images.edit(InlineImageRect(first, y, x, y + 1));
      }
    }
  }

  @override
  void setProtectedMode(bool enabled) {
    if (enabled) _isoProtection = false;
    super.setProtectedMode(enabled);
  }

  @override
  void setIsoProtectedMode(bool enabled) {
    if (enabled) _isoProtection = true;
    super.setIsoProtectedMode(enabled);
  }

  @override
  void eraseLineRightSelective() {
    _erase(
      buffer.cursorX,
      buffer.cursorY,
      viewWidth,
      buffer.cursorY + 1,
      selective: true,
    );
    super.eraseLineRightSelective();
  }

  @override
  void eraseLineLeftSelective() {
    _erase(
      0,
      buffer.cursorY,
      buffer.cursorX + 1,
      buffer.cursorY + 1,
      selective: true,
    );
    super.eraseLineLeftSelective();
  }

  @override
  void eraseLineSelective() {
    _erase(0, buffer.cursorY, viewWidth, buffer.cursorY + 1, selective: true);
    super.eraseLineSelective();
  }

  @override
  void eraseDisplayBelowSelective() {
    _erase(
      buffer.cursorX,
      buffer.cursorY,
      viewWidth,
      buffer.cursorY + 1,
      selective: true,
    );
    _erase(0, buffer.cursorY + 1, viewWidth, viewHeight, selective: true);
    super.eraseDisplayBelowSelective();
  }

  @override
  void eraseDisplayAboveSelective() {
    _erase(0, 0, viewWidth, buffer.cursorY, selective: true);
    _erase(
      0,
      buffer.cursorY,
      buffer.cursorX + 1,
      buffer.cursorY + 1,
      selective: true,
    );
    super.eraseDisplayAboveSelective();
  }

  @override
  void eraseDisplaySelective() {
    _erase(0, 0, viewWidth, viewHeight, selective: true);
    super.eraseDisplaySelective();
  }

  @override
  void eraseLineRight() {
    _erase(buffer.cursorX, buffer.cursorY, viewWidth, buffer.cursorY + 1);
    super.eraseLineRight();
  }

  @override
  void eraseLineLeft() {
    _erase(0, buffer.cursorY, buffer.cursorX + 1, buffer.cursorY + 1);
    super.eraseLineLeft();
  }

  @override
  void eraseLine() {
    _erase(0, buffer.cursorY, viewWidth, buffer.cursorY + 1);
    super.eraseLine();
  }

  @override
  void eraseChars(int amount) {
    _erase(
      buffer.cursorX,
      buffer.cursorY,
      math.min(viewWidth, buffer.cursorX + amount),
      buffer.cursorY + 1,
    );
    super.eraseChars(amount);
  }

  @override
  void eraseDisplayBelow() {
    _erase(buffer.cursorX, buffer.cursorY, viewWidth, buffer.cursorY + 1);
    _erase(0, buffer.cursorY + 1, viewWidth, viewHeight);
    super.eraseDisplayBelow();
  }

  @override
  void eraseDisplayAbove() {
    _erase(0, 0, viewWidth, buffer.cursorY);
    _erase(0, buffer.cursorY, buffer.cursorX + 1, buffer.cursorY + 1);
    super.eraseDisplayAbove();
  }

  @override
  void eraseDisplay() {
    images.store.clearScreen();
    images.releaseAnchors();
    super.eraseDisplay();
    images.synchronize();
  }

  @override
  void eraseScrollbackOnly() {
    super.eraseScrollbackOnly();
    images.synchronize();
  }

  @override
  void eraseRect(int top, int left, int bottom, int right) {
    final rect = _rect(top, left, bottom, right);
    if (rect != null) _erase(rect.left, rect.top, rect.right, rect.bottom);
    super.eraseRect(top, left, bottom, right);
  }

  @override
  void fillRect(int char, int top, int left, int bottom, int right) {
    final rect = _rect(top, left, bottom, right);
    if (rect != null) {
      _erase(rect.left, rect.top, rect.right, rect.bottom, protection: false);
    }
    super.fillRect(char, top, left, bottom, right);
  }

  InlineImageRect? _rect(int top, int left, int bottom, int right) {
    final dy = originMode ? buffer.marginTop : 0;
    final dx = originMode ? buffer.marginLeft : 0;
    final maxY = originMode ? buffer.marginBottom : viewHeight - 1;
    final maxX = originMode ? buffer.marginRight : viewWidth - 1;
    final t = (dy + math.max(1, top) - 1).clamp(0, maxY).toInt();
    final l = (dx + math.max(1, left) - 1).clamp(0, maxX).toInt();
    final b = (dy + math.max(1, bottom) - 1).clamp(0, maxY).toInt();
    final r = (dx + math.max(1, right) - 1).clamp(0, maxX).toInt();
    return t > b || l > r ? null : InlineImageRect(l, t, r + 1, b + 1);
  }

  @override
  void selectiveEraseRect(int top, int left, int bottom, int right) {
    final rect = _rect(top, left, bottom, right);
    if (rect != null) {
      _erase(rect.left, rect.top, rect.right, rect.bottom, selective: true);
    }
    super.selectiveEraseRect(top, left, bottom, right);
  }

  @override
  void screenAlignmentTest() {
    _erase(0, 0, viewWidth, viewHeight, protection: false);
    super.screenAlignmentTest();
  }

  void _scroll(
    int top,
    int bottom,
    int left,
    int right,
    int down,
    int across,
    void Function() action,
  ) {
    images.synchronize();
    down = down.clamp(-(bottom - top), bottom - top);
    across = across.clamp(-(right - left), right - left);
    images.store.scroll(
      InlineImageRect(left, top, right, bottom),
      down,
      across,
    );
    images.releaseAnchors();
    action();
    images.synchronize();
  }

  void _index(void Function() action, {bool reverse = false}) {
    final b = buffer;
    if (b.isInVerticalMargin &&
        b.isInHorizontalMarginOrPendingWrap &&
        b.cursorY == (reverse ? b.marginTop : b.marginBottom)) {
      _scroll(
        b.marginTop,
        b.marginBottom + 1,
        b.marginLeft,
        b.marginRight + 1,
        reverse ? -1 : 1,
        0,
        action,
      );
    } else if (!reverse &&
        !b.isInVerticalMargin &&
        b.cursorY == viewHeight - 1) {
      _scroll(0, viewHeight, 0, viewWidth, 1, 0, action);
    } else {
      action();
    }
  }

  @override
  void index() => _index(super.index);
  @override
  void lineFeed() => _index(super.lineFeed);
  @override
  void nextLine() => _index(super.nextLine);
  @override
  void reverseIndex() => _index(super.reverseIndex, reverse: true);
  @override
  void scrollUp(int amount) => _scroll(
    buffer.marginTop,
    buffer.marginBottom + 1,
    buffer.marginLeft,
    buffer.marginRight + 1,
    amount,
    0,
    () => super.scrollUp(amount),
  );
  @override
  void scrollDown(int amount) => _scroll(
    buffer.marginTop,
    buffer.marginBottom + 1,
    buffer.marginLeft,
    buffer.marginRight + 1,
    -amount,
    0,
    () => super.scrollDown(amount),
  );
  @override
  void insertLines(int amount) {
    if (!buffer.isInVerticalMargin || !buffer.isInHorizontalMargin) {
      super.insertLines(amount);
      return;
    }
    _scroll(
      buffer.cursorY,
      buffer.marginBottom + 1,
      buffer.marginLeft,
      buffer.marginRight + 1,
      -amount,
      0,
      () => super.insertLines(amount),
    );
  }

  @override
  void deleteLines(int amount) {
    if (!buffer.isInVerticalMargin || !buffer.isInHorizontalMargin) {
      super.deleteLines(amount);
      return;
    }
    _scroll(
      buffer.cursorY,
      buffer.marginBottom + 1,
      buffer.marginLeft,
      buffer.marginRight + 1,
      amount,
      0,
      () => super.deleteLines(amount),
    );
  }

  @override
  void deleteChars(int amount) => _scroll(
    buffer.cursorY,
    buffer.cursorY + 1,
    buffer.cursorX,
    buffer.marginRight + 1,
    0,
    amount,
    () => super.deleteChars(amount),
  );
  @override
  void insertBlankChars(int amount) => _scroll(
    buffer.cursorY,
    buffer.cursorY + 1,
    buffer.cursorX,
    buffer.marginRight + 1,
    0,
    -amount,
    () => super.insertBlankChars(amount),
  );
  @override
  void insertColumns(int amount) {
    if (!buffer.isInVerticalMargin || !buffer.isInHorizontalMargin) {
      super.insertColumns(amount);
      return;
    }
    _scroll(
      buffer.marginTop,
      buffer.marginBottom + 1,
      buffer.cursorX,
      buffer.marginRight + 1,
      0,
      -amount,
      () => super.insertColumns(amount),
    );
  }

  @override
  void deleteColumns(int amount) {
    if (!buffer.isInVerticalMargin || !buffer.isInHorizontalMargin) {
      super.deleteColumns(amount);
      return;
    }
    _scroll(
      buffer.marginTop,
      buffer.marginBottom + 1,
      buffer.cursorX,
      buffer.marginRight + 1,
      0,
      amount,
      () => super.deleteColumns(amount),
    );
  }

  @override
  void backIndex() {
    if (buffer.cursorX > 0 &&
        buffer.cursorX == buffer.marginLeft &&
        buffer.isInVerticalMargin) {
      _scroll(
        buffer.marginTop,
        buffer.marginBottom + 1,
        buffer.marginLeft,
        buffer.marginRight + 1,
        0,
        -1,
        super.backIndex,
      );
    } else {
      super.backIndex();
    }
  }

  @override
  void forwardIndex() {
    if (buffer.cursorX < viewWidth - 1 &&
        buffer.cursorX == buffer.marginRight &&
        buffer.isInVerticalMargin) {
      _scroll(
        buffer.marginTop,
        buffer.marginBottom + 1,
        buffer.marginLeft,
        buffer.marginRight + 1,
        0,
        1,
        super.forwardIndex,
      );
    } else {
      super.forwardIndex();
    }
  }

  @override
  void resize(
    int newWidth,
    int newHeight, [
    int? pixelWidth,
    int? pixelHeight,
  ]) {
    super.resize(newWidth, newHeight, pixelWidth, pixelHeight);
    images.store.rows = viewHeight;
    images.store.cols = viewWidth;
    if ((pixelWidth ?? 0) > 0 && (pixelHeight ?? 0) > 0) {
      images.store.updateCellSize(pixelWidth!, pixelHeight!);
    }
    images.synchronize();
  }

  @override
  void useAltBuffer() {
    super.useAltBuffer();
    images.store.alternate = true;
    images.synchronize();
  }

  @override
  void useMainBuffer() {
    super.useMainBuffer();
    images.store.alternate = false;
    images.synchronize();
  }

  @override
  void clearAltBuffer() {
    images.clearScreen(true);
    super.clearAltBuffer();
  }

  @override
  void clear() {
    images.reset();
    super.clear();
  }

  @override
  void reset() {
    _isoProtection = false;
    images.reset(cancelQueued: !_writingText);
    super.reset();
  }

  @override
  void softReset() {
    _isoProtection = false;
    super.softReset();
  }

  @override
  void dispose() {
    images.dispose();
    super.dispose();
  }
}

class _ImageAnchor {
  _ImageAnchor(this.start, this.end, this.row, this.left, this.right);
  final CellAnchor start, end;
  final int row;
  int left, right;
  void dispose() {
    start.dispose();
    end.dispose();
  }
}

class InlineImageRuntime extends ChangeNotifier {
  InlineImageRuntime(
    this.terminal,
    InlineImagePolicy policy,
    InlineImageLimits limits,
  ) {
    final budget = InlineImageBudget(limits);
    _protocol = AsyncInlineImageProtocol(budget: budget, policy: policy);
    store = InlineImageStore(
      budget: budget,
      onReply: (s) => terminal.onOutput?.call(s),
      onChanged: _changed,
    );
    decoder = InlineImageDecoder(
      budget,
      canDecode: () => !_protocol.isBusy,
      waitForInput: () => _queue,
    )..addListener(_redraw);
    paintExtension = TerminalPaintExtension(
      beforeCellBackgrounds: (c) {
        _viewport(c);
        _paint(c, (z) => z < -1073741824);
      },
      beforeCellForegrounds: (c) => _paint(c, (z) => z >= -1073741824 && z < 0),
      afterCellForegrounds: (c) => _paint(c, (z) => z >= 0),
      cellForegroundFilter: (line, col) =>
          line.getCodePoint(col) != KittyPlaceholder.codePoint,
      repaint: this,
    );
    _timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (_disposed || store.assets.isEmpty) return;
      final now = _clock.elapsedMilliseconds;
      final before = store.assets.values.fold(
        0,
        (int n, a) => n + a.generation,
      );
      store.advanceAnimations(now);
      decoder.advance(now);
      if (before !=
          store.assets.values.fold(0, (int n, a) => n + a.generation)) {
        _redraw();
      }
    });
  }
  final InlineImageTerminal terminal;
  late AsyncInlineImageProtocol _protocol;
  late final InlineImageStore store;
  late final InlineImageDecoder decoder;
  late final TerminalPaintExtension paintExtension;
  late final Timer _timer;
  final _clock = Stopwatch()..start();
  final _anchors = <InlineImagePlacement, List<_ImageAnchor>>{};
  final _placeholders = <int, List<InlineImageSlice>>{};
  Future<void> _queue = Future.value();
  bool _disposed = false, _syncing = false;
  int _epoch = 0, _pendingInputBytes = 0, _pendingInputChunks = 0;
  Future<void> get drained async {
    await _queue;
    await decoder.drained;
  }

  InlineImagePolicy get policy => _protocol.policy;
  set policy(InlineImagePolicy value) {
    if (_disposed || value == policy) return;
    reset();
    _protocol.policy = value;
  }

  Set<InlineImageSource> get pendingConsent => store.pendingConsent;
  void decide(InlineImageSource source, bool allowed) {
    if (!_disposed && pendingConsent.contains(source)) {
      source.decide(allowed);
      synchronize();
      _redraw();
    }
  }

  void write(String data) {
    if (_disposed || data.isEmpty) return;
    final bytes = data.length * 2;
    if (bytes > store.limits.pendingInputBytes - _pendingInputBytes ||
        _pendingInputChunks >= store.limits.pendingInputChunks) {
      throw StateError('Terminal input queue limit exceeded');
    }
    _pendingInputBytes += bytes;
    _pendingInputChunks++;
    final epoch = _epoch;
    _queue = _queue
        .then((_) async {
          if (_disposed || epoch != _epoch) return;
          final events = await _protocol.feed(data);
          if (_disposed || epoch != _epoch) {
            for (final event in events.whereType<InlineImageCommand>()) {
              event.dispose();
            }
            return;
          }
          for (final event in events) {
            switch (event) {
              case InlineImageText():
                terminal._writeText(event.text);
              case InlineImageReply():
                terminal.onOutput?.call(event.text);
              case InlineImageCommand():
                synchronize();
                final result = store.apply(
                  event,
                  row: terminal.buffer.cursorY,
                  col: terminal.buffer.cursorX,
                );
                _attach();
                terminal._reserve(result);
                synchronize();
            }
          }
          _changed();
          terminal.notifyListeners();
        })
        .whenComplete(() {
          _pendingInputBytes -= bytes;
          _pendingInputChunks--;
        });
  }

  void _changed() {
    if (_disposed) return;
    decoder.retain(store.assets.values.expand((a) => a.frames));
    _redraw();
  }

  void _redraw() {
    if (!_disposed) notifyListeners();
  }

  Buffer _buffer(bool alternate) =>
      alternate ? terminal.altBuffer : terminal.mainBuffer;

  void _attach() {
    for (final p in store.placements) {
      if (p.virtual || p.parent != null) continue;
      final buffer = _buffer(p.alternate);
      final list = _anchors[p] ??= <_ImageAnchor>[];
      for (var row = 0; row < p.height; row++) {
        final y = p.top + row + buffer.scrollBack;
        if (y < 0 || y >= buffer.height) continue;
        final ranges = p.iterm ? p.coverage[row] : [(p.left, p.left + p.width)];
        for (final (left, right) in ranges) {
          if (list.any(
            (a) =>
                a.row == row &&
                a.left == left &&
                a.right == right &&
                a.start.attached &&
                a.end.attached,
          )) {
            continue;
          }
          final first = left.clamp(0, terminal.viewWidth - 1);
          final last = (right - 1).clamp(0, terminal.viewWidth - 1);
          list.add(
            _ImageAnchor(
              buffer.createAnchor(first, y),
              buffer.createAnchor(last, y),
              row,
              left,
              right,
            ),
          );
        }
      }
      _anchors[p] = list;
    }
  }

  void synchronize() {
    if (_disposed || _syncing) return;
    _syncing = true;
    try {
      for (final p in _anchors.keys.toList()) {
        final list = _anchors[p]!;
        if (!store.placements.contains(p)) {
          for (final a in list) {
            a.dispose();
          }
          _anchors.remove(p);
          continue;
        }
        final live = list
            .where((a) => a.start.attached && a.end.attached)
            .toList();
        if (live.isEmpty) {
          store.placements.remove(p);
          for (final a in list) {
            a.dispose();
          }
          _anchors.remove(p);
          continue;
        }
        final buffer = _buffer(p.alternate);
        final first = live.first;
        final top = first.start.y - buffer.scrollBack - first.row;
        final left = first.start.x - (first.left - p.left);
        if (p.iterm &&
            live.any(
              (a) =>
                  a.start.y - buffer.scrollBack != top + a.row ||
                  a.start.x - a.left != left - p.left ||
                  a.end.y != a.start.y ||
                  a.end.x - a.start.x + 1 != a.right - a.left,
            )) {
          store.placements.remove(p);
          for (final a in live) {
            var sourceCol = p.sourceCol + a.left - p.left;
            for (var y = a.start.y; y <= a.end.y; y++) {
              final l = y == a.start.y ? a.start.x : 0;
              final r = y == a.end.y ? a.end.x + 1 : terminal.viewWidth;
              if (l >= r ||
                  store.placements.length >= store.limits.maxPlacements) {
                continue;
              }
              store.placements.add(
                InlineImagePlacement(
                  asset: p.asset,
                  id: p.id,
                  top: y - buffer.scrollBack,
                  left: l,
                  width: r - l,
                  height: 1,
                  crop: p.crop,
                  z: p.z,
                  iterm: true,
                  alternate: p.alternate,
                  offsetX: p.offsetX,
                  offsetY: p.offsetY,
                  renderWidth: p.renderWidth,
                  renderHeight: p.renderHeight,
                  sourceRow: p.sourceRow + a.row,
                  sourceCol: sourceCol,
                  naturalSize: p.naturalSize,
                ),
              );
              sourceCol += r - l;
            }
          }
          for (final a in list) {
            a.dispose();
          }
          _anchors.remove(p);
        } else {
          final dx = left - p.left;
          p.top = top;
          p.left = left;
          if (dx != 0) {
            if (p.iterm) {
              p.coverage = p.coverage
                  .map((r) => r.map((s) => (s.$1 + dx, s.$2 + dx)).toList())
                  .toList();
            }
            for (final a in list) {
              a.left += dx;
              a.right += dx;
            }
          }
          if (first.row > p.clipTop) p.clipTop = first.row;
        }
      }
      store.rows = terminal.viewHeight;
      store.cols = terminal.viewWidth;
      store.alternate = terminal.isUsingAltBuffer;
      store.trimHistory(terminal.mainBuffer.scrollBack);
      _attach();
      _scanPlaceholders();
      decoder.retain(store.assets.values.expand((a) => a.frames));
    } finally {
      _syncing = false;
    }
  }

  void edit(InlineImageRect rect) {
    if (_disposed) return;
    synchronize();
    store.edit(rect);
    releaseAnchors();
    _attach();
  }

  void releaseAnchors() {
    for (final list in _anchors.values) {
      for (final a in list) {
        a.dispose();
      }
    }
    _anchors.clear();
  }

  void clearScreen(bool alternate) {
    store.placements.removeWhere((p) => p.alternate == alternate);
    releaseAnchors();
    synchronize();
  }

  void reset({bool cancelQueued = true}) {
    if (_disposed) return;
    if (cancelQueued) {
      _epoch++;
      final old = _protocol;
      _protocol = AsyncInlineImageProtocol(
        budget: store.budget,
        policy: old.policy,
      );
      old.dispose();
    }
    // In-band RIS has already passed through the worker; its subsequent partial
    // upload belongs to later input and must survive the display reset.
    releaseAnchors();
    store.clear();
    decoder.retain(const []);
    _placeholders.clear();
  }

  void _scanPlaceholders() {
    _placeholders.clear();
    store.placeholderAnchors.clear();
    if (!store.placements.any((p) => p.virtual)) return;
    final buffer = terminal.buffer;
    var origins = 0;
    for (var y = 0; y < buffer.height; y++) {
      final line = buffer.lines[y];
      (int, int, int, int, int)? previous;
      for (var x = 0; x < line.length; x++) {
        if (line.getCodePoint(x) != KittyPlaceholder.codePoint) {
          previous = null;
          continue;
        }
        final image = line.getForeground(x) & CellColor.valueMask;
        final placement = line.getUnderlineColor(x) & CellColor.valueMask;
        final marks = (line.getCombiningCharacters(x) ?? '').runes
            .map(KittyPlaceholder.index)
            .toList();
        final prev = previous?.$1 == image && previous?.$2 == placement
            ? previous
            : null;
        final row = marks.isNotEmpty ? marks[0] : prev?.$3 ?? 0;
        final col = marks.length > 1
            ? marks[1]
            : prev?.$3 == row
            ? prev!.$4 + 1
            : 0;
        final high = marks.length > 2
            ? marks[2]
            : prev?.$3 == row && prev!.$4 + 1 == col
            ? prev.$5
            : 0;
        previous = (image, placement, row, col, high);
        if (row < 0 || col < 0 || high < 0 || high > 255) continue;
        final id = image | (high << 24);
        InlineImagePlacement? found;
        for (final p in store.placements) {
          if (p.virtual &&
              p.alternate == store.alternate &&
              p.asset.id == id &&
              (placement == 0 || p.id == placement)) {
            found = p;
            break;
          }
        }
        final p = found;
        if (p == null || row >= p.height || col >= p.width) continue;
        if (origins < store.limits.maxPlacements) {
          if ((store.placeholderAnchors[(id, p.id)] ??= {}).add((
            y - buffer.scrollBack - row,
            x - col,
          ))) {
            origins++;
          }
        }
        if (!p.asset.displayAllowed) continue;
        (_placeholders[y] ??= []).add(
          InlineImageSlice(
            asset: p.asset,
            left: x,
            right: x + 1,
            sourceRow: row,
            rows: p.height,
            sourceCol: col,
            columns: p.width,
            crop: p.crop,
            z: p.z,
            renderWidth: p.renderWidth,
            renderHeight: p.renderHeight,
          ),
        );
      }
    }
  }

  void _viewport(TerminalPaintContext context) {
    if (_disposed) return;
    final buffer = terminal.buffer;
    store.viewportTop = context.firstRow - buffer.scrollBack;
    final visible = <InlineImageFrame>{};
    for (var row = context.firstRow; row < context.endRow; row++) {
      for (final slice in [
        ...store.slices(row - buffer.scrollBack),
        ...?_placeholders[row],
      ]) {
        visible.add(slice.asset.currentFrame);
      }
    }
    decoder.retain(visible);
  }

  void _paint(TerminalPaintContext context, bool Function(int) pass) {
    if (_disposed) return;
    final buffer = terminal.buffer;
    for (var row = context.firstRow; row < context.endRow; row++) {
      final slices =
          [...store.slices(row - buffer.scrollBack), ...?_placeholders[row]]
            ..sort(
              (a, b) => a.z != b.z
                  ? a.z.compareTo(b.z)
                  : a.asset.id.compareTo(b.asset.id),
            );
      for (final s in slices) {
        if (!pass(s.z)) continue;
        final image = decoder.imageFor(s.asset.currentFrame);
        if (image == null) continue;
        final cell = context.cellSize;
        final origin =
            context.cellOffset(s.left - s.sourceCol, row - s.sourceRow) +
            ui.Offset(s.offsetX.toDouble(), s.offsetY.toDouble());
        final width = s.naturalSize
            ? s.crop.width.toDouble()
            : s.renderWidth * cell.width;
        final height = s.naturalSize
            ? s.crop.height.toDouble()
            : s.renderHeight * cell.height;
        final sx = width / s.crop.width, sy = height / s.crop.height;
        final dest = ui.Rect.fromLTWH(
          origin.dx - s.crop.left * sx,
          origin.dy - s.crop.top * sy,
          s.asset.width * sx,
          s.asset.height * sy,
        );
        final clip = context.cellOffset(s.left, row);
        context.canvas.save();
        context.canvas.clipRect(
          ui.Rect.fromLTWH(
            clip.dx,
            clip.dy,
            (s.right - s.left) * cell.width,
            cell.height,
          ),
        );
        context.canvas.clipRect(
          ui.Rect.fromLTWH(origin.dx, origin.dy, width, height),
        );
        context.canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          dest,
          ui.Paint()..filterQuality = ui.FilterQuality.low,
        );
        context.canvas.restore();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    _timer.cancel();
    _clock.stop();
    _protocol.dispose();
    releaseAnchors();
    store.dispose();
    decoder.dispose();
    _placeholders.clear();
    super.dispose();
  }
}
