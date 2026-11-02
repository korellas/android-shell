// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:ffi';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:ffi/ffi.dart';

final class _AuthInfo extends Struct {
  @Uint32()
  external int size;
  @Uint32()
  external int version;
  external Pointer<Uint8> nonce;
  @Uint32()
  external int nonceSize;
  external Pointer<Uint8> aad;
  @Uint32()
  external int aadSize;
  external Pointer<Uint8> tag;
  @Uint32()
  external int tagSize;
  external Pointer<Uint8> macContext;
  @Uint32()
  external int macContextSize;
  @Uint32()
  external int totalAadSize;
  @Uint64()
  external int totalDataSize;
  @Uint32()
  external int flags;
}

typedef _OpenNative =
    Int32 Function(
      Pointer<Pointer<Void>>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Uint32,
    );
typedef _SetNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf16>,
      Pointer<Uint8>,
      Uint32,
      Uint32,
    );
typedef _GetNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Utf16>,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint32>,
      Uint32,
    );
typedef _GenerateNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Pointer<Void>>,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint8>,
      Uint32,
      Uint32,
    );
typedef _CryptNative =
    Int32 Function(
      Pointer<Void>,
      Pointer<Uint8>,
      Uint32,
      Pointer<_AuthInfo>,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint8>,
      Uint32,
      Pointer<Uint32>,
      Uint32,
    );
typedef _DestroyNative = Int32 Function(Pointer<Void>);
typedef _CloseNative = Int32 Function(Pointer<Void>, Uint32);

class _Cng {
  _Cng() : library = DynamicLibrary.open('bcrypt.dll');
  static final instance = _Cng();
  final DynamicLibrary library;
  late final open = library
      .lookupFunction<
        _OpenNative,
        int Function(
          Pointer<Pointer<Void>>,
          Pointer<Utf16>,
          Pointer<Utf16>,
          int,
        )
      >('BCryptOpenAlgorithmProvider');
  late final set = library
      .lookupFunction<
        _SetNative,
        int Function(Pointer<Void>, Pointer<Utf16>, Pointer<Uint8>, int, int)
      >('BCryptSetProperty');
  late final get = library
      .lookupFunction<
        _GetNative,
        int Function(
          Pointer<Void>,
          Pointer<Utf16>,
          Pointer<Uint8>,
          int,
          Pointer<Uint32>,
          int,
        )
      >('BCryptGetProperty');
  late final generate = library
      .lookupFunction<
        _GenerateNative,
        int Function(
          Pointer<Void>,
          Pointer<Pointer<Void>>,
          Pointer<Uint8>,
          int,
          Pointer<Uint8>,
          int,
          int,
        )
      >('BCryptGenerateSymmetricKey');
  late final encrypt = library
      .lookupFunction<
        _CryptNative,
        int Function(
          Pointer<Void>,
          Pointer<Uint8>,
          int,
          Pointer<_AuthInfo>,
          Pointer<Uint8>,
          int,
          Pointer<Uint8>,
          int,
          Pointer<Uint32>,
          int,
        )
      >('BCryptEncrypt');
  late final decrypt = library
      .lookupFunction<
        _CryptNative,
        int Function(
          Pointer<Void>,
          Pointer<Uint8>,
          int,
          Pointer<_AuthInfo>,
          Pointer<Uint8>,
          int,
          Pointer<Uint8>,
          int,
          Pointer<Uint32>,
          int,
        )
      >('BCryptDecrypt');
  late final destroy = library
      .lookupFunction<_DestroyNative, int Function(Pointer<Void>)>(
        'BCryptDestroyKey',
      );
  late final close = library
      .lookupFunction<_CloseNative, int Function(Pointer<Void>, int)>(
        'BCryptCloseAlgorithmProvider',
      );
}

