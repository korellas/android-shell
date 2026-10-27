/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
part of 'inline_images.dart';

class _PendingImageCommand {
  _PendingImageCommand(this.command, this.action);
  final InlineImageCommand command;
  final void Function() action;
}

/// Protocol state only. The host owns terminal anchors, scrolling, clipping,
/// asynchronous pixel decoding and rendering of immutable frame graphs.
class InlineImageStore {
  InlineImageStore({
    InlineImageBudget? budget,
    InlineImageLimits limits = const InlineImageLimits(),
    this.onReply,
    this.onChanged,
  }) : budget = budget ?? InlineImageBudget(limits) {
    this.budget.evict = _evict;
  }
  final InlineImageBudget budget;
  InlineImageLimits get limits => budget.limits;
  final void Function(String)? onReply;
  final void Function()? onChanged;
  final Map<int, InlineImageAsset> assets = {};
  final List<InlineImagePlacement> placements = [];
  final Set<InlineImageSource> _held = {};
  final Queue<_PendingImageCommand> _pending = Queue();
  final Map<Object, InlineImageSource> _waitingReplies = {};
  int rows = 24, cols = 80, cellWidth = 8, cellHeight = 16, viewportTop = 0;
  bool alternate = false, _disposed = false;
  int _nextItermId = 0x100000000;

  /// Host supplies origins collected from visible/history Unicode placeholders.
  final Map<(int, int), Set<(int, int)>> placeholderAnchors = {};

  List<(int, int)> origins(InlineImagePlacement placement, [int depth = 0]) {
    if (depth > 32) return const [];
    if (placement.virtual) {
      return placeholderAnchors[(placement.asset.id, placement.id)]?.toList() ??
          const [];
    }
    final parent = placement.parent;
    if (parent == null) return [(placement.top, placement.left)];
    for (final base in placements) {
      if ((base.asset.id, base.id) == parent &&
          base.alternate == placement.alternate) {
        return origins(
          base,
          depth + 1,
        ).map((p) => (p.$1 + placement.top, p.$2 + placement.left)).toList();
      }
    }
    return const [];
  }

  Set<InlineImageSource> get pendingConsent => {
    ..._held,
    ..._waitingReplies.values,
    ..._pending.map((p) => p.command.source).whereType<InlineImageSource>(),
  }.where((s) => s.allowed == null).toSet();

  int get frameCount =>
      assets.values.fold(
        0,
        (sum, asset) =>
            sum +
            asset.frames.fold(
              0,
              (n, frame) => n + (frame.source?.frameCount ?? 1),
            ),
      ) +
      _pending.fold(
        0,
        (n, command) => n + (command.command.source?.frameCount ?? 0),
      );

