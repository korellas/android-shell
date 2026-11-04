// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'package:android_shell_ui/files/file_drag_scope.dart';
import 'package:android_shell_ui/files/transfer.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:super_clipboard/super_clipboard.dart' show SimpleFileFormat;
import 'package:super_clipboard/super_clipboard.dart' as clipboard;
import 'package:android_shell_ui/l10n/strings.dart';

// Native registration stays in the Windows host; mobile consumers need no plugin.
class WindowsFileDrag extends StatelessWidget {
  const WindowsFileDrag({
    super.key,
    required this.child,
    this.chooseDirectory,
    this.readSetting,
    this.writeSetting,
    this.revealFolder,
  });
  final Future<String?> Function()? chooseDirectory;
  final Future<Object?> Function(String)? readSetting;
  final Future<void> Function(String, Object)? writeSetting;
  final Future<void> Function(String)? revealFolder;
  final Widget child;
  @override
  Widget build(BuildContext context) => FileDragScope(
    chooseDirectory: chooseDirectory,
    revealFolder: revealFolder,
    readSetting: readSetting,
    writeSetting: writeSetting,
    readLocalFiles: () async {
      final reader = await clipboard.SystemClipboard.instance?.read();
      final result = <Future<String?>>[];
      for (final item in reader?.items ?? <clipboard.ClipboardDataReader>[]) {
        if (!item.canProvide(clipboard.Formats.fileUri)) continue;
        final value = Completer<String?>();
        item.getValue(
          clipboard.Formats.fileUri,
          (uri) => value.complete(uri?.toFilePath(windows: true)),
          onError: value.completeError,
        );
        result.add(value.future);
      }
      return (await Future.wait(result)).whereType<String>().toList();
    },
    copyRemoteFiles: (entries, download, text) async {
      final items = <clipboard.DataWriterItem>[];
      for (final entry in entries) {
        final item = clipboard.DataWriterItem(suggestedName: entry.filename)
          ..add(clipboard.Formats.plainText(text));
        item.addVirtualFile(
          format: const SimpleFileFormat(
            windowsFormats: ['application/octet-stream'],
          ),
          provider: (sinkProvider, progress) {
            final control = TransferControl();
            progress.onCancel.addListener(control.cancel);
            unawaited(
              writeVirtualDownload(
                entry: entry,
                control: control,
                sinkProvider: sinkProvider,
                download: download,
              ).whenComplete(
                () => progress.onCancel.removeListener(control.cancel),
              ),
            );
          },
        );
        items.add(item);
      }
      await clipboard.SystemClipboard.instance!.write(items);
    },
    targetDropBuilder: (child, upload, path) =>
        _UploadDrop(upload: upload, label: path, child: child),
    selectionDragBuilder: (child, entries, download) {
      if (download == null || entries.any((entry) => !entry.attr.isFile)) {
        return child;
      }
      DragItem item(SftpName entry) {
        final result = DragItem(
          suggestedName: entry.filename,
          localData: 'tilde-remote-file',
        );
        result.addVirtualFile(
          format: const SimpleFileFormat(
            windowsFormats: ['application/octet-stream'],
          ),
          provider: (sinkProvider, progress) {
            final control = TransferControl();
            progress.onCancel.addListener(control.cancel);
            unawaited(
              writeVirtualDownload(
                entry: entry,
                control: control,
                sinkProvider: sinkProvider,
                download: download,
              ).whenComplete(
                () => progress.onCancel.removeListener(control.cancel),
              ),
            );
          },
        );
        return result;
      }

      return DragItemWidget(
        allowedOperations: () => [DropOperation.copy],
        dragItemProvider: (_) => item(entries.first),
        child: DraggableWidget(
          onDragConfiguration: (configuration, _) async => DragConfiguration(
            items: [
              configuration.items.first,
              for (final entry in entries.skip(1))
                DragConfigurationItem(
                  item: item(entry),
                  image: configuration.items.first.image,
                ),
            ],
            allowedOperations: [DropOperation.copy],
          ),
          child: child,
        ),
      );
    },
    dropBuilder: (child, upload) => _UploadDrop(upload: upload, child: child),
    dragBuilder: (child, entry, download) => download == null
        ? child
        : DragItemWidget(
            allowedOperations: () => [DropOperation.copy],
            dragItemProvider: (_) {
              final item = DragItem(
                suggestedName: entry.filename,
                localData: 'tilde-remote-file',
              );
              if (!item.virtualFileSupported) return null;
              item.addVirtualFile(
                format: const SimpleFileFormat(
                  windowsFormats: ['application/octet-stream'],
                ),
                provider: (sinkProvider, progress) {
                  final control = TransferControl();
                  progress.onCancel.addListener(control.cancel);
                  unawaited(
                    writeVirtualDownload(
                      entry: entry,
                      control: control,
                      sinkProvider: sinkProvider,
                      download: download,
                    ).whenComplete(
                      () => progress.onCancel.removeListener(control.cancel),
                    ),
                  );
                },
              );
              return item;
            },
            child: DraggableWidget(child: child),
          ),
    child: child,
  );
}

