/*
 * ConnectBot Terminal
 * Copyright 2026 Kenny Root
 * SPDX-License-Identifier: Apache-2.0
 */
part of 'inline_images.dart';

enum _WireState { text, escape, prefix, passOsc, passApc, image, imageEscape }

class _Upload {
  _Upload(this.iterm, this.options, this.policy, this.budget)
    : bytes = _ImageBytes(budget, budget.limits.uploadBytes) {
    final raw =
        !iterm &&
        [null, '24', '32'].contains(options['f']) &&
        options['o'] == null;
    sink = raw ? ZLibEncoder().startChunkedConversion(bytes) : bytes;
    counter = _CountSink(
      raw ? budget.limits.maxPixels * 4 : budget.limits.uploadBytes,
      sink.add,
    );
    decoder = _ImageBase64(counter.add);
  }
  final bool iterm;
  final Map<String, String> options;
  final InlineImagePolicy policy;
  final InlineImageBudget budget;
  final _ImageBytes bytes;
  late final Sink<List<int>> sink;
  late final _CountSink counter;
  late _ImageBase64 decoder;
  bool closed = false, transferred = false;
  void nextChunk() {
    decoder.finish();
    decoder = _ImageBase64(counter.add);
  }

  InlineImageSource finish() {
    decoder.finish();
    sink.close();
    closed = true;
    var data = bytes;
    try {
      final format = iterm ? 100 : _integer(options, 'f', 32);
      if (format == 100 && options['o'] == 'z') {
        data = _ImageBytes(budget, budget.limits.uploadBytes);
        _inflate(bytes, data);
      }
      final metadata = format == 100
          ? _ImageMetadata.read(data, budget.limits)
          : null;
      final width = metadata?.width ?? _integer(options, 's');
      final height = metadata?.height ?? _integer(options, 'v');
      _validateSize(width, height, budget.limits);
      if (!iterm && format == 100) {
        _require(
          metadata!.mime == 'image/png',
          'EINVAL:Kitty f=100 requires PNG',
        );
      }
      if (format != 100) {
        final expected = width * height * (format ~/ 8);
        final count = _CountSink(expected, null, 'EINVAL:excess pixel data');
        _inflate(data, count);
        _require(count.count == expected, 'EINVAL:short pixel data');
      }
      if (!identical(data, bytes)) bytes.release();
      transferred = true;
      return InlineImageSource._(
        data,
        width,
        height,
        format,
        metadata?.mime,
        metadata?.frames ?? 1,
        policy,
      );
    } catch (_) {
      if (!identical(data, bytes)) data.release();
      rethrow;
    }
  }

  void dispose() {
    // Closing an aborted compressor must not reserve output or evict images.
    if (!transferred) bytes.release();
    if (!closed) {
      try {
        sink.close();
      } catch (_) {
        /* Failed transfers still release their reservation. */
      }
      closed = true;
    }
  }
}

/// Filters only OSC 1337 image commands and APC G. All other streams pass through
/// incrementally. Iterate each feed fully before feeding the next chunk.
class InlineImageProtocol {
  InlineImageProtocol({
    InlineImageBudget? budget,
    InlineImageLimits limits = const InlineImageLimits(),
    InlineImagePolicy policy = InlineImagePolicy.on,
  }) : budget = budget ?? InlineImageBudget(limits),
       _policy = policy;
  final InlineImageBudget budget;
  InlineImageLimits get limits => budget.limits;
  InlineImagePolicy _policy;
  InlineImagePolicy get policy => _policy;
  set policy(InlineImagePolicy value) {
    if (value == _policy) return;
    _abortUpload();
    _discard = _state == _WireState.image || _state == _WireState.imageEscape;
    _policy = value;
  }

  _WireState _state = _WireState.text;
  String _prefix = '', _header = '';
  bool _kitty = false, _payload = false, _discard = false;
  bool _passEscape = false, _disposed = false;
  bool _c1 = false, _cancelUpstreamString = false;
  Map<String, String> _keys = {};
  _Upload? _upload;

