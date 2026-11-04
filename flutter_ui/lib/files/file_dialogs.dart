// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import '../main.dart' show askText;
import '../tilde_design.dart';
import '../tilde_controls.dart';
import 'sftp_file_operations.dart';
import 'transfer.dart';
import '../l10n/strings.dart';

class FilePermissionsPrompt extends StatefulWidget {
  const FilePermissionsPrompt({super.key, required this.names, this.initial});
  final List<String> names;
  final int? initial;
  @override
  State<FilePermissionsPrompt> createState() => _FilePermissionsPromptState();
}

class _FilePermissionsPromptState extends State<FilePermissionsPrompt> {
  late int? mode = widget.initial;
  late final input = TextEditingController(
    text: mode?.toRadixString(8).padLeft(4, '0') ?? '',
  );
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.changePermissions,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.names.join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(width: 80),
              for (final title in [
                context.l10n.read,
                context.l10n.write,
                context.l10n.execute,
              ])
                Expanded(child: Text(title, textAlign: TextAlign.center)),
            ],
          ),
          for (var row = 0; row < 3; row++)
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    [
                      context.l10n.owner,
                      context.l10n.group,
                      context.l10n.other,
                    ][row],
                  ),
                ),
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: Checkbox(
                      key: ValueKey('permission-${8 - row * 3 - col}'),
                      value:
                          mode != null &&
                          (mode! & (1 << (8 - row * 3 - col))) != 0,
                      onChanged: (value) => setState(() {
                        final bit = 1 << (8 - row * 3 - col);
                        mode = value == true
                            ? (mode ?? 0) | bit
                            : (mode ?? 0) & ~bit;
                        input.text = mode!.toRadixString(8).padLeft(4, '0');
                      }),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Text(context.l10n.octalPermissions, style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: input,
            onFieldSubmitted: (_) {
              if (mode != null) Navigator.pop(context, mode);
            },
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: tildeMono),
            decoration: InputDecoration(
              hintText: '0644',
              errorText: input.text.isNotEmpty && mode == null
                  ? context.l10n.enterThreeOrFourDigitsFrom0To7
                  : null,
            ),
            onChanged: (value) => setState(
              () => mode = RegExp(r'^[0-7]{3,4}$').hasMatch(value)
                  ? int.parse(value, radix: 8)
                  : null,
            ),
          ),
          if (mode != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                remotePermissions(mode),
                style: const TextStyle(fontFamily: tildeMono),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: mode == null
                    ? null
                    : () => Navigator.pop(context, mode),
                child: Text(context.l10n.changePermissions2),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class RemoteFolderPicker extends StatefulWidget {
  const RemoteFolderPicker({
    super.key,
    required this.files,
    required this.path,
    this.favorites = const [],
    this.names = const [],
  });
  final SftpClient files;
  final String path;
  final List<String> favorites, names;
  @override
  State<RemoteFolderPicker> createState() => _RemoteFolderPickerState();
}

class _RemoteFolderPickerState extends State<RemoteFolderPicker> {
  late String path = widget.path;
  late final input = TextEditingController(text: path);
  final focus = FocusNode();
  List<SftpName> folders = [];
  bool loading = true, editing = false;
  String? error, selected;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load(path);
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> load(String value) async {
    final contextStrings = context.l10n;
    final token = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final absolute = await widget.files
          .absolute(value)
          .timeout(const Duration(seconds: 30));
      final list = await widget.files
          .listdir(absolute)
          .timeout(const Duration(seconds: 30));
      if (!mounted || token != request) return;
      setState(() {
        path = absolute;
        input.text = path;
        folders =
            list
                .where(
                  (item) =>
                      item.filename != '.' &&
                      item.filename != '..' &&
                      item.attr.isDirectory &&
                      !item.attr.isSymbolicLink,
                )
                .toList()
              ..sort((a, b) => a.filename.compareTo(b.filename));
        editing = false;
        selected = null;
      });
    } catch (e) {
      if (mounted && token == request) {
        setState(
          () => error = contextStrings
              .couldNotOpenFolderCheckThePathAndPermissions((e).toString()),
        );
      }
    } finally {
      if (mounted && token == request) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final contextStrings = context.l10n;
    final name = await askText(
      context,
      contextStrings.newFolder,
      validator: remoteNameError,
      action: contextStrings.create,
    );
    if (name == null || !mounted) return;
    try {
      await SftpFileOperations(widget.files).createDirectory(path, name);
      await load(path);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.names.isEmpty
                  ? context.l10n.destinationFolder
                  : widget.names.length == 1
                  ? context.l10n.move((widget.names.single).toString())
                  : context.l10n.moveItems((widget.names.length).toString()),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: context.l10n.parentFolder,
                  onPressed: loading || path == '/'
                      ? null
                      : () => load(
                          path.substring(0, path.lastIndexOf('/')).isEmpty
                              ? '/'
                              : path.substring(0, path.lastIndexOf('/')),
                        ),
                  icon: const Icon(Icons.arrow_upward),
                ),
                Expanded(
                  child: editing
                      ? TextField(
                          controller: input,
                          focusNode: focus,
                          onSubmitted: load,
                          style: const TextStyle(
                            fontFamily: tildeMono,
                            fontFamilyFallback: tildeMonoFallback,
                          ),
                          decoration: InputDecoration(
                            hintText: context.l10n.folderPath,
                          ),
                        )
                      : Text(
                          path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: tildeMono,
                            fontFamilyFallback: tildeMonoFallback,
                          ),
                        ),
                ),
                IconButton(
                  tooltip: context.l10n.editPath,
                  onPressed: () {
                    setState(() => editing = true);
                    focus.requestFocus();
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            if (widget.favorites.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final favorite in widget.favorites)
                      TextButton(
                        onPressed: () => load(favorite),
                        child: Text(favorite),
                      ),
                  ],
                ),
              ),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final folder in folders)
                    GestureDetector(
                      onDoubleTap: tildePointer(context)
                          ? () => load(remoteChild(path, folder.filename))
                          : null,
                      child: ListTile(
                        selected: selected == folder.filename,
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(folder.filename),
                        onTap: () => tildePointer(context)
                            ? setState(() => selected = folder.filename)
                            : load(remoteChild(path, folder.filename)),
                      ),
                    ),
                ],
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: loading ? null : create,
                  child: Text(context.l10n.newFolder),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: loading || error != null
                      ? null
                      : () => Navigator.pop(context, path),
                  child: Text(context.l10n.moveHere),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class FileDeletePrompt extends StatelessWidget {
  const FileDeletePrompt({
    super.key,
    required this.entries,
    required this.counts,
  });
  final List<SftpName> entries;
  final Future<Map<String, int>> counts;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: FutureBuilder<Map<String, int>>(
        future: counts,
        builder: (context, snapshot) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.permanentlyDeleteItems((entries.length).toString()),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final entry in entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          entry.attr.isDirectory
                              ? Icons.folder_outlined
                              : entry.attr.isSymbolicLink
                              ? Icons.link
                              : Icons.description_outlined,
                        ),
                        title: Text(entry.filename),
                        subtitle: entry.attr.isDirectory
                            ? Text(
                                snapshot.hasData
                                    ? context.l10n.childItems(
                                        (snapshot.data![entry.filename]! - 1)
                                            .toString(),
                                      )
                                    : context.l10n.checkingContents,
                              )
                            : entry.attr.size == null
                            ? null
                            : Text(formatBytes(entry.attr.size!)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              Text(context.l10n.couldNotInspectFolderContentsTryAgain)
            else if (!snapshot.hasData)
              const LinearProgressIndicator()
            else
              Text(
                entries.any((entry) => entry.attr.isDirectory)
                    ? context.l10n
                          .deleteAllItemsIncludingFolderContentsThisCannotBe(
                            (snapshot.data!.values.fold<int>(
                              0,
                              (total, value) => total + value,
                            )).toString(),
                          )
                    : context
                          .l10n
                          .deleteImmediatelyWithoutUsingTrashThisCannotBeUndone,
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: tildeDangerButtonStyle(context),
                  onPressed: snapshot.hasData
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(context.l10n.deletePermanently),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class FileConflictPrompt extends StatefulWidget {
  const FileConflictPrompt({
    super.key,
    required this.destination,
    required this.sourceSize,
    required this.sourceModified,
    required this.existing,
    required this.upload,
    this.currentFile,
    this.totalFiles,
  });
  final String destination;
  final int? sourceSize, sourceModified;
  final SftpFileAttrs existing;
  final bool upload;
  final int? currentFile, totalFiles;
  @override
  State<FileConflictPrompt> createState() => _FileConflictPromptState();
}

class _FileConflictPromptState extends State<FileConflictPrompt> {
  bool keepIncoming = false;
  bool keepExisting = true;
  bool apply = false;
  String get choice => keepIncoming
      ? (keepExisting ? 'keep' : 'replace')
      : (keepExisting ? 'skip' : 'cancel');
  String date(int? seconds) => seconds == null
      ? context.l10n.unknownModificationDate
      : DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
        ).toLocal().toString().substring(0, 16);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.aFileWithTheSameNameExists,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (widget.totalFiles != null && widget.totalFiles! > 0)
            Text(
              context.l10n.transferringItems(
                (widget.currentFile).toString(),
                (widget.totalFiles).toString(),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          tildePathText(
            widget.destination,
            style: const TextStyle(
              fontFamily: tildeMono,
              fontFamilyFallback: tildeMonoFallback,
            ),
          ),
          const SizedBox(height: 16),
          Text(context.l10n.chooseWhichFileToKeepForEachConflict),
          const SizedBox(height: 8),
          for (final incoming in [true, false])
            CheckboxListTile(
              key: ValueKey(
                incoming ? 'conflict-incoming' : 'conflict-existing',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              value: incoming ? keepIncoming : keepExisting,
              onChanged: (value) => setState(() {
                if (incoming) {
                  keepIncoming = value ?? false;
                } else {
                  keepExisting = value ?? false;
                }
                if (choice == 'cancel') apply = false;
              }),
              title: Text(
                incoming
                    ? (widget.upload
                          ? context.l10n.fileBeingUploaded
                          : context.l10n.fileBeingDownloaded)
                    : (widget.upload
                          ? context.l10n.existingFileOnServer
                          : context.l10n.existingFileOnDevice),
              ),
              subtitle: Text(
                '${(incoming ? widget.sourceSize : widget.existing.size) == null ? context.l10n.unknownSize : formatBytes((incoming ? widget.sourceSize : widget.existing.size)!)}\n${date(incoming ? widget.sourceModified : widget.existing.modifyTime)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              isThreeLine: true,
            ),
          const Divider(),
          Semantics(
            liveRegion: true,
            child: Text(
              switch (choice) {
                'skip' =>
                  context.l10n.keepTheExistingFileAndSkipCopyingThisFile,
                'keep' =>
                  context.l10n.keepBothAddTheFirstAvailableNumberStartingAt,
                'replace' =>
                  context.l10n.overwriteTheExistingFileWithTheCopiedFileThis,
                _ => context.l10n.cancelCopyingKeepTheExistingFile,
              },
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: choice == 'replace'
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
          if (widget.totalFiles != null &&
              widget.currentFile != null &&
              widget.totalFiles! > widget.currentFile!)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.l10n.applyToRemainingItems(
                  (widget.totalFiles! - widget.currentFile!).toString(),
                ),
              ),
              value: apply,
              onChanged: choice == 'cancel'
                  ? null
                  : (value) => setState(() => apply = value ?? false),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancelTransfer),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, (action: choice, apply: apply)),
                child: Text(
                  choice == 'cancel'
                      ? context.l10n.cancelCopy
                      : context.l10n.continueAction,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
