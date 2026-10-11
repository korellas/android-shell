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
import 'package:flutter/material.dart';
import 'engine.dart';

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
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final records = rows(
        await widget.engine.query('automation', {'hostId': widget.host['id']}),
      );
      if (mounted) {
        setState(() {
          actions = records;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.host['nickname']} · 접속 자동화'),
      actions: [
        TextButton(onPressed: busy ? null : save, child: const Text('저장')),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: busy ? null : () => edit(),
      child: const Icon(Icons.add),
    ),
    body: Column(
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('접속 후 순서대로 실행돼요. 끌어서 순서를 바꿀 수 있어요.'),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: actions.length,
            onReorder: (oldIndex, newIndex) => setState(() {
              if (newIndex > oldIndex) newIndex--;
              actions.insert(newIndex, actions.removeAt(oldIndex));
            }),
            itemBuilder: (context, index) {
              final action = actions[index];
              return ListTile(
                key: ValueKey(action),
                leading: Text('${index + 1}'),
                title: Text(actionLabel('${action['type']}')),
                subtitle: Text(
                  '${action['text'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => edit(index),
                trailing: IconButton(
                  tooltip: '단계 삭제',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => actions.removeAt(index)),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
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
  const AutomationStepPage({
    super.key,
    required this.engine,
    required this.host,
    this.action,
  });
  @override
  State<AutomationStepPage> createState() => _AutomationStepPageState();
}

class _AutomationStepPageState extends State<AutomationStepPage> {
  late EngineRecord draft;
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
    unawaited(loadForwards());
  }

  Future<void> loadForwards() async {
    final result = rows(
      await widget.engine.query('forwards', {'hostId': widget.host['id']}),
    );
    if (mounted) setState(() => forwards = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('자동화 단계'),
      actions: [
        TextButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(context, draft);
          },
          child: const Text('확인'),
        ),
      ],
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
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
          if (draft['type'] == 'WAIT_FOR_TEXT' || draft['type'] == 'SEND_TEXT')
            TextFormField(
              initialValue: draft['text'] as String,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: '텍스트',
                helperText: '입력한 줄바꿈을 그대로 사용해요.',
              ),
              onChanged: (v) => draft['text'] = v,
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
              onChanged: (v) => draft['durationMs'] = int.tryParse(v),
            ),
          if (draft['type'] == 'SEND_KEY') ...[
            DropdownButtonFormField<int>(
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
            for (final modifier in row(
              widget.engine.preferences['keyModifiers'],
            ).entries)
              CheckboxListTile(
                title: Text(modifier.key),
                value:
                    ((draft['modifiers'] as int) & (modifier.value as int)) !=
                    0,
                onChanged: (v) => setState(() {
                  final mask = modifier.value as int;
                  draft['modifiers'] = v == true
                      ? (draft['modifiers'] as int) | mask
                      : (draft['modifiers'] as int) & ~mask;
                }),
              ),
          ],
          if (draft['type'] == 'ENABLE_FORWARD' ||
              draft['type'] == 'DISABLE_FORWARD')
            DropdownButtonFormField<int>(
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
              onChanged: (v) => draft['forwardId'] = v,
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: draft['failurePolicy'] as String,
            decoration: const InputDecoration(labelText: '실패 시'),
            items: const [
              DropdownMenuItem(value: 'STOP', child: Text('자동화 중단')),
              DropdownMenuItem(value: 'CONTINUE', child: Text('다음 단계 계속')),
            ],
            onChanged: (v) => draft['failurePolicy'] = v,
          ),
        ],
      ),
    ),
  );
}
