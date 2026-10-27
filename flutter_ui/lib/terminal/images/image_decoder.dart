// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'inline_images.dart';

class _CancelledImage implements Exception {}

class _Pixels {
  _Pixels(this.image, this.reservation);
  final ui.Image image;
  final InlineImageReservation reservation;
  void dispose() {
    image.dispose();
    reservation.dispose();
  }
}

class _SourcePixels {
  _SourcePixels(this.codec, this.pixels, this.reservation, this.gap);
  final ui.Codec codec;
  ui.Image pixels;
  final InlineImageReservation reservation;
  int gap, deadline = 0;
  bool advancing = false, retired = false, released = false;
  void dispose() {
    retired = true;
    if (!advancing) release();
  }

  void release() {
    if (released) return;
    released = true;
    codec.dispose();
    pixels.dispose();
    reservation.dispose();
  }
}

/// Owns platform resources; bytes and retained pixel surfaces share one budget.
class InlineImageDecoder extends ChangeNotifier {
  InlineImageDecoder(this.budget, {this.canDecode, this.waitForInput});
  final Future<void> Function()? waitForInput;
  final bool Function()? canDecode;
  final InlineImageBudget budget;
  final _sources = <InlineImageSource, _SourcePixels>{};
  final _frames = <InlineImageFrame, _Pixels>{};
  final _pending = <InlineImageFrame>{};
  final _failed = <InlineImageFrame>{};
  Set<InlineImageFrame> _live = {};
  Set<InlineImageSource> _liveSources = {};
  bool _disposed = false;
  Future<void> _queue = Future.value();
  final _animations = <Future<void>>{};
  final _retired = <void Function()>[];
  int _activeJobs = 0, _revision = 0;
  Future<void> get drained async {
    await _queue;
    await Future.wait(_animations.toList());
  }

  void _releaseOrDefer(void Function() release) {
    if (_activeJobs == 0) {
      release();
    } else {
      _retired.add(release);
    }
  }

  void _flushRetired() {
    if (_activeJobs != 0) return;
    for (final release in _retired) {
      release();
    }
    _retired.clear();
  }

  void retain(Iterable<InlineImageFrame> frames) {
    _live = {};
    void visit(InlineImageFrame frame) {
      if (!_live.add(frame)) return;
      if (frame.background != null) visit(frame.background!);
      if (frame.foreground != null) visit(frame.foreground!);
    }

    for (final frame in frames) {
      visit(frame);
    }
    _liveSources = _live.expand((f) => f.sources).toSet();
    for (final frame in _frames.keys.toList()) {
      if (!_live.contains(frame)) {
        _releaseOrDefer(_frames.remove(frame)!.dispose);
      }
    }
    for (final source in _sources.keys.toList()) {
      if (!_liveSources.contains(source)) {
        _releaseOrDefer(_sources.remove(source)!.dispose);
      }
    }
    _failed.removeWhere((f) => !_live.contains(f));
  }

  ui.Image? imageFor(InlineImageFrame frame) {
    if (_disposed || !frame.displayAllowed) return null;
    if (frame.source != null) {
      final image = _sources[frame.source]?.pixels;
      if (image != null) return image;
    } else if (_frames[frame] case final cached?) {
      return cached.image;
    }
    if (canDecode?.call() == false ||
        _failed.contains(frame) ||
        !_pending.add(frame)) {
      return null;
    }
    _queue = _queue.then((_) async {
      _activeJobs++;
      try {
        await waitForInput?.call();
        await Future.wait(_animations.toList());
        if (_disposed || !_live.contains(frame)) return;
        await _decodeFrame(frame);
        if (!_disposed && _live.contains(frame)) notifyListeners();
      } catch (error) {
        if (!_disposed && error is! _CancelledImage) _failed.add(frame);
      } finally {
        _activeJobs--;
        _flushRetired();
        _pending.remove(frame);
        if (!_disposed && _live.contains(frame)) notifyListeners();
      }
    });
    return null;
  }

