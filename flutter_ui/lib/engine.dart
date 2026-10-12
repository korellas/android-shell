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
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef EngineRecord = Map<String, dynamic>;
EngineRecord row(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<EngineRecord> rows(Object? value) =>
    value is List ? value.map(row).toList() : [];

class AndroidEngine extends ChangeNotifier {
  static const channel = MethodChannel('dev.korellas.androidshell/engine');
  static const events = EventChannel('dev.korellas.androidshell/events');
  EngineRecord state = {};
  String? error;
  EngineRecord? sessionSwitch;
  EngineRecord? textInput;
  EngineRecord? notification;
  bool get isDisposed => _closed;
  StreamSubscription<dynamic>? _subscription;
  bool _refreshing = false;
  bool _again = false;
  bool _closed = false;
  List<EngineRecord> list(String key) => rows(state[key]);
  EngineRecord get preferences => row(state['preferences']);
  bool get ready => state['ready'] == true;
  Future<void> start() async {
    _subscription = events.receiveBroadcastStream().listen(
      (event) {
        final data = row(event);
        if (_closed) return;
        if (data['type'] == 'textInput') {
          textInput = data;
          notifyListeners();
        }
        if (data['type'] == 'switchSession') {
          sessionSwitch = data;
          notifyListeners();
        }
        if (data['type'] == 'message') {
          notification = data;
          notifyListeners();
        }
        refresh();
      },
      onError: (Object e) {
        if (_closed) return;
        error = '$e';
        notifyListeners();
      },
    );
    await refresh();
  }

  Future<void> refresh() async {
    if (_closed) return;
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _again = false;
        state = row(await channel.invokeMethod<Object?>('snapshot'));
        if (!_closed) notifyListeners();
      } while (_again && !_closed);
    } on PlatformException catch (e) {
      error = e.message ?? e.code;
      if (!_closed) notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  Future<dynamic> query(String method, [EngineRecord args = const {}]) async {
    try {
      return await channel.invokeMethod<dynamic>(method, args);
    } on PlatformException catch (e) {
      throw EngineException(e.message ?? e.code, details: e.toString());
    }
  }

  Future<dynamic> invoke(String method, [EngineRecord args = const {}]) async {
    try {
      final result = await channel.invokeMethod<dynamic>(method, args);
      await refresh();
      return result;
    } on PlatformException catch (e) {
      throw EngineException(e.message ?? e.code, details: e.toString());
    }
  }

  @override
  void dispose() {
    _closed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

class EngineException implements Exception {
  final String message;
  final String? details;
  const EngineException(this.message, {this.details});
  @override
  String toString() => message;
}
