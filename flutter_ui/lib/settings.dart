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

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'tilde_design.dart';
import 'tilde_controls.dart';
import 'main.dart';
import 'editors.dart';
import 'management.dart';
import 'settings_widgets.dart';

class SettingsPage extends StatefulWidget {
  final AndroidEngine engine;
  const SettingsPage({super.key, required this.engine});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AndroidEngine get engine => widget.engine;
  String? category;
  Future<void> update(BuildContext c, String key, dynamic value) =>
      runEngine(c, engine, 'settings.update', {'key': key, 'value': value});

  String buildingCategory = 'display';
  final searchTargets = <String, (String, String)>{};
  final rowKeys = <String, GlobalKey>{};
  String? highlighted;
  Timer? highlightTimer;
  @override
  void dispose() {
    highlightTimer?.cancel();
    super.dispose();
  }

  Widget tracked(String key, String label, Widget child) {
    searchTargets[key] = (buildingCategory, label);
    return AnimatedContainer(
      key: rowKeys.putIfAbsent(key, () => GlobalKey()),
      duration: const Duration(milliseconds: 240),
      color: highlighted == key
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: child,
    );
  }

  Widget toggle(
    BuildContext c,
    String key,
    String label, {
    String? sub,
    bool enabled = true,
    IconData? icon,
  }) => tracked(
    key,
    label,
    SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: icon == null ? null : Icon(icon, size: 24),
      title: Text(label),
      subtitle: sub == null ? null : Text(sub),
      value: engine.preferences[key] == true,
      onChanged: enabled ? (v) => update(c, key, v) : null,
    ),
  );
  Widget choice(
    BuildContext c,
    String key,
    String label,
    List<(Object?, String)> values, {
    VoidCallback? manage,
    bool forceList = false,
  }) {
    final current = engine.preferences[key] ?? values.firstOrNull?.$1;
    final options = [...values];
    if (current != null && !options.any((v) => v.$1 == current)) {
      options.add((current, '$current (현재 값)'));
    }
    return tracked(
      key,
      label,
      !forceList && options.length <= 4
          ? tildeSegments(c, label, options, current, (v) => update(c, key, v))
          : ListTile(
              title: Text(label),
              subtitle: Text(
                options.where((v) => v.$1 == current).firstOrNull?.$2 ?? '선택',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await pickTildeOption(
                  c,
                  label,
                  options,
                  current,
                );
                if (result != null && c.mounted) {
                  await update(c, key, result.$1);
                }
              },
            ),
    );
  }

  Widget radio(
    BuildContext c,
    String key,
    List<(Object?, String)> options, {
    required String label,
    Map<Object?, String> subtitles = const {},
  }) => tracked(
    key,
    label,
    tildeRadioOptions(
      c,
      options,
      engine.preferences[key] ?? options.first.$1,
      (v) => update(c, key, v),
      subtitles: subtitles,
    ),
  );
  Future<void> googleFonts(BuildContext c) async {
    final values = [
      for (final font in rows(engine.preferences['fonts']))
        if (font['value'] != 'SYSTEM_DEFAULT')
          (font['value'], '${font['label']}'),
    ];
    final result = await pickTildeOption(
      c,
      'Google Fonts · 고정폭',
      values,
      engine.preferences['fontFamily'],
    );
    if (result != null && c.mounted) {
      if (result.$1 == 'JETBRAINS_MONO') {
        await update(c, 'fontFamily', result.$1);
      } else {
        await runEngine(c, engine, 'font.custom', {'name': result.$2});
      }
    }
  }

  Future<void> searchSettings() async {
    searchTargets.clear();
    for (final id in [
      'display',
      'keyboard',
      'gesture',
      'terminal',
      'connection',
      'security',
      'fonts',
    ]) {
      fields(context, id);
    }
    final options = [
      for (final e in searchTargets.entries)
        (e.key, '${e.value.$2} · ${title(e.value.$1)}'),
    ];
    final result = await pickTildeOption(context, '설정 검색', options, null);
    if (result == null || !mounted) return;
    final key = result.$1 as String;
    setState(() {
      category = searchTargets[key]!.$1;
      highlighted = key;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = rowKeys[key]?.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 240),
          alignment: .25,
        );
      }
    });
    highlightTimer?.cancel();
    highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => highlighted = null);
    });
  }

  String title(String id) => switch (id) {
    'display' => '화면',
    'keyboard' => '키보드',
    'gesture' => '제스처',
    'terminal' => '터미널',
    'connection' => '연결·알림',
    'security' => '보안·백업',
    'fonts' => '폰트 관리',
    _ => '설정',
  };
  String summary(String id) {
    final p = engine.preferences;
    final profile = defaultProfile(engine);
    final scheme = engine
        .list('schemes')
        .where((s) => s['id'] == profile['colorSchemeId'])
        .firstOrNull;
    return switch (id) {
      'display' =>
        '${switch (p['themeMode']) {
          'LIGHT' => '밝게',
          'DARK' => '어둡게',
          _ => '시스템',
        }} · ${scheme?['name'] ?? 'Tilde Night'} · ${fontOptions(engine).where((f) => f.$1 == p['fontFamily']).firstOrNull?.$2 ?? '기본 폰트'}',
      'keyboard' =>
        '특수키 ${((p['terminalBarOrder'] as List? ?? []).where((k) => !(p['terminalBarHidden'] as List? ?? []).contains(k))).length}개 · ${p['terminalBarHeight'] ?? 28}dp',
      'gesture' =>
        '세로 ${p['pgupdngesture'] == true ? '페이지' : '스크롤'} · 가로 ${p['swipeSessions'] == true
            ? '세션'
            : p['swipeTmux'] == true
            ? 'tmux'
            : '사용 안 함'}',
      'terminal' =>
        '스크롤 ${formatCount('${p['scrollback'] ?? ''}')}줄 · ${profile['name'] ?? '기본 프로필'}',
      'connection' =>
        '연결 알림 ${p['connectionAlerts'] == true ? '켜짐' : '꺼짐'} · 벨 ${p['bell'] == true ? '켜짐' : '꺼짐'}',
      'security' => '실행 시 인증 ${p['authOnLaunch'] == true ? '켜짐' : '꺼짐'}',
      _ => '',
    };
  }

  Widget categories(String? selected) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          onPressed: searchSettings,
          icon: const Icon(Icons.search),
          label: const Text('설정 검색'),
        ),
      ),
      settingsSection(context, '앱', [
        for (final (id, icon) in [
          ('display', Icons.palette_outlined),
          ('keyboard', Icons.keyboard_outlined),
          ('gesture', Icons.swipe),
          ('terminal', Icons.terminal),
          ('connection', Icons.notifications_outlined),
          ('security', Icons.lock_outline),
        ])
          ListTile(
            selected: selected == id,
            leading: Icon(icon, size: 24),
            title: Text(title(id)),
            subtitle: Text(summary(id)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => category = id),
          ),
      ]),
      settingsSection(context, '정보', [
        ListTile(
          leading: const Icon(Icons.help_outline, size: 24),
          title: const Text('도움말 및 로그'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => HelpPage(engine: engine)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline, size: 24),
          title: const Text('Tilde'),
          subtitle: Text('${engine.state['appVersion'] ?? ''}'),
        ),
      ]),
    ],
  );

  Future<void> importFont(BuildContext c) async {
    await runEngine(c, engine, 'font.import');
  }

  Widget margin(BuildContext c) {
    final current =
        (engine.preferences['terminalMargin'] as num?)?.toInt() ?? 0;
    return tracked(
      'terminalMargin',
      '좌우 여백',
      Column(
        children: [
          TildeStepper(
            title: '좌우 여백',
            unit: 'dp',
            value: current,
            max: 100,
            onChanged: (v) => update(c, 'terminalMargin', v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final v in {0, 4, 8, 12, current})
                  FilterChip(
                    label: Text('$v'),
                    selected: current == v,
                    onSelected: (_) => update(c, 'terminalMargin', v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget scrollback(BuildContext c) => tracked(
    'scrollback',
    '스크롤 기록',
    TildeStepper(
      title: '스크롤 기록',
      unit: '행 · 500씩',
      value: int.tryParse('${engine.preferences['scrollback'] ?? 140}') ?? 140,
      step: 500,
      onChanged: (v) => update(c, 'scrollback', '$v'),
    ),
  );

  List<Widget> fields(BuildContext c, String id) {
    buildingCategory = id;
    final p = engine.preferences;
    final profile = defaultProfile(engine);
    final scheme = engine
        .list('schemes')
        .where((s) => s['id'] == profile['colorSchemeId'])
        .firstOrNull;
    Widget group(String title, List<Widget> rows) =>
        settingsSection(c, title, rows);
    Widget go(
      String key,
      String label,
      VoidCallback action, {
      String? sub,
      IconData? icon,
      bool enabled = true,
    }) => tracked(
      key,
      label,
      ListTile(
        leading: icon == null ? null : Icon(icon, size: 24),
        title: Text(label),
        subtitle: sub == null ? null : Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? action : null,
      ),
    );
    void page(Widget child) =>
        Navigator.push(c, MaterialPageRoute<void>(builder: (_) => child));
    switch (id) {
      case 'display':
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TerminalPreview(engine: engine),
          ),
          group('테마', [
            choice(c, 'themeMode', '앱 테마', [
              ('SYSTEM', '시스템'),
              ('LIGHT', '밝게'),
              ('DARK', '어둡게'),
            ]),
            go(
              'schemes',
              '색상 테마',
              () => page(SchemesPage(engine: engine)),
              sub: '${scheme?['name'] ?? 'Tilde Night'}',
            ),
          ]),
          group('글꼴', [
            choice(c, 'fontFamily', '기본 폰트', fontOptions(engine)),
            go(
              'fonts',
              '폰트 관리',
              () => setState(() => category = 'fonts'),
              sub:
                  '${rows(p['localFonts']).length + (p['customFonts'] as List? ?? []).length + 1}개',
            ),
          ]),
          group('화면 배치', [
            choice(c, 'rotation', '화면 방향', [
              ('Default', '기기 설정'),
              ('Force landscape', '가로'),
              ('Force portrait', '세로'),
              ('Automatic', '자동'),
            ]),
            toggle(c, 'fullscreen', '터미널 전체 화면', sub: '상태 표시줄을 숨깁니다'),
            toggle(c, 'titlebarhide', '터미널 제목 줄 숨기기'),
          ]),
        ];
      case 'keyboard':
        return [
          group('특수키', [
            toggle(c, 'alwaysvisible', '특수키 항상 표시'),
            go(
              'terminalBar',
              '특수키 구성',
              () => page(TerminalBarPage(engine: engine)),
              sub: '${(p['terminalBarOrder'] as List? ?? []).length}개',
            ),
            choice(c, 'stickymodifiers', 'Ctrl·Alt 고정 방식', [
              ('no', '한 번만'),
              ('yes', '고정'),
              ('alt', 'Alt만 고정'),
            ]),
          ]),
          group('단축키 입력 시 키보드', [
            radio(
              c,
              'imeShortcutInputMode',
              [
                ('FORCE_ASCII', '영문 키보드 요청'),
                ('TYPE_NULL', '직접 키 입력'),
                ('DISABLED', '현재 키보드 유지'),
              ],
              label: '단축키 입력 시 키보드',
              subtitles: {
                'FORCE_ASCII': '대부분 키보드에서 권장',
                'TYPE_NULL': '자동 완성·한글 조합 끔',
              },
            ),
            if (engine.state['koreanKeyboard'] == true)
              toggle(c, 'imeTogglekey', '입력 모드 전환 버튼'),
          ]),
          group(
            '하드웨어 키보드${engine.state['hardwareKeyboard'] == false ? ' · 연결 안 됨' : ''}',
            [
              toggle(c, 'shiftfkeys', 'Shift+숫자를 기능키로', sub: 'Shift+1 → F1'),
              toggle(c, 'ctrlfkeys', 'Ctrl+숫자를 기능키로'),
              choice(c, 'keymode', '보조 키 위치', [
                ('none', '사용 안 함'),
                ('Use left-side keys', '왼쪽'),
                ('Use right-side keys', '오른쪽'),
              ]),
              choice(c, 'camera', '카메라 버튼', [
                ('Ctrl+A then Space', 'Ctrl+A, Space'),
                ('Ctrl+A', 'Ctrl+A'),
                ('Esc', 'Esc'),
                ('Esc+A', 'Esc, A'),
              ], forceList: true),
            ],
          ),
        ];
      case 'gesture':
        return [
          group('터미널 위에서 스와이프', [
            toggle(
              c,
              'pgupdngesture',
              '세로 · 페이지 이동',
              sub: 'PgUp / PgDn 전송',
              icon: Icons.swap_vert,
            ),
            toggle(c, 'swipeSessions', '가로 · 세션 이동', icon: Icons.swap_horiz),
            toggle(
              c,
              'swipeTmux',
              '가로 · tmux 창 이동',
              sub: '세션 이동보다 먼저 적용',
              icon: Icons.view_column_outlined,
            ),
            if (p['swipeTmux'] == true)
              choice(c, 'tmuxCtrlA', 'tmux 접두키', [
                (false, 'Ctrl+B'),
                (true, 'Ctrl+A'),
              ]),
          ]),
          group('버튼 · 촉감', [
            toggle(
              c,
              'volumefont',
              '볼륨 버튼으로 글자 크기',
              icon: Icons.volume_up_outlined,
            ),
            toggle(c, 'bumpyarrows', '특수키 진동', icon: Icons.vibration),
          ]),
        ];
      case 'terminal':
        return [
          group('프로필', [
            choice(c, 'defaultProfileId', '기본 터미널 프로필', [
              for (final profile in engine.list('profiles'))
                (profile['id'], '${profile['name']}'),
            ], forceList: true),
            go(
              'profiles',
              '터미널 프로필 관리',
              () => page(
                RecordListPage(engine: engine, kind: RecordKind.profile),
              ),
              sub: '${engine.list('profiles').length}개',
            ),
          ]),
          group('표시', [scrollback(c), margin(c)]),
          group('터미널 종류 (TERM)', [
            ListTile(
              title: Text(
                '${profile['emulation'] ?? 'xterm-256color'}',
                style: const TextStyle(fontFamily: tildeMono),
              ),
              trailing: const Text('기본'),
            ),
            for (final type in (p['customTerminalTypes'] as List? ?? []))
              ListTile(
                title: Text(
                  '$type',
                  style: const TextStyle(fontFamily: tildeMono),
                ),
                trailing: IconButton(
                  tooltip: '터미널 종류 삭제',
                  icon: const Icon(Icons.close),
                  onPressed: () => runEngine(c, engine, 'terminalType.delete', {
                    'name': type,
                  }),
                ),
              ),
            go('terminalType', '터미널 종류 추가', () async {
              final name = await askText(c, '터미널 종류');
              if (name != null && c.mounted) {
                await runEngine(c, engine, 'terminalType.add', {'name': name});
              }
            }, icon: Icons.add),
          ]),
        ];
      case 'connection':
        return [
          group('연결', [
            toggle(
              c,
              'keepalive',
              '연결 중 화면 켜짐 유지',
              sub: '터미널 화면이 자동으로 꺼지지 않습니다',
            ),
            toggle(c, 'wifilock', 'Wi-Fi 절전 방지', sub: '배터리를 더 씁니다'),
            go(
              'backgroundNotification',
              '백그라운드 연결 알림',
              () => runEngine(c, engine, 'settings.notifications'),
              sub: '연결 중일 때 상단에 고정',
              icon: Icons.notifications_active_outlined,
            ),
          ]),
          group('터미널 벨', [
            tracked(
              'bellMode',
              '벨이 울리면',
              tildeSegments(
                c,
                '벨이 울리면',
                [
                  (0, '무시'),
                  (1, '소리'),
                  (2, '진동'),
                  if (p['bell'] == true && p['bellVibrate'] == true)
                    (3, '소리·진동'),
                ],
                p['bell'] == true
                    ? (p['bellVibrate'] == true ? 3 : 1)
                    : p['bellVibrate'] == true
                    ? 2
                    : 0,
                (v) => runEngine(c, engine, 'settings.bellMode', {'mode': v}),
              ),
            ),
            if (p['bell'] == true)
              tracked(
                'bellVolume',
                '음량',
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('음량'),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value:
                                  ((p['bellVolume'] as num?)?.toDouble() ?? .5)
                                      .clamp(0, 1),
                              onChanged: (v) => update(c, 'bellVolume', v),
                            ),
                          ),
                          Text(
                            '${(((p['bellVolume'] as num?)?.toDouble() ?? .5) * 100).round()}%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ]),
          group('알림', [
            if (p['notificationsAvailable'] == false)
              ListTile(
                leading: const Icon(Icons.info_outline, color: tildeSand),
                title: const Text('알림 권한이 필요합니다'),
                trailing: TextButton(
                  onPressed: () =>
                      runEngine(c, engine, 'settings.notifications'),
                  child: const Text('허용'),
                ),
              ),
            toggle(c, 'connectionAlerts', '연결 알림 사용', sub: '벨·연결 끊김 알림을 허용합니다'),
            toggle(
              c,
              'bellNotification',
              '백그라운드에서 벨',
              enabled: p['connectionAlerts'] == true,
            ),
            toggle(
              c,
              'connectionLostNotification',
              '연결이 끊기면',
              enabled: p['connectionAlerts'] == true,
            ),
            go(
              'notifications',
              'Android 알림 설정',
              () => runEngine(c, engine, 'settings.notifications'),
              sub: p['notificationsAvailable'] == false ? '알림 꺼짐' : '알림 허용됨',
              icon: Icons.open_in_new,
            ),
          ]),
        ];
      case 'security':
        return [
          group('잠금', [
            toggle(
              c,
              'authOnLaunch',
              '앱 실행 시 잠금 해제',
              enabled: p['canAuthenticate'] != false,
              sub: p['canAuthenticate'] == false
                  ? '화면 잠금을 먼저 설정하세요'
                  : '지문 또는 화면 잠금',
            ),
            toggle(c, 'memkeys', '해제한 SSH 키를 메모리에 유지', sub: '앱을 완전히 닫으면 지워집니다'),
          ]),
          group('키와 서버', [
            go(
              'keys',
              'SSH 키',
              () => page(KeyPage(engine: engine)),
              sub: '${engine.list('keys').length}개',
              icon: Icons.key_outlined,
            ),
            go(
              'identities',
              '공용 로그인 계정',
              () => page(
                RecordListPage(engine: engine, kind: RecordKind.identity),
              ),
              sub: '${engine.list('identities').length}개',
              icon: Icons.badge_outlined,
            ),
            go(
              'knownHosts',
              '신뢰한 서버 키',
              () => page(KnownHostsPage(engine: engine)),
              sub: '${engine.list('knownHosts').length}개',
              icon: Icons.verified_user_outlined,
            ),
          ]),
          group('백업', [
            toggle(
              c,
              'backupkeys',
              'SSH 키 백업 허용',
              sub: 'Android 백업에 암호화된 키 포함',
            ),
            go(
              'export',
              '호스트 내보내기',
              () => exportTildeHosts(c, engine),
              sub: 'tilde-hosts.json',
              icon: Icons.upload_outlined,
            ),
            go(
              'import',
              '호스트 가져오기',
              () => importTildeHosts(c, engine),
              icon: Icons.download_outlined,
            ),
          ]),
        ];
      case 'fonts':
        return [
          group('기본 폰트 선택', [
            for (final option in fontOptions(engine).where(
              (f) =>
                  f.$1 == 'JETBRAINS_MONO' ||
                  f.$1 == p['fontFamily'] ||
                  f.$1.toString().startsWith('local:') ||
                  f.$1.toString().startsWith('custom:'),
            ))
              ListTile(
                leading: Icon(
                  option.$1 == p['fontFamily']
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: option.$1 == p['fontFamily']
                      ? Theme.of(c).colorScheme.primary
                      : null,
                ),
                title: TerminalPreview(
                  engine: engine,
                  framed: false,
                  overrides: {
                    'fontFamily': option.$1,
                    'sampleText': '${option.$2} 가나다',
                    'compact': true,
                    'backgroundColor': 0,
                    'foregroundColor': Theme.of(
                      c,
                    ).colorScheme.onSurface.toARGB32(),
                    'profile': {...defaultProfile(engine), 'fontSize': 15},
                  },
                ),
                subtitle: Text(
                  option.$1 == 'JETBRAINS_MONO'
                      ? '앱에 포함'
                      : option.$1.toString().startsWith('local:')
                      ? option.$1.toString().substring(6)
                      : option.$1.toString().startsWith('custom:')
                      ? 'Google Fonts'
                      : '고정폭 폰트',
                ),
                onTap: () => update(c, 'fontFamily', option.$1),
                trailing: option.$1.toString().startsWith('local:')
                    ? IconButton(
                        tooltip: '폰트 삭제',
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          if (await confirm(
                                c,
                                '폰트 삭제',
                                '이 폰트 파일을 삭제할까요?',
                                action: '폰트 삭제',
                              ) &&
                              c.mounted) {
                            await runEngine(c, engine, 'font.delete', {
                              'fileName': option.$1.toString().substring(6),
                            });
                          }
                        },
                      )
                    : option.$1.toString().startsWith('custom:')
                    ? IconButton(
                        tooltip: '폰트 제거',
                        icon: const Icon(Icons.close),
                        onPressed: () => runEngine(
                          c,
                          engine,
                          'font.customDelete',
                          {'name': option.$2},
                        ),
                      )
                    : null,
              ),
            if (p['fontBusy'] == true)
              const Padding(
                padding: EdgeInsets.all(16),
                child: TildeProgress(label: '폰트 준비 중'),
              ),
            if (p['fontError'] != null) settingsNote(c, '${p['fontError']}'),
          ]),
          group('추가', [
            go(
              'fontImport',
              '폰트 파일 가져오기',
              () => importFont(c),
              enabled: p['fontBusy'] != true,
              sub: '.ttf · .otf · .ttc',
              icon: Icons.upload_file,
            ),
            go(
              'fontSearch',
              'Google Fonts에서 찾기',
              () => googleFonts(c),
              enabled: p['fontBusy'] != true,
              sub: '고정폭 폰트만 보여 줍니다',
              icon: Icons.travel_explore,
            ),
          ]),
        ];
      default:
        return [];
    }
  }

  void back(bool wide) {
    if (category == 'fonts') {
      setState(() => category = 'display');
    } else if (!wide && category != null) {
      setState(() => category = null);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final selected = category ?? (wide ? 'display' : null);
        final detail = ListView(
          key: ValueKey(selected),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (wide && selected != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title(selected),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ...fields(context, selected ?? 'display'),
          ],
        );
        return PopScope(
          canPop: category == null || wide && category != 'fonts',
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) back(wide);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(!wide && selected != null ? title(selected) : '설정'),
              leading: IconButton(
                tooltip: '뒤로',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => back(wide),
              ),
            ),
            body: wide
                ? Row(
                    children: [
                      SizedBox(width: 280, child: categories(selected)),
                      const VerticalDivider(width: 1),
                      Expanded(child: detail),
                    ],
                  )
                : selected == null
                ? categories(null)
                : detail,
          ),
        );
      },
    ),
  );
}

class TerminalBarPage extends StatefulWidget {
  final AndroidEngine engine;
  const TerminalBarPage({super.key, required this.engine});
  @override
  State<TerminalBarPage> createState() => _TerminalBarPageState();
}

class _TerminalBarPageState extends State<TerminalBarPage> {
  late List<String> order;
  late Set<String> hidden;
  late int height;
  late bool group;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.engine.preferences;
    order = (p['terminalBarOrder'] as List).cast<String>().toList();
    hidden = (p['terminalBarHidden'] as List).cast<String>().toSet();
    height = p['terminalBarHeight'] as int;
    group = p['terminalBarFn'] == true;
  }

  Future<void> save({
    List<String>? nextOrder,
    Set<String>? nextHidden,
    int? nextHeight,
    bool? nextGroup,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.engine.invoke('settings.update', {
        'key': 'terminalBar',
        'value': {
          'order': nextOrder ?? order,
          'hidden': (nextHidden ?? hidden).toList(),
          'height': nextHeight ?? height,
          'groupFunctionKeys': nextGroup ?? group,
        },
      });
      if (mounted) {
        setState(() {
          order = nextOrder ?? order;
          hidden = nextHidden ?? hidden;
          height = nextHeight ?? height;
          group = nextGroup ?? group;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('설정을 저장하지 못했습니다'),
            action: SnackBarAction(
              label: '자세히',
              onPressed: () => showErrorDetails(context, e),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.engine.preferences;
    final keys = rows(p['barKeys']);
    final defaults = row(p['terminalBarDefaults']);
    final heights = (p['terminalBarHeights'] as List? ?? []).cast<int>();
    return Scaffold(
      appBar: AppBar(title: const Text('특수키 바')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TerminalBarPreview(
              order: order,
              hidden: hidden,
              height: height,
              group: group,
              keys: keys,
            ),
          ),
          settingsNote(
            context,
            'Esc · ⇥ · Ctrl은 왼쪽, 키보드 버튼은 오른쪽에 고정돼요. Fn으로 묶으면 Fn도 오른쪽에 표시돼요.',
          ),
          settingsSection(context, '높이', [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<int>(
                key: ValueKey(MediaQuery.textScalerOf(context).scale(14) > 22),
                direction: MediaQuery.textScalerOf(context).scale(14) > 22
                    ? Axis.vertical
                    : Axis.horizontal,
                expandedInsets: MediaQuery.textScalerOf(context).scale(14) > 22
                    ? null
                    : EdgeInsets.zero,
                showSelectedIcon: false,
                segments: [
                  for (var i = 0; i < heights.length; i++)
                    ButtonSegment(
                      value: heights[i],
                      label: Text(
                        '${i == 0
                            ? '작게'
                            : i == heights.length - 1
                            ? '크게'
                            : '기본'} ${heights[i]}dp',
                      ),
                    ),
                ],
                selected: {height},
                onSelectionChanged: busy
                    ? null
                    : (s) => save(nextHeight: s.first),
              ),
            ),
          ]),
          settingsSection(context, '스크롤 영역 키', [
            settingsNote(context, '손잡이를 길게 눌러 순서를 바꿔요. 변경은 바로 적용돼요.'),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: order.length,
              onReorder: (oldIndex, newIndex) {
                if (busy) return;
                final updated = [...order];
                if (newIndex > oldIndex) newIndex--;
                updated.insert(newIndex, updated.removeAt(oldIndex));
                save(nextOrder: updated);
              },
              itemBuilder: (context, index) {
                final key = order[index];
                final label =
                    keys.where((k) => k['name'] == key).firstOrNull?['label'] ??
                    key;
                return ListTile(
                  key: ValueKey(key),
                  leading: ReorderableDelayedDragStartListener(
                    index: index,
                    enabled: !busy,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator),
                    ),
                  ),
                  title: Text('$label'),
                  trailing: Switch(
                    value: !hidden.contains(key),
                    onChanged: busy
                        ? null
                        : (value) {
                            final updated = {...hidden};
                            if (value) {
                              updated.remove(key);
                            } else {
                              updated.add(key);
                            }
                            save(nextHidden: updated);
                          },
                  ),
                );
              },
            ),
          ]),
          settingsSection(context, '옵션', [
            SwitchListTile(
              title: const Text('F1–F12를 Fn 키로 묶기'),
              subtitle: const Text('Fn을 누르면 스크롤 영역이 F키로 바뀌어요'),
              value: group,
              onChanged: busy ? null : (value) => save(nextGroup: value),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: busy || defaults.isEmpty
                  ? null
                  : () async {
                      if (await confirm(
                            context,
                            '특수키 바를 되돌릴까요?',
                            '높이와 키 순서·표시를 기본값으로 되돌려요.',
                            action: '되돌리기',
                          ) &&
                          mounted) {
                        save(
                          nextOrder: (defaults['order'] as List)
                              .cast<String>()
                              .toList(),
                          nextHidden: (defaults['hidden'] as List)
                              .cast<String>()
                              .toSet(),
                          nextHeight: defaults['height'] as int,
                          nextGroup: defaults['groupFunctionKeys'] as bool,
                        );
                      }
                    },
              child: const Text('기본값으로 되돌리기'),
            ),
          ),
        ],
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  final AndroidEngine engine;
  const HelpPage({super.key, required this.engine});
  Future<void> document(
    BuildContext context,
    String section,
    String title,
  ) async {
    final value = await runEngine(context, engine, 'help.document', {
      'section': section,
    });
    if (value == null || !context.mounted) return;
    var text = '$value';
    if (section == 'license') {
      text +=
          '\n\n${await rootBundle.loadString('assets/fonts/Pretendard-LICENSE.txt')}\n\n${await rootBundle.loadString('assets/fonts/JetBrainsMono-OFL.txt')}';
    }
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(text),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('도움말')),
    body: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TildeWordmark(size: 40),
              const SizedBox(height: 16),
              Text('${engine.state['appVersion'] ?? ''}'),
              const Text('ConnectBot 엔진 기반 SSH · Terminal'),
            ],
          ),
        ),
        settingsSection(context, '도움말', [
          for (final (section, title, icon) in [
            ('hints', '사용 팁', Icons.lightbulb_outline),
            ('license', '라이선스 및 이용 조건', Icons.description_outlined),
            ('contact', '프로젝트 및 문의', Icons.mail_outline),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => document(context, section, title),
            ),
        ]),
        settingsSection(context, '진단', [
          ListTile(
            leading: const Icon(Icons.subject),
            title: const Text('진단 로그'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => LogsPage(engine: engine)),
            ),
          ),
        ]),
      ],
    ),
  );
}