  Future<ui.Image> _decodeSource(InlineImageSource source) async {
    if (_sources[source] case final cached?) return cached.pixels;
    // Codec dependencies and its returned frame are conservatively all charged.
    final reservation = budget.reserveDecoded(
      source.width * source.height * 4 * (source.frameCount + 1) +
          (source.format == 100 ? source.encodedSize * 2 : 0),
    );
    InlineImageDecodeData? data;
    ui.Codec? codec;
    ui.Image? pixels;
    ui.ImmutableBuffer? rawBuffer;
    ui.ImageDescriptor? rawDescriptor;
    try {
      data = await source.openDecodeAsync(rgba: true);
      if (_disposed || !_liveSources.contains(source)) throw _CancelledImage();
      if (source.format == 100) {
        codec = await ui.instantiateImageCodec(data.bytes);
      } else {
        rawBuffer = await ui.ImmutableBuffer.fromUint8List(data.bytes);
        rawDescriptor = ui.ImageDescriptor.raw(
          rawBuffer,
          width: source.width,
          height: source.height,
          pixelFormat: ui.PixelFormat.rgba8888,
        );
        codec = await rawDescriptor.instantiateCodec();
      }
      if (codec.frameCount > source.frameCount) {
        throw StateError('Unexpected image frame count');
      }
      final next = await codec.getNextFrame();
      pixels = next.image;
      if (_disposed || !_liveSources.contains(source)) throw _CancelledImage();
      _sources[source] = _SourcePixels(
        codec,
        pixels,
        reservation,
        next.duration.inMilliseconds,
      );
      return pixels;
    } catch (_) {
      pixels?.dispose();
      codec?.dispose();
      reservation.dispose();
      rethrow;
    } finally {
      rawDescriptor?.dispose();
      rawBuffer?.dispose();
      data?.dispose();
    }
  }

  Future<ui.Image> _decodeFrame(InlineImageFrame frame) async {
    if (!frame.displayAllowed) throw StateError('Image consent is required');
    if (frame.source case final source?) return _decodeSource(source);
    if (_frames[frame] case final cached?) return cached.image;
    final revision = _revision;
    final background = frame.background == null
        ? null
        : await _decodeFrame(frame.background!);
    final foreground = frame.foreground == null
        ? null
        : await _decodeFrame(frame.foreground!);
    final reservation = budget.reserveDecoded(frame.width * frame.height * 4);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    ui.Picture? picture;
    ui.Image? pixels;
    try {
      canvas.drawColor(ui.Color(frame.color), ui.BlendMode.src);
      if (background != null) {
        canvas.drawImage(background, ui.Offset.zero, ui.Paint());
      }
      if (foreground != null) {
        final r = frame.sourceRect;
        final src = r == null
            ? ui.Rect.fromLTWH(
                0,
                0,
                foreground.width.toDouble(),
                foreground.height.toDouble(),
              )
            : ui.Rect.fromLTRB(
                r.left.toDouble(),
                r.top.toDouble(),
                r.right.toDouble(),
                r.bottom.toDouble(),
              );
        final dst = ui.Rect.fromLTWH(
          frame.x.toDouble(),
          frame.y.toDouble(),
          src.width,
          src.height,
        );
        canvas.drawImageRect(
          foreground,
          src,
          dst,
          ui.Paint()
            ..blendMode = frame.replace
                ? ui.BlendMode.src
                : ui.BlendMode.srcOver,
        );
      }
      picture = recorder.endRecording();
      pixels = await picture.toImage(frame.width, frame.height);
      if (_disposed || !_live.contains(frame) || revision != _revision) {
        throw _CancelledImage();
      }
      _frames[frame] = _Pixels(pixels, reservation);
      return pixels;
    } catch (_) {
      pixels?.dispose();
      reservation.dispose();
      rethrow;
    } finally {
      (picture ?? recorder.endRecording()).dispose();
    }
  }

  void advance(int now) {
    if (_disposed || _activeJobs > 0) return;
    for (final entry in _sources.entries.toList()) {
      final value = entry.value;
      if (value.codec.frameCount < 2 ||
          value.advancing ||
          now < value.deadline) {
        continue;
      }
      if (value.deadline == 0) {
        value.deadline = now + (value.gap > 0 ? value.gap : 40);
        continue;
      }
      value.advancing = true;
      late Future<void> task;
      task = () async {
        ui.Image? nextImage;
        try {
          final next = await value.codec.getNextFrame();
          nextImage = next.image;
          if (_disposed || !identical(_sources[entry.key], value)) return;
          value.pixels.dispose();
          value.pixels = nextImage;
          nextImage = null;
          value.gap = next.duration.inMilliseconds;
          value.deadline = now + (value.gap > 0 ? value.gap : 40);
          _revision++;
          for (final frame in _frames.keys.toList()) {
            if (frame.sources.contains(entry.key)) {
              _releaseOrDefer(_frames.remove(frame)!.dispose);
            }
          }
          notifyListeners();
        } catch (_) {
          value.deadline = now + 1000;
        } finally {
          nextImage?.dispose();
          value.advancing = false;
          if (value.retired) value.release();
          _animations.remove(task);
        }
      }();
      _animations.add(task);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final frame in _frames.values) {
      _releaseOrDefer(frame.dispose);
    }
    for (final source in _sources.values) {
      _releaseOrDefer(source.dispose);
    }
    _frames.clear();
    _sources.clear();
    super.dispose();
  }
}
