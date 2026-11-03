// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:dartssh2/dartssh2.dart';

Future<ProcessResult> _queryOpenSsh(List<String> arguments) async {
  final process = await Process.start('ssh.exe', arguments);
  await process.stdin.close();
  try {
    final result = await Future.wait<Object>([
      process.stdout.transform(utf8.decoder).join(),
      process.stderr.transform(utf8.decoder).join(),
      process.exitCode,
    ]).timeout(const Duration(seconds: 10));
    return ProcessResult(process.pid, result[2] as int, result[0], result[1]);
  } on TimeoutException {
    process.kill();
    throw StateError('Windows SSH 설정 조회 시간이 초과됐습니다.');
  }
}

Future<List<SSHIdentity>> loadWindowsSystemKeys(
  Map<String, dynamic> config,
  Future<String> Function(String path) askPassphrase, {
  Future<ProcessResult> Function(List<String> arguments)? query,
  Map<String, String>? environment,
}) async {
  final host = config['host'] as Map;
  if (host['useKeys'] == false || (host['pubkeyId'] ?? -1) != -1) return [];
  final target = host['hostname'] as String;
  final arguments = ['-G', '-T', '-p', '${host['port'] ?? 22}'];
  if ('${host['username'] ?? ''}'.isNotEmpty) {
    arguments.addAll(['-l', host['username'] as String]);
  }
  arguments.addAll(['--', target]);
  ProcessResult result;
  try {
    result = await (query ?? _queryOpenSsh)(arguments);
  } on ProcessException catch (error) {
    if (error.errorCode == 2) return [];
    rethrow;
  }
  if (result.exitCode != 0) {
    throw StateError('Windows SSH 설정을 읽지 못했습니다. ${result.stderr}');
  }
  final options = <String, String>{};
  final paths = <String>[];
  for (final line in const LineSplitter().convert(result.stdout as String)) {
    final separator = line.indexOf(' ');
    if (separator < 0) continue;
    final name = line.substring(0, separator);
    final value = line.substring(separator + 1).trim();
    if (name == 'identityfile') {
      if (value != 'none') paths.add(value);
    } else {
      options[name] = value;
    }
  }
  final env = environment ?? Platform.environment;
  final profile = env['USERPROFILE'];
  final tokens = <String, String>{
    '%': '%',
    'd': ?profile,
    'h': options['hostname'] ?? target,
    'n': target,
    'r': options['user'] ?? '${host['username'] ?? ''}',
    'p': options['port'] ?? '${host['port'] ?? 22}',
    if (env['USERNAME'] != null) 'u': env['USERNAME']!,
    'l': Platform.localHostname,
    'L': Platform.localHostname.split('.').first,
  };
  final seen = <String>{};
  String canonical(String value) =>
      Platform.isWindows ? value.toLowerCase() : value;
  for (final key in config['keys'] as List? ?? const []) {
    if (key['path'] case final String path) {
      if (await File(path).exists()) {
        seen.add(canonical(await File(path).resolveSymbolicLinks()));
      }
    }
  }
  final identities = <SSHIdentity>[];
  for (var path in paths) {
    if (path.startsWith('"') && path.endsWith('"')) {
      path = path.substring(1, path.length - 1);
    }
    if (path.startsWith('~/') || path.startsWith(r'~\')) {
      if (profile == null) throw StateError('Windows 사용자 프로필 경로가 없습니다.');
      path = '$profile${path.substring(1)}';
    }
    path = path.replaceAllMapped(RegExp(r'%(.)'), (match) {
      final value = tokens[match[1]];
      if (value == null) {
        throw UnsupportedError('지원하지 않는 SSH 키 경로 변수: ${match[0]}');
      }
      return value;
    });
    final file = File(path);
    if (!await file.exists()) continue;
    final resolved = await file.resolveSymbolicLinks();
    if (!seen.add(canonical(resolved))) continue;
    final pem = await file.readAsString();
    final encrypted = await Isolate.run(() => SSHKeyPair.isEncryptedPem(pem));
    final password = encrypted ? await askPassphrase(resolved) : null;
    identities.addAll(
      await Isolate.run(() => SSHKeyPair.fromPem(pem, password)),
    );
  }
  return identities;
}