  InlineImageResult apply(
    InlineImageCommand command, {
    int row = 0,
    int col = 0,
  }) {
    if (_disposed) throw StateError('Inline image store is disposed');
    if (command._disposed) {
      throw StateError('Inline image command was already consumed');
    }
    try {
      _require(
        command.source == null ||
            identical(command.source!._bytes.budget, budget),
        'EINVAL:protocol and store must share the same image budget',
      );
      if (command.source?.allowed == null && command.source != null) {
        final waiting = <InlineImageSource>{
          ..._held,
          ..._waitingReplies.values,
          ..._pending
              .map((p) => p.command.source)
              .whereType<InlineImageSource>(),
        };
        _require(
          waiting.where((s) => s.allowed == null).length < limits.maxPlacements,
          'ENOSPC:too many pending image requests',
        );
      }
      if (command.protocol == InlineImageProtocolType.iterm2) {
        return _iterm(command, row, col);
      }
      var options = command.options;
      _require(
        !(options.containsKey('i') && options.containsKey('I')),
        'EINVAL:i and I are mutually exclusive',
      );
      switch (options['a'] ?? 't') {
        case 't':
        case 'T':
        case 'q':
          final source = command.source;
          _require(source != null, 'EINVAL:missing image payload');
          _require(
            frameCount + source!.frameCount <= limits.maxFrames,
            'ENOSPC:too many frames',
          );
          if (options['a'] == 'q') {
            _replyAfterConsent(source, options);
            return const InlineImageResult();
          }
          final id = _identifier(options, 'i') ?? _kittyId();
          final asset = _add(id, _identifier(options, 'I'), _base(source));
          options = {...options, 'i': '$id'};
          final result = options['a'] == 'T'
              ? _place(asset, options, row, col)
              : const InlineImageResult(changed: true);
          _watch(asset, source);
          _replyAfterConsent(source, options);
          return result;
        case 'p':
          final result = _place(_find(options), options, row, col);
          _send(options, 'OK');
          return result;
        case 'd':
          _enqueue(command, () => _delete(options, row, col));
        case 'f':
          _require(command.source != null, 'EINVAL:missing frame data');
          _require(
            frameCount + command.source!.frameCount <= limits.maxFrames,
            'ENOSPC:too many frames',
          );
          final asset = _find(options);
          _enqueue(command, () {
            _require(
              identical(assets[asset.id], asset),
              'ENOENT:image was removed',
            );
            _frame(options, command.source!);
          });
        case 'a':
          _enqueue(command, () => _animate(options));
        case 'c':
          _enqueue(command, () => _compose(options));
        default:
          throw const FormatException('ENOTSUP:unsupported graphics action');
      }
      return const InlineImageResult(changed: true);
    } catch (error) {
      if (command.protocol == InlineImageProtocolType.kitty) {
        _send(command.options, _reason(error));
      }
      return const InlineImageResult();
    } finally {
      _syncSources();
      command.dispose();
      onChanged?.call();
    }
  }

  InlineImageFrame _base(InlineImageSource source) => InlineImageFrame(
    source: source,
    width: source.width,
    height: source.height,
  );
  void _send(Map<String, String> options, String status) {
    final reply = _reply(options, status);
    if (reply != null && !_disposed) onReply?.call(reply);
  }

  void _replyAfterConsent(
    InlineImageSource source,
    Map<String, String> options,
  ) {
    final token = Object();
    _waitingReplies[token] = source;
    source._retain();
    source._whenDecided((allowed) {
      if (_waitingReplies.remove(token) == null) return;
      _send(options, allowed ? 'OK' : 'EPERM:user denied inline image');
      source._release();
    });
  }

  void _watch(InlineImageAsset asset, InlineImageSource source) {
    source._whenDecided((allowed) {
      if (!allowed && identical(assets[asset.id], asset)) remove(asset.id);
      onChanged?.call();
    });
  }

  void _enqueue(InlineImageCommand command, void Function() action) {
    _require(
      _pending.length < limits.maxPlacements,
      'ENOSPC:too many pending image commands',
    );
    command.source?._retain();
    _pending.add(_PendingImageCommand(command, action));
    if (command.source?.allowed == null && command.source != null) {
      command.source!._whenDecided((_) => _drain());
    }
    _drain();
  }

  void _drain() {
    while (_pending.isNotEmpty && !_disposed) {
      final next = _pending.first;
      final source = next.command.source;
      if (source != null && source.allowed == null) break;
      _pending.removeFirst();
      var status = 'EPERM:user denied inline image';
      try {
        if (source?.allowed != false) {
          next.action();
          status = 'OK';
        }
      } catch (error) {
        status = _reason(error);
      }
      _syncSources();
      source?._release();
      _send(next.command.options, status);
      onChanged?.call();
    }
  }

  int _kittyId() {
    var id = 1;
    while (assets.containsKey(id) && id <= 0xffffffff) {
      id++;
    }
    _require(id <= 0xffffffff, 'ENOSPC:no image identifiers');
    return id;
  }

