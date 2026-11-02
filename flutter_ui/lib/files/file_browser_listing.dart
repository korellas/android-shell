// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sftp_file_operations.dart';
import 'transfer.dart';
import 'file_drag_scope.dart';

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
  });
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
  State<FileBrowserListing> createState() => _FileBrowserListingState();
}

class _FileBrowserListingState extends State<FileBrowserListing> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode(),
      _listFocus = FocusNode(),
      _renameFocus = FocusNode();
  final _renameText = TextEditingController();
  final _scroll = ScrollController();
  final _selected = <String>{};
  final _pointerExtended = <String, bool>{};
  final _views =
      <String, ({Set<String> selected, String query, double offset})>{};
  String? _anchor, _focused, _editing, _renameError;
  final _widths = <String, double>{
    '크기': 90,
    '수정일': 155,
    '소유자 UID': 80,
    '그룹 GID': 80,
    '권한': 65,
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
    _search.dispose();
    _searchFocus.dispose();
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
      children: [
        if (widget.locations != null) widget.locations!,
        Row(
          children: [
            const Expanded(
              child: Text(
                '보기 및 정렬',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            if (drawer)
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _search,
          onChanged: (_) => _filterChanged(),
          decoration: InputDecoration(
            labelText: '현재 폴더에서 찾기',
            hintText: '파일명 검색',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '검색 지우기',
                    onPressed: () {
                      _search.clear();
                      _filterChanged();
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('숨김 파일·폴더 표시'),
          value: _showHidden,
          onChanged: (value) {
            _showHidden = value;
            _filterChanged();
            _saveView();
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<FileSort>(
          key: ValueKey(_sort),
          initialValue: _sort,
          decoration: const InputDecoration(
            labelText: '정렬 기준',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: FileSort.name, child: Text('이름')),
            DropdownMenuItem(value: FileSort.size, child: Text('크기')),
            DropdownMenuItem(value: FileSort.modified, child: Text('수정일')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _sort = value);
              _saveView();
            }
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('오름차순')),
            ButtonSegment(value: true, label: Text('내림차순')),
          ],
          selected: {_descending},
          onSelectionChanged: (value) {
            setState(() => _descending = value.single);
            _saveView();
          },
        ),
        const SizedBox(height: 12),
        const Text('폴더를 먼저 표시합니다. 검색은 현재 폴더에만 적용됩니다.'),
      ],
    ),
  );

  String _modified(int? seconds) {
    if (seconds == null) return '—';
    final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)} ${pad(time.hour)}:${pad(time.minute)}';
  }

  Widget _metadata(SftpName entry) => Row(
    children: [
      SizedBox(
        width: _widths['크기']!,
        child: Text(
          entry.attr.isDirectory || entry.attr.size == null
              ? '—'
              : formatBytes(entry.attr.size!),
        ),
      ),
      SizedBox(
        width: _widths['수정일']!,
        child: Text(_modified(entry.attr.modifyTime)),
      ),
      SizedBox(
        width: _widths['소유자 UID']!,
        child: Text('${entry.attr.userID ?? '—'}'),
      ),
      SizedBox(
        width: _widths['그룹 GID']!,
        child: Text('${entry.attr.groupID ?? '—'}'),
      ),
      SizedBox(
        width: _widths['권한']!,
        child: Text(
          entry.attr.mode == null
              ? '—'
              : (entry.attr.mode!.value & 0xfff)
                    .toRadixString(8)
                    .padLeft(4, '0'),
        ),
      ),
    ],
  );

  List<PopupMenuEntry<FileAction>> _actions(SftpName entry) => [
    if (entry.attr.isDirectory)
      PopupMenuItem(
        value: FileAction.open,
        enabled: widget.onOpen != null,
        child: const ListTile(
          leading: Icon(Icons.folder_open),
          title: Text('열기'),
        ),
      )
    else
      PopupMenuItem(
        value: FileAction.download,
        enabled: widget.onDownload != null,
        child: const ListTile(
          leading: Icon(Icons.download_outlined),
          title: Text('다운로드'),
        ),
      ),
    PopupMenuItem(
      value: FileAction.rename,
      enabled:
          (widget.onRename != null || widget.onRenameTo != null) &&
          _selection.length <= 1 &&
          !_locked(entry),
      child: const ListTile(
        leading: Icon(Icons.drive_file_rename_outline),
        title: Text('이름 변경'),
      ),
    ),
    PopupMenuItem(
      value: FileAction.delete,
      enabled:
          (widget.onDelete != null || widget.onDeleteMany != null) &&
          !_selection.any(_locked) &&
          !_locked(entry),
      child: ListTile(
        leading: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('삭제'),
      ),
    ),
    if (widget.onCopy != null)
      const PopupMenuItem(value: FileAction.copy, child: Text('복사')),
    if (widget.onCut != null)
      PopupMenuItem(
        value: FileAction.cut,
        enabled: !_selection.any(_locked),
        child: const Text('잘라내기'),
      ),
    if (widget.onPaste != null)
      const PopupMenuItem(value: FileAction.paste, child: Text('붙여넣기')),
    if (widget.onMove != null)
      PopupMenuItem(
        value: FileAction.move,
        enabled: !_selection.any(_locked),
        child: const Text('이동…'),
      ),
    const PopupMenuItem(value: FileAction.path, child: Text('경로 복사')),
    if (widget.onPermissions != null)
      PopupMenuItem(
        value: FileAction.permissions,
        enabled: !_selection.any(_locked),
        child: const Text('권한 변경…'),
      ),
    const PopupMenuDivider(),
    const PopupMenuItem(
      value: FileAction.info,
      child: ListTile(leading: Icon(Icons.info_outline), title: Text('정보')),
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
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('파일 정보'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final field in [
                      ('이름', entry.filename),
                      ('경로', remoteChild(widget.path, entry.filename)),
                      (
                        '종류',
                        entry.attr.isDirectory
                            ? '폴더'
                            : entry.attr.isSymbolicLink
                            ? '심볼릭 링크'
                            : '파일',
                      ),
                      (
                        '크기',
                        entry.attr.size == null
                            ? '—'
                            : '${formatBytes(entry.attr.size!)} (${entry.attr.size} B)',
                      ),
                      ('수정일', _modified(entry.attr.modifyTime)),
                      ('소유자 UID', '${entry.attr.userID ?? '—'}'),
                      ('그룹 GID', '${entry.attr.groupID ?? '—'}'),
                      (
                        '권한',
                        entry.attr.mode == null
                            ? '—'
                            : (entry.attr.mode!.value & 0xfff)
                                  .toRadixString(8)
                                  .padLeft(4, '0'),
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              field.$1,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            SelectableText(field.$2),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _menu(
    BuildContext context,
    SftpName entry,
    Offset position,
  ) async {
    if (!_selected.contains(entry.filename)) {
      _select(entry, toggle: false, range: false);
    }
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final point = overlay.globalToLocal(position);
    final action = await showMenu<FileAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(point.dx, point.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: _actions(entry),
    );
    if (action != null && mounted) _action(entry, action);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1100;
      final entries = _visible;
      final list = LayoutBuilder(
        builder: (context, listConstraints) {
          final details = listConstraints.maxWidth >= 800;
          final tableWidth = details
              ? (_widths.values.fold<double>(0, (sum, value) => sum + value) +
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                        hintText: '현재 폴더에서 찾기',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: '검색 지우기',
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
                  if (_selected.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${_selected.length}개 선택 · ${formatBytes(_selection.fold<int>(0, (sum, entry) => sum + (entry.attr.isDirectory ? 0 : entry.attr.size ?? 0)))}',
                            ),
                          ),
                          if (widget.onDownloadMany != null)
                            TextButton.icon(
                              onPressed: () =>
                                  widget.onDownloadMany!(_selection),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('다운로드'),
                            ),
                          if (widget.onCopy != null)
                            TextButton(
                              onPressed: () => widget.onCopy!(_selection),
                              child: const Text('복사'),
                            ),
                          if (widget.onMove != null)
                            TextButton(
                              onPressed: _selection.any(_locked)
                                  ? null
                                  : () => widget.onMove!(_selection),
                              child: const Text('이동'),
                            ),
                          if (widget.onDeleteMany != null)
                            TextButton(
                              onPressed: _selection.any(_locked)
                                  ? null
                                  : () => widget.onDeleteMany!(_selection),
                              child: const Text('삭제'),
                            ),
                          IconButton(
                            tooltip: '선택 해제',
                            onPressed: () {
                              setState(_selected.clear);
                              _notify();
                            },
                            icon: const Icon(Icons.clear),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            '${entries.length} / ${widget.entries.length}개 항목',
                          ),
                        ),
                      ),
                      if (!wide)
                        Builder(
                          builder: (context) => IconButton(
                            tooltip: '보기 및 정렬',
                            onPressed: () =>
                                Scaffold.of(context).openEndDrawer(),
                            icon: const Icon(Icons.tune),
                          ),
                        ),
                    ],
                  ),
                  if (details)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(72, 8, 112, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _sortColumn(FileSort.name),
                              child: const Text('이름'),
                            ),
                          ),
                          for (final column in _widths.entries)
                            SizedBox(
                              width: column.value,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: column.key == '크기'
                                          ? () => _sortColumn(FileSort.size)
                                          : column.key == '수정일'
                                          ? () => _sortColumn(FileSort.modified)
                                          : null,
                                      child: Text(column.key),
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
                                      ? '불러오는 중…'
                                      : widget.entries.isEmpty
                                      ? '표시할 파일이 없습니다.'
                                      : '조건에 맞는 파일이 없습니다.',
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final desktop = {
                                  TargetPlatform.windows,
                                  TargetPlatform.macOS,
                                  TargetPlatform.linux,
                                }.contains(Theme.of(context).platform);
                                final tile = ListTile(
                                  selected: _selected.contains(entry.filename),
                                  selectedTileColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: .4),
                                  leading: _selected.isNotEmpty && !desktop
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
                                              ? Icons.folder_outlined
                                              : entry.attr.isSymbolicLink
                                              ? Icons.link
                                              : Icons
                                                    .insert_drive_file_outlined,
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
                                                        tooltip: '이름 변경 적용',
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
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                        ),
                                        if (details) _metadata(entry),
                                      ],
                                    ),
                                  ),
                                  subtitle:
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
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      entry.attr.isDirectory
                                          ? const Icon(Icons.chevron_right)
                                          : IconButton(
                                              tooltip: '다운로드',
                                              onPressed:
                                                  widget.onDownload == null
                                                  ? null
                                                  : () => widget.onDownload!(
                                                      entry,
                                                    ),
                                              icon: const Icon(
                                                Icons.download_outlined,
                                              ),
                                            ),
                                      Builder(
                                        builder: (buttonContext) => IconButton(
                                          tooltip: '${entry.filename} 작업',
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
                                    ],
                                  ),
                                );
                                final contextual = GestureDetector(
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
            if (wide) ...[
              SizedBox(width: 280, child: _controls(context)),
              const VerticalDivider(width: 1),
            ],
            Expanded(child: list),
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
