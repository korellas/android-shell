# Android Shell

An Android SSH/Mosh terminal client based on [ConnectBot](https://github.com/connectbot/connectbot).
This is an independent fork, not an official ConnectBot release.

## Build

Open the project in Android Studio and configure the Android SDK, or set
`sdk.dir` in a local, untracked `local.properties` file. Java compatibility
is configured in [app/build.gradle.kts](app/build.gradle.kts).

Build the open-source debug APK with the checked-in Gradle wrapper:

```sh
./gradlew :app:assembleOssDebug
```

The APK is written to `app/build/outputs/apk/oss/debug/app-oss-debug.apk`.

For local verification:

```sh
./gradlew :app:testOssDebugUnitTest :termlib:testDebugUnitTest
./gradlew :app:lintOssDebug :termlib:lintDebug spotlessCheck
```

## Upstream and licenses

The original ConnectBot history, copyright notices and [LICENSE](LICENSE)
are preserved. The terminal source and IME patch are described in
[termlib/README.md](termlib/README.md). Dependencies retain their own licenses.

See [ConnectBot](https://github.com/connectbot/connectbot),
[ConnectBot Terminal](https://github.com/connectbot/termlib),
[ConnectBot SSH library](https://github.com/connectbot/sshlib) and
[Mosh for Android](https://github.com/connectbot/mosh4android) for upstream projects.
