# Tilde Flutter UI

Flutter owns the screens, terminal rendering, SSH sessions and forwarding. `AndroidEngine` connects `AppSshSession` and `AppLocalSession` to the shared terminal. Android method/event channels provide persistence, protected-key signing, legacy text encodings, local PTYs and foreground notifications. `FlutterSessionRuntime` retains the Flutter engine across Activity recreation; the terminal uses Flutter widgets.

Install the Flutter SDK matching the pinned revision in
[CI](../.github/workflows/ci-build.yml). From the repository root:

```sh
./scripts/build-flutter.sh debug
```

This builds the Flutter AAR before the OSS host APK, so Dart edits are included. The script handles the versioning plugin's Git worktree limitation without modifying its configuration. The debug APK is produced under `app/build/outputs/apk/oss/debug/`.

The paired command also builds the generated iOS runner for iPhone and iPad without signing, under `flutter_ui/build/ios/iphoneos/Runner.app`. The paired command prepares the generated Xcode runner’s display name and app icon before compilation. Run it before opening `.ios/Runner.xcworkspace`; after regenerating `.ios`, run it again. Signing and iOS engine integration are required for device use. For an Android-only build, use `./scripts/build-flutter-android.sh debug`.

Use `release` to build the release AAR and host variant. Distribution still requires the existing release signing configuration.

The application ID is `dev.korellas.androidshell.flutter` with the existing debug suffix. It uses separate app storage and Android Keystore entries. New SSH keys are non-exportable P-256 keys generated in Android Keystore and require strong biometric authentication for every signing operation. Historical software-key rows remain visible only for inspection and deletion; they cannot authenticate or expose private material. Host configuration import/export excludes key bindings and executable behavior. The installed native application is not replaced.

Run UI checks in this directory with `flutter analyze` and `flutter test`. Run native checks using the host Gradle tasks. Physical keyboard, IME, biometric, network recovery, and background behavior require device validation.

See Flutter's [Android add-to-app documentation](https://docs.flutter.dev/add-to-app/android/project-setup) for AAR integration. The Android bridge currently has no iOS implementation.

## Design and navigation

The [Tilde design contract](../docs/design/tilde-design.md) and preserved
[offline guide](../docs/design/tilde-screen-guide.html) define the brand,
screens, colors, fonts, and save/cancel behavior. Saved connections remain the
home screen. Host import/export is under Settings → Security & backup; terminal
profiles are under Settings → Terminal. Editors stage changes behind a bottom
save bar. Settings apply immediately. Only SSH and Android local shells can start;
legacy Mosh, Telnet and SOCKS4 metadata may remain stored but is not executable.
Hardware mappings are visible with the actual connection state.

Diagnostic logs have a separate search/share screen. Port forwarding can target
a selected session, but forwards never start automatically and local/SOCKS listeners
bind only to loopback. The document's example renders use test fixtures and are
separate from device captures.
