// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:android_shell_ui/ssh/ssh_session.dart';
import 'package:flutter/material.dart';
import 'package:xterm2/xterm.dart';
import 'package:android_shell_ui/terminal/images/image_terminal.dart';

import 'package:android_shell_ui/terminal/terminal_input.dart';
import 'package:android_shell_ui/terminal/terminal_pane.dart';

void main() => runApp(const SshProbeApp());

class SshProbeApp extends StatelessWidget {
  const SshProbeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: const SshProbePage(),
  );
}

class SshProbePage extends StatefulWidget {
  const SshProbePage({super.key});

  @override
  State<SshProbePage> createState() => _SshProbePageState();
}

class _SshProbePageState extends State<SshProbePage> {
  final terminal = InlineImageTerminal();
  final controller = TerminalController();
  late final input = TerminalInputController(terminal: terminal);
  final focus = FocusNode();
  SshSession? session;
  int generation = 0;
  bool busy = false;
  String status = '로컬 입력 검증';

  @override
  void initState() {
    super.initState();
    terminal.write('공식 SSH·터미널 라이브러리 검증\r\n');
    terminal.onOutput = (text) {
      if (session case final current? when current.sessionOpen) {
        unawaited(
          current.write(utf8.encode(text)).catchError((Object _) {
            if (identical(session, current)) disconnect();
          }),
        );
      } else if (!busy) {
        terminal.write(text == '\r' ? '\r\n' : text);
      }
    };
    terminal.onResize = (columns, rows, width, height) {
      session?.resize(
        SshPty(
          columns: columns,
          rows: rows,
          pixelWidth: width * columns,
          pixelHeight: height * rows,
        ),
      );
    };
  }

  Future<void> connect() async {
    final host = TextEditingController();
    final port = TextEditingController(text: '22');
    final username = TextEditingController();
    final password = TextEditingController();
    final fingerprint = TextEditingController();
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SSH 검증 연결'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: host,
                  decoration: const InputDecoration(labelText: '호스트'),
                  validator: (value) =>
                      value!.trim().isEmpty ? '호스트를 입력하세요' : null,
                ),
                TextFormField(
                  controller: port,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '포트'),
                  validator: (value) {
                    final number = int.tryParse(value ?? '');
                    return number == null || number < 1 || number > 65535
                        ? '포트를 확인하세요'
                        : null;
                  },
                ),
                TextFormField(
                  controller: username,
                  decoration: const InputDecoration(labelText: '사용자'),
                  validator: (value) =>
                      value!.trim().isEmpty ? '사용자를 입력하세요' : null,
                ),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                ),
                TextFormField(
                  controller: fingerprint,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '확인한 서버 SHA256 지문',
                  ),
                  validator: (value) =>
                      (value ?? '').trim().startsWith('SHA256:')
                      ? null
                      : '서버에서 확인한 SHA256 지문을 입력하세요',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('연결'),
          ),
        ],
      ),
    );
    final endpoint = host.text.trim();
    final sshPort = int.tryParse(port.text) ?? 22;
    final user = username.text.trim();
    final secret = password.text;
    final expectedFingerprint = fingerprint.text.trim();
    for (final field in [host, port, username, password, fingerprint]) {
      field.dispose();
    }
    if (accepted != true || !mounted) return;

    final attempt = ++generation;
    bool active() => mounted && generation == attempt;
    setState(() {
      busy = true;
      status = 'SSH 연결 중';
    });
    final output = StreamController<List<int>>();
    final outputDone = output.stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach((text) {
          if (!active()) return;
          try {
            terminal.write(text);
          } on StateError {
            disconnect();
          }
        });
    final connection = SshSession(
      endpoints: [
        SshEndpoint(
          host: endpoint,
          port: sshPort,
          username: user,
          connectTimeout: const Duration(seconds: 10),
          authTimeout: const Duration(seconds: 20),
          onPassword: () => active() ? secret : null,
          verifyHostKey: (_, presented) =>
              active() && utf8.decode(presented) == expectedFingerprint,
        ),
      ],
      pty: SshPty(columns: terminal.viewWidth, rows: terminal.viewHeight),
      onOutput: output.add,
    );
    session = connection;
    terminal.write('\x1b[2J\x1b[H');
    try {
      await connection.connect();
      if (!active()) return;
      setState(() => status = 'SSH 연결됨');
      focus.requestFocus();
      await connection.done;
    } catch (error) {
      if (active()) terminal.write('\r\n연결 종료: ${error.runtimeType}\r\n');
    } finally {
      await connection.close();
      await output.close();
      await outputDone;
      if (active()) {
        session = null;
        setState(() {
          busy = false;
          status = '로컬 입력 검증';
        });
      }
    }
  }

  void disconnect() {
    generation++;
    unawaited(session?.close());
    session = null;
    if (mounted) {
      setState(() {
        busy = false;
        status = '로컬 입력 검증';
      });
    }
  }

  @override
  void dispose() {
    generation++;
    unawaited(session?.close());
    input.dispose();
    terminal.dispose();
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('공통 SSH 검증'),
      actions: [
        IconButton(
          tooltip: '오픈소스 라이선스',
          onPressed: () => showLicensePage(context: context),
          icon: const Icon(Icons.info_outline),
        ),
        TextButton(
          onPressed: busy ? disconnect : connect,
          child: Text(busy ? '종료' : '연결'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(8), child: Text(status)),
          Expanded(
            child: TerminalPane(
              terminal: terminal,
              controller: controller,
              input: input,
              focusNode: focus,
            ),
          ),
        ],
      ),
    ),
  );
}