class LogsPage extends StatefulWidget {
  final AndroidEngine engine;
  const LogsPage({super.key, required this.engine});
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  String logs = '', search = '';
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.engine.query('logs');
      if (mounted) setState(() => logs = '$result');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('진단 로그'),
      actions: [
        IconButton(
          tooltip: '새로고침',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: '로그 공유',
          onPressed: logs.isEmpty
              ? null
              : () =>
                    runEngine(context, widget.engine, 'share', {'text': logs}),
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '로그 검색',
            ),
            onChanged: (value) => setState(() => search = value),
          ),
        ),
        if (busy) const TildeProgress(),
        if (error != null)
          ListTile(
            title: const Text('로그를 불러오지 못했습니다'),
            trailing: TextButton(
              onPressed: () => showErrorDetails(context, error!),
              child: const Text('자세히'),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: SelectableText(
                logs
                    .split('\n')
                    .where(
                      (line) =>
                          line.toLowerCase().contains(search.toLowerCase()),
                    )
                    .join('\n'),
                style: const TextStyle(fontFamily: tildeMono, fontSize: 12),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: TextButton.icon(
            onPressed: () =>
                runEngine(context, widget.engine, 'logs.tombstone'),
            icon: const Icon(Icons.save_alt),
            label: const Text('네이티브 크래시 기록 저장'),
          ),
        ),
      ],
    ),
  );
}
