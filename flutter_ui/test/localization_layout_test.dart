// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:android_shell_ui/editors.dart';
import 'package:android_shell_ui/engine.dart';
import 'package:android_shell_ui/files/file_browser_listing.dart';
import 'package:android_shell_ui/files/file_dialogs.dart';
import 'package:android_shell_ui/l10n/strings.dart';
import 'package:android_shell_ui/main.dart';
import 'package:android_shell_ui/settings.dart';
import 'package:android_shell_ui/terminal/terminal_prompt.dart';
import 'package:android_shell_ui/tilde_design.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ui_engine_fixture.dart';

const _output = String.fromEnvironment('TILDE_LOCALE_REPORT_DIR');
// Widget tests lack device CJK fallbacks; screenshot runs can supply one.
const _cjkFont = String.fromEnvironment('TILDE_CJK_FONT');
final _evidence = <Map<String, Object?>>[];
final _entries = [
  SftpName(
    filename: 'projects',
    longname: '',
    attr: SftpFileAttrs(mode: SftpFileMode.value(0x4000)),
  ),
  SftpName(
    filename: 'deployment-notes.txt',
    longname: '',
    attr: SftpFileAttrs(size: 4096, modifyTime: 1700000000),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Pretendard', 'D2Coding', 'JetBrainsMono']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    if (_cjkFont.isNotEmpty) {
      await (FontLoader('AuditCjk')
            ..addFont(File(_cjkFont).readAsBytes().then(ByteData.sublistView)))
          .load();
    }
  });
  tearDownAll(() {
    if (_output.isNotEmpty) {
      Directory(_output).createSync(recursive: true);
      File('$_output/layout.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_evidence),
      );
    }
  });
  final profiles = [
    (
      'phone',
      const Size(360, 800),
      1.0,
      Brightness.light,
      TargetPlatform.android,
    ),
    (
      'large-text',
      const Size(390, 844),
      2.0,
      Brightness.dark,
      TargetPlatform.android,
    ),
    ('ipad', const Size(840, 1180), 1.0, Brightness.dark, TargetPlatform.iOS),
    (
      'desktop',
      const Size(1280, 900),
      1.0,
      Brightness.light,
      TargetPlatform.windows,
    ),
  ];
  for (final locale in [
    const Locale('ja'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale('pt', 'BR'),
    const Locale('es'),
  ]) {
    for (final profile in profiles) {
      testWidgets('${locale.toLanguageTag()} ${profile.$1} translated layouts', (
        tester,
      ) async {
        tester.view.physicalSize = profile.$2;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.localesTestValue = [locale];
        debugDefaultTargetPlatformOverride = profile.$5;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearLocalesTestValue();
          debugDefaultTargetPlatformOverride = null;
        });
        final engine = UiEngineFixture()
          ..state = {
            'ready': true,
            'hosts': [],
            'sessions': [],
            'preferences': {},
            'defaults': {
              'host': {'protocol': 'ssh', 'port': 22},
              'profile': {
                'name': 'Terminal',
                'encoding': 'UTF-8',
                'emulation': 'xterm-256color',
                'delKey': 'delete',
                'forceSizeColumns': 80,
                'forceSizeRows': 24,
              },
            },
          };
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              AndroidEngine.channel,
              (call) async => call.method == 'snapshot' ? engine.state : null,
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(AndroidEngine.channel, null),
        );
        final strings = await AppLocalizations.delegate.load(locale);
        final failures = <String>[];
        for (final screen in [
          'home',
          'host',
          'profile',
          'settings',
          'connection',
          'trust',
          'conflict',
          'delete',
          'files',
        ]) {
          final boundary = GlobalKey();
          var theme = tildeTheme(profile.$4, engine);
          if (_cjkFont.isNotEmpty) {
            theme = theme.copyWith(
              textTheme: theme.textTheme.apply(
                fontFamilyFallback: ['AuditCjk'],
              ),
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                  fontFamilyFallback: ['AuditCjk'],
                ),
              ),
              listTileTheme: theme.listTileTheme.copyWith(
                titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
                  fontFamilyFallback: ['AuditCjk'],
                ),
                subtitleTextStyle: theme.listTileTheme.subtitleTextStyle
                    ?.copyWith(fontFamilyFallback: ['AuditCjk']),
              ),
            );
          }
          Widget sheet(BuildContext context) => switch (screen) {
            'trust' => SingleChildScrollView(
              child: TerminalPrompt(
                prompt: const {
                  'type': 'hostKey',
                  'address': 'ssh://deploy@example.com:22',
                  'hostname': 'example.com',
                  'keyType': 'ssh-ed25519',
                  'sha256':
                      'SHA256:AbCdEfGh1234567890AbCdEfGh1234567890AbCdEfGh123',
                  'md5': '00:11:22:33:44:55',
                },
                onResponse: (_) async {},
              ),
            ),
            'conflict' => FileConflictPrompt(
              destination: '/home/deploy/deployment-notes.txt',
              sourceSize: 8192,
              sourceModified: 1700000000,
              existing: SftpFileAttrs(size: 4096, modifyTime: 1690000000),
              upload: true,
              currentFile: 1,
              totalFiles: 3,
            ),
            _ => FileDeletePrompt(
              entries: _entries,
              counts: Future.value({'projects': 3, 'deployment-notes.txt': 1}),
            ),
          };
          final modal = ['trust', 'conflict', 'delete'].contains(screen);
          final home = switch (screen) {
            'home' => ShellHome(engine: engine),
            'host' => RecordEditor(engine: engine, kind: RecordKind.host),
            'profile' => RecordEditor(engine: engine, kind: RecordKind.profile),
            'settings' || 'connection' => SettingsPage(engine: engine),
            'files' => Scaffold(
              appBar: AppBar(title: Text(strings.fileList)),
              body: FileBrowserListing(
                entries: _entries,
                path: '/home/deploy',
                loading: false,
                onOpen: (_) {},
                onDownload: (_) {},
                onNewFolder: () {},
                onRefresh: () {},
              ),
            ),
            _ => Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    key: const ValueKey('open-audit-sheet'),
                    onPressed: () => showTildeSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: sheet,
                    ),
                    child: const Text('Tilde'),
                  ),
                ),
              ),
            ),
          };
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$locale-${profile.$1}-$screen'),
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(profile.$3)),
                child: RepaintBoundary(key: boundary, child: child!),
              ),
              home: home,
            ),
          );
          await tester.pumpAndSettle();
          if (modal) {
            await tester.tap(find.byKey(const ValueKey('open-audit-sheet')));
            await tester.pumpAndSettle();
          }
          if (screen == 'connection') {
            await tester.ensureVisible(
              find.text(strings.connectionsAndNotifications).first,
            );
            await tester.pumpAndSettle();
            await tester.tap(
              find.text(strings.connectionsAndNotifications).first,
            );
            await tester.pumpAndSettle();
          }
          final errors = <String>[];
          Object? error;
          while ((error = tester.takeException()) != null) {
            errors.add(error.toString());
          }
          failures.addAll(errors.map((e) => '$screen: $e'));
          final clipped = <String>[];
          for (final element in find.byType(RichText).evaluate()) {
            final render = element.findRenderObject();
            if (render is RenderParagraph && render.didExceedMaxLines) {
              clipped.add(render.text.toPlainText());
              if (find
                  .ancestor(
                    of: find.byWidget(element.widget),
                    matching: find.byWidgetPredicate(
                      (w) => w is ButtonStyleButton,
                    ),
                  )
                  .evaluate()
                  .isNotEmpty) {
                failures.add(
                  '$screen button label clipped: ${render.text.toPlainText()}',
                );
              }
            }
          }
          final name = '${locale.toLanguageTag()}-${profile.$1}-$screen';
          Future<void> capture(String name) async {
            if (_output.isEmpty) return;
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              Directory(_output).createSync(recursive: true);
              File(
                '$_output/$name.png',
              ).writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture(name);
          final record = <String, Object?>{
            'locale': locale.toLanguageTag(),
            'profile': profile.$1,
            'screen': screen,
            'width': profile.$2.width,
            'height': profile.$2.height,
            'textScale': profile.$3,
            'image': '$name.png',
            'errors': errors,
            'ellipsized': clipped,
          };
          if (modal && find.byType(Scrollable).evaluate().isNotEmpty) {
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -1800),
            );
            await tester.pumpAndSettle();
            while ((error = tester.takeException()) != null) {
              failures.add('$screen scrolled: $error');
              errors.add(error.toString());
            }
            await capture('$name-bottom');
            record['bottomImage'] = '$name-bottom.png';
          }
          _evidence.add(record);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
        debugDefaultTargetPlatformOverride = null;
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  }
}
