<!--
Release notes template. The publish workflow uses this file when a release is dispatched without notes:
{{VERSION}}, {{BUILD}}, {{SHA256}} and {{MIN_MACOS}} are filled in. Write in the Yureisha voice (BRAND.md §3):
state first, then what changed, then what's needed from the reader. No exclamation marks, no emoji, no prices, no dates
that aren't the release date.
-->
## Yureisha {{VERSION}} ({{BUILD}})

**Requires a Mac with Apple silicon** (arm64 only) and macOS {{MIN_MACOS}} or later.

### New
- 

### Improved
- 

### Fixed
- 

### Known issues
- None.

---

**Download:** `Yureisha.dmg` below, signed with Black Mesa Lab's Developer ID, notarized by Apple and stapled.

**SHA-256:** `{{SHA256}}`

Check it with `shasum -a 256 -c Yureisha.dmg.sha256`. Mac App Store customers get this update from the App Store.
