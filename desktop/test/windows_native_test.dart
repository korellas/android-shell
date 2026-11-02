// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilde_desktop/windows_secrets.dart';

void main() {
  test(
    'Windows protects credentials for the current account and restores Unicode',
    () async {
      final secrets = WindowsSecrets();
      final original = Uint8List.fromList(utf8.encode('테스트 전용 credential'));
      final sealed = await secrets.protect(original);
      expect(sealed, isNot(equals(original)));
      expect(await secrets.unprotect(sealed), original);
    },
    skip: !Platform.isWindows,
  );
}
