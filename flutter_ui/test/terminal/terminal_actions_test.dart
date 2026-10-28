/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:android_shell_ui/terminal/terminal_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm2/xterm.dart';

void main() {
  late Terminal terminal;
  late TerminalController controller;
  late GlobalKey<TerminalViewState> viewKey;
  late List<String> edits;
  late List<String> pastes;
  late List<String> shares;
  String? clipboard;

  setUp(() {
    terminal = Terminal();
    controller = TerminalController();
    viewKey = GlobalKey<TerminalViewState>();
    edits = [];
    pastes = [];
    shares = [];
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
  });
  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> mount(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 240,
              child: TerminalActions(
                terminal: terminal,
                controller: controller,
                terminalViewKey: viewKey,
                enabled: enabled,
                onEdit: (text) async {
                  expect(controller.selection, isNull);
                  edits.add(text);
                },
                onPaste: pastes.add,
                onShare: shares.add,
                child: TerminalView(
                  terminal,
                  key: viewKey,
                  controller: controller,
                  readOnly: true,
                  hardwareKeyboardOnly: true,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> select(
    WidgetTester tester,
    CellOffset begin,
    CellOffset end,
  ) async {
    controller.setSelection(
      terminal.buffer.createAnchorFromOffset(begin),
      terminal.buffer.createAnchorFromOffset(end),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('one contextual menu copies exact text and clears selection', (
    tester,
  ) async {
    await mount(tester);
    terminal.write('  alpha  beta  ');
    await select(tester, const CellOffset(0, 0), const CellOffset(9, 0));
    expect(find.text('복사'), findsOneWidget);
    expect(find.text('편집 후 전송'), findsOneWidget);
    await tester.tap(find.text('복사'));
    await tester.pump();
    await tester.pump();
    expect(clipboard, '  alpha  ');
    expect(controller.selection, isNull);
    expect(find.text('복사'), findsNothing);
  });

  testWidgets('edit captures multiline selection before clearing', (
    tester,
  ) async {
    await mount(tester);
    terminal.write('first\r\n  second  ');
    await select(tester, const CellOffset(2, 0), const CellOffset(8, 1));
    final exactText = terminal.buffer.getText(controller.selection);
    await tester.tap(find.text('편집 후 전송'));
    await tester.pump();
    expect(edits, [exactText]);
    expect(exactText, contains('\n  second'));
    expect(controller.selection, isNull);
  });

  testWidgets(
    'overflow uses the same popup for paste share and selection controls',
    (tester) async {
      await mount(tester);
      terminal.write('first\r\nsecond');
      await select(tester, const CellOffset(0, 0), const CellOffset(3, 0));
      await tester.tap(find.byTooltip('선택 메뉴 더보기'));
      await tester.pump();
      expect(find.text('복사'), findsOneWidget);
      await tester.tap(find.text('공유'));
      expect(shares, ['fir']);
      await tester.pump();
      await tester.tap(find.byTooltip('선택 메뉴 더보기'));
      await tester.pump();
      await tester.ensureVisible(find.text('블록'));
      await tester.tap(find.text('블록'));
      await tester.pumpAndSettle();
      expect(controller.selectionMode, SelectionMode.block);
      expect(find.text('선택 단위'), findsOneWidget);
      await tester.ensureVisible(find.text('줄'));
      await tester.tap(find.text('줄'));
      await tester.pumpAndSettle();
      expect(controller.selectionMode, SelectionMode.line);
      clipboard = 'exact paste\n';
      await tester.ensureVisible(find.text('붙여넣기'));
      await tester.tap(find.text('붙여넣기'));
      await tester.pump();
      expect(pastes, ['exact paste\n']);
      expect(controller.selection, isNull);
    },
  );

  testWidgets('select line and all use terminal buffer bounds', (tester) async {
    await mount(tester);
    terminal.write('first\r\nsecond');
    await select(tester, const CellOffset(1, 1), const CellOffset(4, 1));
    await tester.tap(find.byTooltip('선택 메뉴 더보기'));
    await tester.pump();
    await tester.tap(find.text('줄 선택'));
    await tester.pump();
    expect(terminal.buffer.getText(controller.selection).trim(), 'second');
    await tester.tap(find.byTooltip('선택 메뉴 더보기'));
    await tester.pump();
    await tester.tap(find.text('전체 선택'));
    await tester.pump();
    expect(controller.selection!.begin, const CellOffset(0, 0));
    expect(
      controller.selection!.end,
      CellOffset(terminal.viewWidth, terminal.buffer.height - 1),
    );
  });

  testWidgets('menu follows scroll and stays inside terminal viewport', (
    tester,
  ) async {
    await mount(tester);
    terminal.write(List.generate(80, (i) => 'line $i\r\n').join());
    await tester.pump();
    await tester.pump();
    final row = terminal.buffer.height - 5;
    await select(tester, CellOffset(0, row), CellOffset(3, row));
    Rect menuRect() =>
        tester.getRect(find.byKey(const ValueKey('terminal-selection-menu')));
    final before = menuRect();
    final viewport = tester.getRect(find.byType(TerminalActions));
    expect(viewport.contains(before.topLeft), isTrue);
    expect(
      viewport.contains(before.bottomRight - const Offset(0.1, 0.1)),
      isTrue,
    );
    final position = viewKey.currentState!.scrollableState!.position;
    position.jumpTo(position.pixels - 30);
    await tester.pump();
    await tester.pump();
    final after = menuRect();
    expect(after.top, isNot(before.top));
    expect(
      viewport.contains(after.bottomRight - const Offset(0.1, 0.1)),
      isTrue,
    );
    await tester.tap(find.byTooltip('선택 메뉴 더보기'));
    await tester.pump();
    await tester.ensureVisible(find.text('보이는 화면 선택'));
    await tester.tap(find.text('보이는 화면 선택'));
    await tester.pump();
    final render = viewKey.currentState!.renderTerminal;
    expect(controller.selection!.begin.y, render.getCellOffset(Offset.zero).y);
    expect(
      controller.selection!.end.y,
      render.getCellOffset(Offset(0, render.size.height - 0.01)).y,
    );
  });

  testWidgets(
    'endpoint handles resize block selection without a second toolbar',
    (tester) async {
      await mount(tester);
      terminal.write(
        'first row abcdefghijklmnopqrstuvwxyz\r\nsecond row abcdefghijklmnopqrstuvwxyz\r\nthird row',
      );
      await select(tester, const CellOffset(4, 1), const CellOffset(8, 2));
      controller.setSelectionMode(SelectionMode.block);
      await tester.pump();
      await tester.pump();
      final handle = find.bySemanticsLabel('선택 끝');
      expect(handle, findsOneWidget);
      expect(tester.getSize(handle), const Size(48, 48));
      final begin = controller.selection!.begin;
      final end = controller.selection!.end;
      final render = viewKey.currentState!.renderTerminal;
      final cellWidth =
          render.getOffset(const CellOffset(1, 0)).dx -
          render.getOffset(const CellOffset(0, 0)).dx;
      await tester.drag(handle, Offset(cellWidth * 4, 0));
      await tester.pump();
      await tester.pump();
      expect(controller.selection!.begin, begin);
      expect(controller.selection!.end.x, end.x + 4);
      expect(controller.selectionMode, SelectionMode.block);
      expect(find.text('복사'), findsOneWidget);
      await tester.tap(find.text('복사'));
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel('선택 시작'), findsNothing);
      expect(find.bySemanticsLabel('선택 끝'), findsNothing);
    },
  );

  testWidgets('held endpoint drag scrolls and stops on release or disable', (
    tester,
  ) async {
    await mount(tester);
    terminal.write(List.generate(80, (i) => 'line $i\r\n').join());
    await tester.pump();
    await tester.pump();
    final position = viewKey.currentState!.scrollableState!.position;
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pump();
    await tester.pump();
    final render = viewKey.currentState!.renderTerminal;
    final firstRow = render.getCellOffset(Offset.zero).y;
    await select(
      tester,
      CellOffset(1, firstRow + 1),
      CellOffset(6, firstRow + 3),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('선택 끝')),
    );
    final before = position.pixels;
    final bottom = tester.getBottomLeft(find.byType(TerminalActions));
    await gesture.moveTo(Offset(bottom.dx + 160, bottom.dy + 32));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(position.pixels, greaterThan(before));
    await gesture.up();
    await tester.pumpAndSettle();
    final released = position.pixels;
    await tester.pump(const Duration(milliseconds: 300));
    expect(position.pixels, released);
    await select(
      tester,
      CellOffset(1, render.getCellOffset(Offset.zero).y + 1),
      CellOffset(6, render.getCellOffset(Offset.zero).y + 3),
    );
    final disabledGesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('선택 끝')),
    );
    await disabledGesture.moveTo(Offset(bottom.dx + 160, bottom.dy + 32));
    await tester.pump();
    await mount(tester, enabled: false);
    await tester.pumpAndSettle();
    final disabled = position.pixels;
    await tester.pump(const Duration(milliseconds: 300));
    expect(position.pixels, disabled);
    await disabledGesture.up();
  });

  testWidgets(
    'session replacement detaches listeners and cancels handle state',
    (tester) async {
      await mount(tester);
      terminal.write('old session');
      await select(tester, const CellOffset(2, 1), const CellOffset(6, 2));
      final gesture = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('선택 끝')),
      );
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await tester.pump();
      expect(find.text('복사'), findsNothing);
      final oldTerminal = terminal;
      final oldController = controller;
      terminal = Terminal()..write('replacement');
      controller = TerminalController()
        ..setSelection(
          terminal.buffer.createAnchor(0, 0),
          terminal.buffer.createAnchor(4, 0),
        );
      viewKey = GlobalKey<TerminalViewState>();
      await mount(tester);
      expect(oldTerminal.listeners, isEmpty);
      expect(find.text('복사'), findsOneWidget);
      await gesture.up();
      oldController.dispose();
      await tester.pumpWidget(const SizedBox());
      expect(terminal.listeners, isEmpty);
    },
  );

  testWidgets('disabled actions do not expose a menu or callbacks', (
    tester,
  ) async {
    await mount(tester, enabled: false);
    terminal.write('text');
    await select(tester, const CellOffset(0, 0), const CellOffset(4, 0));
    expect(find.text('복사'), findsNothing);
    expect(find.text('편집 후 전송'), findsNothing);
    expect(edits, isEmpty);
    expect(pastes, isEmpty);
    expect(shares, isEmpty);
    await tester.pumpWidget(const SizedBox());
    terminal.write('after disposal');
    controller.clearSelection();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
