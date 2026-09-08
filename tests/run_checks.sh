#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
test_data="$(mktemp -d)"
trap 'rm -rf "$test_data"' EXIT
export XDG_DATA_HOME="$test_data"
"$GODOT_BIN" --headless --path . --editor --import --quit
for test in smoke_test full_route_test polish_test driving_test city_roads_test traffic_test; do
  "$GODOT_BIN" --headless --path . --fixed-fps 60 --script "res://tests/$test.gd"
done

"$GODOT_BIN" --headless --path . --fixed-fps 60 --script res://tests/touch_test.gd -- --touch-ui
