// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine.dart';
import '../tilde_design.dart';
import '../tilde_controls.dart';

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
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                  Tooltip(
                    message: '인증 전송',
                    child: TextButton(
                      onPressed: enabled ? () => respond(text.text) : null,
                      child: const Text('확인'),
                    ),
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
                        style: const TextStyle(
                          fontFamily: tildeMono,
                          fontFamilyFallback: tildeMonoFallback,
                        ),
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
                tildeSegments(
                  context,
                  '지문 형식',
                  const [
                    ('sha256', 'SHA-256'),
                    ('md5', 'MD5'),
                    ('randomArt', '그림'),
                    ('bubblebabble', '단어'),
                  ],
                  fingerprint,
                  enabled
                      ? (value) => setState(() => fingerprint = value as String)
                      : null,
                  labels: const {
                    'randomArt': Tooltip(
                      message: 'Random Art',
                      child: Text('그림'),
                    ),
                    'bubblebabble': Tooltip(
                      message: 'Bubblebabble',
                      child: Text('단어'),
                    ),
                  },
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
                    child: Text(hostKey ? '연결 취소' : '아니요'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: enabled ? () => respond(true) : null,
                    child: Text(
                      hostKey
                          ? '신뢰하고 연결'
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

class TerminalPromptSurface extends StatefulWidget {
  const TerminalPromptSurface({
    super.key,
    required this.prompt,
    required this.onResponse,
    this.enabled = true,
  });
  final EngineRecord prompt;
  final Future<void> Function(Object?) onResponse;
  final bool enabled;
  @override
  State<TerminalPromptSurface> createState() => _TerminalPromptSurfaceState();
}

class _TerminalPromptSurfaceState extends State<TerminalPromptSurface> {
  bool opening = false;
  Route<dynamic>? route;
  NavigatorState? navigator;
  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(covariant TerminalPromptSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) schedule();
  }

  void schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.enabled &&
          !opening &&
          widget.prompt['type'] == 'hostKey') {
        present();
      }
    });
  }

  Future<void> present() async {
    opening = true;
    var responded = false;
    final response = widget.onResponse;
    await showTildeSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        route = ModalRoute.of(c);
        navigator = Navigator.of(c);
        return SingleChildScrollView(
          child: TerminalPrompt(
            prompt: widget.prompt,
            onResponse: (value) async {
              responded = true;
              try {
                await response(value);
              } finally {
                final current = route, nav = navigator;
                if (current?.isActive == true && nav?.mounted == true) {
                  if (current!.isCurrent) {
                    nav!.pop();
                  } else {
                    nav!.removeRoute(current);
                  }
                }
              }
            },
          ),
        );
      },
    );
    if (!responded && mounted) {
      await response(widget.prompt['type'] == 'string' ? null : false);
    }
    opening = false;
  }

  @override
  void dispose() {
    final current = route, nav = navigator;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (current?.isActive == true && nav?.mounted == true) {
        nav!.removeRoute(current!);
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.prompt['type'] == 'hostKey'
      ? const SizedBox.shrink()
      : TerminalPrompt(
          prompt: widget.prompt,
          onResponse: widget.onResponse,
          enabled: widget.enabled,
        );
}
