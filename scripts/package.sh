#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/build"
codesign --verify --strict Saman.app

staging="$(mktemp -d "$PWD/.package.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
archive="$staging/Saman-macOS.zip"

ditto -c -k --norsrc --keepParent Saman.app "$archive"
unzip -tq "$archive"
ditto -x -k "$archive" "$staging/extracted"
codesign --verify --strict "$staging/extracted/Saman.app"
(
    cd "$staging"
    shasum -a 256 Saman-macOS.zip > Saman-macOS.zip.sha256
)
mv "$archive" Saman-macOS.zip
mv "$staging/Saman-macOS.zip.sha256" Saman-macOS.zip.sha256
printf '%s\n' "$PWD/Saman-macOS.zip" "$PWD/Saman-macOS.zip.sha256"
