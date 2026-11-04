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
import 'files/transfer.dart' show fileFailureSummary;
import 'l10n/strings.dart';

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
  final contextStrings = context.l10n;
  try {
    return await engine.invoke(method, args);
  } catch (e) {
    if (context.mounted) {
      showEngineFailure(
        context,
        e,
        summary: method == 'connect'
            ? contextStrings.couldNotConnectTo(
                (engine
                            .list('hosts')
                            .where((h) => h['id'] == args['id'])
                            .firstOrNull?['nickname'] ??
                        contextStrings.server)
                    .toString(),
              )
            : contextStrings.couldNotCompleteOperation,
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
  String? summary,
  String? target,
  explanation,
  DateTime? occurredAt,
  Future<void> Function()? retry,
  VoidCallback? edit,
  Future<void> Function()? saveElsewhere,
}) {
  final resolvedSummary = summary ?? context.l10n.couldNotFinishOperation;
  final details = error is EngineException
      ? error.details ?? error.message
      : '$error';
  final occurred = occurredAt == null
      ? context.l10n.checked((TimeOfDay.now().format(context)).toString())
      : context.l10n.occurred(
          (occurredAt.toLocal().toString().split('.').first).toString(),
        );
  return showTildeSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    maxWidth: 440,
    builder: (c) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(resolvedSummary, style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            explanation ?? fileFailureSummary(error),
            style: Theme.of(c).textTheme.bodyMedium?.copyWith(
              color: Theme.of(c).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(c).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [?target, occurred].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(c).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.copyErrorLog,
                      onPressed: () => Clipboard.setData(
                        ClipboardData(
                          text: '$resolvedSummary\n${target ?? ''}\n$details',
                        ),
                      ),
                      icon: const Icon(Icons.copy_outlined, size: 18),
                    ),
                  ],
                ),
                SelectableText(
                  details,
                  style: TextStyle(
                    fontFamily: tildeMono,
                    fontFamilyFallback: tildeMonoFallback,
                    fontSize: 12.5,
                    color: Theme.of(c).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(context.l10n.close2),
              ),
              if (edit != null)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(c);
                    edit();
                  },
                  child: Text(context.l10n.editHost),
                ),
              if (saveElsewhere != null)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(c);
                    unawaited(saveElsewhere());
                  },
                  child: Text(context.l10n.saveElsewhere),
                ),
              if (retry != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(c);
                    unawaited(retry());
                  },
                  child: Text(context.l10n.retry),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

void showEngineFailure(
  BuildContext context,
  Object error, {
  String? summary,
  Future<void> Function()? retry,
}) {
  summary ??= context.l10n.couldNotCompleteOperation;
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
        label: context.l10n.details,
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
  final contextStrings = context.l10n;
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
          content: Text(
            contextStrings.deletedHost((host['nickname']).toString()),
          ),
          action: SnackBarAction(
            label: contextStrings.undo,
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
  String? action,
  double maxWidth = 440,
  String? hintText,
  bool showPasteAction = false,
  bool hardwareKeyboard = false,
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
    action: action ?? context.l10n.ok,
    hintText: hintText,
    showPasteAction: showPasteAction,
    hardwareKeyboard: hardwareKeyboard,
  ),
);

