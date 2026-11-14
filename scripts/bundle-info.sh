#!/bin/bash
# Mount a Yureisha DMG read-only and print KEY=value lines for the app inside it:
#   VERSION (CFBundleShortVersionString), BUILD (CFBundleVersion), MIN_MACOS (LSMinimumSystemVersion)
set -euo pipefail
mnt=$(mktemp -d)
hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$1" >/dev/null
trap 'hdiutil detach "$mnt" -quiet || true' EXIT
p="$mnt/Yureisha.app/Contents/Info.plist"
echo "VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$p")"
echo "BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$p")"
echo "MIN_MACOS=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$p")"
