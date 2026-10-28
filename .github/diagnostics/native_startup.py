import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import time

ROOT = Path.cwd()
OUT = ROOT / 'native-startup-results'
OUT.mkdir(exist_ok=True)
PACKAGE = 'dev.korellas.androidshell.flutter.debug'
COMPONENT = PACKAGE + '/org.connectbot.flutter.FlutterShellActivity'
APK = ROOT / 'app/build/outputs/apk/google/debug/app-google-debug.apk'
WRAP = 'wrap.' + PACKAGE
results = []


def command(args, name, timeout=60, check=True):
    try:
        completed = subprocess.run(args, capture_output=True, text=True, errors="replace", timeout=timeout)
        text = completed.stdout + completed.stderr
        code = completed.returncode
    except subprocess.TimeoutExpired as error:
        text = str(error)
        code = 124
    (OUT / name).write_text(text)
    if check and code:
        raise RuntimeError(f'{name}: command exited {code}')
    return code, text


def adb(args, name, check=True):
    return command(['adb', *args], name, check=check)


def shell(args, name, check=True):
    return adb(['shell', shlex.join(args)], name, check)


def start(label):
    shell(['am', 'force-stop', PACKAGE], label + '-stop.txt')
    adb(['logcat', '-c'], label + '-log-clear.txt')
    code, _ = shell(['am', 'start', '-W', '-a', 'android.intent.action.MAIN', '-n', COMPONENT], label + '-start.txt', False)
    # A fixed observation window, not a retry-until-pass loop.
    for _ in range(10):
        time.sleep(1)
    _, pid = shell(['pidof', PACKAGE], label + '-pid.txt', False)
    _, log = adb(['logcat', '-d', '-v', 'threadtime'], label + '-logcat.txt')
    if pid.strip().isdigit():
        for file in ['maps', 'status', 'smaps_rollup']:
            shell(['cat', '/proc/' + pid.strip() + '/' + file], label + '-' + file + '.txt', False)
    item = {
        'label': label,
        'start_exit': code,
        'pid_after_window': pid.strip(),
        'target_native_tombstone': '>>> ' + PACKAGE + ' <<<' in log,
        'malloc_debug_enabled': 'malloc debug enabled' in log,
    }
    results.append(item)
    print(json.dumps(item), flush=True)


try:
    adb(['root'], 'adb-root.txt')
    adb(['wait-for-device'], 'adb-ready.txt')
    adb(['shell', 'getprop'], 'device-properties.txt')
    shell(['id'], 'device-user.txt')
    apk_hash = hashlib.sha256(APK.read_bytes()).hexdigest()
    (OUT / 'apk-sha256.txt').write_text(apk_hash + '\n')
    shell(['setprop', WRAP, ''], 'baseline-wrapper.txt')
    adb(['install', '-r', str(APK)], 'install-baseline.txt')
    for i in range(3):
        start(f'normal-{i + 1}')
    shell(['am', 'force-stop', PACKAGE], 'before-instrument-stop.txt')
    adb(['logcat', '-c'], 'instrument-log-clear.txt')
    code, _ = command([
        './gradlew', '--no-parallel', ':app:connectedGoogleDebugAndroidTest',
        '-Pandroid.testInstrumentationRunnerArguments.class=org.connectbot.flutter.FlutterShellActivityLifecycleTest',
        '--no-configuration-cache',
    ], 'instrument-gradle.txt', timeout=900, check=False)
    results.append({'label': 'instrumentation', 'exit': code})
    if hashlib.sha256(APK.read_bytes()).hexdigest() != apk_hash:
        raise RuntimeError('Instrumentation rebuilt a different APK; comparisons are invalid.')
    adb(['logcat', '-d', '-v', 'threadtime'], 'instrument-logcat.txt')
    adb(['install', '-r', str(APK)], 'install-guarded.txt')
    options = 'guard=32 backtrace=16 free_track=128'
    value = 'LIBC_DEBUG_MALLOC_OPTIONS=' + options.replace(' ', '\\ ') + ' logwrapper'
    shell(['setprop', WRAP, value], 'enable-malloc-debug.txt')
    shell(['getprop', WRAP], 'malloc-wrapper-value.txt')
    for i in range(2):
        start(f'malloc-guard-{i + 1}')
    if not any(r.get('malloc_debug_enabled') for r in results):
        raise RuntimeError('Malloc debug activation was not observed; inspect wrapper and logcat artifacts.')
finally:
    shell(['am', 'force-stop', PACKAGE], 'cleanup-stop.txt', False)
    shell(['setprop', WRAP, ''], 'cleanup-wrapper.txt', False)
    adb(['pull', '/data/tombstones', str(OUT / 'tombstones')], 'tombstone-pull.txt', False)
    (OUT / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
