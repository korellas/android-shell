// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sftp_file_operations.dart';
import 'transfer.dart';
import 'file_drag_scope.dart';
import '../tilde_design.dart';
import '../tilde_controls.dart';
import '../l10n/strings.dart';

enum FileSort { name, size, modified }

enum FileAction {
  open,
  download,
  rename,
  delete,
  info,
  copy,
  cut,
  paste,
  move,
  path,
  permissions,
}

class FileBrowserListing extends StatefulWidget {
  const FileBrowserListing({
    super.key,
    required this.entries,
    required this.path,
    required this.loading,
    required this.onOpen,
    required this.onDownload,
    this.onExport,
    this.onRename,
    this.onDelete,
    this.onSelectionChanged,
    this.onDeleteMany,
    this.onDownloadMany,
    this.onCopy,
    this.onCut,
    this.onPaste,
    this.onMove,
    this.onPermissions,
    this.onDropInto,
    this.onRenameTo,
    this.onBack,
    this.onForward,
    this.onUp,
    this.onRefresh,
    this.onAddress,
    this.onNewFolder,
    this.locations,
    this.isLocked,
    this.searchController,
    this.searchFocus,
    this.showToolbar = true,
    this.showSelectionToolbar = true,
  });
  final TextEditingController? searchController;
  final FocusNode? searchFocus;
  final bool showToolbar, showSelectionToolbar;
  final ValueChanged<List<SftpName>>? onSelectionChanged,
      onDeleteMany,
      onDownloadMany,
      onCopy,
      onCut,
      onMove,
      onPermissions;
  final VoidCallback? onPaste,
      onBack,
      onForward,
      onUp,
      onRefresh,
      onAddress,
      onNewFolder;
  final Future<String?> Function(SftpName, String)? onRenameTo;
  final bool Function(SftpName)? isLocked;
  final Widget? locations;
  final Future<void> Function(SftpName, List<String>)? onDropInto;
  final FileExport? onExport;
  final List<SftpName> entries;
  final String path;
  final bool loading;
  final ValueChanged<SftpName>? onOpen, onDownload, onRename, onDelete;

  @override
  FileBrowserListingState createState() => FileBrowserListingState();
}

class FileBrowserListingState extends State<FileBrowserListing> {
  final _localSearch = TextEditingController();
  TextEditingController get _search => widget.searchController ?? _localSearch;
  final _localSearchFocus = FocusNode(),
      _listFocus = FocusNode(),
      _renameFocus = FocusNode();
  FocusNode get _searchFocus => widget.searchFocus ?? _localSearchFocus;
  final _renameText = TextEditingController();
  void clearSelection() {
    setState(_selected.clear);
    _notify();
  }

  void filterChanged() => _filterChanged();
  Future<void> showViewMenu(BuildContext anchor) => _viewMenu(anchor);
  final _scroll = ScrollController();
  final _selected = <String>{};
  final _pointerExtended = <String, bool>{};
  final _views =
      <String, ({Set<String> selected, String query, double offset})>{};
  String? _anchor, _focused, _editing, _renameError, _hover;
  final _columns = <String>{'size', 'modified', 'permissions'};
  final _widths = <String, double>{
    'size': 90,
    'modified': 155,
    'uid': 80,
    'gid': 80,
    'permissions': 110,
  };
  List<SftpName> get _selection => widget.entries
      .where((entry) => _selected.contains(entry.filename))
      .toList();
  bool _locked(SftpName entry) => widget.isLocked?.call(entry) ?? false;
  void _notify() => widget.onSelectionChanged?.call(_selection);
  void _filterChanged() {
    setState(() {
      final visible = _visible.map((entry) => entry.filename).toSet();
      _selected.removeWhere((name) => !visible.contains(name));
    });
    _notify();
  }

  void _select(SftpName entry, {bool? toggle, bool? range}) {
    final entries = _visible;
    final shift = range ?? HardwareKeyboard.instance.isShiftPressed;
    final control = toggle ?? HardwareKeyboard.instance.isControlPressed;
    setState(() {
      if (shift &&
          _anchor != null &&
          entries.any((entry) => entry.filename == _anchor)) {
        final a = entries.indexWhere((entry) => entry.filename == _anchor),
            b = entries.indexOf(entry);
        if (!control) _selected.clear();
        _selected.addAll(
          entries
              .sublist(a < b ? a : b, (a > b ? a : b) + 1)
              .map((entry) => entry.filename),
        );
      } else if (control) {
        _selected.contains(entry.filename)
            ? _selected.remove(entry.filename)
            : _selected.add(entry.filename);
        _anchor = entry.filename;
      } else {
        _selected
          ..clear()
          ..add(entry.filename);
        _anchor = entry.filename;
      }
      _focused = entry.filename;
    });
    _listFocus.requestFocus();
    _notify();
  }

