/*
 * ConnectBot: simple, powerful, open-source SSH client for Android
 * Copyright 2026 Kenny Root
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'tilde_controls.dart';
import 'tilde_design.dart';
import 'package:flutter/material.dart';
import 'engine.dart';
import 'main.dart' show showErrorDetails;

class AutomationPage extends StatefulWidget {
  final AndroidEngine engine;
  final EngineRecord host;
  const AutomationPage({super.key, required this.engine, required this.host});
  @override
  State<AutomationPage> createState() => _AutomationPageState();
}

class _AutomationPageState extends State<AutomationPage> {
  List<EngineRecord> actions = [];
  String? error;
  bool busy = true;
  List<EngineRecord> original = [];
  int? trialSession;
  bool trialStarting = false;
  bool get dirty => jsonEncode(actions) != jsonEncode(original);
  @override
  void initState() {
    super.initState();
    widget.engine.addListener(changed);
    unawaited(load());
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.engine.removeListener(changed);
    super.dispose();
  }

  Future<void> load() async {
    try {
      final records = rows(
        await widget.engine.query('automation', {'hostId': widget.host['id']}),
      );
      if (mounted) {
        setState(() {
          actions = records;
          original = [
            for (final a in records) {...a},
          ];
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          busy = false;
        });
      }
    }
  }

  Future<void> edit([int? index]) async {
    final action = await Navigator.push<EngineRecord>(
      context,
      MaterialPageRoute<EngineRecord>(
        builder: (_) => AutomationStepPage(
          engine: widget.engine,
          host: widget.host,
          action: index == null ? null : actions[index],
          number: (index ?? actions.length) + 1,
        ),
      ),
    );
    if (action != null && mounted) {
      setState(() {
        if (index == null) {
          actions.add(action);
        } else {
          actions[index] = action;
        }
      });
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.engine.invoke('automation.save', {
        'hostId': widget.host['id'],
        'actions': actions,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> back() async {
    if (!dirty || await discardTildeChanges(context)) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> trial() async {
    setState(() => trialStarting = true);
    try {
      final id = await widget.engine.invoke('automation.trial', {
        'hostId': widget.host['id'],
        'actions': actions,
      });
      if (mounted) setState(() => trialSession = id as int);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => trialStarting = false);
    }
  }

  void remove(int index) {
    final removed = actions[index];
    setState(() => actions.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('단계를 삭제했습니다'),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () {
            if (mounted) {
              setState(
                () => actions.insert(index.clamp(0, actions.length), removed),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = row(
      widget.engine
          .list('sessions')
          .where((s) => s['id'] == trialSession)
          .firstOrNull?['automation'],
    );
    return PopScope(
      canPop: !dirty && !busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy) back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.host['nickname']} · 자동 실행'),
          leading: IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back),
            onPressed: busy ? null : back,
          ),
        ),
        bottomNavigationBar: dirty
            ? TildeSaveBar(
                changes: [
                  for (
                    var i = 0;
                    i <
                        (actions.length > original.length
                            ? actions.length
                            : original.length);
                    i++
                  )
                    if (i >= actions.length ||
                        i >= original.length ||
                        !mapEquals(actions[i], original[i]))
                      i,
                ].length,
                busy: busy,
                cancel: () => setState(
                  () => actions = [
                    for (final a in original) {...a},
                  ],
                ),
                save: save,
              )
            : null,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: busy ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('단계 추가'),
        ),
        body: Column(
          children: [
            if (busy || trialStarting) const TildeProgress(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  title: const Text('자동 실행 작업을 완료하지 못했습니다'),
                  trailing: TextButton(
                    onPressed: () => showErrorDetails(context, error!),
                    child: const Text('자세히'),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '끌어서 순서 변경 · 왼쪽으로 밀어 삭제',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy || trialStarting || actions.isEmpty
                        ? null
                        : trial,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('시험 실행'),
                  ),
                ],
              ),
            ),
            if (trialSession != null)
              ListTile(
                leading: progress['running'] == true
                    ? const TildeProgress.circular()
                    : const Icon(Icons.terminal),
                title: Text(
                  progress['running'] == true
                      ? '${(progress['step'] as num?)?.toInt() ?? 1}번째 단계 실행 중'
                      : progress['error'] != null
                      ? '${progress['failedStep'] ?? ''}번째 단계 · ${progress['error']}'
                      : '시험 세션 · $trialSession',
                ),
                subtitle: const Text('별도 세션에서 실행합니다. 기존 연결에는 입력하지 않습니다.'),
              ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 104),
                itemCount: actions.length,
                onReorder: (oldIndex, newIndex) => setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  actions.insert(newIndex, actions.removeAt(oldIndex));
                }),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return Dismissible(
                    key: ObjectKey(action),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => remove(index),
                    background: Container(
                      color: Theme.of(context).colorScheme.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.all(16),
                      child: const Icon(Icons.delete_outline),
                    ),
                    child: ListTile(
                      leading: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: tildeMono,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(actionLabel('${action['type']}')),
                      subtitle: Text(
                        action['type'] == 'DELAY'
                            ? '${action['durationMs']} ms'
                            : '${action['text'] ?? action['key'] ?? ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: tildeMono,
                          fontFamilyFallback: ['Pretendard'],
                        ),
                      ),
                      onTap: () => edit(index),
                      trailing: const Icon(Icons.drag_indicator),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String actionLabel(String type) => switch (type) {
  'WAIT_FOR_TEXT' => '출력 텍스트 기다리기',
  'SEND_TEXT' => '텍스트 전송',
  'SEND_KEY' => '키 전송',
  'DELAY' => '일정 시간 대기',
  'DISCONNECT' => '연결 종료',
  'ENABLE_FORWARD' => '포워딩 활성화',
  'DISABLE_FORWARD' => '포워딩 비활성화',
  _ => type,
};

class AutomationStepPage extends StatefulWidget {
  final AndroidEngine engine;
  final EngineRecord host;
  final EngineRecord? action;
  final int number;
  const AutomationStepPage({
    super.key,
    required this.engine,
    required this.host,
    this.action,
    this.number = 1,
  });
  @override
  State<AutomationStepPage> createState() => _AutomationStepPageState();
}

class _AutomationStepPageState extends State<AutomationStepPage> {
  late EngineRecord draft;
  late EngineRecord original;
  bool get dirty => !mapEquals(original, draft);
  List<EngineRecord> forwards = [];
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    draft = {
      'type': 'SEND_TEXT',
      'text': '',
      'regex': false,
      'durationMs': 30000,
      'key': widget.engine.preferences['enterKey'],
      'modifiers': 0,
      'failurePolicy': 'STOP',
      ...?widget.action,
    };
    original = {...draft};
    unawaited(loadForwards());
  }

  Future<void> loadForwards() async {
    final result = rows(
      await widget.engine.query('forwards', {'hostId': widget.host['id']}),
    );
    if (mounted) setState(() => forwards = result);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop && await discardTildeChanges(context) && context.mounted) {
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: Text('${widget.number}번째 단계')),
      bottomNavigationBar: dirty || widget.action == null
          ? TildeSaveBar(
              changes: dirty ? 1 : 0,
              busy: false,
              cancel: () => Navigator.pop(context),
              save: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, draft);
                }
              },
            )
          : null,
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              isDense: false,
              initialValue: draft['type'] as String,
              decoration: const InputDecoration(labelText: '동작'),
              items: [
                for (final type in [
                  'WAIT_FOR_TEXT',
                  'SEND_TEXT',
                  'SEND_KEY',
                  'DELAY',
                  'DISCONNECT',
                  'ENABLE_FORWARD',
                  'DISABLE_FORWARD',
                ])
                  DropdownMenuItem(value: type, child: Text(actionLabel(type))),
              ],
              onChanged: (v) => setState(() => draft['type'] = v),
            ),
            if (draft['type'] == 'WAIT_FOR_TEXT' ||
                draft['type'] == 'SEND_TEXT')
              TextFormField(
                initialValue: draft['text'] as String,
                maxLines: 6,
                minLines: 3,
                decoration: const InputDecoration(
                  labelText: '텍스트',
                  helperText: '입력한 줄바꿈을 그대로 사용해요.',
                  helperMaxLines: 3,
                ),
                onChanged: (v) => setState(() => draft['text'] = v),
              ),
            if (draft['type'] == 'WAIT_FOR_TEXT')
              SwitchListTile(
                title: const Text('정규 표현식 사용'),
                value: draft['regex'] == true,
                onChanged: (v) => setState(() => draft['regex'] = v),
              ),
            if (draft['type'] == 'WAIT_FOR_TEXT' || draft['type'] == 'DELAY')
              TextFormField(
                initialValue: '${draft['durationMs']}',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: draft['type'] == 'WAIT_FOR_TEXT'
                      ? '타임아웃 (밀리초)'
                      : '대기 시간 (밀리초)',
                ),
                validator: (v) =>
                    int.tryParse(v ?? '') == null || int.parse(v!) < 0
                    ? '0 이상의 정수를 입력하세요.'
                    : null,
                onChanged: (v) =>
                    setState(() => draft['durationMs'] = int.tryParse(v)),
              ),
            if (draft['type'] == 'SEND_KEY') ...[
              DropdownButtonFormField<int>(
                isExpanded: true,
                isDense: false,
                initialValue: draft['key'] as int?,
                decoration: const InputDecoration(labelText: '전송할 키'),
                items: [
                  for (final key in rows(
                    widget.engine.preferences['automationKeys'],
                  ))
                    DropdownMenuItem(
                      value: key['key'] as int,
                      child: Text('${key['label']}'),
                    ),
                ],
                onChanged: (v) => setState(() => draft['key'] = v),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final modifier in row(
                    widget.engine.preferences['keyModifiers'],
                  ).entries)
                    FilterChip(
                      label: Text(modifier.key),
                      selected:
                          ((draft['modifiers'] as int) &
                              (modifier.value as int)) !=
                          0,
                      onSelected: (selected) => setState(() {
                        final mask = modifier.value as int;
                        draft['modifiers'] = selected
                            ? (draft['modifiers'] as int) | mask
                            : (draft['modifiers'] as int) & ~mask;
                      }),
                    ),
                ],
              ),
            ],
            if (draft['type'] == 'ENABLE_FORWARD' ||
                draft['type'] == 'DISABLE_FORWARD')
              DropdownButtonFormField<int>(
                isExpanded: true,
                isDense: false,
                initialValue: draft['forwardId'] as int?,
                decoration: const InputDecoration(labelText: '포워딩'),
                items: [
                  for (final forward in forwards)
                    DropdownMenuItem(
                      value: forward['id'] as int,
                      child: Text('${forward['nickname']}'),
                    ),
                ],
                validator: (v) => v == null ? '포워딩을 선택하세요.' : null,
                onChanged: (v) => setState(() => draft['forwardId'] = v),
              ),
            const SizedBox(height: 16),
            tildeRadioOptions(
              context,
              [('CONTINUE', '다음 단계 계속'), ('STOP', '자동 실행 중단 · 연결 유지')],
              draft['failurePolicy'],
              (v) => setState(() => draft['failurePolicy'] = v),
            ),
          ],
        ),
      ),
    ),
  );
}
