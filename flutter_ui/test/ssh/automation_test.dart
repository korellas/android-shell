// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:android_shell_ui/ssh/automation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SshAutomation runner;
  late List<Object> sent;
  setUp(() {
    sent = [];
    runner = SshAutomation(
      sessionOpen: () => true,
      sendText: (text) async => sent.add(text),
      sendKey: (key, modifiers) async => sent.add([key, modifiers]),
      setForward: (id, enabled) async => sent.add([id, enabled]),
      disconnect: () async => sent.add('disconnect'),
      matchRegexEnd: (expression, text) async =>
          RegExp(expression).firstMatch(text)?.end,
    );
  });

  test(
    'wait consumes output across ANSI/chunk boundaries and retains suffix',
    () async {
      runner.addOutput('\x1b[3');
      runner.addOutput('1mLogin:\x1b[0m\r');
      runner.addOutput('\nREADY 42');
      await runner.run([
        SshAutomationStep(
          type: SshAutomationType.waitForText,
          text: 'Login:\n',
        ),
        SshAutomationStep(
          type: SshAutomationType.waitForText,
          text: r'READY \d+',
          regex: true,
        ),
        SshAutomationStep(type: SshAutomationType.sendText, text: '한글\n'),
        SshAutomationStep(
          type: SshAutomationType.sendKey,
          key: 2,
          modifiers: 4,
        ),
        SshAutomationStep(type: SshAutomationType.enableForward, forwardId: 7),
        SshAutomationStep(type: SshAutomationType.disableForward, forwardId: 7),
      ]);
      expect(runner.state.completed, isTrue);
      expect(sent, [
        '한글\n',
        [2, 4],
        [7, true],
        [7, false],
      ]);
    },
  );

  test('sending clears stale output before a new wait', () async {
    runner.addOutput('READY');
    await runner.run([
      SshAutomationStep(type: SshAutomationType.sendText, text: 'next'),
      SshAutomationStep(
        type: SshAutomationType.waitForText,
        text: 'READY',
        duration: Duration(milliseconds: 10),
      ),
      SshAutomationStep(type: SshAutomationType.sendText, text: 'must not run'),
    ]);
    expect(sent, ['next']);
    expect(runner.state.error, SshAutomationError.timedOut);
    expect(runner.state.failedStep, 2);
  });

  test(
    'continue policy records failure and executes subsequent actions',
    () async {
      await runner.run([
        SshAutomationStep(
          type: SshAutomationType.waitForText,
          text: 'absent',
          duration: Duration(milliseconds: 10),
          continueOnFailure: true,
        ),
        SshAutomationStep(type: SshAutomationType.disconnect),
        SshAutomationStep(
          type: SshAutomationType.sendText,
          text: 'must not run',
        ),
      ]);
      expect(sent, ['disconnect']);
      expect(runner.state.completed, isTrue);
      expect(runner.state.error, SshAutomationError.timedOut);
    },
  );

  test(
    'cancel wakes a pending wait without disconnecting a trial session',
    () async {
      final run = runner.run([
        SshAutomationStep(type: SshAutomationType.waitForText, text: 'absent'),
        SshAutomationStep(type: SshAutomationType.disconnect),
      ]);
      runner.cancel();
      await run.timeout(Duration(seconds: 1));
      expect(runner.state.running, isFalse);
      expect(runner.state.completed, isFalse);
      expect(sent, isEmpty);
    },
  );

  test('bounded output fails even during a delay', () async {
    runner = SshAutomation(
      sessionOpen: () => true,
      sendText: (_) async {},
      sendKey: (_, _) async {},
      setForward: (_, _) async {},
      disconnect: () async {},
      outputCapacity: 8,
    );
    final run = runner.run([
      SshAutomationStep(
        type: SshAutomationType.delay,
        duration: Duration(seconds: 10),
      ),
    ]);
    runner.addOutput('123456789');
    await run.timeout(Duration(seconds: 1));
    expect(runner.state.error, SshAutomationError.bufferOverflow);
  });

  test('a cancelled asynchronous send cannot advance a later run', () async {
    final pending = Completer<void>();
    runner = SshAutomation(
      sessionOpen: () => true,
      sendText: (_) => pending.future,
      sendKey: (_, _) async {},
      setForward: (_, _) async {},
      disconnect: () async => sent.add('disconnect'),
    );
    final first = runner.run([
      SshAutomationStep(type: SshAutomationType.sendText, text: 'pending'),
      SshAutomationStep(type: SshAutomationType.disconnect),
    ]);
    runner.cancel();
    await first;
    await runner.run([
      SshAutomationStep(
        type: SshAutomationType.delay,
        duration: Duration(milliseconds: 1),
      ),
    ]);
    pending.complete();
    await Future<void>.delayed(Duration.zero);
    expect(sent, isEmpty);
    expect(runner.state.completed, isTrue);
  });

  test(
    'overflow during a synchronous send retains its failure reason',
    () async {
      runner = SshAutomation(
        sessionOpen: () => true,
        sendText: (_) async => runner.addOutput('123456789'),
        sendKey: (_, _) async {},
        setForward: (_, _) async {},
        disconnect: () async {},
        outputCapacity: 8,
      );
      await runner.run([SshAutomationStep(type: SshAutomationType.sendText)]);
      expect(runner.state.error, SshAutomationError.bufferOverflow);
    },
  );

  test('regex waits require the platform matcher explicitly', () async {
    runner = SshAutomation(
      sessionOpen: () => true,
      sendText: (_) async {},
      sendKey: (_, _) async {},
      setForward: (_, _) async {},
      disconnect: () async {},
    );
    await runner.run([
      SshAutomationStep(
        type: SshAutomationType.waitForText,
        text: 'prompt',
        regex: true,
      ),
    ]);
    expect(runner.state.error, SshAutomationError.regexUnavailable);
  });

  test(
    'a pending native regex match respects timeout and ignores late result',
    () async {
      final match = Completer<int?>();
      runner = SshAutomation(
        sessionOpen: () => true,
        sendText: (text) async => sent.add(text),
        sendKey: (_, _) async {},
        setForward: (_, _) async {},
        disconnect: () async {},
        matchRegexEnd: (_, _) => match.future,
      );
      await runner.run([
        SshAutomationStep(
          type: SshAutomationType.waitForText,
          text: 'prompt',
          regex: true,
          duration: Duration(milliseconds: 10),
        ),
        SshAutomationStep(
          type: SshAutomationType.sendText,
          text: 'must not run',
        ),
      ]);
      match.complete(0);
      await Future<void>.delayed(Duration.zero);
      expect(runner.state.error, SshAutomationError.timedOut);
      expect(sent, isEmpty);
    },
  );

  test('cancel from a progress callback prevents the announced send', () async {
    runner = SshAutomation(
      sessionOpen: () => true,
      sendText: (text) async => sent.add(text),
      sendKey: (_, _) async {},
      setForward: (_, _) async {},
      disconnect: () async {},
      onState: (state) {
        if (state.running && state.step == 1) runner.cancel();
      },
    );
    await runner.run([
      SshAutomationStep(type: SshAutomationType.sendText, text: 'must not run'),
    ]);
    expect(sent, isEmpty);
    expect(runner.state.completed, isFalse);
  });
}
