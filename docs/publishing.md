# Publishing a direct-download release

> **Draft pipeline.** Nothing below has run yet. Before the first release the operator settles the app repo's
> local build-and-sign path and makes the decisions listed at the end.

Yureisha is planned to ship two ways (operator decision, 2026-11-14; nothing has shipped yet): a **Mac App Store** build, which would update through the App
Store, and a **direct download** (Developer ID signed, notarized and stapled DMG) to be linked from
yureisha.io/download once the site is live. This repo is the public home of the direct download.
Everything is **Apple silicon (arm64) only**.

**No CI on GitHub** (operator, 2026-11-16: "ci in github* nothing should ever be there in any project"; "we should be
running ci locally, using yureisha"). There are no GitHub Actions workflows here and Actions is disabled. Every step
runs locally on Darwin arm64: in a native k3sm pod or through the yurei build queue. The old draft workflows
(`publish.yml`, `appcast.yml` and the app-repo template `docs/source-repo-workflow.yml`) were removed. Git history has
them at commit `a553449`.

## Flow

```
yureisha-io/yureisha (private)                      yureisha-io/releases (public)
──────────────────────────────                      ─────────────────────────────
local release (yurei build queue, Darwin arm64)
  build Yureisha.app, ARCHS=arm64
  sign: Developer ID Application, hardened runtime
  notarize app (notarytool) ─▶ staple
  Yureisha.dmg ─▶ sign ─▶ notarize ─▶ staple
  verify ─▶ dist/Yureisha.dmg ────────────────────▶ scripts/publish.sh --dmg … --version … --build …
                                                       verify: codesign --verify, spctl, stapler validate,
                                                               team id, arm64-only Mach-O, bundle version
                                                       sha256 ─▶ Yureisha.dmg.sha256
                                                       Sparkle sign_update (if SPARKLE_ENABLED)
                                                       gh release create v1.2.3 (draft by default)
                                                       --publish? ─▶ appcast.xml item, opened as a PR
operator publishes the draft in the GitHub UI, then
scripts/publish.sh --appcast-only --version 1.2.3 ─▶ re-checks the DMG, opens the appcast PR
```

- The release asset is always named `Yureisha.dmg`, so
  `https://github.com/yureisha-io/releases/releases/latest/download/Yureisha.dmg` always points at the newest
  published (non-draft, non-prerelease) release. yureisha.io/download links there.
- Releases start as **drafts**. The operator reads the draft, edits the notes, then clicks **Publish release** and runs
  `scripts/publish.sh --appcast-only`. `--publish` skips the draft.
- `appcast.xml` changes always land through a pull request; nothing pushes to `main`.
- `CHANGELOG.md` is edited by hand in a PR; the scripts never touch it.
- Release notes start from `docs/release-notes-template.md` (version, build, SHA-256 and minimum macOS are filled in).

## Set-up checklist (operator)

1. **App repo build-and-sign path.** The build → sign → notarize → staple half belongs to `yureisha-io/yureisha` and
   runs locally through the yurei build queue (never a hosted runner). It needs the Developer ID Application
   certificate and a notarytool profile on the Mac or session host that runs it. That is a credential decision for
   the operator.
2. **Environment for `scripts/publish.sh`** (values are never stored in this repo):

   | Name | What |
   |---|---|
   | `APPLE_TEAM_ID` | the Developer ID team id; publish.sh refuses a DMG signed by any other team |
   | `SPARKLE_ENABLED` | `true` once the shipped app contains Sparkle and the matching `SUPublicEDKey` |
   | `SPARKLE_ED_PRIVATE_KEY` | only if Sparkle is adopted: the EdDSA private key from Sparkle's `generate_keys -x` |
   | `SPARKLE_SHA256` | only if Sparkle is adopted: the pinned sha256 of `Sparkle-<SPARKLE_VERSION>.tar.xz`; the tarball is refused without a match |

   Never commit a key, certificate, password or token to either repo.

## Decisions still open (operator)

- **Sparkle or not.** The appcast and signing steps are ready, but the app doesn't contain Sparkle yet. Adopting it
  means adding the Sparkle package to the direct-download build only (the App Store build must not self-update),
  setting `SUFeedURL` and `SUPublicEDKey`, and storing the private key as `SPARKLE_ED_PRIVATE_KEY`. Until then items are
  written with `sparkle:edSignature="ED_SIGNATURE_PLACEHOLDER"`, which Sparkle would reject, so nothing auto-updates.
- **Feed URL.** `raw.githubusercontent.com/yureisha-io/releases/main/appcast.xml` works today; a `yureisha.io` URL
  would need a site/CDN change (operator-only). Whatever ships in `SUFeedURL` is hard to change later.
- **Minimum macOS.** To be announced. `scripts/publish.sh` reads `LSMinimumSystemVersion` from the built app and copy it into
  the appcast and the release notes, so deciding it in the app project is enough.
- **Version and build numbering.** The app repo's release path sets `MARKETING_VERSION` from the tag and
  `CURRENT_PROJECT_VERSION` from its build counter. Keep build numbers monotonic and in step with the App Store build if both share them.
- **DMG window.** The app repo's release path builds a plain DMG (app + Applications link). The branded background from the brand kit
  (`dmg-background*`, BRAND.md §12) can be added with a Finder layout step later.
- **Prereleases.** Not wired up. A beta channel would use `--prerelease` releases and a separate appcast (or Sparkle
  channels).

## Verifying by hand

```sh
gh release download v1.2.3 -R yureisha-io/releases -p 'Yureisha.dmg*'
shasum -a 256 -c Yureisha.dmg.sha256
codesign --verify --strict --verbose=2 Yureisha.dmg
spctl -a -t open --context context:primary-signature -v Yureisha.dmg
xcrun stapler validate Yureisha.dmg
```
