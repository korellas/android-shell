// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Reuse the pinned xterm2 key map so IME chords use its keyboard protocols.
// ignore: implementation_imports
import 'package:xterm2/src/ui/input_map.dart';
import 'package:xterm2/xterm.dart';

class TerminalInputController extends ChangeNotifier with TextInputClient {
  TerminalInputController({required this.terminal});

  final Terminal terminal;

  // The spaces give Android IMEs a character to delete at an empty prompt.
  static const _initialValue = TextEditingValue(
    text: '  ',
    selection: TextSelection.collapsed(offset: 2),
  );

  TextEditingValue _value = _initialValue;
  String _committed = '';
  String _composingText = '';
  FocusNode? _focusNode;
  TextInputConnection? _connection;
  int? _viewId;
  bool _enabled = true;
  bool _showSoftKeyboard = true;
  bool _disposed = false;
  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;
  Object? _pasteGuardOwner;
  Future<bool> Function(String text)? _pasteGuard;
  String stickyModifiers = 'no';
  final _hardwareModifiers = <PhysicalKeyboardKey, (bool, bool, bool)>{};
  bool get ctrl => _ctrl;
  bool get alt => _alt;
  bool get shift => _shift;

  void _consumeModifiers() {
    final ctrl = stickyModifiers == 'yes' && _ctrl;
    final alt = (stickyModifiers == 'yes' || stickyModifiers == 'alt') && _alt;
    if (ctrl == _ctrl && alt == _alt && !_shift) return;
    _ctrl = ctrl;
    _alt = alt;
    _shift = false;
    notifyListeners();
  }

  String get composingText => _composingText;

  bool get _canSend => _enabled && !_disposed;

  bool get _connected => _connection?.attached == true;

  void attachView({
    required FocusNode focusNode,
    required int viewId,
    required bool enabled,
    required bool showSoftKeyboard,
  }) {
    if (_disposed) return;
    final changed =
        _focusNode != focusNode ||
        _viewId != viewId ||
        _enabled != enabled ||
        _showSoftKeyboard != showSoftKeyboard;
    if (!changed) return;
    _focusNode?.removeListener(_focusChanged);
    _closeConnection();
    _reset();
    _focusNode = focusNode;
    _viewId = viewId;
    _enabled = enabled;
    if (!enabled) _hardwareModifiers.clear();
    _showSoftKeyboard = showSoftKeyboard;
    focusNode.addListener(_focusChanged);
    if (focusNode.hasFocus) _openConnection();
  }

  void detachView() {
    _hardwareModifiers.clear();
    _focusNode?.removeListener(_focusChanged);
    _focusNode = null;
    _closeConnection();
    _reset();
  }

  void sendKey(
    TerminalKey key, {
    bool ctrl = false,
    bool alt = false,
    bool shift = false,
  }) {
    if (!_canSend) return;
    finishComposition();
    terminal.keyInput(
      key,
      ctrl: ctrl || _ctrl,
      alt: alt || _alt,
      shift: shift || _shift,
    );
    _consumeModifiers();
  }

  void setModifiers({bool ctrl = false, bool alt = false, bool shift = false}) {
    if (!_canSend) return;
    if (_ctrl == ctrl && _alt == alt && _shift == shift) return;
    finishComposition();
    _ctrl = ctrl;
    _alt = alt;
    _shift = shift;
    notifyListeners();
  }

  void sendText(String text) {
    if (!_canSend) return;
    finishComposition();
    _emitText(text);
  }

  void paste(String text) {
    if (!_canSend) return;
    finishComposition();
    if (!requiresPasteConfirmation(text)) {
      terminal.paste(text);
      return;
    }
    final guard = _pasteGuard;
    if (guard == null) return;
    unawaited(_pasteAfterConfirmation(text, guard));
  }

  void pasteConfirmed(String text) {
    if (!_canSend) return;
    finishComposition();
    terminal.paste(text);
  }

  void installPasteGuard(
    Object owner,
    Future<bool> Function(String text) guard,
  ) {
    _pasteGuardOwner = owner;
    _pasteGuard = guard;
  }

  void removePasteGuard(Object owner) {
    if (!identical(_pasteGuardOwner, owner)) return;
    _pasteGuardOwner = null;
    _pasteGuard = null;
  }

  Future<void> _pasteAfterConfirmation(
    String text,
    Future<bool> Function(String text) guard,
  ) async {
    if (!await guard(text) || !_canSend || !identical(_pasteGuard, guard)) {
      return;
    }
    terminal.paste(text);
  }

  void finishComposition() {
    if (!_canSend) return;
    if (_value == _initialValue) return;
    final connected = _connected;
    _sendCommitted(_textAfterSentinel(_value.text));
    _closeConnection();
    _reset();
    // A fresh client ID rejects delayed updates from the old composition.
    if (connected) _openConnection();
  }

  void requestKeyboard() {
    if (!_canSend) return;
    _focusNode?.requestFocus();
    _openConnection();
  }

  void closeKeyboard() {
    if (_disposed) return;
    finishComposition();
    _closeConnection();
    _reset();
  }

  void _focusChanged() {
    if (_focusNode?.hasFocus == true) {
      _openConnection();
    } else {
      closeKeyboard();
    }
  }

  void _openConnection() {
    if (!_canSend ||
        !_showSoftKeyboard ||
        _focusNode?.hasFocus != true ||
        _viewId == null) {
      return;
    }
    if (!_connected) {
      _connection = TextInput.attach(
        this,
        TextInputConfiguration(
          viewId: _viewId,
          inputType: TextInputType.multiline,
          inputAction: TextInputAction.newline,
          keyboardAppearance: Brightness.dark,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
        ),
      );
      _connection!.setEditingState(_value);
    }
    _connection!.show();
  }

