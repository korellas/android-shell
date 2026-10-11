# AndroidShell Flutter UI

Flutter owns the management screens and navigation. The host application reuses the Android transport, terminal, persistence, key, and background-service implementations through method/event channels and a terminal PlatformView.

Install the Flutter SDK matching the pinned revision in
[CI](../.github/workflows/ci-build.yml). From the repository root:

```sh
./scripts/build-flutter-android.sh debug
```

This builds the Flutter AAR before the OSS host APK, so Dart edits are included. The script handles the versioning plugin's Git worktree limitation without modifying its configuration. The debug APK is produced under `app/build/outputs/apk/oss/debug/`.

Use `release` to build the release AAR and host variant. Distribution still requires the existing release signing configuration.

The application ID is `dev.korellas.androidshell.flutter` with the existing debug suffix. It uses separate app storage and Android Keystore entries. Host configuration import/export uses the native format; private keys are imported explicitly through key management. The installed native application is not replaced.

Run UI checks in this directory with `flutter analyze` and `flutter test`. Run native checks using the host Gradle tasks. Physical keyboard, IME, biometric, network recovery, and background behavior require device validation.

See Flutter's [Android add-to-app documentation](https://docs.flutter.dev/add-to-app/android/project-setup) for AAR integration. The Android bridge currently has no iOS implementation.

## Menu organization

Saved connections are the home screen. Host import/export share an entry;
terminal profiles are managed under Settings → Terminal. Secondary host and
terminal commands remain available under Additional actions. Hardware mappings,
advanced authentication, profile overrides, and diagnostic logs are collapsed.
SSH-only controls are shown for SSH and Mosh connections. This organization is a
baseline for further design work; it does not establish visual parity with the
native UI.

The settings layout follows the [Flutter design guide](../docs/design/flutter-settings.html),
based on the supplied review examples. Its rendered previews use sample data;
they are separate from device captures.
