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
import 'package:flutter/services.dart';
import 'engine.dart';
import 'tilde_design.dart';
import 'editors.dart';
import 'management.dart';
import 'console.dart';

void main() => runApp(const AndroidShellApp());

class AndroidShellApp extends StatefulWidget {
  const AndroidShellApp({super.key});
  @override
  State<AndroidShellApp> createState() => _AndroidShellAppState();
}

class _AndroidShellAppState extends State<AndroidShellApp> {
  final engine = AndroidEngine();
  @override
  void initState() {
    super.initState();
    unawaited(engine.start());
  }

  @override
  void dispose() {
    engine.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) => tildeTheme(brightness, engine);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) => MaterialApp(
      title: 'Tilde',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      builder: (context, child) =>
          engine.ready ? child! : AppGate(engine: engine),
      themeMode: switch (engine.preferences['themeMode']) {
        'LIGHT' => ThemeMode.light,
        'DARK' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: ShellHome(engine: engine),
    ),
  );
}

Future<dynamic> runEngine(
  BuildContext context,
  AndroidEngine engine,
  String method, [
  EngineRecord args = const {},
]) async {
  try {
    return await engine.invoke(method, args);
  } catch (e) {
    if (context.mounted) {
      showEngineFailure(
        context,
        e,
        summary: method == 'connect'
            ? '${engine.list('hosts').where((h) => h['id'] == args['id']).firstOrNull?['nickname'] ?? '서버'}에 연결하지 못했습니다'
            : '작업을 완료하지 못했습니다',
      );
    }
    return null;
  }
}

Future<void> showErrorDetails(BuildContext context, Object error) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('오류 상세', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 16),
            SelectableText(
              error is EngineException
                  ? error.details ?? error.message
                  : '$error',
              style: const TextStyle(
                fontFamily: tildeMono,
                fontFamilyFallback: ['Pretendard'],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );

void showEngineFailure(
  BuildContext context,
  Object error, {
  String summary = '작업을 완료하지 못했습니다',
}) {
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: colors.inverseSurface,
      content: Text(
        summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onInverseSurface),
      ),
      action: SnackBarAction(
        label: '자세히',
        textColor: colors.inversePrimary,
        onPressed: () => showErrorDetails(context, error),
      ),
    ),
  );
}

Future<bool> deleteTildeHost(
  BuildContext context,
  AndroidEngine engine,
  EngineRecord host, {
  VoidCallback? onDeleted,
}) async {
  final token = await runEngine(context, engine, 'host.delete', {
    'id': host['id'],
    'undo': true,
  });
  if (token == null) return false;
  if (!context.mounted) {
    if (!engine.isDisposed) {
      await engine.query('host.deleteFinish', {'token': token});
    }
    return true;
  }
  final actionContext = Navigator.of(context).context;
  Future<dynamic>? restore;
  final closed = ScaffoldMessenger.of(context)
      .showSnackBar(
        SnackBar(
          content: Text('${host['nickname']} 호스트를 삭제했습니다'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () {
              restore = runEngine(actionContext, engine, 'host.restore', {
                'token': token,
              });
            },
          ),
        ),
      )
      .closed;
  onDeleted?.call();
  await closed;
  await restore;
  if (!engine.isDisposed) {
    await engine.query('host.deleteFinish', {'token': token});
  }
  return true;
}

Future<void> importTildeHosts(
  BuildContext context,
  AndroidEngine engine,
) async {
  final uri = await runEngine(context, engine, 'document.pick');
  if (uri == null || !context.mounted) return;
  final text = await runEngine(context, engine, 'document.read', {'uri': uri});
  if (text == null || !context.mounted) return;
  final result = await runEngine(context, engine, 'config.import', {
    'text': text,
  });
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${row(result)['message']}')));
  }
}

Future<void> exportTildeHosts(
  BuildContext context,
  AndroidEngine engine,
) async {
  final text = await runEngine(context, engine, 'config.export');
  if (text == null || !context.mounted) return;
  final uri = await runEngine(context, engine, 'document.create', {
    'name': 'tilde-hosts.json',
  });
  if (uri != null && context.mounted) {
    await runEngine(context, engine, 'document.write', {
      'uri': uri,
      'text': text,
    });
  }
}

