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
import 'tilde_controls.dart';
import 'tilde_design.dart';
import 'editors.dart';
import 'settings_widgets.dart';
import 'main.dart';
import 'management.dart';
import 'package:xterm2/xterm.dart';
import 'terminal/terminal_pane.dart';
import 'terminal/terminal_prompt.dart';
import 'terminal/session_tabs.dart';

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
          _desktop &&
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
    if (!widget.embedded && _desktop && visible == true && selected != null) {
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
        if (!mounted || target?.sessionOpen != true) return;
        final text = await askText(
          actionsContext,
          '${session['nickname'] ?? '터미널'}로 보내기',
          action: '보내기',
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
  bool exitPromptOpen = false;
  bool closingTab = false;

  Future<void> closeTab(int targetId) async {
    if (closingTab || leaving) return;
    final target = engine
        .list('sessions')
        .where((record) => record['id'] == targetId)
        .firstOrNull;
    if (target == null) return;
    closingTab = true;
    try {
      if ((target['open'] == true || target['connecting'] == true) &&
          !await confirm(
            actionsContext,
            '세션 종료',
            '${target['nickname'] ?? '터미널'} 연결을 종료할까요?',
            action: '종료',
          )) {
        return;
      }
      if (!mounted) return;
      await engine.invoke('session.disconnect', {'id': targetId});
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
        showEngineFailure(actionsContext, error, summary: '연결을 닫지 못했습니다');
      }
    } finally {
      closingTab = false;
    }
  }

  Future<void> requestLeave() async {
    if (leaving || exitPromptOpen) return;
    if (session.isEmpty || session['ended'] == true) {
      await leave(disconnect: true);
      return;
    }
    exitPromptOpen = true;
    final targetId = id;
    try {
      final host =
          engine
              .list('hosts')
              .where((h) => h['id'] == session['hostId'])
              .firstOrNull ??
          session;
      final disconnect = await showTildeSheet<bool>(
        context: actionsContext,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: TildeHostTile(host: host, size: 56),
                  title: Text(
                    '${session['nickname'] ?? '터미널'}에서 나가기',
                    style: Theme.of(c).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    hostAddress(host),
                    style: TextStyle(
                      fontFamily: host['protocol'] == 'local'
                          ? 'Pretendard'
                          : tildeMono,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                tildeActionButtons(c, [
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(c, false),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('연결 유지'),
                  ),
                  FilledButton.icon(
                    style: tildeDangerButtonStyle(c),
                    onPressed: () => Navigator.pop(c, true),
                    icon: const Icon(Icons.link_off_outlined),
                    label: const Text('세션 종료'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
      if (disconnect != null && mounted && id == targetId) {
        await leave(disconnect: disconnect);
      }
    } finally {
      exitPromptOpen = false;
    }
  }

  Future<void> leave({bool disconnect = false}) async {
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
        showEngineFailure(actionsContext, error, summary: '연결을 닫지 못했습니다');
      }
    }
  }

  Future<void> menu(String action) async {
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
    if (action == 'resize') {
      final targetId = id;
      final size = await askText(
        actionsContext,
        '터미널 크기 · 열×행',
        action: '크기 변경',
        initial: '',
        hintText: '80×24 · 빈 값은 자동',
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
          const SnackBar(content: Text('‘80×24’처럼 열×행으로 입력해 주세요.')),
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
        '${session['nickname'] ?? '터미널'}로 보내기',
        action: '보내기',
        maxWidth: 640,
        multiline: true,
        showPasteAction: true,
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
                  Text('터미널 링크', style: Theme.of(c).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (urls.isEmpty) const Text('화면에 링크가 없습니다.'),
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
                                  child: const Text('복사'),
                                ),
                                TextButton(
                                  onPressed: () => runEngine(
                                    actionsContext,
                                    engine,
                                    'openUrl',
                                    {'url': url},
                                  ),
                                  child: const Text('열기'),
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
      final hostId = connectionTarget['hostId'];
      final uri = connectionTarget['uri'];
      if (hostId is int && hostId > 0) {
        await runEngine(actionsContext, engine, 'connect', {
          'id': hostId,
          'newSession': true,
        });
      } else if (uri is String) {
        await runEngine(actionsContext, engine, 'connect', {
          'uri': uri,
          'newSession': true,
        });
      }
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
                  '${session['nickname'] ?? '터미널'}',
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                trailing: side
                    ? IconButton(
                        tooltip: '닫기',
                        icon: const Icon(Icons.close),
                        onPressed: close,
                      )
                    : null,
              ),
              const Divider(),
              if (connected) ...[
                entry('paste', '붙여넣기', Icons.content_paste_outlined),
                entry('text', '텍스트 입력', Icons.edit_note_outlined),
              ],
              if (connected) const Divider(),
              entry('urls', '링크', Icons.link_outlined),
              if (connected)
                entry(
                  'resize',
                  '터미널 크기',
                  Icons.aspect_ratio_outlined,
                  subtitle:
                      '${session['columns'] ?? '열'}×${session['rows'] ?? '행'}',
                  navigates: true,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.fullscreen, size: 22),
                title: const Text('전체 화면'),
                value: engine.preferences['fullscreen'] == true,
                onChanged: (_) => side
                    ? selectMenuAction('fullscreen')
                    : action('fullscreen'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.vertical_align_top, size: 22),
                title: const Text('제목 줄 자동 숨김'),
                value: engine.preferences['titlebarhide'] == true,
                onChanged: (_) => side
                    ? selectMenuAction('titlebarhide')
                    : action('titlebarhide'),
              ),
              const Divider(),
              if (connected && session['canForward'] == true)
                entry('forwards', '포트 포워딩', Icons.swap_horiz, navigates: true),
              if (session['canEnroll'] == true)
                entry(
                  'enroll',
                  '이 서버에 키 등록',
                  Icons.key_outlined,
                  navigates: true,
                ),
              if (!leaving && !connected && session['connecting'] != true)
                entry('reconnect', '다시 연결', Icons.refresh),
              entry(
                'newSession',
                '새 세션',
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
                connected ? '연결 끊기' : '닫기',
                connected ? Icons.link_off_outlined : Icons.close,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openMenu(BuildContext anchor) async {
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
            const PopupMenuItem(
              value: 'paste',
              child: TildeMenuLabel(
                '붙여넣기',
                Icons.content_paste_outlined,
                shortcut: 'Ctrl Shift V',
              ),
            ),
            const PopupMenuItem(
              value: 'text',
              child: TildeMenuLabel('텍스트 입력', Icons.edit_note_outlined),
            ),
            const PopupMenuDivider(),
          ],
          const PopupMenuItem(
            value: 'urls',
            child: TildeMenuLabel('링크', Icons.link_outlined),
          ),
          if (connected)
            const PopupMenuItem(
              value: 'resize',
              child: TildeMenuLabel('터미널 크기', Icons.aspect_ratio_outlined),
            ),
          const PopupMenuItem(
            value: 'fullscreen',
            child: TildeMenuLabel('전체 화면', Icons.fullscreen, shortcut: 'F11'),
          ),
          const PopupMenuDivider(),
          if (connected && session['canForward'] == true)
            const PopupMenuItem(
              value: 'forwards',
              child: TildeMenuLabel('포트 포워딩', Icons.swap_horiz),
            ),
          if (session['canEnroll'] == true)
            const PopupMenuItem(
              value: 'enroll',
              child: TildeMenuLabel('이 서버에 키 등록', Icons.key_outlined),
            ),
          if (!connected && session['connecting'] != true)
            const PopupMenuItem(
              value: 'reconnect',
              child: TildeMenuLabel('다시 연결', Icons.refresh),
            ),
          const PopupMenuItem(
            value: 'newSession',
            child: TildeMenuLabel(
              '새 세션',
              Icons.add_box_outlined,
              shortcut: 'Ctrl Shift T',
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'disconnect',
            child: TildeMenuLabel(
              connected ? '연결 끊기' : '닫기',
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
      tooltip: '터미널 메뉴',
      icon: const Icon(Icons.more_horiz),
      onPressed: () => openMenu(anchor),
    ),
  );

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
        'MONOSPACE';
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
    final desktop = _desktop;
    final showTitle =
        !widget.embedded &&
        (desktop || !(titleHidden && prefs['titlebarhide'] == true));
    final toolbarHeight = showTitle ? (desktop ? 48.0 : 44.0) : 0.0;
    final contentTop = toolbarHeight + (showProgress ? 2 : 0);
    final connectionLog = session['connectionLog'] as List?;
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
                              top:
                                  widget.embedded ||
                                      prefs['titlebarhide'] == true
                                  ? 0
                                  : toolbarHeight,
                              child: session.isEmpty || commonSession == null
                                  ? (leaving
                                        ? const SizedBox.shrink()
                                        : Center(
                                            child: TextButton(
                                              onPressed: () =>
                                                  menu('reconnect'),
                                              child: const Text('다시 연결'),
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
                                              '${session['nickname'] ?? '터미널'}로 보내기',
                                              action: '보내기',
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
                                    tooltip: desktop ? '기기 목록' : '뒤로',
                                    icon: Icon(
                                      desktop
                                          ? Icons.dns_outlined
                                          : Icons.arrow_back,
                                    ),
                                    onPressed: desktop
                                        ? () => leave()
                                        : requestLeave,
                                  ),
                                  titleSpacing: 0,
                                  title: desktop
                                      ? DesktopSessionTabs(
                                          sessions: engine.list('sessions'),
                                          selectedId: id,
                                          onSelect: select,
                                          onClose: (target) =>
                                              unawaited(closeTab(target)),
                                          onNew: () => unawaited(
                                            selectMenuAction('newSession'),
                                          ),
                                        )
                                      : engine.list('sessions').length == 1
                                      ? Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 6,
                                              color: session['open'] == true
                                                  ? theme.colorScheme.primary
                                                  : theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${session['nickname'] ?? '터미널'}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              for (final target in engine.list(
                                                'sessions',
                                              ))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 4,
                                                      ),
                                                  child: TextButton(
                                                    style: TextButton.styleFrom(
                                                      minimumSize: const Size(
                                                        0,
                                                        44,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                          ),
                                                      backgroundColor:
                                                          target['id'] == id
                                                          ? theme
                                                                .colorScheme
                                                                .surfaceContainerHigh
                                                          : null,
                                                      foregroundColor:
                                                          target['id'] == id
                                                          ? theme
                                                                .colorScheme
                                                                .onSurface
                                                          : theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                    ),
                                                    onPressed: () => select(
                                                      target['id'] as int,
                                                    ),
                                                    child: Text(
                                                      '${target['nickname'] ?? '터미널'}',
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                  actions: [popup()],
                                ),
                              ),
                            if (connectionLog != null)
                              Positioned.fill(
                                top: contentTop,
                                bottom: MediaQuery.viewInsetsOf(context).bottom,
                                child: ColoredBox(
                                  color: background,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child: SelectableText(
                                      [
                                        ...connectionLog,
                                        if (progress['state'] == 'ERROR')
                                          progress['message'],
                                      ].join('\n'),
                                      style: TextStyle(
                                        fontFamily: tildeMono,
                                        color: theme.colorScheme.onSurface,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: toolbarHeight,
                              left: 0,
                              right: 0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showProgress)
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
                                              child: const Text('보기'),
                                            ),
                                            IconButton(
                                              tooltip: '배너 닫기',
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
                            if (prompt != null && commonSession != null)
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
                                    child: TerminalPromptSurface(
                                      key: ValueKey((id, prompt['token'])),
                                      prompt: prompt,
                                      enabled: visible == true,
                                      onResponse: (value) async {
                                        await runEngine(
                                          actionsContext,
                                          engine,
                                          'prompt.respond',
                                          {
                                            'sessionId': prompt['sessionId'],
                                            'token': prompt['token'],
                                            'value': value,
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            if (ended)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: MediaQuery.viewInsetsOf(context).bottom,
                                child: Material(
                                  color: theme.colorScheme.surfaceContainerLow,
                                  child: SafeArea(
                                    top: false,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          const Expanded(
                                            child: Text('연결이 끊겼습니다'),
                                          ),
                                          TextButton(
                                            onPressed: () => menu('reconnect'),
                                            child: const Text('다시 연결'),
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

TerminalTheme consoleTerminalTheme(EngineRecord scheme) {
  final fallback = TerminalThemes.defaultTheme;
  final palette = (scheme['palette'] as List? ?? []).cast<num>();
  Color color(int index, Color defaultColor) =>
      index < palette.length ? Color(palette[index].toInt()) : defaultColor;
  return TerminalTheme(
    cursor: scheme.isEmpty ? tildeTide : paletteColor(scheme, 'cursor'),
    selection: tildeTide.withValues(alpha: .3),
    foreground: scheme.isEmpty
        ? const Color(0xffeae9e7)
        : paletteColor(scheme, 'foreground'),
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
    name = '${widget.host['nickname']} SSH 키';
    unawaited(begin());
  }

  Future<void> begin() async {
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
            content: const Text('등록 준비를 완료하지 못했습니다'),
            action: SnackBarAction(
              label: '자세히',
              onPressed: () => showErrorDetails(context, e),
            ),
          ),
        );
      }
    }
  }

  Future<void> choose(EngineRecord state) async {
    final choice = await pickTildeOption(context, '등록할 키', [
      if (state['biometricAvailable'] == true) (null, '새 생체인증 키'),
      ('generate', '새 SSH 키 만들기'),
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
          appBar: AppBar(title: const Text('SSH 키 로그인 등록')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${owner?['nickname'] ?? '다른 호스트'} 키 등록${state['busy'] == true ? '을 진행 중입니다' : '이 끝났습니다'}',
                ),
                if (state['busy'] == true) const TildeProgress(),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: state['busy'] == true ? null : begin,
                  child: const Text('이 호스트의 등록 준비'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기'),
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
        appBar: AppBar(title: const Text('SSH 키 로그인 등록')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            settingsNote(context, '공개키를 등록한 뒤 별도 연결로 키 로그인을 확인합니다.'),
            settingsSection(context, '등록할 키', [
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: Text(
                  keyId == null
                      ? '새 생체인증 키'
                      : '${selected?['nickname'] ?? '키 선택'}',
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
                    decoration: const InputDecoration(labelText: '새 키 이름'),
                    onChanged: (value) => name = value,
                  ),
                ),
            ]),
            settingsSection(context, '진행', [
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
                    ['공개키 등록', '키 로그인 검증', '호스트에 적용'][i],
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
                                'REJECTED' when i == 1 => '서버가 키를 거절했습니다',
                                'ADDITIONAL_AUTH_REQUIRED' when i == 1 =>
                                  '서버가 추가 인증을 요구합니다',
                                _ => '이 단계를 완료하지 못했습니다',
                              }),
                            ),
                            TextButton(
                              onPressed: () =>
                                  showErrorDetails(context, state['error']!),
                              child: const Text('자세히'),
                            ),
                          ],
                        )
                      : i == 0 && state['registration'] != null
                      ? Text(
                          state['registration'] == 'ADDED'
                              ? '서버에 등록했습니다'
                              : '이미 등록된 키입니다',
                        )
                      : i == 1 && state['verification'] != null
                      ? Text(switch (state['verification']) {
                          'VERIFIED' => '키 로그인을 확인했습니다',
                          'ADDITIONAL_AUTH_REQUIRED' => '서버가 추가 인증을 요구합니다',
                          _ => '서버가 이 키를 거절했습니다',
                        })
                      : null,
                ),
            ]),
            if (state['stage'] == 'SUCCESS')
              settingsSection(context, '등록 완료', [
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text('${selected?['nickname'] ?? name} 키를 사용합니다'),
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
                        await runEngine(context, widget.engine, 'host.save', {
                          ...fresh,
                          'clearPassword': true,
                        });
                      }
                    },
                    child: const Text('이 호스트의 저장된 비밀번호 지우기'),
                  ),
              ])
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed:
                      busy ||
                          (keyId == null && state['biometricAvailable'] != true)
                      ? null
                      : () => runEngine(context, widget.engine, 'key.enroll', {
                          'sessionId': widget.sessionId,
                          'keyId': keyId,
                          'name': name,
                        }),
                  child: const Text('등록 및 검증'),
                ),
              ),
            if (busy && started)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('백그라운드에서 계속'),
                ),
              ),
          ],
        ),
      );
    },
  );
}
