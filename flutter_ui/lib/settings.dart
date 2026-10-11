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
import 'package:flutter/material.dart';
import 'engine.dart';
import 'main.dart';
import 'editors.dart';
import 'management.dart';

class SettingsPage extends StatefulWidget {
  final AndroidEngine engine;
  const SettingsPage({super.key, required this.engine});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AndroidEngine get engine => widget.engine;
  String? category;
  Future<void> update(BuildContext context, String key, dynamic value) =>
      runEngine(context, engine, 'settings.update', {
        'key': key,
        'value': value,
      });
  Widget toggle(
    BuildContext context,
    String key,
    String label, {
    bool enabled = true,
  }) => SwitchListTile(
    title: Text(label),
    value: engine.preferences[key] == true,
    onChanged: enabled ? (value) => update(context, key, value) : null,
  );
  Widget choice(
    BuildContext context,
    String key,
    String label,
    List<(Object?, String)> values,
  ) {
    final current = engine.preferences[key];
    final options = [...values];
    if (current != null && !options.any((o) => o.$1 == current)) {
      options.add((current, '$current'));
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<Object>(
        key: ValueKey('$key:$current'),
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final option in options)
            DropdownMenuItem(
              value: option.$1,
              child: Text(option.$2, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) => update(context, key, value),
      ),
    );
  }

