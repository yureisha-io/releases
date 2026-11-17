# Yureisha releases

The planned public release channel for the **direct download** of Yureisha, a native macOS app by Black Mesa Lab
that is still in development. A Mac App Store build is also planned; if it ships, it will update through the App Store
and will not be published here.

> **Status: draft. Yureisha has not been released.** No build has been published here or on the Mac App Store, and
> the website is not live yet. The pipeline in this repo needs the operator to add signing, notarization and
> (optionally) Sparkle secrets before the first release. See [docs/publishing.md](docs/publishing.md).

## Download

There is nothing to download yet. Once the first version is published, it will be at
<https://github.com/yureisha-io/releases/releases/latest/download/Yureisha.dmg>, with every version and its release
notes under [Releases](https://github.com/yureisha-io/releases/releases) and in [CHANGELOG.md](CHANGELOG.md).

**Will require a Mac with Apple silicon.** Yureisha is built for arm64 only; Intel Macs are not supported.
Minimum macOS version: to be announced.

## Verifying a download

When releases begin, every disk image will be signed with Black Mesa Lab's Developer ID, notarized by Apple and
stapled, and the publish script refuses to release one that isn't. Each release will list the SHA-256 of
`Yureisha.dmg` and attach it as `Yureisha.dmg.sha256`.

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
| `scripts/publish.sh` | Verifies a signed, notarized DMG, creates the GitHub Release and opens the `appcast.xml` PR. Runs locally on Darwin arm64; there is no CI on GitHub. |
| `AGENTS.md` | The containers-only and no-CI-on-GitHub rules. |
| `scripts/appcast.py` | Inserts a release into `appcast.xml` (Python standard library only). |

Security reports: see [SECURITY.md](https://github.com/yureisha-io/.github/blob/main/SECURITY.md).
