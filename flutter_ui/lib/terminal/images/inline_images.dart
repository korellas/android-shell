/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

export 'kitty_placeholder.dart';

part 'image_bytes.dart';
part 'image_async.dart';
part 'image_metadata.dart';
part 'image_model.dart';
part 'image_protocol.dart';
part 'image_store.dart';

// Ported from org.connectbot.terminal InlineImageLimits/InlineImageProtocol/
// InlineImageStore/ImageBytes/ImageDimensions/ImageAnimationBounds (Apache-2.0).

enum InlineImagePolicy { off, ask, on }

enum InlineImageProtocolType { kitty, iterm2 }

class InlineImageLimits {
  const InlineImageLimits({
    this.encodedBytes = 16 * 1024 * 1024,
    this.pendingInputBytes = 4 * 1024 * 1024,
    this.pendingInputChunks = 256,
    this.decodedBytes = 32 * 1024 * 1024,
    this.transferBytes = 4 * 1024 * 1024,
    this.uploadBytes = 16 * 1024 * 1024,
    this.maxDimension = 16384,
    this.maxPixels = 16 * 1024 * 1024,
    this.maxImages = 1024,
    this.maxPlacements = 4096,
    this.maxFrames = 4096,
  }) : assert(encodedBytes > 0 && decodedBytes > 0),
       assert(pendingInputBytes > 0 && pendingInputChunks > 0),
       assert(transferBytes >= 16384 && uploadBytes > 0),
       assert(maxDimension > 0 && maxDimension <= 16384),
       assert(
         maxPixels > 0 && maxImages > 0 && maxPlacements > 0 && maxFrames > 0,
       );

  final int encodedBytes, decodedBytes, transferBytes, uploadBytes;
  final int pendingInputBytes, pendingInputChunks;
  final int maxDimension, maxPixels, maxImages, maxPlacements, maxFrames;
}

void _require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

String _reason(Object error) =>
    error is FormatException && error.message.contains(':')
    ? error.message
    : 'EINVAL:invalid image';

int _integer(Map<String, String> options, String key, [int fallback = 0]) {
  if (!options.containsKey(key)) return fallback;
  final value = _decimal(options[key]!);
  _require(
    value != null && value >= -0x80000000 && value <= 0x7fffffff,
    'EINVAL:invalid $key',
  );
  return value!;
}

int? _identifier(Map<String, String> options, String key) {
  if (!options.containsKey(key)) return null;
  final value = _decimal(options[key]!);
  _require(
    value != null && value >= 0 && value <= 0xffffffff,
    'EINVAL:invalid $key',
  );
  return value == 0 ? null : value;
}

// The wire grammar is decimal; Dart's int.tryParse also accepts hex and spaces.
int? _decimal(String value) =>
    RegExp(r'^[+-]?[0-9]+$').hasMatch(value) ? int.tryParse(value) : null;

String? _reply(Map<String, String> options, String status) {
  final quiet = _decimal(options['q'] ?? '') ?? 0;
  if (quiet == 2 || quiet == 1 && status == 'OK') return null;
  final ids = [
    'i',
    'I',
    'p',
  ].where(options.containsKey).map((k) => '$k=${options[k]}').join(',');
  return '\x1b_G$ids;$status\x1b\\';
}

sealed class InlineImageEvent {}

final class InlineImageText extends InlineImageEvent {
  InlineImageText(this.text);
  final String text;
}

final class InlineImageReply extends InlineImageEvent {
  InlineImageReply(this.text);
  final String text;
}

/// Apply once to a store, or dispose if the consumer discards the event.
final class InlineImageCommand extends InlineImageEvent {
  InlineImageCommand(this.protocol, Map<String, String> options, this.source)
    : options = Map.unmodifiable(options);
  final InlineImageProtocolType protocol;
  final Map<String, String> options;
  final InlineImageSource? source;
  bool _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    source?._release();
  }
}
