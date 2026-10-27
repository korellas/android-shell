/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
part of 'inline_images.dart';

class _ByteReader {
  _ByteReader(this.bytes, [int? limit])
    : limit = math.min(limit ?? bytes.size, bytes.size);
  final _ImageBytes bytes;
  final int limit;
  int position = 0;
  int byte() {
    _require(
      position < limit,
      'E2BIG:image header exceeds available bytes or inspection limit',
    );
    final value =
        bytes.chunks[position ~/ _ImageBytes.chunkSize][position %
            _ImageBytes.chunkSize];
    position++;
    return value;
  }

  int uint(int count, [bool little = false]) {
    var value = 0;
    for (var i = 0; i < count; i++) {
      value |= byte() << (8 * (little ? i : count - i - 1));
    }
    return value;
  }

  String text(int count) =>
      String.fromCharCodes(List.generate(count, (_) => byte()));
  void skip(int count) {
    _require(count >= 0 && count <= limit - position, 'EINVAL:truncated image');
    position += count;
  }

  void blocks() {
    while (true) {
      final count = byte();
      if (count == 0) return;
      skip(count);
    }
  }
}

class _ImageMetadata {
  _ImageMetadata(this.width, this.height, this.mime, [this.frames = 1]);
  final int width, height, frames;
  final String mime;
  static _ImageMetadata read(_ImageBytes bytes, InlineImageLimits limits) {
    final r = _ByteReader(bytes, 32 * 1024);
    final first = r.byte(), second = r.byte();
    late _ImageMetadata result;
    if (first == 0x89 && second == 80) {
      _require(r.text(6) == 'NG\r\n\x1a\n', 'EINVAL:invalid PNG signature');
      _require(
        r.uint(4) == 13 && r.text(4) == 'IHDR',
        'EINVAL:missing PNG IHDR',
      );
      final width = r.uint(4), height = r.uint(4);
      r.skip(9);
      result = _ImageMetadata(width, height, 'image/png');
    } else if (first == 71 && second == 73) {
      _require(
        ['F87a', 'F89a'].contains(r.text(4)),
        'EINVAL:invalid GIF signature',
      );
      final width = r.uint(2, true), height = r.uint(2, true);
      r.skip(3);
      result = _ImageMetadata(width, height, 'image/gif');
    } else if (first == 255 && second == 216) {
      result = _jpeg(r);
    } else if (first == 82 && second == 73) {
      result = _webp(r, bytes.size);
    } else {
      throw const FormatException('ENOTSUP:unsupported image file');
    }
    _validateSize(result.width, result.height, limits);
    return _ImageMetadata(
      result.width,
      result.height,
      result.mime,
      _frameCount(bytes, result.mime, limits.maxFrames),
    );
  }

  static _ImageMetadata _jpeg(_ByteReader r) {
    while (true) {
      _require(r.byte() == 255, 'EINVAL:invalid JPEG marker');
      var marker = r.byte();
      while (marker == 255) {
        marker = r.byte();
      }
      _require(
        marker != 0 && marker != 218 && marker != 217,
        'EINVAL:missing JPEG dimensions',
      );
      if (marker == 1 || marker >= 208 && marker <= 216) continue;
      final length = r.uint(2);
      _require(length >= 2, 'EINVAL:invalid JPEG segment');
      if (marker >= 192 && marker <= 207 && ![196, 200, 204].contains(marker)) {
        _require(length >= 8, 'EINVAL:short JPEG frame header');
        r.byte();
        final height = r.uint(2), width = r.uint(2), components = r.byte();
        _require(
          components >= 1 && components <= 4 && length == 8 + components * 3,
          'EINVAL:invalid JPEG frame header',
        );
        r.skip(components * 3);
        return _ImageMetadata(width, height, 'image/jpeg');
      }
      r.skip(length - 2);
    }
  }

  static _ImageMetadata _webp(_ByteReader r, int size) {
    _require(r.text(2) == 'FF', 'EINVAL:invalid WebP signature');
    final length = r.uint(4, true);
    _require(
      length >= 12 && length + 8 <= size && r.text(4) == 'WEBP',
      'EINVAL:invalid WebP container',
    );
    final tag = r.text(4), chunk = r.uint(4, true);
    _require(chunk + (chunk & 1) + 12 <= length, 'EINVAL:invalid WebP chunk');
    switch (tag) {
      case 'VP8X':
        _require(chunk == 10, 'EINVAL:invalid WebP extended header');
        r.skip(4);
        return _ImageMetadata(
          r.uint(3, true) + 1,
          r.uint(3, true) + 1,
          'image/webp',
        );
      case 'VP8L':
        _require(
          chunk >= 5 && r.byte() == 47,
          'EINVAL:invalid WebP lossless header',
        );
        final bits = r.uint(4, true);
        _require(bits >> 29 == 0, 'ENOTSUP:unsupported WebP version');
        return _ImageMetadata(
          (bits & 0x3fff) + 1,
          ((bits >> 14) & 0x3fff) + 1,
          'image/webp',
        );
      case 'VP8 ':
        _require(
          chunk >= 10 && r.byte() & 1 == 0,
          'EINVAL:invalid WebP key frame',
        );
        r.skip(2);
        _require(
          r.byte() == 157 && r.byte() == 1 && r.byte() == 42,
          'EINVAL:invalid VP8 signature',
        );
        return _ImageMetadata(
          r.uint(2, true) & 0x3fff,
          r.uint(2, true) & 0x3fff,
          'image/webp',
        );
      default:
        throw const FormatException('ENOTSUP:unsupported WebP header');
    }
  }

  static int _frameCount(_ImageBytes bytes, String mime, int limit) {
    final r = _ByteReader(bytes);
    var count = 0;
    if (mime == 'image/gif') {
      r.skip(10);
      final flags = r.byte();
      r.skip(2);
      if (flags & 128 != 0) r.skip(3 * (2 << (flags & 7)));
      var finished = false;
      while (!finished) {
        switch (r.byte()) {
          case 0x3b:
            finished = true;
          case 0x21:
            r.byte();
            r.blocks();
          case 0x2c:
            r.skip(8);
            final local = r.byte();
            if (local & 128 != 0) r.skip(3 * (2 << (local & 7)));
            r.byte();
            r.blocks();
            count++;
          default:
            throw const FormatException('EINVAL:invalid GIF block');
        }
        _require(count <= limit, 'ENOSPC:too many animation frames');
      }
    } else if (mime == 'image/webp') {
      r.skip(12);
      while (r.position + 8 <= bytes.size) {
        final tag = r.text(4), size = r.uint(4, true);
        r.skip(size + (size & 1));
        if (tag == 'ANMF') count++;
        _require(count <= limit, 'ENOSPC:too many animation frames');
      }
    }
    return math.max(1, count);
  }
}

void _validateSize(int width, int height, InlineImageLimits limits) => _require(
  width > 0 &&
      height > 0 &&
      width <= limits.maxDimension &&
      height <= limits.maxDimension &&
      width * height <= limits.maxPixels,
  'E2BIG:invalid image dimensions',
);