  void _closeConnection() {
    if (_connected) _connection!.close();
    _connection = null;
  }

  void _reset() {
    _value = _initialValue;
    _committed = '';
    _setComposing('');
    if (_connected) _connection!.setEditingState(_value);
  }

  void _setComposing(String text) {
    if (_composingText == text) return;
    _composingText = text;
    if (!_disposed) notifyListeners();
  }

  String _textAfterSentinel(String text) =>
      text.length < _initialValue.text.length
      ? ''
      : text.substring(_initialValue.text.length);

  @override
  TextEditingValue get currentTextEditingValue => _value;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    if (!_canSend || !_connected) return;
    final wasComposing = _composingText.isNotEmpty;
    _value = value;
    final range = value.composing;
    if (range.isValid &&
        !range.isCollapsed &&
        range.start >= _initialValue.text.length &&
        range.end <= value.text.length) {
      final prefixEnd = range.start.clamp(
        _initialValue.text.length,
        value.text.length,
      );
      _sendCommitted(
        value.text.substring(_initialValue.text.length, prefixEnd),
      );
      _setComposing(range.textInside(value.text));
      return;
    }

    final text = _textAfterSentinel(value.text);
    // An IME can clear its entire buffer when canceling local preedit.
    // Retraction of committed text is handled by an explicit composing range.
    if (text.isNotEmpty) _sendCommitted(text);
    if (!wasComposing &&
        value.text.length < _initialValue.text.length &&
        _committed.isEmpty) {
      terminal.keyInput(TerminalKey.backspace);
    }
    _reset();
  }

  void _sendCommitted(String text) {
    final previous = _committed.characters.toList();
    final next = text.characters.toList();
    var common = 0;
    while (common < previous.length &&
        common < next.length &&
        previous[common] == next[common]) {
      common++;
    }
    for (var index = common; index < previous.length; index++) {
      terminal.keyInput(TerminalKey.backspace);
    }
    final inserted = next.skip(common).join();
    if (inserted.isNotEmpty) {
      if (requiresPasteConfirmation(inserted)) {
        final guard = _pasteGuard;
        if (guard != null) {
          unawaited(_pasteAfterConfirmation(inserted, guard));
        }
      } else {
        _emitText(inserted);
      }
    }
    _committed = text;
  }

  void _emitText(String text) {
    if (!_ctrl && !_alt && !_shift) {
      terminal.textInput(text);
      return;
    }
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      final key = charToTerminalKey(character) ?? TerminalKey.none;
      final consumed = terminal.keyInput(
        key,
        text: character,
        ctrl: _ctrl,
        alt: _alt,
        shift: _shift,
      );
      if (!consumed) terminal.textInput(character);
      _consumeModifiers();
    }
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_canSend) return KeyEventResult.handled;
    final held = _hardwareModifiers[event.physicalKey];
    if (event is KeyUpEvent && held == null) return KeyEventResult.ignored;
    final synonyms = LogicalKeyboardKey.collapseSynonyms({event.logicalKey});
    if (synonyms.any(
      const [
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.alt,
        LogicalKeyboardKey.shift,
        LogicalKeyboardKey.meta,
        LogicalKeyboardKey.altGraph,
      ].contains,
    )) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final modified =
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed;
    final character =
        event.character ??
        (event.logicalKey.keyLabel.runes.length == 1
            ? event.logicalKey.keyLabel
            : null);
    final printable =
        character != null &&
        character.isNotEmpty &&
        character.runes.every((rune) => rune >= 0x20 && rune != 0x7f);
    if (_connected && held == null && !modified && printable) {
      // Let the platform IME deliver text exactly once, including preedit.
      return KeyEventResult.skipRemainingHandlers;
    }
    if (event is! KeyUpEvent) finishComposition();
    final modifiers = held ?? (_ctrl, _alt, _shift);
    if (held != null || modifiers.$1 || modifiers.$2 || modifiers.$3) {
      if (event is KeyUpEvent) {
        _hardwareModifiers.remove(event.physicalKey);
      } else {
        _hardwareModifiers[event.physicalKey] = modifiers;
      }
      final key = keyToTerminalKey(event.logicalKey) ?? TerminalKey.none;
      final consumed = terminal.keyInput(
        key,
        text: event is KeyUpEvent ? null : character,
        ctrl: modifiers.$1 || keyboard.isControlPressed,
        alt: modifiers.$2 || keyboard.isAltPressed,
        shift: modifiers.$3 || keyboard.isShiftPressed,
        superKey: keyboard.isMetaPressed,
        capsLock: keyboard.lockModesEnabled.contains(KeyboardLockMode.capsLock),
        numLock: keyboard.lockModesEnabled.contains(KeyboardLockMode.numLock),
        type: switch (event) {
          KeyUpEvent() => TerminalKeyEventType.release,
          KeyRepeatEvent() => TerminalKeyEventType.repeat,
          _ => TerminalKeyEventType.press,
        },
      );
      if (!consumed && printable && event is! KeyUpEvent) {
        terminal.textInput(character);
      }
      if (event is KeyDownEvent) _consumeModifiers();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void setEditableGeometry(Size size, Matrix4 transform, Rect caret) {
    if (!_connected) return;
    _connection!.setEditableSizeAndTransform(size, transform);
    _connection!.setCaretRect(caret);
  }

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline || action == TextInputAction.done) {
      sendKey(TerminalKey.enter);
    }
  }

  @override
  void connectionClosed() {
    if (_disposed) return;
    if (_canSend) _sendCommitted(_textAfterSentinel(_value.text));
    _connection = null;
    _reset();
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    detachView();
    super.dispose();
  }
}

bool requiresPasteConfirmation(String text) =>
    text.codeUnits.any((unit) => unit == 0x7f || unit < 0x20);
