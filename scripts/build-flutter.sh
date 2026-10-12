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
case "$port_mode" in
  debug|release) ;;
  *) printf 'Usage: %s [debug|release]\n' "$0" >&2; exit 2 ;;
esac
if [[ "$(uname -s)" != Darwin ]]; then
  printf 'Building Android and iPad together requires macOS and Xcode.\n' >&2
  exit 1
fi
"$port_root/scripts/build-flutter-android.sh" "$port_mode"
cd "$port_root/flutter_ui"
python3 "$port_root/branding/ios/apply-branding.py" "$port_root/flutter_ui/.ios"
flutter build ios "--$port_mode" --no-codesign
