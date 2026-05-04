# App Store / Direct Distribution Release Split Deliberation

Date: 2026-04-30
Queue item: 9
Classification: Both, release split audit only
Decision: Run release-split shell audits, entitlement/build-setting inspection, and automated validation where feasible. Do not edit entitlements, schemes, project files, or release metadata in this slice.

## Repo Evidence

- Branch: `feature/landing-liquid-wave`
- HEAD: `ac8c6d28`
- Worktree is very dirty and contains unrelated user/prior-agent changes, so this slice must not clean, stash, or broad-refactor.
- `Epistemos-AppStore` and `Epistemos` schemes both exist.
- `Epistemos-AppStore` build settings show:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.appstore`
  - `INFOPLIST_FILE = Epistemos-AppStore-Info.plist`
  - `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-AppStore.entitlements`
  - `SWIFT_ACTIVE_COMPILATION_CONDITIONS` includes `EPISTEMOS_APP_STORE` and `MAS_SANDBOX`
- `Epistemos` direct build settings show:
  - `PRODUCT_BUNDLE_IDENTIFIER = com.epistemos.app`
  - `INFOPLIST_FILE = Epistemos-Info.plist`
  - `CODE_SIGN_ENTITLEMENTS = Epistemos/Epistemos-Debug.entitlements`
  - `SWIFT_ACTIVE_COMPILATION_CONDITIONS` does not include `EPISTEMOS_APP_STORE` or `MAS_SANDBOX`
- `Epistemos/Resources/PrivacyInfo.xcprivacy` exists.

## Entitlement Evidence

- `Epistemos/Epistemos-AppStore.entitlements` is sandboxed and limited to:
  - app sandbox
  - network client
  - user-selected read/write files
  - app-scope bookmarks
  - JIT
- Direct entitlements include broader direct-distribution capabilities:
  - Apple Events
  - unsigned executable memory
  - disable library validation
  - document-scope bookmarks
  - accessibility mach lookup temporary exception
- Debug entitlements are narrower than direct release but not App Store sandboxed.

## Prior Gate Evidence

- Queue item 7 already built both schemes:
  - `/tmp/epistemos-appstore-gate-build-20260430.log`
  - `/tmp/epistemos-direct-gate-build-20260430.log`
- Queue item 7 also audited MAS/source gating for CLI/MCP/subprocess surfaces and verified `omega-mcp` / `agent_core` MAS feature behavior.

## Release Audit Skill Alignment

The Epistemos Release Audit skill is active for this item, but this is not a final ship call. Because the user explicitly deferred manual UI/runtime verification, this slice cannot produce `READY FOR DIRECT RELEASE`, `READY FOR DIRECT RELEASE, MAS LITE ONLY`, or any final release verdict.

## Alternatives Considered

- Edit entitlements or schemes now: rejected because the queue requires docs/logs first and release config changes need a dedicated gate.
- Claim MAS readiness from compile-only evidence: rejected because the release-audit skill requires manual/runtime verification and log correlation for a ship call.
- Run source/config audits and record a release-readiness matrix: accepted.

## Files Likely Touched

- `docs/fusion/deliberation/app_store_direct_release_split_deliberation_2026_04_30.md`
- `docs/fusion/BUILD_TEST_FLOOR_RESULTS_2026_04_30.md`

## Forbidden Files

- Do not edit `Epistemos.xcodeproj/project.pbxproj`.
- Do not edit `Epistemos/Epistemos-AppStore.entitlements`.
- Do not edit `Epistemos/Epistemos.entitlements`.
- Do not edit `Epistemos/Epistemos-Debug.entitlements`.
- Do not edit `Epistemos-AppStore-Info.plist`.
- Do not edit `Epistemos-Info.plist`.
- Do not introduce hidden network/cloud fallback or Pro tools in MAS.

## Planned Tests And Logs

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' build
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test
codesign -d --entitlements :- <built app>
plutil -p Epistemos/Epistemos-AppStore.entitlements
plutil -p Epistemos/Epistemos.entitlements
plutil -p Epistemos/Epistemos-Debug.entitlements
plutil -p Epistemos/Resources/PrivacyInfo.xcprivacy
```

Full-suite `xcodebuild test` may be long and may still expose unrelated dirty-worktree failures. If it fails, record exact blockers and do not call the branch release-ready.

## Manual Verification

- Deferred by user request.
- Required later before release readiness:
  - launch MAS profile
  - inspect settings/features
  - verify unsupported modes are absent, not merely disabled
  - verify Pro controls are hidden/unreachable in MAS
  - correlate runtime logs with visible behavior

## Rollback

- Revert only this deliberation doc and the fusion floor-log append.
- No source/config rollback should be required because this slice does not edit production or release config files.

## Stop Triggers

- App Store target references Pro-only symbols or launches hidden subprocesses.
- Unsupported model modes remain visible in MAS.
- Entitlements grant direct-only capabilities in the App Store target.
- Release config changes are proposed without a dedicated rationale.
- Full-suite test failures are release-split related and not documented.

## Gate Decision

Approved for shell audit, build/test validation, entitlement inspection, and documentation only. Not approved for release config edits or final release readiness claims.

## Results Summary

- App Store build passed:
  `/tmp/epistemos-release-split-appstore-build-20260430.log`
- Direct build passed:
  `/tmp/epistemos-release-split-direct-build-20260430.log`
- Build-setting logs:
  - `/tmp/epistemos-release-split-appstore-settings-20260430.log`
  - `/tmp/epistemos-release-split-direct-settings-20260430.log`
- App Store embedded audit showed sandboxed entitlements, MAS compile flags, MAS Info.plist identity, no `omega_ax` bundle/linkage, and MAS-stubbed Rust capability surfaces.
- Direct embedded audit showed direct-only entitlements, direct Info.plist identity/usage strings, `libomega_ax.dylib` present, and direct linkage to `libomega_ax`.
- Full-suite `xcodebuild test` was attempted and interrupted after a hang:
  - Log: `/tmp/epistemos-release-split-full-xcode-test-20260430.log`
  - Sample: `/tmp/epistemos-full-test-hang-sample-33021.txt`
  - The run reached live Swift Testing and passed many suites before blocking at `Contextual Shadows V0 is the production-mounted recall surface`.
  - Sample evidence shows the main thread blocked in `String(contentsOf:)` / kernel `open()` while the source guard test read repo files from `/Users/jojo/Downloads/Epistemos`.
- Follow-up before any release claim:
  - Resolve or route around the `Downloads` source-file access hang for full-suite tests.
  - Review App Store `ENABLE_APP_SANDBOX = NO` build setting versus embedded sandbox entitlement `true`.
  - Perform deferred MAS/direct runtime UI verification.
