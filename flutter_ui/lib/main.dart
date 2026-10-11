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

  ThemeData _theme(Brightness brightness) {
    final colors = row(
      row(engine.state['themeColors'])[brightness == Brightness.dark
          ? 'dark'
          : 'light'],
    );
    Color? color(String key) =>
        colors[key] is num ? Color((colors[key] as num).toInt()) : null;
    return ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xff03a9f4),
            brightness: brightness,
          ).copyWith(
            primary: color('primary'),
            onPrimary: color('onPrimary'),
            primaryContainer: color('primaryContainer'),
            onPrimaryContainer: color('onPrimaryContainer'),
            secondary: color('secondary'),
            onSecondary: color('onSecondary'),
            secondaryContainer: color('secondaryContainer'),
            onSecondaryContainer: color('onSecondaryContainer'),
            tertiary: color('tertiary'),
            onTertiary: color('onTertiary'),
            tertiaryContainer: color('tertiaryContainer'),
            onTertiaryContainer: color('onTertiaryContainer'),
            error: color('error'),
            onError: color('onError'),
            errorContainer: color('errorContainer'),
            onErrorContainer: color('onErrorContainer'),
            surface: color('surface'),
            onSurface: color('onSurface'),
            onSurfaceVariant: color('onSurfaceVariant'),
            outline: color('outline'),
            outlineVariant: color('outlineVariant'),
            inverseSurface: color('inverseSurface'),
            onInverseSurface: color('inverseOnSurface'),
            inversePrimary: color('inversePrimary'),
            surfaceTint: color('surfaceTint'),
            surfaceContainerLowest: color('surfaceContainerLowest'),
            surfaceContainerLow: color('surfaceContainerLow'),
            surfaceContainer: color('surfaceContainer'),
            surfaceContainerHigh: color('surfaceContainerHigh'),
            surfaceContainerHighest: color('surfaceContainerHighest'),
          ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: engine,
    builder: (context, _) => MaterialApp(
      title: 'Android Shell',
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    return null;
  }
}

