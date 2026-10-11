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
import 'package:flutter/services.dart';
import 'engine.dart';
import 'main.dart';
import 'management.dart';

class ConsolePage extends StatefulWidget {
  final AndroidEngine engine;
  final int sessionId;
  final bool startKeySetup;
  const ConsolePage({
    super.key,
    required this.engine,
    required this.sessionId,
    this.startKeySetup = false,
  });
  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> {
  late int id;
  EngineRecord connectionTarget = {};
  void rememberSession() {
    final current = session;
    if (current.isNotEmpty) connectionTarget = current;
  }

  final routeOwner = UniqueKey().toString();
  bool? visible;
  bool setupOpened = false;
  Timer? titleTimer;
  bool titleHidden = false;
  void interaction() {
    titleTimer?.cancel();
    if (mounted && titleHidden) setState(() => titleHidden = false);
    if (engine.preferences['titlebarhide'] == true) {
      titleTimer = Timer(
        Duration(
          milliseconds: (engine.state['autoHideDelayMs'] as int?) ?? 3000,
        ),
        () {
          if (mounted) setState(() => titleHidden = true);
        },
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent == true;
    if (visible != current) {
      visible = current;
      engine.query('session.visibility', {
        'id': id,
        'owner': routeOwner,
        'visible': current,
      });
    }
  }

  void select(int target) {
    setState(() => id = target);
    rememberSession();
    engine.query('session.visibility', {
      'id': id,
      'owner': routeOwner,
      'visible': visible == true,
    });
  }

  AndroidEngine get engine => widget.engine;
  @override
  void initState() {
    super.initState();
    id = widget.sessionId;
    rememberSession();
    interaction();
    engine.addListener(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) changed();
    });
  }

  @override
  void dispose() {
    titleTimer?.cancel();
    engine.query('session.visibility', {
      'id': id,
      'owner': routeOwner,
      'visible': false,
    });
    engine.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (!mounted) return;
    rememberSession();
    if (widget.startKeySetup && !setupOpened && session['canEnroll'] == true) {
      setupOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) menu('enroll');
      });
    }
    final input = engine.textInput;
    if (input?['owner'] == routeOwner) {
      engine.textInput = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final text = await askText(
          context,
          '텍스트 입력',
          initial: '${input?['text'] ?? ''}',
          multiline: true,
        );
        if (text != null && mounted) {
          await command('session.sendText', {'text': text});
        }
      });
    }
    final request = engine.sessionSwitch;
    if (request?['owner'] == routeOwner && request?['id'] != id) {
      engine.sessionSwitch = null;
      select(request!['id'] as int);
    } else {
      setState(() {});
    }
  }

  EngineRecord get session =>
      engine.list('sessions').where((s) => s['id'] == id).firstOrNull ?? {};
  Future<dynamic> command(String method, [EngineRecord args = const {}]) =>
      runEngine(context, engine, method, {'id': id, ...args});
  bool leaving = false;
  bool get authenticationPending =>
      engine.list('prompts').any((prompt) => prompt['sessionId'] == id);

  Future<void> leave() async {
    if (leaving) return;
    leaving = true;
    try {
      if (authenticationPending) {
        await engine.invoke('session.disconnect', {'id': id});
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      leaving = false;
    }
  }

  Future<void> menu(String action) async {
    if ([
      'keyboard',
      'compose',
      'select',
      'selectAll',
      'selectVisible',
      'copy',
      'clearSelection',
      'paste',
      'selectionMode',
      'selectionUp',
      'selectionDown',
      'selectionLeft',
      'selectionRight',
    ].contains(action)) {
      await command('session.view', {'action': action});
      return;
    }
    if (action == 'resize') {
      final size = await askText(
        context,
        '터미널 크기 (행 x 열, 빈 값은 자동)',
        initial: '',
      );
      if (size == null || !mounted) return;
      final parts = size.toLowerCase().split('x');
      if (size.isNotEmpty &&
          (parts.length != 2 ||
              int.tryParse(parts.first.trim()) == null ||
              int.tryParse(parts.last.trim()) == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('‘24x80’처럼 행x열로 입력해 주세요.')),
        );
        return;
      }
      await command('session.view', {
        'action': 'resize',
        'rows': size.isEmpty ? null : int.parse(parts.first.trim()),
        'columns': size.isEmpty ? null : int.parse(parts.last.trim()),
      });
      return;
    }
    if (action == 'fontUp' || action == 'fontDown') {
      await command('session.font', {'increase': action == 'fontUp'});
      return;
    }
    if (action == 'text' || action == 'editPaste') {
      final initial = action == 'editPaste'
          ? (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? ''
          : '';
      if (!mounted) return;
      final text = await askText(
        context,
        '텍스트 입력',
        initial: initial,
        multiline: true,
      );
      if (text != null && mounted) {
        await command('session.sendText', {'text': text});
      }
      return;
    }
    if (action == 'disconnect') {
      if (await confirm(context, '연결 종료', '이 세션을 종료할까요?') && mounted) {
        await command('session.disconnect');
      }
      return;
    }
    if (action == 'reconnect') {
      final hostId = connectionTarget['hostId'];
      final uri = connectionTarget['uri'];
      if (hostId is int && hostId > 0) {
        await runEngine(context, engine, 'connect', {'id': hostId});
      } else if (uri is String) {
        await runEngine(context, engine, 'connect', {'uri': uri});
      }
      return;
    }
    if (action == 'cancelAutomation') {
      await command('session.cancelAutomation');
      return;
    }
    if (action == 'urls') {
      final urls = await command('session.urls') as List? ?? [];
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('터미널 링크'),
            content: SizedBox(
              width: 480,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final url in urls)
                    ListTile(
                      title: Text('$url'),
                      onTap: () =>
                          runEngine(context, engine, 'openUrl', {'url': url}),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      }
      return;
    }
    final host = engine
        .list('hosts')
        .where((h) => h['id'] == connectionTarget['hostId'])
        .firstOrNull;
    if (host == null || !mounted) return;
    if (action == 'forwards') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ForwardsPage(engine: engine, host: host),
        ),
      );
    }
    if (action == 'enroll' && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              EnrollmentPage(engine: engine, host: host, sessionId: id),
        ),
      );
    }
  }

  Future<void> pickSession() async {
    final target = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('연결 선택'),
        children: [
          for (final s in engine.list('sessions'))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s['id']),
              child: Text('${s['nickname']}'),
            ),
        ],
      ),
    );
    if (target != null && mounted) select(target);
  }

  Future<void> selectMenuAction(String action) async {
    interaction();
    final sessions = engine.list('sessions');
    final current = sessions.indexWhere((s) => s['id'] == id);
    if (action == 'more') {
      final selected = await askAction(context, '추가 기능', [
        ('editPaste', '텍스트 편집 후 붙여넣기'),
        ('compose', session['composeMode'] == true ? '조합 모드 끄기' : '조합 모드 켜기'),
        ('urls', '링크 찾기'),
        if (session['open'] == true) ('resize', '터미널 크기 지정'),
        if (session['canForward'] == true && session['open'] == true)
          ('forwards', '포트 포워딩'),
        if (session['canEnroll'] == true) ('enroll', '이 서버에 키 등록'),
        if (current > 0) ('previous', '이전 연결'),
        if (current >= 0 && current < sessions.length - 1) ('next', '다음 연결'),
        (
          'fullscreen',
          engine.preferences['fullscreen'] == true ? '전체 화면 끄기' : '전체 화면 켜기',
        ),
        (
          'titlebarhide',
          engine.preferences['titlebarhide'] == true
              ? '제목 표시줄 항상 표시'
              : '제목 표시줄 자동 숨기기',
        ),
      ]);
      if (selected != null && mounted) await selectMenuAction(selected);
    } else if (action == 'previous' || action == 'next') {
      final target = current + (action == 'previous' ? -1 : 1);
      if (target >= 0 && target < sessions.length) {
        select(sessions[target]['id'] as int);
      }
    } else if (action == 'fullscreen' || action == 'titlebarhide') {
      await command('settings.update', {
        'key': action,
        'value': engine.preferences[action] != true,
      });
      interaction();
    } else {
      await menu(action);
    }
  }

  Widget popup() {
    final connected = session['open'] == true;
    return PopupMenuButton<String>(
      tooltip: '터미널 메뉴',
      onOpened: () => titleTimer?.cancel(),
      onCanceled: interaction,
      onSelected: selectMenuAction,
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'paste', child: Text('붙여넣기')),
        const PopupMenuItem(value: 'text', child: Text('텍스트 입력')),
        if (!connected)
          const PopupMenuItem(value: 'reconnect', child: Text('다시 연결')),
        const PopupMenuItem(value: 'more', child: Text('추가 기능')),
        PopupMenuItem(
          value: 'disconnect',
          child: Text(connected ? '연결 끊기' : '닫기'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = engine.preferences;
    return PopScope(
      canPop: !authenticationPending,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(leave());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        primary: prefs['fullscreen'] != true,
        appBar: titleHidden && prefs['titlebarhide'] == true
            ? null
            : AppBar(
                toolbarHeight: 36,
                primary: prefs['fullscreen'] != true,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  tooltip: '뒤로',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: leave,
                ),
                titleSpacing: 0,
                title: InkWell(
                  onTap: pickSession,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${session['nickname'] ?? '터미널'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      if (engine.list('sessions').length > 1)
                        const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
                actions: [popup()],
              ),
        body: SafeArea(
          maintainBottomViewPadding: true,
          top: prefs['fullscreen'] != true,
          bottom: prefs['fullscreen'] != true,
          left: prefs['fullscreen'] != true,
          right: prefs['fullscreen'] != true,
          child: Column(
            children: [
              for (final banner in rows(session['banners']))
                ExpansionTile(
                  title: Text('${banner['sourceName']}'),
                  trailing: IconButton(
                    tooltip: '배너 닫기',
                    icon: const Icon(Icons.close),
                    onPressed: () => command('session.dismissBanner', {
                      'bannerId': banner['id'],
                    }),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText('${banner['message']}'),
                    ),
                  ],
                ),
              if (row(session['automation'])['running'] == true)
                const LinearProgressIndicator(),
              if (session.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('세션이 끝났어요'),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => menu('reconnect'),
                          child: const Text('다시 연결'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Listener(
                    onPointerDown: (_) => interaction(),
                    child: AndroidView(
                      key: ValueKey(id),
                      viewType: 'dev.korellas.androidshell/terminal',
                      creationParams: {'sessionId': id, 'owner': routeOwner},
                      creationParamsCodec: const StandardMessageCodec(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnrollmentPage extends StatefulWidget {
  final AndroidEngine engine;
  final EngineRecord host;
  final int sessionId;
  const EnrollmentPage({
    super.key,
    required this.engine,
    required this.host,
    required this.sessionId,
  });
  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  int? keyId;
  String name = '';
  @override
  void initState() {
    super.initState();
    name = '${widget.host['nickname']} SSH 키';
    widget.engine.invoke('key.enrollmentBegin', {'name': name});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.engine,
    builder: (context, _) {
      final state = row(widget.engine.state['enrollment']);
      final available = widget.engine.list('keys');
      if (keyId == null &&
          state['biometricAvailable'] != true &&
          available.isNotEmpty) {
        keyId = available.first['id'] as int;
      }
      return Scaffold(
        appBar: AppBar(title: const Text('SSH 키 로그인 등록')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('연결된 서버에 공개키를 등록하고 별도의 SSH 연결로 키 로그인이 되는지 확인해요.'),
            DropdownButtonFormField<int>(
              initialValue: keyId,
              decoration: const InputDecoration(labelText: '등록할 키'),
              items: [
                if (state['biometricAvailable'] == true)
                  const DropdownMenuItem(value: null, child: Text('새 생체인증 키')),
                for (final key in available)
                  DropdownMenuItem(
                    value: key['id'] as int,
                    child: Text('${key['nickname']}'),
                  ),
              ],
              onChanged: state['busy'] == true
                  ? null
                  : (value) => setState(() => keyId = value),
            ),
            if (keyId == null)
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: '새 키 이름'),
                onChanged: (value) => name = value,
              ),
            if (state['error'] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('${state['error']}'),
              ),
            if (state['busy'] == true) const LinearProgressIndicator(),
            Text(switch (state['stage']) {
              'SUCCESS' => '공개키 등록과 키 로그인 검증을 완료했어요.',
              'REGISTERING' => '서버에 공개키 등록 중…',
              'VERIFYING' => '키 로그인 확인 중…',
              'APPLYING' => '호스트에 키 적용 중…',
              _ => '',
            }),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: state['busy'] == true || state['stage'] == 'SUCCESS'
                  ? null
                  : () => runEngine(context, widget.engine, 'key.enroll', {
                      'sessionId': widget.sessionId,
                      'keyId': keyId,
                      'name': name,
                    }),
              child: const Text('등록 및 검증'),
            ),
          ],
        ),
      );
    },
  );
}
