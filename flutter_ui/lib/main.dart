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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'engine.dart';
import 'platform/ios_platform.dart';
import 'tilde_design.dart';
import 'tilde_controls.dart';
import 'editors.dart';
import 'management.dart';
import 'console.dart';
import 'desktop_workspace.dart';
import 'terminal/session_tabs.dart';
import 'files/file_browser.dart';

void main() => runApp(const AndroidShellApp());

class AndroidShellApp extends StatefulWidget {
  const AndroidShellApp({super.key, this.engine});
  final AndroidEngine? engine;
  @override
  State<AndroidShellApp> createState() => _AndroidShellAppState();
}

class _AndroidShellAppState extends State<AndroidShellApp> {
  late final engine =
      widget.engine ??
      (defaultTargetPlatform == TargetPlatform.iOS
          ? createIosEngine()
          : AndroidEngine());
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          snackBarTheme: Theme.of(context).snackBarTheme.copyWith(
            insetPadding: tildeToastInsets(MediaQuery.sizeOf(context).width),
          ),
        ),
        child: engine.ready ? child! : AppGate(engine: engine),
      ),
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
        retry: method == 'connect'
            ? () async {
                await runEngine(context, engine, method, args);
              }
            : null,
      );
    }
    return null;
  }
}

Future<void> showErrorDetails(
  BuildContext context,
  Object error, {
  String summary = '작업을 완료하지 못했습니다',
  Future<void> Function()? retry,
}) => showTildeSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (c) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(summary, style: Theme.of(c).textTheme.titleLarge),
        const SizedBox(height: 16),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(c).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            error is EngineException
                ? error.details ?? error.message
                : '$error',
            style: const TextStyle(
              fontFamily: tildeMono,
              fontFamilyFallback: tildeMonoFallback,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: error is EngineException
                        ? error.details ?? error.message
                        : '$error',
                  ),
                ),
                icon: const Icon(Icons.content_copy_outlined, size: 18),
                label: const Text('복사'),
              ),
              if (retry != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(c);
                    unawaited(retry());
                  },
                  child: const Text('다시 연결'),
                ),
            ],
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
  Future<void> Function()? retry,
}) {
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: colors.surfaceContainerHighest,
      content: Text(
        summary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.onSurface),
      ),
      action: SnackBarAction(
        label: '자세히',
        textColor: colors.primary,
        onPressed: () =>
            showErrorDetails(context, error, summary: summary, retry: retry),
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

Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  bool password = false,
  bool multiline = false,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  String action = '확인',
  double maxWidth = 440,
  String? hintText,
  bool showPasteAction = false,
}) => showTildeSheet<String>(
  context: context,
  isScrollControlled: true,
  maxWidth: maxWidth,
  builder: (_) => _TextPrompt(
    title: title,
    initial: initial,
    password: password,
    multiline: multiline,
    keyboardType: keyboardType,
    validator: validator,
    action: action,
    hintText: hintText,
    showPasteAction: showPasteAction,
  ),
);

