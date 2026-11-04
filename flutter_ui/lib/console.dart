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
import 'files/file_browser.dart';
import 'tilde_controls.dart';
import 'tilde_design.dart';
import 'connection_status.dart';
import 'editors.dart';
import 'settings_widgets.dart';
import 'main.dart';
import 'management.dart';
import 'package:xterm2/xterm.dart';
import 'terminal/terminal_pane.dart';
import 'terminal/terminal_prompt.dart';
import 'terminal/session_tabs.dart';
import 'l10n/strings.dart';

class ConsolePage extends StatefulWidget {
  final AndroidEngine engine;
  final int sessionId;
  final bool startKeySetup;
  final bool embedded, active;
  final ValueChanged<int>? onSelectSession;
  final VoidCallback? onGoHome, onKeySetupOpened;
  final Future<void> Function()? onClose;
  final KeyEventResult Function(FocusNode, KeyEvent)? onWorkspaceKey;
  const ConsolePage({
    super.key,
    required this.engine,
    required this.sessionId,
    this.startKeySetup = false,
    this.embedded = false,
    this.active = true,
    this.onSelectSession,
    this.onGoHome,
    this.onKeySetupOpened,
    this.onClose,
    this.onWorkspaceKey,
  });
  @override
  ConsolePageState createState() => ConsolePageState();
}

class ConsolePageState extends State<ConsolePage> {
  late int id;
  final Map<String, Future<String>> terminalFonts = {};
  GlobalKey<TerminalPaneState> terminalKey = GlobalKey<TerminalPaneState>();
  BuildContext? consoleContext;
  BuildContext get actionsContext => consoleContext ?? context;
  EngineRecord connectionTarget = {};
  void rememberSession() {
    final current = session;
    if (current.isNotEmpty) connectionTarget = current;
  }

  final routeOwner = UniqueKey().toString();
  bool? visible;
  bool setupOpened = false;
  Timer? titleTimer;
  bool titleHidden = false;
  bool _tabSwitchPressed = false;
  bool get _desktop => tildePointer(context);

