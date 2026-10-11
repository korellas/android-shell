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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_shell_ui/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.korellas.androidshell/engine');
  var imported = false;
  String? importError;
  setUp(() {
    imported = false;
    importError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel("dev.korellas.androidshell/events"),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'snapshot') {
            return {
              'ready': true,
              'hosts': [
                if (imported)
                  {
                    'id': 8,
                    'nickname': 'Imported host',
                    'hostname': 'imported.test',
                    'username': 'probe',
                    'protocol': 'ssh',
                    'port': 22,
                  },
                {
                  'id': 7,
                  'nickname': 'Research',
                  'hostname': 'example.test',
                  'username': 'alice',
                  'protocol': 'ssh',
                  'port': 22,
                },
              ],
              'sessions': [],
              'identities': [],
              'profiles': [],
              'keys': [],
              'schemes': [],
              'knownHosts': [],
              'themeColors': {
                'light': {'primary': 0xff123456, 'surface': 0xfffafafa},
              },
              'preferences': {},
            };
          }
          if (call.method == 'document.pick') {
            return 'content://test/hosts.json';
          }
          if (call.method == 'document.read') return '{"version":1,"hosts":[]}';
          if (call.method == 'config.import') {
            if (importError != null) {
              throw PlatformException(
                code: 'engine_error',
                message: importError,
              );
            }
            imported = true;
            return {
              'message': '호스트 가져오기 완료',
              'hostsImported': 1,
              'hostsSkipped': 0,
              'profilesImported': 0,
              'profilesSkipped': 0,
            };
          }
          if (call.method == 'connect') {
            throw PlatformException(
              code: 'connection_failed',
              message: 'Connection refused',
            );
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets('home menus keep profile management in settings', (tester) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    expect(find.text('터미널 프로필'), findsNothing);
    expect(find.text('가져오기·내보내기'), findsOneWidget);
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('터미널').first);
    await tester.pumpAndSettle();
    expect(find.text('터미널 프로필'), findsOneWidget);
    await tester.tap(find.text('터미널 프로필'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
  testWidgets('host menus keep secondary actions reachable without clutter', (
    tester,
  ) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Research 옵션'));
    await tester.pumpAndSettle();
    expect(find.text('홈 화면에 추가'), findsNothing);
    expect(find.text('연결 끊기'), findsNothing);
    await tester.tap(find.text('추가 기능'));
    await tester.pumpAndSettle();
    expect(find.text('홈 화면에 추가'), findsOneWidget);
    expect(find.text('저장된 서버 키 삭제'), findsOneWidget);
    await tester.tap(find.text('복제'));
    await tester.pumpAndSettle();
    expect(find.text('복제할 호스트 이름'), findsOneWidget);
  });
  testWidgets('keyboard settings hide hardware mappings until requested', (
    tester,
  ) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('키보드').first);
    await tester.pumpAndSettle();
    expect(find.text('카메라 버튼 동작'), findsNothing);
    await tester.ensureVisible(find.text('하드웨어 키보드'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('하드웨어 키보드'));
    await tester.pumpAndSettle();
    expect(find.text('카메라 버튼 동작'), findsOneWidget);
  });
  testWidgets('saved native hosts are available in Flutter', (tester) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    expect(find.text('Research'), findsOneWidget);
    expect(find.text('ssh · example.test'), findsOneWidget);
  });
  testWidgets(
    'home keeps saved connections central without a management drawer',
    (tester) async {
      await tester.pumpWidget(const AndroidShellApp());
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(SearchBar), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.text('Android Shell'), findsOneWidget);
      expect(find.byTooltip('호스트 추가'), findsOneWidget);
      await tester.tap(find.byTooltip('메뉴'));
      await tester.pumpAndSettle();
      expect(find.text('로그인·SSH 키'), findsOneWidget);
      expect(find.text('신뢰한 서버 키'), findsNothing);
      expect(find.text('색상 테마'), findsNothing);
      await tester.tap(find.text('로그인·SSH 키'));
      await tester.pumpAndSettle();
      expect(find.text('지문 로그인 설정'), findsOneWidget);
      expect(find.text('SSH 키 관리'), findsOneWidget);
      expect(find.text('공용 로그인 계정'), findsOneWidget);
    },
  );
  testWidgets('automation and server trust stay inside the host editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Research 옵션'));
    await tester.pumpAndSettle();
    expect(find.text('접속 자동화'), findsNothing);
    expect(find.text('즐겨찾기 추가'), findsOneWidget);
    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('세션').first);
    await tester.pumpAndSettle();
    expect(find.text('로그인 후 자동 실행'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('인증').first);
    await tester.pumpAndSettle();
    expect(find.text('신뢰한 서버 키'), findsOneWidget);
  });
  testWidgets('settings use the native category hierarchy', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.text('화면'), findsOneWidget);
    expect(find.text('키보드'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.text('키보드'));
    await tester.pumpAndSettle();
    expect(find.text('특수키 항상 표시'), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로').first);
    await tester.pumpAndSettle();
    expect(find.text('화면'), findsOneWidget);
  });
  testWidgets('host edits survive category changes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Research 옵션'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('편집'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('연결'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nickname')), 'Renamed');
    await tester.tap(find.byTooltip('뒤로').first);
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
    await tester.tap(find.text('연결'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
    expect(find.byTooltip('저장'), findsOneWidget);
  });
  testWidgets(
    'wide host editing keeps categories beside the connection fields',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const AndroidShellApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Research 옵션'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('편집'));
      await tester.pumpAndSettle();
      expect(find.text('인증'), findsOneWidget);
      expect(find.text('세션'), findsOneWidget);
      expect(find.byKey(const ValueKey('hostname')), findsOneWidget);
      await tester.tap(find.text('화면·프로필'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hostname')), findsNothing);
      expect(find.text('터미널 프로필 관리'), findsOneWidget);
    },
  );
  testWidgets('file import refreshes connections and reports completion', (
    tester,
  ) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가져오기·내보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('호스트 가져오기'));
    await tester.pumpAndSettle();
    expect(find.text('Imported host'), findsOneWidget);
    expect(find.text('호스트 가져오기 완료'), findsOneWidget);
  });
  testWidgets('file import failure is visible and does not add a connection', (
    tester,
  ) async {
    importError = 'Invalid JSON';
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가져오기·내보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('호스트 가져오기'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid JSON'), findsOneWidget);
    expect(find.text('Imported host'), findsNothing);
  });
  testWidgets('Flutter uses the native theme colors', (tester) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Research'));
    expect(Theme.of(context).colorScheme.primary, const Color(0xff123456));
    expect(Theme.of(context).colorScheme.surface, const Color(0xfffafafa));
  });
  testWidgets('connection failure remains visible without opening a console', (
    tester,
  ) async {
    await tester.pumpWidget(const AndroidShellApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.byType(AndroidView), findsNothing);
  });
}
