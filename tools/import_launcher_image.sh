#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_image="${1:-$project_root/branding/icon_source_v0131.png}"
# Mechanical asset conversion: remove only the external transparent margin,
# retain the provided artwork and fit it inside the adaptive icon viewport.
convert "$source_image" -trim +repage -filter Lanczos -resize 640x640 \
  -background black -alpha remove -alpha off -alpha set \
  -gravity center -background none -extent 1024x1024 \
  "$project_root/branding/ic_launcher_foreground.png"
convert "$project_root/branding/ic_launcher_foreground.png" \
  -background black -alpha remove -alpha off \
  "$project_root/branding/ic_launcher_background.png"
python3 "$project_root/tools/build_icons.py"