  String title(String category) => switch (category) {
    'display' => '화면',
    'keyboard' => '키보드',
    'gesture' => '제스처',
    'terminal' => '터미널',
    'connection' => '연결·알림',
    'security' => '보안·백업',
    'fonts' => '폰트 관리',
    _ => '설정',
  };
  Widget categories(String? selected) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    children: [
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
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title(id)),
          onTap: () => setState(() => category = id),
        ),
    ],
  );
  List<Widget> fields(BuildContext context, String category) {
    final p = engine.preferences;
    return switch (category) {
      'security' => [
        toggle(
          context,
          'authOnLaunch',
          '앱 실행 시 잠금 해제',
          enabled: p['canAuthenticate'] == true,
        ),
        toggle(context, 'memkeys', '해제한 SSH 키를 메모리에 유지'),
        toggle(context, 'backupkeys', 'SSH 키 백업 허용'),
      ],
      'connection' => [
        toggle(context, 'keepalive', '네트워크 연결 유지'),
        toggle(context, 'wifilock', 'Wi-Fi 절전 방지'),
        toggle(context, 'connectionAlerts', '백그라운드 연결 알림'),
        ListTile(
          title: const Text('Android 알림 설정'),
          subtitle: Text(
            p['notificationsAvailable'] == true
                ? '알림 허용됨'
                : 'Android에서 알림 허용이 필요합니다.',
          ),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => runEngine(context, engine, 'settings.notifications'),
        ),
        const Divider(),
        toggle(context, 'bell', '터미널 벨 소리'),
        toggle(context, 'bellVibrate', '터미널 벨 진동'),
        toggle(context, 'bellNotification', '터미널 벨 알림'),
        toggle(context, 'connectionLostNotification', '연결 종료 알림'),
        if (p['bell'] == true)
          ListTile(
            title: const Text('벨 음량'),
            subtitle: Slider(
              value: ((p['bellVolume'] as num?)?.toDouble() ?? 0.5).clamp(0, 1),
              onChanged: (value) => update(context, 'bellVolume', value),
            ),
          ),
      ],
      'display' => [
        choice(context, 'themeMode', '앱 테마', [
          ('SYSTEM', '시스템 설정'),
          ('LIGHT', '밝게'),
          ('DARK', '어둡게'),
        ]),
        choice(context, 'rotation', '화면 방향', [
          ('Default', '기기 설정'),
          ('Force landscape', '가로'),
          ('Force portrait', '세로'),
          ('Automatic', '자동 회전'),
        ]),
        toggle(context, 'fullscreen', '터미널 전체 화면'),
        toggle(context, 'titlebarhide', '터미널 제목 줄 숨기기'),
        choice(context, 'fontFamily', '기본 폰트', fontOptions(engine)),
        ListTile(
          title: const Text('폰트 관리'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => this.category = 'fonts'),
        ),
        ListTile(
          title: const Text('색상 테마'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SchemesPage(engine: engine),
            ),
          ),
        ),
      ],
      'keyboard' => [
        toggle(context, 'alwaysvisible', '특수키 항상 표시'),
        toggle(context, 'imeTogglekey', '입력 모드 전환 버튼'),
        choice(context, 'imeShortcutInputMode', '단축키 입력 시 키보드 모드', [
          ('FORCE_ASCII', '영문 키보드 요청'),
          ('TYPE_NULL', '직접 키 입력'),
          ('DISABLED', '현재 키보드 유지'),
        ]),
        choice(context, 'stickymodifiers', 'Ctrl 및 Alt 고정 방식', [
          ('no', '한 번만 적용'),
          ('yes', '고정'),
          ('alt', 'Alt만 고정'),
        ]),
        ExpansionTile(
          title: const Text('하드웨어 키보드'),
          children: [
            toggle(context, 'shiftfkeys', 'Shift+숫자를 기능키로 사용'),
            toggle(context, 'ctrlfkeys', 'Ctrl+숫자를 기능키로 사용'),
            choice(context, 'keymode', '보조 키 위치', [
              ('none', '사용 안 함'),
              ('Use right-side keys', '오른쪽'),
              ('Use left-side keys', '왼쪽'),
            ]),
            choice(context, 'camera', '카메라 버튼 동작', [
              ('Ctrl+A then Space', 'Ctrl+A, Space'),
              ('Ctrl+A', 'Ctrl+A'),
              ('Esc', 'Escape'),
              ('Esc+A', 'Escape, A'),
            ]),
          ],
        ),
        ListTile(
          title: const Text('특수키 구성 및 순서'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => TerminalBarPage(engine: engine),
            ),
          ),
        ),
      ],
      'gesture' => [
        toggle(context, 'volumefont', '볼륨 버튼으로 글자 크기 조절'),
        toggle(context, 'pgupdngesture', '세로 제스처로 페이지 이동'),
        toggle(context, 'swipeSessions', '가로 제스처로 세션 이동'),
        toggle(context, 'swipeTmux', '가로 제스처로 tmux 창 이동'),
        if (p['swipeTmux'] == true)
          toggle(context, 'tmuxCtrlA', 'tmux 접두키로 Ctrl+A 사용'),
        toggle(context, 'bumpyarrows', '특수키 진동'),
      ],
      'terminal' => [
        ListTile(
          title: const Text('터미널 프로필'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  RecordListPage(engine: engine, kind: RecordKind.profile),
            ),
          ),
        ),
        choice(context, 'defaultProfileId', '기본 터미널 프로필', [
          for (final profile in engine.list('profiles'))
            (profile['id'] as int, '${profile['name']}'),
        ]),
        ListTile(
          title: const Text('스크롤 기록 행 수'),
          subtitle: Text('${p['scrollback'] ?? ''}'),
          onTap: () async {
            final value = await askText(
              context,
              '스크롤 기록 행 수',
              initial: '${p['scrollback'] ?? ''}',
            );
            if (value != null && context.mounted) {
              await update(context, 'scrollback', value);
            }
          },
        ),
        ListTile(
          title: const Text('터미널 좌우 여백'),
          subtitle: Text('${p['terminalMargin'] ?? 0}'),
          onTap: () async {
            final value = await askText(
              context,
              '터미널 좌우 여백',
              initial: '${p['terminalMargin'] ?? 0}',
            );
            if (value != null &&
                int.tryParse(value) != null &&
                context.mounted) {
              await update(context, 'terminalMargin', int.parse(value));
            }
          },
        ),
        ExpansionTile(
          title: const Text('고급 터미널 설정'),
          children: [
            ListTile(
              title: const Text('터미널 종류 추가'),
              leading: const Icon(Icons.add),
              onTap: () async {
                final name = await askText(context, '터미널 종류');
                if (name != null && context.mounted) {
                  await runEngine(context, engine, 'terminalType.add', {
                    'name': name,
                  });
                }
              },
            ),
            for (final type in (p['customTerminalTypes'] as List? ?? []))
              ListTile(
                title: Text('$type'),
                trailing: IconButton(
                  tooltip: '제거',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => runEngine(
                    context,
                    engine,
                    'terminalType.delete',
                    {'name': type},
                  ),
                ),
              ),
          ],
        ),
      ],
      'fonts' => [
        if (p['fontBusy'] == true) const LinearProgressIndicator(),
        if (p['fontError'] != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${p['fontError']}'),
          ),
        ListTile(
          title: const Text('폰트 파일 가져오기'),
          leading: const Icon(Icons.file_open),
          onTap: () async {
            final name = await askText(
              context,
              '폰트 파일 이름',
              initial: 'Imported font.ttf',
            );
            if (name != null && context.mounted) {
              await runEngine(context, engine, 'font.import', {'name': name});
            }
          },
        ),
        for (final font in rows(p['localFonts']))
          ListTile(
            title: Text('${font['displayName']}'),
            subtitle: Text('${font['fileName']}'),
            trailing: IconButton(
              tooltip: '폰트 삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, '폰트 삭제', '이 폰트 파일을 삭제할까요?') &&
                    context.mounted) {
                  await runEngine(context, engine, 'font.delete', {
                    'fileName': font['fileName'],
                  });
                }
              },
            ),
          ),
        ListTile(
          title: const Text('Google Fonts 폰트 추가'),
          leading: const Icon(Icons.add),
          onTap: () async {
            final name = await askText(context, 'Google Fonts 폰트 이름');
            if (name != null && context.mounted) {
              await runEngine(context, engine, 'font.custom', {'name': name});
            }
          },
        ),
        for (final font in (p['customFonts'] as List? ?? []))
          ListTile(
            title: Text('$font'),
            trailing: IconButton(
              tooltip: '폰트 제거',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => runEngine(context, engine, 'font.customDelete', {
                'name': font,
              }),
            ),
          ),
      ],
      _ => [],
    };
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
        final wide = constraints.maxWidth >= 600;
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
  @override
  void initState() {
    super.initState();
    final p = widget.engine.preferences;
    order = (p['terminalBarOrder'] as List).cast<String>().toList();
    hidden = (p['terminalBarHidden'] as List).cast<String>().toSet();
    height = p['terminalBarHeight'] as int;
    group = p['terminalBarFn'] == true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('특수키 구성'),
      actions: [
        TextButton(
          onPressed: () async {
            await runEngine(context, widget.engine, 'settings.update', {
              'key': 'terminalBar',
              'value': {
                'order': order,
                'hidden': hidden.toList(),
                'height': height,
                'groupFunctionKeys': group,
              },
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    ),
    body: Column(
      children: [
        DropdownButtonFormField<int>(
          initialValue: height,
          decoration: const InputDecoration(labelText: '키 높이'),
          items: const [
            DropdownMenuItem(value: 26, child: Text('작게')),
            DropdownMenuItem(value: 28, child: Text('보통')),
            DropdownMenuItem(value: 36, child: Text('크게')),
          ],
          onChanged: (value) => setState(() => height = value!),
        ),
        SwitchListTile(
          title: const Text('기능키 묶어서 표시'),
          value: group,
          onChanged: (value) => setState(() => group = value),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: order.length,
            onReorder: (oldIndex, newIndex) => setState(() {
              if (newIndex > oldIndex) newIndex--;
              order.insert(newIndex, order.removeAt(oldIndex));
            }),
            itemBuilder: (context, index) {
              final key = order[index];
              final label =
                  rows(
                    widget.engine.preferences['barKeys'],
                  ).where((k) => k['name'] == key).firstOrNull?['label'] ??
                  key;
              return SwitchListTile(
                key: ValueKey(key),
                title: Text('$label'),
                value: !hidden.contains(key),
                onChanged: (value) => setState(() {
                  if (value) {
                    hidden.remove(key);
                  } else {
                    hidden.add(key);
                  }
                }),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class HelpPage extends StatefulWidget {
  final AndroidEngine engine;
  const HelpPage({super.key, required this.engine});
  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  String logs = '';
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('도움말 및 로그')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('AndroidShell', style: TextStyle(fontSize: 28)),
        const SizedBox(height: 12),
        const Text(
          '호스트를 추가해 SSH, Mosh, Telnet 또는 로컬 터미널에 연결하세요. 터미널을 눌러 키보드를 열 수 있습니다. 특수키의 Ctrl과 Alt는 다음 입력에 적용됩니다. 터미널 메뉴에서 선택, 복사, 붙여넣기, 입력 작성 모드를 사용할 수 있습니다.',
        ),
        const SizedBox(height: 16),
        for (final (section, title) in [
          ('hints', '사용 팁'),
          ('license', '라이선스 및 이용 조건'),
          ('contact', '프로젝트 및 문의'),
        ])
          ListTile(
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final text = await runEngine(
                context,
                widget.engine,
                'help.document',
                {'section': section},
              );
              if (text != null && context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(title)),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText('$text'),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ExpansionTile(
          title: const Text('진단 로그'),
          children: [
            FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final text = await runEngine(
                        context,
                        widget.engine,
                        'logs',
                      );
                      if (mounted) {
                        setState(() {
                          logs = text as String? ?? '';
                          busy = false;
                        });
                      }
                    },
              child: const Text('진단 로그 불러오기'),
            ),
            if (logs.isNotEmpty) ...[
              SelectableText(logs),
              TextButton(
                onPressed: () =>
                    runEngine(context, widget.engine, 'share', {'text': logs}),
                child: const Text('로그 공유'),
              ),
            ],
            TextButton(
              onPressed: () =>
                  runEngine(context, widget.engine, 'logs.tombstone'),
              child: const Text('네이티브 크래시 기록 저장'),
            ),
          ],
        ),
      ],
    ),
  );
}
