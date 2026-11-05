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

The application ID is `dev.korellas.androidshell.flutter` with the existing debug suffix. New Android credentials offer a standard SSH key or an SSH login password protected with a passkey. Credential Manager retains the passkey; the app stores the SSH private key or password only as ciphertext. Existing Android Keystore keys, direct WebAuthn references and saved device passwords are deprecated and retained for transition. Historical software-key rows remain quarantined. Host configuration import/export excludes key bindings and executable behavior.

Android credential creation requires PRF support from the passkey provider and the platform support checked by `AndroidPasskeys.available`. The relying-party domain is owned by `PASSKEY_RP_ID`; its Digital Asset Links file must authorize the installed package and signing certificate. PRF and HKDF derive the AES-GCM encryption key locally. SSH key authentication uses standard P-256 signatures and does not require enabling a WebAuthn-specific SSH algorithm. Only public keys and signatures cross into Flutter for this mode.

Password credentials are bound to a server, port and account. Unlock happens after host-key verification and only for the SSH password method; hidden keyboard-interactive questions are not autofilled with these credentials. Explicit passkey key or password selection does not fall back to another authentication method. Passwords must briefly enter the Flutter SSH library as strings and are delivered to the server inside SSH transport encryption. They are not retained in prepared session state. This cannot guarantee complete erasure of runtime copies.

Save an encrypted credential file from the SSH key menu before reinstalling or switching devices. It contains ciphertext and public metadata; recovery requires the file and access to the matching PRF-capable passkey. Restore verifies decryption before saving. Losing the passkey cannot be repaired from ciphertext alone. Historical public connection files still restore direct WebAuthn references. Removing a credential in Tilde leaves the provider's passkey intact. iOS passkey creation and encrypted credential restoration are not enabled by this Android integration.

The decryption test in Android SSH key management checks PRF support separately from SSH authentication. Create a test file, open it on the same device, then open it in Tilde on another Android device with access to the same passkey. The native implementation uses PRF, HKDF-SHA256 and AES-GCM to encrypt a fixed test message; Flutter receives only the result. The file contains credential metadata and ciphertext. This experiment does not register an SSH key or change host authentication. Temporary byte arrays are cleared after use, but Credential Manager JSON and cryptographic provider internals prevent a guarantee that every memory copy is erased. Test credentials remain in the credential provider until removed there.

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
