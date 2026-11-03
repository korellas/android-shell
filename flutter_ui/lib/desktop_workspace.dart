// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
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
  final _tabs = <_WorkspaceTab>[_WorkspaceTab('home', '홈', _TabKind.home)];
  final _console = GlobalKey<ConsolePageState>();
  final _search = TextEditingController();
  final _activeTabKey = GlobalKey();
  double? _lastWidth;
  final _searchFocus = FocusNode();
  String _active = 'home';
  int? _hostId, _terminalId, _setupHostId, _setupSessionId;
  bool? _showSidebar;
  bool _consuming = false;
  String? _hoverHost, _hoverTab;
  AndroidEngine get engine => widget.engine;
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
    final current = ModalRoute.of(context)?.isCurrent != false;
    final selected = engine.state['selectedSession'] as int?;
    setState(() {
      for (final session in engine.list('sessions')) {
        final id = session['id'] as int, key = 'session-${session['id']}';
        if (!_tabs.any((t) => t.id == key)) {
          _tabs.add(
            _WorkspaceTab(
              key,
              '${session['nickname'] ?? '터미널'}',
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
            '${session['nickname'] ?? '터미널'}${siblings.length > 1 ? ' · ${siblings.indexWhere((record) => record['id'] == id) + 1}' : ''}';
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

  void _select(_WorkspaceTab tab) {
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

  Future<void> _connect(EngineRecord host, {bool newSession = false}) async {
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
      '${host['nickname']}',
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
      host == null ? '새 호스트' : '${host['nickname']} 편집',
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
            tab.title = '${record['nickname']} 편집';
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
            '연결 끊고 탭 닫기',
            '${tab.title}의 SSH 연결을 종료하고 탭을 닫을까요?',
            action: '연결 끊고 닫기',
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
          const PopupMenuItem(
            value: 'terminal',
            child: TildeMenuLabel(
              '터미널 열기',
              Icons.terminal_outlined,
              shortcut: 'Enter',
            ),
          ),
        if (host['protocol'] == 'ssh')
          const PopupMenuItem(
            value: 'files',
            child: TildeMenuLabel('파일 전송', Icons.folder_open_outlined),
          ),
        if (canConnectHost(host))
          const PopupMenuItem(
            value: 'new',
            child: TildeMenuLabel(
              '새 세션',
              Icons.add_box_outlined,
              shortcut: 'Ctrl Shift T',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'edit',
          child: TildeMenuLabel('편집', Icons.edit_outlined),
        ),
        PopupMenuItem(
          value: 'favorite',
          child: TildeMenuLabel(
            host['favorite'] == true ? '즐겨찾기에서 제거' : '즐겨찾기에 추가',
            Icons.star_border,
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: TildeMenuLabel('복제', Icons.content_copy_outlined),
        ),
        if (host['protocol'] == 'ssh')
          const PopupMenuItem(
            value: 'forwards',
            child: TildeMenuLabel('포트 포워딩', Icons.swap_horiz),
          ),
        if (connected) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'disconnect',
            child: TildeMenuLabel('연결 끊기', Icons.link_off_outlined),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: TildeMenuLabel(
            '삭제',
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
        await _connect(host);
      case 'files':
        _files(host);
      case 'new':
        await _connect(host, newSession: true);
      case 'edit':
        _edit(host);
      case 'favorite':
        await runEngine(context, engine, 'host.favorite', {'id': host['id']});
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
      case 'forwards':
        _page(ForwardsPage(engine: engine, host: host));
      case 'disconnect':
        if (await confirm(
              context,
              '연결 끊기',
              '${host['nickname']}의 연결을 모두 종료할까요?',
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

  Future<void> _page(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  final _handledKeys = <LogicalKeyboardKey>{};
  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent && _handledKeys.remove(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
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
      final i = _tabs.indexOf(active);
      _select(_tabs[(i + (kb.isShiftPressed ? -1 : 1)) % _tabs.length]);
    } else if (kb.isControlPressed &&
        kb.isShiftPressed &&
        key == LogicalKeyboardKey.keyT) {
      final host = engine
          .list('hosts')
          .where((h) => h['id'] == (active.hostId ?? _hostId))
          .firstOrNull;
      if (host != null) unawaited(_connect(host, newSession: true));
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: TildeWordmark(size: 23),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('새 호스트'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              focusNode: _searchFocus,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '검색 또는 ssh user@host',
                prefixIcon: Icon(Icons.search, size: 18),
                suffixIcon: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Ctrl K',
                    style: TextStyle(fontFamily: tildeMono, fontSize: 11),
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _submit,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '호스트',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                if (engine.list('hosts').isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text('아직 호스트가 없습니다'),
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
                          onDoubleTap: () => _connect(host),
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
                                        tooltip: '${host['nickname']} 메뉴',
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
                  title: const Text('설정'),
                  trailing: Text(
                    'Ctrl ,',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => _page(SettingsPage(engine: engine)),
                ),
                ListTile(
                  minTileHeight: 36,
                  leading: const Icon(Icons.help_outline, size: 18),
                  title: const Text('도움말·로그'),
                  onTap: () => _page(HelpPage(engine: engine)),
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
  Widget _tabStrip(bool sidebar) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          if (!sidebar)
            IconButton(
              tooltip: '호스트 목록 (Ctrl B)',
              onPressed: () => setState(() => _showSidebar = true),
              icon: const Icon(Icons.menu),
            ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final tab in _tabs)
                  MouseRegion(
                    onEnter: (_) => setState(() => _hoverTab = tab.id),
                    onExit: (_) => setState(() => _hoverTab = null),
                    child: Material(
                      color: tab.id == _active
                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                          : Colors.transparent,
                      child: Semantics(
                        key: ValueKey('workspace-tab-${tab.id}'),
                        selected: tab.id == _active,
                        child: InkWell(
                          key: tab.id == _active ? _activeTabKey : null,
                          onTap: () => _select(tab),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 86,
                              maxWidth: 210,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_icon(tab), size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      tab.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13.5),
                                    ),
                                  ),
                                  if (tab.dirty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.tertiary,
                                      ),
                                    ),
                                  if (tab.kind != _TabKind.home)
                                    Opacity(
                                      opacity:
                                          tab.id == _active ||
                                              _hoverTab == tab.id
                                          ? 1
                                          : 0,
                                      child: IconButton(
                                        tooltip: '${tab.title} 탭 닫기',
                                        onPressed: () => _close(tab),
                                        icon: const Icon(Icons.close, size: 14),
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 12),
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
          Tooltip(
            message: '새 탭 (Ctrl Shift T)',
            child: TextButton.icon(
              onPressed: () {
                final host = engine
                    .list('hosts')
                    .where((h) => h['id'] == (active.hostId ?? _hostId))
                    .firstOrNull;
                if (host != null) {
                  _connect(host, newSession: true);
                } else {
                  _searchFocus.requestFocus();
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('새 탭'),
            ),
          ),
          if (active.kind == _TabKind.terminal)
            Builder(
              builder: (anchor) => IconButton(
                tooltip: '터미널 메뉴',
                onPressed: () => _console.currentState?.openMenu(anchor),
                icon: const Icon(Icons.more_horiz),
              ),
            ),
        ],
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
    final currentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (sidebar) ...[
                _sidebar(hosts),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Column(
                  children: [
                    _tabStrip(sidebar),
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
                                    startKeySetup:
                                        _setupSessionId == _terminalId,
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
          ),
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
        keyLabel: 'SSH 키 가져오기',
      );
    }
    return HostSummary(
      engine: engine,
      host: host,
      onConnect: () => _connect(host),
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
          constraints: const BoxConstraints(maxWidth: 680),
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
                        Text(
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
                      label: const Text('터미널 열기'),
                    ),
                  if (host['protocol'] == 'ssh')
                    OutlinedButton.icon(
                      onPressed: onFiles,
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: const Text('파일 전송'),
                    ),
                  Builder(
                    builder: (anchor) => IconButton(
                      tooltip: '${host['nickname']} 메뉴',
                      onPressed: () => onMenu(anchor),
                      icon: const Icon(Icons.more_vert),
                    ),
                  ),
                ],
              ),
              if (sessions.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Text(
                  '열린 세션',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < sessions.length; i++)
                  ListTile(
                    minTileHeight: 48,
                    title: Text('세션 ${i + 1}'),
                    subtitle: Text(
                      sessions[i]['open'] == true
                          ? '연결됨'
                          : sessions[i]['connecting'] == true
                          ? '연결 중'
                          : '연결 종료',
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          onSelectSession(sessions[i]['id'] as int),
                      child: const Text('탭으로 이동'),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '연결',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(onPressed: onEdit, child: const Text('편집')),
                ],
              ),
              for (final item in [
                ('주소', hostAddress(host)),
                (
                  '인증',
                  key?['nickname']?.toString() ??
                      (host['pubkeyId'] == -1 ? '사용 가능한 키 모두 시도' : '서버 설정에 따름'),
                ),
                ('터미널 프로필', profile?['name']?.toString() ?? '앱 기본 프로필'),
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
                      Expanded(child: Text(item.$2)),
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
          const Expanded(
            child: Text(
              '포트 포워딩',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              await widget.onManage();
              reload();
            },
            child: const Text('관리'),
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
