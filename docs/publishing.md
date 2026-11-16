# Publishing a direct-download release

> **Draft pipeline.** Nothing below has run yet. Before the first release the operator adds the secrets, copies the
> source-repo workflow into the app repo, and makes the decisions listed at the end.

Yureisha is planned to ship two ways (operator decision, 2026-11-14; nothing has shipped yet): a **Mac App Store** build, which would update through the App
Store, and a **direct download** (Developer ID signed, notarized and stapled DMG) to be linked from
yureisha.io/download once the site is live. This repo is the public home of the direct download.
Everything is **Apple silicon (arm64) only**, and every CI job runs on GitHub's `macos-15` runner, which is arm64.
Intel (`macos-13`, `*-large`) and Linux runners are never used.

## Flow

```
yureisha-io/yureisha (private)                      yureisha-io/releases (public)
──────────────────────────────                      ─────────────────────────────
tag v1.2.3 ─▶ release-direct.yml (macos-15, arm64)
  build Yureisha.app, ARCHS=arm64
  sign: Developer ID Application, hardened runtime
  notarize app (notarytool) ─▶ staple
  Yureisha.dmg ─▶ sign ─▶ notarize ─▶ staple
  verify ─▶ upload artifact "yureisha-dmg"
  repository_dispatch "yureisha-release" ─────────▶ publish.yml (macos-15, arm64)
     {version, build, source_run_id, draft}           download artifact (YUREISHA_SOURCE_TOKEN)
                                                       verify: codesign --verify, spctl, stapler validate,
                                                               team id, arm64-only Mach-O, bundle version
                                                       sha256 ─▶ Yureisha.dmg.sha256
                                                       Sparkle sign_update (if SPARKLE_ENABLED)
                                                       gh release create v1.2.3 (draft by default)
                                                       not a draft? ─▶ appcast.xml item, commit to main
operator publishes the draft in the GitHub UI ────▶ appcast.yml: re-checks the DMG, adds the appcast item
```

- The release asset is always named `Yureisha.dmg`, so
  `https://github.com/yureisha-io/releases/releases/latest/download/Yureisha.dmg` always points at the newest
  published (non-draft, non-prerelease) release. yureisha.io/download links there.
- Tag pushes in the app repo always ask for a **draft** release. The operator reads the draft, edits the notes, then
  clicks **Publish release**, which triggers `appcast.yml`. A manual run of the source workflow (or of `publish.yml`)
  can set `draft: false`.
- `CHANGELOG.md` is edited by hand in a PR; the workflows never touch it.
- Release notes start from `docs/release-notes-template.md` (version, build, SHA-256 and minimum macOS are filled in).

## Set-up checklist (operator)

1. **Copy the source workflow.** Copy `docs/source-repo-workflow.yml` to `.github/workflows/release-direct.yml` in
   `yureisha-io/yureisha` once the other work there has landed. Check the scheme name, the XcodeGen project and the
   `yurei-tap` helper step against the app repo at that time.
2. **App repo secrets** (`yureisha-io/yureisha` → Settings → Secrets and variables → Actions):

   | Secret | What |
   |---|---|
   | `APPLE_TEAM_ID` | Developer ID team id |
   | `DEVELOPER_ID_APPLICATION_P12` | base64 of the *Developer ID Application* certificate + key (.p12) |
   | `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | its export password |
   | `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID`, `NOTARY_API_KEY_P8` | App Store Connect API key for `notarytool` (the `.p8` base64-encoded). The workflow stores it as the keychain profile `yureisha-notary` in a temporary keychain that's deleted at the end of the job. |
   | `RELEASES_DISPATCH_TOKEN` | fine-grained token, **Contents: read and write** on `yureisha-io/releases` only (needed for `repository_dispatch`) |

3. **Releases repo secrets and variables** (`yureisha-io/releases`):

   | Name | Kind | What |
   |---|---|---|
   | `YUREISHA_SOURCE_TOKEN` | secret | fine-grained token (or GitHub App), **Actions: read** on `yureisha-io/yureisha` only, to download the build artifact |
   | `APPLE_TEAM_ID` | secret | same team id; publish.yml refuses a DMG signed by any other team |
   | `SPARKLE_ED_PRIVATE_KEY` | secret | only if Sparkle is adopted: the EdDSA private key from Sparkle's `generate_keys -x` |
   | `SPARKLE_ENABLED` | variable | `true` once the shipped app contains Sparkle and the matching `SUPublicEDKey` |

   Never commit a key, certificate, password or token to either repo.
4. **Branch protection for `main`** here: allow `github-actions[bot]` to push `appcast.xml` (or switch the appcast
   steps to open a PR instead).

## Decisions still open (operator)

- **Sparkle or not.** The appcast and signing steps are ready, but the app doesn't contain Sparkle yet. Adopting it
  means adding the Sparkle package to the direct-download build only (the App Store build must not self-update),
  setting `SUFeedURL` and `SUPublicEDKey`, and storing the private key as `SPARKLE_ED_PRIVATE_KEY`. Until then items are
  written with `sparkle:edSignature="ED_SIGNATURE_PLACEHOLDER"`, which Sparkle would reject, so nothing auto-updates.
- **Feed URL.** `raw.githubusercontent.com/yureisha-io/releases/main/appcast.xml` works today; a `yureisha.io` URL
  would need a site/CDN change (operator-only). Whatever ships in `SUFeedURL` is hard to change later.
- **Minimum macOS.** To be announced. The workflows read `LSMinimumSystemVersion` from the built app and copy it into
  the appcast and the release notes, so deciding it in the app project is enough.
- **Version and build numbering.** The source workflow uses the tag for `MARKETING_VERSION` and the run number for
  `CURRENT_PROJECT_VERSION`. Keep build numbers monotonic and in step with the App Store build if both share them.
- **DMG window.** The workflow builds a plain DMG (app + Applications link). The branded background from the brand kit
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
