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
  final Future<void> Function(EngineRecord host)? onSetup;
  const RecordEditor({
    super.key,
    required this.engine,
    required this.kind,
    this.record,
    this.hostId,
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
    if (widget.kind == RecordKind.host && widget.record == null) {
      hostCategory = 'connection';
    }
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
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(
        key == 'username'
            ? '$key:${draft['identityId']}'
            : key == 'password'
            ? '$key:$passwordRevision'
            : key,
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
        return null;
      },
      onChanged: (value) => setState(() {
        draft[key] = number
            ? (value.isEmpty ? null : int.tryParse(value))
            : (optional && value.isEmpty ? null : value);
      }),
    ),
  );
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
  }) {
    final values = [...options];
    final current = draft[key];
    if (current != null && !values.any((o) => o.$1 == current)) {
      values.add((current, '$current (현재 값)'));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<Object>(
        key: ValueKey('$key:$current'),
        initialValue: current,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: values
            .map(
              (o) => DropdownMenuItem<Object>(
                value: o.$1,
                child: Text(o.$2, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged ?? (value) => setState(() => draft[key] = value),
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
  ]);
  Widget section(String title, List<Widget> children) => ExpansionTile(
    title: Text(title),
    childrenPadding: const EdgeInsets.all(8),
    children: children,
  );
  Widget pubkeySelector() => choices('pubkeyId', '로그인에 사용할 SSH 키', [
    (-1, '잠금이 풀린 키들을 사용'),
    (-2, '키 사용 안함'),
    for (final key in engine.list('keys'))
      (key['id'] as Object, '${key['nickname']}'),
  ]);

  List<Widget> passwordFields() => [
    text(
      'password',
      draft['hasPassword'] == true && '${draft['password'] ?? ''}'.isEmpty
          ? '비밀번호 (변경 없음)'
          : '비밀번호',
      password: true,
    ),
    if (widget.kind == RecordKind.host)
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('로그인 비밀번호를 안전하게 저장해 자동으로 인증해요'),
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
      text('name', '인증정보 이름', required: true),
      text('username', '사용자 이름', required: true),
      pubkeySelector(),
      ...passwordFields(),
      const Text('비밀번호는 이 기기에 암호화해 보관해요. 다른 기기로 복원하면 다시 입력해야 해요.'),
    ],
    RecordKind.profile => [
      text('name', '프로필 이름', required: true),
      text('iconColor', '프로필 색상', optional: true),
      references(
        'colorSchemeId',
        '색상 테마',
        'schemes',
        'name',
        empty: -1,
        emptyLabel: 'Default',
      ),
      choices('fontFamily', '터미널 폰트', [
        (null, '앱 기본값'),
        ...fontOptions(engine),
      ]),
      text('fontSize', '글자 크기', number: true, required: true),
      choices('delKey', '삭제 키', [
        ('del', 'Delete'),
        ('backspace', 'Backspace'),
      ]),
      section('고급 프로필 설정', [
        text('encoding', '문자 인코딩', required: true),
        text('emulation', '터미널 종류', required: true),
        choices('inlineImages', '터미널 이미지', [
          ('off', '표시 안 함'),
          ('ask', '세션마다 확인'),
          ('on', '항상 표시'),
        ]),
        text('forceSizeRows', '고정 행 수 (빈 값은 자동)', number: true, optional: true),
        text(
          'forceSizeColumns',
          '고정 열 수 (빈 값은 자동)',
          number: true,
          optional: true,
        ),
      ]),
    ],
    RecordKind.forward => [
      text('nickname', '포워딩 이름', required: true),
      choices('type', '포워딩 방식', [
        ('local', '로컬 → 원격'),
        ('remote', '원격 → 로컬'),
        ('dynamic5', 'SOCKS 프록시'),
        if (draft['type'] == 'dynamic4') ('dynamic4', 'SOCKS4 (기존 설정)'),
      ]),
      text('sourceAddr', '대기 주소', required: true),
      text('sourcePort', '대기 포트', required: true, number: true),
      if (draft['type'] == 'local' || draft['type'] == 'remote') ...[
        text('destAddr', '대상 주소', required: true),
        text('destPort', '대상 포트', required: true, number: true),
      ],
      toggle('startEnabled', '접속할 때 자동 활성화'),
    ],
    RecordKind.key => [
      text('nickname', '키 이름', required: true),
      toggle('confirmation', '사용할 때마다 확인'),
      if (draft['biometric'] != true) ...[
        toggle('startup', '앱 시작 시 자동 불러오기'),
        toggle('allowBackup', '키 백업 허용'),
        if (draft['type'] != 'IMPORTED') ...[
          SwitchListTile(
            title: const Text('키 암호 변경'),
            value: changePassword,
            onChanged: (v) => setState(() => changePassword = v),
          ),
          if (changePassword) ...[
            text('oldPassword', '기존 암호', password: true),
            text('newPassword', '새 암호 (빈 값은 암호 제거)', password: true),
          ],
        ],
      ],
    ],
  };
  List<Widget> hostFields(String category) => switch (category) {
    'connection' => [
      text('nickname', '호스트 이름', required: true),
      choices('protocol', '연결 방식', [
        ('ssh', 'SSH'),
        ('mosh', 'Mosh'),
        ('telnet', 'Telnet'),
        ('local', '로컬 터미널'),
      ]),
      if (draft['protocol'] != 'local') ...[
        text('hostname', '서버 주소', required: true),
        text('port', '접속 포트', number: true, required: true),
        section('고급 옵션', [
          choices('ipVersion', 'IP 주소 선택', [
            ('IPV4_AND_IPV6', 'IPv4 및 IPv6'),
            ('IPV4_ONLY', 'IPv4'),
            ('IPV6_ONLY', 'IPv6'),
          ]),
          if (draft['protocol'] == 'ssh' || draft['protocol'] == 'mosh')
            references(
              'jumpHostId',
              '점프 호스트',
              'hosts',
              'nickname',
              emptyLabel: '직접 연결',
            ),
          if (draft['protocol'] == 'mosh') ...[
            text('moshPort', 'UDP 포트 (0은 자동)', number: true),
            text(
              'moshNetworkTimeout',
              '네트워크 타임아웃 (초)',
              number: true,
              optional: true,
            ),
            text('moshServer', 'mosh-server 경로', optional: true),
            text('locale', '서버 로케일'),
          ],
        ]),
      ],
    ],
    'authentication' => [
      if (draft['protocol'] == 'ssh') ...[
        TextButton(
          onPressed: widget.record != null && !saving
              ? () => registerKey()
              : null,
          child: const Text('이 서버에 키 등록'),
        ),
        if (widget.record == null) const Text('키 등록 전에 SSH 호스트를 먼저 저장해 주세요.'),
        const SizedBox(height: 16),
      ],
      if (draft['protocol'] == 'ssh' || draft['protocol'] == 'mosh') ...[
        choices(
          'identityId',
          '공용 로그인 계정',
          [
            (null, '이 호스트만의 인증정보'),
            for (final identity in engine.list('identities'))
              (identity['id'] as Object, '${identity['name']}'),
          ],
          onChanged: (id) => setState(() {
            draft['identityId'] = id;
            final identity = engine
                .list('identities')
                .where((i) => i['id'] == id)
                .firstOrNull;
            if (identity != null) {
              draft['username'] = identity['username'];
              draft['pubkeyId'] = identity['pubkeyId'];
            }
            draft['password'] = '';
            draft['hasPassword'] = false;
            draft['clearPassword'] = true;
            passwordRevision++;
          }),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    RecordListPage(engine: engine, kind: RecordKind.identity),
              ),
            ),
            child: const Text('공용 로그인 계정 관리'),
          ),
        ),
        text('username', '사용자 이름', enabled: draft['identityId'] == null),
      ],
      if ((draft['protocol'] == 'ssh' || draft['protocol'] == 'mosh') &&
          draft['identityId'] == null)
        pubkeySelector(),
      if ((draft['protocol'] == 'ssh' || draft['protocol'] == 'mosh') &&
          draft['identityId'] == null) ...[
        ...passwordFields(),
        if (widget.record != null)
          ListTile(
            title: const Text('신뢰한 서버 키'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => KnownHostsPage(
                  engine: engine,
                  hostId: widget.record!['id'] as int,
                ),
              ),
            ),
          ),
      ],
      if (draft['protocol'] == 'ssh' || draft['protocol'] == 'mosh')
        section('고급 인증 설정', [
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('SSH 인증 에이전트 사용'),
            value:
                draft['useAuthAgent'] != null && draft['useAuthAgent'] != 'no',
            onChanged: (enabled) =>
                setState(() => draft['useAuthAgent'] = enabled ? 'yes' : 'no'),
          ),
          if (draft['useAuthAgent'] != null && draft['useAuthAgent'] != 'no')
            SwitchListTile(
              title: const Text('확인 필요'),
              value: draft['useAuthAgent'] == 'confirm',
              onChanged: (enabled) => setState(
                () => draft['useAuthAgent'] = enabled ? 'confirm' : 'yes',
              ),
            ),
        ]),
    ],
    'appearance' => [
      text('color', '호스트 색상', optional: true, hint: '#03A9F4 또는 blue'),
      references('profileId', '터미널 프로필', 'profiles', 'name'),
      ListTile(
        title: const Text('터미널 프로필 관리'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                RecordListPage(engine: engine, kind: RecordKind.profile),
          ),
        ),
      ),
    ],
    'session' => [
      if (draft['protocol'] == 'ssh' || draft['protocol'] == 'mosh') ...[
        toggle('compression', 'SSH 압축'),
        toggle('wantSession', '터미널 세션 열기'),
      ],
      toggle('stayConnected', '연결 유지'),
      toggle('quickDisconnect', '종료 확인 생략'),
      if (widget.record != null)
        ListTile(
          title: const Text('로그인 후 자동 실행'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  AutomationPage(engine: engine, host: widget.record!),
            ),
          ),
        ),
      text('scrollbackLines', '스크롤 기록 행 수', number: true),
      toggle('useCtrlAltAsMetaKey', 'Ctrl+Alt를 Meta로 사용'),
    ],
    _ => [],
  };

  String hostCategoryTitle(String category) => switch (category) {
    'connection' => '연결',
    'authentication' => '인증',
    'appearance' => '화면·프로필',
    'session' => '세션',
    _ => '호스트 편집',
  };
  Widget hostCategories(String? selected) => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    children: [
      if ('${draft['nickname'] ?? ''}'.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${draft['nickname']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      for (final (category, icon, summary) in [
        (
          'connection',
          Icons.terminal,
          '${draft['hostname'] ?? '주소·포트·접속 방식'} · ${draft['protocol'] ?? 'SSH'}',
        ),
        (
          'authentication',
          Icons.key,
          '${draft['username'] ?? '인증 정보·SSH 키·비밀번호'}',
        ),
        ('appearance', Icons.palette_outlined, '터미널 프로필과 호스트 색상'),
        ('session', Icons.tune, '연결 유지와 로그인 후 자동 실행'),
      ])
        ListTile(
          selected: selected == category,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
          leading: CircleAvatar(child: Icon(icon, size: 22)),
          title: Text(hostCategoryTitle(category)),
          subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => setState(() => hostCategory = category),
        ),
    ],
  );

  Future<void> back(bool wide) async {
    if (saving) return;
    if (widget.kind == RecordKind.host && !wide && hostCategory != null) {
      setState(() => hostCategory = null);
      return;
    }
    if (!mapEquals(originalDraft, draft) &&
        !await confirm(context, '변경사항 버리기', '저장하지 않은 변경사항을 버릴까요?')) {
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<bool> save({bool close = true}) async {
    if (form.currentState?.validate() == false) return false;
    setState(() {
      saving = true;
      error = null;
    });
    final data = {...draft};
    if (!changePassword) {
      data.remove('oldPassword');
      data.remove('newPassword');
    }
    try {
      await engine.invoke('${widget.kind.name}.save', data);
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
      final wide = constraints.maxWidth >= 600;
      final host = widget.kind == RecordKind.host;
      final selected = hostCategory ?? (wide && host ? 'connection' : null);
      final dirty = !mapEquals(originalDraft, draft);
      final details = Form(
        key: form,
        child: ListView(
          key: ValueKey(selected),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
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
            if (saving) const LinearProgressIndicator(),
          ],
        ),
      );
      if (widget.kind == RecordKind.identity) {
        return AlertDialog(
          title: const Text('공용 로그인 계정'),
          content: SizedBox(
            width: 360,
            height: MediaQuery.sizeOf(context).height * .55,
            child: details,
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: saving ? null : () => save(),
              child: const Text('저장'),
            ),
          ],
        );
      }
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
          floatingActionButton: dirty
              ? FloatingActionButton(
                  tooltip: '저장',
                  onPressed: saving ? null : () => save(),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer,
                  child: saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.check),
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

class GenerateKeyPage extends StatefulWidget {
  final AndroidEngine engine;
  const GenerateKeyPage({super.key, required this.engine});
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
    appBar: AppBar(title: const Text('SSH 키 생성')),
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
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: '키 종류'),
            items: [
              for (final t in ['ED25519', 'RSA', 'EC', 'DSA'])
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setState(() {
              type = v!;
              bits = null;
              if (type != 'RSA' && type != 'EC') biometric = false;
            }),
          ),
          if (type == 'RSA' || type == 'EC')
            TextFormField(
              key: ValueKey(type),
              decoration: const InputDecoration(
                labelText: '키 강도 (비트)',
                hintText: '기본값 사용 가능',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => (v ?? '').isEmpty || int.tryParse(v!) != null
                  ? null
                  : '정수를 입력하세요.',
              onChanged: (v) => bits = int.tryParse(v),
            ),
          if ((type == 'RSA' || type == 'EC') &&
              row(widget.engine.state['generation'])['biometricAvailable'] ==
                  true)
            SwitchListTile(
              title: const Text('Android 생체인증으로 보호'),
              value: biometric,
              onChanged: (v) => setState(() {
                biometric = v;
                if (v) startup = false;
              }),
            ),
          if (!biometric) ...[
            TextFormField(
              obscureText: true,
              decoration: const InputDecoration(labelText: '키 암호'),
              onChanged: (v) => password = v,
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
          if (busy) const LinearProgressIndicator(),
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
                      await widget.engine.invoke('key.generate', {
                        'nickname': name,
                        'type': type,
                        if (bits != null) 'bits': bits,
                        'biometric': biometric,
                        'startup': startup,
                        'confirmation': confirmation,
                        'password': password,
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error = '$e';
                        });
                      }
                    }
                  },
            child: const Text('생성'),
          ),
        ],
      ),
    ),
  );
}
