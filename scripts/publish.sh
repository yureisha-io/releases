#!/bin/bash
# publish.sh -- publish a direct-download release of Yureisha from a LOCAL, already signed, notarized and stapled DMG.
#
# This replaces the removed GitHub Actions workflows publish.yml and appcast.yml. There is no CI on GitHub
# (.claude/rules/no-github-ci.md): run this in a native Darwin arm64 k3sm pod, or on the Mac through the yurei build
# queue. It never builds or signs the app. The app repo (yureisha-io/yureisha) owns that half.
#
#   scripts/publish.sh --dmg path/to/Yureisha.dmg --version 1.2.3 --build 45            # draft release (default)
#   scripts/publish.sh --dmg path/to/Yureisha.dmg --version 1.2.3 --build 45 --publish  # published + appcast PR
#   scripts/publish.sh --appcast-only --version 1.2.3     # add an already-published release (e.g. a draft the operator
#                                                         # published in the UI) to appcast.xml through a PR
#   scripts/publish.sh --verify-only --dmg path/to/Yureisha.dmg --version 1.2.3 --build 45
#
# Environment:
#   APPLE_TEAM_ID           required: the Developer ID team id; a DMG signed by any other team is refused.
#   SPARKLE_ENABLED         "true" once the app ships Sparkle; otherwise a placeholder signature is written.
#   SPARKLE_ED_PRIVATE_KEY  only read when SPARKLE_ENABLED=true (see scripts/sparkle-sign.sh).
#   SPARKLE_SHA256          required when SPARKLE_ENABLED=true: the pinned sha256 of the Sparkle release tarball.
# appcast.xml changes land through a pull request; this script never pushes to main.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=yureisha-io/releases

die() { echo "publish: $*" >&2; exit 1; }
DMG= VERSION= BUILD= MODE=draft
while [ $# -gt 0 ]; do
  case "$1" in
    --dmg) DMG=$2; shift 2 ;;
    --version) VERSION=$2; shift 2 ;;
    --build) BUILD=$2; shift 2 ;;
    --publish) MODE=publish; shift ;;
    --appcast-only) MODE=appcast; shift ;;
    --verify-only) MODE=verify; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

test "$(uname -s)" = Darwin && test "$(uname -m)" = arm64 || die "must run on Darwin arm64 (a native k3sm pod or the Mac)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || die "bad --version '$VERSION'"
TAG="v$VERSION"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

verify_dmg() {  # $1 = dmg; sets MIN_MACOS
  local dmg=$1 mnt app plist short build bad=0 f archs
  test -f "$dmg" || die "no DMG at $dmg"
  test -n "${APPLE_TEAM_ID:-}" || die "APPLE_TEAM_ID is not set"
  codesign --verify --strict --verbose=2 "$dmg"
  codesign -dv --verbose=4 "$dmg" 2>&1 | grep -q "^TeamIdentifier=$APPLE_TEAM_ID$" || die "DMG not signed by team $APPLE_TEAM_ID"
  spctl -a -t open --context context:primary-signature -v "$dmg" 2>&1 | grep -q "Notarized Developer ID" || die "DMG not notarized"
  xcrun stapler validate "$dmg"
  mnt=$(mktemp -d)
  hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg" >/dev/null
  app="$mnt/Yureisha.app"
  if ! test -d "$app"; then hdiutil detach "$mnt" -quiet || true; die "Yureisha.app not found at the DMG root"; fi
  codesign --verify --deep --strict --verbose=2 "$app"
  codesign -dv --verbose=4 "$app" 2>&1 | grep -q "^Authority=Developer ID Application:" || die "app is not Developer ID signed"
  codesign -dv --verbose=4 "$app" 2>&1 | grep -q "^TeamIdentifier=$APPLE_TEAM_ID$" || die "app not signed by team $APPLE_TEAM_ID"
  spctl -a -t exec -vv "$app" 2>&1 | grep -q "Notarized Developer ID" || die "app not notarized"
  xcrun stapler validate "$app"
  # Apple silicon only: every Mach-O in the bundle must be arm64 and nothing else.
  while IFS= read -r -d '' f; do
    if file -b "$f" | grep -q "Mach-O"; then
      archs=$(lipo -archs "$f" 2>/dev/null || echo "?")
      [ "$archs" = "arm64" ] || { echo "publish: $f is '$archs', expected arm64 only" >&2; bad=1; }
    fi
  done < <(find "$app" -type f -perm +111 -print0)
  plist="$app/Contents/Info.plist"
  short=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
  build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist")
  MIN_MACOS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$plist")
  hdiutil detach "$mnt" -quiet || true
  [ "$bad" = 0 ] || die "non-arm64 Mach-O in the bundle"
  [ "$short" = "$VERSION" ] || die "bundle version $short != $VERSION"
  [ -z "$BUILD" ] || [ "$build" = "$BUILD" ] || die "bundle build $build != $BUILD"
  BUILD=$build
}

