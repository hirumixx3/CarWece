#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
flutter pub get
flutter analyze
flutter test
python3 tools/build_play_bundles.py "$@"