  InlineImageAsset _add(int id, int? number, InlineImageFrame frame) {
    _require(
      assets.length < limits.maxImages || assets.containsKey(id),
      'ENOSPC:too many images',
    );
    remove(id);
    return assets[id] = InlineImageAsset(id, number, frame);
  }

  InlineImageAsset _find(Map<String, String> options) {
    final id = _identifier(options, 'i'), number = _identifier(options, 'I');
    InlineImageAsset? asset = id == null ? null : assets[id];
    if (id == null && number != null) {
      for (final candidate in assets.values) {
        if (candidate.number == number) asset = candidate;
      }
    }
    _require(asset != null, 'ENOENT:unknown image');
    return asset!;
  }

  InlineImageResult _iterm(InlineImageCommand command, int row, int col) {
    final source = command.source!;
    _require(
      frameCount + source.frameCount <= limits.maxFrames,
      'ENOSPC:too many frames',
    );
    final options = command.options;
    var width = _dimension(options['width'], cellWidth, cols);
    var height = _dimension(options['height'], cellHeight, rows);
    if (width == null && height == null) {
      width = source.width.toDouble();
      height = source.height.toDouble();
    }
    width ??= height! * source.width / source.height;
    height ??= width * source.height / source.width;
    if (options['preserveAspectRatio'] != '0') {
      final scale = math.min(width / source.width, height / source.height);
      width = source.width * scale;
      height = source.height * scale;
    }
    final available = math.max(cols - col, 1) * cellWidth;
    if (width > available) {
      height *= available / width;
      width = available.toDouble();
    }
    final columns = math.max(1, (width / cellWidth).ceil());
    final rowCount = (height / cellHeight).ceil().clamp(1, limits.maxDimension);
    _require(
      placements.length < limits.maxPlacements,
      'ENOSPC:too many placements',
    );
    edit(InlineImageRect(col, row, col + columns, row + rowCount));
    final asset = _add(_nextItermId++, null, _base(source));
    placements.add(
      InlineImagePlacement(
        asset: asset,
        id: 0,
        top: row,
        left: col,
        width: columns,
        height: rowCount,
        crop: InlineImageRect(0, 0, source.width, source.height),
        z: -1,
        iterm: true,
        alternate: alternate,
        renderWidth: width / cellWidth,
        renderHeight: height / cellHeight,
      ),
    );
    _syncSources();
    _watch(asset, source);
    return InlineImageResult(
      columns: columns,
      rows: rowCount,
      iterm: true,
      changed: true,
    );
  }

  double? _dimension(String? value, int cell, int extent) {
    if (value == null || value == 'auto') return null;
    final number = double.tryParse(
      value.endsWith('px')
          ? value.substring(0, value.length - 2)
          : value.endsWith('%')
          ? value.substring(0, value.length - 1)
          : value,
    );
    _require(number != null, 'EINVAL:invalid image size');
    final result = value.endsWith('px')
        ? number!
        : value.endsWith('%')
        ? number! * extent * cell / 100
        : number! * cell;
    _require(
      result.isFinite && result > 0 && result <= 0x7fffffff,
      'EINVAL:invalid image size',
    );
    return result;
  }

