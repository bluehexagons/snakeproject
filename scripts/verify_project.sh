#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

# Complete imports before running the scene test. This makes the command
# reliable on a fresh infra-tools VM or a clean checkout.
godot --headless --path . --editor --quit
godot --headless --path . --scene res://scenes/test_runner.tscn
