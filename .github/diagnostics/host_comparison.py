# Copyright 2026 Kenny Root
# Licensed under the Apache License, Version 2.0.

import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys
import time
import tomllib
import zipfile

ROOT = Path.cwd()
CONTROL = ROOT / 'build/native-host-control'
OUT = ROOT / 'native-startup-results'
PRODUCT = 'dev.korellas.androidshell.flutter.debug'
MINIMAL = 'dev.korellas.diagnostic.flutterhost'
TARGETS = {
    PRODUCT: ('org.connectbot.flutter.FlutterShellActivity', ROOT / 'app/build/outputs/apk/google/debug/app-google-debug.apk'),
    MINIMAL: ('io.flutter.embedding.android.FlutterActivity', CONTROL / 'build/outputs/apk/debug/native-host-control-debug.apk'),
}


def prepare():
    versions = tomllib.loads((ROOT / 'gradle/libs.versions.toml').read_text())['versions']
    CONTROL.mkdir(parents=True, exist_ok=True)
    (CONTROL / 'settings.gradle').write_text('''pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
rootProject.name = 'native-host-control'
''')
    (CONTROL / 'gradle.properties').write_text('android.useAndroidX=true\norg.gradle.jvmargs=-Xmx2g\n')
    repo = (ROOT / 'flutter_ui/build/host/outputs/repo').as_uri()
    (CONTROL / 'build.gradle').write_text('''plugins { id 'com.android.application' version '%s' }
repositories {
    maven { url '%s' }
    maven { url 'https://storage.googleapis.com/download.flutter.io' }
    google(); mavenCentral()
}
android {
    namespace '%s'
    compileSdk %s
    defaultConfig {
        applicationId '%s'
        minSdk %s
        targetSdk %s
        versionCode 1
        versionName 'diagnostic'
        ndk { abiFilters 'x86_64' }
    }
}
dependencies { implementation 'dev.korellas.android_shell_ui:flutter_debug:%s' }
''' % (versions['androidGradlePlugin'], repo, MINIMAL, versions['compileSdk'], MINIMAL,
       versions['minSdk'], versions['targetSdk'], versions['flutterModule']))
    manifest = CONTROL / 'src/main/AndroidManifest.xml'
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:label="Diagnostic Flutter host" android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <meta-data android:name="flutterEmbedding" android:value="2" />
        <activity android:name="io.flutter.embedding.android.FlutterActivity" android:exported="true"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true" android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
''')
    subprocess.run([str(ROOT / 'gradlew'), '-p', str(CONTROL), 'assembleDebug', '--no-configuration-cache'], check=True)
    OUT.mkdir(exist_ok=True)
    identity = {}
    for package, (_, apk) in TARGETS.items():
        with zipfile.ZipFile(apk) as archive:
            identity[package] = {
                name: hashlib.sha256(archive.read(name)).hexdigest()
                for name in ['lib/x86_64/libflutter.so', 'assets/flutter_assets/kernel_blob.bin']
            }
    (OUT / 'host-input-hashes.json').write_text(json.dumps(identity, indent=2) + '\n')
    if identity[PRODUCT] != identity[MINIMAL]:
        raise RuntimeError('Control must use identical Flutter engine and Dart kernel.')


def run(args, name, timeout=65, check=True):
    try:
        result = subprocess.run(args, capture_output=True, text=True, errors='replace', timeout=timeout)
        code, output = result.returncode, result.stdout + result.stderr
    except subprocess.TimeoutExpired as error:
        code, output = 124, str(error)
    (OUT / name).write_text(output)
    if check and code:
        raise RuntimeError(f'{name}: command exited {code}')
    return code, output


def shell(args, name, check=True):
    return run(['adb', 'shell', shlex.join(args)], name, check=check)


def observe():
    OUT.mkdir(exist_ok=True)
    observations = []
    run(['adb', 'root'], 'host-adb-root.txt')
    run(['adb', 'wait-for-device'], 'host-adb-ready.txt')
    shell(['getprop'], 'host-device-properties.txt')
    try:
        for package, (_, apk) in TARGETS.items():
            shell(['setprop', 'wrap.' + package, ''], package + '-unset-wrapper.txt')
            run(['adb', 'install', '-r', str(apk)], package + '-install.txt')
        # Fixed interleaved trials; every failure is retained without retrying it.
        for trial in range(6):
            packages = list(TARGETS)
            if trial % 2:
                packages.reverse()
            for package in packages:
                prefix = ('product' if package == PRODUCT else 'minimal') + '-' + str(trial + 1)
                for target in TARGETS:
                    shell(['am', 'force-stop', target], prefix + '-stop-' + target + '.txt')
                run(['adb', 'logcat', '-c'], prefix + '-clear.txt')
                activity, _ = TARGETS[package]
                code, launch = shell(['am', 'start', '-W', '-a', 'android.intent.action.MAIN', '-n', package + '/' + activity], prefix + '-start.txt', False)
                time.sleep(30)
                _, pid = shell(['pidof', package], prefix + '-pid.txt', False)
                _, log = run(['adb', 'logcat', '-d', '-v', 'threadtime'], prefix + '-logcat.txt')
                shell(['dumpsys', 'activity', 'top'], prefix + '-activity.txt', False)
                if pid.strip().isdigit():
                    shell(['cat', '/proc/' + pid.strip() + '/maps'], prefix + '-maps.txt', False)
                observation = {
                    'trial': trial + 1, 'package': package, 'start_exit': code,
                    'start_status_ok': 'Status: ok' in launch,
                    'pid_after_window': pid.strip(),
                    'native_tombstone': '>>> ' + package + ' <<<' in log,
                    'displayed': any('Displayed ' + package + '/' in line for line in log.splitlines()),
                    'engine_backend': [line for line in log.splitlines() if 'Using the ' in line and 'rendering backend' in line],
                }
                observations.append(observation)
                (OUT / 'host-comparison.json').write_text(json.dumps(observations, indent=2) + '\n')
                print(json.dumps(observation), flush=True)
    finally:
        for package in TARGETS:
            shell(['am', 'force-stop', package], package + '-cleanup-stop.txt', False)
            shell(['setprop', 'wrap.' + package, ''], package + '-cleanup-wrapper.txt', False)
        run(['adb', 'pull', '/data/tombstones', str(OUT / 'host-tombstones')], 'host-tombstone-pull.txt', check=False)


if __name__ == '__main__':
    if sys.argv[1] == 'prepare':
        prepare()
    elif sys.argv[1] == 'observe':
        observe()
    else:
        raise ValueError('Expected prepare or observe')
