# Tilde

A Flutter SSH terminal client with shared Dart sessions and rendering, and Android platform services.
The Android data and platform code derives from [ConnectBot](https://github.com/connectbot/connectbot).
This is an independent fork, not an official ConnectBot release.

## Build

Open the project in Android Studio and configure the Android SDK, or set
`sdk.dir` in a local, untracked `local.properties` file. Java compatibility
is configured in [app/build.gradle.kts](app/build.gradle.kts).

Install Flutter matching the revision in [the CI workflow](.github/workflows/ci-build.yml),
and build the Android host and unsigned iPad-compatible iOS app together on macOS:

```sh
./scripts/build-flutter.sh debug
```

The APK is written to `app/build/outputs/apk/oss/debug/app-oss-debug.apk`.

See [Flutter build and validation](flutter_ui/README.md) for module checks and
release builds. The platform bridge supports Android; iPad
device installation and functional verification require iOS platform integration.

For local native verification:

```sh
./gradlew :app:testOssDebugUnitTest
./gradlew :app:lintOssDebug spotlessCheck
```

## Design

[Tilde design contract](docs/design/tilde-design.md) records the supplied
[offline screen guide](docs/design/tilde-screen-guide.html), brand, interaction
rules, and platform-specific interpretation. Existing app and storage identifiers
are retained when changing the display name.

## SSH key setup

Manage keys under **Settings → Security & backup → SSH keys**. To register a key,
open **Register a key on this server** in a connected SSH terminal. Log in with
an existing method, then explicitly register a new fingerprint-protected key or an existing SSH key. Registration
appends to the account's `~/.ssh/authorized_keys`, preserving existing keys and
their restrictions. A separate key-only connection must succeed before the
selected host's login settings change. Password login and shared accounts are
not changed. Servers using a custom authorized-key location require manual setup.

New fingerprint keys authorize each SSH signing operation through Android
Keystore and the system biometric prompt. Existing time-based keys remain
compatible. Device-local private keys cannot be exported or restored to another
phone; keep another working key or login method. If registration or verification
fails, a public key may already have been added to the server. DSA authentication
is unsupported; existing stored key records are preserved.

## Upstream and licenses

The original ConnectBot history, copyright notices and [LICENSE](LICENSE)
are preserved. SSH uses the [app-local dartssh2 copy](flutter_ui/third_party/dartssh2/LOCAL_CHANGES.md);
rendering uses the xterm2 revision pinned in `flutter_ui/pubspec.yaml`. The generic
render hooks and authentication policy were submitted as
[xterm2 PR #3](https://github.com/SoFluffyOS/xterm2/pull/3) and
[dartssh2 PR #251](https://github.com/vicajilau/dartssh2/pull/251). Compression stays local.
Dependencies retain their own licenses, available through the help screen.
The retired native Compose UI and terminal module are removed; their history remains in Git. Archived Mosh sources are not Android application dependencies.
