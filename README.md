# Yureisha releases

The public release channel for the **direct download** of [Yureisha](https://yureisha.io), the native macOS app by
[Black Mesa Lab](https://blackmesalab.com). Yureisha is also on the Mac App Store; App Store builds update through
the App Store and are not published here.

> **Status: draft.** No build has been published yet. The pipeline in this repo needs the operator to add signing,
> notarization and (optionally) Sparkle secrets before the first release. See [docs/publishing.md](docs/publishing.md).

## Download

- **Latest:** <https://github.com/yureisha-io/releases/releases/latest/download/Yureisha.dmg>
  (the same file [yureisha.io/download](https://yureisha.io/download/) links to)
- **All versions and release notes:** [Releases](https://github.com/yureisha-io/releases/releases) and
  [CHANGELOG.md](CHANGELOG.md)

**Requires a Mac with Apple silicon.** Yureisha is built for arm64 only; Intel Macs are not supported.
Minimum macOS version: to be announced.

## Verifying a download

Every disk image is signed with Black Mesa Lab's Developer ID, notarized by Apple and stapled. Each release lists the
SHA-256 of `Yureisha.dmg` and attaches it as `Yureisha.dmg.sha256`.

```sh
shasum -a 256 -c Yureisha.dmg.sha256          # matches the published checksum
spctl -a -t open --context context:primary-signature -v Yureisha.dmg   # "accepted, source=Notarized Developer ID"
xcrun stapler validate Yureisha.dmg            # "The validate action worked!"
```

## What's in this repo

| Path | What it is |
|---|---|
| `appcast.xml` | The update feed (Sparkle format). One `<item>` per published version, newest first. |
| `CHANGELOG.md` | Human-readable history of every direct-download release. |
| `docs/release-notes-template.md` | The template each release's notes start from. |
| `docs/publishing.md` | How a release gets from the app repo to here, the secrets it needs and the open decisions. |
| `docs/source-repo-workflow.yml` | The build → sign → notarize → hand-off workflow for the (private) app repo, to copy there later. |
| `.github/workflows/publish.yml` | Verifies a signed, notarized DMG, creates the GitHub Release and updates `appcast.xml`. |
| `scripts/appcast.py` | Inserts a release into `appcast.xml` (Python standard library only). |

Security reports: see [SECURITY.md](https://github.com/yureisha-io/.github/blob/main/SECURITY.md). Help:
[yureisha.io/support](https://yureisha.io/support/).
