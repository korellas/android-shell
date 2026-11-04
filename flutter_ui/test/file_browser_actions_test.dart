// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:io';
import 'package:android_shell_ui/files/file_browser.dart';
import 'package:android_shell_ui/ssh/app_session.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'sftp_file_operations_test.dart' show FakeFiles;
import 'ui_engine_fixture.dart';
import 'label_layout_test.dart' show capture;
import 'package:android_shell_ui/l10n/strings.dart';

class BrowserFiles extends FakeFiles {
  @override
  Future<String> absolute(String path) async => path == '.' ? '/home' : path;
}

class BrowserSession extends AppSshSession {
  BrowserSession(this.files, VoidCallback changed)
    : super(
        id: 1,
        prepared: {
          'host': {'id': 1},
          'profile': {},
        },
        platform: (_, _) async => null,
        onChanged: changed,
      );
  final BrowserFiles files;
  @override
  bool get connected => true;
  @override
  Future<void> connect() async {}
  @override
  Future<SftpClient> openSftp() async => files;
}

class BrowserEngine extends UiEngineFixture {
  BrowserEngine(this.files);
  final BrowserFiles files;
  @override
  Future<AppSshSession> createFileConnection(
    int hostId, {
    required VoidCallback onChanged,
  }) async => BrowserSession(files, onChanged);
}

class ConflictFiles extends BrowserFiles {
  @override
  Future<void> link(String target, String path) async {
    nodes[path] = SftpFileAttrs(mode: SftpFileMode.value(0xa000));
  }
}

class UploadEngine extends BrowserEngine {
  UploadEngine(super.files, this.path);
  final String path;
  @override
  Future<dynamic> query(
    String method, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (method == 'file.pickUpload') return {'path': path, 'name': 'old.txt'};
    return super.query(method, args);
  }
}