  KeyEventResult _sessionKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.embedded) {
      return widget.onWorkspaceKey?.call(node, event) ?? KeyEventResult.ignored;
    }
    if (!_desktop || event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    if (event is KeyUpEvent && _tabSwitchPressed) {
      _tabSwitchPressed = false;
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyUpEvent ||
        !keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    _tabSwitchPressed = true;
    final tabs = engine.list('sessions');
    if (tabs.isNotEmpty) {
      final current = tabs.indexWhere((tab) => tab['id'] == id);
      final next = (current + (keyboard.isShiftPressed ? -1 : 1)) % tabs.length;
      select(tabs[next]['id'] as int);
    }
    return KeyEventResult.handled;
  }

  void interaction() {
    titleTimer?.cancel();
    if (mounted && titleHidden) setState(() => titleHidden = false);
    if (engine.preferences['titlebarhide'] == true) {
      titleTimer = Timer(
        Duration(
          milliseconds: (engine.state['autoHideDelayMs'] as int?) ?? 3000,
        ),
        () {
          if (mounted) setState(() => titleHidden = true);
        },
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = widget.embedded
        ? widget.active
        : ModalRoute.of(context)?.isCurrent == true;
    if (visible != current) {
      visible = current;
      engine.query('session.visibility', {
        'id': id,
        'owner': routeOwner,
        'visible': current,
      });
      if (!widget.embedded &&
          current &&
          engine.state['selectedSession'] != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) changed();
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ConsolePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionId != oldWidget.sessionId) {
      setupOpened = false;
      select(widget.sessionId);
    }
    if (widget.startKeySetup && !oldWidget.startKeySetup) {
      setupOpened = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) changed();
      });
    }
    if (widget.active != oldWidget.active) {
      if (!widget.active) engine.terminalSession(id)?.input.finishComposition();
      visible = widget.active;
      unawaited(
        engine.query('session.visibility', {
          'id': id,
          'owner': routeOwner,
          'visible': widget.active,
        }),
      );
    }
  }

  void select(int target) {
    if (target == id) return;
    engine.terminalSession(id)?.input.finishComposition();
    setState(() {
      id = target;
      terminalKey = GlobalKey<TerminalPaneState>();
    });
    widget.onSelectSession?.call(target);
    rememberSession();
    engine.query('session.visibility', {
      'id': id,
      'owner': routeOwner,
      'visible': visible == true,
    });
  }

  AndroidEngine get engine => widget.engine;
  @override
  void initState() {
    super.initState();
    id = widget.sessionId;
    rememberSession();
    interaction();
    engine.addListener(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) changed();
    });
  }

  @override
  void dispose() {
    titleTimer?.cancel();
    engine.removeListener(changed);
    engine.query('session.visibility', {
      'id': id,
      'owner': routeOwner,
      'visible': false,
    });
    super.dispose();
  }

  void changed() {
    if (!mounted) return;
    final selected = engine.state['selectedSession'] as int?;
    if (!widget.embedded && visible == true && selected != null) {
      select(selected);
      unawaited(engine.invoke('session.consumeSelection'));
    }
    rememberSession();
    if (widget.startKeySetup && !setupOpened && session['canEnroll'] == true) {
      setupOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onKeySetupOpened?.call();
          menu('enroll');
        }
      });
    }
    final input = engine.textInput;
    if (input?['owner'] == routeOwner) {
      engine.textInput = null;
      final target = engine.terminalSession(id);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final contextStrings = context.l10n;
        if (!mounted || target?.sessionOpen != true) return;
        final text = await askText(
          actionsContext,
          contextStrings.sendTo(
            (session['nickname'] ?? contextStrings.terminal).toString(),
          ),
          action: contextStrings.send2,
          maxWidth: 640,
          initial: '${input?['text'] ?? ''}',
          multiline: true,
        );
        await WidgetsBinding.instance.endOfFrame;
        if (text != null &&
            mounted &&
            target?.sessionOpen == true &&
            engine.terminalSession(id) == target) {
          target!.input.paste(text);
        }
      });
    }
    final request = engine.sessionSwitch;
    if (request?['owner'] == routeOwner && request?['id'] != id) {
      engine.sessionSwitch = null;
      select(request!['id'] as int);
    } else {
      setState(() {});
    }
  }

  EngineRecord get session =>
      engine.list('sessions').where((s) => s['id'] == id).firstOrNull ?? {};
  Future<dynamic> command(String method, [EngineRecord args = const {}]) =>
      runEngine(actionsContext, engine, method, {'id': id, ...args});
  bool leaving = false;
  bool closingTab = false;

  Future<void> closeTab(int targetId) async {
    final contextStrings = context.l10n;
    if (closingTab || leaving) return;
    final target = engine
        .list('sessions')
        .where((record) => record['id'] == targetId)
        .firstOrNull;
    if (target == null) return;
    closingTab = true;
    try {
      if (!await closeTildeSession(actionsContext, engine, targetId)) return;
      if (!mounted || id != targetId) return;
      final remaining = engine
          .list('sessions')
          .where((record) => record['id'] != targetId)
          .toList();
      if (remaining.isEmpty) {
        await leave();
      } else {
        select(remaining.first['id'] as int);
      }
    } catch (error) {
      if (mounted) {
        showEngineFailure(
          actionsContext,
          error,
          summary: contextStrings.couldNotCloseConnection,
        );
      }
    } finally {
      closingTab = false;
    }
  }

  Future<void> requestLeave() => leave();

  Future<void> openSessions() async {
    final result = await showTildeSessions(
      actionsContext,
      engine,
      selectedId: id,
    );
    if (!mounted || result == null) return;
    if (result.$2) {
      await closeTab(result.$1);
    } else if (engine.list('sessions').any((s) => s['id'] == result.$1)) {
      select(result.$1);
    }
  }

  Future<void> leave({bool disconnect = false}) async {
    final contextStrings = context.l10n;
    if (widget.embedded) {
      if (disconnect) {
        await widget.onClose?.call();
      } else {
        widget.onGoHome?.call();
      }
      return;
    }
    if (leaving) return;
    leaving = true;
    try {
      if (disconnect && session.isNotEmpty) {
        await engine.invoke('session.disconnect', {'id': id});
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      leaving = false;
      if (mounted) {
        showEngineFailure(
          actionsContext,
          error,
          summary: contextStrings.couldNotCloseConnection,
        );
      }
    }
  }

  Future<void> menu(String action) async {
    final contextStrings = context.l10n;
    if ([
      'keyboard',
      'select',
      'selectAll',
      'selectVisible',
      'copy',
      'clearSelection',
      'paste',
      'selectionMode',
      'selectionUp',
      'selectionDown',
      'selectionLeft',
      'selectionRight',
    ].contains(action)) {
      await terminalKey.currentState?.viewAction(action);
      return;
    }
    if (action == 'files') {
      final host = engine
          .list('hosts')
          .where((h) => h['id'] == session['hostId'])
          .firstOrNull;
      if (host != null) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => FileBrowserPage(engine: engine, host: host),
          ),
        );
      }
      return;
    }
    if (action == 'display') {
      await showTildeSheet<void>(
        context: actionsContext,
        builder: (c) => StatefulBuilder(
          builder: (c, refresh) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  contextStrings.display,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (session['open'] == true)
                ListTile(
                  leading: const Icon(Icons.aspect_ratio),
                  title: Text(contextStrings.terminalSize),
                  subtitle: Text(
                    '${session['columns'] ?? contextStrings.columns}×${session['rows'] ?? contextStrings.rows}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(c);
                    menu('resize');
                  },
                ),
              for (final option in [
                ('fullscreen', contextStrings.fullScreen, Icons.fullscreen),
                (
                  'titlebarhide',
                  contextStrings.autoHideTitleBar,
                  Icons.vertical_align_top,
                ),
              ])
                SwitchListTile(
                  secondary: Icon(option.$3),
                  title: Text(option.$2),
                  value: engine.preferences[option.$1] == true,
                  onChanged: (_) async {
                    await selectMenuAction(option.$1);
                    if (c.mounted) refresh(() {});
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
      return;
    }
    if (action == 'resize') {
      final targetId = id;
      final size = await askText(
        actionsContext,
        contextStrings.terminalSizeColumnsRows,
        action: contextStrings.resize,
        initial: '',
        hintText: contextStrings.text8024LeaveBlankForAutomaticSizing,
      );
      if (size == null || !mounted) return;
      final parts = size.trim().toLowerCase().replaceAll('×', 'x').split('x');
      if (size.trim().isNotEmpty &&
          (parts.length != 2 ||
              int.tryParse(parts.first.trim()) == null ||
              int.tryParse(parts.last.trim()) == null ||
              (int.tryParse(parts.first.trim()) ?? 0) <= 0 ||
              (int.tryParse(parts.last.trim()) ?? 0) <= 0)) {
        ScaffoldMessenger.of(actionsContext).showSnackBar(
          SnackBar(content: Text(contextStrings.enterColumnsRowsSuchAs8024)),
        );
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || id != targetId) return;
      terminalKey.currentState?.resize(
        rows: size.trim().isEmpty ? null : int.parse(parts.last.trim()),
        columns: size.trim().isEmpty ? null : int.parse(parts.first.trim()),
      );
      return;
    }
    if (action == 'fontUp' || action == 'fontDown') {
      await command('session.font', {'increase': action == 'fontUp'});
      return;
    }
    if (action == 'text') {
      final target = engine.terminalSession(id);
      if (target?.sessionOpen != true) return;
      if (!mounted) return;
      final text = await askText(
        actionsContext,
        contextStrings.sendTo(
          (session['nickname'] ?? contextStrings.terminal).toString(),
        ),
        action: contextStrings.send2,
        maxWidth: 640,
        multiline: true,
        showPasteAction: true,
        hardwareKeyboard: engine.state['hardwareKeyboard'] == true,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (text != null &&
          mounted &&
          target?.sessionOpen == true &&
          engine.terminalSession(id) == target) {
        target!.input.paste(text);
      }
      return;
    }
    if (action == 'disconnect') {
      await leave(disconnect: true);
      return;
    }
    if (action == 'reconnect') {
      if (engine.terminalSession(id) != null) {
        await command('session.reconnect');
        return;
      }
      final hostId = connectionTarget['hostId'];
      final uri = connectionTarget['uri'];
      if (hostId is int && hostId > 0) {
        await runEngine(actionsContext, engine, 'connect', {'id': hostId});
      } else if (uri is String) {
        await runEngine(actionsContext, engine, 'connect', {'uri': uri});
      }
      return;
    }
    if (action == 'urls') {
      final urls = await command('session.urls') as List? ?? [];
      if (mounted) {
        await showTildeSheet<void>(
          context: actionsContext,
          isScrollControlled: true,
          maxWidth: 560,
          builder: (c) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    contextStrings.terminalLinks,
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (urls.isEmpty) Text(contextStrings.noLinksOnScreen),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final url in urls)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '$url',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: tildeMono,
                                fontFamilyFallback: tildeMonoFallback,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => Clipboard.setData(
                                    ClipboardData(text: '$url'),
                                  ),
                                  child: Text(contextStrings.copy2),
                                ),
                                TextButton(
                                  onPressed: () => runEngine(
                                    actionsContext,
                                    engine,
                                    'openUrl',
                                    {'url': url},
                                  ),
                                  child: Text(contextStrings.open),
                                ),
                              ],
                            ),
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
      return;
    }
    final host = engine
        .list('hosts')
        .where((h) => h['id'] == connectionTarget['hostId'])
        .firstOrNull;
    if (host == null || !mounted) return;
    if (action == 'forwards') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              ForwardsPage(engine: engine, host: host, sessionId: id),
        ),
      );
    }
    if (action == 'enroll' && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              EnrollmentPage(engine: engine, host: host, sessionId: id),
        ),
      );
    }
  }

  Future<void> selectMenuAction(String action) async {
    interaction();
    if (action == 'fullscreen' || action == 'titlebarhide') {
      await command('settings.update', {
        'key': action,
        'value': engine.preferences[action] != true,
      });
      interaction();
    } else if (action == 'newSession') {
      await leave();
    } else {
      await menu(action);
    }
  }

  Widget consoleMenu(BuildContext c, VoidCallback close, {bool side = false}) {
    final connected = session['open'] == true;
    final host =
        engine
            .list('hosts')
            .where((h) => h['id'] == session['hostId'])
            .firstOrNull ??
        session;
    void action(String value) {
      if (!side) {
        Navigator.pop(c, value);
        return;
      }
      close();
      unawaited(selectMenuAction(value));
    }

    Widget entry(
      String value,
      String label,
      IconData icon, {
      String? subtitle,
      bool enabled = true,
      bool navigates = false,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: Icon(icon, size: 22),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: navigates ? const Icon(Icons.chevron_right) : null,
      onTap: enabled ? () => action(value) : null,
    );
    return Material(
      color: Theme.of(c).colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, side ? 20 : 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: TildeHostTile(host: host, size: 48),
                title: Text(
                  '${session['nickname'] ?? c.l10n.terminal}',
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                trailing: side
                    ? IconButton(
                        tooltip: c.l10n.close2,
                        icon: const Icon(Icons.close),
                        onPressed: close,
                      )
                    : null,
              ),
              const Divider(),
              if (connected) ...[
                entry('paste', c.l10n.paste, Icons.content_paste_outlined),
                entry('text', c.l10n.enterText, Icons.edit_note_outlined),
              ],
              if (connected) const Divider(),
              entry('urls', c.l10n.links, Icons.link_outlined),
              entry(
                'display',
                c.l10n.display,
                Icons.display_settings_outlined,
                navigates: true,
              ),
              const Divider(),
              if (session['hostId'] != null)
                entry(
                  'files',
                  c.l10n.fileTransfer,
                  Icons.folder_outlined,
                  navigates: true,
                ),
              if (connected && session['canForward'] == true)
                entry(
                  'forwards',
                  c.l10n.portForwarding,
                  Icons.swap_horiz,
                  navigates: true,
                ),
              if (session['canEnroll'] == true)
                entry(
                  'enroll',
                  c.l10n.registerKeyOnThisServer,
                  Icons.key_outlined,
                  navigates: true,
                ),
              if (!leaving && !connected && session['connecting'] != true)
                entry('reconnect', c.l10n.reconnect, Icons.refresh),
              entry(
                'newSession',
                c.l10n.newTerminal,
                Icons.add_box_outlined,
                enabled:
                    connectionTarget['hostId'] != null ||
                    connectionTarget['uri'] != null,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
              entry(
                'disconnect',
                connected ? c.l10n.disconnect : c.l10n.close2,
                connected ? Icons.link_off_outlined : Icons.close,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openMenu(BuildContext anchor) async {
    final anchorStrings = anchor.l10n;
    titleTimer?.cancel();
    final targetId = id;
    final connected = session['open'] == true;
    final String? action;
    if (tildePointer(anchor)) {
      action = await TildeItemMenu.show<String>(
        anchor,
        title: '',
        icon: Icons.terminal_outlined,
        itemBuilder: (_) => [
          if (connected) ...[
            PopupMenuItem(
              value: 'paste',
              child: TildeMenuLabel(
                anchorStrings.paste,
                Icons.content_paste_outlined,
                shortcut: 'Ctrl Shift V',
              ),
            ),
            PopupMenuItem(
              value: 'text',
              child: TildeMenuLabel(
                anchorStrings.enterText,
                Icons.edit_note_outlined,
              ),
            ),
            const PopupMenuDivider(),
          ],
          PopupMenuItem(
            value: 'urls',
            child: TildeMenuLabel(anchorStrings.links, Icons.link_outlined),
          ),
          PopupMenuItem(
            value: 'display',
            child: TildeMenuLabel(
              anchorStrings.display,
              Icons.display_settings_outlined,
            ),
          ),
          if (session['hostId'] != null)
            PopupMenuItem(
              value: 'files',
              child: TildeMenuLabel(
                anchorStrings.fileTransfer,
                Icons.folder_outlined,
              ),
            ),
          PopupMenuItem(
            value: 'fullscreen',
            child: TildeMenuLabel(
              anchorStrings.fullScreen,
              Icons.fullscreen,
              shortcut: 'F11',
            ),
          ),
          const PopupMenuDivider(),
          if (connected && session['canForward'] == true)
            PopupMenuItem(
              value: 'forwards',
              child: TildeMenuLabel(
                anchorStrings.portForwarding,
                Icons.swap_horiz,
              ),
            ),
          if (session['canEnroll'] == true)
            PopupMenuItem(
              value: 'enroll',
              child: TildeMenuLabel(
                anchorStrings.registerKeyOnThisServer,
                Icons.key_outlined,
              ),
            ),
          if (!connected && session['connecting'] != true)
            PopupMenuItem(
              value: 'reconnect',
              child: TildeMenuLabel(anchorStrings.reconnect, Icons.refresh),
            ),
          PopupMenuItem(
            value: 'newSession',
            child: TildeMenuLabel(
              anchorStrings.newTerminal,
              Icons.add_box_outlined,
              shortcut: 'Ctrl Shift T',
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'disconnect',
            child: TildeMenuLabel(
              connected ? anchorStrings.disconnect : anchorStrings.close2,
              connected ? Icons.link_off_outlined : Icons.close,
            ),
          ),
        ],
      );
    } else {
      action = await showTildeSheet<String>(
        context: actionsContext,
        isScrollControlled: true,
        builder: (c) => ListenableBuilder(
          listenable: engine,
          builder: (_, _) => consoleMenu(c, () => Navigator.pop(c)),
        ),
      );
    }
    if (!mounted) return;
    interaction();
    if (action != null && id == targetId) {
      await engine.query('session.visibility', {
        'id': id,
        'owner': routeOwner,
        'visible': !widget.embedded || widget.active,
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted &&
          id == targetId &&
          (widget.embedded
              ? widget.active
              : ModalRoute.of(context)?.isCurrent == true)) {
        await selectMenuAction(action);
      }
    }
  }

  Widget popup() => Builder(
    builder: (anchor) => IconButton(
      tooltip: context.l10n.terminalMenu,
      icon: const Icon(Icons.more_horiz),
      onPressed: () => openMenu(anchor),
    ),
  );

  Widget _loginPrompt(EngineRecord prompt) => TerminalPromptSurface(
    key: ValueKey((id, prompt['token'])),
    prompt: {
      'nickname': session['nickname'],
      'address':
          session['uri'] ??
          hostAddress(
            engine
                    .list('hosts')
                    .where((h) => h['id'] == session['hostId'])
                    .firstOrNull ??
                session,
          ),
      ...prompt,
    },
    enabled: visible == true,
    onResponse: (value) async {
      await runEngine(actionsContext, engine, 'prompt.respond', {
        'sessionId': prompt['sessionId'],
        'token': prompt['token'],
        'value': value,
      });
    },
  );

  Widget _connectionStatus(EngineRecord? prompt) {
    final phase = session['connectionPhase'] as String? ?? 'server';
    final failed =
        row(session['progress'])['state'] == 'ERROR' ||
        session['ended'] == true;
    final title = failed
        ? switch (phase) {
            'hostKey' => context.l10n.couldNotVerifyServerKey,
            'authentication' => context.l10n.couldNotLogIn,
            'ready' => context.l10n.couldNotOpenTerminal,
            _ => context.l10n.couldNotConnectToServer,
          }
        : context.l10n.connectingTo2(
            (session['nickname'] ?? context.l10n.server).toString(),
          );
    final host = engine
        .list('hosts')
        .where((host) => host['id'] == session['hostId'])
        .firstOrNull;
    final details = [
      ...?session['connectionLog'] as List?,
      if (row(session['progress'])['message'] != null)
        row(session['progress'])['message'],
    ].join('\n');
    return ConnectionStatusView(
      record: session,
      title: title,
      address:
          session['connectionHost'] as String? ??
          session['uri'] as String? ??
          '',
      finalStage: context.l10n.openTerminal,
      failed: failed,
      failureHint: failed
          ? switch (phase) {
              'hostKey' =>
                context.l10n.checkTheSavedServerKeyAndTheFingerprintProvided,
              'authentication' =>
                context.l10n.checkYourUsernameAndCredentialsIfUsingAnSsh,
              _ => context.l10n.checkTheServerAddressPortAndNetworkConnection,
            }
          : null,
      prompt: prompt == null ? null : _loginPrompt(prompt),
      actions: [
        if (failed || tildePointer(context))
          TextButton(
            onPressed: () => showErrorDetails(
              actionsContext,
              details,
              summary: failed
                  ? context.l10n.couldNotConnectTo(
                      (session['nickname'] ?? context.l10n.server).toString(),
                    )
                  : context.l10n.connectionLog,
              target: session['uri'] as String?,
              explanation: session['failureSummary'] as String?,
              occurredAt: DateTime.tryParse('${session['failedAt']}'),
              edit: host == null
                  ? null
                  : () => Navigator.push<void>(
                      actionsContext,
                      MaterialPageRoute(
                        builder: (_) => RecordEditor(
                          engine: engine,
                          kind: RecordKind.host,
                          record: host,
                        ),
                      ),
                    ),
              retry: failed ? () => menu('reconnect') : null,
            ),
            child: Text(
              failed ? context.l10n.details : context.l10n.connectionLog,
            ),
          ),
        if (failed && host != null)
          OutlinedButton(
            onPressed: () => Navigator.push<void>(
              actionsContext,
              MaterialPageRoute(
                builder: (_) => RecordEditor(
                  engine: engine,
                  kind: RecordKind.host,
                  record: host,
                ),
              ),
            ),
            child: Text(context.l10n.editHost),
          ),
        if (failed)
          FilledButton(
            onPressed: () => menu('reconnect'),
            child: Text(context.l10n.retry),
          )
        else
          TextButton(
            onPressed: () => leave(disconnect: true),
            child: Text(context.l10n.cancel),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = engine.preferences;
    final commonSession = engine.terminalSession(id);
    final prompt = engine
        .list('prompts')
        .where((p) => p['sessionId'] == id)
        .firstOrNull;
    final storedFont =
        commonSession?.profile['fontFamily'] as String? ??
        prefs['fontFamily'] as String? ??
        'D2CODING';
    final scheme = session.containsKey('backgroundColor')
        ? session
        : {
            'backgroundColor': tildeNightBackground.toARGB32(),
            'foregroundColor': 0xffeae9e7,
            'cursorColor': tildeTide.toARGB32(),
          };
    final background = Color((scheme['backgroundColor'] as num).toInt());
    final dark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    final baseTheme = tildeTheme(
      dark ? Brightness.dark : Brightness.light,
      engine,
      terminalScheme: scheme,
    );
    final theme = baseTheme.copyWith(
      snackBarTheme: baseTheme.snackBarTheme.copyWith(
        insetPadding: tildeToastInsets(MediaQuery.sizeOf(context).width),
      ),
    );
    final overlays = SystemUiOverlayStyle(
      statusBarColor: background,
      systemNavigationBarColor: background,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    );
    final ended = session['ended'] == true;
    final progress = row(session['progress']);
    final progressVisible =
        progress.isNotEmpty && progress['state'] != 'HIDDEN';
    final showProgress = session['connecting'] == true || progressVisible;
    final connectionLog = session['connectionLog'] as List?;
    final showConnection = connectionLog != null;
    final desktop = _desktop;
    final tabs =
        desktop || MediaQuery.sizeOf(context).width >= sessionTabsMinWidth;
    final showTitle = !widget.embedded;
    final toolbarHeight = showTitle
        ? (desktop ? 48.0 : sessionTabsHeight)
        : 0.0;
    final contentTop = toolbarHeight;
    final content = Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          consoleContext = context;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlays,
            child: PopScope(
              canPop: widget.embedded || leaving,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && !widget.embedded) unawaited(requestLeave());
              },
              child: Scaffold(
                resizeToAvoidBottomInset: false,
                primary: false,
                backgroundColor: background,
                body: SafeArea(
                  top: prefs['fullscreen'] != true,
                  bottom: prefs['fullscreen'] != true,
                  left: prefs['fullscreen'] != true,
                  right: prefs['fullscreen'] != true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              top: widget.embedded ? 0 : toolbarHeight,
                              child: session.isEmpty || commonSession == null
                                  ? (leaving
                                        ? const SizedBox.shrink()
                                        : Center(
                                            child: TextButton(
                                              onPressed: () =>
                                                  menu('reconnect'),
                                              child: Text(
                                                context.l10n.reconnect,
                                              ),
                                            ),
                                          ))
                                  : Listener(
                                      onPointerDown: (_) => interaction(),
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          bottom: MediaQuery.viewInsetsOf(
                                            context,
                                          ).bottom,
                                        ),
                                        child: FutureBuilder<String>(
                                          future: terminalFonts.putIfAbsent(
                                            storedFont,
                                            () =>
                                                engine.terminalFont(storedFont),
                                          ),
                                          builder: (context, font) => TerminalPane(
                                            key: terminalKey,
                                            initialRows:
                                                commonSession
                                                        .profile['forceSizeRows']
                                                    as int?,
                                            initialColumns:
                                                commonSession
                                                        .profile['forceSizeColumns']
                                                    as int?,
                                            alwaysVisibleKeys:
                                                prefs['alwaysvisible'] == true,
                                            keyHideDelay: Duration(
                                              milliseconds:
                                                  engine.state['autoHideDelayMs']
                                                      as int? ??
                                                  3000,
                                            ),
                                            pageGesture:
                                                prefs['pgupdngesture'] == true,
                                            volumeFont:
                                                prefs['volumefont'] == true,
                                            onFontSize: (increase) => command(
                                              'session.font',
                                              {'increase': increase},
                                            ),
                                            onSwipe:
                                                prefs['swipeSessions'] ==
                                                        true ||
                                                    prefs['swipeTmux'] == true
                                                ? (direction) {
                                                    if (prefs['swipeSessions'] ==
                                                        true) {
                                                      final sessions = engine
                                                          .list('sessions');
                                                      final index = sessions
                                                          .indexWhere(
                                                            (s) =>
                                                                s['id'] == id,
                                                          );
                                                      final target =
                                                          (index + direction)
                                                              .clamp(
                                                                0,
                                                                sessions.length -
                                                                    1,
                                                              );
                                                      if (target != index) {
                                                        select(
                                                          sessions[target]['id']
                                                              as int,
                                                        );
                                                      }
                                                    } else {
                                                      commonSession.input.sendText(
                                                        '${prefs['tmuxCtrlA'] == true ? '\u0001' : '\u0002'}${direction > 0 ? 'n' : 'p'}',
                                                      );
                                                    }
                                                  }
                                                : null,
                                            terminal: commonSession.terminal,
                                            controller:
                                                commonSession.controller,
                                            input: commonSession.input,
                                            onKeyEvent: _sessionKeyEvent,
                                            onOpenUrl: (url) => unawaited(
                                              runEngine(
                                                actionsContext,
                                                engine,
                                                'openUrl',
                                                {'url': url},
                                              ),
                                            ),
                                            onShare: (text) => unawaited(
                                              command('share', {'text': text}),
                                            ),
                                            enabled:
                                                engine.ready &&
                                                commonSession.sessionOpen &&
                                                visible == true &&
                                                prompt == null,
                                            theme: consoleTerminalTheme(
                                              row(
                                                commonSession
                                                    .prepared['scheme'],
                                              ),
                                              ended: ended,
                                            ),
                                            textStyle: TerminalStyle(
                                              fontSize: commonSession.fontSize,
                                              fontFamily:
                                                  font.data ?? tildeMono,
                                              fontFamilyFallback:
                                                  tildeMonoFallback,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  (prefs['terminalMargin']
                                                              as num? ??
                                                          0)
                                                      .toDouble()
                                                      .clamp(
                                                        1,
                                                        double.infinity,
                                                      ),
                                              vertical: 4,
                                            ),
                                            keyOrder:
                                                (prefs['terminalBarOrder']
                                                        as List?)
                                                    ?.cast<String>(),
                                            hiddenKeys:
                                                (prefs['terminalBarHidden']
                                                            as List? ??
                                                        [])
                                                    .cast<String>()
                                                    .toSet(),
                                            keyHeight:
                                                (prefs['terminalBarHeight']
                                                            as num? ??
                                                        36)
                                                    .toDouble(),
                                            groupFunctionKeys:
                                                prefs['terminalBarFn'] != false,
                                            stickyModifiers:
                                                prefs['stickymodifiers']
                                                    as String? ??
                                                'no',
                                            hapticFeedback:
                                                prefs['bumpyarrows'] == true,
                                            showKeyboardToggle:
                                                prefs['imeTogglekey'] != false,
                                            onEdit: (initial) => askText(
                                              actionsContext,
                                              context.l10n.sendTo(
                                                (session['nickname'] ??
                                                        context.l10n.terminal)
                                                    .toString(),
                                              ),
                                              action: context.l10n.send2,
                                              maxWidth: 640,
                                              initial: initial,
                                              multiline: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            if (showTitle)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: toolbarHeight,
                                child: AppBar(
                                  toolbarHeight: toolbarHeight,
                                  primary: false,
                                  backgroundColor: background,
                                  foregroundColor: theme.colorScheme.onSurface,
                                  systemOverlayStyle: overlays,
                                  automaticallyImplyLeading: false,
                                  leading: IconButton(
                                    tooltip: desktop
                                        ? context.l10n.deviceList
                                        : context.l10n.home,
                                    icon: Icon(
                                      desktop
                                          ? Icons.dns_outlined
                                          : Icons.home_outlined,
                                    ),
                                    onPressed: () => leave(),
                                  ),
                                  titleSpacing: 0,
                                  title: tabs
                                      ? DesktopSessionTabs(
                                          sessions: engine.list('sessions'),
                                          selectedId: id,
                                          onSelect: select,
                                          onClose: (target) =>
                                              unawaited(closeTab(target)),
                                          onNew: () => unawaited(leave()),
                                        )
                                      : titleHidden &&
                                            prefs['titlebarhide'] == true
                                      ? const SizedBox.shrink()
                                      : Text(
                                          sessionLabel(
                                            engine.list('sessions'),
                                            session,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  actions: [
                                    if (!tabs) ...[
                                      SessionSwitcherButton(
                                        count: engine.list('sessions').length,
                                        onPressed: openSessions,
                                      ),
                                      IconButton(
                                        tooltip: context.l10n.newTab,
                                        onPressed: () => leave(),
                                        icon: const Icon(Icons.add),
                                      ),
                                    ],
                                    popup(),
                                  ],
                                ),
                              ),
                            if (showConnection)
                              Positioned.fill(
                                top: contentTop,
                                bottom: MediaQuery.viewInsetsOf(context).bottom,
                                child: ColoredBox(
                                  color: background,
                                  child: _connectionStatus(prompt),
                                ),
                              ),
                            Positioned(
                              top: toolbarHeight,
                              left: 0,
                              right: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showProgress && !showConnection)
                                    LinearProgressIndicator(
                                      minHeight: 2,
                                      value:
                                          progressVisible &&
                                              progress['state'] !=
                                                  'INDETERMINATE'
                                          ? ((progress['value'] as num?)
                                                            ?.toDouble() ??
                                                        0)
                                                    .clamp(0, 100) /
                                                100
                                          : null,
                                      color: progress['state'] == 'ERROR'
                                          ? theme.colorScheme.error
                                          : progress['state'] == 'WARNING'
                                          ? theme.colorScheme.tertiary
                                          : theme.colorScheme.primary,
                                    ),
                                  for (final banner in rows(
                                    connectionLog == null
                                        ? session['banners']
                                        : null,
                                  ))
                                    Material(
                                      color:
                                          theme.colorScheme.surfaceContainerLow,
                                      child: ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.campaign_outlined,
                                        ),
                                        title: Text(
                                          '${banner['sourceName']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: () => showTildeSheet<void>(
                                                context: context,
                                                isScrollControlled: true,
                                                useSafeArea: true,
                                                builder: (c) => Theme(
                                                  data: theme,
                                                  child: SingleChildScrollView(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          24,
                                                        ),
                                                    child: SelectableText(
                                                      '${banner['message']}',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              child: Text(context.l10n.view),
                                            ),
                                            IconButton(
                                              tooltip:
                                                  context.l10n.dismissBanner,
                                              icon: const Icon(Icons.close),
                                              onPressed: () => command(
                                                'session.dismissBanner',
                                                {'bannerId': banner['id']},
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!showConnection &&
                                prompt != null &&
                                commonSession != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: MediaQuery.viewInsetsOf(context).bottom,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        (MediaQuery.sizeOf(context).height -
                                                MediaQuery.viewInsetsOf(
                                                  context,
                                                ).bottom -
                                                44)
                                            .clamp(0, double.infinity) *
                                        0.7,
                                  ),
                                  child: SingleChildScrollView(
                                    child: _loginPrompt(prompt),
                                  ),
                                ),
                              ),
                            if (ended && !showConnection)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: MediaQuery.viewInsetsOf(context).bottom,
                                child: Card(
                                  margin: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: theme.colorScheme.surfaceContainerLow,
                                  child: SafeArea(
                                    top: false,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            switch (session['disconnectReason']) {
                                              'USER_REQUESTED' =>
                                                context.l10n.connectionClosed,
                                              'SESSION_EXIT' =>
                                                context
                                                    .l10n
                                                    .theServerEndedTheSession,
                                              'AUTH_FAIL' =>
                                                context
                                                    .l10n
                                                    .connectionEndedAfterAuthenticationFailed,
                                              _ => context.l10n.connectionLost,
                                            },
                                          ),
                                          if (session['endedAt'] != null)
                                            Text(
                                              context.l10n.ended(
                                                (DateTime.tryParse(
                                                              '${session['endedAt']}',
                                                            )
                                                            ?.toLocal()
                                                            .toString()
                                                            .split('.')
                                                            .first ??
                                                        session['endedAt'])
                                                    .toString(),
                                              ),
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    menu('disconnect'),
                                                child: Text(
                                                  context.l10n.close2,
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () async {
                                                  await menu('selectAll');
                                                  await menu('copy');
                                                },
                                                child: Text(
                                                  context.l10n.copyOutput,
                                                ),
                                              ),
                                              FilledButton.tonal(
                                                onPressed: () =>
                                                    menu('reconnect'),
                                                child: Text(
                                                  context.l10n.reconnect,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
          );
        },
      ),
    );
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _sessionKeyEvent,
      child: content,
    );
  }
}

TerminalTheme consoleTerminalTheme(EngineRecord scheme, {bool ended = false}) {
  final fallback = TerminalThemes.defaultTheme;
  final palette = (scheme['palette'] as List? ?? []).cast<num>();
  Color color(int index, Color defaultColor) =>
      (index < palette.length ? Color(palette[index].toInt()) : defaultColor)
          .withValues(alpha: ended ? .55 : 1);
  return TerminalTheme(
    cursor: ended
        ? Colors.transparent
        : scheme.isEmpty
        ? tildeTide
        : paletteColor(scheme, 'cursor'),
    selection: tildeTide.withValues(alpha: .3),
    foreground:
        (scheme.isEmpty
                ? const Color(0xffeae9e7)
                : paletteColor(scheme, 'foreground'))
            .withValues(alpha: ended ? .55 : 1),
    background: scheme.isEmpty
        ? tildeNightBackground
        : paletteColor(scheme, 'background'),
    black: color(0, fallback.black),
    red: color(1, fallback.red),
    green: color(2, fallback.green),
    yellow: color(3, fallback.yellow),
    blue: color(4, fallback.blue),
    magenta: color(5, fallback.magenta),
    cyan: color(6, fallback.cyan),
    white: color(7, fallback.white),
    brightBlack: color(8, fallback.brightBlack),
    brightRed: color(9, fallback.brightRed),
    brightGreen: color(10, fallback.brightGreen),
    brightYellow: color(11, fallback.brightYellow),
    brightBlue: color(12, fallback.brightBlue),
    brightMagenta: color(13, fallback.brightMagenta),
    brightCyan: color(14, fallback.brightCyan),
    brightWhite: color(15, fallback.brightWhite),
    searchHitBackground: fallback.searchHitBackground,
    searchHitBackgroundCurrent: fallback.searchHitBackgroundCurrent,
    searchHitForeground: fallback.searchHitForeground,
  );
}

class EnrollmentPage extends StatefulWidget {
  final AndroidEngine engine;
  final EngineRecord host;
  final int sessionId;
  const EnrollmentPage({
    super.key,
    required this.engine,
    required this.host,
    required this.sessionId,
  });
  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  int? keyId;
  String name = '';
  bool started = false;
  @override
  void initState() {
    super.initState();
    name = deviceStrings.sshKey((widget.host['nickname']).toString());
    unawaited(begin());
  }

  Future<void> begin() async {
    final contextStrings = deviceStrings;
    try {
      await widget.engine.invoke('key.enrollmentBegin', {'name': name});
      if (mounted) {
        setState(() {
          keyId =
              row(widget.engine.state['enrollment'])['selectedKeyId'] as int?;
          started = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => started = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(contextStrings.couldNotPrepareRegistration),
            action: SnackBarAction(
              label: contextStrings.details,
              onPressed: () => showErrorDetails(context, e),
            ),
          ),
        );
      }
    }
  }

  Future<void> choose(EngineRecord state) async {
    final contextStrings = context.l10n;
    final choice =
        await pickTildeOption(context, contextStrings.keyToRegister, [
          if (state['biometricAvailable'] == true)
            (null, contextStrings.newBiometricKey),
          ('generate', contextStrings.createNewSshKey),
          for (final key
              in widget.engine
                  .list('keys')
                  .where(
                    (k) =>
                        k['supported'] != false &&
                        k['publicKey'] is String &&
                        (k['publicKey'] as String).isNotEmpty,
                  ))
            (key['id'], '${key['nickname']} · ${key['type']}'),
        ], keyId);
    if (choice == null || !mounted) return;
    if (choice.$1 == 'generate') {
      final record = await showTildeSheet<EngineRecord>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (c) =>
            GenerateKeyPage(engine: widget.engine, returnGeneratedKey: true),
      );
      if (record != null && mounted) {
        setState(() => keyId = record['id'] as int);
      }
    } else {
      setState(() => keyId = choice.$1 as int?);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.engine,
    builder: (context, _) {
      final state = row(widget.engine.state['enrollment']);
      if (state['hostId'] != null && state['hostId'] != widget.host['id']) {
        final owner = widget.engine
            .list('hosts')
            .where((h) => h['id'] == state['hostId'])
            .firstOrNull;
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.registerSshKeyLogin)),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.keyRegistration(
                    (owner?['nickname'] ?? context.l10n.anotherHost).toString(),
                    (state['busy'] == true
                            ? context.l10n.isInProgress
                            : context.l10n.isComplete)
                        .toString(),
                  ),
                ),
                if (state['busy'] == true) const TildeProgress(),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: state['busy'] == true ? null : begin,
                  child: Text(context.l10n.registrationPreparationForThisHost),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.close2),
                ),
              ],
            ),
          ),
        );
      }
      final busy = state['busy'] == true || !started;
      final selected = widget.engine
          .list('keys')
          .where(
            (k) =>
                k['id'] ==
                (state['stage'] == 'SUCCESS' ? state['selectedKeyId'] : keyId),
          )
          .firstOrNull;
      final failed = state['error'] != null;
      final stage = switch (state['stage']) {
        'REGISTERING' => 0,
        'VERIFYING' => 1,
        'APPLYING' => 2,
        'SUCCESS' => 3,
        _ =>
          state['verification'] == 'VERIFIED'
              ? 2
              : state['registration'] != null
              ? 1
              : 0,
      };
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.registerSshKeyLogin)),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: tildePointer(context) ? 640 : double.infinity,
            ),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                settingsNote(
                  context,
                  context.l10n.installThePublicKeyThenVerifyKeyLoginWith,
                ),
                settingsSection(context, context.l10n.keyToRegister, [
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(
                      keyId == null
                          ? context.l10n.newBiometricKey
                          : '${selected?['nickname'] ?? context.l10n.selectKey}',
                    ),
                    subtitle: selected?['fingerprint'] == null
                        ? null
                        : Text(
                            '${selected?['fingerprint']}',
                            style: const TextStyle(
                              fontFamily: tildeMono,
                              fontSize: 12,
                            ),
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: busy || state['stage'] == 'SUCCESS'
                        ? null
                        : () => choose(state),
                  ),
                  if (keyId == null && state['biometricAvailable'] == true)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        initialValue: name,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: context.l10n.newKeyName,
                        ),
                        onChanged: (value) => name = value,
                      ),
                    ),
                ]),
                settingsSection(context, context.l10n.progress, [
                  for (var i = 0; i < 3; i++)
                    ListTile(
                      leading: failed && stage == i
                          ? Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                            )
                          : stage > i
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : busy && stage == i
                          ? const TildeProgress.circular()
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: tildeMono,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                      title: Text(
                        [
                          context.l10n.installPublicKey,
                          context.l10n.verifyKeyLogin,
                          context.l10n.applyToHost,
                        ][i],
                        style: stage < i
                            ? TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                      subtitle: failed && stage == i
                          ? Row(
                              children: [
                                Expanded(
                                  child: Text(switch (state['verification']) {
                                    'REJECTED' when i == 1 =>
                                      context.l10n.theServerRejectedTheKey,
                                    'ADDITIONAL_AUTH_REQUIRED' when i == 1 =>
                                      context
                                          .l10n
                                          .theServerRequiresAdditionalAuthentication,
                                    _ => context.l10n.couldNotCompleteThisStep,
                                  }),
                                ),
                                TextButton(
                                  onPressed: () => showErrorDetails(
                                    context,
                                    state['error']!,
                                  ),
                                  child: Text(context.l10n.details),
                                ),
                              ],
                            )
                          : i == 0 && state['registration'] != null
                          ? Text(
                              state['registration'] == 'ADDED'
                                  ? context.l10n.installedOnServer
                                  : context.l10n.keyAlreadyInstalled,
                            )
                          : i == 1 && state['verification'] != null
                          ? Text(switch (state['verification']) {
                              'VERIFIED' => context.l10n.keyLoginVerified,
                              'ADDITIONAL_AUTH_REQUIRED' =>
                                context
                                    .l10n
                                    .theServerRequiresAdditionalAuthentication,
                              _ => context.l10n.theServerRejectedThisKey,
                            })
                          : null,
                    ),
                ]),
                if (state['stage'] == 'SUCCESS')
                  settingsSection(context, context.l10n.registrationComplete, [
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(
                        context.l10n.usingKey(
                          (selected?['nickname'] ?? name).toString(),
                        ),
                      ),
                    ),
                    if (widget.engine
                            .list('hosts')
                            .where((h) => h['id'] == widget.host['id'])
                            .firstOrNull?['hasPassword'] ==
                        true)
                      TextButton(
                        onPressed: () async {
                          final fresh = widget.engine
                              .list('hosts')
                              .where((h) => h['id'] == widget.host['id'])
                              .firstOrNull;
                          if (fresh != null) {
                            await runEngine(
                              context,
                              widget.engine,
                              'host.save',
                              {...fresh, 'clearPassword': true},
                            );
                          }
                        },
                        child: Text(
                          context.l10n.removeSavedPasswordForThisHost,
                        ),
                      ),
                  ])
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed:
                          busy ||
                              (keyId == null &&
                                  state['biometricAvailable'] != true)
                          ? null
                          : () => runEngine(
                              context,
                              widget.engine,
                              'key.enroll',
                              {
                                'sessionId': widget.sessionId,
                                'keyId': keyId,
                                'name': name,
                              },
                            ),
                      child: Text(context.l10n.registerAndVerify),
                    ),
                  ),
                if (busy && started)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.continueInBackground),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
