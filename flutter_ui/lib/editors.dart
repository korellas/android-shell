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
  const RecordEditor({
    super.key,
    required this.engine,
    required this.kind,
    this.record,
    this.hostId,
    this.sessionId,
    this.onSetup,
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
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
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
    final uri = Uri.tryParse(
      input.contains('://') ? input : '${draft['protocol'] ?? 'ssh'}://$input',
    );
    if (uri == null ||
        uri.host.isEmpty ||
        !['ssh', 'mosh', 'telnet'].contains(uri.scheme)) {
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
  }) {
    final current = draft[key] ?? options.firstOrNull?.$1;
    final values = [...options];
    if (current != null && !values.any((v) => v.$1 == current)) {
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
      for (final key in engine.list('keys')) (key['id'], '${key['nickname']}'),
      (-1, '잠금 해제된 키 모두 시도'),
      (-2, '키 쓰지 않음'),
    ],
    draft['pubkeyId'] ?? -1,
    (v) => setState(() => draft['pubkeyId'] = v),
    subtitles: {
      for (final key in engine.list('keys'))
        key['id']: '${key['type']} · ${key['fingerprint'] ?? ''}',
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: text(
                  'forceSizeColumns',
                  '열 수 · 자동',
                  number: true,
                  optional: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('×'),
              ),
              Expanded(
                child: text(
                  'forceSizeRows',
                  '행 수 · 자동',
                  number: true,
                  optional: true,
                ),
              ),
            ],
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
          ('dynamic5', 'D · SOCKS'),
          if (draft['type'] == 'dynamic4') ('dynamic4', 'SOCKS4'),
        ]),
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
          settingsNote(context, '기존 SOCKS4 설정입니다. 새 프록시는 SOCKS5를 사용하세요.'),
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
        toggle('startEnabled', '접속할 때 자동 활성화'),
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
        if (draft['type'] == 'IMPORTED')
          settingsNote(context, '가져온 PEM 키는 비밀키 암호를 확인한 뒤 사용할 수 있습니다.'),
      ]),
      section('키 설정', [
        text('nickname', '키 이름', required: true),
        toggle('confirmation', '사용할 때마다 확인'),
        if (draft['biometric'] == true)
          const ListTile(
            leading: Icon(Icons.fingerprint),
            title: Text('Android Keystore 생체인증 키'),
            subtitle: Text('비밀키는 기기 밖으로 내보낼 수 없습니다'),
          ),
        if (draft['biometric'] != true) ...[
          toggle('startup', '앱 시작 시 자동 불러오기'),
          toggle('allowBackup', '키 백업 허용'),
          if (draft['type'] != 'IMPORTED')
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
                final value = await showModalBottomSheet<EngineRecord>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const KeyPasswordSheet(),
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
  bool get savedHost =>
      (draft['id'] as num?)?.toInt() != null &&
      (draft['id'] as num).toInt() > 0;
  bool get sshHost => draft['protocol'] == 'ssh' || draft['protocol'] == 'mosh';
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
            ('mosh', 'Mosh'),
            ('telnet', 'Telnet'),
            ('local', '로컬'),
          ]),
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
                references(
                  'jumpHostId',
                  '점프 호스트',
                  'hosts',
                  'nickname',
                  emptyLabel: '직접 연결',
                ),
              if (draft['protocol'] == 'mosh') ...[
                text('moshPort', 'UDP 포트 (0 = 자동)', number: true),
                text('moshNetworkTimeout', '네트워크 타임아웃', number: true),
                text('moshServer', 'mosh-server 경로', optional: true),
                text('locale', '서버 로케일'),
              ],
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
            toggle('stayConnected', '연결 유지', description: '화면을 꺼도 끊지 않습니다'),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 104),
      children: [
        ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: TildeHostTile(host: draft, size: 48),
          title: Text(
            '${draft['nickname'] ?? ''}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text(
            draft['protocol'] == 'local'
                ? '로컬 셸'
                : '${draft['username'] ?? ''}@${draft['hostname'] ?? ''}:${draft['port'] ?? ''}',
            style: const TextStyle(fontFamily: tildeMono),
          ),
        ),
        if (savedHost)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: saving ? null : connectSavedHost,
                    icon: const Icon(Icons.terminal),
                    label: const Text('연결'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : duplicateHost,
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('복제'),
                  ),
                ),
              ],
            ),
          ),
        settingsSection(context, '설정', [
          for (final (id, icon, summary) in [
            (
              'connection',
              Icons.lan_outlined,
              draft['protocol'] == 'local'
                  ? '로컬 셸'
                  : '${draft['hostname'] ?? ''}:${draft['port'] ?? ''} · ${draft['protocol'] ?? 'ssh'}',
            ),
            if (sshHost)
              (
                'authentication',
                Icons.key_outlined,
                '${draft['username'] ?? ''} · ${key?['nickname'] ?? '키 선택'}',
              ),
            (
              'appearance',
              Icons.palette_outlined,
              '${profile['name'] ?? 'Default'}',
            ),
            (
              'session',
              Icons.tune,
              draft['stayConnected'] == true ? '연결 유지' : '연결 설정',
            ),
          ])
            ListTile(
              selected: selected == id,
              leading: Icon(icon, size: 24),
              title: Text(hostCategoryTitle(id)),
              subtitle: Text(
                summary,
                style: const TextStyle(fontFamily: tildeMono, fontSize: 12.5),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => hostCategory = id),
            ),
        ]),
        if (savedHost)
          settingsSection(context, '이 호스트의', [
            if (sshHost)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('포트 포워딩'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ForwardsPage(engine: engine, host: draft),
                  ),
                ),
              ),
            if (sshHost)
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('신뢰한 서버 키'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => KnownHostsPage(
                      engine: engine,
                      hostId: draft['id'] as int,
                    ),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.add_to_home_screen),
              title: const Text('홈 화면에 추가'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => runEngine(context, engine, 'shortcut', {
                'id': draft['id'],
                'color': draft['color'],
              }),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                '호스트 삭제',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: deleteHost,
            ),
          ]),
      ],
    );
  }

  Future<void> connectSavedHost() async {
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
    await runEngine(context, engine, 'connect', {'id': id});
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
    if (await confirm(context, '호스트 삭제', '설정과 연결을 삭제할까요?', action: '삭제') &&
        mounted) {
      await runEngine(context, engine, 'host.delete', {'id': draft['id']});
      if (mounted) Navigator.pop(context);
    }
  }

  bool get wideEditor => MediaQuery.sizeOf(context).width >= 720;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
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
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (host) ...hostFields(selected ?? 'connection') else ...fields(),
            if (saving) const TildeProgress(),
          ],
        ),
      );
      return PopScope(
        canPop: !saving && !dirty && !(host && !wide && hostCategory != null),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) back(wide);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '뒤로',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => back(wide),
            ),
            title: Text(
              host && !wide && selected != null
                  ? hostCategoryTitle(selected)
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
              : null,
          body: host && wide
              ? Row(
                  children: [
                    SizedBox(width: 280, child: hostCategories(selected)),
                    const VerticalDivider(width: 1),
                    Expanded(child: details),
                  ],
                )
              : host && selected == null
              ? hostCategories(null)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
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
  bool biometric = false, startup = false, confirmation = false, busy = false;
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
          SwitchListTile(
            title: const Text('사용할 때마다 확인'),
            value: confirmation,
            onChanged: (v) => setState(() => confirmation = v),
          ),
          if (error != null) Text(error!),
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
                            'confirmation': confirmation,
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
            child: busy
                ? const SizedBox(height: 12, child: TildeProgress())
                : const Text('만들기'),
          ),
        ],
      ),
    ),
  );
}

class KeyPasswordSheet extends StatefulWidget {
  const KeyPasswordSheet({super.key});
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
                    'oldPassword': oldPassword,
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
