#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
app_dir="$source_dir/../Orbit.app"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/orbit-build.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
for architecture in arm64 x86_64; do
  xcrun swiftc -parse-as-library -O -target "$architecture-apple-macosx13.0" -module-cache-path "$build_dir/cache" "$source_dir/Orbit.swift" -o "$build_dir/Orbit-$architecture"
done
lipo -create "$build_dir/Orbit-arm64" "$build_dir/Orbit-x86_64" -output "$app_dir/Contents/MacOS/Orbit"
cp "$source_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$source_dir/Orbit.icns" "$app_dir/Contents/Resources/Orbit.icns"
xattr -d com.apple.FinderInfo "$app_dir" 2>/dev/null || true
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "Built Orbit.app for Apple silicon and Intel Macs."