  Iterable<InlineImageEvent> feed(String chunk) sync* {
    if (_disposed) throw StateError('Inline image protocol is disposed');
    var text = StringBuffer();
    for (final value in chunk.codeUnits) {
      final events = <InlineImageEvent>[];
      try {
        switch (_state) {
          case _WireState.text:
            _normal(value, text);
          case _WireState.escape:
            _afterEscape(value, text);
          case _WireState.prefix:
            _prefix += String.fromCharCode(value);
            final candidates = _prefix.startsWith('\x1b_')
                ? const ['\x1b_G']
                : const [
                    '\x1b]1337;File=',
                    '\x1b]1337;MultipartFile=',
                    '\x1b]1337;FilePart=',
                    '\x1b]1337;FileEnd',
                    '\x1b]1337;Capabilities',
                  ];
            if (candidates.contains(_prefix)) {
              // The stripped introducer would have cancelled the passthrough
              // string in xterm. Preserve that boundary without its payload.
              if (_cancelUpstreamString) text.writeCharCode(0x18);
              _cancelUpstreamString = false;
              _kitty = _prefix.startsWith('\x1b_');
              _header = _kitty ? 'G' : _prefix.substring(7);
              _keys = {};
              _payload = _header == 'FilePart=';
              _discard = false;
              _state = _WireState.image;
            } else if (!candidates.any((s) => s.startsWith(_prefix))) {
              final wirePrefix = _wirePrefix;
              _prefix = '';
              if (value == 27 || value >= 0x80 && value <= 0x9f) {
                text.write(wirePrefix.substring(0, wirePrefix.length - 1));
                _cancelUpstreamString = true;
                _normal(value, text);
              } else {
                text.write(wirePrefix);
                _cancelUpstreamString = false;
                _state = value == 0x18 || value == 0x1a || !_kitty && value == 7
                    ? _WireState.text
                    : _kitty
                    ? _WireState.passApc
                    : _WireState.passOsc;
                _passEscape = false;
              }
            }
          case _WireState.passOsc:
          case _WireState.passApc:
            if (_passEscape) {
              _passEscape = false;
              if (value == 92) {
                text.write('\x1b\\');
                _state = _WireState.text;
              } else {
                _cancelUpstreamString = true;
                _afterEscape(value, text);
              }
            } else if (value == 27) {
              _passEscape = true;
            } else if (value == 0x9c ||
                value == 0x18 ||
                value == 0x1a ||
                _state == _WireState.passOsc && value == 7) {
              text.writeCharCode(value);
              _state = _WireState.text;
            } else if (value >= 0x80 && value <= 0x9f) {
              _cancelUpstreamString = true;
              _normal(value, text);
            } else {
              text.writeCharCode(value);
            }
          case _WireState.image:
            if (value == 0x18 || value == 0x1a) {
              _abortUpload();
              _state = _WireState.text;
            } else if (value == 27) {
              _state = _WireState.imageEscape;
            } else if (value == 0x9c || (!_kitty && value == 7)) {
              _state = _WireState.text;
              if (!_discard) _finish(events, String.fromCharCode(value));
            } else if (value >= 0x80 && value <= 0x9f) {
              _abortUpload();
              _normal(value, text);
            } else if (!_discard) {
              _accept(value);
            }
          case _WireState.imageEscape:
            if (value == 92) {
              _state = _WireState.text;
              if (!_discard) _finish(events, '\x1b\\');
            } else {
              _abortUpload();
              _afterEscape(value, text);
            }
        }
      } catch (error) {
        if (_kitty && policy != InlineImagePolicy.off) {
          final reply = _reply(_keys, _reason(error));
          if (reply != null) events.add(InlineImageReply(reply));
        }
        _abortUpload();
        _discard = true;
      }
      if (events.isNotEmpty) {
        if (text.isNotEmpty) {
          yield InlineImageText(text.toString());
          text = StringBuffer();
        }
        yield* events;
      }
    }
    if (text.isNotEmpty) yield InlineImageText(text.toString());
  }

  String get _wirePrefix => _c1
      ? '${String.fromCharCode(_kitty ? 0x9f : 0x9d)}${_prefix.substring(2)}'
      : _prefix;

  void _beginPrefix(bool kitty, bool c1) {
    _kitty = kitty;
    _c1 = c1;
    _prefix = kitty ? '\x1b_' : '\x1b]';
    _state = _WireState.prefix;
  }

  void _normal(int value, StringBuffer text) {
    if (value == 27) {
      _state = _WireState.escape;
    } else if (value == 0x9d || value == 0x9f) {
      _beginPrefix(value == 0x9f, true);
    } else {
      text.writeCharCode(value);
      _state = [0x90, 0x98, 0x9e].contains(value)
          ? _WireState.passApc
          : _WireState.text;
      _passEscape = false;
      _cancelUpstreamString = false;
    }
  }

  void _afterEscape(int value, StringBuffer text) {
    if (value == 93 || value == 95) {
      _beginPrefix(value == 95, false);
    } else if (value == 27) {
      text.write('\x1b');
      _state = _WireState.escape;
      _cancelUpstreamString = true;
    } else if (value >= 0x80 && value <= 0x9f) {
      text.write('\x1b');
      _cancelUpstreamString = true;
      _normal(value, text);
    } else {
      if (value == 99) _abortUpload(); // RIS ends any earlier multipart upload.
      text.write('\x1b${String.fromCharCode(value)}');
      _state = [80, 88, 94].contains(value)
          ? _WireState.passApc
          : _WireState.text;
      _passEscape = false;
      _cancelUpstreamString = false;
    }
  }