void main() {
  setUpAll(() async {
    for (final (family, path) in [
      ('Pretendard', 'assets/fonts/Pretendard-Regular.ttf'),
      ('D2Coding', 'assets/fonts/D2Coding-Regular.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  late BrowserFiles files;
  Future<void> show(WidgetTester tester, {ThemeData? theme}) async {
    files = BrowserFiles()
      ..nodes.addAll({
        '/home': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
        '/home/old.txt': SftpFileAttrs(size: 10),
      });
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: FileBrowserPage(
          engine: BrowserEngine(files),
          host: const {'id': 1, 'nickname': 'test'},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Windows path and search are quiet until hovered or focused',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final theme = tildeTheme(Brightness.dark, UiEngineFixture());
      await show(tester, theme: theme);
      final path = find.byKey(const ValueKey('file-path-field'));
      final sample = tester.getRect(path).topRight + const Offset(-140, 10);
      Future<Color> pathColor() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        final (bytes, imageWidth) = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final width = image.width;
          image.dispose();
          return (bytes, width);
        }))!;
        final offset = (sample.dy.floor() * imageWidth + sample.dx.floor()) * 4;
        final color = Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
        return color;
      }

      expect(await pathColor(), theme.colorScheme.surfaceContainerHigh);
      await capture(tester, 'windows-path-idle');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(sample);
      await tester.pumpAndSettle();
      expect(await pathColor(), theme.colorScheme.surfaceContainerHighest);
      await capture(tester, 'windows-path-hover');
      await tester.tapAt(sample);
      await tester.pumpAndSettle();
      final address = find.widgetWithText(TextField, '원격 폴더 경로');
      final input = tester.widget<InputDecorator>(
        find.descendant(of: address, matching: find.byType(InputDecorator)),
      );
      expect(input.isFocused, isTrue);
      expect(
        input.decoration.focusedBorder!.borderSide.color,
        theme.colorScheme.primary,
      );
      expect(input.decoration.focusedBorder!.borderSide.width, 2);
      await capture(tester, 'windows-path-edit');
      final search = find.widgetWithText(TextField, '현재 폴더에서 찾기');
      final searchInput = tester.widget<InputDecorator>(
        find.descendant(of: search, matching: find.byType(InputDecorator)),
      );
      expect(searchInput.decoration.enabledBorder!.borderSide, BorderSide.none);
      expect(
        searchInput.decoration.focusedBorder!.borderSide.color,
        theme.colorScheme.primary,
      );
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.windows}),
  );

  Future<void> action(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('old.txt 작업'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(label).last);
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  for (final occupied in [false, true]) {
    testWidgets('keep both uses first available suffix, occupied=$occupied', (
      t,
    ) async {
      final temporary = Directory.systemTemp.createTempSync('tilde-conflict-');
      addTearDown(() => temporary.deleteSync(recursive: true));
      final source = Link('${temporary.path}/old.txt')..createSync('target');
      final files = ConflictFiles()
        ..nodes.addAll({
          '/home': SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
          '/home/old.txt': SftpFileAttrs(size: 10),
          if (occupied) '/home/old (1).txt': SftpFileAttrs(size: 15),
        });
      final engine = UploadEngine(files, source.path);
      addTearDown(engine.dispose);
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: FileBrowserPage(
            engine: engine,
            host: const {'id': 1, 'nickname': 'test'},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, '업로드'));
      for (
        var i = 0;
        i < 50 &&
            find.byKey(const ValueKey('conflict-incoming')).evaluate().isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('conflict-incoming')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('conflict-incoming')));
      await t.pump();
      await t.tap(find.text('둘 다 보관'));
      final destination = '/home/old (${occupied ? 2 : 1}).txt';
      for (var i = 0; i < 50 && !files.nodes.containsKey(destination); i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(files.nodes[destination]?.isSymbolicLink, isTrue);
      expect(files.nodes['/home/old.txt']?.size, 10);
      if (occupied) expect(files.nodes['/home/old (1).txt']?.size, 15);
      expect(files.allowedOverwrite, isFalse);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }

  testWidgets(
    'delete cancel makes no changes; confirmed deletion refreshes listing',
    (tester) async {
      await show(tester);
      await action(tester, '삭제');
      expect(find.text('1개 항목을 영구 삭제할까요?'), findsOneWidget);
      expect(files.removed, isEmpty);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(files.removed, isEmpty);
      await action(tester, '삭제');
      await tester.tap(find.widgetWithText(FilledButton, '영구 삭제'));
      await tester.pumpAndSettle();
      expect(files.removed, ['/home/old.txt']);
      expect(find.text('old.txt'), findsNothing);
      expect(find.text('1개 항목을 삭제했습니다.'), findsOneWidget);
    },
  );
  testWidgets(
    'rename validates and refreshes the row; new folder is available',
    (tester) async {
      await show(tester);
      await action(tester, '이름 변경');
      await tester.enterText(find.byType(TextFormField), '../escape');
      await tester.tap(find.byTooltip('이름 변경 적용'));
      await tester.pumpAndSettle();
      expect(files.nodes.containsKey('/home/old.txt'), isTrue);
      expect(find.textContaining('경로 구분자'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '새 이름.txt');
      await tester.tap(find.byTooltip('이름 변경 적용'));
      await tester.pumpAndSettle();
      expect(find.text('새 이름.txt'), findsOneWidget);
      expect(files.allowedOverwrite, isFalse);
      await tester.tap(find.widgetWithText(TextButton, '새 폴더'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '새 폴더');
      await tester.tap(find.text('만들기'));
      await tester.pumpAndSettle();
      expect(files.nodes['/home/새 폴더']?.isDirectory, isTrue);
      expect(find.text('새 폴더'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('rename collision reports an error and keeps both files', (
    tester,
  ) async {
    await show(tester);
    files.nodes['/home/taken'] = SftpFileAttrs();
    await action(tester, '이름 변경');
    await tester.enterText(find.byType(TextFormField), 'taken');
    await tester.tap(find.byTooltip('이름 변경 적용'));
    await tester.pumpAndSettle();
    expect(files.nodes.keys, containsAll(['/home/old.txt', '/home/taken']));
    expect(find.textContaining('같은 이름의'), findsWidgets);
  });
}
