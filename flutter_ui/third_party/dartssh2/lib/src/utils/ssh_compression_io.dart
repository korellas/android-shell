import 'dart:io';
import 'dart:typed_data';

import '../ssh_errors.dart';
import '../ssh_packet.dart';

/// A persistent zlib dictionary, flushed once per SSH packet.
class SSHZlib {
  static const supported = true;

  SSHZlib({required bool compress})
      : _filter = compress
            ? RawZLibFilter.deflateFilter()
            : RawZLibFilter.inflateFilter();

  RawZLibFilter? _filter;

  Uint8List process(Uint8List input) {
    final filter = _filter;
    if (filter == null) throw StateError('SSH compression context is closed');
    try {
      if (input.length > SSHPacket.maxLength) {
        throw SSHPacketError('SSH compression input exceeds packet limit');
      }
      filter.process(input, 0, input.length);
      final output = BytesBuilder(copy: false);
      while (true) {
        // Z_SYNC_FLUSH keeps the dictionary while completing this packet.
        final chunk = filter.processed(flush: true, end: false);
        if (chunk == null) break;
        if (chunk.length > SSHPacket.maxLength - output.length) {
          throw SSHPacketError('SSH compression output exceeds packet limit');
        }
        output.add(chunk);
      }
      return output.takeBytes();
    } catch (error) {
      dispose();
      if (error is SSHError) rethrow;
      throw SSHPacketError('Invalid SSH compressed payload: $error');
    }
  }

  void dispose() {
    // The SDK owns/finalizes native zlib state. Do not drain malformed input
    // during cleanup: it may be the expansion that exceeded our packet limit.
    _filter = null;
  }
}
