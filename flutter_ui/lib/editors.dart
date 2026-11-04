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
import 'l10n/strings.dart';

enum RecordKind { host, profile, identity, forward, key }

String kindTitle(RecordKind kind) => switch (kind) {
  RecordKind.host => deviceStrings.host,
  RecordKind.profile => deviceStrings.profile,
  RecordKind.identity => deviceStrings.sharedLoginAccount,
  RecordKind.forward => deviceStrings.portForwarding,
  RecordKind.key => deviceStrings.sshKeys,
};

class RecordEditor extends StatefulWidget {
  final AndroidEngine engine;
  final RecordKind kind;
  final EngineRecord? record;
  final int? hostId;
  final int? sessionId;
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
    if (widget.kind == RecordKind.host && widget.record == null) {
      hostCategory = 'connection';
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
                return context.l10n.enter((label).toString());
              }
              if (number &&
                  (value ?? '').isNotEmpty &&
                  int.tryParse(value!) == null) {
                return context.l10n.enterAWholeNumber;
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
                  return context.l10n.checkThePortRange;
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
      values.add((current, context.l10n.currentValue((current).toString())));
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
                values.where((v) => v.$1 == current).firstOrNull?.$2 ??
                    context.l10n.select,
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
    String? emptyLabel,
  }) => choices(key, label, [
    (empty, emptyLabel ?? context.l10n.defaultValue),
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
          '${key['nickname']}${key['supported'] == false ? context.l10n.dsaUnsupported : ''}',
        ),
      (
        -1,
        engine.state['platform'] == 'windows'
            ? context.l10n.windowsDefaultKeysAndAddedKeys
            : context.l10n.tryAllAvailableKeys,
      ),
      (-2, context.l10n.noKey),
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
              ? context.l10n.passwordSaved
              : context.l10n.password,
          password: true,
        ),
        settingsNote(
          context,
          widget.kind == RecordKind.host
              ? context.l10n.storedEncryptedOnThisDeviceEnterItAgainAfter
              : context.l10n.storedEncryptedOnThisDevice,
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
          child: Text(context.l10n.deleteSavedPassword),
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
      section(context.l10n.sharedLoginAccount, [
        text('name', context.l10n.accountName, required: true),
        text('username', context.l10n.username, required: true),
      ]),
      if (widget.record != null)
        settingsNote(
          context,
          context.l10n.appliesToHosts(
            (engine
                    .list('hosts')
                    .where((h) => h['identityId'] == draft['id'])
                    .length)
                .toString(),
          ),
        ),
      section(context.l10n.sshKeys, [pubkeySelector()]),
      section(context.l10n.password, passwordFields()),
    ],
    RecordKind.profile => [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TerminalPreview(engine: engine, overrides: {'profile': draft}),
      ),
      section(context.l10n.display, [
        text('name', context.l10n.profileName, required: true),
        references(
          'colorSchemeId',
          context.l10n.colorTheme,
          'schemes',
          'name',
          empty: -1,
          emptyLabel: 'Tilde Night',
        ),
        choices('fontFamily', context.l10n.terminalFont, [
          (null, context.l10n.appDefault),
          ...fontOptions(engine),
        ], forceList: true),
        TildeStepper(
          title: context.l10n.fontSize,
          unit: 'sp',
          value: (draft['fontSize'] as num?)?.toInt() ?? 14,
          min: 4,
          max: 72,
          onChanged: (v) => setState(() => draft['fontSize'] = v),
        ),
      ]),
      section(context.l10n.terminal, [
        choices('encoding', context.l10n.characterEncoding, [
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
        choices('delKey', context.l10n.deleteKey, [
          ('del', 'Delete'),
          ('backspace', 'Backspace'),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = text(
                'forceSizeColumns',
                context.l10n.columnsAutomatic,
                number: true,
                optional: true,
              );
              final rows = text(
                'forceSizeRows',
                context.l10n.rowsAutomatic,
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
      section(context.l10n.forwarding, [
        text('nickname', context.l10n.forwardingName, required: true),
        choices('type', context.l10n.type, [
          ('local', context.l10n.local),
          ('remote', context.l10n.remote),
          ('dynamic5', 'SOCKS5'),
        ], preserveUnknown: false),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(switch (draft['type']) {
            'remote' =>
              context.l10n.forwardConnectionsFromAServerPortToAnAddress,
            'local' =>
              context.l10n.forwardConnectionsFromADevicePortToAnAddress,
            _ => context.l10n.openASocks5ProxyOnThisDevice,
          }),
        ),
        if (draft['type'] == 'dynamic4')
          settingsNote(
            context,
            context.l10n.socks4IsUnsupportedChangeTheTypeToSocks5To,
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
                      ? text(
                          'sourceAddr',
                          context.l10n.listenAddressOnServer,
                          required: true,
                        )
                      : ListTile(
                          title: Text(context.l10n.listenAddressOnThisDevice),
                          subtitle: Text(
                            context.l10n.text127001AccessibleOnlyOnThisDevice,
                          ),
                        ),
                  text(
                    'sourcePort',
                    context.l10n.port,
                    required: true,
                    number: true,
                  ),
                ),
                if (draft['type'] == 'local' || draft['type'] == 'remote')
                  pair(
                    text(
                      'destAddr',
                      context.l10n.destinationAddress,
                      required: true,
                    ),
                    text(
                      'destPort',
                      context.l10n.port,
                      required: true,
                      number: true,
                    ),
                  ),
              ],
            );
          },
        ),
      ]),
    ],
    RecordKind.key => [
      section(context.l10n.publicKey, [
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
                  child: Text(context.l10n.copyFingerprint),
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
            label: Text(context.l10n.copyPublicKey),
          ),
      ]),
      section(context.l10n.keySettings, [
        text('nickname', context.l10n.keyName, required: true),
        if (draft['supported'] == true)
          toggle(
            'confirmation',
            context.l10n.confirmBeforeUse,
            description:
                context.l10n.askForPermissionBeforeAuthenticatingWithThisKey,
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
                  ? context.l10n.importedPrivateKey
                  : context.l10n.androidKeystoreP256Key,
            ),
            subtitle: Text(
              draft['type'] == 'IMPORTED'
                  ? context.l10n.authenticateWithAnImportedPrivateKeyFile
                  : context.l10n.thePrivateKeyCannotBeExportedFromThisDevice,
            ),
          ),
        if (draft['supported'] != true)
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: Text(context.l10n.disabledLegacyPrivateKey),
            subtitle: Text(
              '${draft['supportMessage'] ?? context.l10n.replaceItWithANewAndroidKeystoreKeyBefore}',
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
          choices('protocol', context.l10n.connectionType, [
            ('ssh', 'SSH'),
            if (engine.state['platform'] != 'ios')
              ('local', context.l10n.local),
          ], preserveUnknown: false),
          if (!supportedHost)
            settingsNote(
              context,
              context.l10n.connectionsAreUnsupportedChangeToSshOrLocal(
                (draft['protocol']).toString(),
              ),
            ),
          if (!wideEditor)
            text('nickname', context.l10n.hostName, required: true),
          if (wideEditor) text('nickname', context.l10n.name, required: true),
          if (draft['protocol'] != 'local') ...[
            if (wideEditor)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: text(
                      'username',
                      context.l10n.username,
                      enabled: draft['identityId'] == null,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: text(
                      'hostname',
                      context.l10n.serverAddress,
                      required: true,
                      hint: 'user@host:port',
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    child: text(
                      'port',
                      context.l10n.port,
                      number: true,
                      required: true,
                    ),
                  ),
                ],
              )
            else ...[
              text(
                'hostname',
                context.l10n.serverAddress,
                required: true,
                hint: 'user@host:port',
              ),
              text('port', context.l10n.port, number: true, required: true),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.pasteUserHostPortIntoTheAddressFieldTo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            group(context.l10n.advanced, [
              choices('ipVersion', context.l10n.ipAddress, [
                ('IPV4_AND_IPV6', context.l10n.automatic),
                ('IPV4_ONLY', 'IPv4'),
                ('IPV6_ONLY', 'IPv6'),
              ]),
              if (sshHost)
                choices(
                  'jumpHostId',
                  context.l10n.jumpHost,
                  [
                    (null, context.l10n.directConnection),
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
          return [
            settingsNote(
              context,
              context
                  .l10n
                  .thisConnectionTypeDoesNotUseSshAuthenticationSettings,
            ),
          ];
        }
        final identity = engine
            .list('identities')
            .where((i) => i['id'] == draft['identityId'])
            .firstOrNull;
        return [
          group(context.l10n.account, [
            choices(
              'identityId',
              context.l10n.sharedLoginAccount,
              [
                (null, context.l10n.doNotUse),
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
              text('username', context.l10n.username)
            else if (identity != null)
              ListTile(
                title: Text(
                  context.l10n.usingAccount((identity['name']).toString()),
                ),
                subtitle: Text(
                  '${identity['username']}',
                  style: const TextStyle(fontFamily: tildeMono),
                ),
                trailing: TextButton(
                  onPressed: () =>
                      showIdentityEditor(context, engine, record: identity),
                  child: Text(context.l10n.edit2),
                ),
              ),
          ]),
          if (identity == null) ...[
            group(context.l10n.loginKey, [pubkeySelector()]),
            group(context.l10n.password, [
              ...passwordFields(),
              if (draft['protocol'] == 'ssh')
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: Text(context.l10n.registerKeyOnThisServer),
                  subtitle: Text(
                    context.l10n.logInOnceWithAPasswordToInstallThe,
                  ),
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
          group(context.l10n.hostColor, [
            ListTile(
              leading: TildeHostTile(host: draft),
              title: Text('${draft['nickname'] ?? ''}'),
              subtitle: Text(
                context.l10n.previewInTheHomeListTabsAndNotifications,
              ),
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
                    tooltip: context.l10n.customHostColor,
                    onPressed: () async {
                      final contextStrings = context.l10n;
                      final color = await pickTildeColor(
                        context,
                        Color(
                          0xff000000 |
                              (current ??
                                  ((draft['iconArgb'] as int?) ?? 0xff6fd8c4)),
                        ),
                        title: contextStrings.hostColor,
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
          group(context.l10n.terminalProfile, [
            tildeRadioOptions(
              context,
              [
                (
                  null,
                  context.l10n.appDefault2(
                    (defaultProfile(engine)['name'] ?? 'Default').toString(),
                  ),
                ),
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
              title: Text(context.l10n.manageProfiles),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => page(
                RecordListPage(engine: engine, kind: RecordKind.profile),
              ),
            ),
          ]),
        ];
      case 'session':
        return [
          group(context.l10n.connect, [
            if (sshHost)
              toggle(
                'stayConnected',
                context.l10n.keepConnectionAlive,
                description: context.l10n.reconnectAutomaticallyAfterAnIOError,
              ),
            toggle(
              'quickDisconnect',
              context.l10n.closeWithoutAsking,
              description: context.l10n.closeTheTabImmediatelyAfterExit,
            ),
            if (sshHost) ...[
              toggle(
                'compression',
                context.l10n.sshCompression,
                description: context.l10n.enableOnlyOnSlowConnections,
              ),
              toggle(
                'wantSession',
                context.l10n.openTerminal,
                description: context.l10n.whenOffOnlyPortForwardingIsEnabled,
              ),
            ],
          ]),
          group(context.l10n.overrideForThisHost, [
            TildeStepper(
              title: context.l10n.scrollback,
              unit: context.l10n.linesDefault(
                (engine.preferences['scrollback'] ?? '').toString(),
              ),
              value:
                  (draft['scrollbackLines'] as num?)?.toInt() ??
                  int.tryParse('${engine.preferences['scrollback'] ?? 140}') ??
                  140,
              step: 500,
              onChanged: (v) => setState(() => draft['scrollbackLines'] = v),
            ),
            toggle('useCtrlAltAsMetaKey', context.l10n.useCtrlAltAsMeta),
          ]),
        ];
      default:
        return [];
    }
  }

  String hostCategoryTitle(String category) => switch (category) {
    'connection' => context.l10n.connect,
    'authentication' => context.l10n.authentication,
    'appearance' => context.l10n.displayAndProfile,
    'session' => context.l10n.session2,
    _ => context.l10n.editHost,
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
                  context.l10n.fileTransfer,
                  Icons.folder_open_outlined,
                  () => page(FileBrowserPage(engine: engine, host: draft)),
                ),
              if (sshHost)
                quick(
                  context.l10n.forwarding,
                  Icons.swap_horiz,
                  () => page(ForwardsPage(engine: engine, host: draft)),
                ),
              if (supportedHost)
                quick(
                  context.l10n.duplicate,
                  Icons.file_copy_outlined,
                  duplicateHost,
                ),
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
              ? context.l10n.localShell
              : '${draft['protocol'] ?? 'ssh'} · ${draft['hostname'] ?? ''}:${draft['port'] ?? ''}',
        ),
        if (sshHost)
          (
            'authentication',
            '${key?['nickname'] ?? context.l10n.selectKey} · ${draft['username'] ?? ''}',
          ),
        ('appearance', '${profile['name'] ?? context.l10n.appDefault}'),
        (
          'session',
          draft['stayConnected'] == true
              ? context.l10n.keepConnectionAlive
              : context.l10n.connectionSettings,
        ),
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
          title: Text(context.l10n.trustedServerKeys),
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
    final contextStrings = context.l10n;
    final name = await askText(
      context,
      contextStrings.nameForDuplicate,
      initial: contextStrings.copy((draft['nickname']).toString()),
      action: contextStrings.duplicate,
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
    final contextStrings = context.l10n;
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
            content: Text(contextStrings.couldNotSave),
            action: SnackBarAction(
              label: contextStrings.details,
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
        _fieldLabels[key] ??
        (key == 'password' ? context.l10n.password : context.l10n.settings);
    Future<void> showChanges() => showTildeSheet<void>(
      context: context,
      builder: (c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.changedFields,
              style: Theme.of(c).textTheme.titleLarge,
            ),
            for (final key in keys)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label(key)),
                subtitle: Text(
                  key == 'password'
                      ? context.l10n.changePassword
                      : '${originalDraft[key] ?? context.l10n.none} → ${draft[key] ?? context.l10n.none}',
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
                      Text(context.l10n.saving)
                    else if (dirty && error != null)
                      TextButton.icon(
                        onPressed: () => showErrorDetails(context, error!),
                        icon: Icon(
                          Icons.circle,
                          size: 6,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        label: Text(context.l10n.couldNotSave),
                      )
                    else if (dirty)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            keys.length == 1
                                ? context.l10n.changed(
                                    (label(keys.first)).toString(),
                                  )
                                : context.l10n.andOthers(
                                    (label(keys.first)).toString(),
                                  ),
                          ),
                          if (keys.length > 1)
                            TextButton(
                              onPressed: showChanges,
                              child: Text(
                                context.l10n.items((keys.length - 1)),
                              ),
                            ),
                        ],
                      )
                    else if (savedNotice)
                      Text(context.l10n.saved),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (dirty || saving) ...[
                          TextButton(
                            onPressed: saving ? null : cancelEdits,
                            child: Text(context.l10n.undo),
                          ),
                          Tooltip(
                            message: 'Ctrl S',
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => save(close: false),
                              child: Text(context.l10n.save),
                            ),
                          ),
                        ],
                        if (supportedHost && !wide) ...[
                          FilledButton(
                            onPressed: saving ? null : connectSavedHost,
                            child: Text(
                              dirty
                                  ? context.l10n.saveAndOpenNewTerminal
                                  : context.l10n.newTerminal,
                            ),
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
            PopupMenuItem(
              value: 'duplicate',
              child: TildeMenuLabel(
                context.l10n.duplicate,
                Icons.content_copy_outlined,
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: TildeMenuLabel(
              context.l10n.deleteHost,
              Icons.delete_outline,
              danger: true,
            ),
          ),
        ],
      );
      final details = Form(
        key: form,
        child: ListView(
          shrinkWrap: widget.sheet,
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
                        label: Text(
                          dirty
                              ? context.l10n.saveAndOpenNewTerminal
                              : context.l10n.newTerminal,
                        ),
                      ),
                    if (savedHost) hostMenu,
                  ],
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(context.l10n.couldNotSaveChanges),
                  trailing: TextButton(
                    onPressed: () => showErrorDetails(context, error!),
                    child: Text(context.l10n.details),
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
                          widget.record == null
                              ? context.l10n.add2(kindTitle(widget.kind))
                              : context.l10n.edit(kindTitle(widget.kind)),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Flexible(child: details),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: saving ? null : () => back(false),
                                child: Text(context.l10n.cancel),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: saving ? null : () => save(),
                                child: Text(
                                  saving
                                      ? context.l10n.saving2
                                      : widget.sessionId != null
                                      ? context.l10n.apply
                                      : context.l10n.save,
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
                                  tooltip: context.l10n.back,
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => back(wide),
                                ),
                          title: Text(
                            host && !wide && selected != null
                                ? hostCategoryTitle(selected)
                                : widget.embedded
                                ? context.l10n.edit(
                                    (draft['nickname'] ?? context.l10n.newHost)
                                        .toString(),
                                  )
                                : widget.record == null
                                ? context.l10n.add2(kindTitle(widget.kind))
                                : context.l10n.edit(kindTitle(widget.kind)),
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
                              ? context.l10n.add
                              : context.l10n.save,
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
                                    label: Text(context.l10n.newTerminal),
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
                                                '${draft['nickname'] ?? context.l10n.newHost}',
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
      font['value'] == 'SYSTEM_DEFAULT'
          ? deviceStrings.systemDefault
          : '${font['label']}',
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
      (value == null ? deviceStrings.appDefaultFont : '$value');
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
            Text(
              context.l10n.newSshKey,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Text(context.l10n.keyName, style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? context.l10n.enterAName : null,
              onChanged: (v) => name = v,
            ),
            settingsNote(
              context,
              context.l10n.createAP256PrivateKeyInAndroidKeystore,
            ),
            if (error != null)
              ListTile(
                title: Text(context.l10n.couldNotCreateKey),
                trailing: TextButton(
                  onPressed: () => showErrorDetails(context, error!),
                  child: Text(context.l10n.details),
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
                  : Text(context.l10n.createKey),
            ),
          ],
        ),
      ),
    ),
  );
}
