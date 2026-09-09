#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if [[ -n "${GODOT_BIN:-}" ]]; then
  godot_bin="$GODOT_BIN"
elif command -v godot4 >/dev/null 2>&1; then
  godot_bin="$(command -v godot4)"
else
  godot_bin="$(command -v godot || true)"
fi
if [[ -z "$godot_bin" ]]; then
  echo "Godot 4.6 was not found. Set GODOT_BIN=/path/to/godot4." >&2
  exit 127
fi

mkdir -p build/web
"$godot_bin" --headless --path . --editor --import --quit
"$godot_bin" --headless --path . --export-release Web build/web/index.html

test -s build/web/index.html
archive="build/marshrutchik_web.zip"
rm -f "$archive"
(
  cd build/web
  zip -q -r "../marshrutchik_web.zip" .
)
test -s "$archive"
echo "Web build: $archive"