Future<void> writeVirtualDownload({
  required SftpName entry,
  required TransferControl control,
  required EventSink Function({required int fileSize}) sinkProvider,
  required FileExport download,
}) async {
  Directory? temporary;
  EventSink? sink;
  try {
    control.check();
    temporary = await Directory.systemTemp.createTemp('tilde-drag-');
    final file = localDestination(temporary, entry.filename);
    await download(entry, file, control);
    control.check();
    sink = sinkProvider(fileSize: await file.length());
    await for (final chunk in file.openRead()) {
      await control.ready;
      sink.add(chunk);
    }
    control.check();
    sink.close();
  } catch (error, stack) {
    sink ??= sinkProvider(fileSize: 0);
    sink.addError(error, stack);
  } finally {
    await temporary?.delete(recursive: true);
  }
}

class _UploadDrop extends StatefulWidget {
  const _UploadDrop({required this.child, required this.upload, this.label});
  final String? label;
  final Widget child;
  final Future<void> Function(List<String>)? upload;
  @override
  State<_UploadDrop> createState() => _UploadDropState();
}

class _UploadDropState extends State<_UploadDrop> {
  bool _hover = false;
  Future<void> _upload(
    List<Future<Uri?>> pending,
    Future<void> Function(List<String>) upload,
  ) async {
    try {
      final uris = await Future.wait(pending);
      final paths = uris
          .whereType<Uri>()
          .where((uri) => uri.scheme == 'file')
          .map((uri) => uri.toFilePath(windows: true))
          .toList();
      if (mounted && paths.isNotEmpty) await upload(paths);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotImportFiles((error).toString())),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => DropRegion(
    formats: const [Formats.fileUri],
    hitTestBehavior: HitTestBehavior.opaque,
    onDropOver: (event) {
      final accepted =
          widget.upload != null &&
          event.session.allowedOperations.contains(DropOperation.copy) &&
          event.session.items.isNotEmpty &&
          event.session.items.every(
            (item) =>
                item.localData != 'tilde-remote-file' &&
                item.canProvide(Formats.fileUri),
          );
      if (_hover != accepted) setState(() => _hover = accepted);
      return accepted ? DropOperation.copy : DropOperation.none;
    },
    onDropLeave: (_) => setState(() => _hover = false),
    onPerformDrop: (event) async {
      setState(() => _hover = false);
      final upload = widget.upload;
      if (upload == null) return;
      final pending = <Future<Uri?>>[];
      for (final item in event.session.items) {
        final reader = item.dataReader;
        if (reader == null || item.localData == 'tilde-remote-file') continue;
        final value = Completer<Uri?>();
        pending.add(value.future);
        reader.getValue(
          Formats.fileUri,
          value.complete,
          onError: value.completeError,
        );
      }
      // Request the URIs during the native callback, then return before SSH I/O.
      unawaited(_upload(pending, upload));
    },
    child: Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_hover)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: .9),
                alignment: Alignment.center,
                child: Text(
                  context.l10n.uploadTo(
                    (widget.label ?? context.l10n.currentFolder).toString(),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
