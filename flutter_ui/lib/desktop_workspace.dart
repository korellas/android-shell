// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:math' as math;
import 'windows_window_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'console.dart';
import 'editors.dart';
import 'engine.dart';
import 'files/file_browser.dart';
import 'files/file_preview.dart';
import 'main.dart'
    show
        askText,
        confirm,
        deleteTildeHost,
        hostAddress,
        runEngine,
        canConnectHost;
import 'management.dart';
import 'tilde_controls.dart';
import 'tilde_design.dart';
import 'l10n/strings.dart';

enum _TabKind { home, terminal, files, editor, document }

class _WorkspaceTab {
  _WorkspaceTab(
    this.id,
    this.title,
    this.kind, {
    this.hostId,
    this.sessionId,
    this.child,
    this.parent,
  });
  String id;
  String title;
  final _TabKind kind;
  int? hostId;
  final int? sessionId;
  final Widget? child;
  final String? parent;
  Future<bool> Function()? canClose;
  bool dirty = false;
}

class DesktopWorkspace extends StatefulWidget {
  const DesktopWorkspace({super.key, required this.engine});
  final AndroidEngine engine;
  @override
  State<DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends State<DesktopWorkspace> {
  final _tabs = <_WorkspaceTab>[
    _WorkspaceTab('home', deviceStrings.home, _TabKind.home),
  ];
  final _console = GlobalKey<ConsolePageState>();
  final _search = TextEditingController();
  final _activeTabKey = GlobalKey();
  final _pageNavigator = GlobalKey<NavigatorState>();
  bool _pageOpen = false;
  double? _lastWidth;
  final _searchFocus = FocusNode();
  String _active = 'home';
  int? _hostId, _terminalId, _setupHostId, _setupSessionId;
  bool? _showSidebar;
  bool _consuming = false;
  String? _hoverHost, _hoverTab;
  AndroidEngine get engine => widget.engine;
  bool get nativeWindow => engine.state['platform'] == 'windows';
  _WorkspaceTab get active =>
      _tabs.firstWhere((t) => t.id == _active, orElse: () => _tabs.first);
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
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent != false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _changed();
      });
    }
  }

  void _changed() {
    if (!mounted) return;
    final current = !_pageOpen && ModalRoute.of(context)?.isCurrent != false;
    final selected = engine.state['selectedSession'] as int?;
    setState(() {
      for (final session in engine.list('sessions')) {
        final id = session['id'] as int, key = 'session-${session['id']}';
        if (!_tabs.any((t) => t.id == key)) {
          _tabs.add(
            _WorkspaceTab(
              key,
              '${session['nickname'] ?? context.l10n.terminal}',
              _TabKind.terminal,
              sessionId: id,
              hostId: session['hostId'] as int?,
            ),
          );
        }
        final siblings = engine
            .list('sessions')
            .where((s) => s['nickname'] == session['nickname'])
            .toList();
        _tabs.firstWhere((tab) => tab.id == key).title =
            '${session['nickname'] ?? context.l10n.terminal}${siblings.length > 1 ? ' · ${siblings.indexWhere((record) => record['id'] == id) + 1}' : ''}';
        _terminalId ??= id;
      }
      if (current &&
          selected != null &&
          _tabs.any((t) => t.sessionId == selected)) {
        _active = 'session-$selected';
        _terminalId = selected;
        final session = engine
            .list('sessions')
            .firstWhere((record) => record['id'] == selected);
        if (_setupHostId != null && _setupHostId == session['hostId']) {
          _setupSessionId = selected;
          _setupHostId = null;
        }
      }
    });
    if (current && selected != null && !_consuming) {
      _focusActive();
      _revealActive();
      _consuming = true;
      unawaited(
        engine
            .invoke('session.consumeSelection')
            .whenComplete(() => _consuming = false),
      );
    }
  }

  void _focusActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          active.kind == _TabKind.terminal &&
          !_pageOpen &&
          ModalRoute.of(context)?.isCurrent != false) {
        engine.terminalSession(_terminalId!)?.input.requestKeyboard();
      }
    });
  }

  void _revealActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _activeTabKey.currentContext;
      if (mounted && anchor != null) {
        Scrollable.ensureVisible(anchor, alignment: .5);
      }
    });
  }

  Future<void> _select(_WorkspaceTab tab) async {
    if (_pageOpen) {
      await _pageNavigator.currentState?.maybePop();
      if (!mounted || _pageOpen) return;
    }
    if (_active == tab.id) return;
    final previous = _terminalId;
    if (active.kind == _TabKind.terminal) {
      engine.terminalSession(previous ?? -1)?.input.finishComposition();
    }
    setState(() {
      _active = tab.id;
      if (tab.sessionId != null) _terminalId = tab.sessionId;
    });
    _focusActive();
    _revealActive();
  }

  Future<void> _connect(EngineRecord host, {bool newSession = true}) async {
    if (!canConnectHost(host)) {
      _edit(host);
      return;
    }
    await runEngine(context, engine, 'connect', {
      'id': host['id'],
      if (newSession) 'newSession': true,
    });
  }

  Future<void> _submit(String value) async {
    final text = value.trim();
    final match = engine
        .list('hosts')
        .where((h) => h['nickname'] == text || h['hostname'] == text)
        .firstOrNull;
    if (match != null) {
      await _connect(match);
      return;
    }
    if (text.isEmpty) {
      final h = engine
          .list('hosts')
          .where((h) => h['id'] == _hostId)
          .firstOrNull;
      if (h != null) await _connect(h);
      return;
    }
    await runEngine(context, engine, 'connect', {
      'uri': text.startsWith('ssh ') ? text.substring(4).trim() : text,
    });
  }

  void _files(EngineRecord host) {
    final id = 'files-${host['id']}';
    final existing = _tabs.where((t) => t.id == id).firstOrNull;
    if (existing != null) {
      _select(existing);
      return;
    }
    late _WorkspaceTab tab;
    tab = _WorkspaceTab(
      id,
      context.l10n.files((host['nickname']).toString()),
      _TabKind.files,
      hostId: host['id'] as int,
      child: FileBrowserPage(
        engine: engine,
        host: host,
        embedded: true,
        registerLeaveGuard: (guard) => tab.canClose = guard,
        onPreview: (preview) => _document(tab, preview),
      ),
    );
    setState(() {
      _tabs.add(tab);
      _active = id;
    });
    _revealActive();
  }

  void _document(_WorkspaceTab parent, FilePreview preview) {
    final id = '${parent.id}:${preview.path}';
    final existing = _tabs.where((tab) => tab.id == id).firstOrNull;
    if (existing != null) {
      _select(existing);
      return;
    }
    late _WorkspaceTab tab;
    tab = _WorkspaceTab(
      id,
      preview.path.split('/').last,
      _TabKind.document,
      parent: parent.id,
      hostId: parent.hostId,
      child: FilePreview(
        path: preview.path,
        size: preview.size,
        host: preview.host,
        load: preview.load,
        save: preview.save,
        newFile: preview.newFile,
        embedded: true,
        onDownload: preview.onDownload,
        registerLeaveGuard: (guard) => tab.canClose = guard,
        onClose: () => _close(tab),
        onDirtyChanged: (dirty) {
          if (mounted) setState(() => tab.dirty = dirty);
        },
      ),
    );
    setState(() {
      _tabs.add(tab);
      _active = tab.id;
    });
    _revealActive();
  }

  Future<void> _setupHost(EngineRecord host) async {
    _setupHostId = host['id'] as int;
    final connected = await runEngine(context, engine, 'connect', {
      'id': host['id'],
    });
    if (connected == null) _setupHostId = null;
  }

  void _edit([EngineRecord? host]) {
    final id = 'editor-${host?['id'] ?? 'new'}';
    final existing = _tabs.where((t) => t.id == id).firstOrNull;
    if (existing != null) {
      _select(existing);
      return;
    }
    late _WorkspaceTab tab;
    tab = _WorkspaceTab(
      id,
      host == null
          ? context.l10n.newHost
          : context.l10n.edit((host['nickname']).toString()),
      _TabKind.editor,
      hostId: host?['id'] as int?,
      child: RecordEditor(
        engine: engine,
        kind: RecordKind.host,
        record: host,
        embedded: true,
        onSetup: _setupHost,
        onSaved: (record) {
          if (!mounted) return;
          setState(() {
            final previous = tab.id;
            tab.id = 'editor-${record['id']}';
            tab.hostId = record['id'] as int?;
            tab.title = context.l10n.edit((record['nickname']).toString());
            if (_active == previous) _active = tab.id;
            _hostId = tab.hostId;
          });
        },
        registerLeaveGuard: (guard) => tab.canClose = guard,
        onDirtyChanged: (dirty) {
          if (mounted) setState(() => tab.dirty = dirty);
        },
        onClose: () => _close(tab),
      ),
    );
    setState(() {
      _tabs.add(tab);
      _active = id;
    });
    _revealActive();
  }

  Future<void> _close(_WorkspaceTab tab) async {
    final contextStrings = context.l10n;
    if (tab.kind == _TabKind.home) return;
    final children = _tabs.where((t) => t.parent == tab.id).toList();
    for (final child in children) {
      if (child.canClose != null && !await child.canClose!()) return;
    }
    if (tab.canClose != null && !await tab.canClose!()) return;
    if (!mounted) return;
    if (tab.sessionId != null) {
      final session = engine
          .list('sessions')
          .where((s) => s['id'] == tab.sessionId)
          .firstOrNull;
      if (session?['open'] == true &&
          !await confirm(
            context,
            contextStrings.disconnectAndCloseTab,
            contextStrings.disconnectFromAndCloseThisTab(
              (tab.title).toString(),
            ),
            action: contextStrings.disconnectAndClose,
          )) {
        return;
      }
      if (!mounted) return;
      await runEngine(context, engine, 'session.disconnect', {
        'id': tab.sessionId,
      });
    }
    if (!mounted) return;
    setState(() {
      final index = _tabs.indexOf(tab);
      _tabs.removeWhere((t) => t.id == tab.id || t.parent == tab.id);
      if (!_tabs.any((t) => t.id == _active)) {
        _active = _tabs[(index - 1).clamp(0, _tabs.length - 1)].id;
      }
      if (active.sessionId != null) {
        _terminalId = active.sessionId;
      } else if (!_tabs.any((t) => t.sessionId == _terminalId)) {
        _terminalId = _tabs
            .where((t) => t.kind == _TabKind.terminal)
            .firstOrNull
            ?.sessionId;
      }
    });
    _focusActive();
    _revealActive();
  }

  Future<void> _hostMenu(
    EngineRecord host,
    BuildContext anchor, [
    Offset? point,
  ]) async {
    final anchorStrings = anchor.l10n;
    final connected = engine
        .list('sessions')
        .any((s) => s['hostId'] == host['id'] && s['open'] == true);
    final action = await TildeItemMenu.show<String>(
      anchor,
      title: '${host['nickname']}',
      icon: Icons.dns_outlined,
      position: point,
      itemBuilder: (_) => [
        if (canConnectHost(host))
          PopupMenuItem(
            value: 'terminal',
            child: TildeMenuLabel(
              anchorStrings.newTerminal,
              Icons.terminal_outlined,
              shortcut: 'Enter',
            ),
          ),
        if (host['protocol'] == 'ssh')
          PopupMenuItem(
            value: 'files',
            child: TildeMenuLabel(
              anchorStrings.fileTransfer,
              Icons.folder_open_outlined,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'edit',
          child: TildeMenuLabel(anchorStrings.edit2, Icons.edit_outlined),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: TildeMenuLabel(
            host['favorite'] == true
                ? anchorStrings.removeFromFavorites
                : anchorStrings.addToFavorites,
            Icons.star_border,
          ),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: TildeMenuLabel(
            anchorStrings.duplicate,
            Icons.content_copy_outlined,
          ),
        ),
        if (host['protocol'] == 'ssh')
          PopupMenuItem(
            value: 'forwards',
            child: TildeMenuLabel(
              anchorStrings.portForwarding,
              Icons.swap_horiz,
            ),
          ),
        if (connected) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'disconnect',
            child: TildeMenuLabel(
              anchorStrings.disconnect,
              Icons.link_off_outlined,
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: TildeMenuLabel(
            anchorStrings.delete,
            Icons.delete_outline,
            danger: true,
            shortcut: 'Del',
          ),
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'terminal':
        await _connect(host, newSession: true);
      case 'files':
        _files(host);
      case 'edit':
        _edit(host);
      case 'favorite':
        await runEngine(context, engine, 'host.favorite', {'id': host['id']});
      case 'duplicate':
        final name = await askText(
          context,
          anchorStrings.nameForDuplicateHost,
          initial: anchorStrings.copy((host['nickname']).toString()),
          action: anchorStrings.duplicate,
        );
        if (name != null && mounted) {
          await runEngine(context, engine, 'host.duplicate', {
            'id': host['id'],
            'nickname': name,
          });
        }
      case 'forwards':
        _page(ForwardsPage(engine: engine, host: host));
      case 'disconnect':
        if (await confirm(
              context,
              anchorStrings.disconnect,
              anchorStrings.disconnectAllSessionsFor(
                (host['nickname']).toString(),
              ),
              action: anchorStrings.disconnect,
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

  Future<void> _page(Widget page) async {
    if (!nativeWindow) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page));
      return;
    }
    if (_pageOpen) return;
    setState(() => _pageOpen = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await _pageNavigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    } finally {
      if (mounted) {
        setState(() => _pageOpen = false);
        _focusActive();
      }
    }
  }

  Future<void> _newTab() async {
    await _select(_tabs.first);
    if (!mounted || _pageOpen) return;
    setState(() => _showSidebar = true);
  }

  final _handledKeys = <LogicalKeyboardKey>{};
  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent && _handledKeys.remove(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent || _pageOpen) return KeyEventResult.ignored;
    final key = event.logicalKey, kb = HardwareKeyboard.instance;
    if (kb.isControlPressed && key == LogicalKeyboardKey.keyB) {
      setState(
        () => _showSidebar =
            !(_showSidebar ?? MediaQuery.sizeOf(context).width >= 720),
      );
    } else if (kb.isControlPressed && key == LogicalKeyboardKey.keyK) {
      setState(() => _showSidebar = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocus.requestFocus();
          _search.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _search.text.length,
          );
        }
      });
    } else if (kb.isControlPressed && key == LogicalKeyboardKey.comma) {
      _page(SettingsPage(engine: engine));
    } else if (kb.isControlPressed && key == LogicalKeyboardKey.tab) {
      final tabs = _tabs.where((tab) => tab.kind != _TabKind.home).toList();
      if (tabs.isNotEmpty) {
        final i = tabs.indexOf(active);
        final next = i < 0
            ? (kb.isShiftPressed ? tabs.length - 1 : 0)
            : (i + (kb.isShiftPressed ? -1 : 1)) % tabs.length;
        _select(tabs[next]);
      }
    } else if (kb.isControlPressed &&
        kb.isShiftPressed &&
        key == LogicalKeyboardKey.keyT) {
      unawaited(_newTab());
    } else if (key == LogicalKeyboardKey.f11) {
      unawaited(
        runEngine(context, engine, 'settings.update', {
          'key': 'fullscreen',
          'value': engine.preferences['fullscreen'] != true,
        }),
      );
    } else {
      return KeyEventResult.ignored;
    }
    _handledKeys.add(key);
    return KeyEventResult.handled;
  }

  Widget _sidebar(List<EngineRecord> hosts) {
    final filtered = hosts
        .where(
          (h) => '${h['nickname']} ${h['hostname']}'.toLowerCase().contains(
            _search.text.toLowerCase(),
          ),
        )
        .toList();
    return SizedBox(
      key: const ValueKey('workspace-sidebar'),
      width: 264,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!nativeWindow)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TildeWordmark(size: 23),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    decoration: tildeToolbarInput(
                      context,
                      InputDecoration(
                        isDense: true,
                        hintText: context.l10n.searchHosts,
                        prefixIcon: Tooltip(
                          message:
                              context.l10n.searchHostsOrEnterSshAddressCtrlK,
                          child: Icon(Icons.search, size: 18),
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _submit,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.addHost,
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                if (engine.list('hosts').isEmpty)
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(context.l10n.noHostsYet),
                  ),
                for (final host in filtered)
                  Builder(
                    builder: (anchor) {
                      final selected = host['id'] == _hostId,
                          hover = _hoverHost == '${host['id']}';
                      return MouseRegion(
                        onEnter: (_) =>
                            setState(() => _hoverHost = '${host['id']}'),
                        onExit: (_) => setState(() => _hoverHost = null),
                        child: GestureDetector(
                          onDoubleTap: () => _connect(host, newSession: true),
                          onSecondaryTapUp: (event) =>
                              _hostMenu(host, anchor, event.globalPosition),
                          child: Material(
                            color: selected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            child: InkWell(
                              key: ValueKey('workspace-host-${host['id']}'),
                              borderRadius: BorderRadius.circular(6),
                              onTap: () => setState(() {
                                _hostId = host['id'] as int;
                                _active = 'home';
                              }),
                              child: SizedBox(
                                height: 36,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    TildeHostTile(host: host, size: 24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${host['nickname']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    for (final kind in [
                                      _TabKind.terminal,
                                      _TabKind.files,
                                    ])
                                      if (_tabs
                                              .where(
                                                (tab) =>
                                                    tab.hostId == host['id'] &&
                                                    tab.kind == kind,
                                              )
                                              .firstOrNull
                                          case final tab?)
                                        IconButton(
                                          tooltip: kind == _TabKind.terminal
                                              ? context.l10n.openTerminals
                                              : context.l10n.openFiles,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                          iconSize: 15,
                                          icon: Icon(
                                            kind == _TabKind.terminal
                                                ? Icons.terminal
                                                : Icons.folder_outlined,
                                          ),
                                          onPressed: () =>
                                              setState(() => _active = tab.id),
                                        ),
                                    if (host['favorite'] == true)
                                      Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.tertiary,
                                      ),
                                    if (hover)
                                      IconButton(
                                        tooltip: context.l10n.menu(
                                          (host['nickname']).toString(),
                                        ),
                                        onPressed: () =>
                                            _hostMenu(host, anchor),
                                        icon: const Icon(
                                          Icons.more_vert,
                                          size: 18,
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 32),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ListTile(
                  minTileHeight: 36,
                  leading: const Icon(Icons.settings_outlined, size: 18),
                  title: Text(context.l10n.settings),
                  trailing: Text(
                    'Ctrl ,',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => _page(SettingsPage(engine: engine)),
                ),
                ListTile(
                  minTileHeight: 36,
                  leading: const Icon(Icons.help_outline, size: 18),
                  title: Text(context.l10n.helpAndLogs),
                  onTap: () => _page(
                    SettingsPage(
                      engine: engine,
                      initialPage: HelpPage(engine: engine),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(_WorkspaceTab tab) => switch (tab.kind) {
    _TabKind.home => Icons.home,
    _TabKind.files => Icons.folder_outlined,
    _TabKind.editor => Icons.edit_outlined,
    _TabKind.document => Icons.description_outlined,
    _ => Icons.terminal_outlined,
  };
  Widget _tabStrip(
    bool sidebar, {
    Widget? dragRegion,
    bool showDivider = true,
  }) {
    final tabs = _tabs.where((tab) => tab.kind != _TabKind.home).toList();
    final colors = Theme.of(context).colorScheme;
    Widget button(String tooltip, IconData icon, VoidCallback action) =>
        SizedBox(
          width: 40,
          child: IconButton(
            tooltip: tooltip,
            onPressed: action,
            icon: Icon(icon, size: 19),
          ),
        );
    return Container(
      height: 40,
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            )
          : null,
      padding: dragRegion == null
          ? EdgeInsets.zero
          : const EdgeInsets.only(top: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = math.min(
            tabs.length * 180.0,
            math.max(
              0.0,
              constraints.maxWidth -
                  80 -
                  40 -
                  48 -
                  (active.kind == _TabKind.terminal ? 40 : 0),
            ),
          );
          return Row(
            children: [
              button(
                context.l10n.hostListCtrlB,
                Icons.vertical_split_outlined,
                () => setState(() => _showSidebar = !sidebar),
              ),
              Semantics(
                key: const ValueKey('workspace-tab-home'),
                selected: _active == 'home',
                child: SizedBox(
                  width: 40,
                  child: IconButton(
                    tooltip: context.l10n.home,
                    isSelected: _active == 'home',
                    onPressed: () => _select(_tabs.first),
                    icon: const Icon(Icons.home_outlined, size: 19),
                    selectedIcon: const Icon(Icons.home, size: 19),
                  ),
                ),
              ),
              SizedBox(
                width: tabWidth,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final tab in tabs)
                      MouseRegion(
                        onEnter: (_) => setState(() => _hoverTab = tab.id),
                        onExit: (_) => setState(() => _hoverTab = null),
                        child: Material(
                          color: tab.id == _active
                              ? (dragRegion == null
                                    ? colors.surfaceContainerHigh
                                    : colors.surface)
                              : Colors.transparent,
                          borderRadius: dragRegion == null
                              ? null
                              : const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                          child: Semantics(
                            key: ValueKey('workspace-tab-${tab.id}'),
                            selected: tab.id == _active,
                            child: InkWell(
                              key: tab.id == _active ? _activeTabKey : null,
                              onTap: () => _select(tab),
                              child: Container(
                                width: 180,
                                decoration:
                                    dragRegion != null && tab.id == _active
                                    ? BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: colors.primary,
                                            width: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    right: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _icon(tab),
                                        size: 16,
                                        color:
                                            tab.kind == _TabKind.terminal &&
                                                engine
                                                        .list('sessions')
                                                        .where(
                                                          (session) =>
                                                              session['id'] ==
                                                              tab.sessionId,
                                                        )
                                                        .firstOrNull?['ended'] ==
                                                    true
                                            ? colors.error
                                            : tab.id == _active
                                            ? colors.primary
                                            : colors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          tab.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                      if (tab.dirty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: colors.tertiary,
                                          ),
                                        ),
                                      Opacity(
                                        opacity:
                                            tab.id == _active ||
                                                _hoverTab == tab.id
                                            ? 1
                                            : 0,
                                        child: SizedBox(
                                          width: 32,
                                          child: IconButton(
                                            tooltip: context.l10n.closeTab(
                                              (tab.title).toString(),
                                            ),
                                            onPressed: () => _close(tab),
                                            icon: const Icon(
                                              Icons.close,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              button(context.l10n.newTabCtrlShiftT, Icons.add, () => _newTab()),
              if (active.kind == _TabKind.terminal)
                Builder(
                  builder: (anchor) => button(
                    context.l10n.terminalMenu,
                    Icons.more_horiz,
                    () => _console.currentState?.openMenu(anchor),
                  ),
                ),
              Expanded(child: dragRegion ?? const SizedBox.shrink()),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (_lastWidth != width) {
      _lastWidth = width;
      _revealActive();
    }
    final hosts = engine.list('hosts');
    if (!hosts.any((h) => h['id'] == _hostId)) {
      _hostId = hosts.firstOrNull?['id'] as int?;
    }
    final host = hosts.where((h) => h['id'] == _hostId).firstOrNull;
    final sidebar = _showSidebar ?? MediaQuery.sizeOf(context).width >= 720;
    final terminal = active.kind == _TabKind.terminal;
    final pages = _tabs.where((t) => t.kind != _TabKind.terminal).toList();
    final currentRoute =
        !_pageOpen && (ModalRoute.of(context)?.isCurrent ?? true);
    final workspace = Row(
      children: [
        if (sidebar) ...[_sidebar(hosts), const VerticalDivider(width: 1)],
        Expanded(
          child: Column(
            children: [
              if (!nativeWindow) _tabStrip(sidebar),
              Expanded(
                child: IndexedStack(
                  index: terminal ? 0 : pages.indexOf(active) + 1,
                  children: [
                    _terminalId == null
                        ? const SizedBox.shrink()
                        : TickerMode(
                            enabled: terminal && currentRoute,
                            child: ConsolePage(
                              key: _console,
                              engine: engine,
                              sessionId: _terminalId!,
                              embedded: true,
                              startKeySetup: _setupSessionId == _terminalId,
                              onKeySetupOpened: () =>
                                  setState(() => _setupSessionId = null),
                              active: terminal && currentRoute,
                              onSelectSession: (id) {
                                final tab = _tabs
                                    .where((t) => t.sessionId == id)
                                    .firstOrNull;
                                if (tab != null) _select(tab);
                              },
                              onWorkspaceKey: _key,
                              onClose: () => _close(
                                _tabs.firstWhere(
                                  (t) => t.sessionId == _terminalId,
                                ),
                              ),
                              onGoHome: () => _select(_tabs.first),
                            ),
                          ),
                    for (final tab in pages)
                      TickerMode(
                        enabled: active.id == tab.id,
                        child: tab.kind == _TabKind.home
                            ? _home(host)
                            : tab.child ?? const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: Scaffold(
        body: SafeArea(
          child: nativeWindow
              ? WindowsWindowFrame(
                  titleBar: (dragRegion) => _tabStrip(
                    sidebar,
                    dragRegion: dragRegion,
                    showDivider: false,
                  ),
                  child: Stack(
                    children: [
                      workspace,
                      if (_pageOpen)
                        Positioned.fill(
                          child: Navigator(
                            key: _pageNavigator,
                            onGenerateRoute: (_) => MaterialPageRoute<void>(
                              builder: (_) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : workspace,
        ),
      ),
    );
  }

  Widget _home(EngineRecord? host) {
    if (host == null) {
      return TildeWelcome(
        onAdd: () => _edit(),
        onQuickConnect: () {
          setState(() => _showSidebar = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _searchFocus.requestFocus();
          });
        },
        onKey: () => importTildeKeyFile(context, engine),
        keyLabel: context.l10n.importSshKey,
      );
    }
    return HostSummary(
      engine: engine,
      host: host,
      onConnect: () => _connect(host, newSession: true),
      onFiles: () => _files(host),
      onEdit: () => _edit(host),
      onMenu: (anchor) => _hostMenu(host, anchor),
      onForwards: () => _page(ForwardsPage(engine: engine, host: host)),
      onSelectSession: (id) {
        final tab = _tabs.where((tab) => tab.sessionId == id).firstOrNull;
        if (tab != null) _select(tab);
      },
    );
  }
}

class HostSummary extends StatelessWidget {
  const HostSummary({
    super.key,
    required this.engine,
    required this.host,
    required this.onConnect,
    required this.onFiles,
    required this.onEdit,
    required this.onMenu,
    required this.onForwards,
    required this.onSelectSession,
  });
  final AndroidEngine engine;
  final EngineRecord host;
  final VoidCallback onConnect, onFiles, onEdit;
  final Future<void> Function() onForwards;
  final ValueChanged<BuildContext> onMenu;
  final ValueChanged<int> onSelectSession;
  @override
  Widget build(BuildContext context) {
    final sessions = engine
        .list('sessions')
        .where((s) => s['hostId'] == host['id'])
        .toList();
    final profile = engine
        .list('profiles')
        .where(
          (p) =>
              p['id'] ==
              (host['profileId'] ?? engine.preferences['defaultProfileId']),
        )
        .firstOrNull;
    final key = engine
        .list('keys')
        .where((k) => k['id'] == host['pubkeyId'])
        .firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TildeHostTile(host: host, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${host['nickname']}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        tildePathText(
                          hostAddress(host),
                          style: TextStyle(
                            fontFamily: tildeMono,
                            fontFamilyFallback: tildeMonoFallback,
                            fontSize: 12.5,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canConnectHost(host))
                    FilledButton.icon(
                      onPressed: onConnect,
                      icon: const Icon(Icons.terminal_outlined, size: 18),
                      label: Text(context.l10n.newTerminal),
                    ),
                  if (host['protocol'] == 'ssh')
                    OutlinedButton.icon(
                      onPressed: onFiles,
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: Text(context.l10n.fileTransfer),
                    ),
                  Builder(
                    builder: (anchor) => IconButton(
                      tooltip: context.l10n.menu((host['nickname']).toString()),
                      onPressed: () => onMenu(anchor),
                      icon: const Icon(Icons.more_vert),
                    ),
                  ),
                ],
              ),
              if (sessions.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text(
                  context.l10n.openSessions,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < sessions.length; i++)
                  ListTile(
                    minTileHeight: 48,
                    title: Text(context.l10n.session((i + 1).toString())),
                    subtitle: Text(
                      sessions[i]['open'] == true
                          ? context.l10n.connected
                          : sessions[i]['connecting'] == true
                          ? context.l10n.connecting
                          : context.l10n.disconnected,
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          onSelectSession(sessions[i]['id'] as int),
                      child: Text(context.l10n.open),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.connect,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: onEdit,
                    child: Text(context.l10n.edit2),
                  ),
                ],
              ),
              for (final item in [
                (context.l10n.address, hostAddress(host)),
                (
                  context.l10n.authentication,
                  key?['nickname']?.toString() ??
                      (host['pubkeyId'] == -1
                          ? context.l10n.tryAllAvailableKeys
                          : context.l10n.useServerSettings),
                ),
                (
                  context.l10n.terminalProfile,
                  profile?['name']?.toString() ??
                      context.l10n.appDefaultProfile,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          item.$1,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(child: tildePathText(item.$2)),
                    ],
                  ),
                ),
              if (host['protocol'] == 'ssh') ...[
                const SizedBox(height: 20),
                _HostForwards(
                  key: ValueKey(host['id']),
                  engine: engine,
                  host: host,
                  onManage: onForwards,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HostForwards extends StatefulWidget {
  const _HostForwards({
    super.key,
    required this.engine,
    required this.host,
    required this.onManage,
  });
  final AndroidEngine engine;
  final EngineRecord host;
  final Future<void> Function() onManage;
  @override
  State<_HostForwards> createState() => _HostForwardsState();
}

class _HostForwardsState extends State<_HostForwards> {
  late Future<dynamic> future = widget.engine.query('forwards', {
    'hostId': widget.host['id'],
  });
  void reload() {
    if (mounted) {
      setState(
        () => future = widget.engine.query('forwards', {
          'hostId': widget.host['id'],
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.portForwarding,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              await widget.onManage();
              reload();
            },
            child: Text(context.l10n.manage),
          ),
        ],
      ),
      FutureBuilder<dynamic>(
        future: future,
        builder: (context, snapshot) => Column(
          children: [
            for (final forward in rows(snapshot.data))
              ListTile(
                minTileHeight: 48,
                title: Text('${forward['nickname'] ?? ''}'),
                subtitle: Text(
                  '${forward['sourcePort'] ?? ''} → ${forward['destAddr'] ?? ''}:${forward['destPort'] ?? ''}',
                  style: const TextStyle(
                    fontFamily: tildeMono,
                    fontFamilyFallback: tildeMonoFallback,
                    fontSize: 12.5,
                  ),
                ),
                onTap: () async {
                  await showForwardEditor(
                    context,
                    widget.engine,
                    widget.host,
                    record: forward,
                  );
                  reload();
                },
              ),
          ],
        ),
      ),
    ],
  );
}
