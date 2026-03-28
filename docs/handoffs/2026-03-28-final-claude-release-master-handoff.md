# Final Claude Release Master Handoff

**Date:** 2026-03-28  
**Current source-of-truth commit:** `6994c784`  
**Audience:** Claude Code  
**Goal:** Re-check the exact work completed in the zero-corruption + release-hardening session, verify the current app state honestly, and decide whether the app is truly ready for public direct release.

---

## 1. Read These First

Read these in order before making any release claim:

1. [2026-03-28-codex-release-audit-handoff.md](/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-03-28-codex-release-audit-handoff.md)
2. [2026-03-28-zero-corruption-handoff-for-claude.md](/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-28-zero-corruption-handoff-for-claude.md)
3. [2026-03-28-codex-dead-code-cleanup.md](/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-03-28-codex-dead-code-cleanup.md)
4. [2026-03-28-distribution-decision-and-compliance-report.md](/Users/jojo/Downloads/Epistemos/docs/plans/2026-03-28-distribution-decision-and-compliance-report.md)
5. [2026-03-28-jojo-manual-release-checklist.md](/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-03-28-jojo-manual-release-checklist.md)
6. [2026-03-28-codex-claude-release-preservation-prompt.md](/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-03-28-codex-claude-release-preservation-prompt.md)

Treat older “ready for release” documents as historical inputs, not truth. The current repo state must be re-verified from disk.

---

## 2. What This Session Actually Changed

This session was not one small fix. It was a long hardening sweep that touched release packaging, runtime integrity, Swift concurrency cleanup, Rust FFI safety, and bundle correctness.

### Zero-corruption / integrity work that landed

- `NoteFileStorage` now uses hardened atomic writes, integrity sidecars, xattrs, quarantine flow, and NFC sanitization.
- Startup integrity checking was added and then moved behind a real pre-UI launch gate.
- Bookmark validation now participates in startup integrity before automatic restore.
- Recovery snapshots stopped hot-copying live SQLite files and now use SQLite backup behavior for real databases.
- APFS safety snapshot requests and retention tracking were added on the destructive recovery path.
- Search index and event store SQLite configuration were hardened around WAL / `synchronous=FULL` / integrity check.
- Idle maintenance now includes a passive search-index WAL checkpoint path.
- The sanitize-and-normalize Rust export now throws typed errors instead of using an empty-string sentinel.

### Swift / Rust / UniFFI hardening that landed

- Raw `libc::fsync` fallback was removed from the Rust durability export path.
- Exported Rust recall-index access no longer uses `lock().unwrap()`.
- Release Rust profiles are configured with `panic = "abort"`.
- Generated UniFFI Swift bindings are patched for Swift 6 default MainActor isolation.
- The generated Omega binding pointer deinit race was fixed in the patcher path, not by hand-editing generated Swift.
- Production `@unchecked Sendable` usages in the touched surfaces were removed or narrowed into safer patterns.

### Release packaging / artifact correctness work that landed

- Runtime Knowledge Fusion assets are now explicitly bundled into the app via `bundle-app-runtime-assets.sh`.
- Rust outputs were moved to universal macOS binaries (`arm64` + `x86_64`) using `lipo`.
- Omega crates now embed as `.dylib`s instead of stale static archive paths.
- Runtime dylib loading was tightened to the signed bundle-local `Contents/Frameworks` path instead of unstable external copies.
- A new `embed-and-sign-rust-dylib.sh` helper now signs embedded Rust dylibs during Xcode app builds, fixing the “The executable is not codesigned” launch failure for fresh Debug bundles.

### Test / audit work that landed

- Runtime validation tests were expanded to protect the new build graph and signing strategy.
- Targeted regressions were added around packaging, SQLite backup behavior, runtime assets, and startup integrity.
- ASan exposed a real UTF-8 test bug, and that test is now fixed.
- TSan remains blocked at mixed Swift/Rust link time; this is still unresolved.

---

## 3. Current Evidence Already Established

This evidence was gathered in the current branch and should be rechecked, not blindly trusted:

### Clean state

- current commit: `6994c784`
- last major code hardening commit before the handoff-only follow-up: `b99f0337`
- repo was committed clean after the latest changes

### Rust

- `epistemos-core` tests passed
- `graph-engine` tests passed
- `omega-mcp` tests passed
- `omega-ax` tests passed

### Swift / app

- the new repeatable preflight passed end to end:
  - `./scripts/audit/release_preflight.sh /tmp/epistemos-release-preflight-final`
- a fresh Debug app build succeeded with:
  - `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/epistemos-signfix build`
