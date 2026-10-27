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
export 'automation.dart';
export 'settings.dart';

Future<void> showIdentityEditor(
  BuildContext context,
  AndroidEngine engine, {
  EngineRecord? record,
}) => showTildeSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
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
  builder: (context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .88,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: RecordEditor(
        engine: engine,
        kind: RecordKind.forward,
        record: record,
        hostId: host['id'] as int,
        sessionId: sessionId,
      ),
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final records = engine.list(
        kind == RecordKind.profile ? 'profiles' : 'identities',
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(kind == RecordKind.profile ? '터미널 프로필' : kindTitle(kind)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => edit(context),
          icon: const Icon(Icons.add),
          label: Text('${kindTitle(kind)} 추가'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 104),
          children: [
            if (kind == RecordKind.identity)
              settingsNote(context, '여러 호스트에서 사용자 이름·키·비밀번호를 함께 사용합니다.'),
            if (kind == RecordKind.identity)
              for (final record in records)
                settingsSection(context, '${record['name']}', [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('${record['username']}'),
                    subtitle: Text('${usage(record)}개 호스트에서 사용'),
                    onTap: () => edit(context, record),
                    trailing: TildeItemMenu<String>(
                      onSelected: (value) => action(context, record, value),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('편집')),
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
                  ),
                ]),
            if (kind == RecordKind.profile)
              settingsSection(context, '프로필', [
                for (final record in records)
                  ListTile(
                    leading: kind == RecordKind.profile
                        ? SizedBox(
                            width: 80,
                            height: 52,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
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
                      kind == RecordKind.profile
                          ? '${engine.list('schemes').where((s) => s['id'] == record['colorSchemeId']).firstOrNull?['name'] ?? '색상 테마'} · ${record['fontSize']}${record['id'] == engine.preferences['defaultProfileId'] ? ' · 앱 기본값' : ''}'
                          : '${record['username']}',
                    ),
                    onTap: () => edit(context, record),
                    trailing: TildeItemMenu<String>(
                      onSelected: (value) => action(context, record, value),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('편집')),
                        if (kind == RecordKind.profile) ...[
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('앱 기본값으로 사용'),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Text('복제'),
                          ),
                        ],
                        if (kind != RecordKind.profile ||
                            record['id'] !=
                                engine.preferences['defaultProfileId'])
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('삭제'),
                          ),
                      ],
                    ),
                  ),
              ]),
          ],
        ),
      );
    },
  );
}

class KeyPage extends StatefulWidget {
  final AndroidEngine engine;
  const KeyPage({super.key, required this.engine});
  @override
  State<KeyPage> createState() => _KeyPageState();
}

