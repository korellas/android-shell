// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:flutter/services.dart';
import '../engine.dart';
import 'ssh_keys.dart';
import 'stored_platform.dart';

AndroidEngine createIosEngine({SshPlatformCall? native}) {
  const channel = MethodChannel('dev.korellas.tilde/ios');
  final call =
      native ??
      (String method, Map<String, Object?> args) =>
          channel.invokeMethod<Object?>(method, args);
  final platform = () async {
    final directory = await call('storageDirectory', {}) as String;
    return StoredPlatform(
      file: File('$directory/state.json'),
      platform: 'ios',
      hardwareKeyboard: false,
      native: call,
      protect: (bytes) async =>
          await call('protect', {'bytes': bytes}) as Uint8List,
      unprotect: (bytes) async =>
          await call('unprotect', {'bytes': bytes}) as Uint8List,
      exportFile: (path) async {
        await call('exportFile', {'path': path});
      },
    );
  }();
  return AndroidEngine(
    platformCall: (method, args) async {
      try {
        return await (await platform).call(method, args);
      } on PlatformException {
        rethrow;
      } catch (error) {
        throw PlatformException(code: 'ios_platform', message: '$error');
      }
    },
    identityLoader: ({required id}) async =>
        (await platform).identities(id: id),
  );
}
