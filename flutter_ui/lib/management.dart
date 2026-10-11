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
import 'editors.dart';
import 'settings_widgets.dart';
import 'main.dart';
export 'automation.dart';
export 'settings.dart';

class RecordListPage extends StatelessWidget {
  final AndroidEngine engine;
  final RecordKind kind;
  const RecordListPage({super.key, required this.engine, required this.kind});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) {
      final records = engine.list(
        kind == RecordKind.profile ? 'profiles' : 'identities',
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(kindTitle(kind)),
          actions: [
            if (kind == RecordKind.profile)
              IconButton(
                tooltip: '색상 관리',
                icon: const Icon(Icons.palette_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SchemesPage(engine: engine),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => kind == RecordKind.identity
              ? showDialog<void>(
                  context: context,
                  builder: (_) => RecordEditor(engine: engine, kind: kind),
                )
              : Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RecordEditor(engine: engine, kind: kind),
                  ),
                ),
          child: const Icon(Icons.add),
        ),
        body: ListView(
          children: [
            if (kind == RecordKind.identity)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '사용자 이름·키·비밀번호를 여러 서버에서 함께 써요. 호스트 편집에서 사용할 인증정보를 고르면 돼요.',
                ),
              ),
            for (final record in records)
              ListTile(
                title: Text('${record['name']}'),
                subtitle: Text(
                  kind == RecordKind.profile
                      ? '${record['encoding']} · ${record['emulation']} · ${record['fontSize']}sp'
                      : '${record['username']}',
                ),
                onTap: () => kind == RecordKind.identity
                    ? showDialog<void>(
                        context: context,
                        builder: (_) => RecordEditor(
                          engine: engine,
                          kind: kind,
                          record: record,
                        ),
                      )
                    : Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => RecordEditor(
                            engine: engine,
                            kind: kind,
                            record: record,
                          ),
                        ),
                      ),
                trailing: kind == RecordKind.identity
                    ? IconButton(
                        tooltip: '삭제',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirm(
                                context,
                                '삭제',
                                '${record['name']} 인증정보를 삭제할까요? 호스트와 현재 사용자 이름·키는 남지만 공용 비밀번호는 삭제돼요.',
                              ) &&
                              context.mounted) {
                            await runEngine(
                              context,
                              engine,
                              'identity.delete',
                              {'id': record['id']},
                            );
                          }
                        },
                      )
                    : PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'duplicate') {
                            final name = await askText(
                              context,
                              '복제할 이름',
                              initial: '${record['name']} copy',
                            );
                            if (name != null && context.mounted) {
                              await runEngine(
                                context,
                                engine,
                                'profile.duplicate',
                                {'id': record['id'], 'name': name},
                              );
                            }
                          }
                          if (action == 'delete' &&
                              context.mounted &&
                              await confirm(
                                context,
                                '삭제',
                                '${record['name']} 항목을 삭제할까요?',
                              ) &&
                              context.mounted) {
                            await runEngine(
                              context,
                              engine,
                              '${kind.name}.delete',
                              {'id': record['id']},
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          if (kind == RecordKind.profile)
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Text('복제'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('삭제'),
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
          final encrypt = await confirm(
            context,
            '저장 암호',
            '가져온 키를 별도의 암호로 보호할까요?',
          );
          String? newPassword;
          if (encrypt && mounted) {
            newPassword = await askText(context, '새 저장 암호', password: true);
          }
          if (mounted && (!encrypt || newPassword != null)) {
            await runEngine(context, engine, 'key.importPassword', {
              'nickname': encrypted['nickname'],
              'password': password,
              'encrypt': encrypt,
              'encryptPassword': newPassword,
            });
          }
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

  Future<void> keyAction(EngineRecord key, String action) async {
    if (action == 'private') {
      final operation = await askAction(context, '비밀키', [
        ('copy', '복사'),
        ('export', '파일로 저장'),
      ]);
      if (operation == null || !mounted) return;
      final format = await askAction(context, '비밀키 형식', [
        ('openssh', 'OpenSSH'),
        ('pem', 'PEM'),
        ('encrypted', '암호화된 PEM'),
      ]);
      if (format != null && mounted) await keyAction(key, '$operation.$format');
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
      if (await confirm(context, '키 삭제', '${key['nickname']} 키를 삭제할까요?') &&
          mounted) {
        await runEngine(context, engine, 'key.delete', {'id': key['id']});
      }
      return;
    }
    String? password;
    final privateAction = action != 'copy.public' && action != 'export.public';
    if (key['encrypted'] == true &&
        ((action == 'load' && key['loaded'] != true) ||
            privateAction && action != 'load')) {
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
          PopupMenuButton<String>(
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => GenerateKeyPage(engine: engine),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          if (state['error'] != null || state['nicknameError'] != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${state['error'] ?? state['nicknameError']}'),
            ),
          if (state['importPassword'] != null ||
              state['pendingNickname'] != null)
            ListTile(
              title: const Text('키 가져오기 계속'),
              onTap: () => pending(retry: true),
            ),
          for (final key in engine.list('keys'))
            ListTile(
              leading: Icon(
                key['biometric'] == true ? Icons.fingerprint : Icons.key,
              ),
              title: Text('${key['nickname']}'),
              subtitle: Text(
                '${key['type']} · ${key['loaded'] == true ? '사용 중' : '잠김'}${key['encrypted'] == true ? ' · 암호화' : ''}',
              ),
              onTap: () => keyAction(key, 'load'),
              trailing: PopupMenuButton<String>(
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
            ),
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class ForwardsPage extends StatefulWidget {
  final AndroidEngine engine;
  final EngineRecord host;
  const ForwardsPage({super.key, required this.engine, required this.host});
  @override
  State<ForwardsPage> createState() => _ForwardsPageState();
}

class _ForwardsPageState extends State<ForwardsPage> {
  List<EngineRecord> forwards = [];
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.engine.addListener(changed);
    unawaited(load());
  }

  @override
  void dispose() {
    widget.engine.removeListener(changed);
    super.dispose();
  }

  void changed() {
    unawaited(load());
  }

  Future<void> load() async {
    if (loading || !mounted) return;
    loading = true;
    try {
      final records = rows(
        await widget.engine.query('forwards', {'hostId': widget.host['id']}),
      );
      if (mounted) {
        setState(() {
          forwards = records;
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
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RecordEditor(
          engine: widget.engine,
          kind: RecordKind.forward,
          record: record,
          hostId: widget.host['id'] as int,
        ),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.host['nickname']} · 포워딩')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => edit(),
      child: const Icon(Icons.add),
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        children: [
          if (error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
          for (final forward in forwards)
            ListTile(
              title: Text('${forward['nickname']}'),
              subtitle: Text(
                '${forward['type']} · ${forward['sourceAddr']}:${forward['sourcePort']} → ${forward['destAddr'] ?? 'SOCKS'}:${forward['destPort']}',
              ),
              onTap: () => edit(forward),
              leading: Switch(
                value: forward['enabled'] == true,
                onChanged: (value) async {
                  await runEngine(context, widget.engine, 'forward.toggle', {
                    'hostId': widget.host['id'],
                    'id': forward['id'],
                    'enabled': value,
                  });
                  await load();
                },
              ),
              trailing: IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(
                        context,
                        '포워딩 삭제',
                        '${forward['nickname']} 포워딩을 삭제할까요?',
                      ) &&
                      context.mounted) {
                    await runEngine(context, widget.engine, 'forward.delete', {
                      'id': forward['id'],
                    });
                    await load();
                  }
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
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('신뢰한 서버 키')),
      body: ListView(
        children: [
          for (final host
              in engine
                  .list('knownHosts')
                  .where((host) => hostId == null || host['hostId'] == hostId))
            ListTile(
              title: Text('${host['hostname']}:${host['port']}'),
              subtitle: Text('${host['algorithm']}'),
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('${host['hostname']}'),
                  content: SelectableText(
                    '${host['algorithm']}\n${host['key']}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              ),
              trailing: IconButton(
                tooltip: '신뢰 삭제',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await confirm(
                        context,
                        '신뢰 삭제',
                        '다음에 연결할 때 서버 키를 다시 확인해요.',
                        action: '지우기',
                      ) &&
                      context.mounted) {
                    await runEngine(context, engine, 'knownHost.delete', {
                      'id': host['id'],
                    });
                  }
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class SchemesPage extends StatelessWidget {
  final AndroidEngine engine;
  const SchemesPage({super.key, required this.engine});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('색상 테마'),
        actions: [
          IconButton(
            tooltip: '테마 가져오기',
            icon: const Icon(Icons.file_open),
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
            await runEngine(context, engine, 'scheme.create', {'name': name});
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
              for (final scheme in engine.list('schemes'))
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
                                      fontFamily: 'monospace',
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
                                PopupMenuButton<String>(
                                  tooltip: '${scheme['name']} 옵션',
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => PalettePage(
                                            engine: engine,
                                            scheme: scheme,
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (action == 'duplicate' ||
                                        action == 'rename') {
                                      final name = await askText(
                                        context,
                                        '테마 이름',
                                        initial:
                                            '${scheme['name']}${action == 'duplicate' ? ' copy' : ''}',
                                      );
                                      if (name != null && context.mounted) {
                                        await runEngine(
                                          context,
                                          engine,
                                          'scheme.$action',
                                          {'id': scheme['id'], 'name': name},
                                        );
                                      }
                                    }
                                    if (action == 'delete' &&
                                        context.mounted &&
                                        await confirm(
                                          context,
                                          '테마 삭제',
                                          '${scheme['name']} 테마를 삭제할까요?',
                                        ) &&
                                        context.mounted) {
                                      await runEngine(
                                        context,
                                        engine,
                                        'scheme.delete',
                                        {'id': scheme['id']},
                                      );
                                    }
                                    if (action == 'export' && context.mounted) {
                                      final text = await runEngine(
                                        context,
                                        engine,
                                        'scheme.export',
                                        {'id': scheme['id']},
                                      );
                                      if (text == null || !context.mounted) {
                                        return;
                                      }
                                      final uri = await runEngine(
                                        context,
                                        engine,
                                        'document.create',
                                        {'name': '${scheme['name']}.json'},
                                      );
                                      if (uri != null && context.mounted) {
                                        await runEngine(
                                          context,
                                          engine,
                                          'document.write',
                                          {'uri': uri, 'text': text},
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => [
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

  @override
  Widget build(BuildContext context) {
    final editable = (widget.scheme['id'] as int) >= 0;
    final colors = (palette['colors'] as List? ?? []).cast<int>();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.scheme['name']}'),
        actions: [
          if (editable)
            IconButton(
              tooltip: '팔레트 초기화',
              icon: const Icon(Icons.restore),
              onPressed: () async {
                if (await confirm(context, '색상 초기화', '팔레트를 초기화할까요?') &&
                    context.mounted) {
                  await runEngine(context, widget.engine, 'scheme.reset', {
                    'id': widget.scheme['id'],
                  });
                  await load();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null) Text(error!),
          if (!editable) const Text('기본 테마를 수정하려면 먼저 복제해 주세요.'),
          for (final field in ['foreground', 'background'])
            DropdownButtonFormField<int>(
              key: ValueKey('$field:${palette[field]}'),
              initialValue: palette[field] as int?,
              decoration: InputDecoration(
                labelText: field == 'foreground' ? '기본 글자 색상' : '기본 배경 색상',
              ),
              items: [
                for (var i = 0; i < colors.length; i++)
                  DropdownMenuItem(value: i, child: Text('색상 $i')),
              ],
              onChanged: !editable
                  ? null
                  : (value) async {
                      await runEngine(
                        context,
                        widget.engine,
                        'scheme.defaults',
                        {
                          'id': widget.scheme['id'],
                          'foreground': field == 'foreground'
                              ? value
                              : palette['foreground'],
                          'background': field == 'background'
                              ? value
                              : palette['background'],
                        },
                      );
                      await load();
                    },
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < colors.length; i++)
                InkWell(
                  onTap: !editable
                      ? null
                      : () async {
                          final hex = await askText(
                            context,
                            '색상 $i · RGB',
                            initial: (colors[i] & 0xffffff)
                                .toRadixString(16)
                                .padLeft(6, '0'),
                          );
                          if (hex == null || !context.mounted) return;
                          final value = int.tryParse(
                            hex.replaceFirst('#', ''),
                            radix: 16,
                          );
                          if (value == null || value < 0 || value > 0xffffff) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('RGB 색상을 입력해 주세요.')),
                            );
                            return;
                          }
                          await runEngine(
                            context,
                            widget.engine,
                            'scheme.color',
                            {
                              'id': widget.scheme['id'],
                              'index': i,
                              'color': 0xff000000 | value,
                            },
                          );
                          await load();
                        },
                  child: Container(
                    width: 64,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Color(0xff000000 | colors[i]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$i',
                      style: TextStyle(
                        color:
                            ThemeData.estimateBrightnessForColor(
                                  Color(0xff000000 | colors[i]),
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  final AndroidEngine engine;
  final Future<void> Function(EngineRecord host) onSetup;
  const LoginPage({super.key, required this.engine, required this.onSetup});

  Future<void> chooseServer(BuildContext context) async {
    final hosts = engine
        .list('hosts')
        .where((h) => h['protocol'] == 'ssh' && (h['id'] as int) > 0)
        .toList();
    final host = await showDialog<EngineRecord>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('등록할 SSH 서버'),
        content: hosts.isEmpty
            ? const Text(
                '먼저 SSH 호스트를 저장해 주세요. Mosh는 같은 서버의 SSH 호스트에서 키를 등록해 주세요.',
              )
            : SizedBox(
                width: 400,
                height: 300,
                child: ListView(
                  children: [
                    for (final host in hosts)
                      ListTile(
                        title: Text('${host['nickname']}'),
                        subtitle: Text(
                          '${host['username']}@${host['hostname']}:${host['port']}',
                        ),
                        onTap: () => Navigator.pop(context, host),
                      ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
    if (host != null && context.mounted) await onSetup(host);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('로그인·SSH 키')),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        card(
          '지문 로그인 설정',
          '먼저 기존 방식으로 로그인한 뒤 공개키를 등록하고 키 로그인을 확인해요.',
          Icons.fingerprint,
          () => chooseServer(context),
        ),
        card(
          'SSH 키 관리',
          '키 생성·가져오기, 공개키 복사, 보호 옵션을 관리해요.',
          Icons.key_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => KeyPage(engine: engine)),
          ),
        ),
        card(
          '공용 로그인 계정',
          '여러 서버에서 같은 사용자 이름과 로그인 설정을 함께 써요.',
          Icons.people_outline,
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  RecordListPage(engine: engine, kind: RecordKind.identity),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '지문 키는 내보내기·다른 폰으로 복원이 불가능해요. 기존 Mac 키나 다른 로그인 수단을 유지해 주세요. 지문 등록을 변경하면 키를 다시 만들어야 할 수 있어요.',
          ),
        ),
      ],
    ),
  );
  Widget card(
    String title,
    String summary,
    IconData icon,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(summary),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    ),
  );
}
