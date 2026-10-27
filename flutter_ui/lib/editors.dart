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

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'engine.dart';
import 'tilde_design.dart';
import 'tilde_controls.dart';
import 'settings_widgets.dart';
import 'management.dart';
import 'main.dart';

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
  final Future<void> Function(EngineRecord host)? onSetup;
  final bool embedded;
  final VoidCallback? onClose;
  final void Function(Future<bool> Function())? registerLeaveGuard;
  const RecordEditor({
    super.key,
    required this.engine,
    required this.kind,
    this.record,
    this.hostId,
    this.sessionId,
    this.onSetup,
    this.embedded = false,
    this.onClose,
    this.registerLeaveGuard,
  });
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final form = GlobalKey<FormState>();
  late EngineRecord draft;
  bool saving = false;
  String? hostCategory;
  late EngineRecord originalDraft;
  String? error;
  bool changePassword = false;
  int passwordRevision = 0;
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
        'startEnabled': true,
        'hostId': widget.hostId,
        ...?widget.record,
      };
    }
    if (widget.kind == RecordKind.identity) {
      draft = {'pubkeyId': -1, ...?widget.record};
    }
    originalDraft = {...draft};
    engine.addListener(engineChanged);
    if (widget.kind == RecordKind.host && widget.record == null) {
      hostCategory = 'connection';
    }
  }

  void engineChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: TextFormField(
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
      decoration: InputDecoration(labelText: label, hintText: hint),
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
            ['port', 'sourcePort', 'destPort', 'moshPort'].contains(key)) {
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
  );
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

  Widget toggle(String key, String label, {String? description}) =>
      SwitchListTile(
        title: Text(label),
        subtitle: description == null ? null : Text(description),
        value: draft[key] == true,
        onChanged: (value) => setState(() => draft[key] = value),
      );
  Widget choices(
    String key,
    String label,
    List<(Object?, String)> options, {
    ValueChanged<Object?>? onChanged,
    bool forceList = false,
    bool preserveUnknown = true,
  }) {
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
        : ListTile(
            title: Text(label),
            subtitle: Text(
              values.where((v) => v.$1 == current).firstOrNull?.$2 ?? '선택',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await pickTildeOption(
                context,
                label,
                values,
                current,
              );
              if (result != null && mounted) change(result.$1);
            },
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
      (-1, '잠금 해제된 키 모두 시도'),
      (-2, '키 쓰지 않음'),
    ],
    draft['pubkeyId'] ?? -1,
    (v) => setState(() => draft['pubkeyId'] = v),
    subtitles: {
      for (final key in engine.list('keys'))
        key['id']:
            '${key['displayType'] ?? key['type']} · ${key['fingerprint'] ?? ''}',
    },
  );

  List<Widget> passwordFields() => [
    text(
      'password',
      draft['hasPassword'] == true && '${draft['password'] ?? ''}'.isEmpty
          ? '비밀번호 (저장됨)'
          : '비밀번호',
      password: true,
    ),
    if (widget.kind == RecordKind.host)
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('이 기기에 암호화해 보관합니다. 다른 기기로 복원하면 다시 입력해야 합니다.'),
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
      section('비밀번호', [
        ...passwordFields(),
        settingsNote(context, '이 기기에 암호화해 보관합니다.'),
      ]),
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
        choices('inlineImages', '터미널 이미지', [
          ('off', '표시 안 함'),
          ('ask', '세션마다 확인'),
          ('on', '항상 표시'),
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
          ('local', 'L · 로컬'),
          ('remote', 'R · 원격'),
          ('dynamic5', 'D · SOCKS5'),
        ], preserveUnknown: false),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  draft['type'] == 'remote' ? '원격 서버' : '이 기기',
                  textAlign: TextAlign.center,
                ),
              ),
              const Icon(Icons.arrow_forward),
              Expanded(
                child: Text(
                  draft['type'].toString().startsWith('dynamic')
                      ? 'SOCKS 프록시'
                      : draft['type'] == 'remote'
                      ? '이 기기'
                      : '원격 서버',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        if (draft['type'] == 'dynamic4')
          settingsNote(
            context,
            'SOCKS4는 실행할 수 없습니다. 방식을 SOCKS5로 변경하면 사용할 수 있습니다.',
          ),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: text('sourceAddr', '대기 주소', required: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: text('sourcePort', '포트', required: true, number: true),
            ),
          ],
        ),
        if (draft['type'] == 'local' || draft['type'] == 'remote')
          Row(
            children: [
              Expanded(
                flex: 2,
                child: text('destAddr', '대상 주소', required: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: text('destPort', '포트', required: true, number: true),
              ),
            ],
          ),
        if (draft['type'] != 'dynamic4') toggle('startEnabled', '접속할 때 자동 활성화'),
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
            child: SelectableText(
              '${draft['fingerprint']}',
              style: const TextStyle(fontFamily: tildeMono, fontSize: 12),
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
        toggle(
          'confirmation',
          '사용할 때 확인',
          description: '이 키로 인증하기 전에 허용 여부를 묻습니다',
        ),
        if (draft['biometric'] == true)
          const ListTile(
            leading: Icon(Icons.fingerprint),
            title: Text('Android Keystore 생체인증 키'),
            subtitle: Text('비밀키는 기기 밖으로 내보낼 수 없습니다'),
          ),
        if (draft['biometric'] != true) ...[
          toggle('startup', '앱 시작 시 자동 불러오기'),
          toggle('allowBackup', '키 백업 허용'),
          if (draft['supported'] != false)
            ListTile(
              title: const Text('키 암호 변경'),
              subtitle: Text(
                changePassword
                    ? '저장할 때 적용됩니다'
                    : draft['encrypted'] == true
                    ? '암호로 보호됨'
                    : '암호 없음',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final value = await showTildeSheet<EngineRecord>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => KeyPasswordSheet(
                    requireOldPassword:
                        draft['encrypted'] == true && draft['loaded'] != true,
                  ),
                );
                if (value != null && mounted) {
                  setState(() {
                    changePassword = true;
                    draft.addAll(value);
                    if ('${value['newPassword'] ?? ''}'.isNotEmpty) {
                      draft['startup'] = false;
                    }
                  });
                }
              },
            ),
        ],
      ]),
    ],
  };
  @override
  void didUpdateWidget(RecordEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.embedded || widget.record?['id'] != oldWidget.record?['id']) {
      return;
    }
    for (final entry in widget.record!.entries) {
      if (draft[entry.key] == originalDraft[entry.key]) {
        draft[entry.key] = entry.value;
      }
      originalDraft[entry.key] = entry.value;
    }
  }

  bool get savedHost =>
      (draft['id'] as num?)?.toInt() != null &&
      (draft['id'] as num).toInt() > 0;
  bool get sshHost => draft['protocol'] == 'ssh';
  bool get supportedHost => canConnectHost(draft);
  List<Widget> hostFields(String category) {
    Widget group(String title, List<Widget> widgets) =>
        settingsSection(context, title, widgets);
    void page(Widget child) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => child));
    switch (category) {
      case 'connection':
        return [
          choices('protocol', '연결 방식', [
            ('ssh', 'SSH'),
            ('local', '로컬'),
          ], preserveUnknown: false),
          if (!supportedHost)
            settingsNote(
              context,
              '${draft['protocol']} 연결은 지원하지 않습니다. SSH 또는 로컬로 변경하세요.',
            ),
          text('nickname', '호스트 이름', required: true),
          if (draft['protocol'] != 'local') ...[
            text('hostname', '서버 주소', required: true, hint: 'user@host:port'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('user@host:port를 붙여 넣으면 나눠서 채웁니다'),
            ),
            text('port', '포트', number: true, required: true),
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
            if (identity == null)
              text('username', '사용자 이름')
            else
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
          group('고급', [
            choices('useAuthAgent', 'SSH 인증 에이전트', [
              ('no', '끔'),
              ('yes', '사용'),
              ('confirm', '매번 확인'),
            ]),
          ]),
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
          if (savedHost)
            group('로그인 후', [
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('자동 실행'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => page(AutomationPage(engine: engine, host: draft)),
              ),
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
    Widget quick(String title, IconData icon, VoidCallback action) => SizedBox(
      width: 132,
      child: FilledButton.tonal(
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
      Text(
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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (supportedHost)
              quick(
                '새 세션',
                Icons.library_add_outlined,
                () => connectSavedHost(newSession: true),
              ),
            if (supportedHost)
              quick('복제', Icons.file_copy_outlined, duplicateHost),
            if (sshHost)
              quick(
                '포워딩',
                Icons.swap_horiz,
                () => page(ForwardsPage(engine: engine, host: draft)),
              ),
            if (supportedHost)
              quick(
                '홈 화면',
                Icons.add_to_home_screen_outlined,
                () => runEngine(context, engine, 'shortcut', {
                  'id': draft['id'],
                  'color': draft['color'],
                }),
              ),
          ],
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
      if (savedHost)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            '호스트 삭제',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: deleteHost,
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

  Future<void> connectSavedHost({bool newSession = false}) async {
    if (!mapEquals(originalDraft, draft)) {
      final action = await askAction(context, '변경 사항이 있습니다', [
        ('save', '저장하고 연결'),
        ('stored', '저장된 설정으로 연결'),
      ]);
      if (action == null || !mounted) return;
      if (action == 'save' && !await save(close: false)) return;
    }
    if (!mounted) return;
    final id = draft['id'];
    Navigator.of(context).popUntil((r) => r.isFirst);
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
        if (mounted && !widget.embedded) Navigator.pop(context);
      },
    );
  }

  bool get wideEditor =>
      !widget.embedded && MediaQuery.sizeOf(context).width >= 720;
  int get changeCount => {
    for (final key in {...originalDraft.keys, ...draft.keys})
      if (originalDraft[key] != draft[key] && !key.startsWith('_'))
        if ([
          'password',
          'hasPassword',
          'clearPassword',
          'oldPassword',
          'newPassword',
        ].contains(key))
          'password'
        else
          key,
  }.length;
  int draftRevision = 0;
  void resetDraft() {
    draft = {...originalDraft};
    passwordRevision++;
    draftRevision++;
    changePassword = false;
  }

  void cancelEdits() {
    setState(resetDraft);
    if (widget.kind == RecordKind.host && savedHost) {
      if (!wideEditor) setState(() => hostCategory = null);
    } else {
      Navigator.pop(context);
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
    if (widget.kind == RecordKind.host) {
      parseAddress('${draft['hostname'] ?? ''}');
    }
    if (form.currentState?.validate() == false) return false;
    setState(() {
      saving = true;
      error = null;
    });
    final data = {
      ...draft,
      if (widget.kind == RecordKind.forward && widget.sessionId != null)
        'sessionId': widget.sessionId,
    };
    if (!changePassword) {
      data.remove('oldPassword');
      data.remove('newPassword');
    }
    try {
      final result = await engine.invoke('${widget.kind.name}.save', data);
      if (result is Map) draft = {...draft, ...row(result)};
      if (mounted) {
        if (close) {
          Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = !widget.embedded && constraints.maxWidth >= 720;
      final host = widget.kind == RecordKind.host;
      final selected = hostCategory ?? (wide && host ? 'connection' : null);
      final dirty = !mapEquals(originalDraft, draft);
      final details = Form(
        key: form,
        child: ListView(
          key: ValueKey(selected),
          padding: const EdgeInsets.only(top: 12, bottom: 104),
          children: [
            if (wide && host && selected != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  hostCategoryTitle(selected),
                  style: Theme.of(context).textTheme.titleLarge,
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
      return PopScope(
        canPop:
            !saving &&
            !dirty &&
            !(host && !wide && hostCategory != null) &&
            !(widget.embedded && MediaQuery.sizeOf(context).width < 720),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) back(wide);
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading:
                widget.embedded &&
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
                  ? ''
                  : '${kindTitle(widget.kind)} ${widget.record == null ? '추가' : '편집'}',
            ),
          ),
          bottomNavigationBar: dirty
              ? TildeSaveBar(
                  changes: changeCount,
                  busy: saving,
                  cancel: cancelEdits,
                  save: () => save(close: !host),
                  saveLabel:
                      widget.kind == RecordKind.forward && widget.record == null
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
                          width: widget.embedded && constraints.maxWidth >= 568
                              ? (constraints.maxWidth - 20) / 2
                              : double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving || !supportedHost
                                ? null
                                : connectSavedHost,
                            icon: const Icon(Icons.terminal_outlined),
                            label: const Text('연결'),
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
                    SizedBox(width: 320, child: hostCategories(selected)),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
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
  String name = '', type = 'ED25519', password = '';
  int? bits;
  bool biometric = false, startup = false, busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('새 SSH 키'),
      leading: IconButton(
        tooltip: '닫기',
        icon: const Icon(Icons.close),
        onPressed: busy ? null : () => Navigator.pop(context),
      ),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: '키 이름'),
            validator: (v) => (v ?? '').trim().isEmpty ? '이름을 입력하세요.' : null,
            onChanged: (v) => name = v,
          ),
          tildeRadioOptions(
            context,
            [('ED25519', 'Ed25519'), ('RSA', 'RSA'), ('EC', 'ECDSA')],
            type,
            (v) => setState(() {
              type = v as String;
              bits = type == 'RSA'
                  ? 3072
                  : type == 'EC'
                  ? 256
                  : null;
              if (type == 'ED25519') biometric = false;
            }),
          ),
          if (type == 'RSA' || type == 'EC')
            tildeSegments(
              context,
              '키 강도',
              [
                for (final n
                    in type == 'RSA' ? [2048, 3072, 4096] : [256, 384, 521])
                  (n, '$n'),
              ],
              bits ?? (type == 'RSA' ? 3072 : 256),
              (v) => setState(() => bits = v as int),
            ),
          if ((type == 'RSA' || type == 'EC') &&
              row(widget.engine.state['generation'])['biometricAvailable'] ==
                  true)
            tildeSegments(
              context,
              '보호',
              [(false, '암호'), (true, '지문')],
              biometric,
              busy
                  ? null
                  : (v) => setState(() {
                      biometric = v as bool;
                      if (biometric) startup = false;
                    }),
            ),
          if (!biometric) ...[
            TextFormField(
              obscureText: true,
              decoration: const InputDecoration(labelText: '키 암호'),
              onChanged: (v) => setState(() {
                password = v;
              }),
            ),
            SwitchListTile(
              title: const Text('시작 시 자동 불러오기'),
              value: startup,
              onChanged: (v) => setState(() => startup = v),
            ),
          ],
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
                      final generated = await widget.engine
                          .invoke('key.generate', {
                            'nickname': name,
                            'type': type,
                            if (bits != null) 'bits': bits,
                            'biometric': biometric,
                            'startup': startup,
                            'password': password,
                          });
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
            child: busy ? const TildeProgress.circular() : const Text('만들기'),
          ),
        ],
      ),
    ),
  );
}

class KeyPasswordSheet extends StatefulWidget {
  final bool requireOldPassword;
  const KeyPasswordSheet({super.key, this.requireOldPassword = true});
  @override
  State<KeyPasswordSheet> createState() => _KeyPasswordSheetState();
}

class _KeyPasswordSheetState extends State<KeyPasswordSheet> {
  final form = GlobalKey<FormState>();
  String oldPassword = '', newPassword = '', confirmation = '';
  @override
  Widget build(BuildContext context) => SafeArea(
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
          children: [
            Text('키 암호 변경', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (widget.requireOldPassword)
              TextFormField(
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: '기존 암호'),
                onChanged: (v) => oldPassword = v,
              ),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '새 암호',
                helperText: '빈 값으로 저장하면 암호를 제거합니다',
                helperMaxLines: 3,
              ),
              onChanged: (v) => newPassword = v,
            ),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: '새 암호 확인'),
              validator: (v) => v == newPassword ? null : '암호가 다릅니다',
              onChanged: (v) => confirmation = v,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, {
                    if (widget.requireOldPassword) 'oldPassword': oldPassword,
                    'newPassword': newPassword,
                  });
                }
              },
              child: const Text('변경'),
            ),
          ],
        ),
      ),
    ),
  );
}
