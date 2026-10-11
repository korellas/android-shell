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

  Widget toggle(
    BuildContext c,
    String key,
    String label, {
    String? sub,
    bool enabled = true,
  }) => SwitchListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    title: Text(label),
    subtitle: sub == null ? null : Text(sub),
    value: engine.preferences[key] == true,
    onChanged: enabled ? (value) => update(c, key, value) : null,
  );

  Widget choice(
    BuildContext c,
    String key,
    String label,
    List<(Object?, String)> values, {
    VoidCallback? manage,
  }) {
    final current = engine.preferences[key];
    final options = [...values];
    if (current != null && !options.any((o) => o.$1 == current)) {
      options.add((current, '$current'));
    }
    return ListTile(
      title: Text(label),
      subtitle: Text(
        options.where((v) => v.$1 == current).firstOrNull?.$2 ?? '설정되지 않음',
      ),
      trailing: const Icon(Icons.expand_more),
      onTap: () async {
        final result = await showModalBottomSheet<(Object?, String)>(
          context: c,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheet) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheet).height * .75,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      label,
                      style: Theme.of(sheet).textTheme.titleLarge,
                    ),
                  ),
                  for (final option in options)
                    ListTile(
                      title: Text(option.$2),
                      trailing: option.$1 == current
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(sheet, option),
                    ),
                  if (manage != null) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.font_download_outlined),
                      title: const Text('가져온 글꼴 관리'),
                      onTap: () {
                        Navigator.pop(sheet);
                        manage();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
        if (result != null && c.mounted) await update(c, key, result.$1);
      },
    );
  }

  String title(String id) => switch (id) {
    'display' => '화면',
    'keyboard' => '키보드',
    'gesture' => '제스처',
    'terminal' => '터미널',
    'connection' => '연결·알림',
    'security' => '보안·백업',
    'fonts' => '글꼴 관리',
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
          'LIGHT' => '라이트',
          'DARK' => '다크',
          _ => '시스템',
        }} · ${scheme?['name'] ?? '기본 색상'} · 여백 ${p['terminalMargin'] ?? 0}dp',
      'keyboard' =>
        '특수키 ${((p['terminalBarOrder'] as List? ?? []).where((k) => !(p['terminalBarHidden'] as List? ?? []).contains(k))).length}개 · ${p['terminalBarHeight'] ?? 28}dp',
      'gesture' =>
        '${['pgupdngesture', 'swipeSessions', 'swipeTmux'].where((k) => p[k] == true).length}개 켜짐',
      'terminal' =>
        '스크롤 ${formatCount('${p['scrollback'] ?? ''}')}줄 · ${profile['name'] ?? '기본 프로필'}',
      'connection' =>
        '연결 알림 ${p['connectionAlerts'] == true ? '켜짐' : '꺼짐'} · 벨 ${p['bell'] == true ? '켜짐' : '꺼짐'}',
      'security' => '실행 시 인증 ${p['authOnLaunch'] == true ? '켜짐' : '꺼짐'}',
      _ => '',
    };
  }

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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: ListTile(
            selected: selected == id,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            minTileHeight: 64,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(icon, size: 22),
            ),
            title: Text(title(id)),
            subtitle: Text(
              summary(id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => setState(() => category = id),
          ),
        ),
    ],
  );

  Future<void> importFont(BuildContext c) async {
    await runEngine(c, engine, 'font.import');
  }

  Widget margin(BuildContext c) {
    final current =
        (engine.preferences['terminalMargin'] as num?)?.toInt() ?? 0;
    final values = {0, 2, 4, 8, 12, 16, 24, current}.toList()..sort();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final value in values)
            FilterChip(
              label: Text('${value}dp'),
              selected: current == value,
              onSelected: (_) => update(c, 'terminalMargin', value),
            ),
        ],
      ),
    );
  }

  Widget scrollback(BuildContext c) {
    final saved = '${engine.preferences['scrollback'] ?? ''}';
    final current = int.tryParse(saved);
    const steps = [0, 140, 500, 1000, 2000, 5000, 10000, 20000, 100000];
    final lower = current == null
        ? null
        : steps.where((s) => s < current).lastOrNull;
    final upper = current == null
        ? null
        : steps.where((s) => s > current).firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('스크롤 버퍼', style: TextStyle(fontSize: 16)),
          Text(
            '세션마다 기억할 줄 수',
            style: Theme.of(c).textTheme.bodyMedium?.copyWith(
              color: Theme.of(c).colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton.outlined(
                tooltip: '스크롤 버퍼 줄이기',
                icon: const Icon(Icons.remove),
                onPressed: lower == null
                    ? null
                    : () => update(c, 'scrollback', '$lower'),
              ),
              Flexible(
                child: TextButton(
                  onPressed: () async {
                    final value = await askText(
                      c,
                      '스크롤 버퍼',
                      initial: saved,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final n = int.tryParse(value ?? '');
                        return n != null && n >= 0 && n <= 100000
                            ? null
                            : '0부터 100,000 사이의 줄 수를 입력해 주세요.';
                      },
                    );
                    if (value != null && c.mounted) {
                      await update(c, 'scrollback', value);
                    }
                  },
                  child: Text('${formatCount(saved)}줄'),
                ),
              ),
              IconButton.outlined(
                tooltip: '스크롤 버퍼 늘리기',
                icon: const Icon(Icons.add),
                onPressed: upper == null
                    ? null
                    : () => update(c, 'scrollback', '$upper'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> fields(BuildContext c, String id) {
    final p = engine.preferences;
    final cs = Theme.of(c).colorScheme;
    final selectedScheme = engine
        .list('schemes')
        .where((s) => s['id'] == defaultProfile(engine)['colorSchemeId'])
        .firstOrNull;
    return switch (id) {
      'display' => [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TerminalPreview(engine: engine),
        ),
        settingsSection(c, '모양', [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('앱 테마'),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (c, constraints) {
                    final segments = [
                      for (final (value, label) in [
                        ('SYSTEM', '시스템'),
                        ('LIGHT', '라이트'),
                        ('DARK', '다크'),
                      ])
                        ButtonSegment(value: value, label: Text(label)),
                    ];
                    return SegmentedButton<String>(
                      key: ValueKey(
                        MediaQuery.textScalerOf(context).scale(14) > 22,
                      ),
                      segments: segments,
                      direction: MediaQuery.textScalerOf(c).scale(14) > 22
                          ? Axis.vertical
                          : Axis.horizontal,
                      showSelectedIcon: false,
                      expandedInsets:
                          MediaQuery.textScalerOf(context).scale(14) > 22
                          ? null
                          : EdgeInsets.zero,
                      selected: {p['themeMode'] as String? ?? 'SYSTEM'},
                      onSelectionChanged: (s) =>
                          update(c, 'themeMode', s.first),
                    );
                  },
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('색상 테마'),
            subtitle: Text('${selectedScheme?['name'] ?? '기본 색상'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute<void>(
                builder: (_) => SchemesPage(engine: engine),
              ),
            ),
          ),
          choice(
            c,
            'fontFamily',
            '글꼴',
            fontOptions(engine),
            manage: () => setState(() => category = 'fonts'),
          ),
          ListTile(
            title: const Text('글꼴 파일 가져오기'),
            subtitle: const Text('기기에 있는 TTF·OTF·TTC 파일'),
            trailing: const Icon(Icons.upload_file),
            onTap: p['fontBusy'] == true ? null : () => importFont(c),
          ),
          if (p['fontBusy'] == true) const LinearProgressIndicator(),
          if (p['fontError'] != null) settingsNote(c, '${p['fontError']}'),
        ]),
        settingsSection(c, '터미널 여백', [margin(c)]),
        settingsSection(c, '콘솔 화면', [
          choice(c, 'rotation', '화면 방향', [
            ('Default', '기기 설정 따름'),
            ('Force landscape', '가로'),
            ('Force portrait', '세로'),
            ('Automatic', '자동 회전'),
          ]),
          toggle(c, 'fullscreen', '전체 화면', sub: '콘솔에서 상태 표시줄과 내비게이션 바 숨기기'),
          toggle(c, 'titlebarhide', '제목 표시줄 자동 숨기기', sub: '콘솔을 탭하면 다시 나타나요'),
          toggle(c, 'keepalive', '화면 켜짐 유지', sub: '콘솔에 연결된 동안 화면이 꺼지지 않아요'),
        ]),
      ],
      'keyboard' => [
        settingsSection(c, '특수키 바', [
          toggle(c, 'alwaysvisible', '특수키 항상 표시', sub: '키보드를 내려도 특수키 바를 남겨 둬요'),
          ListTile(
            title: const Text('특수키 구성'),
            subtitle: Text('${p['terminalBarHeight'] ?? 28}dp · 길게 눌러 순서 변경'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute<void>(
                builder: (_) => TerminalBarPage(engine: engine),
              ),
            ),
          ),
        ]),
        settingsSection(c, '한글 입력', [
          choice(c, 'imeShortcutInputMode', '한글 입력 중 Ctrl·Alt', [
            ('FORCE_ASCII', 'ASCII 키보드로 전환 (권장)'),
            ('TYPE_NULL', '직접 키 입력'),
            ('DISABLED', '현재 키보드 유지'),
          ]),
          choice(c, 'stickymodifiers', 'Ctrl·Alt 고정 방식', [
            ('no', '한 번만 적용'),
            ('yes', '고정'),
            ('alt', 'Alt만 고정'),
          ]),
        ]),
        settingsNote(c, '조합 모드는 콘솔 메뉴의 추가 기능에서 켜고 꺼요.'),
        settingsSection(c, '고급', [
          toggle(c, 'volumefont', '볼륨 키로 글꼴 크기 조절', sub: '호스트별 설정에서도 바꿀 수 있어요'),
          toggle(c, 'bumpyarrows', '방향키 진동', sub: '방향키를 누를 때 진동으로 알려요'),
          ExpansionTile(
            title: const Text('하드웨어 키보드'),
            children: [
              toggle(c, 'shiftfkeys', 'Shift+숫자를 기능키로 사용'),
              toggle(c, 'ctrlfkeys', 'Ctrl+숫자를 기능키로 사용'),
              choice(c, 'keymode', '보조 키 위치', [
                ('none', '사용 안 함'),
                ('Use right-side keys', '오른쪽'),
                ('Use left-side keys', '왼쪽'),
              ]),
              choice(c, 'camera', '카메라 버튼 동작', [
                ('Ctrl+A then Space', 'Ctrl+A, Space'),
                ('Ctrl+A', 'Ctrl+A'),
                ('Esc', 'Escape'),
                ('Esc+A', 'Escape, A'),
              ]),
            ],
          ),
        ]),
      ],
      'gesture' => [
        settingsSection(c, '콘솔 제스처', [
          toggle(
            c,
            'pgupdngesture',
            '세로 제스처로 페이지 이동',
            sub: 'PgUp·PgDn 키 입력으로 보내요',
          ),
          toggle(c, 'swipeSessions', '가로 제스처로 세션 이동'),
          toggle(c, 'swipeTmux', '가로 제스처로 tmux 창 이동'),
          if (p['swipeTmux'] == true)
            toggle(c, 'tmuxCtrlA', 'tmux 접두키로 Ctrl+A 사용'),
        ]),
      ],
      'terminal' => [
        settingsSection(c, '스크롤 기록', [scrollback(c)]),
        settingsSection(c, '프로필', [
          choice(c, 'defaultProfileId', '기본 터미널 프로필', [
            for (final profile in engine.list('profiles'))
              (profile['id'] as int, '${profile['name']}'),
          ]),
          ListTile(
            title: const Text('터미널 프로필'),
            subtitle: Text('${engine.list('profiles').length}개'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              c,
              MaterialPageRoute<void>(
                builder: (_) =>
                    RecordListPage(engine: engine, kind: RecordKind.profile),
              ),
            ),
          ),
        ]),
        settingsSection(c, '사용자 지정 TERM', [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in (p['customTerminalTypes'] as List? ?? []))
                  InputChip(
                    label: Text(
                      '$type',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    onDeleted: () => runEngine(
                      c,
                      engine,
                      'terminalType.delete',
                      {'name': type},
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('추가'),
                  onPressed: () async {
                    final name = await askText(c, '터미널 종류');
                    if (name != null && c.mounted) {
                      await runEngine(c, engine, 'terminalType.add', {
                        'name': name,
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ]),
      ],
      'connection' => [
        settingsSection(c, '알림', [
          toggle(c, 'connectionAlerts', '연결 알림', sub: '선택한 벨·연결 끊김 알림을 허용해요'),
          ListTile(
            title: const Text('알림 채널 관리'),
            subtitle: Text(
              p['notificationsAvailable'] == true
                  ? 'Android 설정에서 종류별로 조정해요'
                  : 'Android 설정에서 알림을 허용해 주세요',
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => runEngine(c, engine, 'settings.notifications'),
          ),
          ExpansionTile(
            title: const Text('알림 종류'),
            children: [
              toggle(
                c,
                'bellNotification',
                '벨 알림',
                enabled: p['connectionAlerts'] == true,
              ),
              toggle(
                c,
                'connectionLostNotification',
                '연결 끊김 알림',
                enabled: p['connectionAlerts'] == true,
              ),
            ],
          ),
          toggle(c, 'wifilock', 'Wi-Fi 연결 유지', sub: '세션이 열려 있는 동안 Wi-Fi 절전 방지'),
        ]),
        settingsSection(c, '터미널 벨', [
          toggle(c, 'bell', '벨 소리', sub: '터미널이 경고하면 소리 재생'),
          if (p['bell'] == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.volume_down, color: cs.onSurfaceVariant),
                  Expanded(
                    child: Slider(
                      value: ((p['bellVolume'] as num?)?.toDouble() ?? .5)
                          .clamp(0, 1),
                      label:
                          '${(((p['bellVolume'] as num?)?.toDouble() ?? .5) * 100).round()}%',
                      onChanged: (v) => update(c, 'bellVolume', v),
                    ),
                  ),
                  Text(
                    '${(((p['bellVolume'] as num?)?.toDouble() ?? .5) * 100).round()}%',
                    style: Theme.of(c).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          toggle(c, 'bellVibrate', '벨 진동', sub: '터미널이 경고하면 진동'),
        ]),
        settingsNote(c, '연결 중 상태 알림은 세션 유지용으로, 위의 연결 알림과 별개예요.'),
      ],
      'security' => [
        settingsSection(c, '잠금과 SSH 키', [
          toggle(
            c,
            'authOnLaunch',
            '앱 실행 시 잠금 해제',
            sub: '기기의 지문이나 화면 잠금으로 인증해요',
            enabled: p['canAuthenticate'] == true,
          ),
          toggle(c, 'memkeys', '해제한 SSH 키를 메모리에 유지'),
          toggle(c, 'backupkeys', 'SSH 키 백업 허용'),
        ]),
      ],
      'fonts' => [
        if (p['fontBusy'] == true) const LinearProgressIndicator(),
        if (p['fontError'] != null) settingsNote(c, '${p['fontError']}'),
        settingsSection(c, '기기의 글꼴', [
          ListTile(
            title: const Text('글꼴 파일 가져오기'),
            leading: const Icon(Icons.upload_file),
            onTap: p['fontBusy'] == true ? null : () => importFont(c),
          ),
          for (final font in rows(p['localFonts']))
            ListTile(
              title: Text('${font['displayName']}'),
              subtitle: Text('${font['fileName']}'),
              trailing: IconButton(
                tooltip: '글꼴 삭제',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(
                        c,
                        '글꼴을 지울까요?',
                        '이 글꼴 파일을 삭제해요.',
                        action: '지우기',
                      ) &&
                      c.mounted) {
                    await runEngine(c, engine, 'font.delete', {
                      'fileName': font['fileName'],
                    });
                  }
                },
              ),
            ),
        ]),
        settingsSection(c, 'Google Fonts', [
          ListTile(
            title: const Text('글꼴 추가'),
            leading: const Icon(Icons.add),
            onTap: () async {
              final name = await askText(c, 'Google Fonts 글꼴 이름');
              if (name != null && c.mounted) {
                await runEngine(c, engine, 'font.custom', {'name': name});
              }
            },
          ),
          for (final font in (p['customFonts'] as List? ?? []))
            ListTile(
              title: Text('$font'),
              trailing: IconButton(
                tooltip: '글꼴 제거',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    runEngine(c, engine, 'font.customDelete', {'name': font}),
              ),
            ),
        ]),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
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
          '호스트를 추가해 SSH, Mosh, Telnet 또는 로컬 터미널에 연결해요. 터미널을 누르면 키보드가 열려요. 특수키의 Ctrl과 Alt는 다음 입력에 적용돼요. 콘솔 메뉴에서 선택, 복사, 붙여넣기, 조합 모드를 사용할 수 있어요.',
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
