# Tilde Flutter UI

Flutter owns the screens, terminal rendering, SSH sessions and forwarding. `AndroidEngine` connects `AppSshSession` and `AppLocalSession` to the shared terminal. Android method/event channels provide persistence, protected-key signing, legacy text encodings, local PTYs and foreground notifications. `FlutterSessionRuntime` retains the Flutter engine across Activity recreation; the terminal uses Flutter widgets.

Install the Flutter SDK matching the pinned revision in
[CI](../.github/workflows/ci-build.yml). From the repository root:

```sh
./scripts/build-flutter.sh debug
```

This builds the Flutter AAR before the OSS host APK, so Dart edits are included. The script handles the versioning plugin's Git worktree limitation without modifying its configuration. The debug APK is produced under `app/build/outputs/apk/oss/debug/`.

The paired command also builds the generated iOS runner for iPhone and iPad without signing, under `flutter_ui/build/ios/iphoneos/Runner.app`. It prepares the native iOS channel, display name and app icon before compilation. Run it before opening `.ios/Runner.xcworkspace`; after regenerating `.ios`, run it again. Physical devices require signing. For an Android-only build, use `./scripts/build-flutter-android.sh debug`.

After the paired build, use `flutter devices` and `flutter run -d <simulator-id>` from this directory to run on a booted iPad simulator. A physical iPad and developer account are not required for simulator development. iOS uses the shared host storage and SSH engine, protects saved credentials with a Keychain-held encryption key, and imports private keys through the system document picker into protected app storage. Android local shells and Android Keystore key generation remain Android-specific.

Use `release` to build the release AAR and host variant. Distribution still requires the existing release signing configuration.

The application ID is `dev.korellas.androidshell.flutter` with the existing debug suffix. It uses separate app storage and Android Keystore entries. New SSH keys are non-exportable P-256 keys generated in Android Keystore and require strong biometric authentication for every signing operation. Historical software-key rows remain visible only for inspection and deletion; they cannot authenticate or expose private material. Host configuration import/export excludes key bindings and executable behavior. The installed native application is not replaced.

Run UI checks in this directory with `flutter analyze` and `flutter test`. Run native checks using the host Gradle tasks. Physical keyboard, IME, biometric, network recovery, and background behavior require device validation.

See Flutter's [Android add-to-app documentation](https://docs.flutter.dev/add-to-app/android/project-setup) for AAR integration.

## Design and navigation

The [Tilde design contract](../docs/design/tilde-design.md) and preserved
[offline guide](../docs/design/tilde-screen-guide.html) define the brand,
screens, colors, fonts, and save/cancel behavior. Saved connections remain the
home screen. Host import/export is under Settings → Security & backup; terminal
profiles are under Settings → Terminal. Editors stage changes behind a bottom
save bar. Settings apply immediately. Only SSH and Android local shells can start;
legacy Mosh, Telnet and SOCKS4 metadata may remain stored but is not executable.
Hardware mappings are visible with the actual connection state.

Saved SSH hosts offer a terminal or a file browser. The file browser uses the
host's configured authentication and host-key checks, opens SFTP without a
terminal, and closes its own connection when leaving. Uploads and downloads use
the system document picker; uploads ask before replacing a remote file.

Diagnostic logs have a separate search/share screen. Port forwarding can target
a selected session, but forwards never start automatically and local/SOCKS listeners
bind only to loopback. The document's example renders use test fixtures and are
separate from device captures.
