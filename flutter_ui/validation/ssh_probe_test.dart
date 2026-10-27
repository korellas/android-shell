// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

import 'ssh_probe.dart';

void main() {
  testWidgets('the probe runs without an Android engine channel', (
    tester,
  ) async {
    await tester.pumpWidget(const SshProbeApp());
    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.text('로컬 입력 검증'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final tab = find.widgetWithText(TextButton, 'tab');
    expect(tester.getSize(tab).width, 56);
    expect(tester.getSize(tab).height, greaterThanOrEqualTo(44));
    expect(
      tester.getTopRight(tab).dx,
      tester.view.physicalSize.width / tester.view.devicePixelRatio - 4,
    );
  });

  testWidgets('the connection form rejects empty endpoints and cancels', (
    tester,
  ) async {
    await tester.pumpWidget(const SshProbeApp());
    await tester.tap(find.widgetWithText(TextButton, '연결'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '연결'));
    await tester.pumpAndSettle();
    expect(find.text('호스트를 입력하세요'), findsOneWidget);
    expect(find.text('사용자를 입력하세요'), findsOneWidget);
    expect(find.text('서버에서 확인한 SHA256 지문을 입력하세요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('SSH 검증 연결'), findsNothing);
    expect(find.text('로컬 입력 검증'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
