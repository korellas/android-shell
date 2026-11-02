// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../main.dart' show confirm;

class FilePreview extends StatefulWidget {
  const FilePreview({
    super.key,
    required this.path,
    required this.load,
    required this.save,
    this.newFile = false,
  });
  final String path;
  final Future<Uint8List> Function() load;
  final Future<void> Function(Uint8List) save;
  final bool newFile;
  @override
  State<FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<FilePreview> {
  final _text = TextEditingController();
  late final Future<Uint8List> _data;
  bool _textFile = false, _editing = false, _saving = false, _bom = false;
  String? _error;
  String _savedText = '';
  bool get _dirty => _textFile && _text.text != _savedText;
  Future<void> _close() async {
    if (_saving) return;
    if (_dirty &&
        !await confirm(
          context,
          '변경 내용 버리기',
          '저장하지 않은 변경 내용을 버릴까요?',
          action: '버리기',
        )) {
      return;
    }
    if (mounted) {
      setState(() => _savedText = _text.text);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _editing = widget.newFile;
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
      setState(() {});
      return bytes;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
          _error = '저장했습니다.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Dialog(
      child: SizedBox(
        width: 900,
        height: 650,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.path,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: _saving ? null : _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: FutureBuilder<Uint8List>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: SelectableText('${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!_textFile) {
                      return InteractiveViewer(
                        child: Image.memory(
                          snapshot.data!,
                          errorBuilder: (context, error, stack) => const Center(
                            child: Text(
                              '이 형식은 미리보기를 지원하지 않습니다. 다운로드해서 열어 주세요.',
                            ),
                          ),
                        ),
                      );
                    }
                    return TextField(
                      controller: _text,
                      onChanged: (_) => setState(() => _error = null),
                      readOnly: !_editing || _saving,
                      expands: true,
                      maxLines: null,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
              if (_error != null)
                Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _textFile && !_saving
                        ? () => setState(() => _editing = !_editing)
                        : null,
                    child: Text(_editing ? '읽기 전용' : '편집'),
                  ),
                  FilledButton(
                    onPressed: _editing && !_saving ? _save : null,
                    child: Text(_saving ? '저장 중…' : '서버에 저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