Future<String?> askAction(
  BuildContext context,
  String title,
  List<(String, String)> actions,
) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final (action, label) in actions)
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(context, action),
              ),
          ],
        ),
      ),
    ),
  ),
);

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  bool password = false,
  bool multiline = false,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) async {
  var value = initial;
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: TextFormField(
          keyboardType: keyboardType,
          validator: validator,
          initialValue: initial,
          onChanged: (text) => value = text,
          autofocus: true,
          obscureText: password,
          maxLines: multiline ? 8 : 1,
          minLines: multiline ? 3 : 1,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, value);
            }
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
  return result;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = '삭제',
  bool destructive = true,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: Theme.of(c).colorScheme.error,
                        )
                      : null,
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(action),
                ),
              ],
            ),
          ],
        ),
      ),
    ) ??
    false;

String hostAddress(EngineRecord host) {
  final protocol = '${host['protocol'] ?? ''}';
  if (protocol == 'local') return '로컬 셸';
  final port = host['port'];
  final standard = switch (protocol) {
    'ssh' || 'mosh' => 22,
    'telnet' => 23,
    _ => null,
  };
  final suffix = port == null || port == standard ? '' : ':$port';
  final user = '${host['username'] ?? ''}';
  return '${user.isEmpty ? '' : '$user@'}${host['hostname'] ?? ''}$suffix';
}

class ShellHome extends StatefulWidget {
  final AndroidEngine engine;
  const ShellHome({super.key, required this.engine});
  @override
  State<ShellHome> createState() => _ShellHomeState();
}

class _ShellHomeState extends State<ShellHome> {
  AndroidEngine get engine => widget.engine;
  bool _promptOpen = false;
  final Set<String> _answered = {};
  int? _setupHostId;
  int? _intentSession;
  int? _menuHostId;
  String _quickUri = '';
  void _quickConnect(String value) {
    if (value.trim().isNotEmpty) {
      runEngine(context, engine, 'connect', {'uri': value.trim()});
    }
  }

