/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
part of 'inline_images.dart';

/// One worker owns the streaming parser, including unsendable zlib state.
/// Consumers must await each feed before starting another.
class AsyncInlineImageProtocol {
  AsyncInlineImageProtocol({
    required this.budget,
    this.policy = InlineImagePolicy.on,
  });
  final InlineImageBudget budget;
  InlineImagePolicy policy;
  Isolate? _isolate;
  SendPort? _requests;
  ReceivePort? _responses;
  StreamIterator<dynamic>? _iterator;
  int _pendingBytes = 0;
  bool _busy = false, _disposed = false;
  bool get isBusy => _busy;

  Future<List<InlineImageEvent>> feed(String chunk) async {
    if (_disposed) return const [];
    if (_busy) throw StateError('Image feeds must be serialized');
    _busy = true;
    // Reserve the worker's whole available allowance before it can allocate.
    // UI decode copies cannot spend those same bytes during the request.
    final allowance = budget.limits.encodedBytes - budget.encodedUsage;
    budget._reserve(allowance);
    var heldAllowance = allowance;
    try {
      if (_requests == null) {
        final responses = _responses = ReceivePort();
        _iterator = StreamIterator(responses);
        _isolate = await Isolate.spawn(_imageParserWorker, (
          responses.sendPort,
          budget.limits,
        ));
        if (_disposed) {
          _isolate!.kill(priority: Isolate.immediate);
          return const [];
        }
        if (!await _iterator!.moveNext()) return const [];
        _requests = _iterator!.current as SendPort;
      }
      if (_disposed) return const [];
      _requests!.send((
        chunk,
        policy,
        budget.encodedUsage - _pendingBytes - heldAllowance,
      ));
      if (!await _iterator!.moveNext() || _disposed) return const [];
      final (events, pending) =
          _iterator!.current as (List<InlineImageEvent>, int);
      budget._encoded -= heldAllowance;
      heldAllowance = 0;
      budget._encoded -= _pendingBytes;
      _pendingBytes = 0;
      for (final event in events) {
        if (event is InlineImageCommand && event.source != null) {
          final bytes = event.source!._bytes;
          budget._reserve(bytes.allocated);
          bytes.budget = budget;
        }
      }
      budget._reserve(pending);
      _pendingBytes = pending;
      return events;
    } finally {
      budget._encoded -= heldAllowance;
      _busy = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    budget._encoded -= _pendingBytes;
    _pendingBytes = 0;
    _isolate?.kill(priority: Isolate.immediate);
    _responses?.close();
    unawaited(_iterator?.cancel());
  }
}

void _imageParserWorker((SendPort, InlineImageLimits) init) {
  final (responses, limits) = init;
  final requests = ReceivePort();
  final parser = InlineImageProtocol(limits: limits);
  responses.send(requests.sendPort);
  requests.listen((dynamic message) {
    final (chunk, policy, retained) =
        message as (String, InlineImagePolicy, int);
    parser.policy = policy;
    parser.budget._encoded += retained;
    final events = parser.feed(chunk).toList();
    final commands = events.whereType<InlineImageCommand>().toList();
    final transferred = commands.fold(
      0,
      (int n, c) => n + (c.source?._bytes.allocated ?? 0),
    );
    try {
      // SendPort copies source chunks; reserve that transient second copy too.
      parser.budget._reserve(transferred);
      responses.send((
        events,
        parser.budget.encodedUsage - retained - transferred * 2,
      ));
      parser.budget._encoded -= transferred;
    } catch (_) {
      final rejected = <InlineImageEvent>[];
      for (final event in events) {
        if (event is! InlineImageCommand) {
          rejected.add(event);
        } else if (event.protocol == InlineImageProtocolType.kitty) {
          final reply = _reply(event.options, 'ENOSPC:image memory limit');
          if (reply != null) rejected.add(InlineImageReply(reply));
        }
      }
      responses.send((
        rejected,
        parser.budget.encodedUsage - retained - transferred,
      ));
    }
    for (final command in commands) {
      command.dispose();
    }
    parser.budget._encoded -= retained;
  });
}

extension AsyncInlineImageSource on InlineImageSource {
  /// With rgba, raw sources become platform premultiplied RGBA in the worker.
  Future<InlineImageDecodeData> openDecodeAsync({bool rgba = false}) async {
    if (!displayAllowed || _bytes.released) {
      throw StateError('Inline image consent and a live source are required');
    }
    final channels = rgba && format == 24 ? 4 : format ~/ 8;
    final length = format == 100 ? _bytes.size : width * height * channels;
    final reservation = _bytes.budget.reserveDecoded(length);
    _retain();
    var copied = false;
    final copySize = _bytes.allocated;
    try {
      _bytes.budget._reserve(copySize);
      copied = true;
      final parts = _bytes.parts.map((p) => p as Uint8List).toList();
      final data = await _expandAsync(
        parts,
        length,
        format == 100,
        rgba && format == 24,
        rgba && format == 32,
      );
      return InlineImageDecodeData._(data, reservation);
    } catch (_) {
      reservation.dispose();
      rethrow;
    } finally {
      if (copied) _bytes.budget._encoded -= copySize;
      _release();
    }
  }
}

Future<Uint8List> _expandAsync(
  List<Uint8List> parts,
  int length,
  bool encoded,
  bool rgb,
  bool premultiply,
) => Isolate.run(() {
  final result = Uint8List(length);
  var offset = 0;
  final sink = _CountSink(rgb ? length ~/ 4 * 3 : length, (data) {
    if (rgb) {
      for (final byte in data) {
        result[offset++] = byte;
        if (offset % 4 == 3) result[offset++] = 255;
      }
    } else {
      result.setRange(offset, offset + data.length, data);
      offset += data.length;
    }
  });
  if (encoded) {
    for (final part in parts) {
      sink.add(part);
    }
  } else {
    final decoder = ZLibDecoder().startChunkedConversion(sink);
    for (final part in parts) {
      decoder.add(part);
    }
    decoder.close();
  }
  _require(offset == length, 'EINVAL:short pixel data');
  if (premultiply) {
    for (var i = 0; i < result.length; i += 4) {
      final alpha = result[i + 3];
      for (var c = 0; c < 3; c++) {
        result[i + c] = (result[i + c] * alpha + 127) ~/ 255;
      }
    }
  }
  return result;
});
