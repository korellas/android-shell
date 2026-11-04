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
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'engine.dart';
import 'tilde_design.dart';
import 'tilde_controls.dart';
import 'settings_widgets.dart';
import 'management.dart';
import 'main.dart';
import 'files/file_browser.dart';

enum RecordKind { host, profile, identity, forward, key }

String kindTitle(RecordKind kind) => switch (kind) {
  RecordKind.host => '호스트',
  RecordKind.profile => '프로필',
  RecordKind.identity => '공용 로그인 계정',
  RecordKind.forward => '포트 포워딩',
  RecordKind.key => 'SSH 키',
};

class RecordEditor extends StatefulWidget {
  final AndroidEngine engine;
  final RecordKind kind;
  final EngineRecord? record;
  final int? hostId;
  final int? sessionId;
  final String? initialHostCategory;
  final Future<void> Function(EngineRecord host)? onSetup;
  final bool embedded, sheet;
  final VoidCallback? onClose;
  final ValueChanged<bool>? onDirtyChanged;
  final ValueChanged<EngineRecord>? onSaved;
  final void Function(Future<bool> Function())? registerLeaveGuard;
  const RecordEditor({
    super.key,
    required this.engine,
    required this.kind,
    this.record,
    this.hostId,
    this.sessionId,
    this.initialHostCategory,
    this.onSetup,
    this.embedded = false,
    this.sheet = false,
    this.onClose,
    this.onDirtyChanged,
    this.onSaved,
    this.registerLeaveGuard,
  });
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final form = GlobalKey<FormState>();
  final detailsScroll = ScrollController();
  late EngineRecord draft;
  bool saving = false, savedNotice = false;
  Timer? savedTimer;
  String? hostCategory;
  late EngineRecord originalDraft;
  String? error;
  int passwordRevision = 0;
  bool? _reportedDirty;
  String _buildingHostCategory = 'connection';
  final _fieldCategories = <String, String>{},
      _fieldLabels = <String, String>{};
  void trackField(String key, String label) {
    _fieldCategories[key] = _buildingHostCategory;
    _fieldLabels[key] = label;
  }

  AndroidEngine get engine => widget.engine;
  @override
  void initState() {
    super.initState();
    widget.registerLeaveGuard?.call(() async {
      if (!mounted || mapEquals(originalDraft, draft)) return true;
      if (saving) return false;
      return discardTildeChanges(context);
    });
    draft = {
      ...row(row(engine.state['defaults'])[widget.kind.name]),
      ...?widget.record,
    };
    if (widget.kind == RecordKind.forward) {
      draft = {
        'type': 'local',
        'sourceAddr': 'localhost',
        'sourcePort': 8080,
        'destPort': 80,
        'startEnabled': false,
        'hostId': widget.hostId,
        ...?widget.record,
      };
    }
    if (widget.kind == RecordKind.identity) {
      draft = {'pubkeyId': -1, ...?widget.record};
    }
    originalDraft = {...draft};
    engine.addListener(engineChanged);
    if (widget.kind == RecordKind.host) {
      hostCategory =
          widget.initialHostCategory ??
          (widget.record == null ? 'connection' : null);
    }
  }

  void engineChanged() {
    if (!mounted) return;
    if (widget.embedded && widget.kind == RecordKind.host) {
      final current = engine
          .list('hosts')
          .where((host) => host['id'] == draft['id'])
          .firstOrNull;
      if (current != null) mergeRecord(current);
    }
    setState(() {});
  }

  void mergeRecord(EngineRecord record) {
    for (final entry in record.entries) {
      if (draft[entry.key] == originalDraft[entry.key]) {
        draft[entry.key] = entry.value;
      }
      originalDraft[entry.key] = entry.value;
    }
  }

  @override
  void dispose() {
    savedTimer?.cancel();
    detailsScroll.dispose();
    engine.removeListener(engineChanged);
    super.dispose();
  }

