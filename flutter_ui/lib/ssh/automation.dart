// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

enum SshAutomationType {
  waitForText,
  sendText,
  sendKey,
  delay,
  disconnect,
  enableForward,
  disableForward,
}

enum SshAutomationError {
  timedOut,
  bufferOverflow,
  noSession,
  forwardMissing,
  regexUnavailable,
  actionFailed,
}

class SshAutomationStep {
  const SshAutomationStep({
    required this.type,
    this.text = '',
    this.regex = false,
    this.duration = const Duration(seconds: 30),
    this.key = 2,
    this.modifiers = 0,
    this.forwardId,
    this.continueOnFailure = false,
  });

  final SshAutomationType type;
  final String text;
  final bool regex;
  final Duration duration;
  final int key;
  final int modifiers;
  final int? forwardId;
  final bool continueOnFailure;
}

class SshAutomationState {
  const SshAutomationState({
    this.running = false,
    this.step = 0,
    this.total = 0,
    this.error,
    this.failedStep,
    this.completed = false,
  });

  final bool running;
  final int step;
  final int total;
  final SshAutomationError? error;
  final int? failedStep;
  final bool completed;
}

/// Receives decoded output independently of the terminal widget lifetime.
/// Key translation and text encoding belong to the terminal/session adapter.
class SshAutomation {
  SshAutomation({
    required this.sessionOpen,
    required this.sendText,
    required this.sendKey,
    required this.setForward,
    required this.disconnect,
    this.onState,
    this.matchRegexEnd,
    this.outputCapacity = 65536,
  }) {
    if (outputCapacity <= 0) throw ArgumentError.value(outputCapacity);
  }

  final bool Function() sessionOpen;
  final Future<void> Function(String) sendText;
  final Future<void> Function(int, int) sendKey;
  final Future<void> Function(int, bool) setForward;
  final Future<void> Function() disconnect;
  final void Function(SshAutomationState)? onState;
  // The platform adapter reuses the existing RE2 matcher off the UI thread.
  final Future<int?> Function(String expression, String text)? matchRegexEnd;
  final int outputCapacity;
  SshAutomationState get state => _state;
  SshAutomationState _state = const SshAutomationState();
  _AutomationRun? _active;
  String _output = '';
  _Escape _escape = _Escape.text;
  bool _pendingCr = false;
  bool _overflow = false;
  Completer<void> _changed = Completer<void>();

  void _publish(SshAutomationState state) {
    _state = state;
    onState?.call(state);
  }

  void addOutput(String chunk) {
    if (_overflow) return;
    final text = StringBuffer(_output);
    for (final code in chunk.codeUnits) {
      switch (_escape) {
        case _Escape.escape:
          _escape = switch (code) {
            0x5b => _Escape.csi,
            0x5d || 0x50 || 0x5e || 0x5f => _Escape.string,
            >= 0x20 && <= 0x2f => _Escape.intermediate,
            _ => _Escape.text,
          };
        case _Escape.csi:
          if (code >= 0x40 && code <= 0x7e) _escape = _Escape.text;
        case _Escape.string:
          if (code == 7 || code == 0x9c) _escape = _Escape.text;
          if (code == 0x1b) _escape = _Escape.stringEscape;
        case _Escape.stringEscape:
          _escape = code == 0x5c ? _Escape.text : _Escape.string;
        case _Escape.intermediate:
          if (code >= 0x30 && code <= 0x7e) _escape = _Escape.text;
        case _Escape.text:
          switch (code) {
            case 0x1b:
              _escape = _Escape.escape;
            case 0x9b:
              _escape = _Escape.csi;
            case 0x9d || 0x90 || 0x9e || 0x9f:
              _escape = _Escape.string;
            case 13:
              text.write('\n');
              _pendingCr = true;
            case 10:
              if (!_pendingCr) text.write('\n');
              _pendingCr = false;
            default:
              _pendingCr = false;
              if (code == 9 || code >= 32) text.writeCharCode(code);
          }
      }
      if (text.length > outputCapacity) {
        _overflow = true;
        _active?.interrupt(SshAutomationError.bufferOverflow);
        _output = '';
        _notifyOutput();
        return;
      }
    }
    _output = text.toString();
    _notifyOutput();
  }

  void _notifyOutput() {
    final previous = _changed;
    _changed = Completer<void>();
    previous.complete();
  }

