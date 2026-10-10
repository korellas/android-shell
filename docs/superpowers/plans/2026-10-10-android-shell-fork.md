# Android Shell Fork Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan.

**Goal:** Produce an installable open-source Android Shell debug build from current ConnectBot upstream, retaining its SSH, Mosh, Korean IME, host verification, imported-key, and biometric Keystore behavior while applying the agreed app identity and terminal key bar.

**Architecture:** Keep ConnectBot's existing transport, terminal, service, authentication, and persistence boundaries unchanged. Apply only product identity changes and a Compose key-bar layout change, then validate the retained upstream behavior through its existing tests and an installed-device smoke test.

**Tech Stack:** Android/Kotlin/Java 17, Jetpack Compose, Gradle, ConnectBot SSH/Mosh stack, Android Keystore, ADB.

---

### Task 1: Establish the upstream implementation baseline

**Files:**
- Preserve: `docs/superpowers/specs/2026-10-10-android-ssh-mosh-client-design.md`
- Preserve: `docs/superpowers/plans/2026-10-10-android-shell-fork.md`

**Step 1: Create the implementation branch from the fetched upstream base**

Create a new branch at `upstream/main` without rewriting the existing design branch, then cherry-pick the design, ignore, scope-narrowing, and plan commits.

**Step 2: Confirm repository instructions and baseline state**

Run:

```bash
git status --short --branch
git log --oneline --decorate -5
./gradlew :app:testOssDebugUnitTest --tests org.connectbot.TerminalKeyboardContentTest
```

Expected: the branch descends from `upstream/main`, the planning documents remain present, and the focused upstream test passes before production edits.

### Task 2: Apply Android Shell identity

**Files:**
- Modify: `app/build.gradle.kts`
- Modify: `app/src/main/res/values/notrans.xml`

**Step 1: Change install identity without renaming source packages**

Set the application ID to `dev.korellas.androidshell`, the test application ID to `dev.korellas.androidshell.tests`, and the app label to `Android Shell`. Keep the upstream `org.connectbot` namespace and source packages to avoid an unrelated package migration.

**Step 2: Validate the configuration**

Run:

```bash
./gradlew :app:processOssDebugMainManifest
git diff --check
```

Expected: manifest processing succeeds and the diff contains only the agreed identity changes.

**Step 3: Commit**

```bash
git add app/build.gradle.kts app/src/main/res/values/notrans.xml
git commit -m "Apply Android Shell app identity"
```

### Task 3: Fix the special-key bar using TDD

**Files:**
- Modify: `app/src/test/kotlin/org/connectbot/TerminalKeyboardContentTest.kt`
- Modify: `app/src/main/java/org/connectbot/ui/components/TerminalKeyboard.kt`

**Step 1: Add failing behavior tests**

Extend `TerminalKeyboardContentTest` to:

- scroll from the `Esc` region and verify `Ctrl` and `Alt` remain displayed;
- tap `Ins` and `Del` and verify callbacks receive `VTermKey.INS` and `VTermKey.DEL` in order.

**Step 2: Run the focused test and confirm the intended failure**

```bash
./gradlew :app:testOssDebugUnitTest --tests org.connectbot.TerminalKeyboardContentTest
```

Expected: the new test fails because modifiers currently scroll with the row and insertion/deletion buttons do not exist.

**Step 3: Implement the minimum Compose layout change**

Move the existing `Ctrl` and `Alt` modifier buttons outside the horizontally scrolling row. Keep `Esc` onward inside that row, and insert `Ins` and `Del` after `PgDn`, using `VTermKey.INS` and `VTermKey.DEL`. Reuse existing insertion/deletion accessibility strings.

**Step 4: Run the focused tests**

```bash
./gradlew :app:testOssDebugUnitTest --tests org.connectbot.TerminalKeyboardContentTest
```

Expected: all focused key-bar tests pass.

**Step 5: Commit**

```bash
git add app/src/main/java/org/connectbot/ui/components/TerminalKeyboard.kt app/src/test/kotlin/org/connectbot/TerminalKeyboardContentTest.kt
git commit -m "Keep terminal modifiers fixed"
```

### Task 4: Run regression validation and build the APK

**Files:**
- Inspect: all task-owned changes
- Produce: `app/build/outputs/apk/oss/debug/app-oss-debug.apk`

**Step 1: Run relevant automated checks**

```bash
./gradlew spotlessCheck
./gradlew :app:testOssDebugUnitTest
./gradlew :app:lintOssDebug
./gradlew :app:assembleOssDebug
```

Expected: formatting, unit tests, lint, and the OSS debug build pass. The existing suite supplies regression coverage for unchanged SSH, Mosh, terminal, host-key, imported-key, and Keystore behavior.

**Step 2: Inspect final repository state**

```bash
git status --short --branch
git diff --check
git diff upstream/main...HEAD --stat
git log --oneline --decorate upstream/main..HEAD
```

Expected: only planned source, test, and design artifacts differ; there are no unexplained untracked files.

### Task 5: Install and launch over wireless debugging

**Files:**
- Use: `app/build/outputs/apk/oss/debug/app-oss-debug.apk`

**Step 1: Confirm a single authorized Android target**

```bash
adb devices -l
```

Expected: one wireless-debugging device is listed as `device`. If more than one target is present, select the intended serial explicitly rather than installing to an ambiguous target.

**Step 2: Install and launch the debug build**

```bash
adb install -r app/build/outputs/apk/oss/debug/app-oss-debug.apk
adb shell monkey -p dev.korellas.androidshell.debug -c android.intent.category.LAUNCHER 1
adb shell pidof dev.korellas.androidshell.debug
```

Expected: installation and launch succeed and the process is alive.

**Step 3: Check startup logs**

Capture a bounded logcat view for the application process and verify there is no fatal startup exception.

**Step 4: Report the device acceptance boundary**

Report installation and launch evidence. Do not request or store server credentials. Real SSH/Mosh login, Korean input with Gboard/Samsung Keyboard in shell/Vim/tmux, changed-host-key handling, and biometric signing remain user-driven device acceptance when their required server and keyboard environments are available.
