#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

# Keep integration fixtures and autosaves away from the player's real save.
test_data_dir="$(mktemp -d)"
trap 'rm -rf "$test_data_dir"' EXIT
export XDG_DATA_HOME="$test_data_dir"

# Complete imports before running the scene test. This makes the command
# reliable on a fresh infra-tools VM or a clean checkout.
godot --headless --path . --import
godot --headless --path . --scene res://scenes/test_runner.tscn

godot --headless --path . --scene res://scenes/gameplay_test.tscn
