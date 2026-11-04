// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine.dart';
import '../main.dart' show askText, confirm, showErrorDetails;
import '../editors.dart';
import '../ssh/app_session.dart';
import '../terminal/terminal_prompt.dart';
import 'sftp_transfer.dart';
import 'sftp_file_operations.dart';
import 'file_browser_listing.dart';
import 'file_drag_scope.dart';
import 'file_job_queue.dart';
import 'file_queue_panel.dart';
import 'file_preview.dart';
import 'file_dialogs.dart';
import '../tilde_design.dart';
import '../connection_status.dart';
import 'sftp_tree_transfer.dart';
import 'transfer.dart';
import '../l10n/strings.dart';

class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({
    super.key,
    required this.engine,
    required this.host,
    this.embedded = false,
    this.onPreview,
    this.registerLeaveGuard,
  });
  final bool embedded;
  final void Function(FilePreview)? onPreview;
  final void Function(Future<bool> Function())? registerLeaveGuard;
  final AndroidEngine engine;
  final EngineRecord host;
  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  AppSshSession? _connection;
  SftpClient? _files;
  List<SftpName> _entries = [];
  String _path = '', _status = deviceStrings.loggingInForFileTransfer;
  bool _editingAddress = false;
  String? _error;
  bool _loading = true, _leaving = false;
  int _request = 0, _historyIndex = -1, _connectGeneration = 0;
  final _history = <String>[], _favorites = <String>{}, _recent = <String>[];
  final _address = TextEditingController();
  final _filter = TextEditingController();
  final _filterFocus = FocusNode();
  final _listingKey = GlobalKey<FileBrowserListingState>();
  List<SftpName> _selected = [];
  final _addressFocus = FocusNode();
  final _queue = FileJobQueue();
  final _staged = <EngineRecord>[];
  TransferControl? _operationControl;
  Future<void>? _operation;
  DateTime _lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
  List<({String path, SftpName entry})> _clipboard = [];
  bool _cut = false;
  FileDragScope? _platform;
  bool _settingsLoaded = false;
  @override
  void initState() {
    super.initState();
    _queue.addListener(_changed);
    widget.registerLeaveGuard?.call(_canLeave);
    unawaited(_connect());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _platform = FileDragScope.of(context);
    if (!_settingsLoaded) {
      _settingsLoaded = true;
      unawaited(_guard(_loadLocations));
    }
  }

  Future<void> _loadLocations() async {
    final saved = await _platform?.readSetting?.call(
      'fileLocations.${widget.host['id']}',
    );
    if (saved is Map && mounted) {
      setState(() {
        _favorites.addAll(
          (saved['favorites'] as List? ?? []).whereType<String>(),
        );
        _recent.addAll((saved['recent'] as List? ?? []).whereType<String>());
      });
    }
  }

  void _saveLocations() {
    unawaited(
      _platform?.writeSetting
          ?.call('fileLocations.${widget.host['id']}', {
            'favorites': _favorites.toList(),
            'recent': _recent.toList(),
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _progress() {
    final now = DateTime.now();
    if (now.difference(_lastProgress).inMilliseconds >= 80) {
      _lastProgress = now;
      _queue.changed();
    }
  }

  bool get _connected => _connection?.connected == true && !_leaving;
  bool get _enabled => _connected && !_loading && _operationControl == null;
  String _parent(String path) {
    final trimmed = path.length > 1 && path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final index = trimmed.lastIndexOf('/');
    return index <= 0 ? '/' : trimmed.substring(0, index);
  }

  void _editAddress() {
    setState(() => _editingAddress = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _addressFocus.requestFocus();
        _address.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _address.text.length,
        );
      }
    });
  }

  Future<void> _connect() async {
    final contextStrings = deviceStrings;
    final generation = ++_connectGeneration;
    final previous = _connection;
    setState(() {
      _connection = null;
      _files = null;
      _leaving = false;
      _loading = true;
      _error = null;
      _status = '';
    });
    try {
      await previous?.dispose();
      if (!mounted || generation != _connectGeneration) return;
      final connection = await widget.engine.createFileConnection(
        widget.host['id'] as int,
        onChanged: _changed,
      );
      if (!mounted || generation != _connectGeneration) {
        await connection.dispose();
        return;
      }
      _connection = connection;
      await connection.connect();
      if (!mounted || generation != _connectGeneration) return;
      if (!connection.connected) {
        throw StateError(
          row(connection.record['progress'])['message'] as String? ??
              contextStrings.couldNotLogInForFileTransfer,
        );
      }
      final files = await connection.openSftp();
      if (!mounted || generation != _connectGeneration) return;
      _files = files;
      if (mounted && generation == _connectGeneration) await _navigate('.');
    } catch (error) {
      if (mounted && generation == _connectGeneration) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _navigate(
    String path, {
    bool record = true,
    bool quiet = false,
    int? historyIndex,
  }) async {
    final files = _files;
    if (files == null || !mounted || _leaving) return;
    final request = ++_request;
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final absolute = await files
          .absolute(path)
          .timeout(const Duration(seconds: 30));
      final entries = await files
          .listdir(absolute)
          .timeout(const Duration(seconds: 30));
      entries.removeWhere(
        (entry) => entry.filename == '.' || entry.filename == '..',
      );
      if (!mounted || request != _request) return;
      setState(() {
        if (historyIndex != null) {
          _historyIndex = historyIndex;
        } else if (record &&
            (_historyIndex < 0 || _history[_historyIndex] != absolute)) {
          _history.removeRange(_historyIndex + 1, _history.length);
          _history.add(absolute);
          _historyIndex = _history.length - 1;
        }
        _path = absolute;
        _entries = entries;
        _address.text = absolute;
        if (!quiet) _status = '';
        _recent
          ..remove(absolute)
          ..insert(0, absolute);
        if (_recent.length > 12) _recent.removeLast();
      });
      _saveLocations();
    } catch (error) {
      if (mounted && request == _request) setState(() => _error = '$error');
    } finally {
      if (mounted && request == _request && !quiet) {
        setState(() => _loading = false);
      }
    }
  }

  void _refreshAt(String directory) {
    if (mounted && !_leaving && _path == directory) {
      unawaited(_navigate(directory, record: false, quiet: true));
    }
  }

  bool _locked(SftpName entry) =>
      _queue.locks(remoteChild(_path, entry.filename));
  Future<void> _open(SftpName entry) async {
    final path = remoteChild(_path, entry.filename);
    try {
      if (entry.attr.isDirectory ||
          (entry.attr.isSymbolicLink &&
              (await _files!.stat(path)).isDirectory)) {
        if (mounted) await _navigate(path);
      } else {
        await _preview(path, entry);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<Uint8List> _read(String path) async {
    final contextStrings = context.l10n;
    final channel = await _connection!.openSftp();
    try {
      final file = await channel.open(path);
      try {
        final size = (await file.stat()).size;
        if (size == null || size > 4 * 1024 * 1024) {
          throw StateError(
            contextStrings.previewSupportsFilesUpTo4MibDownloadThe,
          );
        }
        return await file.readBytes(length: size);
      } finally {
        await file.close();
      }
    } finally {
      await channel.close();
    }
  }

  Future<void> _preview(
    String path,
    SftpName? entry, {
    bool create = false,
  }) async {
    final contextStrings = context.l10n;
    SftpFileAttrs? original = entry?.attr;
    Future<void> saveContents(String targetPath, Uint8List bytes) async {
      final job = _queue.add(contextStrings.saveFile, targetPath, (job) async {
        final transfer = SftpTransfer(
          files: _files!,
          openChannel: _connection!.openSftp,
        );
        final exists = await transfer.exists(targetPath);
        int? permissions;
        if (exists) {
          final current = await _files!.stat(targetPath, followLink: false);
          if (current.isSymbolicLink || current.isDirectory) {
            throw StateError(
              contextStrings.theEditorCannotOverwriteFoldersOrSymbolicLinks,
            );
          }
          permissions = current.mode == null
              ? null
              : current.mode!.value & 0xfff;
          if (targetPath != path ||
              original == null ||
              current.size != original!.size ||
              current.modifyTime != original!.modifyTime) {
            if (!mounted ||
                !await confirm(
                  context,
                  targetPath == path
                      ? contextStrings.serverFileChanged
                      : contextStrings.aFileWithTheSameNameExists,
                  targetPath == path
                      ? contextStrings
                            .theServerFileChangedAfterEditingBeganOverwriteIt(
                              (targetPath).toString(),
                            )
                      : contextStrings.overwriteTheExistingFile(
                          (targetPath).toString(),
                        ),
                  action: contextStrings.overwrite,
                  destructive: false,
                )) {
              throw TransferCancelled();
            }
          }
        }
        final temporary = await Directory.systemTemp.createTemp('tilde-edit-');
        try {
          final file = await File('${temporary.path}/data').writeAsBytes(bytes);
          await transfer.upload(
            file,
            targetPath,
            control: job.control,
            overwrite: exists,
            permissions: permissions,
            onProgress: (_) => _progress(),
          );
          if (targetPath == path) {
            original = await _files!.stat(targetPath, followLink: false);
          }
        } finally {
          await temporary.delete(recursive: true);
        }
        _refreshAt(_parent(targetPath));
      });
      await job.wait();
    }

    final preview = FilePreview(
      path: path,
      size: entry?.attr.size,
      host: '${widget.host['nickname']}',
      onDownload: entry == null
          ? null
          : () => _guard(() => _downloadMany([entry])),
      newFile: create,
      load: () async {
        if (create) return Uint8List(0);
        if (_connection?.connected != true) {
          await _connect();
          if (_connection?.connected != true) {
            throw StateError(
              contextStrings.couldNotReconnectToTheServerCheckAuthenticationIn,
            );
          }
        }
        return _read(path);
      },
      save: (bytes) => saveContents(path, bytes),
      saveCopy: (bytes) async {
        final destination = await askText(
          context,
          contextStrings.saveACopyElsewhere,
          initial: path,
          action: contextStrings.saveCopy,
          hintText: '/home/user/copy.txt',
          validator: (value) {
            final target = value?.trim() ?? '';
            if (!target.startsWith('/') || target.endsWith('/')) {
              return contextStrings.enterAnAbsolutePathIncludingTheFileName;
            }
            if (target == path) {
              return contextStrings.enterAPathDifferentFromTheOriginal;
            }
            return null;
          },
        );
        if (destination == null) return null;
        await saveContents(destination.trim(), bytes);
        return destination.trim();
      },
    );
    if (widget.onPreview != null) {
      widget.onPreview!(preview);
      return;
    }
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => preview));
  }

  Future<void> _newFile() async {
    final contextStrings = context.l10n;
    final directory = _path;
    final name = await askText(
      context,
      contextStrings.newFile,
      validator: remoteNameError,
      action: contextStrings.create,
    );
    if (name == null || !mounted) return;
    final path = remoteChild(directory, name);
    if (await SftpTransfer(
      files: _files!,
      openChannel: _connection!.openSftp,
    ).exists(path)) {
      if (mounted) {
        setState(
          () => _error = contextStrings.anItemWithTheSameNameAlreadyExists,
        );
      }
      return;
    }
    if (mounted) await _preview(path, null, create: true);
  }

  Future<String?> _renameTo(SftpName entry, String name) async {
    final contextStrings = context.l10n;
    final directory = _path;
    if (_locked(entry)) return contextStrings.thisItemIsBeingTransferred;
    try {
      final job = _queue.add(
        contextStrings.rename,
        remoteChild(directory, name),
        (job) async {
          await job.control.ready;
          await SftpFileOperations(
            _files!,
          ).rename(directory, entry.filename, name);
          _refreshAt(directory);
        },
        paths: {remoteChild(directory, entry.filename)},
      );
      await job.wait();
      return null;
    } catch (error) {
      return '$error';
    }
  }

  Future<void> _rename(SftpName entry) async {
    final contextStrings = context.l10n;
    final name = await askText(
      context,
      contextStrings.rename,
      initial: entry.filename,
      validator: remoteNameError,
      action: contextStrings.change,
    );
    if (name == null || !mounted) return;
    final error = await _renameTo(entry, name);
    if (error != null && mounted) setState(() => _error = error);
  }

  Future<void> _createDirectory() async {
    final contextStrings = context.l10n;
    final directory = _path;
    final name = await askText(
      context,
      contextStrings.newFolder,
      validator: remoteNameError,
      action: contextStrings.create,
    );
    if (name == null || !mounted) return;
    await _runOperation(contextStrings.creatingFolder, (
      files,
      _,
      completed,
    ) async {
      await files.createDirectory(directory, name);
      return contextStrings.folderCreated;
    }, paths: {remoteChild(directory, name)});
  }

  Future<void> _deleteMany(List<SftpName> entries) async {
    final contextStrings = context.l10n;
    if (entries.isEmpty || entries.any(_locked)) return;
    final paths = entries
        .map((entry) => remoteChild(_path, entry.filename))
        .toList();
    Future<int> count(String path) async {
      final attr = await _files!
          .stat(path, followLink: false)
          .timeout(const Duration(seconds: 30));
      var total = 1;
      if (attr.isDirectory && !attr.isSymbolicLink) {
        for (final entry
            in await _files!
                .listdir(path)
                .timeout(const Duration(seconds: 30))) {
          if (entry.filename != '.' && entry.filename != '..') {
            total += await count(remoteChild(path, entry.filename));
          }
        }
      }
      return total;
    }

    final counts = Future<Map<String, int>>(() async {
      final result = <String, int>{};
      for (var i = 0; i < paths.length; i++) {
        result[entries[i].filename] = await count(paths[i]);
      }
      return result;
    });
    if (await showTildeSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  FileDeletePrompt(entries: entries, counts: counts),
            ) !=
            true ||
        !mounted) {
      return;
    }
    var deleted = 0;
    await _runOperation(
      contextStrings.deleting,
      (files, control, completed) async {
        for (final path in paths) {
          if (completed.contains(path)) continue;
          final before = deleted;
          await files.delete(
            path,
            control: control,
            onDeleted: (count) {
              deleted = before + count;
              _status = contextStrings.deletingItems((deleted).toString());
              _changed();
            },
          );
          completed.add(path);
        }
        return contextStrings.deletedItems((deleted).toString());
      },
      partialResult: () => deleted == 0
          ? ''
          : contextStrings.itemsWereDeleted((deleted).toString()),
      paths: paths.toSet(),
    );
  }

  Future<void> _permissions(List<SftpName> entries) async {
    final contextStrings = context.l10n;
    if (entries.isEmpty || entries.any(_locked)) return;
    final paths = entries
        .map((entry) => remoteChild(_path, entry.filename))
        .toList();
    final value = await showTildeSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FilePermissionsPrompt(
        names: entries.map((entry) => entry.filename).toList(),
        initial: entries.first.attr.mode == null
            ? null
            : entries.first.attr.mode!.value & 0xfff,
      ),
    );
    if (value == null || !mounted) return;
    await _runOperation(contextStrings.changingPermissions, (
      _,
      control,
      completed,
    ) async {
      for (final path in paths) {
        if (completed.contains(path)) continue;
        await control.ready;
        final attr = await _files!
            .stat(path, followLink: false)
            .timeout(const Duration(seconds: 30));
        if (attr.isSymbolicLink) {
          throw StateError(
            contextStrings.symbolicLinkPermissionsWillNotBeChanged,
          );
        }
        await _files!
            .setStat(path, SftpFileAttrs(mode: SftpFileMode.value(value)))
            .timeout(const Duration(seconds: 30));
        completed.add(path);
      }
      return contextStrings.permissionsChanged;
    }, paths: paths.toSet());
  }

  Future<void> _runOperation(
    String status,
    Future<String> Function(SftpFileOperations, TransferControl, Set<String>)
    action, {
    String Function()? partialResult,
    Set<String> paths = const {},
  }) {
    if (!_enabled) return Future.value();
    final directory = _path;
    final job = _queue.add(status, paths.firstOrNull ?? directory, (job) async {
      final contextStrings = context.l10n;
      if (mounted) {
        setState(() {
          _operationControl = job.control;
          _error = null;
          _status = status;
        });
      }
      try {
        await job.control.ready;
        final result = await action(
          SftpFileOperations(_files!),
          job.control,
          job.completedPaths,
        );
        if (mounted) _status = result;
      } on TransferCancelled {
        if (mounted) {
          _status = contextStrings.operationCancelled(
            (partialResult?.call() ?? '').toString(),
          );
        }
        rethrow;
      } catch (error) {
        if (mounted) {
          _error = '$error';
          _status = contextStrings.couldNotCompleteOperation2(
            (partialResult?.call() ?? '').toString(),
          );
        }
        rethrow;
      } finally {
        if (mounted) setState(() => _operationControl = null);
        _refreshAt(directory);
      }
    }, paths: paths);
    return _operation = () async {
      try {
        await job.wait();
      } catch (_) {
        /* The queue retains the error for retry. */
      }
    }();
  }

  Future<void> _copy(List<SftpName> entries, {bool cut = false}) async {
    final contextStrings = context.l10n;
    if (entries.isEmpty || cut && entries.any(_locked)) return;
    final directory = _path;
    _clipboard = [
      for (final entry in entries)
        (path: remoteChild(directory, entry.filename), entry: entry),
    ];
    _cut = cut;
    await Clipboard.setData(
      ClipboardData(text: _clipboard.map((item) => item.path).join('\n')),
    );
    if (!cut &&
        _platform?.copyRemoteFiles != null &&
        !entries.any((entry) => entry.attr.isDirectory)) {
      await _platform!.copyRemoteFiles!(
        entries,
        (entry, destination, control) =>
            _exportFrom(directory, entry, destination, control),
        _clipboard.map((item) => item.path).join('\n'),
      );
    }
    if (mounted) {
      setState(
        () => _status = contextStrings.itemsPasteInTheDestinationFolder(
          (entries.length).toString(),
          (cut ? contextStrings.cut : contextStrings.copy2).toString(),
        ),
      );
    }
  }

  Future<void> _paste() async {
    final contextStrings = context.l10n;
    final directory = _path;
    final text = await Clipboard.getData(Clipboard.kTextPlain);
    if (_clipboard.isNotEmpty &&
        text?.text == _clipboard.map((item) => item.path).join('\n')) {
      final items = List.of(_clipboard);
      final cut = _cut;
      _enqueueRemote(items, directory, move: cut);
      if (cut) {
        _clipboard = [];
        _cut = false;
      }
      return;
    }
    final paths = await _platform?.readLocalFiles?.call();
    if (paths != null && paths.isNotEmpty) {
      await _uploadPaths(paths, directory);
    } else if (mounted) {
      setState(() => _status = contextStrings.noFilesToPaste);
    }
  }

  Future<void> _moveMany(List<SftpName> entries) async {
    if (entries.isEmpty || entries.any(_locked)) return;
    final source = _path;
    final target = await showTildeSheet<String>(
      context: context,
      isScrollControlled: true,
      maxWidth: 560,
      builder: (_) => RemoteFolderPicker(
        names: entries.map((entry) => entry.filename).toList(),
        files: _files!,
        path: source,
        favorites: _favorites.toList(),
      ),
    );
    if (target == null || !mounted) return;
    final absolute = await _files!.absolute(target);
    _enqueueRemote(
      [
        for (final entry in entries)
          (path: remoteChild(source, entry.filename), entry: entry),
      ],
      absolute,
      move: true,
    );
  }

  void _enqueueRemote(
    List<({String path, SftpName entry})> entries,
    String target, {
    required bool move,
  }) {
    for (final item in entries) {
      final destination = remoteChild(target, item.entry.filename);
      if (destination == item.path || destination.startsWith('${item.path}/')) {
        setState(
          () => _error = context.l10n.cannotMoveOrCopyToTheSameLocationOr,
        );
        continue;
      }
      _queue.add(
        move ? context.l10n.move2 : context.l10n.copyTemporaryDownloadAndUpload,
        destination,
        (job) async {
          if (move) {
            await job.control.ready;
            await SftpFileOperations(_files!).move(item.path, destination);
          } else {
            final temporary = await Directory.systemTemp.createTemp(
              'tilde-copy-',
            );
            try {
              final tree = SftpTreeTransfer(_files!, _connection!.openSftp);
              job.completedPaths.clear();
              final local = localDestination(
                temporary,
                item.entry.filename,
              ).path;
              await tree.run(
                await tree.planDownload(item.path, local, job.control),
                upload: false,
                job: job,
                resolve: _conflicts(job, upload: false),
                changed: _progress,
              );
              job.completedPaths.clear();
              await tree.run(
                await tree.planUpload(local, destination, job.control),
                upload: true,
                job: job,
                resolve: _conflicts(job, upload: true),
                changed: _progress,
              );
            } finally {
              await temporary.delete(recursive: true);
            }
          }
          _refreshAt(target);
          _refreshAt(_parent(item.path));
        },
        paths: {item.path},
      );
    }
  }

  ResolveFileConflict _conflicts(FileJob job, {required bool upload}) {
    String? policy;
    return (source, existing) async {
      String? action = policy;
      if (action == null) {
        if (!mounted || _leaving) throw TransferCancelled();
        final result = await showTildeSheet<({String action, bool apply})>(
          context: context,
          isScrollControlled: true,
          builder: (_) => FileConflictPrompt(
            destination: source.destination,
            sourceSize: source.size,
            sourceModified: source.modified == null
                ? null
                : upload
                ? source.modified! ~/ 1000
                : source.modified,
            existing: existing,
            upload: upload,
            currentFile: job.completedFiles + 1,
            totalFiles: job.totalFiles,
          ),
        );
        if (result == null || result.action == 'cancel') {
          throw TransferCancelled();
        }
        action = result.action;
        if (result.apply) policy = action;
      }
      if (action == 'skip') return null;
      if (action == 'keep') {
        final separator = source.destination.lastIndexOf(RegExp(r'[/\\]'));
        final directory = source.destination.substring(0, separator + 1),
            name = source.destination.substring(separator + 1);
        final dot = name.lastIndexOf('.');
        final stem = dot > 0 ? name.substring(0, dot) : name,
            extension = dot > 0 ? name.substring(dot) : '';
        for (var suffix = 1; ; suffix++) {
          await job.control.ready;
          final candidate = '$directory$stem ($suffix)$extension';
          final exists = upload
              ? await SftpTransfer(
                  files: _files!,
                  openChannel: _connection!.openSftp,
                ).exists(candidate)
              : await FileSystemEntity.type(candidate, followLinks: false) !=
                    FileSystemEntityType.notFound;
          if (!exists) return (path: candidate, overwrite: false);
        }
      }
      return (path: source.destination, overwrite: true);
    };
  }

  Future<void> _uploadPaths(
    List<String> paths,
    String target, {
    Map<String, String> names = const {},
  }) async {
    final contextStrings = context.l10n;
    if (!_connected) return;
    for (final path in paths) {
      final destination = remoteChild(target, names[path] ?? fileName(path));
      List<TreeEntry>? plan;
      _queue.add(contextStrings.upload, destination, (job) async {
        final tree = SftpTreeTransfer(_files!, _connection!.openSftp);
        plan ??= await tree.planUpload(path, destination, job.control);
        await tree.run(
          plan!,
          upload: true,
          job: job,
          resolve: _conflicts(job, upload: true),
          changed: _progress,
        );
        _refreshAt(target);
      });
    }
  }

  Future<void> _pickUpload() async {
    final target = _path;
    try {
      final staged = row(await widget.engine.query('file.pickUpload'));
      if (staged['path'] is! String) return;
      _staged.add(staged);
      await _uploadPaths(
        [staged['path'] as String],
        target,
        names: {staged['path'] as String: staged['name'] as String},
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _uploadFolder() async {
    final target = _path;
    final folder = await _platform?.chooseDirectory?.call();
    if (folder != null) await _uploadPaths([folder], target);
  }

  Future<void> _downloadMany(List<SftpName> entries) async {
    final contextStrings = context.l10n;
    if (entries.isEmpty) return;
    final sourceDirectory = _path;
    if (entries.length == 1 && !entries.single.attr.isDirectory) {
      final entry = entries.single;
      final source = remoteChild(sourceDirectory, entry.filename);
      try {
        final staged = row(
          await widget.engine.query('file.prepareDownload', {
            'name': entry.filename,
          }),
        );
        if (staged['path'] is! String) return;
        _staged.add(staged);
        _queue.add(
          contextStrings.download,
          staged['uri'] as String? ?? entry.filename,
          (job) async {
            await SftpTransfer(
              files: _files!,
              openChannel: _connection!.openSftp,
            ).download(
              source,
              File(staged['path'] as String),
              control: job.control,
              overwrite: true,
              onProgress: (_) => _progress(),
            );
            await widget.engine.query('file.finishTransfer', {
              ...staged,
              'save': true,
            });
            _staged.remove(staged);
          },
          paths: {source},
        );
      } catch (error) {
        if (mounted) setState(() => _error = '$error');
      }
    } else {
      final directory = await _platform?.chooseDirectory?.call();
      if (directory == null) {
        if (_platform?.chooseDirectory == null && mounted) {
          setState(
            () => _error = contextStrings
                .choosingAFolderDestinationIsUnsupportedOnThisPlatform,
          );
        }
        return;
      }
      for (final entry in entries) {
        final source = remoteChild(sourceDirectory, entry.filename),
            target = localDestination(
              Directory(directory),
              entry.filename,
            ).path;
        List<TreeEntry>? plan;
        _queue.add(
          contextStrings.download,
          target,
          (job) async {
            final tree = SftpTreeTransfer(_files!, _connection!.openSftp);
            plan ??= await tree.planDownload(source, target, job.control);
            await tree.run(
              plan!,
              upload: false,
              job: job,
              resolve: _conflicts(job, upload: false),
              changed: _progress,
            );
          },
          paths: {source},
          reveal: _platform?.revealFolder == null
              ? null
              : () => _platform!.revealFolder!(directory),
        );
      }
    }
  }

  Future<void> _exportFrom(
    String directory,
    SftpName entry,
    File destination,
    TransferControl control,
  ) async {
    final contextStrings = context.l10n;
    if (!_connected) throw StateError(contextStrings.connectionClosed2);
    final source = remoteChild(directory, entry.filename);
    final job = _queue.add(
      contextStrings.downloadToFileManager,
      destination.path,
      (job) async {
        job.control = control;
        final tree = SftpTreeTransfer(_files!, _connection!.openSftp);
        await tree.run(
          await tree.planDownload(source, destination.path, control),
          upload: false,
          job: job,
          resolve: (entry, existing) async => throw StateError(
            contextStrings.theTemporaryExportPathAlreadyExists,
          ),
          changed: _progress,
        );
      },
      paths: {source},
      retryable: false,
    );
    await job.wait();
  }

  Future<bool> _canLeave() async {
    final contextStrings = context.l10n;
    if (!_queue.busy && _operationControl == null) return true;
    if (!await confirm(
      context,
      contextStrings.cancelTransfersAndClose,
      contextStrings.cancelActiveTransfersAndQueuedOperationsInThisTab,
      action: contextStrings.cancelTransfersAndClose,
    )) {
      return false;
    }
    _leaving = true;
    for (final job in _queue.jobs) {
      if (job.state == FileJobState.pending ||
          job.state == FileJobState.running) {
        _queue.cancel(job);
      }
    }
    _operationControl?.cancel();
    await _queue.drained;
    await _operation;
    return true;
  }

  Future<void> _cancelAndLeave() async {
    if (_leaving || !await _canLeave()) return;
    _leaving = true;
    for (final job in _queue.jobs) {
      if (job.state == FileJobState.pending ||
          job.state == FileJobState.running) {
        _queue.cancel(job);
      }
    }
    _operationControl?.cancel();
    _changed();
    await _queue.drained;
    await _operation;
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _leaving = true;
    _operationControl?.cancel();
    _queue.removeListener(_changed);
    _queue.dispose();
    unawaited(_connection?.dispose());
    for (final staged in _staged) {
      unawaited(
        widget.engine
            .query('file.finishTransfer', {...staged, 'save': false})
            .catchError((Object _) {}),
      );
    }
    _address.dispose();
    _filter.dispose();
    _filterFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  List<Widget> _selectionActions() => [
    TextButton.icon(
      onPressed: _connected
          ? () => _guard(() => _downloadMany(_selected))
          : null,
      icon: const Icon(Icons.download_outlined, size: 18),
      label: Text(context.l10n.download),
    ),
    TextButton(
      onPressed: _connected ? () => _guard(() => _copy(_selected)) : null,
      child: Text(context.l10n.copy2),
    ),
    TextButton(
      onPressed: _enabled && !_selected.any(_locked)
          ? () => _guard(() => _moveMany(_selected))
          : null,
      child: Text(context.l10n.move2),
    ),
    TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      onPressed: _enabled && !_selected.any(_locked)
          ? () => _guard(() => _deleteMany(_selected))
          : null,
      child: Text(context.l10n.delete),
    ),
  ];
  List<Widget> _normalActions() => [
    FilledButton.icon(
      onPressed: _connected ? _pickUpload : null,
      icon: const Icon(Icons.upload_outlined, size: 18),
      label: Text(context.l10n.upload),
    ),
    if (_platform?.chooseDirectory != null)
      TextButton(
        onPressed: _connected ? () => _guard(_uploadFolder) : null,
        child: Text(context.l10n.uploadFolder),
      ),
    TextButton.icon(
      onPressed: _enabled ? _newFile : null,
      icon: const Icon(Icons.note_add_outlined, size: 18),
      label: Text(context.l10n.newFile),
    ),
    TextButton.icon(
      onPressed: _enabled ? _createDirectory : null,
      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
      label: Text(context.l10n.newFolder),
    ),
  ];

  Future<void> _cancelConnection() async {
    ++_connectGeneration;
    final connection = _connection;
    setState(() {
      _connection = null;
      _leaving = true;
      _loading = false;
      _error = null;
    });
    await connection?.dispose();
  }

  Widget _connectionView() {
    final record = _connection?.record ?? <String, dynamic>{};
    final phase = record['connectionPhase'] as String? ?? 'server';
    final failed = _error != null;
    final pointer = tildePointer(context);
    final prompts = _connection?.prompts ?? [];
    final title = _leaving
        ? context.l10n.connectionCancelled
        : failed
        ? switch (phase) {
            'hostKey' => context.l10n.couldNotVerifyServerKey,
            'authentication' => context.l10n.couldNotLogIn,
            'ready' => context.l10n.couldNotOpenFileList,
            _ => context.l10n.couldNotConnectToServer,
          }
        : context.l10n.connectingTo2((widget.host['nickname']).toString());
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                context.l10n.fileTransfer2(
                  (widget.host['nickname']).toString(),
                ),
              ),
            ),
      body: SafeArea(
        top: false,
        child: ConnectionStatusView(
          record: record,
          title: title,
          address:
              record['connectionHost'] as String? ??
              '${widget.host['username'] ?? ''}@${widget.host['hostname'] ?? ''}:${widget.host['port'] ?? 22}',
          finalStage: context.l10n.fileList,
          failed: failed,
          cancelled: _leaving,
          failureHint: failed
              ? switch (phase) {
                  'hostKey' =>
                    context
                        .l10n
                        .checkTheSavedServerKeyAndTheFingerprintProvided,
                  'authentication' =>
                    context.l10n.checkYourUsernameAndCredentialsIfUsingAnSsh,
                  'ready' =>
                    context.l10n.checkTheFolderPathAndPermissionsThenTryAgain,
                  _ =>
                    context.l10n.checkTheServerAddressPortAndNetworkConnection,
                }
              : null,
          prompt: prompts.isEmpty
              ? null
              : TerminalPromptSurface(
                  key: ValueKey(prompts.first['token']),
                  prompt: prompts.first,
                  onResponse: (value) async => _connection?.respond(
                    prompts.first['token'] as String,
                    value,
                  ),
                ),
          actions: [
            if (failed)
              TextButton(
                onPressed: () => showErrorDetails(
                  context,
                  _error!,
                  summary: title,
                  retry: _connect,
                ),
                child: Text(context.l10n.details),
              ),
            if (pointer && !failed && !_leaving)
              TextButton(
                onPressed: () => showErrorDetails(
                  context,
                  (record['connectionLog'] as List? ?? []).join('\n'),
                  summary: context.l10n.connectionLog,
                ),
                child: Text(context.l10n.connectionLog),
              ),
            if (!failed && !_leaving)
              TextButton(
                onPressed: _cancelConnection,
                child: Text(context.l10n.cancel),
              ),
            if (failed)
              OutlinedButton(
                onPressed: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordEditor(
                        engine: widget.engine,
                        kind: RecordKind.host,
                        record:
                            widget.engine
                                .list('hosts')
                                .where((h) => h['id'] == widget.host['id'])
                                .firstOrNull ??
                            widget.host,
                      ),
                    ),
                  );
                },
                child: Text(context.l10n.editHost),
              ),
            if (failed || _leaving)
              FilledButton(
                onPressed: _connect,
                child: Text(context.l10n.retry),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_path.isEmpty) return _connectionView();
    final connection = _connection, prompts = connection?.prompts ?? [];
    final directory = _path;
    final locations = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.l10n.favorites)),
            IconButton(
              tooltip: context.l10n.bookmarkCurrentFolder,
              onPressed: _path.isEmpty
                  ? null
                  : () {
                      setState(
                        () => _favorites.contains(_path)
                            ? _favorites.remove(_path)
                            : _favorites.add(_path),
                      );
                      _saveLocations();
                    },
              icon: Icon(
                _favorites.contains(_path) ? Icons.star : Icons.star_border,
              ),
            ),
          ],
        ),
        for (final path in _favorites)
          ListTile(
            dense: true,
            title: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: _connected ? () => _navigate(path) : null,
          ),
        if (_recent.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(context.l10n.recentLocations),
            children: [
              for (final path in _recent)
                ListTile(
                  dense: true,
                  title: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: _connected ? () => _navigate(path) : null,
                ),
            ],
          ),
      ],
    );
    final pointer = tildePointer(context);
    final listing = FileBrowserListing(
      key: _listingKey,
      searchController: pointer ? _filter : null,
      searchFocus: pointer ? _filterFocus : null,
      showToolbar: !pointer && _selected.isEmpty,
      showSelectionToolbar: false,
      onSelectionChanged: (entries) {
        if (mounted) setState(() => _selected = entries);
      },
      entries: _entries,
      path: _path,
      loading: _loading,
      onOpen: _connected ? _open : null,
      onDownload: _connected
          ? (entry) => _guard(() => _downloadMany([entry]))
          : null,
      onExport: _connected
          ? (entry, destination, control) =>
                _exportFrom(directory, entry, destination, control)
          : null,
      onRename: _enabled ? _rename : null,
      onRenameTo: _enabled ? _renameTo : null,
      onDelete: _enabled ? (entry) => _deleteMany([entry]) : null,
      onDeleteMany: _enabled ? _deleteMany : null,
      onDownloadMany: _connected
          ? (entries) => _guard(() => _downloadMany(entries))
          : null,
      onCopy: _connected ? (entries) => _guard(() => _copy(entries)) : null,
      onCut: _enabled
          ? (entries) => _guard(() => _copy(entries, cut: true))
          : null,
      onPaste: _enabled && _clipboard.isNotEmpty
          ? () => unawaited(_guard(_paste))
          : null,
      onMove: _enabled ? (entries) => _guard(() => _moveMany(entries)) : null,
      onPermissions: _enabled ? _permissions : null,
      isLocked: _locked,
      onDropInto: _connected
          ? (entry, paths) =>
                _uploadPaths(paths, remoteChild(directory, entry.filename))
          : null,
      locations: locations,
      onBack: _historyIndex > 0
          ? () => _navigate(
              _history[_historyIndex - 1],
              record: false,
              historyIndex: _historyIndex - 1,
            )
          : null,
      onForward: _historyIndex + 1 < _history.length
          ? () => _navigate(
              _history[_historyIndex + 1],
              record: false,
              historyIndex: _historyIndex + 1,
            )
          : null,
      onUp: () => _navigate(_parent(_path)),
      onRefresh: () => _navigate(_path, record: false),
      onAddress: _editAddress,
      onNewFolder: _enabled ? _createDirectory : null,
    );
    return PopScope(
      canPop: widget.embedded || (!_queue.busy && _operationControl == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancelAndLeave());
      },
      child: Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(
                leading: !pointer && _selected.isNotEmpty
                    ? IconButton(
                        tooltip: context.l10n.clearSelection,
                        onPressed: () =>
                            _listingKey.currentState?.clearSelection(),
                        icon: const Icon(Icons.close),
                      )
                    : null,
                title: Text(
                  !pointer && _selected.isNotEmpty
                      ? context.l10n.selected((_selected.length).toString())
                      : context.l10n.fileTransfer2(
                          (widget.host['nickname']).toString(),
                        ),
                ),
              ),
        bottomNavigationBar: !pointer && _selected.isNotEmpty
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectionActions(),
                  ),
                ),
              )
            : null,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: pointer ? 12 : 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: context.l10n.back,
                      onPressed: _connected && _historyIndex > 0
                          ? () => _navigate(
                              _history[_historyIndex - 1],
                              record: false,
                              historyIndex: _historyIndex - 1,
                            )
                          : null,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    IconButton(
                      tooltip: context.l10n.forward,
                      onPressed:
                          _connected && _historyIndex + 1 < _history.length
                          ? () => _navigate(
                              _history[_historyIndex + 1],
                              record: false,
                              historyIndex: _historyIndex + 1,
                            )
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    IconButton(
                      tooltip: context.l10n.parentFolder,
                      onPressed: _connected && _path != '/'
                          ? () => _navigate(_parent(_path))
                          : null,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    Expanded(
                      child: Container(
                        key: const ValueKey('file-path-field'),
                        decoration: _editingAddress
                            ? null
                            : BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _editingAddress
                                  ? CallbackShortcuts(
                                      bindings: {
                                        const SingleActivator(
                                          LogicalKeyboardKey.escape,
                                        ): () => setState(
                                          () => _editingAddress = false,
                                        ),
                                      },
                                      child: TextField(
                                        controller: _address,
                                        focusNode: _addressFocus,
                                        onSubmitted: (path) {
                                          setState(
                                            () => _editingAddress = false,
                                          );
                                          _navigate(path);
                                        },
                                        onTapOutside: (_) => setState(
                                          () => _editingAddress = false,
                                        ),
                                        style: const TextStyle(
                                          fontFamily: tildeMono,
                                          fontFamilyFallback: tildeMonoFallback,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText:
                                              context.l10n.remoteFolderPath,
                                        ),
                                      ),
                                    )
                                  : InkWell(
                                      onTap: _editAddress,
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        height: tildePointer(context) ? 36 : 44,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              TextButton(
                                                style: TextButton.styleFrom(
                                                  minimumSize: Size(
                                                    0,
                                                    pointer ? 36 : 44,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                ),
                                                onPressed: () => _navigate('/'),
                                                child: const Text('/'),
                                              ),
                                              for (
                                                var index = 0;
                                                index <
                                                    _path
                                                        .split('/')
                                                        .where(
                                                          (part) =>
                                                              part.isNotEmpty,
                                                        )
                                                        .length;
                                                index++
                                              )
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    minimumSize: Size(
                                                      0,
                                                      pointer ? 36 : 44,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                        ),
                                                  ),
                                                  onPressed: () => _navigate(
                                                    '/${_path.split('/').where((part) => part.isNotEmpty).take(index + 1).join('/')}',
                                                  ),
                                                  child: Text(
                                                    '${_path.split('/').where((part) => part.isNotEmpty).elementAt(index)} /',
                                                  ),
                                                ),
                                              const SizedBox(width: 32),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            if (pointer) ...[
                              IconButton(
                                tooltip: context.l10n.bookmarkCurrentFolder,
                                icon: Icon(
                                  _favorites.contains(_path)
                                      ? Icons.star
                                      : Icons.star_border,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _favorites.contains(_path)
                                        ? _favorites.remove(_path)
                                        : _favorites.add(_path),
                                  );
                                  _saveLocations();
                                },
                              ),
                              PopupMenuButton<String>(
                                tooltip:
                                    context.l10n.bookmarksAndRecentLocations,
                                icon: const Icon(Icons.history),
                                onSelected: _connected
                                    ? (path) => _navigate(path)
                                    : null,
                                itemBuilder: (_) => [
                                  if (_favorites.isNotEmpty)
                                    PopupMenuItem<String>(
                                      enabled: false,
                                      child: Text(context.l10n.favorites),
                                    ),
                                  for (final path in _favorites)
                                    PopupMenuItem(
                                      value: path,
                                      child: Text(
                                        path,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (_recent.isNotEmpty)
                                    PopupMenuItem<String>(
                                      enabled: false,
                                      child: Text(context.l10n.recentLocations),
                                    ),
                                  for (final path in _recent)
                                    PopupMenuItem(
                                      value: path,
                                      child: Text(
                                        path,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.refresh,
                      onPressed: _connected
                          ? () => _navigate(_path, record: false)
                          : null,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (pointer)
                LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    height:
                        (MediaQuery.textScalerOf(context).scale(14) * 1.4 + 16)
                            .clamp(44, double.infinity),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: constraints.maxWidth.clamp(
                          760 * MediaQuery.textScalerOf(context).scale(14) / 14,
                          double.infinity,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: pointer ? 12 : 16,
                          ),
                          child: Row(
                            children: [
                              if (_selected.isEmpty)
                                ..._normalActions()
                              else ...[
                                Text(
                                  context.l10n.selected(
                                    (_selected.length).toString(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ..._selectionActions(),
                                IconButton(
                                  tooltip: context.l10n.clearSelection,
                                  onPressed: () => _listingKey.currentState
                                      ?.clearSelection(),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                              const Spacer(),
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: _filter,
                                  focusNode: _filterFocus,
                                  onChanged: (_) =>
                                      _listingKey.currentState?.filterChanged(),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.search, size: 18),
                                    hintText: context.l10n.findInCurrentFolder,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (anchor) => TextButton.icon(
                                  onPressed: () => _listingKey.currentState
                                      ?.showViewMenu(anchor),
                                  icon: const Icon(Icons.tune, size: 18),
                                  label: Text(context.l10n.view),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (_selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _normalActions(),
                    ),
                  ),
                ),
              if (_loading || _operationControl != null)
                const LinearProgressIndicator(),
              if (prompts.isNotEmpty)
                TerminalPromptSurface(
                  key: ValueKey(prompts.first['token']),
                  prompt: prompts.first,
                  onResponse: (value) async {
                    connection!.respond(
                      prompts.first['token'] as String,
                      value,
                    );
                  },
                ),
              if (connection?.connecting == true && prompts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    (connection!.record['connectionLog'] as List? ?? []).join(
                      '\n',
                    ),
                  ),
                ),
              Expanded(
                child:
                    _platform?.targetDropBuilder?.call(
                      listing,
                      _connected
                          ? (paths) => _uploadPaths(paths, directory)
                          : null,
                      directory,
                    ) ??
                    _platform?.dropBuilder(
                      listing,
                      _connected
                          ? (paths) => _uploadPaths(paths, directory)
                          : null,
                    ) ??
                    listing,
              ),
              FileQueuePanel(queue: _queue),
              if (_error != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 80),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SelectableText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_status.isNotEmpty)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _status,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
