#!/usr/bin/env python3
"""Insert one release into appcast.xml (Sparkle 2 format), newest first. Standard library only.

  python3 scripts/appcast.py --version 1.0.0 --build 1 --length 12345678 \
      --min-macos 15.0 --ed-signature <base64 or ED_SIGNATURE_PLACEHOLDER> [--appcast appcast.xml]

The enclosure URL and release-notes link point at this repo's GitHub Release for tag v<version>.
Every item is Apple silicon only (sparkle:hardwareRequirements arm64). Re-running for a version that is already in the
feed fails, so a published item is never rewritten.
"""
import argparse
import email.utils
import pathlib
import sys
from xml.sax.saxutils import escape, quoteattr

REPO = "yureisha-io/releases"
MARKER = "<!-- ITEMS: newest first; scripts/appcast.py inserts below this line -->"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="marketing version, e.g. 1.0.0 (CFBundleShortVersionString)")
    ap.add_argument("--build", required=True, help="build number (CFBundleVersion); Sparkle compares this")
    ap.add_argument("--length", required=True, type=int, help="DMG size in bytes")
    ap.add_argument("--min-macos", required=True, help="LSMinimumSystemVersion of the app, e.g. 15.0")
    ap.add_argument("--ed-signature", required=True, help="sign_update's edSignature, or a placeholder")
    ap.add_argument("--appcast", default="appcast.xml")
    a = ap.parse_args()

    path = pathlib.Path(a.appcast)
    text = path.read_text()
    if MARKER not in text:
        sys.exit(f"{path}: ITEMS marker not found")
    tag = f"v{a.version}"
    url = f"https://github.com/{REPO}/releases/download/{tag}/Yureisha.dmg"
    if url in text:
        sys.exit(f"{path}: {tag} is already in the feed")

    item = f"""
    <item>
      <title>Version {escape(a.version)}</title>
      <pubDate>{email.utils.formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{escape(a.build)}</sparkle:version>
      <sparkle:shortVersionString>{escape(a.version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{escape(a.min_macos)}</sparkle:minimumSystemVersion>
      <sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>
      <sparkle:releaseNotesLink>https://github.com/{REPO}/releases/tag/{tag}</sparkle:releaseNotesLink>
      <enclosure url={quoteattr(url)} length="{a.length}" type="application/octet-stream"
                 sparkle:edSignature={quoteattr(a.ed_signature)} />
    </item>"""
    path.write_text(text.replace(MARKER, MARKER + item, 1))
    print(f"{path}: added {tag} (build {a.build})")


if __name__ == "__main__":
    main()