  @override
  void initState() {
    super.initState();
    engine.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _changed();
    });
  }

  @override
  void dispose() {
    engine.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final notice = engine.notification;
    if (notice != null) {
      engine.notification = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showEngineFailure(
            context,
            EngineException('${notice['message']}'),
            summary: '${notice['summary'] ?? '작업을 완료하지 못했습니다'}',
          );
        }
      });
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentPrompt();
    });
    final id = engine.state['selectedSession'] as int?;
    if (id == null) _intentSession = null;
    if (id != null && id != _intentSession) {
      _intentSession = id;
      final selected = engine
          .list('sessions')
          .where((s) => s['id'] == id)
          .firstOrNull;
      final setup = _setupHostId != null && _setupHostId == selected?['hostId'];
      _setupHostId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ConsolePage(
                engine: engine,
                sessionId: id,
                startKeySetup: setup,
              ),
            ),
          );
          unawaited(engine.invoke('session.consumeSelection'));
        }
      });
    }
  }

  Future<void> _presentPrompt() async {
    if (_promptOpen || !engine.ready || !mounted) return;
    if (engine.list('prompts').isEmpty &&
        engine.list('startupKeys').isNotEmpty) {
      final key = engine.list('startupKeys').first;
      _promptOpen = true;
      try {
        final password = await askText(
          context,
          '${key['nickname']} 키 암호',
          password: true,
        );
        if (mounted) {
          await runEngine(context, engine, 'key.startup', {
            'id': key['id'],
            'password': password,
            'cancel': password == null,
          });
        }
      } finally {
        _promptOpen = false;
      }
      if (mounted) unawaited(_presentPrompt());
      return;
    }
    final pending = engine
        .list('prompts')
        .where(
          (p) =>
              p['nativePresentation'] != true &&
              !_answered.contains(p['token']),
        )
        .toList();
    if (pending.isEmpty) return;
    final p = pending.first;
    _promptOpen = true;
    dynamic value;
    try {
      if (p['type'] == 'string') {
        value = await askText(
          context,
          [
            p['instructions'],
            p['hint'],
            '인증',
          ].whereType<String>().firstWhere((text) => text.trim().isNotEmpty),
          password: p['password'] == true,
        );
      } else if (p['type'] == 'hostKey') {
        value = await confirm(
          context,
          '${p['hostname']} 서버 키 확인',
          '${p['keyType']} ${p['keySize']}\nSHA256: ${p['sha256']}\nMD5: ${p['md5']}\n\n${p['randomArt']}\n${p['bubblebabble']}',
          action: '서버 키 신뢰',
          destructive: false,
        );
      } else if (p['type'] == 'biometric') {
        value = await confirm(
          context,
          '생체인증',
          '${p['nickname']} 키로 인증해요.',
          action: '인증',
          destructive: false,
        );
      } else {
        value = await confirm(
          context,
          '${p['instructions'] ?? '확인'}',
          '${p['message'] ?? ''}',
          action: '계속',
          destructive: false,
        );
      }
      _answered.add(p['token'] as String);
      if (mounted) {
        await runEngine(context, engine, 'prompt.respond', {
          'sessionId': p['sessionId'],
          'token': p['token'],
          'value': value,
        });
      }
    } finally {
      _promptOpen = false;
      if (mounted) unawaited(_presentPrompt());
    }
  }

  Future<void> _connect(EngineRecord host, {bool newSession = false}) async {
    if (engine.state['entryAction'] ==
        'android.intent.action.CREATE_SHORTCUT') {
      await runEngine(context, engine, 'shortcut', {
        'id': host['id'],
        'color': host['color'],
      });
      return;
    }
    // Native selectedSession is the single owner of navigation after connection.
    await runEngine(context, engine, 'connect', {
      'id': host['id'],
      if (newSession) 'newSession': true,
    });
  }

  void _page(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  Future<void> _setupHost(EngineRecord host) async {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _setupHostId = host['id'] as int;
    final connected = await runEngine(context, engine, 'connect', {
      'id': host['id'],
    });
    if (connected == null) _setupHostId = null;
  }

  Future<void> _homeMenu(String action) async {
    switch (action) {
      case 'sort':
        await runEngine(context, engine, 'host.sort');
      case 'settings':
        await engine.refresh();
        if (mounted) _page(SettingsPage(engine: engine));
      case 'disconnect':
        if (await confirm(
              context,
              '연결 모두 끊기',
              '모든 연결을 종료할까요?',
              action: '모두 연결 끊기',
            ) &&
            mounted) {
          await runEngine(context, engine, 'session.disconnectAll');
        }
      case 'help':
        _page(HelpPage(engine: engine));
    }
  }

  Future<void> _hostMenu(EngineRecord host, String action) async {
    switch (action) {
      case 'newSession':
        await _connect(host, newSession: true);
      case 'favorite':
        await runEngine(context, engine, 'host.favorite', {'id': host['id']});
      case 'edit':
        _page(
          RecordEditor(
            engine: engine,
            kind: RecordKind.host,
            record: host,
            onSetup: _setupHost,
          ),
        );
      case 'forwards':
        _page(ForwardsPage(engine: engine, host: host));
      case 'duplicate':
        final name = await askText(
          context,
          '복제할 호스트 이름',
          initial: '${host['nickname']} copy',
        );
        if (name != null && mounted) {
          await runEngine(context, engine, 'host.duplicate', {
            'id': host['id'],
            'nickname': name,
          });
        }
      case 'shortcut':
        await runEngine(context, engine, 'shortcut', {
          'id': host['id'],
          'color': host['color'],
        });
      case 'forget':
        if (await confirm(
              context,
              '서버 키를 지울까요?',
              '다음에 연결할 때 서버 키를 다시 확인해요.',
              action: '서버 키 삭제',
            ) &&
            mounted) {
          await runEngine(context, engine, 'host.forgetKeys', {
            'id': host['id'],
          });
        }
      case 'disconnect':
        if (await confirm(
              context,
              '연결 끊기',
              '${host['nickname']} 연결을 종료할까요?',
              action: '연결 끊기',
            ) &&
            mounted) {
          await runEngine(context, engine, 'host.disconnect', {
            'id': host['id'],
          });
        }
      case 'delete':
        await deleteTildeHost(context, engine, host);
    }
  }

  Future<void> _showHostMenu(EngineRecord host, Offset finger) async {
    HapticFeedback.selectionClick();
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final point = overlay.globalToLocal(finger);
    setState(() => _menuHostId = host['id'] as int);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(point.dx, point.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${host['nickname']}'),
              Text(
                hostAddress(host),
                style: const TextStyle(fontFamily: tildeMono, fontSize: 12),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'newSession', child: Text('새 세션으로 연결')),
        const PopupMenuItem(value: 'edit', child: Text('편집')),
        const PopupMenuItem(value: 'duplicate', child: Text('복제')),
        PopupMenuItem(
          value: 'favorite',
          child: Text(host['favorite'] == true ? '즐겨찾기에서 제거' : '즐겨찾기 추가'),
        ),
        const PopupMenuDivider(),
        if (host['protocol'] == 'ssh')
          const PopupMenuItem(value: 'forwards', child: Text('포트 포워딩')),
        const PopupMenuItem(value: 'shortcut', child: Text('홈 화면에 추가')),
        if (host['protocol'] == 'ssh')
          const PopupMenuItem(value: 'forget', child: Text('저장된 서버 키 삭제')),
        const PopupMenuDivider(),
        if (engine.list('sessions').any((s) => s['hostId'] == host['id']))
          const PopupMenuItem(value: 'disconnect', child: Text('연결 끊기')),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            '삭제',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
    if (mounted) setState(() => _menuHostId = null);
    if (selected != null && mounted) await _hostMenu(host, selected);
  }

  Widget _hostIcon(EngineRecord host) => TildeHostTile(host: host);

  @override
  Widget build(BuildContext context) {
    if (!engine.ready) return AppGate(engine: engine);
    final hosts = engine.list('hosts');
    final shortcut =
        engine.state['entryAction'] == 'android.intent.action.CREATE_SHORTCUT';
    return Scaffold(
      appBar: AppBar(
        title: const TildeWordmark(),
        actions: [
          if (!shortcut)
            PopupMenuButton<String>(
              tooltip: '메뉴',
              onSelected: _homeMenu,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'sort',
                  child: Text(
                    engine.state['sortedByColor'] == true ? '이름순 정렬' : '색상순 정렬',
                  ),
                ),
                const PopupMenuItem(value: 'settings', child: Text('설정')),
                const PopupMenuItem(
                  value: 'disconnect',
                  child: Text('연결 모두 끊기'),
                ),
                const PopupMenuItem(value: 'help', child: Text('도움말')),
              ],
            ),
        ],
      ),
      floatingActionButton: shortcut
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: FloatingActionButton(
                tooltip: '호스트 추가',
                onPressed: () =>
                    _page(RecordEditor(engine: engine, kind: RecordKind.host)),
                child: const Icon(Icons.add),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
        children: [
          if (!shortcut)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'user@host · 빠른 연결',
                  prefixIcon: const Icon(Icons.terminal),
                  suffixIcon: IconButton(
                    tooltip: '빠른 연결',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _quickConnect(_quickUri),
                  ),
                ),
                textInputAction: TextInputAction.go,
                onChanged: (v) => _quickUri = v,
                onSubmitted: _quickConnect,
              ),
            ),
          if (hosts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '저장된 호스트가 없어요',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => _page(
                      RecordEditor(engine: engine, kind: RecordKind.host),
                    ),
                    child: const Text('호스트 추가'),
                  ),
                ],
              ),
            ),
          for (final group in ['연결됨', '전체']) ...[
            if (hosts.any(
              (h) =>
                  (engine
                      .list('sessions')
                      .any(
                        (s) => s['hostId'] == h['id'] && s['open'] == true,
                      )) ==
                  (group == '연결됨'),
            )) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  group,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Card.filled(
                margin: const EdgeInsets.only(bottom: 20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final host in hosts.where(
                      (h) =>
                          engine
                              .list('sessions')
                              .any(
                                (s) =>
                                    s['hostId'] == h['id'] && s['open'] == true,
                              ) ==
                          (group == '연결됨'),
                    ))
                      Builder(
                        builder: (tileContext) {
                          final count = engine
                              .list('sessions')
                              .where(
                                (s) =>
                                    s['hostId'] == host['id'] &&
                                    s['open'] == true,
                              )
                              .length;
                          return GestureDetector(
                            onLongPressStart: shortcut
                                ? null
                                : (details) => _showHostMenu(
                                    host,
                                    details.globalPosition,
                                  ),
                            child: ListTile(
                              selected: _menuHostId == host['id'],
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              leading: _hostIcon(host),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${host['nickname']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (host['favorite'] == true)
                                    const Icon(Icons.star, size: 16),
                                ],
                              ),
                              subtitle: Text(
                                hostAddress(host),
                                style: const TextStyle(
                                  fontFamily: tildeMono,
                                  fontSize: 12.5,
                                ),
                              ),
                              trailing: count > 0
                                  ? Text(
                                      '세션 $count',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                    )
                                  : null,
                              onTap: () => _connect(host),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class AppGate extends StatelessWidget {
  final AndroidEngine engine;
  const AppGate({super.key, required this.engine});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const TildeWordmark()),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (engine.state['authenticated'] == false)
            FilledButton(
              onPressed: () => runEngine(context, engine, 'authenticateApp'),
              child: const Text('잠금 해제'),
            )
          else if (engine.state['error'] != null) ...[
            const Text('앱 데이터를 준비하지 못했습니다'),
            TextButton(
              onPressed: () =>
                  showErrorDetails(context, '${engine.state['error']}'),
              child: const Text('자세히'),
            ),
            FilledButton(
              onPressed: () => runEngine(context, engine, 'retryMigration'),
              child: const Text('다시 시도'),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(32),
              child: TildeProgress(label: 'Tilde 준비 중'),
            ),
          if (engine.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => showErrorDetails(context, engine.error!),
                child: const Text('오류 자세히'),
              ),
            ),
        ],
      ),
    ),
  );
}
