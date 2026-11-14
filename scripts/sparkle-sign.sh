#!/bin/bash
# Print the Sparkle EdDSA signature for a file, or ED_SIGNATURE_PLACEHOLDER when Sparkle isn't enabled.
#   SPARKLE_ENABLED=true SPARKLE_ED_PRIVATE_KEY=... SPARKLE_VERSION=2.6.4 scripts/sparkle-sign.sh dist/Yureisha.dmg
# The key is written to a 0600 temp file for sign_update and removed straight after. Never echo it.
set -euo pipefail
f="$1"
if [ "${SPARKLE_ENABLED:-}" != "true" ]; then
  echo "Sparkle not enabled (vars.SPARKLE_ENABLED); using a placeholder signature." >&2
  echo ED_SIGNATURE_PLACEHOLDER; exit 0
fi
[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ] || { echo "::error::SPARKLE_ED_PRIVATE_KEY secret is not set" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
v="${SPARKLE_VERSION:-2.6.4}"
curl -fsSL -o "$tmp/sparkle.tar.xz" "https://github.com/sparkle-project/Sparkle/releases/download/$v/Sparkle-$v.tar.xz"
mkdir "$tmp/sparkle" && tar -xJf "$tmp/sparkle.tar.xz" -C "$tmp/sparkle"
( umask 077; printf '%s' "$SPARKLE_ED_PRIVATE_KEY" > "$tmp/ed.key" )
out=$("$tmp/sparkle/bin/sign_update" --ed-key-file "$tmp/ed.key" "$f")
sig=$(printf '%s' "$out" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
[ -n "$sig" ] || { echo "::error::sign_update produced no signature" >&2; exit 1; }
echo "$sig"