/// CNG owns the expanded AES key. Packet scratch buffers are reused, and no
/// plaintext is returned until CNG has verified the SSH authentication tag.
class WindowsAesGcm implements SSHAesGcm {
  WindowsAesGcm(Uint8List key) {
    if (key.length != 16 && key.length != 32) {
      throw ArgumentError('SSH AES-GCM requires a 128- or 256-bit key');
    }
    try {
      using((arena) {
        final algorithm = arena<Pointer<Void>>();
        _check(
          _cng.open(
            algorithm,
            'AES'.toNativeUtf16(allocator: arena),
            nullptr,
            0,
          ),
        );
        _algorithm = algorithm.value;
        final mode = 'ChainingModeGCM'.toNativeUtf16(allocator: arena);
        _check(
          _cng.set(
            _algorithm,
            'ChainingMode'.toNativeUtf16(allocator: arena),
            mode.cast(),
            ('ChainingModeGCM'.length + 1) * 2,
            0,
          ),
        );
        final objectLength = arena<Uint32>(), count = arena<Uint32>();
        _check(
          _cng.get(
            _algorithm,
            'ObjectLength'.toNativeUtf16(allocator: arena),
            objectLength.cast(),
            sizeOf<Uint32>(),
            count,
            0,
          ),
        );
        _keyObjectSize = objectLength.value;
        _keyObject = calloc<Uint8>(_keyObjectSize);
        final secret = arena<Uint8>(key.length);
        secret.asTypedList(key.length).setAll(0, key);
        final handle = arena<Pointer<Void>>();
        try {
          _check(
            _cng.generate(
              _algorithm,
              handle,
              _keyObject,
              _keyObjectSize,
              secret,
              key.length,
              0,
            ),
          );
          _key = handle.value;
        } finally {
          secret.asTypedList(key.length).fillRange(0, key.length, 0);
        }
      });
      _info = calloc<_AuthInfo>();
      _nonce = calloc<Uint8>(12);
      _tag = calloc<Uint8>(16);
      _written = calloc<Uint32>();
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  final _Cng _cng = _Cng.instance;
  Pointer<Void> _algorithm = nullptr, _key = nullptr;
  Pointer<Uint8> _keyObject = nullptr, _nonce = nullptr, _tag = nullptr;
  Pointer<Uint8> _input = nullptr, _output = nullptr, _aad = nullptr;
  Pointer<_AuthInfo> _info = nullptr;
  Pointer<Uint32> _written = nullptr;
  int _keyObjectSize = 0, _capacity = 0, _aadCapacity = 0;
  bool _disposed = false;

  void _check(int status) {
    if (status < 0) {
      throw SSHInternalError(
        StateError(
          'Windows AES-GCM failed (0x${(status & 0xffffffff).toRadixString(16)})',
        ),
      );
    }
  }

  @override
  Uint8List process({
    required Uint8List nonce,
    required Uint8List aad,
    required Uint8List input,
    required bool encrypt,
  }) {
    if (_disposed) throw StateError('AES-GCM context is disposed');
    if (nonce.length != 12) {
      throw ArgumentError('SSH AES-GCM nonce must be 12 bytes');
    }
    if (!encrypt && input.length < 16) {
      throw SSHPacketError('AEAD authentication failed');
    }
    final size = encrypt ? input.length : input.length - 16;
    if (size + 16 > _capacity) {
      _clear(_input, _capacity);
      _input = nullptr;
      _clear(_output, _capacity);
      _output = nullptr;
      _capacity = size + 16;
      _input = calloc<Uint8>(_capacity);
      _output = calloc<Uint8>(_capacity);
    }
    if (aad.length > _aadCapacity) {
      _clear(_aad, _aadCapacity);
      _aad = nullptr;
      _aadCapacity = aad.length;
      _aad = calloc<Uint8>(_aadCapacity);
    }
    _nonce.asTypedList(12).setAll(0, nonce);
    if (aad.isNotEmpty) _aad.asTypedList(aad.length).setAll(0, aad);
    _input.asTypedList(size).setAll(0, Uint8List.sublistView(input, 0, size));
    if (!encrypt) {
      _tag.asTypedList(16).setAll(0, Uint8List.sublistView(input, size));
    }
    final info = _info.ref;
    info.size = sizeOf<_AuthInfo>();
    info.version = 1;
    info.nonce = _nonce;
    info.nonceSize = 12;
    info.aad = aad.isEmpty ? nullptr : _aad;
    info.aadSize = aad.length;
    info.tag = _tag;
    info.tagSize = 16;
    info.macContext = nullptr;
    info.macContextSize = 0;
    info.totalAadSize = 0;
    info.totalDataSize = 0;
    info.flags = 0;
    final operation = encrypt ? _cng.encrypt : _cng.decrypt;
    final status = operation(
      _key,
      _input,
      size,
      _info,
      nullptr,
      0,
      _output,
      _capacity,
      _written,
      0,
    );
    if (status < 0) {
      _output.asTypedList(_capacity).fillRange(0, _capacity, 0);
      if (!encrypt && (status & 0xffffffff) == 0xc000a002) {
        throw SSHPacketError('AEAD authentication failed');
      }
      _check(status);
    }
    if (_written.value != size) {
      throw SSHInternalError(StateError('Unexpected AES-GCM output length'));
    }
    final result = Uint8List(size + (encrypt ? 16 : 0));
    result.setRange(0, size, _output.asTypedList(size));
    if (encrypt) result.setRange(size, result.length, _tag.asTypedList(16));
    return result;
  }

  void _clear(Pointer<Uint8> pointer, int length) {
    if (pointer == nullptr) return;
    pointer.asTypedList(length).fillRange(0, length, 0);
    calloc.free(pointer);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_key != nullptr) _cng.destroy(_key);
    if (_algorithm != nullptr) _cng.close(_algorithm, 0);
    _clear(_keyObject, _keyObjectSize);
    _clear(_nonce, 12);
    _clear(_tag, 16);
    _clear(_input, _capacity);
    _clear(_output, _capacity);
    _clear(_aad, _aadCapacity);
    if (_info != nullptr) calloc.free(_info);
    if (_written != nullptr) calloc.free(_written);
  }
}
