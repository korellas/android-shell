/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
part of 'inline_images.dart';

class InlineImageSource {
  InlineImageSource._(
    this._bytes,
    this.width,
    this.height,
    this.format,
    this.mime,
    this.frameCount,
    InlineImagePolicy policy,
  ) : _allowed = policy == InlineImagePolicy.ask
          ? null
          : policy == InlineImagePolicy.on;
  final _ImageBytes _bytes;
  final int width, height, format, frameCount;
  final String? mime;
  bool? _allowed;
  bool? get allowed => _allowed;
  bool get displayAllowed => _allowed == true;
  int _references = 1;
  final List<void Function(bool)> _listeners = [];
  InlineImageDecodeData? _cached;
  int get encodedSize => _bytes.size;

  void decide(bool allowed) {
    if (_allowed != null) return;
    _allowed = allowed;
    final listeners = List.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener(allowed);
    }
  }

  void _whenDecided(void Function(bool) callback) {
    if (_allowed == null) {
      _listeners.add(callback);
    } else {
      callback(_allowed!);
    }
  }

  /// Caller must dispose the returned lease after its platform decode finishes.
  /// This method never performs a pixel decode; format 24/32 returns RGB/RGBA.
  InlineImageDecodeData openDecode() {
    if (!displayAllowed) {
      throw StateError('Inline image consent is required before decoding');
    }
    if (_bytes.released) {
      throw StateError('Inline image source has been released');
    }
    final length = format == 100 ? _bytes.size : width * height * (format ~/ 8);
    final reservation = _bytes.budget.reserveDecoded(length);
    try {
      if (format == 100) {
        return InlineImageDecodeData._(_bytes.flatten(), reservation);
      }
      final result = Uint8List(length);
      var offset = 0;
      _inflate(
        _bytes,
        _CountSink(length, (data) {
          result.setRange(offset, offset + data.length, data);
          offset += data.length;
        }),
      );
      _require(offset == length, 'EINVAL:short pixel data');
      return InlineImageDecodeData._(result, reservation);
    } catch (_) {
      reservation.dispose();
      rethrow;
    }
  }

  /// Convenient retained copy; its reservation lasts as long as this source.
  Uint8List bytesForDecode() =>
      (_cached ??= openDecode()).bytes.asUnmodifiableView();
  void _retain() {
    _references++;
  }

  void _release() {
    if (--_references != 0) return;
    _cached?.dispose();
    _bytes.release();
    _listeners.clear();
  }
}

class InlineImageRect {
  const InlineImageRect(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
  int get width => right - left;
  int get height => bottom - top;
  bool intersects(InlineImageRect other) =>
      left < other.right &&
      other.left < right &&
      top < other.bottom &&
      other.top < bottom;
}

/// Immutable frame graph shared by composition/animation commands.
class InlineImageFrame {
  InlineImageFrame({
    this.source,
    this.background,
    this.foreground,
    this.x = 0,
    this.y = 0,
    required this.width,
    required this.height,
    this.color = 0,
    this.replace = false,
    this.sourceRect,
  }) : depth = 1 + math.max(background?.depth ?? 0, foreground?.depth ?? 0),
       operations =
           1 + (background?.operations ?? 0) + (foreground?.operations ?? 0);
  final InlineImageSource? source;
  final InlineImageFrame? background, foreground;
  final int x, y, width, height, color, depth, operations;
  final bool replace;
  final InlineImageRect? sourceRect;
  bool get displayAllowed => sources.every((s) => s.displayAllowed);
  Set<InlineImageSource> get sources {
    final result = <InlineImageSource>{};
    final visited = <InlineImageFrame>{};
    void visit(InlineImageFrame frame) {
      if (!visited.add(frame)) return;
      if (frame.source != null) result.add(frame.source!);
      if (frame.background != null) visit(frame.background!);
      if (frame.foreground != null) visit(frame.foreground!);
    }

    visit(this);
    return result;
  }
}

class InlineImageAsset {
  InlineImageAsset(this.id, this.number, InlineImageFrame frame)
    : frames = [frame],
      width = frame.width,
      height = frame.height;
  final int id;
  final int? number;
  final int width, height;
  final List<InlineImageFrame> frames;
  final List<int> gaps = [0];
  int frameIndex = 0, generation = 0, animationState = 1;
  int loops = 0, completedLoops = 0, deadline = 0;
  bool get displayAllowed => frames.every((frame) => frame.displayAllowed);
  InlineImageFrame get currentFrame => frames[frameIndex];
}

class InlineImagePlacement {
  InlineImagePlacement({
    required this.asset,
    required this.id,
    required this.top,
    required this.left,
    required this.width,
    required this.height,
    required this.crop,
    this.z = 0,
    this.iterm = false,
    this.alternate = false,
    this.virtual = false,
    this.parent,
    this.offsetX = 0,
    this.offsetY = 0,
    required this.renderWidth,
    required this.renderHeight,
    this.naturalSize = false,
    this.sourceRow = 0,
    this.sourceCol = 0,
  }) : clipBottom = height,
       clipRight = width,
       coverage = iterm
           ? List.generate(height, (_) => [(left, left + width)])
           : [];
  final InlineImageAsset asset;
  final int id;
  int top, left, width, height;
  final InlineImageRect crop;
  final int z, offsetX, offsetY;
  final bool iterm, alternate, virtual, naturalSize;
  final (int, int)? parent;
  final double renderWidth, renderHeight;
  final int sourceRow, sourceCol;
  int clipTop = 0, clipBottom, clipLeft = 0, clipRight;
  List<List<(int, int)>> coverage;

  void erase(int row, int start, int end) {
    coverage[row] = coverage[row].expand((range) {
      if (end <= range.$1 || start >= range.$2) return [range];
      return [
        if (start > range.$1) (range.$1, start),
        if (end < range.$2) (end, range.$2),
      ];
    }).toList();
  }

  InlineImagePlacement fragment(int row, int start, int end) =>
      InlineImagePlacement(
        asset: asset,
        id: id,
        top: top + row,
        left: start,
        width: end - start,
        height: 1,
        crop: crop,
        z: z,
        iterm: true,
        alternate: alternate,
        offsetX: offsetX,
        offsetY: offsetY,
        renderWidth: renderWidth,
        renderHeight: renderHeight,
        sourceRow: sourceRow + row,
        sourceCol: sourceCol + start - left,
        naturalSize: naturalSize,
      );
}

class InlineImageSlice {
  const InlineImageSlice({
    required this.asset,
    required this.left,
    required this.right,
    required this.sourceRow,
    required this.rows,
    required this.sourceCol,
    required this.columns,
    required this.crop,
    required this.z,
    this.offsetX = 0,
    this.offsetY = 0,
    required this.renderWidth,
    required this.renderHeight,
    this.naturalSize = false,
  });
  final InlineImageAsset asset;
  final int left,
      right,
      sourceRow,
      rows,
      sourceCol,
      columns,
      z,
      offsetX,
      offsetY;
  final InlineImageRect crop;
  final double renderWidth, renderHeight;
  final bool naturalSize;
}

class InlineImageResult {
  const InlineImageResult({
    this.rows = 0,
    this.columns = 0,
    this.iterm = false,
    this.changed = false,
  });
  final int rows, columns;
  final bool iterm, changed;
}
