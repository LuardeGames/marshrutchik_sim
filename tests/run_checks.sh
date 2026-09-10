#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT_BIN="$GODOT_BIN"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="$(command -v godot4)"
else
  GODOT_BIN="$(command -v godot || true)"
fi
if [[ -z "$GODOT_BIN" ]]; then
  echo "Godot 4.6 was not found. Set GODOT_BIN=/path/to/godot4." >&2
  exit 127
fi
test_data="$(mktemp -d)"
trap 'rm -rf "$test_data"' EXIT
export XDG_DATA_HOME="$test_data"
"$GODOT_BIN" --headless --path . --editor --import --quit
for test in smoke_test full_route_test polish_test driving_test city_roads_test city_density_test traffic_test; do
  "$GODOT_BIN" --headless --path . --fixed-fps 60 --script "res://tests/$test.gd"
done

"$GODOT_BIN" --headless --path . --fixed-fps 60 --script res://tests/touch_test.gd -- --touch-ui
