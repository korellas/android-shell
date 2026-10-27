// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
import 'dart:convert';
import 'ssh_session.dart';

String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

/// The native enrollment script, preserving its symlink and duplicate checks.
const enrollmentInstallScript = r'''cd || exit 1
umask 077
directory=.ssh
file=.ssh/authorized_keys
if [ -L "$directory" ] || [ -L "$file" ]; then
    printf '%s\n' 'Refusing a symlink in the SSH key path.' >&2
    exit 1
fi
if { [ -e "$directory" ] && [ ! -d "$directory" ]; } ||
   { [ -e "$file" ] && [ ! -f "$file" ]; }; then
    printf '%s\n' 'The SSH key path is not a regular directory and file.' >&2
    exit 1
fi
IFS= read -r key || exit 1
IFS=' ' read -r kind blob comment <<KEY
$key
KEY
[ -n "$kind" ] && [ -n "$blob" ] || exit 1
mkdir -p "$directory" &&
touch "$file" &&
chmod 700 "$directory" && chmod 600 "$file" || exit 1
awk -v kind="$kind" -v blob="$blob" '
    /^[[:space:]]*#/ { next }
    { for (i = 1; i < NF; i++) if ($i == kind && $(i + 1) == blob) found = 1 }
    END { exit !found }
' "$file"
case $? in
    0) printf '%s\n' ALREADY_PRESENT; exit 0 ;;
    1) ;;
    *) printf '%s\n' 'Could not check existing SSH keys.' >&2; exit 1 ;;
esac
if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
    printf '\n' >> "$file" || exit 1
fi
printf '%s\n' "$key" >> "$file" || exit 1
if command -v restorecon >/dev/null 2>&1; then
    restorecon "$directory" "$file" >/dev/null 2>&1 || :
fi
printf '%s\n' ADDED''';

Future<String> registerEnrollmentPublicKey(
  Future<SshCommandResult> Function(String command) execute,
  String publicKey,
) async {
  if (publicKey.contains('\n') ||
      publicKey.contains('\r') ||
      publicKey.trim().isEmpty) {
    throw const FormatException('Invalid SSH public-key line');
  }
  final command =
      "printf '%s\\n' ${_quote(publicKey)} | sh -c ${_quote(enrollmentInstallScript)}";
  final result = await execute(command);
  final output = utf8
      .decode(result.stdout.take(4096).toList(), allowMalformed: true)
      .trim();
  final error = utf8
      .decode(result.stderr.take(4096).toList(), allowMalformed: true)
      .trim();
  if (result.exitCode != 0) {
    throw StateError(
      error.isEmpty ? 'Server did not confirm public-key registration.' : error,
    );
  }
  final status = output.split('\n').last;
  if (status != 'ADDED' && status != 'ALREADY_PRESENT') {
    throw StateError('Server did not confirm public-key registration.');
  }
  return status;
}

class SshEnrollmentController {
  SshEnrollmentController({
    required this.onChanged,
    required this.keys,
    required this.biometricAvailable,
    required this.createBiometricKey,
    required this.readHost,
    required this.saveHost,
  });
  final void Function() onChanged;
  final List<Map<String, dynamic>> Function() keys;
  final bool Function() biometricAvailable;
  final Future<Map<String, dynamic>> Function(String name) createBiometricKey;
  final Future<Map<String, dynamic>?> Function(int id) readHost;
  final Future<void> Function(Map<String, dynamic> host) saveHost;
  Map<String, dynamic> _state = {'stage': 'IDLE'};
  bool get busy =>
      const ['REGISTERING', 'VERIFYING', 'APPLYING'].contains(_state['stage']);
  Map<String, dynamic> get state => {
    ..._state,
    'busy': busy,
    'biometricAvailable': biometricAvailable(),
  };
  void _update(Map<String, dynamic> value) {
    _state = {..._state, ...value};
    onChanged();
  }

  void begin(String name) {
    if (busy) return;
    _state = {
      'stage': 'IDLE',
      'newKeyName': name,
      'selectedKeyId': biometricAvailable() ? null : keys().firstOrNull?['id'],
    };
    onChanged();
  }

  Future<void> enroll({
    required Map<String, dynamic> originalHost,
    required bool Function() canEnroll,
    required Future<String> Function(int keyId) register,
    required Future<String> Function(int keyId) verify,
    required String username,
    int? keyId,
    String name = '',
  }) async {
    if (busy || _state['stage'] == 'SUCCESS') return;
    final original = Map<String, dynamic>.from(originalHost);
    if (!canEnroll() || (original['id'] as int? ?? 0) <= 0) {
      throw StateError('Log in to a saved SSH host before registering a key.');
    }
    _update({
      'stage': 'REGISTERING',
      'hostId': original['id'],
      'registration': null,
      'verification': null,
      'error': null,
    });
    try {
      Map<String, dynamic>? key;
      if (keyId != null) {
        key = keys().where((key) => key['id'] == keyId).firstOrNull;
        if (key == null) {
          throw StateError('The selected SSH key no longer exists.');
        }
      } else {
        final trimmed = name.trim();
        if (!biometricAvailable() ||
            trimmed.isEmpty ||
            keys().any((key) => key['nickname'] == trimmed)) {
          throw StateError('A unique biometric key name is required.');
        }
        key = await createBiometricKey(trimmed);
      }
      final selected = key['id'] as int;
      _update({'selectedKeyId': selected});
      if (!canEnroll()) {
        throw StateError(
          'The original SSH connection is no longer authenticated.',
        );
      }
      final registration = await register(selected);
      if (!canEnroll()) {
        throw StateError(
          'The original SSH connection is no longer authenticated.',
        );
      }
      _update({'stage': 'VERIFYING', 'registration': registration});
      final verification = await verify(selected);
      if (!canEnroll()) {
        throw StateError(
          'The original SSH connection is no longer authenticated.',
        );
      }
      _update({'verification': verification});
      if (verification != 'VERIFIED') {
        _update({
          'stage': 'FAILED',
          if (verification == 'INDETERMINATE')
            'error':
                'Key-only login was not completed. The server may require additional authentication. Login settings were not changed.',
        });
        return;
      }
      _update({'stage': 'APPLYING'});
      if (!canEnroll()) {
        throw StateError(
          'The original SSH connection is no longer authenticated.',
        );
      }
      final fresh = await readHost(original['id'] as int);
      if (!canEnroll()) {
        throw StateError(
          'The original SSH connection is no longer authenticated.',
        );
      }
      if (fresh == null) throw StateError('The saved host no longer exists.');
      if (fresh['hostname'] != original['hostname'] ||
          fresh['port'] != original['port'] ||
          fresh['jumpHostId'] != original['jumpHostId']) {
        throw StateError(
          'The host address changed during registration. Its login settings were not changed.',
        );
      }
      await saveHost({
        ...fresh,
        'pubkeyId': selected,
        'identityId': null,
        'username': username,
      });
      _update({'stage': 'SUCCESS'});
    } catch (error) {
      _update({'stage': 'FAILED', 'error': '$error'});
    }
  }
}
