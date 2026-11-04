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
import 'tilde_controls.dart';
import 'tilde_design.dart';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'editors.dart';
import 'settings_widgets.dart';
import 'main.dart';
export 'settings.dart';

Future<void> showIdentityEditor(
  BuildContext context,
  AndroidEngine engine, {
  EngineRecord? record,
}) => showTildeSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  maxWidth: 560,
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .88,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: RecordEditor(
        engine: engine,
        kind: RecordKind.identity,
        record: record,
      ),
    ),
  ),
);

Future<void> showForwardEditor(
  BuildContext context,
  AndroidEngine engine,
  EngineRecord host, {
  EngineRecord? record,
  int? sessionId,
}) => showTildeSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  maxWidth: 440,
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: (MediaQuery.sizeOf(context).height * .9).clamp(
        0,
        double.infinity,
      ),
    ),
    child: RecordEditor(
      sheet: true,
      engine: engine,
      kind: RecordKind.forward,
      record: record,
      hostId: host['id'] as int,
      sessionId: sessionId,
    ),
  ),
);

class RecordListPage extends StatelessWidget {
  final AndroidEngine engine;
  final RecordKind kind;
  const RecordListPage({super.key, required this.engine, required this.kind});
  int usage(EngineRecord record) => engine
      .list('hosts')
      .where(
        (h) =>
            h[kind == RecordKind.profile ? 'profileId' : 'identityId'] ==
            record['id'],
      )
      .length;
  Future<void> edit(BuildContext context, [EngineRecord? record]) =>
      kind == RecordKind.identity
      ? showIdentityEditor(context, engine, record: record)
      : Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RecordEditor(engine: engine, kind: kind, record: record),
          ),
        );
  Future<void> action(
    BuildContext context,
    EngineRecord record,
    String action,
  ) async {
    if (action == 'edit') {
      await edit(context, record);
      return;
    }
    if (action == 'default') {
      await runEngine(context, engine, 'settings.update', {
        'key': 'defaultProfileId',
        'value': record['id'],
      });
      return;
    }
    if (action == 'duplicate') {
      final name = await askText(
        context,
        '복제할 이름',
        initial: "${record['name']} 복사본",
        action: '복제',
      );
      if (name != null && context.mounted) {
        await runEngine(context, engine, 'profile.duplicate', {
          'id': record['id'],
          'name': name,
        });
      }
      return;
    }
    final count = usage(record);
    final impact = kind == RecordKind.profile
        ? (count > 0 ? '$count개 호스트가 앱 기본 프로필을 사용하게 됩니다.' : '이 프로필을 삭제합니다.')
        : '$count개 호스트의 연결은 남지만 공용 비밀번호는 삭제됩니다.';
    if (await confirm(
          context,
          '${kindTitle(kind)} 삭제',
          "${record['name']}\n$impact",
          action: '삭제',
        ) &&
        context.mounted) {
      await runEngine(context, engine, '${kind.name}.delete', {
        'id': record['id'],
      });
    }
  }

  List<PopupMenuEntry<String>> items(EngineRecord record) => [
    const PopupMenuItem(
      value: 'edit',
      child: TildeMenuLabel('편집', Icons.edit_outlined),
    ),
    if (kind == RecordKind.profile) ...[
      if (record['id'] != engine.preferences['defaultProfileId'])
        PopupMenuItem(
          value: 'default',
          child: TildeMenuLabel(
            '기본으로 지정',
            Icons.task_alt,
            selected: record['id'] == engine.preferences['defaultProfileId'],
          ),
        ),
      const PopupMenuItem(
        value: 'duplicate',
        child: TildeMenuLabel('복제', Icons.content_copy_outlined),
      ),
    ],
    if (kind != RecordKind.profile ||
        record['id'] != engine.preferences['defaultProfileId']) ...[
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'delete',
        child: TildeMenuLabel('삭제', Icons.delete_outline, danger: true),
      ),
    ],
  ];

  Future<void> showMenu(BuildContext context, EngineRecord record) async {
    final value = await TildeItemMenu.show<String>(
      context,
      title: '${record['name']}',
      icon: kind == RecordKind.profile
          ? Icons.terminal_outlined
          : Icons.person_outline,
      itemBuilder: (_) => items(record),
    );
    if (value != null && context.mounted) await action(context, record, value);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final profile = kind == RecordKind.profile;
      final records = engine.list(profile ? 'profiles' : 'identities');
      return Scaffold(
        appBar: AppBar(
          title: Text(profile ? '터미널 프로필' : kindTitle(kind)),
          actions: [
            if (tildePointer(context))
              TextButton.icon(
                onPressed: () => edit(context),
                icon: const Icon(Icons.add),
                label: Text('${profile ? '프로필' : '계정'} 추가'),
              )
            else if (records.isNotEmpty)
              IconButton(
                tooltip: '${profile ? '프로필' : '계정'} 추가',
                onPressed: () => edit(context),
                icon: const Icon(Icons.add),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => edit(context),
                    icon: const Icon(Icons.add),
                    label: Text('${profile ? '프로필' : '계정'} 추가'),
                  ),
                ),
              ),
            if (!profile && records.isEmpty)
              settingsNote(context, '여러 호스트에서 사용자 이름·키·비밀번호를 함께 사용합니다.'),
            for (final record in records)
              Builder(
                builder: (anchor) => GestureDetector(
                  onSecondaryTapUp: (_) => showMenu(anchor, record),
                  child: ListTile(
                    leading: profile
                        ? SizedBox(
                            width: 64,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: TerminalPreview(
                                engine: engine,
                                framed: false,
                                overrides: {
                                  'profile': {...record, 'fontSize': 9},
                                  'compact': true,
                                },
                              ),
                            ),
                          )
                        : const Icon(Icons.person_outline),
                    title: Text('${record['name']}'),
                    subtitle: Text(
                      profile
                          ? '${engine.list('schemes').where((s) => s['id'] == record['colorSchemeId']).firstOrNull?['name'] ?? '색상 테마'} · ${record['fontSize'] ?? ''}${record['id'] == engine.preferences['defaultProfileId'] ? ' · 기본' : ''}'
                          : '${record['username'] ?? ''} · ${usage(record) == 0 ? '쓰는 호스트 없음' : '호스트 ${usage(record)}개'}',
                    ),
                    onTap: () => edit(context, record),
                    onLongPress: () => showMenu(anchor, record),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TildeItemMenu<String>(
                          title: '${record['name']}',
                          icon: profile
                              ? Icons.terminal_outlined
                              : Icons.person_outline,
                          onSelected: (value) => action(context, record, value),
                          itemBuilder: (_) => items(record),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Future<void> importTildeKeyFile(
  BuildContext context,
  AndroidEngine engine,
) async {
  final path = await runEngine(context, engine, 'document.pick');
  if (path is! String || !context.mounted) return;
  final password = await askText(
    context,
    '개인키 암호',
    password: true,
    hintText: '암호가 없으면 비워두세요.',
    action: '추가',
  );
  if (password == null || !context.mounted) return;
  await runEngine(context, engine, 'key.import', {
    'path': path,
    'password': password,
    'nickname': Uri.file(
      path,
      windows: engine.state['platform'] == 'windows',
    ).pathSegments.last,
  });
}

class KeyPage extends StatefulWidget {
  final AndroidEngine engine;
  const KeyPage({super.key, required this.engine});
  @override
  State<KeyPage> createState() => _KeyPageState();
}

class _KeyPageState extends State<KeyPage> {
  AndroidEngine get engine => widget.engine;

  @override
  void initState() {
    super.initState();
    engine.addListener(changed);
  }

  @override
  void dispose() {
    engine.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> keyAction(EngineRecord key, String action) async {
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              RecordEditor(engine: engine, kind: RecordKind.key, record: key),
        ),
      );
      return;
    }
    if (action == 'delete') {
      if (await confirm(
            context,
            '키 삭제',
            '${key['nickname']} 키를 삭제할까요?',
            action: '키 삭제',
          ) &&
          mounted) {
        await runEngine(context, engine, 'key.delete', {'id': key['id']});
      }
      return;
    }
    if (!mounted) return;
    final parts = action.split('.');
    if (mounted && parts.last == 'public') {
      await runEngine(context, engine, 'key.${parts.first}', {
        'id': key['id'],
        'format': 'public',
      });
    }
  }

  List<PopupMenuEntry<String>> items(EngineRecord key) => [
    const PopupMenuItem(
      value: 'edit',
      child: TildeMenuLabel('편집', Icons.edit_outlined),
    ),
    if (key['publicKey'] != null) ...[
      const PopupMenuItem(
        value: 'copy.public',
        child: TildeMenuLabel('공개키 복사', Icons.content_copy_outlined),
      ),
      const PopupMenuItem(
        value: 'export.public',
        child: TildeMenuLabel('공개키 파일 저장', Icons.download_outlined),
      ),
    ],
    const PopupMenuDivider(),
    const PopupMenuItem(
      value: 'delete',
      child: TildeMenuLabel('삭제', Icons.delete_outline, danger: true),
    ),
  ];

  Future<void> showMenu(
    BuildContext anchor,
    EngineRecord key, [
    Offset? position,
  ]) async {
    final value = await TildeItemMenu.show<String>(
      anchor,
      position: position,
      title: '${key['nickname']}',
      subtitle: '${key['displayType'] ?? key['type']}',
      icon: Icons.key_outlined,
      itemBuilder: (_) => items(key),
    );
    if (value != null && mounted) await keyAction(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final state = row(engine.state['keyState']);
    final ios = engine.state['platform'] == 'ios';
    final fileKeys = ios || engine.state['platform'] == 'windows';
    final VoidCallback? addKey = fileKeys
        ? () => importTildeKeyFile(context, engine)
        : row(engine.state['generation'])['biometricAvailable'] == true
        ? () => showTildeSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (c) => GenerateKeyPage(engine: engine),
          )
        : null;
    final addLabel = fileKeys ? '키 파일 추가' : '새 키';
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH 키'),
        actions: [
          if (tildePointer(context))
            TextButton.icon(
              onPressed: addKey,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            )
          else if (engine.list('keys').isNotEmpty)
            IconButton(
              tooltip: addLabel,
              onPressed: addKey,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: ListView(
        children: [
          if (state['error'] != null || state['nicknameError'] != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                title: const Text('키 작업을 완료하지 못했습니다'),
                trailing: TextButton(
                  onPressed: () => showErrorDetails(
                    context,
                    '${state['error'] ?? state['nicknameError']}',
                  ),
                  child: const Text('자세히'),
                ),
              ),
            ),
          if (engine.list('keys').isEmpty)
            settingsNote(
              context,
              ios
                  ? '가져온 개인키는 앱의 보호된 저장소에서 사용합니다. 저장한 키 암호는 iOS Keychain으로 보호합니다.'
                  : fileKeys
                  ? '개인키 파일은 원래 위치에서 사용합니다. 저장한 키 암호는 Windows 계정으로 보호합니다.'
                  : '개인키는 Android Keystore에서 생성되며 기기 밖으로 내보낼 수 없습니다. 기존 개인키는 사용 중지 상태로 보존됩니다.',
            ),
          if (engine.list('keys').isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: addKey,
                  icon: const Icon(Icons.add),
                  label: Text(addLabel),
                ),
              ),
            ),
          ...[
            for (final key in engine.list('keys'))
              Builder(
                builder: (anchor) => GestureDetector(
                  onSecondaryTapUp: (event) =>
                      showMenu(anchor, key, event.globalPosition),
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text('${key['nickname']}'),
                    subtitle: Text(
                      '${key['displayType'] ?? key['type']}${key['supported'] == true ? ' · ${key['providerLabel'] ?? (fileKeys ? '키 파일' : 'Android Keystore')}' : ' · ${key['supportMessage'] ?? '사용 중지'}'}',
                    ),
                    onTap: () => keyAction(key, 'edit'),
                    onLongPress: () => showMenu(anchor, key),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TildeItemMenu<String>(
                          title: '${key['nickname']}',
                          icon: Icons.key_outlined,
                          tooltip: '${key['nickname']} 옵션',
                          onSelected: (action) => keyAction(key, action),
                          itemBuilder: (_) => items(key),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class ForwardsPage extends StatefulWidget {
  final AndroidEngine engine;
  final EngineRecord host;
  final int? sessionId;
  const ForwardsPage({
    super.key,
    required this.engine,
    required this.host,
    this.sessionId,
  });
  @override
  State<ForwardsPage> createState() => _ForwardsPageState();
}

class _ForwardsPageState extends State<ForwardsPage> {
  List<EngineRecord> forwards = [];
  bool loading = false;
  String? error;
  int? sessionId;
  List<EngineRecord> get sessions => widget.engine
      .list('sessions')
      .where((s) => s['hostId'] == widget.host['id'] && s['canForward'] == true)
      .toList();
  bool get live => sessions.any((s) => s['id'] == sessionId);
  @override
  void initState() {
    super.initState();
    sessionId =
        widget.sessionId ??
        (sessions.length == 1 ? sessions.first['id'] as int : null);
    widget.engine.addListener(changed);
    unawaited(load());
  }

  @override
  void dispose() {
    widget.engine.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (mounted) setState(() {});
    unawaited(load());
  }

  Future<void> load() async {
    if (loading || !mounted) return;
    loading = true;
    try {
      final result = rows(
        await widget.engine.query('forwards', {
          'hostId': widget.host['id'],
          if (live) 'sessionId': sessionId,
        }),
      );
      if (mounted) {
        setState(() {
          forwards = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      loading = false;
    }
  }

  Future<void> edit([EngineRecord? record]) async {
    await showForwardEditor(
      context,
      widget.engine,
      widget.host,
      record: record,
      sessionId: live ? sessionId : null,
    );
    await load();
  }

  Future<void> menu(
    BuildContext anchor,
    EngineRecord forward, [
    Offset? position,
  ]) async {
    final action = await TildeItemMenu.show<String>(
      anchor,
      position: position,
      title: '${forward['nickname']}',
      icon: Icons.swap_horiz,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: TildeMenuLabel('편집', Icons.edit_outlined),
        ),
        PopupMenuItem(
          value: 'copy',
          child: TildeMenuLabel('복제', Icons.content_copy_outlined),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: TildeMenuLabel('삭제', Icons.delete_outline, danger: true),
        ),
      ],
    );
    if (action == null || !mounted) return;
    if (action == 'edit') {
      await edit(forward);
      return;
    }
    if (action == 'copy') {
      final copy = {
        ...forward,
        'id': 0,
        'nickname': '${forward['nickname']} 복사본',
      };
      await edit(copy);
      return;
    }
    if (await confirm(
          context,
          '포워딩 삭제',
          '${forward['nickname']} 설정을 삭제할까요?',
          action: '삭제',
        ) &&
        mounted) {
      await runEngine(context, widget.engine, 'forward.delete', {
        'id': forward['id'],
      });
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.host['nickname']} · 포워딩'),
      actions: [
        if (tildePointer(context))
          TextButton.icon(
            onPressed: () => edit(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('포워딩 추가'),
          )
        else if (forwards.isNotEmpty)
          IconButton(
            tooltip: '포워딩 추가',
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
          ),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: tildePointer(context) ? 640 : double.infinity,
        ),
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 104),
            children: [
              if (forwards.isEmpty && !loading)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('포워딩 추가'),
                    ),
                  ),
                ),
              if (sessions.isNotEmpty)
                ListTile(
                  title: const Text('제어할 세션'),
                  subtitle: Text(
                    live
                        ? '${sessions.where((s) => s['id'] == sessionId).first['nickname']} · 스위치를 바꾸면 즉시 적용됩니다'
                        : '접속 시 기본값',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final choice = await pickTildeOption(context, '제어할 세션', [
                      (null, '접속 시 기본값'),
                      for (final s in sessions) (s['id'], '${s['nickname']}'),
                    ], live ? sessionId : null);
                    if (choice != null && mounted) {
                      setState(() => sessionId = choice.$1 as int?);
                      await load();
                    }
                  },
                ),

              if (error != null)
                ListTile(
                  title: const Text('포워딩을 불러오지 못했습니다'),
                  trailing: TextButton(
                    onPressed: () => showErrorDetails(context, error!),
                    child: const Text('자세히'),
                  ),
                ),
              for (final f in forwards)
                Builder(
                  builder: (anchor) => GestureDetector(
                    onSecondaryTapUp: (event) =>
                        menu(anchor, f, event.globalPosition),
                    child: ListTile(
                      title: Text('${f['nickname']}'),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(switch (f['type']) {
                              'local' => '로컬',
                              'remote' => '원격',
                              _ => 'SOCKS',
                            }, style: const TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Tooltip(
                              message:
                                  '${f['sourceAddr']}:${f['sourcePort']} → ${f['destAddr']}:${f['destPort']}',
                              child: Text(
                                f['type'] == 'dynamic4'
                                    ? 'SOCKS4 미지원 · SOCKS5로 변경하세요'
                                    : '${['127.0.0.1', 'localhost', '::1', ''].contains(f['sourceAddr']) ? '' : '${f['sourceAddr']}:'}${f['sourcePort']} → ${f['type'].toString().startsWith('dynamic') ? 'SOCKS5' : '${f['destAddr']}:${f['destPort']}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: tildeMono,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => edit(f),
                      onLongPress: () => menu(anchor, f),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (live)
                            Switch(
                              value:
                                  f['type'] != 'dynamic4' &&
                                  f['enabled'] == true,
                              onChanged: f['type'] == 'dynamic4'
                                  ? null
                                  : (value) async {
                                      await runEngine(
                                        context,
                                        widget.engine,
                                        'forward.toggle',
                                        {
                                          'hostId': widget.host['id'],
                                          'sessionId': sessionId,
                                          'id': f['id'],
                                          'enabled': value,
                                        },
                                      );
                                      await load();
                                    },
                            ),
                          IconButton(
                            tooltip: '${f['nickname']} 옵션',
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => menu(anchor, f),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class KnownHostsPage extends StatelessWidget {
  final AndroidEngine engine;
  final int? hostId;
  const KnownHostsPage({super.key, required this.engine, this.hostId});
  Future<void> action(
    BuildContext context,
    EngineRecord host,
    String value,
  ) async {
    if (value == 'copy') {
      await Clipboard.setData(
        ClipboardData(text: '${host['fingerprint'] ?? ''}'),
      );
      return;
    }
    if (value == 'detail') {
      await showTildeSheet<void>(
        context: context,
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${host['hostname']}:${host['port']}',
                style: Theme.of(c).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('${host['algorithm']}'),
              const SizedBox(height: 8),
              SelectableText(
                '${host['fingerprint'] ?? ''}',
                style: const TextStyle(
                  fontFamily: tildeMono,
                  fontFamilyFallback: tildeMonoFallback,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => action(c, host, 'copy'),
                  child: const Text('지문 복사'),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (await confirm(
          context,
          '서버 키 신뢰 삭제',
          '${host['hostname']}:${host['port']}\n다음 접속에서 서버 키를 다시 확인합니다.',
          action: '서버 키 삭제',
        ) &&
        context.mounted) {
      await runEngine(context, engine, 'knownHost.delete', {'id': host['id']});
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final hosts = engine
          .list('knownHosts')
          .where((host) => hostId == null || host['hostId'] == hostId)
          .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('신뢰한 서버 키')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (hosts.isEmpty) settingsNote(context, '신뢰한 서버 키가 없습니다.'),
            for (final host in hosts)
              ListTile(
                title: Text(
                  '${host['hostname']}:${host['port']} · ${host['algorithm']}',
                ),
                subtitle: LayoutBuilder(
                  builder: (context, constraints) {
                    final text = '${host['fingerprint'] ?? ''}';
                    final count = (constraints.maxWidth / 7.5).floor().clamp(
                      12,
                      text.length < 12 ? 12 : text.length,
                    );
                    final shown = text.length > count
                        ? '${text.substring(0, count ~/ 2)}…${text.substring(text.length - count ~/ 2)}'
                        : text;
                    return Text(
                      shown,
                      maxLines: 1,
                      style: const TextStyle(
                        fontFamily: tildeMono,
                        fontFamilyFallback: tildeMonoFallback,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
                onTap: () => action(context, host, 'detail'),
                trailing: TildeItemMenu<String>(
                  title: '${host['hostname']}',
                  icon: Icons.verified_user_outlined,
                  onSelected: (value) => action(context, host, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'copy',
                      child: TildeMenuLabel(
                        '지문 복사',
                        Icons.content_copy_outlined,
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: TildeMenuLabel(
                        '서버 키 신뢰 삭제',
                        Icons.delete_outline,
                        danger: true,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

class SchemesPage extends StatefulWidget {
  final AndroidEngine engine;
  const SchemesPage({super.key, required this.engine});
  @override
  State<SchemesPage> createState() => _SchemesPageState();
}

class _SchemesPageState extends State<SchemesPage> {
  AndroidEngine get engine => widget.engine;
  int? hover;
  List<PopupMenuEntry<String>> items(EngineRecord scheme) => [
    const PopupMenuItem(
      value: 'use',
      child: TildeMenuLabel('사용', Icons.check_circle_outline),
    ),
    if ((scheme['id'] as int) >= 0) ...[
      const PopupMenuItem(
        value: 'edit',
        child: TildeMenuLabel('팔레트 편집', Icons.tune),
      ),
      const PopupMenuItem(
        value: 'copyEdit',
        child: TildeMenuLabel('복제', Icons.content_copy_outlined),
      ),
    ] else
      const PopupMenuItem(
        value: 'copyEdit',
        child: TildeMenuLabel('복제', Icons.content_copy_outlined),
      ),
    const PopupMenuItem(
      value: 'export',
      child: TildeMenuLabel('내보내기', Icons.ios_share),
    ),
    if ((scheme['id'] as int) >= 0) ...[
      const PopupMenuItem(
        value: 'rename',
        child: TildeMenuLabel('이름 변경', Icons.drive_file_rename_outline),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'delete',
        child: TildeMenuLabel('삭제', Icons.delete_outline, danger: true),
      ),
    ],
  ];

  Future<void> showMenu(
    BuildContext context,
    EngineRecord scheme, [
    Offset? position,
  ]) async {
    final value = await TildeItemMenu.show<String>(
      context,
      title: '${scheme['name']}',
      position: position,
      leading: SizedBox(
        width: 64,
        height: 40,
        child: TerminalPreview(
          engine: engine,
          framed: false,
          overrides: {
            'profile': {'colorSchemeId': scheme['id'], 'fontSize': 9},
            'compact': true,
          },
        ),
      ),
      subtitle: (scheme['id'] as int) < 0 ? '기본 테마' : '사용자 테마',
      icon: Icons.palette_outlined,
      itemBuilder: (_) => items(scheme),
    );
    if (value != null && context.mounted) await action(context, scheme, value);
  }

  Future<void> action(
    BuildContext context,
    EngineRecord scheme,
    String action,
  ) async {
    if (action == 'use') {
      await runEngine(context, engine, 'settings.update', {
        'key': 'colorScheme',
        'value': scheme['id'],
      });
      return;
    }
    if (action == 'copyEdit') {
      final name = await askText(
        context,
        '복제할 테마 이름',
        initial: '${scheme['name']} 복사본',
        action: '복제',
      );
      if (name == null || !context.mounted) return;
      final id = await runEngine(context, engine, 'scheme.duplicate', {
        'id': scheme['id'],
        'name': name,
      });
      if (id == null || !context.mounted) return;
      final copy = engine
          .list('schemes')
          .where((s) => s['id'] == id)
          .firstOrNull;
      if (copy != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => PalettePage(engine: engine, scheme: copy),
          ),
        );
      }
      return;
    }

    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PalettePage(engine: engine, scheme: scheme),
        ),
      );
      return;
    }
    if (action == 'rename') {
      final name = await askText(
        context,
        '테마 이름',
        initial: '${scheme['name']}',
        action: '이름 변경',
      );
      if (name != null && context.mounted) {
        await runEngine(context, engine, 'scheme.$action', {
          'id': scheme['id'],
          'name': name,
        });
      }
    }
    if (action == 'delete' &&
        context.mounted &&
        await confirm(context, '테마 삭제', '${scheme['name']} 테마를 삭제할까요?') &&
        context.mounted) {
      await runEngine(context, engine, 'scheme.delete', {'id': scheme['id']});
    }
    if (action == 'export' && context.mounted) {
      final text = await runEngine(context, engine, 'scheme.export', {
        'id': scheme['id'],
      });
      if (text == null || !context.mounted) {
        return;
      }
      final uri = await runEngine(context, engine, 'document.create', {
        'name': '${scheme['name']}.json',
      });
      if (uri != null && context.mounted) {
        await runEngine(context, engine, 'document.write', {
          'uri': uri,
          'text': text,
        });
      }
    }
  }

  Future<void> createTheme(BuildContext context) async {
    final name = await askText(context, '새 테마 이름', action: '만들기');
    if (name == null || !context.mounted) return;
    final id = await runEngine(context, engine, 'scheme.create', {
      'name': name,
      'sourceId': defaultProfile(engine)['colorSchemeId'] ?? -1,
    });
    if (id != null && context.mounted) {
      final scheme = engine
          .list('schemes')
          .where((scheme) => scheme['id'] == id)
          .firstOrNull;
      if (scheme != null) await action(context, scheme, 'edit');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('색상 테마'),
        actions: [
          if (tildePointer(context))
            TextButton.icon(
              onPressed: () => createTheme(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 테마'),
            )
          else
            IconButton(
              tooltip: '새 테마',
              onPressed: () => createTheme(context),
              icon: const Icon(Icons.add),
            ),
          TextButton(
            child: const Text('가져오기'),
            onPressed: () async {
              final uri = await runEngine(context, engine, 'document.pick');
              if (uri == null || !context.mounted) return;
              final text = await runEngine(context, engine, 'document.read', {
                'uri': uri,
              });
              if (text != null && context.mounted) {
                await runEngine(context, engine, 'scheme.import', {
                  'text': text,
                });
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final pointer = tildePointer(context);
          final count = pointer
              ? ((constraints.maxWidth - 20) / 212).floor().clamp(1, 100)
              : constraints.maxWidth < 360 || scale > 1.4
              ? 1
              : constraints.maxWidth > 900
              ? 3
              : 2;
          final selectedId = defaultProfile(engine)['colorSchemeId'];
          return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: pointer ? count * 212.0 + 20 : constraints.maxWidth,
              child: GridView.count(
                crossAxisCount: count,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 128 + scale * 64,
                children: [
                  for (final scheme in [
                    ...engine
                        .list('schemes')
                        .where((s) => tildeBaseSchemeIds.contains(s['id'])),
                    ...engine
                        .list('schemes')
                        .where((s) => !tildeBaseSchemeIds.contains(s['id'])),
                  ])
                    MouseRegion(
                      onEnter: (_) =>
                          setState(() => hover = scheme['id'] as int),
                      onExit: (_) => setState(() => hover = null),
                      child: Semantics(
                        selected: scheme['id'] == selectedId,
                        child: GestureDetector(
                          onSecondaryTapUp: (event) =>
                              showMenu(context, scheme, event.globalPosition),
                          child: Card.filled(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: InkWell(
                              onLongPress: () => showMenu(context, scheme),
                              onDoubleTap: pointer
                                  ? () => action(context, scheme, 'use')
                                  : null,
                              onTap: pointer
                                  ? () => setState(
                                      () => hover = scheme['id'] as int,
                                    )
                                  : () => runEngine(
                                      context,
                                      engine,
                                      'settings.update',
                                      {
                                        'key': 'colorScheme',
                                        'value': scheme['id'],
                                      },
                                    ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: paletteColor(scheme, 'background'),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            r'~ $ ls',
                                            style: TextStyle(
                                              fontFamily: tildeMono,
                                              fontSize: 12,
                                              color: paletteColor(
                                                scheme,
                                                'foreground',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              for (final color
                                                  in (scheme['palette']
                                                              as List? ??
                                                          [])
                                                      .skip(1)
                                                      .take(4))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 4,
                                                      ),
                                                  child: Container(
                                                    width: 14,
                                                    height: 14,
                                                    decoration: BoxDecoration(
                                                      color: Color(
                                                        (color as num).toInt(),
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            7,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${scheme['name']}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                        ),
                                        if (scheme['id'] == selectedId)
                                          Icon(
                                            Icons.check_circle,
                                            size: 20,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        Opacity(
                                          opacity:
                                              !pointer || hover == scheme['id']
                                              ? 1
                                              : 0,
                                          child: TildeItemMenu<String>(
                                            title: '${scheme['name']}',
                                            icon: Icons.palette_outlined,
                                            tooltip: '${scheme['name']} 옵션',
                                            onSelected: (value) =>
                                                action(context, scheme, value),
                                            itemBuilder: (_) => items(scheme),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class PalettePage extends StatefulWidget {
  final AndroidEngine engine;
  final EngineRecord scheme;
  const PalettePage({super.key, required this.engine, required this.scheme});
  @override
  State<PalettePage> createState() => _PalettePageState();
}

class _PalettePageState extends State<PalettePage> {
  EngineRecord palette = {};
  String? error;
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final result = row(
        await widget.engine.query('scheme.palette', {
          'id': widget.scheme['id'],
        }),
      );
      if (mounted) setState(() => palette = result);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Color role(String key) => Color(
    (palette['${key}Color'] as num?)?.toInt() ??
        (key == 'background'
            ? tildeNightBackground.toARGB32()
            : tildeTide.toARGB32()),
  );
  Future<void> editColor({String? key, int? index}) async {
    final original = Map<String, dynamic>.from(palette);
    final colors = List<int>.from(palette['colors'] as List? ?? []);
    final initial = key == null ? Color(colors[index!]) : role(key);
    void preview(Color value) {
      if (!mounted) return;
      setState(() {
        if (key != null) {
          palette['${key}Color'] = value.toARGB32();
        } else {
          final updated = List<int>.from(colors);
          updated[index!] = value.toARGB32();
          palette['colors'] = updated;
        }
      });
    }

    final value = await pickTildeColor(
      context,
      initial,
      title: key == null
          ? 'ANSI $index'
          : switch (key) {
              'foreground' => '글자 색',
              'background' => '배경 색',
              _ => '커서 · 앱 강조색',
            },
      onPreview: preview,
      swatches: [for (final color in colors) Color(color)],
    );
    if (!mounted) return;
    setState(() => palette = original);
    if (value == null) return;
    await runEngine(
      context,
      widget.engine,
      key == null ? 'scheme.color' : 'scheme.role',
      {
        'id': widget.scheme['id'],
        'role': ?key,
        'index': ?index,
        'color': value.toARGB32(),
      },
    );
    await load();
  }

  Future<void> menu(String value) async {
    if (value != 'export') return;
    final text = await runEngine(context, widget.engine, 'scheme.export', {
      'id': widget.scheme['id'],
    });
    if (text == null || !mounted) return;
    final uri = await runEngine(context, widget.engine, 'document.create', {
      'name': '${widget.scheme['name']}.json',
    });
    if (uri != null && mounted) {
      await runEngine(context, widget.engine, 'document.write', {
        'uri': uri,
        'text': text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = (widget.scheme['id'] as int) >= 0;
    final colors = List<int>.from(palette['colors'] as List? ?? []);
    double contrast(Color a, Color b) {
      final l = a.computeLuminance(), r = b.computeLuminance();
      return ((l > r ? l : r) + .05) / ((l > r ? r : l) + .05);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.scheme['name']}'),
        actions: [
          TildeItemMenu<String>(
            title: '${widget.scheme['name']}',
            icon: Icons.palette_outlined,
            onSelected: menu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'export',
                child: TildeMenuLabel('내보내기', Icons.ios_share),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (error != null)
            ListTile(
              title: const Text('색상 테마를 불러오지 못했습니다'),
              trailing: TextButton(
                onPressed: () => showErrorDetails(context, error!),
                child: const Text('자세히'),
              ),
            ),
          if (!editable) settingsNote(context, '복사본을 만들어 색상을 편집하세요.'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: role('background'),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '~ \$ ls\nsrc  build  한글.md\n',
                      style: TextStyle(color: role('foreground')),
                    ),
                    TextSpan(
                      text: '▏',
                      style: TextStyle(color: role('cursor')),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontFamily: tildeMono,
                  fontFamilyFallback: ['Pretendard'],
                  fontSize: 14,
                ),
              ),
            ),
          ),
          settingsSection(context, '기본 색', [
            for (final key in ['foreground', 'background', 'cursor'])
              ListTile(
                title: Text(switch (key) {
                  'foreground' => '글자 색',
                  'background' => '배경 색',
                  _ => '커서 · 앱 강조색',
                }),
                subtitle: Text(
                  key != 'background' &&
                          contrast(role(key), role('background')) < 3
                      ? '배경과 대비가 낮습니다'
                      : '#${role(key).toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  style: TextStyle(
                    fontFamily:
                        key != 'background' &&
                            contrast(role(key), role('background')) < 3
                        ? 'Pretendard'
                        : tildeMono,
                    color:
                        key != 'background' &&
                            contrast(role(key), role('background')) < 3
                        ? Theme.of(context).colorScheme.tertiary
                        : null,
                  ),
                ),
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: role(key),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                onTap: editable ? () => editColor(key: key) : null,
              ),
          ]),
          settingsSection(context, 'ANSI 팔레트', [
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < colors.length; i++)
                      Semantics(
                        label: 'ANSI $i 색상',
                        button: true,
                        child: InkWell(
                          onTap: editable ? () => editColor(index: i) : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: (constraints.maxWidth - 56) / 8,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color(colors[i]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$i',
                              style: TextStyle(
                                color: Color(colors[i]).computeLuminance() > .4
                                    ? Colors.black
                                    : Colors.white,
                                fontFamily: tildeMono,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
