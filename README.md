# Android Shell

A Flutter Android SSH/Mosh terminal client based on [ConnectBot](https://github.com/connectbot/connectbot).
This is an independent fork, not an official ConnectBot release.

## Build

Open the project in Android Studio and configure the Android SDK, or set
`sdk.dir` in a local, untracked `local.properties` file. Java compatibility
is configured in [app/build.gradle.kts](app/build.gradle.kts).

Install Flutter matching the revision in [the CI workflow](.github/workflows/ci-build.yml),
and build the Flutter module and open-source Android host together:

```sh
./scripts/build-flutter-android.sh debug
```

The APK is written to `app/build/outputs/apk/oss/debug/app-oss-debug.apk`.

See [Flutter build and validation](flutter_ui/README.md) for module checks and
release builds. The Android engine bridge supports Android; iOS integration and
visual design parity still need work.

For local native verification:

```sh
./gradlew :app:testOssDebugUnitTest :termlib:testDebugUnitTest
./gradlew :app:lintOssDebug :termlib:lintDebug spotlessCheck
```

## SSH key setup

Open **Login & SSH keys** from the host list, or **Register a key on this server**
in a connected SSH terminal. Log in with an existing method, then explicitly
register a new fingerprint-protected key or an existing SSH key. Registration
appends to the account's `~/.ssh/authorized_keys`, preserving existing keys and
their restrictions. A separate key-only connection must succeed before the
selected host's login settings change. Password login and shared accounts are
not changed. Servers using a custom authorized-key location require manual setup.

New fingerprint keys authorize each SSH signing operation through Android
Keystore and the system biometric prompt. Existing time-based keys remain
compatible. Device-local private keys cannot be exported or restored to another
phone; keep another working key or login method. If registration or verification
fails, a public key may already have been added to the server. Register Mosh
account keys through an SSH host for the same server.

## Upstream and licenses

The original ConnectBot history, copyright notices and [LICENSE](LICENSE)
are preserved. The terminal source and IME patch are described in
[termlib/README.md](termlib/README.md). Dependencies retain their own licenses.

See [ConnectBot](https://github.com/connectbot/connectbot),
[ConnectBot Terminal](https://github.com/connectbot/termlib),
[ConnectBot SSH library](https://github.com/connectbot/sshlib) and
[Mosh for Android](https://github.com/connectbot/mosh4android) for upstream projects.
