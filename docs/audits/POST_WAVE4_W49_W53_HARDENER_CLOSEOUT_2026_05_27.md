# Post-Wave-4 W-49 / W-53 Hardener Closeout - 2026-05-27

Status: closed by existing code plus source/regression guards.

This audit was opened from
`docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`, which initially kept
W-49 and W-53 in the "next hardener" lane. Reading the current source showed
both hardeners are already present and tested. No source change is needed.

## W-49 - iMessage Driver App Store Guard

Verdict: closed.

Evidence:

- `Epistemos/Omega/iMessageDriver/IMessageDriverService.swift` is wrapped in
  `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `Epistemos/Omega/iMessageDriver/IMessageReplyDelegate.swift` is wrapped in
  the same direct-distribution guard.
- `Epistemos/Omega/iMessageDriver/IMessageNativeSetupDoctor.swift` is wrapped in
  the same direct-distribution guard.
- `Epistemos/Views/Settings/IMessageDriverSettingsView.swift` and
  `Epistemos/Views/Settings/ChannelsSettingsView.swift` are also wrapped in the
  same guard.
- `Epistemos/App/AppBootstrap.swift` stores and initializes
  `IMessageDriverService` only inside
  `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`.
- `Epistemos/App/AppEnvironment.swift` injects the channel registry and
  iMessage driver only in the direct-distribution branch.
- `Epistemos/Views/Settings/SettingsView.swift` hides channel/iMessage panes in
  App Store / MAS sandbox builds.

Regression guard:

- `EpistemosTests/CoreMASBoundarySourceGuardTests.swift`
  - `appStoreBuildsCompileOutNativeIMessageAutomationPaths`
  - verifies the driver/service/settings source files are fully guarded.
  - verifies the App Store target defines both `EPISTEMOS_APP_STORE` and
    `MAS_SANDBOX`.
  - verifies Settings routes App Store-only channel/iMessage cases to
    `GeneralDetailView()` rather than instantiating native panes.

## W-53 - ModelDownloadManager SHA256 / LFS Verification

Verdict: closed.

Evidence:

- `Epistemos/Engine/ModelDownloadManager.swift` downloads into a staging
  directory and only activates after snapshot and checksum verification.
- `verifyChecksums(...)` requires each weight file to have remote LFS metadata
  and a normalized 64-character SHA256 ETag before it can be marked verified.
- If SHA256/LFS metadata is absent, the install record is marked
  `unverifiedChecksum` rather than silently promoted.
- If the remote SHA256 does not match the staged file, installation throws
  `LocalModelManagerError.checksumMismatch` and the staging directory is
  cleaned.
- `LocalModelInstallRecord` carries `checksumVerification`.
- Settings surfaces `record.checksumVerification.displayLabel`.

Regression guards:

- `EpistemosTests/LocalModelInfrastructureTests.swift`
  - `installerRecordsChecksumStates`
  - covers verified SHA256, missing-hash unverified state, and checksum
    mismatch cleanup under isolated per-request fixtures.
  - source guards for installed model row checksum display.

## No-Orphan Check

- Motion: Project/Verify deployment and model artifact truth to Settings/tests.
- UAS: not a new data object; these are deployment and artifact-integrity
  guards for existing model/channel surfaces.
- Plane: Verification plane.
- Residency: App Store / MAS sandbox vs direct distribution is explicit.
- WBO/error: no approximation. Unknown checksum state remains unverified.
- Witness: source guards and install-integrity tests.
- Falsifier: App Store boundary source guard and model checksum tests.
- Tier: Current App / App Store floor; Pro-only iMessage remains direct
  distribution.
- Rollback: no runtime migration; failure path refuses install or hides the
  unavailable surface.

## Result

Do not dispatch a W-49/W-53 terminal unless one of these guards fails. The next
active terminals should be:

1. Agent Capability Truth.
2. Provenance / Residency Detail.

Then run `RESUME ACS ANCHOR HARNESS` or `RESUME METAL WITNESS GATES` depending
on whether the next push is product-floor or research-floor.