  InlineImageResult _place(
    InlineImageAsset asset,
    Map<String, String> o,
    int row,
    int col,
  ) {
    final base = asset.frames.first;
    final x = _integer(o, 'x'), y = _integer(o, 'y');
    final w = _integer(o, 'w', base.width - x),
        h = _integer(o, 'h', base.height - y);
    _require(
      x >= 0 && y >= 0 && w > 0 && h > 0 && x < base.width && y < base.height,
      'EINVAL:invalid crop',
    );
    final crop = InlineImageRect(
      x,
      y,
      math.min(base.width, x + w),
      math.min(base.height, y + h),
    );
    var columns = _integer(o, 'c'), rowCount = _integer(o, 'r');
    final natural = columns == 0 && rowCount == 0;
    _require(columns >= 0 && rowCount >= 0, 'EINVAL:negative placement size');
    final offsetX = _integer(o, 'X'), offsetY = _integer(o, 'Y');
    _require(
      offsetX >= 0 &&
          offsetX < cellWidth &&
          offsetY >= 0 &&
          offsetY < cellHeight,
      'EINVAL:invalid cell offset',
    );
    var pixelWidth = columns.toDouble() * cellWidth - offsetX;
    var pixelHeight = rowCount.toDouble() * cellHeight - offsetY;
    if (natural) {
      pixelWidth = crop.width.toDouble();
      pixelHeight = crop.height.toDouble();
      columns = ((pixelWidth + offsetX) / cellWidth).ceil();
      rowCount = ((pixelHeight + offsetY) / cellHeight).ceil();
    } else if (columns == 0) {
      pixelWidth = pixelHeight * crop.width / crop.height;
      columns = ((pixelWidth + offsetX) / cellWidth).ceil();
    } else if (rowCount == 0) {
      pixelHeight = pixelWidth * crop.height / crop.width;
      rowCount = ((pixelHeight + offsetY) / cellHeight).ceil();
    }
    _require(
      columns > 0 &&
          columns <= limits.maxDimension &&
          rowCount > 0 &&
          rowCount <= limits.maxDimension,
      'E2BIG:invalid placement size',
    );
    final id = _identifier(o, 'p') ?? 0;
    final parentId = _identifier(o, 'P');
    final parent = parentId == null
        ? null
        : (parentId, _identifier(o, 'Q') ?? 0);
    if (parent != null) {
      final visited = <(int, int)>{(asset.id, id)};
      (int, int)? current = parent;
      _require(
        placements.any((p) => (p.asset.id, p.id) == parent),
        'ENOENT:missing parent placement',
      );
      while (current != null) {
        _require(
          visited.add(current) && visited.length <= 32,
          'EINVAL:cyclic or excessive relative placement depth',
        );
        InlineImagePlacement? ancestor;
        for (final p in placements) {
          if ((p.asset.id, p.id) == current) {
            ancestor = p;
            break;
          }
        }
        current = ancestor?.parent;
      }
    }
    final virtual = o['U'] == '1';
    if (virtual) {
      final scale = math.min(
        pixelWidth / crop.width,
        pixelHeight / crop.height,
      );
      pixelWidth = crop.width * scale;
      pixelHeight = crop.height * scale;
    }
    _require(
      placements.length < limits.maxPlacements,
      'ENOSPC:too many placements',
    );
    if (id != 0) {
      placements.removeWhere(
        (p) =>
            identical(p.asset, asset) && p.id == id && p.alternate == alternate,
      );
    }
    placements.add(
      InlineImagePlacement(
        asset: asset,
        id: id,
        top: parent == null ? row : _integer(o, 'V'),
        left: parent == null ? col : _integer(o, 'H'),
        width: columns,
        height: rowCount,
        crop: crop,
        z: _integer(o, 'z'),
        alternate: alternate,
        virtual: virtual,
        parent: parent,
        offsetX: offsetX,
        offsetY: offsetY,
        renderWidth: pixelWidth / cellWidth,
        renderHeight: pixelHeight / cellHeight,
        naturalSize: natural,
      ),
    );
    return virtual || parent != null || o['C'] == '1'
        ? const InlineImageResult(changed: true)
        : InlineImageResult(columns: columns, rows: rowCount, changed: true);
  }

