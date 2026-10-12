# Tilde Flutter UI

Flutter owns the management screens and navigation. The host application reuses the Android transport, terminal, persistence, key, and background-service implementations through method/event channels and a terminal PlatformView.

Install the Flutter SDK matching the pinned revision in
[CI](../.github/workflows/ci-build.yml). From the repository root:

```sh
./scripts/build-flutter.sh debug
```

This builds the Flutter AAR before the OSS host APK, so Dart edits are included. The script handles the versioning plugin's Git worktree limitation without modifying its configuration. The debug APK is produced under `app/build/outputs/apk/oss/debug/`.

The paired command also builds the generated iOS runner for iPhone and iPad without signing, under `flutter_ui/build/ios/iphoneos/Runner.app`. The paired command prepares the generated Xcode runner’s display name and app icon before compilation. Run it before opening `.ios/Runner.xcworkspace`; after regenerating `.ios`, run it again. Signing and iOS engine integration are required for device use. For an Android-only build, use `./scripts/build-flutter-android.sh debug`.

Use `release` to build the release AAR and host variant. Distribution still requires the existing release signing configuration.

The application ID is `dev.korellas.androidshell.flutter` with the existing debug suffix. It uses separate app storage and Android Keystore entries. Host configuration import/export uses the native format; private keys are imported explicitly through key management. The installed native application is not replaced.

Run UI checks in this directory with `flutter analyze` and `flutter test`. Run native checks using the host Gradle tasks. Physical keyboard, IME, biometric, network recovery, and background behavior require device validation.

See Flutter's [Android add-to-app documentation](https://docs.flutter.dev/add-to-app/android/project-setup) for AAR integration. The Android bridge currently has no iOS implementation.

## Design and navigation

The [Tilde design contract](../docs/design/tilde-design.md) and preserved
[offline guide](../docs/design/tilde-screen-guide.html) define the brand,
screens, colors, fonts, and save/cancel behavior. Saved connections remain the
home screen. Host import/export is under Settings → Security & backup; terminal
profiles are under Settings → Terminal. Editors stage changes behind a bottom
save bar. Settings apply immediately. SSH and Mosh retain their protocol-specific
controls. Hardware mappings are visible with the actual connection state.

Diagnostic logs have a separate search/share screen. Port forwarding can target
a selected session, and automation trials open a separate session using the
staged steps. The document's example renders use test fixtures and are separate
from device captures.
