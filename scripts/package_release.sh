#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

tag="${1:-}"
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected a release tag such as v0.4.0." >&2
  exit 1
fi

version="${tag#v}"
if ! grep -Fxq "config/version=\"$version\"" project.godot; then
  echo "Tag $tag does not match config/version in project.godot." >&2
  exit 1
fi
if ! grep -Fxq "application/file_version=\"$version.0\"" export_presets.cfg ||
   ! grep -Fxq "application/product_version=\"$version.0\"" export_presets.cfg; then
  echo "Both Windows version fields in export_presets.cfg must be $version.0." >&2
  exit 1
fi

godot="${GODOT:-godot}"
mkdir -p build
package_dir="$(mktemp -d build/release.XXXXXX)"
trap 'rm -rf -- "$package_dir"' EXIT
windows_dir="$package_dir/windows"
web_dir="$package_dir/web"
mkdir -p "$windows_dir" "$web_dir"

# Import before exporting on an empty checkout. Treat editor errors as failures
# even when Godot exits successfully.
run_godot() {
  local log
  log="$(mktemp)"
  if ! "$godot" --headless --path . "$@" > "$log" 2>&1 || grep -q 'ERROR:' "$log"; then
    cat "$log" >&2
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
}

run_godot --import
run_godot --export-release 'Windows Desktop' "$windows_dir/snake3d.exe"
run_godot --export-release Web "$web_dir/index.html"
test -s "$windows_dir/snake3d.exe"
test -s "$windows_dir/snake3d.pck"
test -s "$web_dir/index.html"
test -s "$web_dir/index.js"
test -s "$web_dir/index.wasm"
test -s "$web_dir/index.pck"

# License and third-party notices from the Godot 4.7.2 source commit.
godot_source=https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf001b61586d9930840f2f1394092c079
curl -fsSL --retry 4 "$godot_source/LICENSE.txt" -o "$windows_dir/GODOT_LICENSE.txt"
curl -fsSL --retry 4 "$godot_source/COPYRIGHT.txt" -o "$windows_dir/GODOT_COPYRIGHT.txt"
cp LICENSE NOTICE "$windows_dir/"
cp LICENSE NOTICE "$windows_dir/GODOT_LICENSE.txt" "$windows_dir/GODOT_COPYRIGHT.txt" "$web_dir/"
printf '%s\n' "$tag" > "$web_dir/version.txt"

(
  cd "$windows_dir"
  zip -q -9 "../snake3d-$tag-windows-x86_64.zip" snake3d.exe snake3d.pck \
    LICENSE NOTICE GODOT_LICENSE.txt GODOT_COPYRIGHT.txt
)

trap - EXIT
printf '%s\n' "$package_dir"
