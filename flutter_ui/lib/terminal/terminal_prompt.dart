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
  bool busy = false, revealPassword = false, savePassword = false;
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
      await widget.onResponse(
        value is String &&
                savePassword &&
                widget.prompt['canSavePassword'] == true
            ? {'value': value, 'savePassword': true}
            : value,
      );
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
    final formats = [
      for (final option in const [
        ('sha256', 'SHA-256'),
        ('md5', 'MD5'),
        ('randomArt', '그림'),
        ('bubblebabble', '단어'),
      ])
        if ('${prompt[option.$1] ?? ''}'.isNotEmpty) option,
    ];
    final rawFingerprint = '${prompt[fingerprint] ?? ''}';
    final title = hostKey
        ? '처음 연결하는 서버입니다'
        : biometric
        ? '생체인증'
        : '${prompt['nickname'] ?? '서버'} 로그인';
    final instructions = '${prompt['instructions'] ?? ''}';
    final message = '${prompt['message'] ?? ''}';
    final showInstructions =
        instructions.trim().isNotEmpty && instructions.trim() != title;
    final showMessage =
        !string &&
        message.trim().isNotEmpty &&
        message.trim() != title &&
        message != instructions;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
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
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (hostKey || prompt['address'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: tildePathText(
                  hostKey ? '${prompt['hostname']}' : '${prompt['address']}',
                  style: const TextStyle(fontFamily: tildeMono, fontSize: 13),
                ),
              ),
            if (!hostKey && !biometric && (showInstructions || showMessage))
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '서버 메시지',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (showInstructions) SelectableText(instructions),
                    if (showMessage) SelectableText(message),
                  ],
                ),
              ),
            if (string) ...[
              const SizedBox(height: 12),
              TextField(
                controller: text,
                enabled: enabled,
                autofocus: widget.enabled,
                obscureText: prompt['password'] == true && !revealPassword,
                autocorrect: false,
                enableSuggestions: prompt['password'] != true,
                keyboardType: prompt['password'] == true
                    ? TextInputType.visiblePassword
                    : TextInputType.text,
                textInputAction: TextInputAction.done,
                onSubmitted: enabled ? respond : null,
                decoration: InputDecoration(
                  labelText: prompt['passwordKind'] == 'host'
                      ? '비밀번호'
                      : '${prompt['hint'] ?? '인증'}',
                  suffixIcon: prompt['password'] == true
                      ? IconButton(
                          tooltip: revealPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                          onPressed: () =>
                              setState(() => revealPassword = !revealPassword),
                          icon: Icon(
                            revealPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        )
                      : null,
                ),
              ),
              if (prompt['canSavePassword'] == true)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('이 기기에 저장'),
                  value: savePassword,
                  onChanged: enabled
                      ? (value) => setState(() => savePassword = value ?? false)
                      : null,
                ),
            ] else if (hostKey) ...[
              const SizedBox(height: 12),
              const Text('서버 관리자가 알려 준 지문과 같은지 확인하세요.'),
              const SizedBox(height: 16),
              Text(
                '${prompt['keyType']}${prompt['keySize'] == null ? '' : ' · ${prompt['keySize']}'}',
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: fingerprint == 'sha256'
                        ? Semantics(
                            label: rawFingerprint,
                            child: Wrap(
                              spacing: 6,
                              children: [
                                if (rawFingerprint.startsWith('SHA256:'))
                                  const Text(
                                    'SHA256:',
                                    style: TextStyle(fontFamily: tildeMono),
                                  ),
                                for (final chunk
                                    in RegExp(r'.{1,4}').allMatches(
                                      rawFingerprint.replaceFirst(
                                        'SHA256:',
                                        '',
                                      ),
                                    ))
                                  Text(
                                    chunk.group(0)!,
                                    style: const TextStyle(
                                      fontFamily: tildeMono,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : SelectableText(
                            rawFingerprint,
                            style: const TextStyle(fontFamily: tildeMono),
                          ),
                  ),
                  IconButton(
                    tooltip: '지문 복사',
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: rawFingerprint)),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              if (formats.length > 1)
                tildeSegments(
                  context,
                  '지문 형식',
                  formats,
                  fingerprint,
                  enabled
                      ? (value) => setState(() => fingerprint = value as String)
                      : null,
                ),
            ] else if (biometric) ...[
              const SizedBox(height: 12),
              SelectableText('${prompt['nickname']} 키로 인증합니다.'),
            ],
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: enabled
                      ? () => respond(string ? null : false)
                      : null,
                  child: Text(string || hostKey || biometric ? '연결 취소' : '거절'),
                ),
                FilledButton(
                  onPressed: enabled
                      ? () => respond(string ? text.text : true)
                      : null,
                  child: Text(
                    hostKey
                        ? '신뢰하고 연결'
                        : string
                        ? '로그인'
                        : biometric
                        ? '인증'
                        : '계속',
                  ),
                ),
              ],
            ),
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
  bool opening = false, presented = false;
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
      if (mounted && widget.enabled && !opening && !presented) {
        present();
      }
    });
  }

  Future<void> present() async {
    presented = true;
    setState(() => opening = true);
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
    if (mounted) setState(() => opening = false);
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
  Widget build(BuildContext context) => opening
      ? const SizedBox.shrink()
      : Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListTile(
            title: Text('${widget.prompt['nickname'] ?? '서버'} 로그인 대기'),
            trailing: TextButton(
              onPressed: widget.enabled ? present : null,
              child: const Text('로그인 계속'),
            ),
          ),
        );
}
