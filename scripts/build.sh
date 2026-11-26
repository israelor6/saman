#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p build

staging="$(mktemp -d "$root/build/.staging.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
bundle="$staging/Saman.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp -R Resources/*.lproj "$bundle/Contents/Resources/"
plutil -lint "$bundle/Contents/Info.plist"
xcrun swift scripts/make-icon.swift "$staging/Saman.iconset"
iconutil -c icns -o "$bundle/Contents/Resources/Saman.icns" "$staging/Saman.iconset"

xcrun swiftc -swift-version 5 -O -parse-as-library \
    -target "$(uname -m)-apple-macosx27.0" \
    Sources/Saman/*.swift -o "$bundle/Contents/MacOS/Saman"

codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"

destination="$root/build/Saman.app"
if [[ -d "$destination" ]]; then
    mv "$destination" "$staging/previous.app"
fi
if ! mv "$bundle" "$destination"; then
    if [[ -d "$staging/previous.app" ]]; then mv "$staging/previous.app" "$destination"; fi
    exit 1
fi

echo "$destination"
if [[ "${1:-}" == "--open" ]]; then open "$destination"; fi
