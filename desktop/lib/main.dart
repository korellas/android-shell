// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'windows_platform.dart';
import 'windows_secrets.dart';
import 'windows_system_keys.dart';
import 'windows_file_drag.dart';
import 'windows_aes_gcm.dart';
import 'package:android_shell_ui/ssh/ssh_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  for (final (family, asset) in [
    ('Pretendard', 'Pretendard-Regular.ttf'),
    ('JetBrainsMono', 'JetBrainsMono-Regular.ttf'),
  ]) {
    await (FontLoader(family)..addFont(
          rootBundle.load('packages/android_shell_ui/assets/fonts/$asset'),
        ))
        .load();
  }
  final root = Platform.environment['APPDATA'];
  if (root == null) throw StateError('Windows 사용자 데이터 폴더가 없습니다.');
  const channel = MethodChannel('dev.korellas.tilde/windows');
  final secrets = WindowsSecrets();
  final platform = WindowsPlatform(
    file: File('$root/Tilde/state.json'),
    native: (method, args) => channel.invokeMethod<Object?>(method, args),
    protect: secrets.protect,
    unprotect: secrets.unprotect,
  );
  final snapshot = await platform.call('snapshot', {}) as Map;
  if ((snapshot['preferences'] as Map)['fullscreen'] == true) {
    await channel.invokeMethod<void>('setFullscreen', {'enabled': true});
  }
  runApp(
    WindowsFileDrag(
      chooseDirectory: () => channel.invokeMethod<String>('chooseDirectory'),
      revealFolder: (path) =>
          channel.invokeMethod<void>('openFolder', {'path': path}),
      readSetting: (key) async =>
          ((await platform.call('snapshot', {})) as Map)['preferences'][key],
      writeSetting: (key, value) async {
        await platform.call('settings.update', {'key': key, 'value': value});
      },
      child: AndroidShellApp(
        engine: AndroidEngine(
          sshTransportFactory:
              ({
                required endpoints,
                required onOutput,
                required onState,
                required onError,
                required wantShell,
                required pty,
              }) => SshSession(
                endpoints: endpoints,
                onOutput: onOutput,
                onState: onState,
                onError: onError,
                wantShell: wantShell,
                pty: pty,
                aesGcmFactory: WindowsAesGcm.new,
              ),
          platformCall: (method, args) async {
            try {
              return await platform.call(method, args);
            } catch (error) {
              throw PlatformException(
                code: 'windows_platform',
                message: '$error',
              );
            }
          },
          identityLoader: platform.identities,
          systemIdentityLoader: loadWindowsSystemKeys,
        ),
      ),
    ),
  );
}