  Widget text(
    String key,
    String label, {
    bool required = false,
    bool number = false,
    bool optional = false,
    bool password = false,
    bool enabled = true,
    bool multiline = false,
    String? hint,
  }) {
    trackField(key, label);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey(
              key == 'username'
                  ? '$key:${draft['identityId']}'
                  : key == 'password'
                  ? '$key:$passwordRevision'
                  : '$key:$draftRevision',
            ),
            enabled: enabled,
            autocorrect: !password,
            enableSuggestions: !password,
            initialValue: '${draft[key] ?? ''}',
            obscureText: password,
            minLines: multiline ? 3 : 1,
            maxLines: multiline ? 6 : 1,
            keyboardType: number
                ? const TextInputType.numberWithOptions(signed: true)
                : multiline
                ? TextInputType.multiline
                : password
                ? TextInputType.visiblePassword
                : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              isDense: tildePointer(context),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: tildePointer(context) ? 9 : 14,
              ),
            ),
            errorBuilder: (context, error) => Text(error),
            validator: (value) {
              if (required && (value ?? '').trim().isEmpty) {
                return '$label 항목을 입력하세요.';
              }
              if (number &&
                  (value ?? '').isNotEmpty &&
                  int.tryParse(value!) == null) {
                return '정수를 입력하세요.';
              }
              if (number &&
                  (value ?? '').isNotEmpty &&
                  [
                    'port',
                    'sourcePort',
                    'destPort',
                    'moshPort',
                  ].contains(key)) {
                final n = int.tryParse(value!)!;
                if (n < (key == 'moshPort' ? 0 : 1) || n > 65535) {
                  return '포트 범위를 확인하세요.';
                }
              }
              return null;
            },
            onChanged: (value) => setState(() {
              final previous = '${draft[key] ?? ''}';
              draft[key] = number
                  ? (value.isEmpty ? null : int.tryParse(value))
                  : (optional && value.isEmpty ? null : value);
              if (widget.kind == RecordKind.host &&
                  key == 'hostname' &&
                  value.length - previous.length > 1) {
                parseAddress(value);
              }
            }),
          ),
        ],
      ),
    );
  }

  void parseAddress(String input) {
    if (!input.contains('@') &&
        !input.contains('://') &&
        !RegExp(r':\d+$').hasMatch(input)) {
      return;
    }
    final uri = Uri.tryParse(input.contains('://') ? input : 'ssh://$input');
    if (uri == null || uri.host.isEmpty || uri.scheme != 'ssh') {
      return;
    }
    draft['hostname'] = uri.host;
    draft['protocol'] = uri.scheme;
    if (uri.hasPort) draft['port'] = uri.port;
    if (uri.userInfo.isNotEmpty) {
      draft['username'] = uri.userInfo.split(':').first;
      draft['identityId'] = null;
    }
    draftRevision++;
  }

  Widget toggle(String key, String label, {String? description}) {
    trackField(key, label);
    return SwitchListTile(
      title: Text(label),
      subtitle: description == null ? null : Text(description),
      value: draft[key] == true,
      onChanged: (value) => setState(() => draft[key] = value),
    );
  }

  Widget choices(
    String key,
    String label,
    List<(Object?, String)> options, {
    ValueChanged<Object?>? onChanged,
    bool forceList = false,
    bool preserveUnknown = true,
  }) {
    trackField(key, label);
    final current = draft[key] ?? options.firstOrNull?.$1;
    final values = [...options];
    if (preserveUnknown &&
        current != null &&
        !values.any((v) => v.$1 == current)) {
      values.add((current, '$current (현재 값)'));
    }
    void change(Object? value) {
      if (value == draft[key]) return;
      if (onChanged != null) {
        onChanged(value);
      } else {
        setState(() => draft[key] = value);
      }
    }

    return !forceList && values.length <= 4
        ? tildeSegments(context, label, values, current, change)
        : Builder(
            builder: (anchor) => ListTile(
              title: Text(label),
              subtitle: Text(
                values.where((v) => v.$1 == current).firstOrNull?.$2 ?? '선택',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await pickTildeOption(
                  anchor,
                  label,
                  values,
                  current,
                );
                if (result != null && mounted) change(result.$1);
              },
            ),
          );
  }

  Widget references(
    String key,
    String label,
    String collection,
    String name, {
    Object? empty,
    String emptyLabel = '기본값',
  }) => choices(key, label, [
    (empty, emptyLabel),
    for (final record
        in engine.list(collection).where((record) => record["id"] != empty))
      (record['id'] as Object, '${record[name]}'),
  ], forceList: true);
  Widget section(String title, List<Widget> children) =>
      settingsSection(context, title, children);
  Widget pubkeySelector() => tildeRadioOptions(
    context,
    [
      for (final key
          in engine
              .list('keys')
              .where(
                (key) =>
                    key['supported'] != false || key['id'] == draft['pubkeyId'],
              ))
        (
          key['id'],
          '${key['nickname']}${key['supported'] == false ? ' (DSA 미지원)' : ''}',
        ),
      (
        -1,
        engine.state['platform'] == 'windows'
            ? 'Windows 기본 키와 등록한 키'
            : '사용 가능한 키 모두 시도',
      ),
      (-2, '키 쓰지 않음'),
    ],
    draft['pubkeyId'] ?? -1,
    (v) => setState(() => draft['pubkeyId'] = v),
    subtitles: {
      for (final key in engine.list('keys'))
        key['id']:
            '${key['displayType'] ?? key['type']} · ${tildeShortFingerprint('${key['fingerprint'] ?? ''}')}',
    },
  );

  List<Widget> passwordFields() => [
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text(
          'password',
          draft['hasPassword'] == true && '${draft['password'] ?? ''}'.isEmpty
              ? '비밀번호 (저장됨)'
              : '비밀번호',
          password: true,
        ),
        settingsNote(
          context,
          widget.kind == RecordKind.host
              ? '이 기기에 암호화해 보관합니다. 다른 기기로 복원하면 다시 입력해야 합니다.'
              : '이 기기에 암호화해 보관합니다.',
        ),
      ],
    ),
    if (draft['hasPassword'] == true)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() {
            draft['password'] = '';
            draft['hasPassword'] = false;
            draft['clearPassword'] = true;
            passwordRevision++;
          }),
          child: const Text('저장된 비밀번호 삭제'),
        ),
      ),
  ];

  Future<void> registerKey() async {
    if (!mapEquals(originalDraft, draft) && !await save(close: false)) return;
    if (mounted) await widget.onSetup?.call(draft);
  }

  List<Widget> fields() => switch (widget.kind) {
    RecordKind.host => hostFields(hostCategory ?? 'connection'),
    RecordKind.identity => [
      section('공용 로그인 계정', [
        text('name', '계정 이름', required: true),
        text('username', '사용자 이름', required: true),
      ]),
      if (widget.record != null)
        settingsNote(
          context,
          '${engine.list('hosts').where((h) => h['identityId'] == draft['id']).length}개 호스트에 적용됩니다',
        ),
      section('SSH 키', [pubkeySelector()]),
      section('비밀번호', passwordFields()),
    ],
    RecordKind.profile => [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TerminalPreview(engine: engine, overrides: {'profile': draft}),
      ),
      section('화면', [
        text('name', '프로필 이름', required: true),
        references(
          'colorSchemeId',
          '색상 테마',
          'schemes',
          'name',
          empty: -1,
          emptyLabel: 'Tilde Night',
        ),
        choices('fontFamily', '터미널 폰트', [
          (null, '앱 기본값'),
          ...fontOptions(engine),
        ], forceList: true),
        TildeStepper(
          title: '글자 크기',
          unit: 'sp',
          value: (draft['fontSize'] as num?)?.toInt() ?? 14,
          min: 4,
          max: 72,
          onChanged: (v) => setState(() => draft['fontSize'] = v),
        ),
      ]),
      section('터미널', [
        choices('encoding', '문자 인코딩', [
          (draft['encoding'], '${draft['encoding']}'),
          for (final v
              in (engine.state['encodings'] as List? ??
                  ['UTF-8', 'ISO-8859-1', 'EUC-KR', 'SHIFT_JIS']))
            if (v != draft['encoding']) (v, '$v'),
        ], forceList: true),
        choices('emulation', 'TERM', [
          (draft['emulation'], '${draft['emulation']}'),
          for (final v in [
            'xterm-256color',
            'xterm',
            'vt100',
            'screen',
            'screen-256color',
            ...(engine.preferences['customTerminalTypes'] as List? ?? []),
          ])
            if (v != draft['emulation']) (v, '$v'),
        ], forceList: true),
        choices('delKey', '삭제 키', [
          ('del', 'Delete'),
          ('backspace', 'Backspace'),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = text(
                'forceSizeColumns',
                '열 수 · 자동',
                number: true,
                optional: true,
              );
              final rows = text(
                'forceSizeRows',
                '행 수 · 자동',
                number: true,
                optional: true,
              );
              if (MediaQuery.textScalerOf(context).scale(15) > 20 ||
                  constraints.maxWidth < 300) {
                return Column(children: [columns, rows]);
              }
              return Row(
                children: [
                  Expanded(child: columns),
                  const Text('×'),
                  Expanded(child: rows),
                ],
              );
            },
          ),
        ),
      ]),
    ],
    RecordKind.forward => [
      section('포워딩', [
        text('nickname', '포워딩 이름', required: true),
        choices('type', '방식', [
          ('local', '로컬'),
          ('remote', '원격'),
          ('dynamic5', 'SOCKS5'),
        ], preserveUnknown: false),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(switch (draft['type']) {
            'remote' => '서버의 포트로 들어온 연결을 이 기기의 주소로 보냅니다.',
            'local' => '이 기기 포트로 들어온 연결을 서버 쪽 주소로 보냅니다.',
            _ => '이 기기에 SOCKS5 프록시를 엽니다.',
          }),
        ),
        if (draft['type'] == 'dynamic4')
          settingsNote(
            context,
            'SOCKS4는 실행할 수 없습니다. 방식을 SOCKS5로 변경하면 사용할 수 있습니다.',
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(14) > 21;
            Widget pair(Widget address, Widget port) => stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [address, port],
                  )
                : Row(
                    children: [
                      Expanded(flex: 2, child: address),
                      const SizedBox(width: 12),
                      Expanded(child: port),
                    ],
                  );
            return Column(
              children: [
                pair(
                  draft['type'] == 'remote'
                      ? text('sourceAddr', '서버에서 받을 주소', required: true)
                      : const ListTile(
                          title: Text('이 기기에서 받을 주소'),
                          subtitle: Text('127.0.0.1 · 이 기기에서만 접근'),
                        ),
                  text('sourcePort', '포트', required: true, number: true),
                ),
                if (draft['type'] == 'local' || draft['type'] == 'remote')
                  pair(
                    text('destAddr', '대상 주소', required: true),
                    text('destPort', '포트', required: true, number: true),
                  ),
              ],
            );
          },
        ),
      ]),
    ],
    RecordKind.key => [
      section('공개키', [
        if (draft['publicKey'] != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              '${draft['publicKey']}',
              style: const TextStyle(fontFamily: tildeMono, fontSize: 12),
            ),
          ),
        if (draft['fingerprint'] != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tildeShortFingerprint('${draft['fingerprint']}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: tildeMono,
                      fontFamilyFallback: tildeMonoFallback,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: '${draft['fingerprint']}'),
                  ),
                  child: const Text('지문 복사'),
                ),
              ],
            ),
          ),
        if (draft['publicKey'] != null)
          TextButton.icon(
            onPressed: () => runEngine(context, engine, 'key.copy', {
              'id': draft['id'],
              'format': 'public',
            }),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('공개키 복사'),
          ),
      ]),
      section('키 설정', [
        text('nickname', '키 이름', required: true),
        if (draft['supported'] == true)
          toggle(
            'confirmation',
            '사용할 때 확인',
            description: '이 키로 인증하기 전에 허용 여부를 묻습니다',
          ),
        if (draft['supported'] == true)
          ListTile(
            leading: Icon(
              draft['type'] == 'IMPORTED'
                  ? Icons.file_open_outlined
                  : Icons.fingerprint,
            ),
            title: Text(
              draft['type'] == 'IMPORTED'
                  ? '가져온 개인키'
                  : 'Android Keystore P-256 키',
            ),
            subtitle: Text(
              draft['type'] == 'IMPORTED'
                  ? '가져온 개인키 파일로 인증합니다'
                  : '비밀키는 기기 밖으로 내보낼 수 없습니다',
            ),
          ),
        if (draft['supported'] != true)
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: const Text('사용 중지된 기존 개인키'),
            subtitle: Text(
              '${draft['supportMessage'] ?? '새 Android Keystore 키로 교체한 뒤 삭제하세요.'}',
            ),
          ),
      ]),
    ],
  };
  @override
  void didUpdateWidget(RecordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.embedded || widget.record?['id'] != oldWidget.record?['id']) {
      return;
    }
    if (widget.record != null) mergeRecord(widget.record!);
  }

  bool get savedHost =>
      (draft['id'] as num?)?.toInt() != null &&
      (draft['id'] as num).toInt() > 0;
  bool get sshHost => draft['protocol'] == 'ssh';
  bool get supportedHost => canConnectHost(draft);
  List<Widget> hostFields(String category) {
    _buildingHostCategory = category;
    Widget group(String title, List<Widget> widgets) =>
        settingsSection(context, title, widgets);
    void page(Widget child) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => child));
    switch (category) {
      case 'connection':
        return [
          choices('protocol', '연결 방식', [
            ('ssh', 'SSH'),
            if (engine.state['platform'] != 'ios') ('local', '로컬'),
          ], preserveUnknown: false),
          if (!supportedHost)
            settingsNote(
              context,
              '${draft['protocol']} 연결은 지원하지 않습니다. SSH 또는 로컬로 변경하세요.',
            ),
          if (!wideEditor) text('nickname', '호스트 이름', required: true),
          if (wideEditor) text('nickname', '이름', required: true),
          if (draft['protocol'] != 'local') ...[
            if (wideEditor)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: text(
                      'username',
                      '사용자 이름',
                      enabled: draft['identityId'] == null,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: text(
                      'hostname',
                      '서버 주소',
                      required: true,
                      hint: 'user@host:port',
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    child: text('port', '포트', number: true, required: true),
                  ),
                ],
              )
            else ...[
              text('hostname', '서버 주소', required: true, hint: 'user@host:port'),
              text('port', '포트', number: true, required: true),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'user@host:port를 주소 칸에 붙여 넣으면 나눠서 채웁니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            group('고급', [
              choices('ipVersion', 'IP 주소', [
                ('IPV4_AND_IPV6', '자동'),
                ('IPV4_ONLY', 'IPv4'),
                ('IPV6_ONLY', 'IPv6'),
              ]),
              if (sshHost)
                choices(
                  'jumpHostId',
                  '점프 호스트',
                  [
                    (null, '직접 연결'),
                    for (final host
                        in engine
                            .list('hosts')
                            .where(
                              (host) =>
                                  host['protocol'] == 'ssh' &&
                                  host['id'] != draft['id'],
                            ))
                      (host['id'], '${host['nickname']}'),
                  ],
                  forceList: true,
                  preserveUnknown: false,
                ),
            ]),
          ],
        ];
      case 'authentication':
        if (!sshHost) {
          return [settingsNote(context, '이 연결 방식은 SSH 인증 설정을 사용하지 않습니다.')];
        }
        final identity = engine
            .list('identities')
            .where((i) => i['id'] == draft['identityId'])
            .firstOrNull;
        return [
          group('계정', [
            choices(
              'identityId',
              '공용 로그인 계정',
              [
                (null, '쓰지 않음'),
                for (final i in engine.list('identities'))
                  (i['id'], '${i['name']}'),
              ],
              forceList: true,
              onChanged: (id) => setState(() {
                draft['identityId'] = id;
                final selected = engine
                    .list('identities')
                    .where((i) => i['id'] == id)
                    .firstOrNull;
                if (selected != null) {
                  draft['username'] = selected['username'];
                  draft['pubkeyId'] = selected['pubkeyId'];
                }
                draft['password'] = '';
                draft['hasPassword'] = false;
                draft['clearPassword'] = true;
                passwordRevision++;
              }),
            ),
            if (identity == null && !wideEditor)
              text('username', '사용자 이름')
            else if (identity != null)
              ListTile(
                title: Text('${identity['name']} 계정을 씁니다'),
                subtitle: Text(
                  '${identity['username']}',
                  style: const TextStyle(fontFamily: tildeMono),
                ),
                trailing: TextButton(
                  onPressed: () =>
                      showIdentityEditor(context, engine, record: identity),
                  child: const Text('편집'),
                ),
              ),
          ]),
          if (identity == null) ...[
            group('로그인 키', [pubkeySelector()]),
            group('비밀번호', [
              ...passwordFields(),
              if (draft['protocol'] == 'ssh')
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('이 서버에 키 등록'),
                  subtitle: const Text('비밀번호로 한 번 로그인해 공개키를 올립니다'),
                  onTap: savedHost && widget.onSetup != null && !saving
                      ? registerKey
                      : null,
                ),
            ]),
          ],
        ];
      case 'appearance':
        final selectedProfile =
            engine
                .list('profiles')
                .where((p) => p['id'] == draft['profileId'])
                .firstOrNull ??
            defaultProfile(engine);
        final scheme =
            engine
                .list('schemes')
                .where((s) => s['id'] == selectedProfile['colorSchemeId'])
                .firstOrNull ??
            {};
        final palette = (scheme['palette'] as List? ?? []).cast<num>();
        final colors = [
          for (final i in [4, 5, 2, 6, 3, 1, 7, 8])
            if (i < palette.length) Color(palette[i].toInt()),
        ];
        final current = int.tryParse(
          '${draft['color'] ?? ''}'.replaceFirst('#', ''),
          radix: 16,
        );
        return [
          group('호스트 색', [
            ListTile(
              leading: TildeHostTile(host: draft),
              title: Text('${draft['nickname'] ?? ''}'),
              subtitle: const Text('홈 목록·탭·알림에서 이렇게 보입니다'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final color in colors)
                    InkWell(
                      onTap: () => setState(
                        () => draft['color'] =
                            '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                      ),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child:
                            current != null &&
                                (0xff000000 | current) == color.toARGB32()
                            ? Icon(
                                Icons.check,
                                color: color.computeLuminance() > .45
                                    ? Colors.black
                                    : Colors.white,
                              )
                            : null,
                      ),
                    ),
                  IconButton(
                    tooltip: '호스트 색 직접 지정',
                    onPressed: () async {
                      final color = await pickTildeColor(
                        context,
                        Color(
                          0xff000000 |
                              (current ??
                                  ((draft['iconArgb'] as int?) ?? 0xff6fd8c4)),
                        ),
                        title: '호스트 색',
                      );
                      if (color != null && mounted) {
                        setState(
                          () => draft['color'] =
                              '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                        );
                      }
                    },
                    icon: const Icon(Icons.colorize),
                  ),
                ],
              ),
            ),
          ]),
          group('터미널 프로필', [
            tildeRadioOptions(
              context,
              [
                (null, '앱 기본 · ${defaultProfile(engine)['name'] ?? 'Default'}'),
                for (final p in engine.list('profiles'))
                  (p['id'], '${p['name']}'),
              ],
              draft['profileId'],
              (v) => setState(() => draft['profileId'] = v),
              subtitles: {
                for (final p in engine.list('profiles'))
                  p['id']:
                      '${engine.list('schemes').where((s) => s['id'] == p['colorSchemeId']).firstOrNull?['name'] ?? 'Tilde Night'} · ${fontLabel(engine, p['fontFamily'])} ${p['fontSize'] ?? ''}',
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('프로필 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => page(
                RecordListPage(engine: engine, kind: RecordKind.profile),
              ),
            ),
          ]),
        ];
      case 'session':
        return [
          group('연결', [
            if (sshHost)
              toggle(
                'stayConnected',
                '연결 유지',
                description: '입출력 오류로 연결이 끊기면 자동으로 다시 연결합니다',
              ),
            toggle(
              'quickDisconnect',
              '닫을 때 묻지 않기',
              description: 'exit 후 바로 탭을 닫습니다',
            ),
            if (sshHost) ...[
              toggle('compression', 'SSH 압축', description: '느린 회선에서만 켜세요'),
              toggle('wantSession', '터미널 열기', description: '끄면 포트 포워딩만 합니다'),
            ],
          ]),
          group('이 호스트만 다르게', [
            TildeStepper(
              title: '스크롤 기록',
              unit: '행 · 기본값 ${engine.preferences['scrollback'] ?? ''}',
              value:
                  (draft['scrollbackLines'] as num?)?.toInt() ??
                  int.tryParse('${engine.preferences['scrollback'] ?? 140}') ??
                  140,
              step: 500,
              onChanged: (v) => setState(() => draft['scrollbackLines'] = v),
            ),
            toggle('useCtrlAltAsMetaKey', 'Ctrl+Alt를 Meta로'),
          ]),
        ];
      default:
        return [];
    }
  }

  String hostCategoryTitle(String category) => switch (category) {
    'connection' => '연결',
    'authentication' => '인증',
    'appearance' => '화면·프로필',
    'session' => '세션',
    _ => '호스트 편집',
  };
  Widget hostCategories(String? selected) {
    final profile =
        engine
            .list('profiles')
            .where((p) => p['id'] == draft['profileId'])
            .firstOrNull ??
        defaultProfile(engine);
    final key = engine
        .list('keys')
        .where((k) => k['id'] == draft['pubkeyId'])
        .firstOrNull;
    void page(Widget page) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    Widget quick(String title, IconData icon, VoidCallback action) =>
        FilledButton.tonal(
          onPressed: saving ? null : action,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 72),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 8),
              Text(title),
            ],
          ),
        );
    final identity = <Widget>[
      Center(child: TildeHostTile(host: draft, size: 80)),
      const SizedBox(height: 16),
      Text(
        '${draft['nickname'] ?? ''}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      tildePathText(
        hostAddress(draft),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: draft['protocol'] == 'local' ? 'Pretendard' : tildeMono,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 24),
      if (savedHost)
        Builder(
          builder: (context) {
            final actions = <Widget>[
              if (sshHost)
                quick(
                  '파일 전송',
                  Icons.folder_open_outlined,
                  () => page(FileBrowserPage(engine: engine, host: draft)),
                ),
              if (sshHost)
                quick(
                  '포워딩',
                  Icons.swap_horiz,
                  () => page(ForwardsPage(engine: engine, host: draft)),
                ),
              if (supportedHost)
                quick('복제', Icons.file_copy_outlined, duplicateHost),
            ];
            return MediaQuery.textScalerOf(context).scale(15) > 21
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final action in actions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: action,
                        ),
                    ],
                  )
                : Row(
                    children: [
                      for (final (index, action) in actions.indexed) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(child: action),
                      ],
                    ],
                  );
          },
        ),
      const SizedBox(height: 24),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(15) > 20;
    final details = <Widget>[
      for (final (id, summary) in [
        (
          'connection',
          draft['protocol'] == 'local'
              ? '로컬 셸'
              : '${draft['protocol'] ?? 'ssh'} · ${draft['hostname'] ?? ''}:${draft['port'] ?? ''}',
        ),
        if (sshHost)
          (
            'authentication',
            '${key?['nickname'] ?? '키 선택'} · ${draft['username'] ?? ''}',
          ),
        ('appearance', '${profile['name'] ?? '앱 기본값'}'),
        ('session', draft['stayConnected'] == true ? '연결 유지' : '연결 설정'),
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          selected: selected == id,
          selectedTileColor: Theme.of(context).colorScheme.surfaceContainerLow,
          title: Text(hostCategoryTitle(id)),
          subtitle: largeText
              ? Text(summary, style: Theme.of(context).textTheme.bodySmall)
              : null,
          trailing: largeText
              ? const Icon(Icons.chevron_right)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ),
          onTap: () => setState(() => hostCategory = id),
        ),
      if (savedHost && sshHost)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('신뢰한 서버 키'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              page(KnownHostsPage(engine: engine, hostId: draft['id'] as int)),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            widget.embedded &&
            constraints.maxWidth >= 600 &&
            MediaQuery.textScalerOf(context).scale(15) <= 20;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: columns
              ? [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: identity)),
                      const SizedBox(width: 20),
                      Expanded(child: Column(children: details)),
                    ],
                  ),
                ]
              : [...identity, ...details],
        );
      },
    );
  }

  Future<void> connectSavedHost({bool newSession = true}) async {
    if (!mapEquals(originalDraft, draft) && !await save(close: false)) return;
    if (!mounted) return;
    final id = draft['id'];
    if (!widget.embedded) Navigator.of(context).popUntil((r) => r.isFirst);
    await runEngine(context, engine, 'connect', {
      'id': id,
      if (newSession) 'newSession': true,
    });
  }

  Future<void> duplicateHost() async {
    final name = await askText(
      context,
      '복제할 이름',
      initial: '${draft['nickname']} 복사',
      action: '복제',
    );
    if (name != null && mounted) {
      await runEngine(context, engine, 'host.duplicate', {
        'id': draft['id'],
        'nickname': name,
      });
    }
  }

  Future<void> deleteHost() async {
    await deleteTildeHost(
      context,
      engine,
      draft,
      onDeleted: () {
        if (mounted) {
          if (widget.embedded) {
            setState(resetDraft);
            widget.onClose?.call();
          } else {
            Navigator.pop(context);
          }
        }
      },
    );
  }

  bool get wideEditor =>
      tildePointer(context) && MediaQuery.sizeOf(context).width >= 720;
  Set<String> get changedKeys => {
    for (final key in {...originalDraft.keys, ...draft.keys})
      if (originalDraft[key] != draft[key] && !key.startsWith('_'))
        if (['password', 'hasPassword', 'clearPassword'].contains(key))
          'password'
        else
          key,
  };
  int get changeCount => changedKeys.length;
  int draftRevision = 0;
  void resetDraft() {
    error = null;
    savedNotice = false;
    draft = {...originalDraft};
    passwordRevision++;
    draftRevision++;
  }

  void cancelEdits() {
    setState(resetDraft);
    if (widget.kind == RecordKind.host && savedHost) {
      if (!wideEditor) setState(() => hostCategory = null);
    } else {
      if (widget.embedded) {
        widget.onClose?.call();
      } else {
        Navigator.pop(context);
      }
    }
  }

  Future<void> back(bool wide) async {
    if (saving) return;
    if (!mapEquals(originalDraft, draft)) {
      if (!await discardTildeChanges(context) || !mounted) return;
      resetDraft();
    }
    if (widget.kind == RecordKind.host &&
        !wide &&
        hostCategory != null &&
        savedHost) {
      setState(() => hostCategory = null);
      return;
    }
    if (widget.embedded && widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<bool> save({bool close = true}) async {
    if (saving) return false;
    if (widget.kind == RecordKind.host) {
      parseAddress('${draft['hostname'] ?? ''}');
    }
    if (form.currentState?.validate() == false) return false;
    setState(() {
      saving = true;
      savedTimer?.cancel();
      savedNotice = false;
      error = null;
    });
    final data = {
      ...draft,
      if (widget.kind == RecordKind.forward && widget.sessionId != null)
        'sessionId': widget.sessionId,
    };
    try {
      final result = await engine.invoke('${widget.kind.name}.save', data);
      if (result is Map) draft = {...draft, ...row(result)};
      if (mounted) {
        widget.onSaved?.call({...draft});
        if (close) {
          if (widget.embedded) {
            widget.onClose?.call();
          } else {
            Navigator.pop(context);
          }
        } else {
          final updated = engine
              .list('hosts')
              .where((h) => h['id'] == draft['id'])
              .firstOrNull;
          draft = {...draft, ...?updated}
            ..remove('password')
            ..remove('clearPassword');
          passwordRevision++;
          originalDraft = {...draft};
          savedNotice = true;
          savedTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => savedNotice = false);
          });
          if (!wideEditor) hostCategory = null;
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('저장하지 못했습니다'),
            action: SnackBarAction(
              label: '자세히',
              onPressed: () => showErrorDetails(context, e),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
    return false;
  }

  Widget desktopSaveBar(bool wide, bool dirty) {
    final keys = changedKeys.toList();
    String label(String key) =>
        _fieldLabels[key] ?? (key == 'password' ? '비밀번호' : '설정');
    Future<void> showChanges() => showTildeSheet<void>(
      context: context,
      builder: (c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('변경한 항목', style: Theme.of(c).textTheme.titleLarge),
            for (final key in keys)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label(key)),
                subtitle: Text(
                  key == 'password'
                      ? '비밀번호 변경'
                      : '${originalDraft[key] ?? '없음'} → ${draft[key] ?? '없음'}',
                ),
              ),
          ],
        ),
      ),
    );
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: wide
                ? (176 * MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                        176,
                        320,
                      ) +
                      1
                : 0,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (saving)
                      const Text('저장하는 중입니다')
                    else if (dirty && error != null)
                      TextButton.icon(
                        onPressed: () => showErrorDetails(context, error!),
                        icon: Icon(
                          Icons.circle,
                          size: 6,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        label: const Text('저장하지 못했습니다'),
                      )
                    else if (dirty)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            keys.length == 1
                                ? '${label(keys.first)}를 바꿨습니다'
                                : '${label(keys.first)} 외',
                          ),
                          if (keys.length > 1)
                            TextButton(
                              onPressed: showChanges,
                              child: Text('${keys.length - 1}개 항목'),
                            ),
                        ],
                      )
                    else if (savedNotice)
                      const Text('저장했습니다'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (dirty || saving) ...[
                          TextButton(
                            onPressed: saving ? null : cancelEdits,
                            child: const Text('되돌리기'),
                          ),
                          Tooltip(
                            message: 'Ctrl S',
                            child: FilledButton(
                              onPressed: saving
                                  ? null
                                  : () => save(close: false),
                              child: const Text('저장'),
                            ),
                          ),
                        ],
                        if (supportedHost && !wide) ...[
                          FilledButton(
                            onPressed: saving ? null : connectSavedHost,
                            child: Text(dirty ? '저장하고 새 터미널' : '새 터미널'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pointer = tildePointer(context);
      final wide = pointer && constraints.maxWidth >= 600;
      final host = widget.kind == RecordKind.host;
      final selected = hostCategory ?? (wide && host ? 'connection' : null);
      if (host) {
        for (final category in [
          'connection',
          'authentication',
          'appearance',
          'session',
        ]) {
          hostFields(category);
        }
      }
      final dirty = !mapEquals(originalDraft, draft);
      if (_reportedDirty != dirty) {
        _reportedDirty = dirty;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onDirtyChanged?.call(dirty);
        });
      }
      final hostMenu = TildeItemMenu<String>(
        title: '${draft['nickname']}',
        icon: Icons.dns_outlined,
        onSelected: (action) {
          if (action == 'delete') {
            deleteHost();
          } else {
            duplicateHost();
          }
        },
        itemBuilder: (_) => [
          if (supportedHost)
            const PopupMenuItem(
              value: 'duplicate',
              child: TildeMenuLabel('복제', Icons.content_copy_outlined),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: TildeMenuLabel('호스트 삭제', Icons.delete_outline, danger: true),
          ),
        ],
      );
      final details = Form(
        key: form,
        child: ListView(
          shrinkWrap: widget.sheet,
          controller: detailsScroll,
          key: ValueKey(selected),
          padding: EdgeInsets.only(top: 12, bottom: widget.sheet ? 16 : 104),
          children: [
            if (wide && host && selected != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hostCategoryTitle(selected),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (supportedHost)
                      OutlinedButton.icon(
                        onPressed: saving ? null : connectSavedHost,
                        icon: const Icon(Icons.terminal_outlined, size: 18),
                        label: Text(dirty ? '저장하고 새 터미널' : '새 터미널'),
                      ),
                    if (savedHost) hostMenu,
                  ],
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: const Text('변경 사항을 저장하지 못했습니다'),
                  trailing: TextButton(
                    onPressed: () => showErrorDetails(context, error!),
                    child: const Text('자세히'),
                  ),
                ),
              ),
            if (host) ...hostFields(selected ?? 'connection') else ...fields(),
            if (saving) const TildeProgress(),
          ],
        ),
      );
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
              save(close: !host),
        },
        child: PopScope(
          canPop:
              widget.embedded ||
              !saving &&
                  !dirty &&
                  !(host && !wide && hostCategory != null) &&
                  !(widget.embedded && MediaQuery.sizeOf(context).width < 720),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) back(wide);
          },
          child: widget.sheet
              ? Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Text(
                          '${kindTitle(widget.kind)} ${widget.record == null ? '추가' : '편집'}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Flexible(
                        child: Stack(
                          children: [
                            Scrollbar(
                              controller: detailsScroll,
                              thumbVisibility: true,
                              child: details,
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 16,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerLow
                                            .withValues(alpha: 0),
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerLow,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: saving ? null : () => back(false),
                                child: const Text('취소'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: saving ? null : () => save(),
                                child: Text(
                                  saving
                                      ? '저장 중…'
                                      : widget.sessionId != null
                                      ? '적용'
                                      : '저장',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Scaffold(
                  appBar: host && wide
                      ? null
                      : AppBar(
                          actions: [if (host && savedHost) hostMenu],
                          automaticallyImplyLeading: false,
                          leading:
                              widget.kind == RecordKind.forward ||
                                  widget.kind == RecordKind.identity ||
                                  pointer && host && wide
                              ? null
                              : widget.embedded &&
                                    hostCategory == null &&
                                    MediaQuery.sizeOf(context).width >= 720
                              ? null
                              : IconButton(
                                  tooltip: '뒤로',
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => back(wide),
                                ),
                          title: Text(
                            host && !wide && selected != null
                                ? hostCategoryTitle(selected)
                                : widget.embedded
                                ? '${draft['nickname'] ?? '새 호스트'} 편집'
                                : '${kindTitle(widget.kind)} ${widget.record == null ? '추가' : '편집'}',
                          ),
                        ),
                  bottomNavigationBar:
                      pointer &&
                          host &&
                          (!wide || dirty || saving || savedNotice)
                      ? desktopSaveBar(wide, dirty)
                      : dirty
                      ? TildeSaveBar(
                          changes: changeCount,
                          busy: saving,
                          cancel: cancelEdits,
                          save: () => save(close: !host),
                          saveLabel:
                              widget.kind == RecordKind.forward &&
                                  widget.record == null
                              ? '추가'
                              : '저장',
                        )
                      : host && savedHost && selected == null
                      ? SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: LayoutBuilder(
                              builder: (context, constraints) => Align(
                                alignment: Alignment.centerLeft,
                                heightFactor: 1,
                                child: SizedBox(
                                  width:
                                      widget.embedded &&
                                          constraints.maxWidth >= 568
                                      ? (constraints.maxWidth - 20) / 2
                                      : double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: saving || !supportedHost
                                        ? null
                                        : connectSavedHost,
                                    icon: const Icon(Icons.terminal_outlined),
                                    label: const Text('새 터미널'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                  body: host && wide
                      ? Row(
                          children: [
                            SizedBox(
                              width:
                                  (176 *
                                          MediaQuery.textScalerOf(
                                            context,
                                          ).scale(14) /
                                          14)
                                      .clamp(176, 320),
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 8,
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      4,
                                      8,
                                      20,
                                    ),
                                    child: Row(
                                      children: [
                                        TildeHostTile(host: draft, size: 32),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${draft['nickname'] ?? '새 호스트'}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              tildePathText(
                                                hostAddress(draft),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontFamily: tildeMono,
                                                      fontFamilyFallback:
                                                          tildeMonoFallback,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (final category in [
                                    'connection',
                                    if (sshHost) 'authentication',
                                    'appearance',
                                    'session',
                                  ])
                                    ListTile(
                                      minTileHeight: 36,
                                      selected: selected == category,
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Tooltip(
                                              message: hostCategoryTitle(
                                                category,
                                              ),
                                              child: Text(
                                                hostCategoryTitle(category),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          if (_fieldCategories.entries.any(
                                            (entry) =>
                                                entry.value == category &&
                                                draft[entry.key] !=
                                                    originalDraft[entry.key],
                                          ))
                                            Icon(
                                              Icons.circle,
                                              size: 5,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.tertiary,
                                            ),
                                        ],
                                      ),
                                      onTap: () => setState(
                                        () => hostCategory = category,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 640,
                                  ),
                                  child: details,
                                ),
                              ),
                            ),
                          ],
                        )
                      : host && selected == null
                      ? hostCategories(null)
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: details,
                          ),
                        ),
                ),
        ),
      );
    },
  );
}

List<(Object?, String)> fontOptions(AndroidEngine engine) => [
  for (final font in rows(engine.preferences['fonts']))
    (
      font['value'] as String,
      font['value'] == 'SYSTEM_DEFAULT' ? '시스템 기본값' : '${font['label']}',
    ),
  for (final font in (engine.preferences['customFonts'] as List? ?? []))
    ('custom:$font', '$font'),
  for (final font in rows(engine.preferences['localFonts']))
    ('local:${font['fileName']}', '${font['displayName']}'),
];

String fontLabel(AndroidEngine engine, Object? stored) {
  final value = stored ?? engine.preferences['fontFamily'];
  return fontOptions(
        engine,
      ).where((font) => font.$1 == value).firstOrNull?.$2 ??
      (value == null ? '앱 기본 폰트' : '$value');
}

class GenerateKeyPage extends StatefulWidget {
  final AndroidEngine engine;
  final bool returnGeneratedKey;
  const GenerateKeyPage({
    super.key,
    required this.engine,
    this.returnGeneratedKey = false,
  });
  @override
  State<GenerateKeyPage> createState() => _GenerateKeyPageState();
}

class _GenerateKeyPageState extends State<GenerateKeyPage> {
  final form = GlobalKey<FormState>();
  String name = '';
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('새 SSH 키', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            const Text('키 이름', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(),
              validator: (v) => (v ?? '').trim().isEmpty ? '이름을 입력하세요.' : null,
              onChanged: (v) => name = v,
            ),
            settingsNote(
              context,
              'P-256 개인키를 Android Keystore에 만들고 서명할 때마다 생체인증을 요구합니다. 개인키는 복사·내보내기·백업할 수 없습니다.',
            ),
            if (error != null)
              ListTile(
                title: const Text('키를 만들지 못했습니다'),
                trailing: TextButton(
                  onPressed: () => showErrorDetails(context, error!),
                  child: const Text('자세히'),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (form.currentState?.validate() == false) return;
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final generated = await widget.engine.invoke(
                          'key.generate',
                          {'nickname': name, 'type': 'EC', 'bits': 256},
                        );
                        if (context.mounted) {
                          if (widget.returnGeneratedKey) {
                            Navigator.pop(context, row(generated));
                          } else {
                            Navigator.pop(context);
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            busy = false;
                            error = '$e';
                          });
                        }
                      }
                    },
              child: busy
                  ? const TildeProgress.circular()
                  : const Text('키 만들기'),
            ),
          ],
        ),
      ),
    ),
  );
}
