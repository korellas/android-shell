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

## Mink Store Distribution

신규 배포와 앱 업데이트 완료에는 검증, 서명된 단일 APK 빌드, 개인용 Mink Store 등록 및 등록 확인까지 포함한다. 배포 전에 `/Users/korellas/git/appstore/AGENTS.md`를 읽는다. 기존 로컬 변경을 보존하고 GitHub Release나 직접 APK 전달 대신 Mink Store로 배포한다.

기존 배포 APK의 applicationId와 서명 인증서를 유지한다. Tilde의 배포 패키지는 `dev.korellas.androidshell.flutter.debug`이며 release 빌드도 기존 suffix를 유지한다. `app/build.gradle.kts`의 `appVersioning.overrideVersionCode`를 스토어 및 기존 배포 APK의 versionCode보다 높인다. Git 커밋 수에만 의존해 업데이트 버전을 정하지 않는다.

배포 키는 기존 APK의 인증서와 대조한다. 기존 키가 없거나 일치하지 않으면 배포를 중단하고 사용자에게 알린다. 새 키 생성, 다른 키로 재서명, 기기 앱 삭제로 해결하지 않는다. 기존 Android Debug 인증서로 배포한 APK를 업데이트할 때도 해당 기존 키를 그대로 사용한다. 키와 비밀번호는 Git이나 보고서에 기록하지 않는다.

`flutter analyze`, `flutter test`, 관련 Gradle 단위 테스트, lint 및 형식을 검증한다. Flutter 변경은 위의 Android·iPad 빌드 지침도 따른다. 기존 키를 Gradle의 `keystoreFile`, `keystoreAlias`, `keystorePassword` 속성으로 전달하고 `./scripts/build-flutter-android.sh release`로 release AAR와 OSS host APK를 함께 빌드한다. 서명 속성은 로컬 환경에서 제공하고, 키 파일이 실제로 존재하는지 먼저 확인한다. AAB나 분할 APK 대신 `app/build/outputs/apk/oss/release/app-oss-release.apk`를 사용하고 APK에서 패키지, versionCode, 앱 이름과 서명을 검증한다.

이 맥에서 실제 APK 절대 경로와 변경 내용을 사용해 실행한다.

```sh
/Users/korellas/git/appstore/storectl publish /Users/korellas/git/android_shell/app/build/outputs/apk/oss/release/app-oss-release.apk --name "Tilde" --notes "변경 내용"
/Users/korellas/git/appstore/storectl list
```

목록에서 패키지, versionCode와 서명 인증서를 빌드 결과와 대조한다. 서버 재시작이나 휴대폰 접속 키 전달은 필요하지 않다. 사용자 접속·다운로드·보고서 링크는 항상 `korellas-mac.mink.lan`에 서비스의 포트와 경로를 붙인다. 컴파일, 서명, 스토어 등록, 기기 설치·실행 검증 결과는 구분해 보고한다.