  void _accept(int value) {
    if (_payload) {
      if (policy != InlineImagePolicy.off) _upload?.decoder.accept(value);
      return;
    }
    if (_kitty && value == 59 ||
        !_kitty && value == 58 && _header.startsWith('File=')) {
      _payload = true;
      if (policy == InlineImagePolicy.off) return;
      if (_kitty) {
        _prepareKitty(true);
      } else {
        _abortUpload();
        _keys = _parse(_header.substring(5), ';');
        if (_keys['inline'] == '1') {
          _upload = _Upload(true, _keys, policy, budget);
        }
      }
      return;
    }
    _require(_header.length < 4096, 'E2BIG:image header exceeds limit');
    _header += String.fromCharCode(value);
  }

  Map<String, String> _parse(String value, String separator) {
    if (value.isEmpty) return {};
    final result = <String, String>{};
    for (final field in value.split(separator)) {
      final index = field.indexOf('=');
      _require(index >= 0, 'EINVAL:invalid image header');
      result[field.substring(0, index)] = field.substring(index + 1);
    }
    return result;
  }

  void _prepareKitty(bool hasPayload) {
    _keys = _parse(_header.substring(1), ',');
    if (!hasPayload && ![null, 't', 'T', 'q', 'f'].contains(_keys['a'])) return;
    if (_upload != null &&
        !_upload!.iterm &&
        _keys.keys.every((k) => ['m', 'q', 'a', 'i', 'I'].contains(k))) {
      final inherited = Map<String, String>.of(_upload!.options)..remove('m');
      _keys = {...inherited, ..._keys};
    } else if (hasPayload || _keys['m'] == '1') {
      _abortUpload();
      _require(
        [null, 'd'].contains(_keys['t']),
        'ENOTSUP:only stream transport is supported',
      );
      _require(
        [null, '24', '32', '100'].contains(_keys['f']),
        'ENOTSUP:unsupported pixel format',
      );
      _require(
        [null, 'z'].contains(_keys['o']),
        'ENOTSUP:unsupported compression',
      );
      _upload = _Upload(false, Map.of(_keys), policy, budget);
    }
  }

  void _finish(List<InlineImageEvent> events, String terminator) {
    if (!_kitty && _header == 'Capabilities') {
      events.add(
        InlineImageReply(
          '\x1b]1337;Capabilities=${policy == InlineImagePolicy.off ? '' : 'F'}\x1b\\',
        ),
      );
      return;
    }
    if (policy == InlineImagePolicy.off) return;
    if (_kitty) {
      if (!_payload) _prepareKitty(false);
      if (_keys['m'] == '1') {
        _upload?.nextChunk();
        return;
      }
      final action = _keys['a'] ?? 't';
      _require(
        ['t', 'T', 'q', 'p', 'd', 'f', 'a', 'c'].contains(action),
        'ENOTSUP:unsupported graphics action',
      );
      InlineImageSource? source;
      if (['t', 'T', 'q', 'f'].contains(action)) {
        _require(_upload != null, 'EINVAL:missing image payload');
        source = _upload!.finish();
      }
      events.add(
        InlineImageCommand(InlineImageProtocolType.kitty, _keys, source),
      );
      if (['t', 'T', 'q', 'f', 'd'].contains(action)) _abortUpload();
    } else if (_header.startsWith('MultipartFile=')) {
      _abortUpload();
      _keys = _parse(_header.substring(14), ';');
      if (_keys['inline'] == '1') {
        _upload = _Upload(true, _keys, policy, budget);
      }
    } else if (_header == 'FileEnd' ||
        _payload && _header.startsWith('File=')) {
      final upload = _upload;
      if (upload == null) return;
      _require(upload.iterm, 'EINVAL:unexpected FileEnd');
      final source = upload.finish();
      events.add(
        InlineImageCommand(
          InlineImageProtocolType.iterm2,
          upload.options,
          source,
        ),
      );
      _abortUpload();
    } else if (_header != 'FilePart=') {
      events.add(
        InlineImageText('${_c1 ? '\x9d' : '\x1b]'}1337;$_header$terminator'),
      );
    }
  }

  void _abortUpload() {
    _upload?.dispose();
    _upload = null;
  }

  void reset() {
    _abortUpload();
    _state = _WireState.text;
    _prefix = _header = '';
    _keys = {};
    _discard = false;
    _passEscape = _cancelUpstreamString = _c1 = false;
  }

  void dispose() {
    reset();
    _disposed = true;
  }
}