  /// Stops automation only; an attached trial terminal remains connected.
  void cancel() {
    _active?.interrupt(null);
  }

  Future<T> _await<T>(Future<T> operation, _AutomationRun run) {
    return Future.any([
      operation,
      run.interrupted.future.then<T>((reason) => throw _Interrupted(reason)),
    ]);
  }

  Future<void> run(List<SshAutomationStep> actions) async {
    if (_active != null) throw StateError('Automation is already running');
    if (actions.isEmpty) return;
    final run = _AutomationRun();
    _active = run;
    var step = 0;
    SshAutomationError? error;
    int? failed;
    void publish({bool running = true, bool completed = false}) {
      _publish(
        SshAutomationState(
          running: running,
          completed: completed,
          step: step,
          total: actions.length,
          error: error,
          failedStep: failed,
        ),
      );
    }

    publish();
    try {
      if (_overflow) throw _Interrupted(SshAutomationError.bufferOverflow);
      for (final action in actions) {
        run.check();
        step++;
        publish();
        try {
          final disconnecting = await _execute(action, run);
          run.check();
          if (disconnecting) break;
        } on _Interrupted {
          rethrow;
        } catch (failure) {
          error = failure is SshAutomationError
              ? failure
              : SshAutomationError.actionFailed;
          failed = step;
          if (!action.continueOnFailure) {
            publish(running: false);
            return;
          }
        }
      }
      publish(running: false, completed: true);
    } on _Interrupted catch (interrupted) {
      if (interrupted.reason != null) {
        error = interrupted.reason;
        failed = step;
      }
      publish(running: false);
    } finally {
      _active = null;
    }
  }

  Future<bool> _execute(SshAutomationStep action, _AutomationRun run) async {
    run.check();
    switch (action.type) {
      case SshAutomationType.waitForText:
        _requireSession();
        if (action.text.isEmpty || action.duration <= Duration.zero) {
          throw SshAutomationError.actionFailed;
        }
        final expired = Completer<void>();
        final timer = Timer(action.duration, () => expired.complete());
        Future<T> wait<T>(Future<T> future) => _await(
          Future.any([
            future,
            expired.future.then<T>((_) => throw SshAutomationError.timedOut),
          ]),
          run,
        );
        try {
          while (true) {
            run.check();
            final changed = _changed.future;
            final snapshot = _output;
            final int? end;
            if (action.regex) {
              final matcher = matchRegexEnd;
              if (matcher == null) throw SshAutomationError.regexUnavailable;
              end = await wait(matcher(action.text, snapshot));
            } else {
              final index = snapshot.indexOf(action.text);
              end = index < 0 ? null : index + action.text.length;
            }
            if (end != null) {
              _output = _output.substring(end);
              break;
            }
            await wait(changed);
          }
        } finally {
          timer.cancel();
        }
      case SshAutomationType.sendText:
        _requireSession();
        _output = '';
        await _await(sendText(action.text), run);
      case SshAutomationType.sendKey:
        _requireSession();
        _output = '';
        await _await(sendKey(action.key, action.modifiers), run);
      case SshAutomationType.delay:
        if (action.duration <= Duration.zero) {
          throw SshAutomationError.actionFailed;
        }
        final elapsed = Completer<void>();
        final timer = Timer(action.duration, () => elapsed.complete());
        try {
          await _await(elapsed.future, run);
        } finally {
          timer.cancel();
        }
      case SshAutomationType.disconnect:
        await _await(disconnect(), run);
        return true;
      case SshAutomationType.enableForward:
      case SshAutomationType.disableForward:
        final id = action.forwardId;
        if (id == null) throw SshAutomationError.forwardMissing;
        await _await(
          setForward(id, action.type == SshAutomationType.enableForward),
          run,
        );
    }
    return false;
  }

  void _requireSession() {
    if (!sessionOpen()) throw SshAutomationError.noSession;
  }
}

enum _Escape { text, escape, csi, string, stringEscape, intermediate }

class _AutomationRun {
  final interrupted = Completer<SshAutomationError?>();
  SshAutomationError? _reason;
  void interrupt(SshAutomationError? reason) {
    if (!interrupted.isCompleted) {
      _reason = reason;
      interrupted.complete(reason);
    }
  }

  void check() {
    if (interrupted.isCompleted) throw _Interrupted(_reason);
  }
}

class _Interrupted implements Exception {
  const _Interrupted(this.reason);
  final SshAutomationError? reason;
}
