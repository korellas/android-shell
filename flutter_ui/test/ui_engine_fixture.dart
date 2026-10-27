import 'package:android_shell_ui/engine.dart';
import 'package:flutter/services.dart';
import 'package:android_shell_ui/terminal/app_terminal_session.dart';
import 'package:android_shell_ui/terminal/local_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI contract double. Runtime and key behavior are tested with their own engines.
class UiEngineFixture extends AndroidEngine {
  UiEngineFixture({this.fontFamily = 'monospace'}) {
    addTearDown(() {
      if (!isDisposed) dispose();
    });
  }

  final String fontFamily;

  final _terminals = <int, _UiTerminalSession>{};

  @override
  AppTerminalSession? terminalSession(int id) {
    if (!list('sessions').any((record) => record['id'] == id)) return null;
    return _terminals.putIfAbsent(id, () => _UiTerminalSession(id, this));
  }

  @override
  Future<String> terminalFont(String name) async => fontFamily;

  @override
  void dispose() {
    if (isDisposed) return;
    for (final session in _terminals.values) {
      session.input.dispose();
      session.controller.dispose();
      session.terminal.dispose();
    }
    _terminals.clear();
    super.dispose();
  }

  @override
  Future<void> start() => refresh();

  @override
  Future<void> refresh() async {
    if (isDisposed) return;
    state = row(await AndroidEngine.channel.invokeMethod<Object?>('snapshot'));
    if (!isDisposed) notifyListeners();
  }

  @override
  Future<dynamic> query(String method, [EngineRecord args = const {}]) async {
    try {
      return await AndroidEngine.channel.invokeMethod<dynamic>(method, args);
    } on PlatformException catch (error) {
      throw EngineException(
        error.message ?? error.code,
        details: error.toString(),
      );
    }
  }
}

class _UiTerminalSession extends AppLocalSession {
  _UiTerminalSession(int id, this.engine)
    : super(
        id: id,
        prepared: {
          'host': {'id': id},
          'profile': <String, dynamic>{},
        },
        platform: (_, _) async => null,
        events: const Stream.empty(),
        onChanged: () {},
      );

  final UiEngineFixture engine;
  @override
  EngineRecord get record =>
      engine.list('sessions').firstWhere((s) => s['id'] == id);
  @override
  bool get sessionOpen => record['open'] == true;
  @override
  bool get connecting => record['connecting'] == true;
  @override
  bool get ended => record['ended'] == true;
}
