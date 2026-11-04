// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../engine.dart';
import '../tilde_design.dart';
import '../tilde_controls.dart';
import '../l10n/strings.dart';

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
      for (final option in [
        ('sha256', 'SHA-256'),
        ('md5', 'MD5'),
        ('randomArt', context.l10n.image),
        ('bubblebabble', context.l10n.words),
      ])
        if ('${prompt[option.$1] ?? ''}'.isNotEmpty) option,
    ];
    final rawFingerprint = '${prompt[fingerprint] ?? ''}';
    final title = hostKey
        ? context.l10n.firstConnectionToThisServer
        : biometric
        ? context.l10n.biometricAuthentication
        : context.l10n.logInTo(
            (prompt['nickname'] ?? context.l10n.server).toString(),
          );
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
            if (prompt['address'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: tildePathText(
                  '${prompt['address']}',
                  style: const TextStyle(fontFamily: tildeMono, fontSize: 13),
                ),
              ),
            if (!hostKey && '${prompt['instructions'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '${prompt['instructions']}',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                      ? context.l10n.password
                      : '${prompt['hint'] ?? context.l10n.authentication}',
                  suffixIcon: prompt['password'] == true
                      ? IconButton(
                          tooltip: revealPassword
                              ? context.l10n.hidePassword
                              : context.l10n.showPassword,
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
                  title: Text(context.l10n.saveOnThisDevice),
                  value: savePassword,
                  onChanged: enabled
                      ? (value) => setState(() => savePassword = value ?? false)
                      : null,
                ),
            ] else if (hostKey) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.checkThatThisFingerprintMatchesTheOneProvidedBy,
              ),
              const SizedBox(height: 16),
              Text(
                '${prompt['hostname']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: tildeMono),
              ),
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
                    tooltip: context.l10n.copyFingerprint,
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: rawFingerprint)),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              if (formats.length > 1)
                tildeSegments(
                  context,
                  context.l10n.fingerprintFormat,
                  formats,
                  fingerprint,
                  enabled
                      ? (value) => setState(() => fingerprint = value as String)
                      : null,
                ),
            ] else ...[
              const SizedBox(height: 12),
              SelectableText(
                biometric
                    ? context.l10n.authenticateWithKey(
                        (prompt['nickname']).toString(),
                      )
                    : '${prompt['message'] ?? ''}',
              ),
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
                  child: Text(
                    string || hostKey || biometric
                        ? context.l10n.cancelConnection
                        : context.l10n.reject,
                  ),
                ),
                FilledButton(
                  onPressed: enabled
                      ? () => respond(string ? text.text : true)
                      : null,
                  child: Text(
                    hostKey
                        ? context.l10n.trustAndConnect
                        : string
                        ? context.l10n.logIn
                        : biometric
                        ? context.l10n.authentication
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
            title: Text(
              context.l10n.waitingForLogin(
                (widget.prompt['nickname'] ?? context.l10n.server).toString(),
              ),
            ),
            trailing: TextButton(
              onPressed: widget.enabled ? present : null,
              child: Text(context.l10n.continueLogin),
            ),
          ),
        );
}
