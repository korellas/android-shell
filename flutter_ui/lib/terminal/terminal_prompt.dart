// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine.dart';
import '../tilde_design.dart';

/// Authentication belongs to its console and leaves other sessions accessible.
class TerminalPrompt extends StatefulWidget {
  const TerminalPrompt({
    super.key,
    required this.prompt,
    required this.onResponse,
    this.enabled = true,
  });

  final EngineRecord prompt;
  final Future<void> Function(Object? value) onResponse;
  final bool enabled;

  @override
  State<TerminalPrompt> createState() => _TerminalPromptState();
}

class _TerminalPromptState extends State<TerminalPrompt> {
  final text = TextEditingController();
  bool busy = false;
  String fingerprint = 'sha256';

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> respond(Object? value) async {
    if (busy || !widget.enabled) return;
    setState(() => busy = true);
    FocusScope.of(context).unfocus();
    try {
      await widget.onResponse(value);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompt = widget.prompt;
    final enabled = widget.enabled && !busy;
    final string = prompt['type'] == 'string';
    final hostKey = prompt['type'] == 'hostKey';
    final biometric = prompt['type'] == 'biometric';
    final instructions = hostKey
        ? '${prompt['hostname']} 서버 키 확인'
        : biometric
        ? '생체인증'
        : '${prompt['instructions'] ?? ''}';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (instructions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  instructions,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            if (string)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: text,
                      enabled: enabled,
                      autofocus: widget.enabled,
                      obscureText: prompt['password'] == true,
                      autocorrect: false,
                      enableSuggestions: prompt['password'] != true,
                      keyboardType: prompt['password'] == true
                          ? TextInputType.visiblePassword
                          : TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onSubmitted: enabled ? respond : null,
                      decoration: InputDecoration(
                        labelText: '${prompt['hint'] ?? '인증'}',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '인증 전송',
                    onPressed: enabled ? () => respond(text.text) : null,
                    icon: const Icon(Icons.send_outlined),
                  ),
                  IconButton(
                    tooltip: '인증 취소',
                    onPressed: enabled ? () => respond(null) : null,
                    icon: const Icon(Icons.close),
                  ),
                ],
              )
            else ...[
              if (hostKey) ...[
                Text('${prompt['keyType']} ${prompt['keySize']}'),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        '${prompt[fingerprint] ?? ''}',
                        style: const TextStyle(fontFamily: tildeMono),
                      ),
                    ),
                    IconButton(
                      tooltip: '지문 복사',
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: '${prompt[fingerprint] ?? ''}'),
                      ),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
                DropdownButton<String>(
                  value: fingerprint,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'sha256', child: Text('SHA-256')),
                    DropdownMenuItem(
                      value: 'randomArt',
                      child: Text('Random Art'),
                    ),
                    DropdownMenuItem(
                      value: 'bubblebabble',
                      child: Text('Bubblebabble'),
                    ),
                    DropdownMenuItem(value: 'md5', child: Text('MD5')),
                  ],
                  onChanged: enabled
                      ? (value) => setState(() => fingerprint = value!)
                      : null,
                ),
                const Text('이 서버 키를 신뢰하고 계속할까요?'),
              ] else
                Text(
                  biometric
                      ? '${prompt['nickname']} 키로 인증해요.'
                      : '${prompt['message'] ?? ''}',
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: enabled ? () => respond(false) : null,
                    child: const Text('아니요'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: enabled ? () => respond(true) : null,
                    child: Text(
                      hostKey
                          ? '서버 키 신뢰'
                          : biometric
                          ? '인증'
                          : '예',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
