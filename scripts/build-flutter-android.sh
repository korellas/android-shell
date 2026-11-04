#!/usr/bin/env bash
# ConnectBot: simple, powerful, open-source SSH client for Android
# Copyright 2026 Kenny Root
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail
port_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
port_mode="${1:-debug}"
port_distribution="${2:-mink}"
if (( $# > 2 )); then
  printf 'Usage: %s [debug|release] [mink|play]\n' "$0" >&2
  exit 2
fi
case "$port_mode" in
  debug|release) ;;
  *) printf 'Usage: %s [debug|release] [mink|play]\n' "$0" >&2; exit 2 ;;
esac
case "$port_distribution" in
  mink|play) ;;
  *) printf 'Distribution must be mink or play.\n' >&2; exit 2 ;;
esac
if [[ "$port_distribution" == play && "$port_mode" != release ]]; then
  printf 'Play distribution requires release mode.\n' >&2
  exit 2
fi
port_test_ads="${TILDE_TEST_ADS:-false}"
case "$port_test_ads" in
  true|false) ;;
  *) printf 'TILDE_TEST_ADS must be true or false.\n' >&2; exit 2 ;;
esac
cd "$port_root/flutter_ui"
flutter pub get
if [[ "$port_mode" == debug ]]; then
  flutter build aar --debug --no-profile --no-release "--dart-define=TILDE_TEST_ADS=$port_test_ads"
else
  flutter build aar --release --no-profile --no-debug "--dart-define=TILDE_TEST_ADS=$port_test_ads"
fi
cd "$port_root"
port_git_directory="$(git rev-parse --path-format=absolute --git-common-dir)"
port_git_root="${port_git_directory%/.git}"
port_init_script="$(mktemp)"
trap 'rm -f "$port_init_script"' EXIT
cat > "$port_init_script" <<'GRADLE'
gradle.beforeProject { project ->
    if (project.path == ":app") {
        project.pluginManager.withPlugin("io.github.reactivecircus.app-versioning") {
            project.extensions.getByName("appVersioning").gitRootDirectory.set(
                project.file(project.findProperty("flutterPortGitRoot"))
            )
        }
    }
}
GRADLE
if [[ "$port_mode" == debug ]]; then port_variant=Debug; else port_variant=Release; fi
if [[ "$port_distribution" == play ]]; then
  ./gradlew -I "$port_init_script" "-PflutterPortGitRoot=$port_git_root" -PplayDistribution=true :app:bundleOssRelease --no-configuration-cache
else
  ./gradlew -I "$port_init_script" "-PflutterPortGitRoot=$port_git_root" ":app:assembleOss$port_variant" --no-configuration-cache
fi
