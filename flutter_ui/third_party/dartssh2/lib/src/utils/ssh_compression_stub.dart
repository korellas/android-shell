import 'dart:typed_data';

/// Compression is opt-in and available only where the SDK provides zlib.
class SSHZlib {
  static const supported = false;

  SSHZlib({required bool compress}) {
    throw UnsupportedError('SSH compression requires the Dart VM');
  }

  Uint8List process(Uint8List input) =>
      throw UnsupportedError('SSH compression requires the Dart VM');

  void dispose() {}
}