- the resulting app bundle passed:
  - `codesign --verify --deep --strict --verbose=4 /tmp/epistemos-signfix/Build/Products/Debug/Epistemos.app`
  - `codesign --verify --deep --strict --verbose=4 /tmp/epistemos-release-preflight-final/Build/Products/Debug/Epistemos.app`
- the app bundle contents were verified to include:
  - `Contents/Frameworks/libepistemos_core.dylib`
  - `Contents/Frameworks/libomega_mcp.dylib`
  - `Contents/Frameworks/libomega_ax.dylib`
  - `Contents/Resources/model_manifest.json`
  - `Contents/Resources/RetroGaming.ttf`
  - `Contents/Resources/PrivacyInfo.xcprivacy`
  - `Contents/Resources/KnowledgeFusion/...` runtime files
- `Contents/PlugIns` was absent in the fresh app bundle
- direct launch of the fresh signed app stayed alive for the sample window
- `RuntimeValidationTests` passed after the final signing-path change

### Important caveat

The latest step was **not** a full 3-pass re-certification after the final embedded-dylib signing fix. It was a targeted, high-signal verification pass. Do not claim fresh full public-release certification unless you rerun the full release-audit workflow now.

---

## 4. Release Verdict Right Now

### Honest current status

**Best current label:** `PRE-NOTARIZATION DIRECT-RELEASE CANDIDATE`

What that means:

- the codebase is materially hardened
- the local app bundle now builds, signs, launches, and contains the important runtime assets
- the known fresh local launch/signing blocker is fixed
- the repo is in much better shape for direct distribution than it was at the start of the session

What it does **not** mean:

- it is not yet proven ready for public release until direct-distribution steps are completed
- it is not yet proven by a fresh end-to-end new-user install flow
- it is not ready for Mac App Store full distribution

### My recommendation for Claude

Unless you independently rerun the full release audit and external packaging checks, do **not** say `READY FOR DIRECT RELEASE` yet. Say something closer to:

`Close to direct release, but final public-release signoff still depends on Developer ID signing, notarization, DMG packaging, and fresh-machine/new-user verification.`

---

## 5. Biggest Remaining Work

### External release tasks still required

- Apple Developer enrollment if not already active
- `Developer ID Application` signing setup
- notarization setup and notarization pass
- DMG packaging
- hosted privacy policy URL
- hosted support URL
- GitHub Release or equivalent download hosting

### Manual release-risk verification still required

- fresh-machine or fresh-user-account install test from packaged DMG
- first-launch permission flow
- model/runtime asset discovery after install
- Omega/browser/AX/Terminal permissions and tool flows
- note AI stream / accept / discard / reopen
- any direct-distribution updater or license path, if used

### Code-adjacent but still real follow-up

- dead code cleanup in [2026-03-28-codex-dead-code-cleanup.md](/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-03-28-codex-dead-code-cleanup.md)
- zero-corruption future architecture items still listed in the zero-corruption handoff
- TSan mixed Swift/Rust link blocker still unresolved

---

## 6. Build Method Guidance

### Yes, you still build in Xcode

For normal development, local runs, and most iteration:

- keep using Xcode
- keep using the `Epistemos` scheme
- keep `Run` on `Debug`

The project is set up so Xcode builds the Rust components, patches UniFFI bindings, bundles runtime assets, embeds the dylibs, and ad hoc signs a launchable local app.

### But release readiness should not depend on “just clicking Run”

To preserve readiness, use the scripted preflight:

- [release_preflight.sh](/Users/jojo/Downloads/Epistemos/scripts/audit/release_preflight.sh)

That script runs the high-signal recurring checks:

- `git diff --check`
- all 4 Rust test suites
- fresh Debug app build into isolated DerivedData
- `RuntimeValidationTests`
- deep codesign verification on the resulting app
- required runtime-asset presence checks
- plugin-noise absence check

This is the new minimum repeatable release-preservation method.

---

## 7. What Claude Should Do Next

1. Run [release_preflight.sh](/Users/jojo/Downloads/Epistemos/scripts/audit/release_preflight.sh) and confirm it still passes on the current branch.
2. Use the repo’s release-audit skill and perform a true fresh release pass.
3. Re-check the direct-distribution decision from the compliance report.
4. Verify whether a real Developer ID / notarization / DMG flow now exists, or document the exact remaining gap.
5. Use [2026-03-28-codex-dead-code-cleanup.md](/Users/jojo/Downloads/Epistemos/docs/handoffs/2026-03-28-codex-dead-code-cleanup.md) for the cleanup lane after release-critical verification.
6. Produce an updated final verdict using one of:
   - `READY FOR DIRECT RELEASE`
   - `NOT READY`

If you cannot fully certify public release, say why plainly.