appcast_pr() {  # adds $TAG to appcast.xml on a branch and opens a PR; needs LENGTH, MIN_MACOS, ED_SIGNATURE, BUILD
  local branch="appcast/$TAG"
  grep -q "/releases/download/$TAG/Yureisha.dmg" appcast.xml && { echo "$TAG is already in appcast.xml"; return 0; }
  git fetch -q origin main
  git switch -q -c "$branch" origin/main
  python3 scripts/appcast.py --version "$VERSION" --build "$BUILD" --length "$LENGTH" \
    --min-macos "$MIN_MACOS" --ed-signature "$ED_SIGNATURE"
  git add appcast.xml
  git commit -q -m "chore(appcast): publish $TAG"
  git push -q -u origin "$branch"
  gh pr create -R "$REPO" --base main --head "$branch" --title "chore(appcast): publish $TAG" \
    --body "Adds $TAG to appcast.xml (scripts/publish.sh). The DMG was verified locally before this PR was opened."
}

if [ "$MODE" = appcast ]; then
  gh release view "$TAG" -R "$REPO" --json isDraft -q .isDraft | grep -qx false || die "$TAG is not a published release"
  gh release download "$TAG" -R "$REPO" -p Yureisha.dmg -p Yureisha.dmg.sha256 -D "$WORK"
  (cd "$WORK" && shasum -a 256 -c Yureisha.dmg.sha256)
  verify_dmg "$WORK/Yureisha.dmg"
  LENGTH=$(stat -f%z "$WORK/Yureisha.dmg")
  ED_SIGNATURE=$(scripts/sparkle-sign.sh "$WORK/Yureisha.dmg")
  appcast_pr
  exit 0
fi

[[ "$BUILD" =~ ^[0-9]+(\.[0-9]+)*$ ]] || die "bad --build '$BUILD'"
verify_dmg "$DMG"
[ "$MODE" = verify ] && { echo "publish: $DMG verified ($TAG, build $BUILD, macOS $MIN_MACOS+)"; exit 0; }

gh release view "$TAG" -R "$REPO" >/dev/null 2>&1 && die "release $TAG already exists"
cp "$DMG" "$WORK/Yureisha.dmg"
(cd "$WORK" && shasum -a 256 Yureisha.dmg > Yureisha.dmg.sha256)
SHA256=$(cut -d' ' -f1 "$WORK/Yureisha.dmg.sha256")
LENGTH=$(stat -f%z "$WORK/Yureisha.dmg")
ED_SIGNATURE=$(scripts/sparkle-sign.sh "$WORK/Yureisha.dmg")
sed -e "s/{{VERSION}}/$VERSION/g" -e "s/{{BUILD}}/$BUILD/g" -e "s/{{SHA256}}/$SHA256/g" -e "s/{{MIN_MACOS}}/$MIN_MACOS/g" \
  docs/release-notes-template.md | awk '/^<!--/{c=1} !c{print} /-->/{c=0}' > "$WORK/notes.md"
flags=(--title "Yureisha $VERSION" --notes-file "$WORK/notes.md" --target main)
[ "$MODE" = draft ] && flags+=(--draft)
# The asset name stays Yureisha.dmg so releases/latest/download/Yureisha.dmg (linked from yureisha.io) works.
gh release create "$TAG" -R "$REPO" "$WORK/Yureisha.dmg" "$WORK/Yureisha.dmg.sha256" "${flags[@]}"
# A draft's download URL isn't public, so the appcast only changes for a published release.
if [ "$MODE" = publish ]; then appcast_pr; else echo "publish: draft $TAG created; after publishing it, run --appcast-only --version $VERSION"; fi