Future<String?> askAction(
  BuildContext context,
  String title,
  List<(String, String)> actions,
) => showDialog<String>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: [
      for (final (action, label) in actions)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, action),
          child: Text(label),
        ),
    ],
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
  final controller = TextEditingController(text: initial);
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
          controller: controller,
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
              Navigator.pop(context, controller.text);
            }
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = '확인',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
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
  return '$protocol · ${host['hostname'] ?? ''}$suffix';
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
          '${p['instructions'] ?? p['hint'] ?? '인증'}',
          password: p['password'] == true,
        );
      } else if (p['type'] == 'hostKey') {
        value = await confirm(
          context,
          '${p['hostname']} 서버 키 확인',
          '${p['keyType']} ${p['keySize']}\nSHA256: ${p['sha256']}\nMD5: ${p['md5']}\n\n${p['randomArt']}\n${p['bubblebabble']}',
        );
      } else if (p['type'] == 'biometric') {
        value = await confirm(context, '생체인증', '${p['nickname']} 키로 인증해요.');
      } else {
        value = await confirm(
          context,
          '${p['instructions'] ?? '확인'}',
          '${p['message'] ?? ''}',
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

  Future<void> _import() async {
    final uri = await runEngine(context, engine, 'document.pick');
    if (uri == null || !mounted) return;
    final text = await runEngine(context, engine, 'document.read', {
      'uri': uri,
    });
    if (text != null && mounted) {
      final result = await runEngine(context, engine, 'config.import', {
        'text': text,
      });
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(row(result)['message'] as String)),
        );
      }
    }
  }

  Future<void> _export() async {
    final text = await runEngine(context, engine, 'config.export');
    if (text == null || !mounted) return;
    final uri = await runEngine(context, engine, 'document.create', {
      'name': 'android-shell-hosts.json',
    });
    if (uri != null && mounted) {
      await runEngine(context, engine, 'document.write', {
        'uri': uri,
        'text': text,
      });
    }
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
      case 'quick':
        final uri = await askText(context, '빠른 연결', initial: 'ssh://');
        if (uri != null && uri.trim().isNotEmpty && mounted) {
          await runEngine(context, engine, 'connect', {'uri': uri.trim()});
        }
      case 'sort':
        await runEngine(context, engine, 'host.sort');
      case 'settings':
        _page(SettingsPage(engine: engine));
      case 'login':
        _page(LoginPage(engine: engine, onSetup: _setupHost));
      case 'config':
        final selected = await askAction(context, '가져오기·내보내기', [
          ('import', '호스트 가져오기'),
          ('export', '호스트 내보내기'),
        ]);
        if (selected != null && mounted) await _homeMenu(selected);
      case 'export':
        await _export();
      case 'import':
        await _import();
      case 'disconnect':
        if (await confirm(context, '연결 모두 끊기', '모든 연결을 종료할까요?') && mounted) {
          await runEngine(context, engine, 'session.disconnectAll');
        }
      case 'help':
        _page(HelpPage(engine: engine));
    }
  }

  Future<void> _hostMenu(EngineRecord host, String action) async {
    switch (action) {
      case 'more':
        final selected = await askAction(context, '추가 기능', [
          ('forwards', '포트 포워딩'),
          ('duplicate', '복제'),
          ('shortcut', '홈 화면에 추가'),
          if (host['protocol'] == 'ssh') ('forget', '저장된 서버 키 삭제'),
        ]);
        if (selected != null && mounted) await _hostMenu(host, selected);
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
              action: '지우기',
            ) &&
            mounted) {
          await runEngine(context, engine, 'host.forgetKeys', {
            'id': host['id'],
          });
        }
      case 'disconnect':
        if (await confirm(context, '연결 끊기', '${host['nickname']} 연결을 종료할까요?') &&
            mounted) {
          await runEngine(context, engine, 'host.disconnect', {
            'id': host['id'],
          });
        }
      case 'delete':
        if (await confirm(
              context,
              '호스트 삭제',
              '${host['nickname']} 설정과 연결을 삭제할까요?',
            ) &&
            mounted) {
          await runEngine(context, engine, 'host.delete', {'id': host['id']});
        }
    }
  }

  Widget hostMenuLabel(IconData icon, String title) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 24), const SizedBox(width: 12), Text(title)],
  );

  Widget _hostIcon(EngineRecord host) {
    final status = host['connectionState'] ?? 'UNKNOWN';
    final statusColor = switch (status) {
      'CONNECTED' => Colors.green,
      'DISCONNECTED' => Theme.of(context).colorScheme.onSurfaceVariant,
      'UNREAD_OUTPUT' => const Color(0xffb26a00),
      'ERROR' => Theme.of(context).colorScheme.error,
      _ => Colors.transparent,
    };
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color((host['iconArgb'] as int?) ?? 0xff9e9e9e),
              border: Border.all(color: statusColor, width: 3),
            ),
            child: Icon(
              host['protocol'] == 'ssh' || host['protocol'] == 'telnet'
                  ? Icons.computer
                  : Icons.link,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (status != 'UNKNOWN')
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Icon(
                  switch (status) {
                    'CONNECTED' => Icons.check_circle,
                    'DISCONNECTED' => Icons.link_off,
                    'UNREAD_OUTPUT' => Icons.info,
                    _ => Icons.error,
                  },
                  size: 16,
                  color: statusColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!engine.ready) return AppGate(engine: engine);
    final hosts = engine.list('hosts');
    final shortcut =
        engine.state['entryAction'] == 'android.intent.action.CREATE_SHORTCUT';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android Shell'),
        actions: [
          if (!shortcut)
            PopupMenuButton<String>(
              tooltip: '메뉴',
              onSelected: _homeMenu,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'quick', child: Text('빠른 연결')),
                PopupMenuItem(
                  value: 'sort',
                  child: Text(
                    engine.state['sortedByColor'] == true ? '이름순 정렬' : '색상순 정렬',
                  ),
                ),
                const PopupMenuItem(value: 'settings', child: Text('설정')),
                const PopupMenuItem(value: 'login', child: Text('로그인·SSH 키')),
                const PopupMenuItem(value: 'config', child: Text('가져오기·내보내기')),
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
      body: hosts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Text(
                      '서버를 추가하거나 메뉴에서 빠른 연결을 써 보세요.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _page(
                      RecordEditor(engine: engine, kind: RecordKind.host),
                    ),
                    child: const Text('호스트 추가'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 104),
              itemCount: hosts.length,
              itemBuilder: (context, index) {
                final host = hosts[index];
                return Column(
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: _hostIcon(host),
                      title: Row(
                        children: [
                          if (host['favorite'] == true)
                            const Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(Icons.star, size: 18),
                            ),
                          Expanded(
                            child: Text(
                              '${host['nickname']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(hostAddress(host)),
                      onTap: () => _connect(host),
                      trailing: shortcut
                          ? null
                          : PopupMenuButton<String>(
                              tooltip: '${host['nickname']} 옵션',
                              onSelected: (action) => _hostMenu(host, action),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'newSession',
                                  child: hostMenuLabel(
                                    Icons.add_box_outlined,
                                    '새 세션으로 연결',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'favorite',
                                  child: hostMenuLabel(
                                    host['favorite'] == true
                                        ? Icons.star
                                        : Icons.star_border,
                                    host['favorite'] == true
                                        ? '즐겨찾기에서 제거'
                                        : '즐겨찾기 추가',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: hostMenuLabel(Icons.edit, '편집'),
                                ),
                                PopupMenuItem(
                                  value: 'more',
                                  child: hostMenuLabel(
                                    Icons.more_horiz,
                                    '추가 기능',
                                  ),
                                ),
                                if (host['connectionState'] == 'CONNECTED')
                                  PopupMenuItem(
                                    value: 'disconnect',
                                    child: hostMenuLabel(
                                      Icons.link_off,
                                      '연결 끊기',
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: hostMenuLabel(Icons.delete, '삭제'),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class AppGate extends StatelessWidget {
  final AndroidEngine engine;
  const AppGate({super.key, required this.engine});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Android Shell')),
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
            Text('${engine.state['error']}'),
            FilledButton(
              onPressed: () => runEngine(context, engine, 'retryMigration'),
              child: const Text('다시 시도'),
            ),
          ] else
            const CircularProgressIndicator(),
          if (engine.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(engine.error!),
            ),
        ],
      ),
    ),
  );
}