  void _beginRename(SftpName entry) {
    if (widget.onRenameTo == null) {
      widget.onRename?.call(entry);
      return;
    }
    _renameText.text = entry.filename;
    final dot = entry.filename.lastIndexOf('.');
    _renameText.selection = TextSelection(
      baseOffset: 0,
      extentOffset: dot > 0 ? dot : entry.filename.length,
    );
    setState(() {
      _editing = entry.filename;
      _renameError = null;
    });
    _renameFocus.requestFocus();
  }

  Future<void> _commitRename(SftpName entry) async {
    final name = _renameText.text;
    final invalid = remoteNameError(name);
    if (invalid != null) {
      setState(() => _renameError = invalid);
      return;
    }
    final error = await widget.onRenameTo!(entry, name);
    if (!mounted) return;
    setState(() {
      _renameError = error;
      if (error == null) {
        _editing = null;
        _selected
          ..remove(entry.filename)
          ..add(name);
        _focused = name;
      }
    });
    if (error == null) {
      _notify();
      _listFocus.requestFocus();
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        FocusManager.instance.primaryFocus != _listFocus) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey,
        ctrl = HardwareKeyboard.instance.isControlPressed,
        alt = HardwareKeyboard.instance.isAltPressed,
        shift = HardwareKeyboard.instance.isShiftPressed;
    final selected = _selection;
    final focused = widget.entries
        .where((entry) => entry.filename == _focused)
        .firstOrNull;
    if (ctrl && key == LogicalKeyboardKey.keyA) {
      setState(() => _selected.addAll(_visible.map((entry) => entry.filename)));
      _notify();
    } else if (ctrl && key == LogicalKeyboardKey.keyF) {
      _searchFocus.requestFocus();
    } else if (ctrl && key == LogicalKeyboardKey.keyL) {
      widget.onAddress?.call();
    } else if (ctrl && shift && key == LogicalKeyboardKey.keyN) {
      widget.onNewFolder?.call();
    } else if (ctrl && key == LogicalKeyboardKey.keyC) {
      widget.onCopy?.call(selected);
    } else if (ctrl && key == LogicalKeyboardKey.keyX) {
      widget.onCut?.call(selected);
    } else if (ctrl && key == LogicalKeyboardKey.keyV) {
      widget.onPaste?.call();
    } else if (key == LogicalKeyboardKey.f2 &&
        selected.length == 1 &&
        !_locked(selected.single)) {
      _beginRename(selected.single);
    } else if (key == LogicalKeyboardKey.delete &&
        selected.isNotEmpty &&
        !selected.any(_locked)) {
      widget.onDeleteMany?.call(selected);
    } else if (key == LogicalKeyboardKey.f5) {
      widget.onRefresh?.call();
    } else if (alt && key == LogicalKeyboardKey.arrowLeft) {
      widget.onBack?.call();
    } else if (alt && key == LogicalKeyboardKey.arrowRight) {
      widget.onForward?.call();
    } else if (key == LogicalKeyboardKey.backspace ||
        alt && key == LogicalKeyboardKey.arrowUp) {
      widget.onUp?.call();
    } else if (key == LogicalKeyboardKey.escape) {
      setState(_selected.clear);
      _notify();
    } else if (key == LogicalKeyboardKey.enter && focused != null) {
      widget.onOpen?.call(focused);
    } else if (shift && key == LogicalKeyboardKey.f10 && focused != null) {
      final box = context.findRenderObject()! as RenderBox;
      _menu(context, focused, box.localToGlobal(const Offset(100, 100)));
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.home ||
        key == LogicalKeyboardKey.end) {
      final entries = _visible;
      if (entries.isNotEmpty) {
        final old = entries.indexWhere((entry) => entry.filename == _focused);
        final index =
            (key == LogicalKeyboardKey.home
                    ? 0
                    : key == LogicalKeyboardKey.end
                    ? entries.length - 1
                    : old + (key == LogicalKeyboardKey.arrowDown ? 1 : -1))
                .clamp(0, entries.length - 1);
        _select(entries[index], toggle: false, range: shift);
        if (_scroll.hasClients) {
          _scroll.animateTo(
            (index * 64.0).clamp(0, _scroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  bool _showHidden = false, _descending = false;
  FileSort _sort = FileSort.name;

  bool _viewLoaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_viewLoaded) {
      _viewLoaded = true;
      unawaited(_loadView());
    }
  }

  Future<void> _loadView() async {
    try {
      final saved = await FileDragScope.of(
        context,
      )?.readSetting?.call('fileView');
      if (saved is! Map || !mounted) return;
      setState(() {
        _showHidden = saved['hidden'] == true;
        if (saved['columns'] is List) {
          _columns
            ..clear()
            ..addAll(
              (saved['columns'] as List).whereType<String>().where(
                _widths.containsKey,
              ),
            );
        }
        _descending = saved['descending'] == true;
        _sort =
            FileSort.values
                .where((sort) => sort.name == saved['sort'])
                .firstOrNull ??
            FileSort.name;
        final widths = saved['widths'];
        if (widths is Map) {
          for (final key in _widths.keys) {
            final value = widths[key];
            if (value is num && value.isFinite) {
              _widths[key] = value.toDouble().clamp(65, 240);
            }
          }
        }
      });
    } catch (_) {
      // View preferences never prevent browsing.
    }
  }

  void _saveView() {
    unawaited(
      FileDragScope.of(context)?.writeSetting
          ?.call('fileView', {
            'hidden': _showHidden,
            'descending': _descending,
            'sort': _sort.name,
            'widths': {..._widths},
            'columns': _columns.toList(),
          })
          .catchError((Object _) {}),
    );
  }

  void _sortColumn(FileSort next) {
    setState(() {
      if (_sort == next) {
        _descending = !_descending;
      } else {
        _sort = next;
        _descending = false;
      }
    });
    _saveView();
  }

  @override
  void didUpdateWidget(FileBrowserListing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _views[oldWidget.path] = (
        selected: {..._selected},
        query: _search.text,
        offset: _scroll.hasClients ? _scroll.offset : 0,
      );
      final view = _views[widget.path];
      _selected
        ..clear()
        ..addAll(view?.selected ?? {});
      _search.text = view?.query ?? '';
      _focused = view?.selected.firstOrNull;
      _anchor = _focused;
      _editing = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          _scroll.jumpTo(
            (view?.offset ?? 0).clamp(0, _scroll.position.maxScrollExtent),
          );
        }
        _notify();
      });
    }
    _selected.removeWhere(
      (name) => !widget.entries.any((entry) => entry.filename == name),
    );
  }

