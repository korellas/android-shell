// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import '../main.dart' show askText;
import '../tilde_design.dart';
import '../tilde_controls.dart';
import 'sftp_file_operations.dart';
import 'transfer.dart';

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
          Text('권한 변경', style: Theme.of(context).textTheme.titleLarge),
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
              for (final title in ['읽기', '쓰기', '실행'])
                Expanded(child: Text(title, textAlign: TextAlign.center)),
            ],
          ),
          for (var row = 0; row < 3; row++)
            Row(
              children: [
                SizedBox(width: 80, child: Text(['소유자', '그룹', '기타'][row])),
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
          const Text('8진수 권한', style: TextStyle(fontSize: 13)),
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
                  ? '0–7로 된 3자리 또는 4자리 값을 입력하세요.'
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
                child: const Text('취소'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: mode == null
                    ? null
                    : () => Navigator.pop(context, mode),
                child: const Text('권한 바꾸기'),
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
        setState(() => error = '폴더를 열지 못했습니다. 경로와 접근 권한을 확인하세요.\n$e');
      }
    } finally {
      if (mounted && token == request) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final name = await askText(
      context,
      '새 폴더',
      validator: remoteNameError,
      action: '만들기',
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
                  ? '이동할 폴더'
                  : widget.names.length == 1
                  ? '${widget.names.single} 이동'
                  : '${widget.names.length}개 항목 이동',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: '상위 폴더',
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
                          decoration: const InputDecoration(hintText: '폴더 경로'),
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
                  tooltip: '경로 편집',
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
                  child: const Text('새 폴더'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: loading || error != null
                      ? null
                      : () => Navigator.pop(context, path),
                  child: const Text('여기로 이동'),
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
              '${entries.length}개 항목을 영구 삭제할까요?',
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
                                    ? '하위 항목 ${snapshot.data![entry.filename]! - 1}개'
                                    : '내용 확인 중…',
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
              const Text('폴더 내용을 확인하지 못했습니다. 다시 시도해 주세요.')
            else if (!snapshot.hasData)
              const LinearProgressIndicator()
            else
              Text(
                entries.any((entry) => entry.attr.isDirectory)
                    ? '폴더 안 내용을 포함해 ${snapshot.data!.values.fold<int>(0, (total, value) => total + value)}개 항목을 모두 지웁니다. 되돌릴 수 없습니다.'
                    : '휴지통 없이 바로 지웁니다. 되돌릴 수 없습니다.',
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: tildeDangerButtonStyle(context),
                  onPressed: snapshot.hasData
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('영구 삭제'),
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
      ? '수정일 알 수 없음'
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
            '같은 이름의 파일이 있습니다',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (widget.totalFiles != null && widget.totalFiles! > 0)
            Text(
              '전송 ${widget.currentFile} / ${widget.totalFiles}개',
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
          const Text('남길 파일을 각각 선택하세요.'),
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
                    ? (widget.upload ? '올리는 파일' : '내려받는 파일')
                    : (widget.upload ? '서버의 기존 파일' : '기기의 기존 파일'),
              ),
              subtitle: Text(
                '${(incoming ? widget.sourceSize : widget.existing.size) == null ? '크기 알 수 없음' : formatBytes((incoming ? widget.sourceSize : widget.existing.size)!)}\n${date(incoming ? widget.sourceModified : widget.existing.modifyTime)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              isThreeLine: true,
            ),
          const Divider(),
          Semantics(
            liveRegion: true,
            child: Text(
              switch (choice) {
                'skip' => '기존 파일을 유지하고 이 파일의 복사를 건너뜁니다.',
                'keep' => '둘 다 보관합니다. 복사되는 파일은 확장자 앞에 (1)부터 비어 있는 번호를 붙입니다.',
                'replace' => '복사되는 파일로 기존 파일을 덮어씁니다. 되돌릴 수 없습니다.',
                _ => '복사를 취소합니다. 기존 파일은 그대로 유지됩니다.',
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
                '남은 ${widget.totalFiles! - widget.currentFile!}개에도 적용',
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
                child: const Text('전송 취소'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, (action: choice, apply: apply)),
                child: Text(choice == 'cancel' ? '복사 취소' : '계속'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
