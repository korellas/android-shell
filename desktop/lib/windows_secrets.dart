// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class WindowsSecrets {
  Future<Uint8List> protect(Uint8List bytes) => _convert(bytes, true);
  Future<Uint8List> unprotect(Uint8List bytes) => _convert(bytes, false);

  Future<Uint8List> _convert(Uint8List bytes, bool protect) async {
    final script =
        '''
\$ErrorActionPreference = 'Stop'
\$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Security
\$bytes = [Convert]::FromBase64String([Console]::In.ReadToEnd())
\$result = [Security.Cryptography.ProtectedData]::${protect ? 'Protect' : 'Unprotect'}(\$bytes, \$null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
[Console]::Out.Write([Convert]::ToBase64String(\$result))
''';
    final encoded = base64Encode([
      for (final unit in script.codeUnits) ...[unit & 255, unit >> 8],
    ]);
    final process = await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      encoded,
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final error = process.stderr.transform(utf8.decoder).join();
    process.stdin.write(base64Encode(bytes));
    await process.stdin.close();
    final exit = await process.exitCode;
    final result = await output;
    final failure = await error;
    if (exit != 0) {
      throw FileSystemException('Windows 계정의 인증정보 보호에 실패했습니다. $failure');
    }
    return base64Decode(result.trim());
  }
}