  @override
  void dispose() {
    _localSearch.dispose();
    _localSearchFocus.dispose();
    _listFocus.dispose();
    _renameFocus.dispose();
    _renameText.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<SftpName> get _visible {
    final query = _search.text.toLowerCase();
    final entries = widget.entries
        .where(
          (entry) =>
              entry.filename != '.' &&
              entry.filename != '..' &&
              (_showHidden || !entry.filename.startsWith('.')) &&
              entry.filename.toLowerCase().contains(query),
        )
        .toList();
    entries.sort((a, b) {
      if (a.attr.isDirectory != b.attr.isDirectory) {
        return a.attr.isDirectory ? -1 : 1;
      }
      final left = _sort == FileSort.size ? a.attr.size : a.attr.modifyTime;
      final right = _sort == FileSort.size ? b.attr.size : b.attr.modifyTime;
      int order;
      if (_sort == FileSort.name) {
        order = naturalFileCompare(a.filename, b.filename);
      } else {
        // Missing metadata stays last in either direction.
        if (left == null && right != null) return 1;
        if (right == null && left != null) return -1;
        order = left == null ? 0 : left.compareTo(right!);
      }
      if (order == 0) order = a.filename.compareTo(b.filename);
      return _descending ? -order : order;
    });
    return entries;
  }

  Widget _controls(BuildContext context, {bool drawer = false}) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [if (widget.locations != null) widget.locations!],
    ),
  );

  Future<void> _viewMenu(BuildContext anchor) => showTildeSheet<void>(
    context: anchor,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, refresh) {
        void update(VoidCallback change) {
          setState(change);
          _saveView();
          refresh(() {});
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(anchor.l10n.view, style: Theme.of(c).textTheme.titleLarge),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(anchor.l10n.showHiddenFilesAndFolders),
                value: _showHidden,
                onChanged: (value) {
                  update(() => _showHidden = value);
                  _filterChanged();
                },
              ),
              tildeSegments(
                c,
                anchor.l10n.sort,
                [
                  (FileSort.name, anchor.l10n.name),
                  (FileSort.size, anchor.l10n.size),
                  (FileSort.modified, anchor.l10n.modified),
                ],
                _sort,
                (value) => update(() => _sort = value as FileSort),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(anchor.l10n.descending),
                value: _descending,
                onChanged: (value) =>
                    update(() => _descending = value ?? false),
              ),
              const SizedBox(height: 12),
              Text(anchor.l10n.visibleColumns),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final column in _widths.keys)
                    FilterChip(
                      label: Text(_columnLabel(column)),
                      selected: _columns.contains(column),
                      showCheckmark: true,
                      avatar: _columns.contains(column)
                          ? null
                          : const Icon(Icons.add, size: 16),
                      onSelected: (value) => update(() {
                        value ? _columns.add(column) : _columns.remove(column);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text(anchor.l10n.close2),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  String _modified(int? seconds) {
    if (seconds == null) return '—';
    final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)} ${pad(time.hour)}:${pad(time.minute)}';
  }

  String _columnLabel(String column) => switch (column) {
    'size' => context.l10n.size,
    'modified' => context.l10n.modified,
    'uid' => context.l10n.ownerUid,
    'gid' => context.l10n.groupGid,
    'permissions' => context.l10n.permissions,
    _ => column,
  };
  String _value(SftpName entry, String column) => switch (column) {
    'size' =>
      entry.attr.isDirectory || entry.attr.size == null
          ? '—'
          : formatBytes(entry.attr.size!),
    'modified' => _modified(entry.attr.modifyTime),
    'uid' => '${entry.attr.userID ?? '—'}',
    'gid' => '${entry.attr.groupID ?? '—'}',
    'permissions' =>
      entry.attr.mode == null ? '—' : remotePermissions(entry.attr.mode!.value),
    _ => '',
  };
  Widget _metadata(SftpName entry) => Row(
    children: [
      for (final column in _widths.keys.where(_columns.contains))
        SizedBox(
          width: _widths[column],
          child: Text(
            _value(entry, column),
            maxLines: 1,
            style: TextStyle(
              fontSize: 12.5,
              fontFamily: column == 'permissions' ? tildeMono : null,
            ),
          ),
        ),
    ],
  );

  List<PopupMenuEntry<FileAction>> _actions(SftpName entry) => [
    PopupMenuItem(
      value: FileAction.open,
      enabled: widget.onOpen != null,
      child: TildeMenuLabel(
        entry.attr.isDirectory ? context.l10n.open : context.l10n.preview,
        entry.attr.isDirectory
            ? Icons.folder_open_outlined
            : Icons.description_outlined,
        shortcut: 'Enter',
      ),
    ),
    PopupMenuItem(
      value: FileAction.download,
      enabled: widget.onDownload != null,
      child: TildeMenuLabel(context.l10n.download, Icons.download_outlined),
    ),
    const PopupMenuDivider(),
    if (widget.onCopy != null)
      PopupMenuItem(
        value: FileAction.copy,
        child: TildeMenuLabel(
          context.l10n.copy2,
          Icons.content_copy_outlined,
          shortcut: 'Ctrl C',
        ),
      ),
    if (widget.onCut != null)
      PopupMenuItem(
        value: FileAction.cut,
        enabled: !_selection.any(_locked),
        child: TildeMenuLabel(
          context.l10n.cut,
          Icons.content_cut_outlined,
          shortcut: 'Ctrl X',
        ),
      ),
    if (widget.onPaste != null)
      PopupMenuItem(
        value: FileAction.paste,
        child: TildeMenuLabel(
          context.l10n.paste,
          Icons.content_paste_outlined,
          shortcut: 'Ctrl V',
        ),
      ),
    PopupMenuItem(
      value: FileAction.rename,
      enabled:
          (widget.onRename != null || widget.onRenameTo != null) &&
          _selection.length <= 1 &&
          !_locked(entry),
      child: TildeMenuLabel(
        context.l10n.rename,
        Icons.drive_file_rename_outline,
        shortcut: 'F2',
      ),
    ),
    if (widget.onMove != null)
      PopupMenuItem(
        value: FileAction.move,
        enabled: !_selection.any(_locked),
        child: TildeMenuLabel(
          context.l10n.move3,
          Icons.drive_file_move_outlined,
        ),
      ),
    const PopupMenuDivider(),
    if (tildePointer(context))
      PopupMenuItem(
        value: FileAction.path,
        child: TildeMenuLabel(context.l10n.copyPath, Icons.link_outlined),
      ),
    PopupMenuItem(
      value: FileAction.info,
      child: TildeMenuLabel(context.l10n.info, Icons.info_outline),
    ),
    if (tildePointer(context) && widget.onPermissions != null)
      PopupMenuItem(
        value: FileAction.permissions,
        enabled: !_selection.any(_locked),
        child: TildeMenuLabel(
          context.l10n.changePermissions3,
          Icons.security_outlined,
        ),
      ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: FileAction.delete,
      enabled:
          (widget.onDelete != null || widget.onDeleteMany != null) &&
          !_selection.any(_locked) &&
          !_locked(entry),
      child: TildeMenuLabel(
        context.l10n.delete,
        Icons.delete_outline,
        danger: true,
        shortcut: 'Del',
      ),
    ),
  ];

  void _action(SftpName entry, FileAction action) {
    switch (action) {
      case FileAction.open:
        widget.onOpen?.call(entry);
      case FileAction.download:
        widget.onDownloadMany != null
            ? widget.onDownloadMany!(
                _selected.contains(entry.filename) ? _selection : [entry],
              )
            : widget.onDownload?.call(entry);
      case FileAction.rename:
        _beginRename(entry);
      case FileAction.delete:
        widget.onDeleteMany != null
            ? widget.onDeleteMany!(
                _selected.contains(entry.filename) ? _selection : [entry],
              )
            : widget.onDelete?.call(entry);
      case FileAction.copy:
        widget.onCopy?.call(_selection);
      case FileAction.cut:
        widget.onCut?.call(_selection);
      case FileAction.paste:
        widget.onPaste?.call();
      case FileAction.move:
        widget.onMove?.call(_selection);
      case FileAction.permissions:
        widget.onPermissions?.call(_selection);
      case FileAction.path:
        Clipboard.setData(
          ClipboardData(
            text: (_selected.contains(entry.filename) ? _selection : [entry])
                .map((entry) => remoteChild(widget.path, entry.filename))
                .join('\n'),
          ),
        );
      case FileAction.info:
        showTildeSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (c) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.fileInformation,
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  for (final field in [
                    (context.l10n.name, entry.filename),
                    (
                      context.l10n.path,
                      remoteChild(widget.path, entry.filename),
                    ),
                    (
                      context.l10n.type2,
                      entry.attr.isDirectory
                          ? context.l10n.folder
                          : entry.attr.isSymbolicLink
                          ? context.l10n.symbolicLink
                          : context.l10n.file,
                    ),
                    (
                      context.l10n.size,
                      entry.attr.size == null
                          ? '—'
                          : formatBytes(entry.attr.size!),
                    ),
                    (context.l10n.modified, _modified(entry.attr.modifyTime)),
                    (context.l10n.ownerUid, '${entry.attr.userID ?? '—'}'),
                    (context.l10n.groupGid, '${entry.attr.groupID ?? '—'}'),
                    (
                      context.l10n.permissions,
                      entry.attr.mode == null
                          ? '—'
                          : '${remotePermissions(entry.attr.mode!.value)} (${(entry.attr.mode!.value & 0xfff).toRadixString(8).padLeft(4, '0')})',
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(
                              field.$1,
                              style: Theme.of(c).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              field.$2,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(
                            text: remoteChild(widget.path, entry.filename),
                          ),
                        ),
                        child: Text(context.l10n.copyPath),
                      ),
                      if (widget.onPermissions != null)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(c);
                            widget.onPermissions!([entry]);
                          },
                          child: Text(context.l10n.changePermissions),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Future<void> _menu(
    BuildContext context,
    SftpName entry,
    Offset position,
  ) async {
    final contextStrings = context.l10n;
    if (!_selected.contains(entry.filename)) {
      _select(entry, toggle: false, range: false);
    }
    final action = await TildeItemMenu.show<FileAction>(
      context,
      title: entry.filename,
      subtitle: entry.attr.isDirectory
          ? contextStrings.folder
          : entry.attr.size == null
          ? null
          : formatBytes(entry.attr.size!),
      icon: entry.attr.isDirectory
          ? Icons.folder_outlined
          : Icons.description_outlined,
      position: position,
      itemBuilder: (_) => _actions(entry),
    );
    if (action != null && mounted) _action(entry, action);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = tildePointer(context) && constraints.maxWidth >= 900;
      final desktop = tildePointer(context);
      final horizontalPadding = desktop ? 12.0 : 16.0;
      final leadingExtent = !desktop && _selected.isNotEmpty
          ? 48.0
          : desktop
          ? 22.0
          : 24.0;
      final actionExtent = desktop ? 40.0 : 48.0;
      final entries = _visible;
      final list = LayoutBuilder(
        builder: (context, listConstraints) {
          final details =
              tildePointer(context) || listConstraints.maxWidth >= 800;
          final tableWidth = details
              ? (_widths.entries
                            .where((e) => _columns.contains(e.key))
                            .fold<double>(0, (sum, e) => sum + e.value) +
                        320)
                    .clamp(listConstraints.maxWidth, double.infinity)
              : listConstraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: listConstraints.maxHeight,
              child: Column(
                children: [
                  if (widget.showToolbar)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        8,
                        horizontalPadding,
                        12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _search,
                              focusNode: _searchFocus,
                              onChanged: (_) {
                                setState(
                                  () => _selected.removeWhere(
                                    (name) => !_visible.any(
                                      (entry) => entry.filename == name,
                                    ),
                                  ),
                                );
                                _notify();
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: context.l10n.findInCurrentFolder,
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: IconButton(
                                  tooltip: context.l10n.clearSearch,
                                  onPressed: () {
                                    _search.clear();
                                    _filterChanged();
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (anchor) => TextButton.icon(
                              onPressed: () => _viewMenu(anchor),
                              icon: const Icon(Icons.tune, size: 18),
                              label: Text(context.l10n.view),
                            ),
                          ),
                          if (!wide)
                            Builder(
                              builder: (c) => TextButton(
                                onPressed: () => Scaffold.of(c).openEndDrawer(),
                                child: Text(context.l10n.location),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (widget.showSelectionToolbar)
                    SizedBox(
                      height: tildePointer(context) ? 36 : null,
                      child: _selected.isEmpty
                          ? const SizedBox.shrink()
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      context.l10n.selected2(
                                        (_selected.length).toString(),
                                        (formatBytes(
                                          _selection.fold<int>(
                                            0,
                                            (sum, entry) =>
                                                sum +
                                                (entry.attr.isDirectory
                                                    ? 0
                                                    : entry.attr.size ?? 0),
                                          ),
                                        )).toString(),
                                      ),
                                    ),
                                  ),
                                  if (widget.onDownloadMany != null)
                                    TextButton.icon(
                                      onPressed: () =>
                                          widget.onDownloadMany!(_selection),
                                      icon: const Icon(Icons.download_outlined),
                                      label: Text(context.l10n.download),
                                    ),
                                  if (widget.onCopy != null)
                                    TextButton(
                                      onPressed: () =>
                                          widget.onCopy!(_selection),
                                      child: Text(context.l10n.copy2),
                                    ),
                                  if (widget.onMove != null)
                                    TextButton(
                                      onPressed: _selection.any(_locked)
                                          ? null
                                          : () => widget.onMove!(_selection),
                                      child: Text(context.l10n.move2),
                                    ),
                                  if (widget.onDeleteMany != null)
                                    TextButton(
                                      onPressed: _selection.any(_locked)
                                          ? null
                                          : () => widget.onDeleteMany!(
                                              _selection,
                                            ),
                                      child: Text(context.l10n.delete),
                                    ),
                                  IconButton(
                                    tooltip: context.l10n.clearSelection,
                                    onPressed: () {
                                      setState(_selected.clear);
                                      _notify();
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  if (details)
                    ListTile(
                      minTileHeight: desktop ? 32 : 40,
                      minVerticalPadding: 0,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      minLeadingWidth: leadingExtent,
                      horizontalTitleGap: 12,
                      dense: desktop,
                      leading: SizedBox(width: leadingExtent),
                      trailing: SizedBox(width: actionExtent * 2),
                      titleTextStyle: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                      title: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _sortColumn(FileSort.name),
                              child: Text(context.l10n.name),
                            ),
                          ),
                          for (final column in _widths.entries.where(
                            (column) => _columns.contains(column.key),
                          ))
                            SizedBox(
                              width: column.value,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: column.key == 'size'
                                          ? () => _sortColumn(FileSort.size)
                                          : column.key == 'modified'
                                          ? () => _sortColumn(FileSort.modified)
                                          : null,
                                      child: Text(_columnLabel(column.key)),
                                    ),
                                  ),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.resizeColumn,
                                    child: GestureDetector(
                                      onHorizontalDragEnd: (_) => _saveView(),
                                      onHorizontalDragUpdate: (event) =>
                                          setState(
                                            () => _widths[column.key] =
                                                (column.value + event.delta.dx)
                                                    .clamp(65, 240),
                                          ),
                                      child: const SizedBox(
                                        width: 12,
                                        height: 24,
                                        child: VerticalDivider(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const Divider(height: 1),
                  if (widget.path != '/' && widget.onUp != null)
                    ListTile(
                      minTileHeight: desktop ? 36 : 56,
                      minVerticalPadding: desktop ? 0 : 4,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      minLeadingWidth: leadingExtent,
                      horizontalTitleGap: 12,
                      dense: desktop,
                      leading: SizedBox(
                        width: leadingExtent,
                        child: Icon(
                          Icons.drive_folder_upload,
                          size: desktop ? 22 : 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Semantics(
                        label: context.l10n.parentFolder,
                        excludeSemantics: true,
                        child: Tooltip(
                          message: context.l10n.parentFolderBackspace,
                          child: Text(
                            '..',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      onTap: widget.onUp,
                    ),
                  Expanded(
                    child: Focus(
                      focusNode: _listFocus,
                      autofocus: true,
                      onKeyEvent: _key,
                      child: entries.isEmpty
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _listFocus.requestFocus,
                              child: Center(
                                child: Text(
                                  widget.loading
                                      ? context.l10n.loading
                                      : widget.entries.isEmpty
                                      ? context.l10n.noFilesToDisplay
                                      : context.l10n.noMatchingFiles,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final tile = ListTile(
                                  minTileHeight: desktop ? 36 : 56,
                                  minVerticalPadding: desktop ? 0 : 4,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding,
                                  ),
                                  minLeadingWidth: leadingExtent,
                                  horizontalTitleGap: 12,
                                  dense: desktop,
                                  selected: _selected.contains(entry.filename),
                                  selectedTileColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: .4),
                                  leading: SizedBox(
                                    width: leadingExtent,
                                    child: _selected.isNotEmpty && !desktop
                                        ? Checkbox(
                                            value: _selected.contains(
                                              entry.filename,
                                            ),
                                            onChanged: (_) => _select(
                                              entry,
                                              toggle: true,
                                              range: false,
                                            ),
                                          )
                                        : Icon(
                                            entry.attr.isDirectory
                                                ? Icons.folder
                                                : entry.attr.isSymbolicLink
                                                ? Icons.link
                                                : Icons
                                                      .insert_drive_file_outlined,
                                            size: desktop ? 22 : 24,
                                            color: entry.attr.isDirectory
                                                ? Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.amber.shade400
                                                      : Colors.amber.shade800
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                  ),
                                  title: GestureDetector(
                                    onDoubleTap:
                                        desktop && _editing != entry.filename
                                        ? () => widget.onOpen?.call(entry)
                                        : null,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _editing == entry.filename
                                              ? CallbackShortcuts(
                                                  bindings: {
                                                    const SingleActivator(
                                                      LogicalKeyboardKey.escape,
                                                    ): () {
                                                      setState(
                                                        () => _editing = null,
                                                      );
                                                      _listFocus.requestFocus();
                                                    },
                                                  },
                                                  child: TextFormField(
                                                    controller: _renameText,
                                                    focusNode: _renameFocus,
                                                    autofocus: true,
                                                    onFieldSubmitted: (_) =>
                                                        _commitRename(entry),
                                                    decoration: InputDecoration(
                                                      errorText: _renameError,
                                                      isDense: true,
                                                      suffixIcon: IconButton(
                                                        tooltip: context
                                                            .l10n
                                                            .applyNewName,
                                                        onPressed: () =>
                                                            _commitRename(
                                                              entry,
                                                            ),
                                                        icon: const Icon(
                                                          Icons.check,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  entry.filename,
                                                  maxLines: desktop ? 1 : 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                        ),
                                        if (details) _metadata(entry),
                                      ],
                                    ),
                                  ),
                                  subtitle:
                                      desktop ||
                                          details ||
                                          entry.attr.isDirectory ||
                                          entry.attr.size == null
                                      ? null
                                      : Text(formatBytes(entry.attr.size!)),
                                  onTap: () {
                                    if (desktop) {
                                      if (!(_pointerExtended[entry.filename] ??
                                          false)) {
                                        _select(
                                          entry,
                                          toggle: false,
                                          range: false,
                                        );
                                      }
                                    } else if (_selected.isNotEmpty) {
                                      _select(
                                        entry,
                                        toggle: true,
                                        range: false,
                                      );
                                    } else {
                                      widget.onOpen?.call(entry);
                                    }
                                  },
                                  onLongPress: () {
                                    if (!_selected.contains(entry.filename)) {
                                      _select(
                                        entry,
                                        toggle: false,
                                        range: false,
                                      );
                                    }
                                    final box =
                                        context.findRenderObject()!
                                            as RenderBox;
                                    _menu(
                                      context,
                                      entry,
                                      box.localToGlobal(
                                        Offset(
                                          box.size.width / 2,
                                          box.size.height / 2,
                                        ),
                                      ),
                                    );
                                  },
                                  trailing: Visibility(
                                    visible:
                                        !desktop || _hover == entry.filename,
                                    maintainSize: true,
                                    maintainState: true,
                                    maintainAnimation: true,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: actionExtent,
                                          child: entry.attr.isDirectory
                                              ? const Icon(Icons.chevron_right)
                                              : IconButton(
                                                  tooltip:
                                                      context.l10n.download,
                                                  onPressed:
                                                      widget.onDownload == null
                                                      ? null
                                                      : () =>
                                                            widget.onDownload!(
                                                              entry,
                                                            ),
                                                  icon: const Icon(
                                                    Icons.download_outlined,
                                                  ),
                                                ),
                                        ),
                                        SizedBox(
                                          width: actionExtent,
                                          child: Builder(
                                            builder: (buttonContext) => IconButton(
                                              tooltip: context.l10n.actions(
                                                (entry.filename).toString(),
                                              ),
                                              icon: const Icon(Icons.more_vert),
                                              onPressed: () {
                                                final box =
                                                    buttonContext
                                                            .findRenderObject()!
                                                        as RenderBox;
                                                _menu(
                                                  context,
                                                  entry,
                                                  box.localToGlobal(
                                                    Offset(
                                                      box.size.width,
                                                      box.size.height,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                final contextual = MouseRegion(
                                  onEnter: (_) =>
                                      setState(() => _hover = entry.filename),
                                  onExit: (_) => setState(() => _hover = null),
                                  child: GestureDetector(
                                    onSecondaryTapUp: (details) => _menu(
                                      context,
                                      entry,
                                      details.globalPosition,
                                    ),
                                    child: Listener(
                                      onPointerDown: (event) {
                                        if (desktop &&
                                            event.buttons == 1 &&
                                            _editing != entry.filename) {
                                          _pointerExtended[entry.filename] =
                                              HardwareKeyboard
                                                  .instance
                                                  .isControlPressed ||
                                              HardwareKeyboard
                                                  .instance
                                                  .isShiftPressed;
                                          if (!_selected.contains(
                                                entry.filename,
                                              ) ||
                                              HardwareKeyboard
                                                  .instance
                                                  .isControlPressed ||
                                              HardwareKeyboard
                                                  .instance
                                                  .isShiftPressed) {
                                            _select(entry);
                                          } else {
                                            _listFocus.requestFocus();
                                          }
                                        }
                                      },
                                      child: tile,
                                    ),
                                  ),
                                );
                                final drag = FileDragScope.of(context);
                                if (entry.attr.isDirectory &&
                                    drag?.targetDropBuilder != null &&
                                    widget.onDropInto != null) {
                                  return drag!.targetDropBuilder!(
                                    contextual,
                                    (paths) => widget.onDropInto!(entry, paths),
                                    remoteChild(widget.path, entry.filename),
                                  );
                                }
                                if (!entry.attr.isFile || drag == null) {
                                  return contextual;
                                }
                                final selection =
                                    _selected.contains(entry.filename)
                                    ? _selection
                                    : [entry];
                                return drag.selectionDragBuilder?.call(
                                      contextual,
                                      selection,
                                      widget.onExport,
                                    ) ??
                                    drag.dragBuilder(
                                      contextual,
                                      entry,
                                      widget.onExport,
                                    );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return Scaffold(
        endDrawer: wide
            ? null
            : Drawer(child: _controls(context, drawer: true)),
        body: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(child: list),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.items3(
                          (entries.length).toString(),
                          (entries.length != widget.entries.length
                                  ? context.l10n.hiddenFiltered(
                                      (widget.entries.length - entries.length)
                                          .toString(),
                                    )
                                  : "")
                              .toString(),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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

int naturalFileCompare(String a, String b) {
  final parts = RegExp(r'\d+|\D+');
  final left = parts
          .allMatches(a.toLowerCase())
          .map((match) => match.group(0)!)
          .toList(),
      right = parts
          .allMatches(b.toLowerCase())
          .map((match) => match.group(0)!)
          .toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    var l = left[i], r = right[i];
    int order;
    if (RegExp(r'^\d+$').hasMatch(l) && RegExp(r'^\d+$').hasMatch(r)) {
      l = l.replaceFirst(RegExp(r'^0+'), '');
      r = r.replaceFirst(RegExp(r'^0+'), '');
      order = l.length.compareTo(r.length);
      if (order == 0) order = l.compareTo(r);
    } else {
      order = l.compareTo(r);
    }
    if (order != 0) return order;
  }
  return left.length.compareTo(right.length);
}