  void _delete(Map<String, String> o, int row, int col) {
    final selector = o['d'] ?? 'a', lower = (o['d'] ?? 'a').toLowerCase();
    _require(
      selector.length == 1 &&
          [
            'a',
            'i',
            'n',
            'c',
            'f',
            'p',
            'q',
            'r',
            'x',
            'y',
            'z',
          ].contains(lower),
      'EINVAL:unknown deletion selector',
    );
    final x = _integer(o, 'x', 1) - 1,
        y = _integer(o, 'y', 1) - 1,
        z = _integer(o, 'z');
    final selected = placements.where((p) {
      if (p.alternate != alternate ||
          p.iterm ||
          p.virtual && !['i', 'n', 'r'].contains(lower)) {
        return false;
      }
      bool contains(int px, int py) =>
          px >= p.left &&
          px < p.left + p.width &&
          py >= p.top &&
          py < p.top + p.height;
      return switch (lower) {
        'i' =>
          p.asset.id == _identifier(o, 'i') &&
              (!o.containsKey('p') || p.id == _identifier(o, 'p')),
        'n' => identical(p.asset, _find(o)),
        'r' =>
          p.asset.id >= (int.tryParse(o['x'] ?? '') ?? 0) &&
              p.asset.id <= (int.tryParse(o['y'] ?? '') ?? 0),
        'c' => contains(col, row),
        'p' || 'q' => contains(x, y) && (lower != 'q' || p.z == z),
        'x' => x >= p.left && x < p.left + p.width,
        'y' => y >= p.top && y < p.top + p.height,
        'z' => p.z == z,
        'f' => false,
        _ => p.top < rows && p.top + p.height > 0,
      };
    }).toSet();
    placements.removeWhere(selected.contains);
    if (lower == 'f') {
      final asset = _find(o), index = _integer(o, 'r', 1) - 1;
      _require(
        index >= 0 && index < asset.frames.length && asset.frames.length > 1,
        'EINVAL:invalid frame deletion',
      );
      asset.frames.removeAt(index);
      asset.gaps.removeAt(index);
      asset.frameIndex = math.min(asset.frameIndex, asset.frames.length - 1);
      asset.generation++;
    } else if (selector != lower) {
      final ids = selected.map((p) => p.asset.id).toSet();
      if (selector == 'I' && _identifier(o, 'i') != null) {
        ids.add(_identifier(o, 'i')!);
      }
      if (selector == 'N') ids.add(_find(o).id);
      for (final id in ids) {
        if (!placements.any((p) => p.asset.id == id)) remove(id);
      }
    }
  }

  void _frame(Map<String, String> o, InlineImageSource source) {
    final asset = _find(o),
        target = _integer(o, 'r') - 1,
        baseIndex = _integer(o, 'c') - 1;
    _require(frameCount < limits.maxFrames, 'ENOSPC:too many frames');
    _require(
      target == -1 || target >= 0 && target < asset.frames.length,
      'EINVAL:invalid frame number',
    );
    _require(
      baseIndex == -1 || baseIndex >= 0 && baseIndex < asset.frames.length,
      'EINVAL:invalid background frame',
    );
    final background = target >= 0
        ? asset.frames[target]
        : baseIndex >= 0
        ? asset.frames[baseIndex]
        : null;
    final rgba = _decimal(o['Y'] ?? '') ?? 0;
    final frame = InlineImageFrame(
      background: background,
      foreground: _base(source),
      x: _integer(o, 'x'),
      y: _integer(o, 'y'),
      width: asset.width,
      height: asset.height,
      color: ((rgba & 255) << 24) | ((rgba >> 8) & 0xffffff),
      replace: o['X'] == '1',
    );
    _validateFrame(frame);
    final gap = _integer(o, 'z');
    if (target < 0) {
      asset.frames.add(frame);
      asset.gaps.add(gap == 0 ? 40 : math.max(0, gap));
    } else {
      asset.frames[target] = frame;
      if (gap != 0) asset.gaps[target] = math.max(0, gap);
    }
    asset.generation++;
  }

