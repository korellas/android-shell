# Repository Guidelines

## Project Structure & Module Organization

Tilde uses Flutter for screens, SSH and terminal rendering in `flutter_ui/`, with a Gradle Android host and `oss` and `google` product flavors. Android bridge, data, dependency injection and platform services live under `app/src/main/java/org/connectbot`; JNI code is in `app/src/main/cpp`, resources in `app/src/main/res`, and Room schemas in `app/schemas`. JVM tests are in `app/src/test/kotlin` and flavor-specific test source sets, instrumentation tests in `app/src/androidTest`, and shared helpers in `app/src/sharedTest/kotlin`. Translation files are under `translations/` and `app/locale/`.

## Build, Test, and Development Commands

Use the checked-in Gradle wrapper:

- `./gradlew assemble` builds all variants.
- `./gradlew :app:assembleOssDebug` builds the open-source debug APK.
- `./gradlew test` runs local JVM/Robolectric tests.
- `./gradlew connectedAndroidTest` runs device/emulator instrumentation tests.
- `./gradlew connectedOssDebugAndroidTest` and `./gradlew connectedGoogleDebugAndroidTest` run flavor-specific instrumentation tests.
- `./gradlew lint` runs Android lint with `app/lint.xml`.
- `./gradlew spotlessCheck` verifies formatting; `./gradlew spotlessApply` formats supported files.
- `./gradlew check test` runs the standard verification set used before submitting changes.

For Flutter app changes, build both Android and iPad-compatible iOS targets from the same `flutter_ui` sources. Use `./scripts/build-flutter.sh debug` on macOS, and report compilation separately from signing, installation, and device testing.

## Coding Style & Naming Conventions

Target Java 17/JVM 17. Kotlin uses ktlint; Java under `app/src/main/java/org/connectbot` uses Google Java Format through Spotless. Keep package names lowercase and aligned with existing feature areas. Name Kotlin and Java types in `PascalCase`, functions and properties in `camelCase`, and tests as `*Test`. Prefer existing Flutter, Hilt, Room, and repository patterns over new abstractions. Declare Gradle dependency and plugin versions in `gradle/libs.versions.toml` and use version catalog aliases from build scripts. Add XML comments directly before new `strings.xml` entries so translators understand the string's purpose and placement. For new project-owned source files, use the current-year copyright notice for Kenny Root unless the surrounding package uses a different established notice.

## Testing Guidelines

Add focused tests for behavior changes. Use Robolectric for Android bridge/ViewModel tests in `app/src/test/kotlin`; use Android instrumentation tests only when device APIs, Hilt runner behavior, or emulator state is required. Keep platform behavior in its existing ViewModels and repositories. Use `org.mockito.Mockito` imports rather than mockito-kotlin in new tests. For database changes, update Room schema JSON under `app/schemas` and test migrations when relevant. SSH interoperability checks live under `flutter_ui/validation`; local Docker builds and container tests are not permitted.

## Commit & Pull Request Guidelines

Commit history uses short imperative subjects, for example `Fix pubkey list item compose lint` or `Add unit tests for importKeyFromText`. Keep the subject at 50 characters or less when practical, add a wrapped body for context, and make each commit a logical unit. Before opening a PR, run `git diff --check`, `./gradlew lint`, and `./gradlew check test`. PRs should describe the change, link related issues, mention test coverage, and include screenshots or screen recordings for visible UI changes.

## Agent-Specific Instructions

Do not overwrite unrelated local changes. Keep edits scoped to the requested behavior, preserve generated schema and translation files unless intentionally updating them, and prefer Gradle tasks over ad hoc build commands. Never block the main UI thread; dispatch IPC, network, disk I/O, and other long-running work off the main thread. In injected classes and ViewModels, use the injected `CoroutineDispatchers` instead of hardcoded `Dispatchers.IO` or similar dispatchers so tests can control execution.

## CI Verification

The reusable CI workflow owns the required task selection. Flutter checks and AAR builds run in its `flutter` job; Android consumers restore that job's Maven repository artifact. Common JVM tests run on OSS; Google runs its language-pack-specific unit tests. Both variants retain unit coverage, lint, release builds, lifecycle and migration device checks. Device variants run sequentially on one emulator. Code changes also run repository formatting, so a separate docs job is needed only for documentation-only changes.