class _TextPrompt extends StatefulWidget {
  final String title, initial, action;
  final bool password, multiline, showPasteAction, hardwareKeyboard;
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
    required this.hardwareKeyboard,
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
                  context.l10n.linesEnterInsertsANewline(
                    controller.text.split('\n').length,
                    (tildePointer(context) || widget.hardwareKeyboard
                            ? context.l10n.ctrlEnterSends
                            : '')
                        .toString(),
                  ),
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
                      label: Text(context.l10n.paste),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
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
  String? action,
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
                  child: Text(context.l10n.cancel),
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
                  child: Text(action ?? context.l10n.delete),
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
  if (protocol == 'local') return deviceStrings.localShell;
  final port = host['port'];
  final standard = switch (protocol) {
    'ssh' || 'mosh' => 22,
    'telnet' => 23,
    _ => null,
  };
  final suffix = port == null || port == standard ? '' : ':$port';
  final user = '${host['username'] ?? ''}';
  return '${user.isEmpty ? '' : '$user@'}${host['hostname'] ?? ''}$suffix${canConnectHost(host) ? '' : deviceStrings.unsupported((protocol).toString())}';
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
            summary:
                '${notice['summary'] ?? context.l10n.couldNotCompleteOperation}',
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
    final contextStrings = context.l10n;
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
            contextStrings.authentication,
          ].whereType<String>().firstWhere((text) => text.trim().isNotEmpty),
          password: p['password'] == true,
        );
      } else if (p['type'] == 'hostKey') {
        value = await confirm(
          context,
          contextStrings.verifyServerKeyFor((p['hostname']).toString()),
          '${p['keyType']} ${p['keySize']}\nSHA256: ${p['sha256']}\nMD5: ${p['md5']}\n\n${p['randomArt']}\n${p['bubblebabble']}',
          action: contextStrings.trustServerKey,
          destructive: false,
        );
      } else if (p['type'] == 'biometric') {
        value = await confirm(
          context,
          contextStrings.biometricAuthentication,
          contextStrings.authenticateWithKey2((p['nickname']).toString()),
          action: contextStrings.authentication,
          destructive: false,
        );
      } else {
        value = await confirm(
          context,
          '${p['instructions'] ?? contextStrings.ok}',
          '${p['message'] ?? ''}',
          action: contextStrings.continueAction,
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
    final contextStrings = context.l10n;
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
              contextStrings.disconnectAll,
              contextStrings.disconnectAllSessions,
              action: contextStrings.disconnectAll2,
            ) &&
            mounted) {
          await runEngine(context, engine, 'session.disconnectAll');
        }
      case 'help':
        _page(HelpPage(engine: engine));
    }
  }

  Future<void> _hostMenu(EngineRecord host, String action) async {
    final contextStrings = context.l10n;
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
          contextStrings.nameForDuplicateHost,
          initial: contextStrings.copy((host['nickname']).toString()),
          action: contextStrings.duplicate,
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
              contextStrings.removeServerKey,
              contextStrings.theServerKeyWillBeVerifiedAgainOnThe,
              action: contextStrings.deleteServerKey,
            ) &&
            mounted) {
          await runEngine(context, engine, 'host.forgetKeys', {
            'id': host['id'],
          });
        }
      case 'disconnect':
        if (await confirm(
              context,
              contextStrings.disconnect,
              contextStrings.disconnectFrom((host['nickname']).toString()),
              action: contextStrings.disconnect,
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
    final contextStrings = context.l10n;
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
      subtitle:
          '${hostAddress(host)}${sessions > 0 ? contextStrings.sessions((sessions).toString()) : ''}',
      icon: host['protocol'] == 'local' ? Icons.terminal : Icons.dns_outlined,
      itemBuilder: (c) => [
        if (host['protocol'] == 'ssh')
          PopupMenuItem(
            value: 'files',
            child: TildeMenuLabel(
              contextStrings.fileTransferSftp,
              Icons.folder_outlined,
            ),
          ),
        if (canConnectHost(host))
          PopupMenuItem(
            value: 'newSession',
            child: TildeMenuLabel(
              contextStrings.newTerminal,
              Icons.add_box_outlined,
            ),
          ),
        PopupMenuItem(
          value: 'edit',
          child: TildeMenuLabel(contextStrings.edit2, Icons.edit_outlined),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: TildeMenuLabel(
            contextStrings.favorites,
            Icons.star_border,
            selected: host['favorite'] == true,
          ),
        ),
        if (canConnectHost(host))
          PopupMenuItem(
            value: 'duplicate',
            child: TildeMenuLabel(
              contextStrings.duplicate,
              Icons.content_copy_outlined,
            ),
          ),
        if (host['protocol'] == 'ssh')
          PopupMenuItem(
            value: 'forwards',
            child: Row(
              children: [
                Expanded(
                  child: TildeMenuLabel(
                    contextStrings.portForwarding,
                    Icons.swap_horiz,
                  ),
                ),
                Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        if (sessions > 0) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'disconnect',
            child: TildeMenuLabel(
              contextStrings.disconnect,
              Icons.link_off_outlined,
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: TildeMenuLabel(
            contextStrings.delete,
            Icons.delete_outline,
            danger: true,
          ),
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
            tooltip: context.l10n.quickConnect,
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
          Text(
            context.l10n.openSessions,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                        subtitle: tildePathText(
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
                    tooltip: context.l10n.menu((host['nickname']).toString()),
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
                      ? context.l10n.importSshKey
                      : context.l10n.createSshKeyOnThisDevice,
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
            tooltip: context.l10n.addHost,
            onPressed: () =>
                _page(RecordEditor(engine: engine, kind: RecordKind.host)),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: context.l10n.menu2,
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              final contextStrings = context.l10n;
              final action = await TildeItemMenu.show<String>(
                context,
                title: '',
                icon: Icons.tune,
                itemBuilder: (c) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(contextStrings.sort),
                  ),
                  PopupMenuItem(
                    value: 'sortColor',
                    child: TildeMenuLabel(
                      contextStrings.byColor,
                      Icons.palette_outlined,
                      selected: engine.state['sortedByColor'] == true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sortName',
                    child: TildeMenuLabel(
                      contextStrings.byName,
                      Icons.sort_by_alpha,
                      selected: engine.state['sortedByColor'] != true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'settings',
                    child: TildeMenuLabel(
                      contextStrings.settings,
                      Icons.settings_outlined,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'help',
                    child: TildeMenuLabel(
                      contextStrings.help,
                      Icons.help_outline,
                    ),
                  ),
                  const PopupMenuDivider(),
                  if (engine.list('sessions').isNotEmpty)
                    PopupMenuItem(
                      value: 'disconnect',
                      child: TildeMenuLabel(
                        contextStrings.disconnectAll,
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
              child: Text(context.l10n.unlock),
            )
          else if (engine.state['error'] != null) ...[
            Text(context.l10n.couldNotPrepareAppData),
            TextButton(
              onPressed: () =>
                  showErrorDetails(context, '${engine.state['error']}'),
              child: Text(context.l10n.details),
            ),
            FilledButton(
              onPressed: () => runEngine(context, engine, 'retryMigration'),
              child: Text(context.l10n.retry),
            ),
          ] else
            Padding(
              padding: EdgeInsets.all(32),
              child: TildeProgress(label: context.l10n.preparingTilde),
            ),
          if (engine.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => showErrorDetails(context, engine.error!),
                child: Text(context.l10n.errorDetails),
              ),
            ),
        ],
      ),
    ),
  );
}