  void _validateFrame(InlineImageFrame frame) => _require(
    frame.depth <= 32 && frame.operations <= limits.maxFrames,
    'E2BIG:frame dependency limit',
  );
  void _animate(Map<String, String> o) {
    final asset = _find(o);
    if (o.containsKey('s')) {
      final state = _integer(o, 's');
      _require(state >= 1 && state <= 3, 'EINVAL:invalid animation state');
      asset.animationState = state;
      if (state == 1) asset.completedLoops = 0;
    }
    if (o.containsKey('c')) {
      final index = _integer(o, 'c') - 1;
      _require(
        index >= 0 && index < asset.frames.length,
        'EINVAL:invalid animation frame',
      );
      asset.frameIndex = index;
    }
    if (o.containsKey('v')) {
      final count = _integer(o, 'v');
      _require(count >= 0, 'EINVAL:invalid loop count');
      if (count > 0) {
        asset.loops = count - 1;
        asset.completedLoops = 0;
      }
    }
    if (o.containsKey('z')) {
      final index = _integer(o, 'r', asset.frameIndex + 1) - 1,
          gap = _integer(o, 'z');
      _require(
        index >= 0 && index < asset.frames.length,
        'EINVAL:invalid animation gap frame',
      );
      if (gap != 0) asset.gaps[index] = math.max(0, gap);
    }
    asset.deadline = 0;
    asset.generation++;
  }

  void _compose(Map<String, String> o) {
    final asset = _find(o),
        si = _integer(o, 'r') - 1,
        ti = _integer(o, 'c') - 1;
    _require(
      si >= 0 &&
          si < asset.frames.length &&
          ti >= 0 &&
          ti < asset.frames.length,
      'ENOENT:invalid composition frame',
    );
    final source = asset.frames[si], target = asset.frames[ti];
    final x = _integer(o, 'x'),
        y = _integer(o, 'y'),
        w = _integer(o, 'w', source.width),
        h = _integer(o, 'h', source.height);
    _require(
      x >= 0 &&
          y >= 0 &&
          w > 0 &&
          h > 0 &&
          x + w <= source.width &&
          y + h <= source.height,
      'EINVAL:invalid composition rectangle',
    );
    final dx = _integer(o, 'X'), dy = _integer(o, 'Y');
    _require(
      dx >= 0 && dy >= 0 && dx + w <= target.width && dy + h <= target.height,
      'EINVAL:invalid destination rectangle',
    );
    final crop = InlineImageRect(x, y, x + w, y + h),
        destination = InlineImageRect(dx, dy, dx + w, dy + h);
    _require(
      si != ti || !crop.intersects(destination),
      'EINVAL:overlapping composition rectangles',
    );
    final frame = InlineImageFrame(
      background: target,
      foreground: source,
      x: dx,
      y: dy,
      width: target.width,
      height: target.height,
      replace: o['C'] == '1',
      sourceRect: crop,
    );
    _validateFrame(frame);
    asset.frames[ti] = frame;
    asset.generation++;
  }

  void advanceAnimations(int now) {
    for (final asset in assets.values) {
      if (!asset.displayAllowed ||
          asset.animationState == 1 ||
          asset.frames.length < 2) {
        continue;
      }
      if (asset.deadline == 0) {
        asset.deadline = now + asset.gaps[asset.frameIndex];
      }
      var steps = 0;
      while (now >= asset.deadline && steps++ < asset.frames.length * 2) {
        if (asset.frameIndex == asset.frames.length - 1) {
          if (asset.animationState == 2) break;
          asset.completedLoops++;
          if (asset.loops > 0 && asset.completedLoops >= asset.loops) {
            asset.animationState = 1;
            break;
          }
          asset.frameIndex = 0;
        } else {
          asset.frameIndex++;
        }
        asset.deadline += asset.gaps[asset.frameIndex];
        asset.generation++;
      }
    }
  }

  void _syncSources() {
    final next = <InlineImageSource>{};
    for (final asset in assets.values) {
      for (final frame in asset.frames) {
        next.addAll(frame.sources);
      }
    }
    for (final source in next.difference(_held)) {
      source._retain();
    }
    for (final source in _held.difference(next)) {
      source._release();
    }
    _held
      ..clear()
      ..addAll(next);
  }

