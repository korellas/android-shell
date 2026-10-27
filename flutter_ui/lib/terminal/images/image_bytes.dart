/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
part of 'inline_images.dart';

/// Shared by protocol uploads, retained sources, and renderer decode leases.
class InlineImageBudget {
  InlineImageBudget([this.limits = const InlineImageLimits()]);
  final InlineImageLimits limits;
  int _encoded = 0, _decoded = 0;
  int get encodedUsage => _encoded;
  int get decodedUsage => _decoded;
  void Function(int bytes)? evict;

  void _reserve(int bytes) {
    if (_encoded + bytes > limits.encodedBytes) evict?.call(bytes);
    _require(
      bytes >= 0 && _encoded + bytes <= limits.encodedBytes,
      'ENOSPC:image memory limit',
    );
    _encoded += bytes;
  }

  /// Renderer retains the lease until the decoded image/temporary is disposed.
  InlineImageReservation reserveDecoded(int bytes) {
    _require(
      bytes >= 0 && _decoded + bytes <= limits.decodedBytes,
      'ENOSPC:decoded image memory limit',
    );
    _decoded += bytes;
    return InlineImageReservation._(() => _decoded -= bytes);
  }
}

class InlineImageReservation {
  InlineImageReservation._(this._release);
  void Function()? _release;
  void dispose() {
    final release = _release;
    _release = null;
    release?.call();
  }
}

class InlineImageDecodeData {
  InlineImageDecodeData._(this.bytes, this._reservation);
  final Uint8List bytes;
  final InlineImageReservation _reservation;
  void dispose() => _reservation.dispose();
}

class _ImageBytes implements Sink<List<int>> {
  _ImageBytes(this.budget, this.limit);
  static const chunkSize = 4096;
  InlineImageBudget budget;
  final int limit;
  final List<Uint8List> chunks = [];
  int size = 0, allocated = 0;
  bool released = false;
  @override
  void add(List<int> data) {
    if (released) return;
    _require(data.length <= limit - size, 'E2BIG:image upload exceeds limit');
    var offset = 0;
    while (offset < data.length) {
      if (size == allocated) {
        final bytes = math.min(chunkSize, limit - allocated);
        budget._reserve(bytes);
        allocated += bytes;
        chunks.add(Uint8List(bytes));
      }
      final position = size % chunkSize;
      final count = math.min(
        data.length - offset,
        chunks.last.length - position,
      );
      chunks.last.setRange(position, position + count, data, offset);
      offset += count;
      size += count;
    }
  }

  @override
  void close() {}
  Iterable<List<int>> get parts sync* {
    var remaining = size;
    for (final chunk in chunks) {
      final count = math.min(remaining, chunk.length);
      if (count == 0) break;
      yield Uint8List.sublistView(chunk, 0, count);
      remaining -= count;
    }
  }

  Uint8List flatten() {
    final data = Uint8List(size);
    var offset = 0;
    for (final part in parts) {
      data.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return data;
  }

  void release() {
    if (released) return;
    released = true;
    budget._encoded -= allocated;
    chunks.clear();
  }
}

/// Strict quartet decoder, including canonical tail bits and split padding.
class _ImageBase64 {
  _ImageBase64(this.write);
  final void Function(List<int>) write;
  int bits = 0, count = 0, padding = 0;
  final Uint8List _scratch = Uint8List(4096);
  int _used = 0;
  void _emit(int byte) {
    _scratch[_used++] = byte & 255;
    if (_used == _scratch.length) flush();
  }

  void flush() {
    if (_used == 0) return;
    write(Uint8List.sublistView(_scratch, 0, _used));
    _used = 0;
  }

  void accept(int value) {
    if (value == 61) {
      _require(
        count >= 2 && count <= 3 && padding < 2 && count + padding < 4,
        'EINVAL:invalid base64 padding',
      );
      if (padding == 0) {
        _require(
          count == 2 ? bits & 15 == 0 : bits & 3 == 0,
          'EINVAL:invalid base64 tail',
        );
        if (count == 2) {
          _emit(bits >> 4);
        } else {
          _emit(bits >> 10);
          _emit(bits >> 2);
        }
      }
      padding++;
      return;
    }
    _require(padding == 0, 'EINVAL:data after base64 padding');
    final decoded = switch (value) {
      >= 65 && <= 90 => value - 65,
      >= 97 && <= 122 => value - 71,
      >= 48 && <= 57 => value + 4,
      43 => 62,
      47 => 63,
      _ => -1,
    };
    _require(decoded >= 0, 'EINVAL:invalid base64 byte');
    bits = (bits << 6) | decoded;
    if (++count == 4) {
      _emit(bits >> 16);
      _emit(bits >> 8);
      _emit(bits);
      count = bits = 0;
    }
  }

  void finish() {
    if (padding > 0) {
      _require(count + padding == 4, 'EINVAL:incomplete base64 quartet');
    } else if (count == 2) {
      _require(bits & 15 == 0, 'EINVAL:invalid base64 tail');
      _emit(bits >> 4);
    } else if (count == 3) {
      _require(bits & 3 == 0, 'EINVAL:invalid base64 tail');
      _emit(bits >> 10);
      _emit(bits >> 2);
    } else {
      _require(count == 0, 'EINVAL:incomplete base64 quartet');
    }
    flush();
  }
}

class _CountSink implements Sink<List<int>> {
  _CountSink(
    this.limit, [
    this.output,
    this.reason = 'E2BIG:pixel stream exceeds limit',
  ]);
  final int limit;
  final void Function(List<int>)? output;
  final String reason;
  int count = 0;
  @override
  void add(List<int> data) {
    _require(data.length <= limit - count, reason);
    count += data.length;
    output?.call(data);
  }

  @override
  void close() {}
}

void _inflate(_ImageBytes bytes, Sink<List<int>> output) {
  final decoder = ZLibDecoder().startChunkedConversion(output);
  for (final part in bytes.parts) {
    decoder.add(part);
  }
  decoder.close();
}