class _KeyPageState extends State<KeyPage> {
  AndroidEngine get engine => widget.engine;
  bool dialogOpen = false;
  String? seenPending;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) pending();
    });
  }

  Future<void> pending({bool retry = false}) async {
    if (dialogOpen || !mounted) return;
    final state = row(engine.state['keyState']);
    final encrypted = row(state['importPassword']);
    final name = state['pendingNickname'] as String?;
    final id = state['biometricUnlock'] as int?;
    final key = id != null
        ? 'biometric:$id'
        : encrypted.isNotEmpty
        ? 'password:${encrypted['nickname']}'
        : name;
    if (key == null) {
      seenPending = null;
      return;
    }
    if (!retry && key == seenPending) return;
    seenPending = key;
    dialogOpen = true;
    try {
      if (id != null) {
        await runEngine(context, engine, 'key.biometricUnlock', {'id': id});
      } else if (encrypted.isNotEmpty) {
        final password = await askText(
          context,
          '${encrypted['nickname']} 키 암호',
          password: true,
        );
        if (password != null && mounted) {
          await runEngine(context, engine, 'key.importPassword', {
            'nickname': encrypted['nickname'],
            'password': password,
            'encrypt': true,
            'encryptPassword': password,
          });
        } else if (mounted) {
          await runEngine(context, engine, 'key.importCancel');
        }
      } else {
        final nickname = await askText(context, '가져올 키 이름', initial: name!);
        if (mounted) {
          await runEngine(
            context,
            engine,
            nickname == null ? 'key.importCancel' : 'key.importName',
            {'nickname': nickname},
          );
        }
      }
    } finally {
      dialogOpen = false;
    }
  }

  Future<void> keyAction(
    EngineRecord key,
    String action, {
    bool selectFormat = true,
  }) async {
    if (action == 'private' || selectFormat && action == 'export.public') {
      final format = await showTildeSheet<(String, String)>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => KeyExportSheet(
          privateOnly: action == 'private',
          allowPrivate: key['biometric'] != true,
        ),
      );
      if (format != null && mounted) {
        await keyAction(key, '${format.$1}.${format.$2}', selectFormat: false);
      }
      return;
    }
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
    String? password;
    final privateAction = action != 'copy.public' && action != 'export.public';
    if (key['encrypted'] == true &&
        key['loaded'] != true &&
        (action == 'load' || privateAction)) {
      password = await askText(context, '키 암호', password: true);
      if (password == null) return;
    }
    if (!mounted) return;
    if (action == 'load') {
      await runEngine(context, engine, 'key.load', {
        'id': key['id'],
        'password': password,
      });
      return;
    }
    final parts = action.split('.');
    String? exportPassword;
    if (parts.last == 'encrypted') {
      exportPassword = await askText(context, '내보낼 파일 암호', password: true);
      if (exportPassword == null || exportPassword.isEmpty) return;
    }
    if (mounted) {
      await runEngine(context, engine, 'key.${parts.first}', {
        'id': key['id'],
        'format': parts.last,
        'password': password,
        'exportPassword': exportPassword,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = row(engine.state['keyState']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH 키'),
        actions: [
          TildeItemMenu<String>(
            onSelected: (action) async {
              if (action == 'file') {
                await runEngine(context, engine, 'key.import');
              }
              if (action == 'text' && context.mounted) {
                final text = await askText(context, '키 붙여넣기', multiline: true);
                if (text == null || !context.mounted) return;
                final name = await askText(context, '키 이름');
                if (name != null && context.mounted) {
                  await runEngine(context, engine, 'key.import', {
                    'text': text,
                    'nickname': name,
                  });
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'file', child: Text('파일에서 가져오기')),
              PopupMenuItem(value: 'text', child: Text('텍스트에서 가져오기')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTildeSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (c) => SizedBox(
            height: MediaQuery.sizeOf(c).height * .9,
            child: GenerateKeyPage(engine: engine),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('새 키'),
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
          if (state['importPassword'] != null ||
              state['pendingNickname'] != null)
            ListTile(
              title: const Text('키 가져오기 계속'),
              onTap: () => pending(retry: true),
            ),
          settingsSection(context, 'SSH 키', [
            for (final key in engine.list('keys'))
              ListTile(
                leading: Icon(
                  key['loaded'] == true
                      ? Icons.lock_open_outlined
                      : Icons.lock_outline,
                ),
                title: Text('${key['nickname']}'),
                subtitle: Text(
                  '${key['displayType'] ?? key['type']}${key['supported'] == false ? ' · DSA 로그인 미지원' : ''}${key['biometric'] == true
                      ? ' · 생체인증 보호'
                      : key['encrypted'] == true
                      ? ' · 암호 보호'
                      : ''}',
                ),
                onTap: () => keyAction(key, 'edit'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: key['loaded'] == true,
                      onChanged: key['supported'] == false
                          ? null
                          : (_) => keyAction(key, 'load'),
                    ),
                    TildeItemMenu<String>(
                      tooltip: '${key['nickname']} 옵션',
                      onSelected: (action) => keyAction(key, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('편집')),
                        const PopupMenuItem(
                          value: 'copy.public',
                          child: Text('공개키 복사'),
                        ),
                        const PopupMenuItem(
                          value: 'export.public',
                          child: Text('공개키 파일 저장'),
                        ),
                        if (key['biometric'] != true)
                          const PopupMenuItem(
                            value: 'private',
                            child: Text('비밀키 복사·저장'),
                          ),
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
                  ],
                ),
              ),
          ]),
          const SizedBox(height: 96),
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

  Future<void> menu(EngineRecord forward) async {
    final action = await askAction(context, '${forward['nickname']}', [
      ('edit', '편집'),
      ('copy', '복제'),
      ('delete', '삭제'),
    ]);
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
    appBar: AppBar(title: Text('${widget.host['nickname']} · 포워딩')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      icon: const Icon(Icons.add),
      label: const Text('포워딩 추가'),
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 104),
        children: [
          if (sessions.isNotEmpty)
            ListTile(
              title: const Text('제어할 세션'),
              subtitle: Text(
                live
                    ? '${sessions.where((s) => s['id'] == sessionId).first['nickname']}'
                    : '접속 시 기본값',
              ),
              trailing: const Icon(Icons.expand_more),
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
          settingsNote(
            context,
            live ? '스위치는 선택한 세션에만 적용합니다.' : '스위치는 다음 접속 시 자동 활성화 여부입니다.',
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
            ListTile(
              leading: Text(
                switch (f['type']) {
                  'local' => 'L',
                  'remote' => 'R',
                  _ => 'D',
                },
                style: TextStyle(
                  fontFamily: tildeMono,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text('${f['nickname']}'),
              subtitle: Text(
                f['type'] == 'dynamic4'
                    ? 'SOCKS4 미지원 · 편집에서 SOCKS5로 변경하세요'
                    : '${f['sourceAddr']}:${f['sourcePort']} → ${f['type'].toString().startsWith('dynamic') ? 'SOCKS5' : '${f['destAddr']}:${f['destPort']}'}',
                style: const TextStyle(fontFamily: tildeMono, fontSize: 12),
              ),
              onTap: () => edit(f),
              onLongPress: () => menu(f),
              trailing: Switch(
                value:
                    f['type'] != 'dynamic4' &&
                    f[live ? 'enabled' : 'startEnabled'] == true,
                onChanged: f['type'] == 'dynamic4'
                    ? null
                    : (value) async {
                        await runEngine(
                          context,
                          widget.engine,
                          live ? 'forward.toggle' : 'forward.start',
                          live
                              ? {
                                  'hostId': widget.host['id'],
                                  'sessionId': sessionId,
                                  'id': f['id'],
                                  'enabled': value,
                                }
                              : {'id': f['id'], 'enabled': value},
                        );
                        await load();
                      },
              ),
            ),
        ],
      ),
    ),
  );
}

class KnownHostsPage extends StatelessWidget {
  final AndroidEngine engine;
  final int? hostId;
  const KnownHostsPage({super.key, required this.engine, this.hostId});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final groups = <String, List<EngineRecord>>{};
      for (final h
          in engine
              .list('knownHosts')
              .where((h) => hostId == null || h['hostId'] == hostId)) {
        groups.putIfAbsent('${h['hostname']}:${h['port']}', () => []).add(h);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('신뢰한 서버 키')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (groups.isEmpty) settingsNote(context, '신뢰한 서버 키가 없습니다.'),
            for (final group in groups.entries)
              settingsSection(context, group.key, [
                for (final host in group.value)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${host['algorithm']}'),
                        const SizedBox(height: 8),
                        SelectableText(
                          '${host['fingerprint'] ?? ''}',
                          style: const TextStyle(
                            fontFamily: tildeMono,
                            fontSize: 12,
                          ),
                        ),
                        if (host['firstSeenAt'] is num)
                          Text(
                            DateTime.fromMillisecondsSinceEpoch(
                              (host['firstSeenAt'] as num).toInt(),
                            ).toLocal().toString(),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: host['fingerprint'] == null
                                  ? null
                                  : () => Clipboard.setData(
                                      ClipboardData(
                                        text: '${host['fingerprint']}',
                                      ),
                                    ),
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text('복사'),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                              onPressed: () async {
                                final approved = await showTildeSheet<bool>(
                                  context: context,
                                  showDragHandle: true,
                                  builder: (c) => SafeArea(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '서버 키 신뢰 삭제',
                                            style: Theme.of(
                                              c,
                                            ).textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '${group.key}\n이 작업은 되돌릴 수 없습니다. 다음 접속에서 서버 키를 다시 확인합니다.',
                                          ),
                                          const SizedBox(height: 16),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Theme.of(
                                                c,
                                              ).colorScheme.error,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('서버 키 삭제'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                if (approved == true && context.mounted) {
                                  await runEngine(
                                    context,
                                    engine,
                                    'knownHost.delete',
                                    {'id': host['id']},
                                  );
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('삭제'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ]),
          ],
        ),
      );
    },
  );
}

class SchemesPage extends StatelessWidget {
  final AndroidEngine engine;
  const SchemesPage({super.key, required this.engine});
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
        '복사본 이름',
        initial: '${scheme['name']} 복사본',
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
    if (action == 'duplicate' || action == 'rename') {
      final name = await askText(
        context,
        '테마 이름',
        initial: '${scheme['name']}${action == 'duplicate' ? ' 복사' : ''}',
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('색상 테마'),
        actions: [
          TextButton.icon(
            label: const Text('가져오기'),
            icon: const Icon(Icons.file_open_outlined),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await askText(context, '새 테마 이름');
          if (name != null && context.mounted) {
            await runEngine(context, engine, 'scheme.create', {
              'name': name,
              'sourceId': defaultProfile(engine)['colorSchemeId'] ?? -1,
            });
          }
        },
        child: const Icon(Icons.add),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final count = constraints.maxWidth < 360 || scale > 1.4
              ? 1
              : constraints.maxWidth > 900
              ? 3
              : 2;
          final selectedId = defaultProfile(engine)['colorSchemeId'];
          return GridView.count(
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
                Semantics(
                  selected: scheme['id'] == selectedId,
                  child: Card.filled(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: scheme['id'] == selectedId
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: scheme['id'] == selectedId ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      onLongPress: () async {
                        final choice = await askAction(
                          context,
                          '${scheme['name']}',
                          [
                            ('use', '사용'),
                            ('copyEdit', '복제해 편집'),
                            ('export', '내보내기'),
                            if ((scheme['id'] as int) >= 0) ...[
                              ('edit', '편집'),
                              ('delete', '삭제'),
                            ],
                          ],
                        );
                        if (choice != null && context.mounted) {
                          await action(context, scheme, choice);
                        }
                      },
                      onTap: () => runEngine(
                        context,
                        engine,
                        'settings.update',
                        {'key': 'colorScheme', 'value': scheme['id']},
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              color: paletteColor(scheme, 'background'),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    r'~ $ ls',
                                    style: TextStyle(
                                      fontFamily: tildeMono,
                                      fontSize: 12,
                                      color: paletteColor(scheme, 'foreground'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      for (final color
                                          in (scheme['palette'] as List? ?? [])
                                              .skip(1)
                                              .take(4))
                                        Padding(
                                          padding: const EdgeInsets.only(
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
                                                  BorderRadius.circular(7),
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
                                TildeItemMenu<String>(
                                  tooltip: '${scheme['name']} 옵션',
                                  onSelected: (value) =>
                                      action(context, scheme, value),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'use',
                                      child: Text('사용'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'copyEdit',
                                      child: Text('복제해 편집'),
                                    ),
                                    if ((scheme['id'] as int) >= 0)
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('팔레트 편집'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'duplicate',
                                      child: Text('복제'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'export',
                                      child: Text('내보내기'),
                                    ),
                                    if ((scheme['id'] as int) >= 0) ...[
                                      const PopupMenuItem(
                                        value: 'rename',
                                        child: Text('이름 변경'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('삭제'),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
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
    if (value == 'rename') {
      final name = await askText(
        context,
        '테마 이름',
        initial: '${widget.scheme['name']}',
      );
      if (name != null && mounted) {
        await runEngine(context, widget.engine, 'scheme.rename', {
          'id': widget.scheme['id'],
          'name': name,
        });
        if (mounted) Navigator.pop(context);
      }
    } else if (value == 'export') {
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
    } else if (await confirm(context, '테마 삭제', '이 테마를 삭제할까요?', action: '삭제') &&
        mounted) {
      await runEngine(context, widget.engine, 'scheme.delete', {
        'id': widget.scheme['id'],
      });
      if (mounted) Navigator.pop(context);
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
            onSelected: menu,
            itemBuilder: (_) => [
              if (editable)
                const PopupMenuItem(value: 'rename', child: Text('이름 변경')),
              const PopupMenuItem(value: 'export', child: Text('내보내기')),
              if (editable)
                const PopupMenuItem(value: 'delete', child: Text('삭제')),
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
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < colors.length; i++)
                    Semantics(
                      label: 'ANSI $i 색상',
                      button: true,
                      child: InkWell(
                        onTap: editable ? () => editColor(index: i) : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 56,
                          height: 56,
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
          ]),
        ],
      ),
    );
  }
}

class KeyExportSheet extends StatefulWidget {
  final bool privateOnly, allowPrivate;
  const KeyExportSheet({
    super.key,
    required this.privateOnly,
    required this.allowPrivate,
  });
  @override
  State<KeyExportSheet> createState() => _KeyExportSheetState();
}

class _KeyExportSheetState extends State<KeyExportSheet> {
  late String format = widget.privateOnly ? 'openssh' : 'public';
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '키 내보내기',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          tildeSegments(
            context,
            '형식',
            [
              (
                widget.privateOnly ? 'openssh' : 'public',
                widget.privateOnly ? 'OpenSSH 비밀키' : 'OpenSSH 공개키',
              ),
              if (widget.allowPrivate) ...[
                ('pem', 'PEM 비밀키'),
                ('encrypted', '암호화 PEM'),
              ],
            ],
            format,
            (v) => setState(() => format = v as String),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              format == 'public'
                  ? '서버에 등록하는 공개키입니다. 비밀키는 포함하지 않습니다.'
                  : format == 'encrypted'
                  ? '파일을 열 때 필요한 암호를 다음 단계에서 입력합니다.'
                  : '암호 없이 비밀키를 내보냅니다. 파일을 안전하게 보관하세요.',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.privateOnly)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, ('copy', format)),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('복사'),
                ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, ('export', format)),
                icon: const Icon(Icons.save_alt),
                label: const Text('파일로 저장'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