  void updateCellSize(int width, int height) {
    _require(width > 0 && height > 0, 'EINVAL:invalid cell size');
    if (width == cellWidth && height == cellHeight) return;
    for (final p in placements.where((p) => p.naturalSize && !p.virtual)) {
      final oldWidth = p.width, oldHeight = p.height;
      p.width = math.max(1, ((p.crop.width + p.offsetX) / width).ceil());
      p.height = math.max(1, ((p.crop.height + p.offsetY) / height).ceil());
      if (p.clipRight == oldWidth) p.clipRight = p.width;
      if (p.clipBottom == oldHeight) p.clipBottom = p.height;
    }
    cellWidth = width;
    cellHeight = height;
  }

  void _collectIterm() {
    final unused = assets.values
        .where(
          (a) =>
              a.id >= 0x100000000 &&
              !placements.any((p) => identical(p.asset, a)),
        )
        .map((a) => a.id)
        .toList();
    for (final id in unused) {
      remove(id);
    }
  }

  void clearScreen() {
    placements.removeWhere(
      (p) => p.alternate == alternate && !p.virtual && p.top + p.height > 0,
    );
    _collectIterm();
    onChanged?.call();
  }

  void switchScreen(bool value) {
    alternate = value;
    if (value) placements.removeWhere((p) => p.alternate);
    _collectIterm();
    onChanged?.call();
  }

  void edit(InlineImageRect rect) {
    for (final p in placements.where(
      (p) => p.iterm && p.alternate == alternate,
    )) {
      for (
        var row = math.max(rect.top, p.top);
        row < math.min(rect.bottom, p.top + p.height);
        row++
      ) {
        p.erase(row - p.top, rect.left, rect.right);
      }
    }
    placements.removeWhere(
      (p) => p.iterm && p.coverage.every((row) => row.isEmpty),
    );
    _collectIterm();
  }

  void scroll(InlineImageRect rect, int down, int right) {
    final history =
        !alternate &&
        rect.top == 0 &&
        rect.left == 0 &&
        rect.right == cols &&
        down > 0 &&
        right == 0;
    final moving = placements
        .where(
          (p) => p.alternate == alternate && !p.virtual && p.parent == null,
        )
        .toList();
    for (final p in moving) {
      if (history &&
          p.top < rect.bottom &&
          p.left >= rect.left &&
          p.left + p.width <= rect.right) {
        p.top -= down;
      } else if (p.top >= rect.top &&
          p.top + p.height <= rect.bottom &&
          p.left >= rect.left &&
          p.left + p.width <= rect.right) {
        p.top -= down;
        p.left -= right;
        p.coverage = p.coverage
            .map(
              (ranges) =>
                  ranges.map((r) => (r.$1 - right, r.$2 - right)).toList(),
            )
            .toList();
        p.clipTop = math.max(p.clipTop, rect.top - p.top);
        p.clipBottom = math.min(p.clipBottom, rect.bottom - p.top);
        p.clipLeft = math.max(p.clipLeft, rect.left - p.left);
        p.clipRight = math.min(p.clipRight, rect.right - p.left);
      } else if (p.iterm) {
        final moved = <(int, int, int)>[];
        for (var row = 0; row < p.coverage.length; row++) {
          if (p.top + row < rect.top || p.top + row >= rect.bottom) continue;
          for (final range in p.coverage[row]) {
            final first = math.max(range.$1, rect.left),
                end = math.min(range.$2, rect.right);
            if (first < end) moved.add((row, first, end));
          }
        }
        for (final range in moved) {
          p.erase(range.$1, range.$2, range.$3);
        }
        for (final range in moved) {
          final dest = p.top + range.$1 - down;
          final first = math.max(rect.left, range.$2 - right),
              end = math.min(rect.right, range.$3 - right);
          if (dest >= rect.top &&
              dest < rect.bottom &&
              first < end &&
              placements.length < limits.maxPlacements) {
            final fragment = p.fragment(range.$1, first + right, end + right);
            fragment.top = dest;
            fragment.left = first;
            fragment.coverage[0] = [(first, end)];
            placements.add(fragment);
          }
        }
      }
    }
    placements.removeWhere(
      (p) => p.iterm && p.coverage.every((row) => row.isEmpty),
    );
    // The host chooses its actual scrollback bound through trimHistory.
    _collectIterm();
  }

