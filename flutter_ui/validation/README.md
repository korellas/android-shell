# Shared SSH and terminal validation

The shared application dependencies are pinned in `../pubspec.yaml` and `../pubspec.lock`. The shared terminal and SSH kernel use xterm2 and dartssh2 as application dependencies. The xterm2 Git revision pins the proposed paint extension while its upstream PR is reviewed. The application entry point remains `lib/main.dart`.

The agreed migration targets SSH on Android first. SOCKS4 and Telnet are excluded, the local shell remains Android-specific, and iOS platform work is deferred. Mosh and advertising are outside this stage.

## Run

From `flutter_ui`:

```sh
flutter analyze
flutter test
python3 validation/run_ssh_tests.py
flutter test validation/ssh_probe_test.dart
flutter test validation/terminal_compatibility_test.dart
flutter build apk --debug --target=validation/ssh_probe.dart
```

The OpenSSH runner requires a Unix account, OpenSSH server/client tools and Flutter. It generates temporary host/client keys, binds its disposable server to `0.0.0.0`, and forces every connection through a restricted test process. It does not change system SSH configuration or authorized keys. The runner stops the server in a finally block and cleans its temporary directory on normal completion or a reported test failure. Do not run it as root.

The protocol tests cover pinned host verification, rejection before authentication/execution, public-key authentication, asynchronous external signing, PTY dimensions, ordered UTF-8 input, forwarding, hop chains, compression and reconnects. They exercise both `SshSession` and the application `AppSshSession` adapter. The external signer test uses a software test key; it does not prove Android Keystore or biometric integration. Password and keyboard-interactive authentication still require separate validation.

## Probe and acceptance boundary

The separate probe entry point renders `TerminalPane` without the Android engine channel. The pane connects the application IME adapter, selection editor and keyboard bar to xterm2. It uses the shared `SshSession` kernel. Its connection form accepts a password and a previously verified SHA256 server-key fingerprint. It does not persist credentials or host trust. It exposes package license notices through its information button.

`terminal_compatibility_test.dart` is an explicit migration acceptance suite, alongside the application tests. A failure blocks accepting a terminal dependency update. Do not replace its expected input order with the candidate's current behavior or skip a failing case.

The committed-prefix and composing-special-key tests exercise the application input adapter. Special keys and paste must use `TerminalInputController` so pending composition precedes their output; calling the underlying terminal directly bypasses that ordering. The adapter reuses the pinned xterm2 key-map helper for modifier encoding, so library upgrades require the input regression tests.

The widget tests cover selection editing, touch handles, keybar layout and composition ordering. Image tests cover bounded uploads, consent, placements, frame commands and rendered pixels. Android codec tests exercise non-UTF-8 streaming independently of a live session; they do not establish full application parity. Android device IME behavior must be checked separately from widget tests and APK compilation.

## Platform and image boundaries

Preserve the Android application identity and existing Keystore references when changing platform storage. iOS compilation does not verify an iOS platform bridge.

`InlineImageRuntime` follows terminal edit handlers and cell anchors; direct buffer mutation and rectangle copying require separate image-edit coverage. `InlineImageDecoder` budgets full-resolution surfaces and rejects working sets beyond its memory limits rather than silently allocating them. Its pixel tests do not establish parity for every native terminal operation.
