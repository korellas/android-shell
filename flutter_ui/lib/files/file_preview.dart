// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show confirm, showErrorDetails;
import '../tilde_design.dart';
import 'transfer.dart';

class FilePreview extends StatefulWidget {
  const FilePreview({
    super.key,
    required this.path,
    required this.load,
    required this.save,
    this.newFile = false,
    this.size,
    this.embedded = false,
    this.host = '',
    this.onDownload,
    this.onClose,
    this.onDirtyChanged,
    this.registerLeaveGuard,
  });
  final String path, host;
  final int? size;
  final Future<Uint8List> Function() load;
  final Future<void> Function(Uint8List) save;
  final bool newFile, embedded;
  final VoidCallback? onDownload, onClose;
  final ValueChanged<bool>? onDirtyChanged;
  final void Function(Future<bool> Function())? registerLeaveGuard;
  @override
  State<FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<FilePreview> {
  final _text = TextEditingController(), _scroll = ScrollController();
  final _undo = UndoHistoryController();
  late final Future<Uint8List> _data;
  bool _textFile = false,
      _editing = false,
      _saving = false,
      _bom = false,
      _allowPop = false;
  String? _error;
  String _savedText = '', _status = '읽기 전용';
  bool get _dirty => _textFile && _text.text != _savedText;
  Future<bool> _canClose() async =>
      !_saving &&
      (!_dirty ||
          await confirm(
            context,
            '변경 내용 버리기',
            '${widget.path}\n저장하지 않은 변경 내용을 버릴까요?',
            action: '버리기',
          ));
  Future<void> _close() async {
    if (widget.embedded && widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (!await _canClose() || !mounted) return;
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _changed() {
    if (!mounted) return;
    widget.onDirtyChanged?.call(_dirty);
    setState(() {
      _error = null;
      _status = _dirty
          ? '저장하지 않음'
          : _editing
          ? '편집 중'
          : '읽기 전용';
    });
  }

  @override
  void initState() {
    super.initState();
    _editing = widget.newFile;
    widget.registerLeaveGuard?.call(_canClose);
    _data = widget.load().then((bytes) {
      if (!mounted) return bytes;
      try {
        final text = utf8.decode(bytes);
        _textFile = !text.contains('\x00');
        _text.text = text;
        _savedText = text;
        _bom =
            bytes.length >= 3 &&
            bytes[0] == 239 &&
            bytes[1] == 187 &&
            bytes[2] == 191;
      } on FormatException {
        _textFile = false;
      }
      _text.addListener(_changed);
      setState(() {});
      return bytes;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _undo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.save(
        Uint8List.fromList([
          ...(_bom ? [239, 187, 191] : <int>[]),
          ...utf8.encode(_text.text),
        ]),
      );
      if (mounted) {
        setState(() {
          _savedText = _text.text;
          _status = '저장했습니다.';
          _error = null;
        });
        widget.onDirtyChanged?.call(false);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _editor() {
    final lines = _text.text.split('\n');
    const style = TextStyle(
      fontFamily: tildeMono,
      fontFamilyFallback: tildeMonoFallback,
      fontSize: 14,
      height: 1.6,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 48,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (context, _) => Stack(
                children: [
                  Positioned(
                    top: 12 - (_scroll.hasClients ? _scroll.offset : 0),
                    left: 0,
                    right: 8,
                    child: Text(
                      List.generate(lines.length, (i) => '${i + 1}').join('\n'),
                      textAlign: TextAlign.right,
                      style: style.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(
                  constraints.maxWidth,
                  lines.fold<int>(0, (n, line) => math.max(n, line.length)) *
                          14.0 +
                      24,
                ),
                height: constraints.maxHeight,
                child: TextField(
                  controller: _text,
                  scrollController: _scroll,
                  undoController: _undo,
                  readOnly: !_editing || _saving,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  autocorrect: false,
                  enableSuggestions: false,
                  textAlignVertical: TextAlignVertical.top,
                  style: style,
                  strutStyle: const StrutStyle(
                    fontFamily: tildeMono,
                    fontSize: 14,
                    height: 1.6,
                    forceStrutHeight: true,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
          _save(),
      const SingleActivator(LogicalKeyboardKey.escape): () => _close(),
    },
    child: PopScope(
      canPop: widget.embedded || _allowPop || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: widget.embedded
              ? null
              : IconButton(
                  tooltip: '뒤로',
                  onPressed: _saving ? null : _close,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${widget.host.isEmpty ? '' : '${widget.host}:'}${widget.path}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: tildeMono,
                  fontFamilyFallback: tildeMonoFallback,
                ),
              ),
            ],
          ),
          actions: [
            if (_textFile)
              if (!_editing)
                TextButton(
                  onPressed: () => setState(() {
                    _editing = true;
                    _status = '편집 중';
                  }),
                  child: const Text('편집'),
                )
              else ...[
                ValueListenableBuilder<UndoHistoryValue>(
                  valueListenable: _undo,
                  builder: (context, value, _) => TextButton(
                    onPressed: value.canUndo && !_saving ? _undo.undo : null,
                    child: const Text('되돌리기'),
                  ),
                ),
                TextButton(
                  onPressed: _dirty && !_saving ? _save : null,
                  child: Text(_saving ? '저장 중…' : '저장'),
                ),
              ],
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: FutureBuilder<Uint8List>(
                future: _data,
                builder: (context, snapshot) {
                  Widget unavailable(String message) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.size == null ? '' : '${formatBytes(widget.size!)} · '}$message',
                            textAlign: TextAlign.center,
                          ),
                          if (widget.onDownload != null) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: widget.onDownload,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('다운로드'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                  if (snapshot.hasError) {
                    return unavailable(fileFailureSummary(snapshot.error!));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_textFile) return _editor();
                  return InteractiveViewer(
                    child: Image.memory(
                      snapshot.data!,
                      errorBuilder: (context, error, stack) =>
                          unavailable('이 파일 형식은 미리보기를 지원하지 않습니다.'),
                    ),
                  );
                },
              ),
            ),
            if (_error != null)
              ListTile(
                title: const Text('저장하지 못했습니다. 변경 내용은 유지됩니다.'),
                trailing: TextButton(
                  onPressed: () => showErrorDetails(context, _error!),
                  child: const Text('자세히'),
                ),
              ),
            SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  '$_status${_textFile ? ' · UTF-8${_bom ? ' BOM' : ''} · ${_text.text.split('\n').length}줄 · ${utf8.encode(_text.text).length + (_bom ? 3 : 0)} B' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