  void trimHistory(int lines) {
    placements.removeWhere(
      (p) => !p.alternate && !p.virtual && p.top + p.height <= -lines,
    );
    _collectIterm();
  }

  void resizeImages(bool screen, int delta, int rows, int cols) {
    for (final p in placements.where(
      (p) => p.alternate == screen && !p.virtual && p.parent == null,
    )) {
      p.top += delta;
      if (screen) p.clipTop = math.max(p.clipTop, -p.top);
    }
    placements.removeWhere(
      (p) =>
          p.alternate == screen &&
          !p.virtual &&
          (p.top >= rows || p.clipRight <= p.clipLeft),
    );
    _collectIterm();
  }

  List<InlineImageSlice> slices(int row, {bool? screen}) {
    final result = <InlineImageSlice>[];
    for (final p in placements) {
      if (p.alternate != (screen ?? alternate) ||
          p.virtual ||
          !p.asset.displayAllowed) {
        continue;
      }
      for (final origin in origins(p)) {
        final y = row - origin.$1;
        if (y < math.max(0, p.clipTop) ||
            y >= math.min(p.height, p.clipBottom)) {
          continue;
        }
        final ranges = p.iterm
            ? p.coverage[y]
            : [(origin.$2, origin.$2 + p.width)];
        for (final range in ranges) {
          final left = math.max(0, math.max(range.$1, origin.$2 + p.clipLeft));
          final right = math.min(
            cols,
            math.min(range.$2, origin.$2 + p.clipRight),
          );
          if (left >= right) continue;
          result.add(
            InlineImageSlice(
              asset: p.asset,
              left: left,
              right: right,
              sourceRow: y + p.sourceRow,
              rows: p.height,
              sourceCol: left - origin.$2 + p.sourceCol,
              columns: p.width,
              crop: p.crop,
              z: p.z,
              offsetX: p.offsetX,
              offsetY: p.offsetY,
              renderWidth: p.renderWidth,
              renderHeight: p.renderHeight,
              naturalSize: p.naturalSize,
            ),
          );
        }
      }
    }
    result.sort((a, b) {
      final z = a.z.compareTo(b.z);
      return z != 0 ? z : a.asset.id.compareTo(b.asset.id);
    });
    return result;
  }

  void _evict(int bytes) {
    while (budget.encodedUsage + bytes > limits.encodedBytes) {
      InlineImageAsset? victim;
      for (final asset in assets.values) {
        if (!placements.any((p) => identical(p.asset, asset))) {
          victim = asset;
          break;
        }
      }
      if (victim == null) {
        for (final asset in assets.values) {
          if (!placements.any(
            (p) =>
                identical(p.asset, asset) &&
                p.alternate == alternate &&
                origins(p).any(
                  (origin) =>
                      origin.$1 < viewportTop + rows &&
                      origin.$1 + p.height > viewportTop &&
                      origin.$2 < cols &&
                      origin.$2 + p.width > 0,
                ),
          )) {
            victim = asset;
            break;
          }
        }
      }
      if (victim == null) break;
      remove(victim.id);
    }
  }

  void remove(int id) {
    assets.remove(id);
    placements.removeWhere((p) => p.asset.id == id);
    _syncSources();
    onChanged?.call();
  }

  void clear() {
    for (final source in _waitingReplies.values) {
      source._release();
    }
    _waitingReplies.clear();
    for (final pending in _pending) {
      pending.command.source?._release();
    }
    _pending.clear();
    assets.clear();
    placeholderAnchors.clear();
    placements.clear();
    _syncSources();
    onChanged?.call();
  }

  void dispose() {
    _disposed = true;
    clear();
    budget.evict = null;
  }
}