class _TextPrompt extends StatefulWidget {
  final String title, initial, action;
  final bool password, multiline, showPasteAction;
  final String? hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _TextPrompt({
    required this.title,
    required this.initial,
    required this.password,
    required this.multiline,
    required this.keyboardType,
    required this.validator,
    required this.action,
    required this.hintText,
    required this.showPasteAction,
  });
  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  final form = GlobalKey<FormState>();
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (!mounted || text == null) return;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    controller.value = TextEditingValue(
      text: controller.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  void submit() {
    if (form.currentState!.validate()) Navigator.pop(context, controller.text);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter, control: true): submit,
    },
    child: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Form(
              key: form,
              child: TextFormField(
                controller: controller,
                onChanged: widget.multiline ? (_) => setState(() {}) : null,
                onFieldSubmitted: widget.multiline ? null : (_) => submit(),
                keyboardType: widget.keyboardType,
                validator: widget.validator,
                decoration: InputDecoration(hintText: widget.hintText),
                autofocus: true,
                obscureText: widget.password,
                maxLines: widget.multiline ? 8 : 1,
                minLines: widget.multiline ? 3 : 1,
              ),
            ),
            if (widget.multiline)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${controller.text.split('\n').length}줄 · Enter는 줄바꿈, Ctrl Enter는 보내기',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.showPasteAction)
                    TextButton.icon(
                      onPressed: paste,
                      icon: const Icon(Icons.content_paste_outlined, size: 18),
                      label: const Text('붙여넣기'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: () {
                      submit();
                    },
                    child: Text(widget.action),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = '삭제',
  bool destructive = true,
}) async =>
    await showTildeSheet<bool>(
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
                  autofocus: tildePointer(c),
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

bool canConnectHost(EngineRecord host) =>
    host['protocol'] == 'ssh' || host['protocol'] == 'local';

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
  return '${user.isEmpty ? '' : '$user@'}${host['hostname'] ?? ''}$suffix${canConnectHost(host) ? '' : ' · $protocol 미지원'}';
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
  final _quickFocus = FocusNode();
  int? _selectedHostId;
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
    _quickFocus.dispose();
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
    if (tildePointer(context) || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (id != null && id != _intentSession) {
      _intentSession = id;
      final selected = engine
          .list('sessions')
          .where((s) => s['id'] == id)
          .firstOrNull;
      final setup = _setupHostId != null && _setupHostId == selected?['hostId'];
      _setupHostId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
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
    final pending = engine
        .list('prompts')
        .where(
          (p) =>
              p['nativePresentation'] != true &&
              engine.terminalSession(p['sessionId'] as int? ?? -1) == null &&
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
    if (MediaQuery.sizeOf(context).width >= 720) {
      setState(() => _selectedHostId = host['id'] as int);
    }
    if (!canConnectHost(host)) {
      await _hostMenu(host, 'edit');
      return;
    }
    // Native selectedSession is the single owner of navigation after connection.
    await runEngine(context, engine, 'connect', {
      'id': host['id'],
      if (newSession) 'newSession': true,
    });
  }

  Future<void> _page(Widget page) =>
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
      case 'sortColor':
      case 'sortName':
        if ((engine.state['sortedByColor'] == true) !=
            (action == 'sortColor')) {
          await runEngine(context, engine, 'host.sort');
        }
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
      case 'files':
        _page(FileBrowserPage(engine: engine, host: host));
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
          initial: '${host['nickname']} 복사',
          action: '복제',
        );
        if (name != null && mounted) {
          await runEngine(context, engine, 'host.duplicate', {
            'id': host['id'],
            'nickname': name,
          });
        }
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

  Future<void> _showHostMenu(EngineRecord host, [Offset? finger]) async {
    HapticFeedback.selectionClick();
    setState(() => _menuHostId = host['id'] as int);
    final sessions = engine
        .list('sessions')
        .where((s) => s['hostId'] == host['id'])
        .length;
    final selected = await TildeItemMenu.show<String>(
      context,
      title: '${host['nickname']}',
      leading: TildeHostTile(host: host, size: 48),
      position: finger,
      subtitle: '${hostAddress(host)}${sessions > 0 ? ' · 세션 $sessions' : ''}',
      icon: host['protocol'] == 'local' ? Icons.terminal : Icons.dns_outlined,
      itemBuilder: (c) => [
        if (host['protocol'] == 'ssh')
          const PopupMenuItem(
            value: 'files',
            child: TildeMenuLabel('파일 전송 (SFTP)', Icons.folder_outlined),
          ),
        if (canConnectHost(host))
          const PopupMenuItem(
            value: 'newSession',
            child: TildeMenuLabel('새 세션', Icons.add_box_outlined),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: TildeMenuLabel('편집', Icons.edit_outlined),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: TildeMenuLabel(
            '즐겨찾기',
            Icons.star_border,
            selected: host['favorite'] == true,
          ),
        ),
        if (canConnectHost(host))
          const PopupMenuItem(
            value: 'duplicate',
            child: TildeMenuLabel('복제', Icons.content_copy_outlined),
          ),
        if (host['protocol'] == 'ssh')
          const PopupMenuItem(
            value: 'forwards',
            child: Row(
              children: [
                Expanded(child: TildeMenuLabel('포트 포워딩', Icons.swap_horiz)),
                Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        if (sessions > 0) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'disconnect',
            child: TildeMenuLabel('연결 끊기', Icons.link_off_outlined),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: TildeMenuLabel('삭제', Icons.delete_outline, danger: true),
        ),
      ],
    );
    if (mounted) setState(() => _menuHostId = null);
    if (selected != null && mounted) await _hostMenu(host, selected);
  }

  Widget _quickConnectField() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        style: const TextStyle(fontFamily: tildeMono),
        decoration: InputDecoration(
          hintText: 'ssh user@host',
          prefixIcon: const SizedBox(
            width: 56,
            child: Center(
              child: Text(r'~ $', style: TextStyle(fontFamily: tildeMono)),
            ),
          ),
          suffixIcon: IconButton(
            tooltip: '빠른 연결',
            icon: const Icon(Icons.arrow_upward),
            onPressed: () => _quickConnect(_quickUri),
          ),
        ),
        textInputAction: TextInputAction.go,
        onChanged: (v) => _quickUri = v,
        onSubmitted: _quickConnect,
        focusNode: _quickFocus,
      ),
    ),
  );

  Future<void> _selectHost(EngineRecord host) async {
    if (!canConnectHost(host)) {
      await _hostMenu(host, 'edit');
      return;
    }
    if (MediaQuery.sizeOf(context).width >= 720) {
      setState(() => _selectedHostId = host['id'] as int);
      return;
    }
    final choice = await showTildeSheet<(String, int?)>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * .8,
        child: HostSummary(
          engine: engine,
          host: host,
          onConnect: () => Navigator.pop(c, ('connect', null)),
          onFiles: () => Navigator.pop(c, ('files', null)),
          onEdit: () => Navigator.pop(c, ('edit', null)),
          onMenu: (_) => Navigator.pop(c, ('menu', null)),
          onForwards: () async {
            Navigator.pop(c, ('forwards', null));
          },
          onSelectSession: (id) => Navigator.pop(c, ('session', id)),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice.$1) {
      case 'connect':
        await _connect(host, newSession: true);
      case 'session':
        _resumeSession(choice.$2!);
      case 'menu':
        await _showHostMenu(host);
      default:
        await _hostMenu(host, choice.$1);
    }
  }

  void _resumeSession(int id) {
    if (!engine.list('sessions').any((s) => s['id'] == id)) return;
    unawaited(_page(ConsolePage(engine: engine, sessionId: id)));
  }

  Future<void> _openSessions() async {
    final result = await showTildeSessions(context, engine);
    if (!mounted || result == null) return;
    if (result.$2) {
      await closeTildeSession(context, engine, result.$1);
    } else {
      _resumeSession(result.$1);
    }
  }

  Widget _hostList(List<EngineRecord> hosts, bool wide) {
    final sessions = engine.list('sessions');
    bool open(EngineRecord h) =>
        sessions.any((s) => s['hostId'] == h['id'] && s['open'] == true);
    final ordered = [...hosts.where(open), ...hosts.where((h) => !open(h))];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (sessions.isNotEmpty) ...[
          Text('열린 세션', style: Theme.of(context).textTheme.titleMedium),
          SessionList(
            engine: engine,
            onSelect: _resumeSession,
            onClose: (id) => unawaited(closeTildeSession(context, engine, id)),
          ),
          const Divider(height: 32),
        ],
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0 && open(ordered[i - 1]) && !open(ordered[i]))
            const SizedBox(height: 20),
          Builder(
            builder: (c) {
              final host = ordered[i];
              final count = sessions
                  .where((s) => s['hostId'] == host['id'] && s['open'] == true)
                  .length;
              final tileHost = {
                ...host,
                if (host['connectionState'] == null && count > 0)
                  'connectionState': 'CONNECTED',
              };
              return Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPressStart: (details) =>
                          _showHostMenu(host, details.globalPosition),
                      onDoubleTap: null,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: 80,
                        selected:
                            _menuHostId == host['id'] ||
                            wide && _selectedHostId == host['id'],
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        selectedColor: Theme.of(context).colorScheme.onSurface,
                        leading: TildeHostTile(
                          host: tileHost,
                          size: 56,
                          sessionCount: count,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${host['nickname']}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (host['favorite'] == true)
                              Icon(
                                Icons.star,
                                size: 16,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          hostAddress(host),
                          style: TextStyle(
                            fontFamily: host['protocol'] == 'local'
                                ? 'Pretendard'
                                : tildeMono,
                            fontSize: 13,
                          ),
                        ),
                        onTap: () => _selectHost(host),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '${host['nickname']} 메뉴',
                    onPressed: () => _showHostMenu(host),
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!engine.ready) return AppGate(engine: engine);
    if (tildePointer(context)) return DesktopWorkspace(engine: engine);
    final hosts = engine.list('hosts');
    final wide = MediaQuery.sizeOf(context).width >= 720 && hosts.isNotEmpty;
    if (wide && !hosts.any((host) => host['id'] == _selectedHostId)) {
      _selectedHostId = hosts.firstOrNull?['id'] as int?;
    }
    final selected = hosts.where((h) => h['id'] == _selectedHostId).firstOrNull;
    final list = Column(
      children: [
        Expanded(
          child: hosts.isEmpty && engine.list('sessions').isEmpty
              ? TildeWelcome(
                  onAdd: () => _page(
                    RecordEditor(engine: engine, kind: RecordKind.host),
                  ),
                  onQuickConnect: () => _quickFocus.requestFocus(),
                  keyLabel: engine.state['platform'] == 'ios'
                      ? 'SSH 키 가져오기'
                      : '이 기기에 SSH 키 만들기',
                  onKey: () async {
                    if (engine.state['platform'] == 'ios') {
                      await importTildeKeyFile(context, engine);
                    } else if (row(
                          engine.state['generation'],
                        )['biometricAvailable'] ==
                        true) {
                      await showTildeSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => GenerateKeyPage(engine: engine),
                      );
                    } else {
                      await _page(KeyPage(engine: engine));
                    }
                  },
                )
              : _hostList(hosts, wide),
        ),
        _quickConnectField(),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const TildeWordmark(),
        actions: [
          if (engine.list('sessions').isNotEmpty)
            SessionSwitcherButton(
              count: engine.list('sessions').length,
              onPressed: _openSessions,
            ),
          IconButton(
            tooltip: '호스트 추가',
            onPressed: () =>
                _page(RecordEditor(engine: engine, kind: RecordKind.host)),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: '메뉴',
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              final action = await TildeItemMenu.show<String>(
                context,
                title: '',
                icon: Icons.tune,
                itemBuilder: (c) => [
                  const PopupMenuItem(enabled: false, child: Text('정렬')),
                  PopupMenuItem(
                    value: 'sortColor',
                    child: TildeMenuLabel(
                      '색상순',
                      Icons.palette_outlined,
                      selected: engine.state['sortedByColor'] == true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sortName',
                    child: TildeMenuLabel(
                      '이름순',
                      Icons.sort_by_alpha,
                      selected: engine.state['sortedByColor'] != true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'settings',
                    child: TildeMenuLabel('설정', Icons.settings_outlined),
                  ),
                  const PopupMenuItem(
                    value: 'help',
                    child: TildeMenuLabel('도움말', Icons.help_outline),
                  ),
                  const PopupMenuDivider(),
                  if (engine.list('sessions').isNotEmpty)
                    PopupMenuItem(
                      value: 'disconnect',
                      child: const TildeMenuLabel(
                        '연결 모두 끊기',
                        Icons.link_off_outlined,
                      ),
                    ),
                ],
              );
              if (action != null && mounted) await _homeMenu(action);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: wide
                ? (MediaQuery.sizeOf(context).width >= 1000 ? 380 : 320)
                : MediaQuery.sizeOf(context).width,
            child: list,
          ),
          if (wide) ...[
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? const SizedBox.shrink()
                  : HostSummary(
                      engine: engine,
                      host: selected,
                      onConnect: () => _connect(selected, newSession: true),
                      onFiles: () => _page(
                        FileBrowserPage(engine: engine, host: selected),
                      ),
                      onEdit: () => _hostMenu(selected, 'edit'),
                      onMenu: (_) => _showHostMenu(selected),
                      onForwards: () =>
                          _page(ForwardsPage(engine: engine, host: selected)),
                      onSelectSession: (id) =>
                          _page(ConsolePage(engine: engine, sessionId: id)),
                    ),
            ),
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
