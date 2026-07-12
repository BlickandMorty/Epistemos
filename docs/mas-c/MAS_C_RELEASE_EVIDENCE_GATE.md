# MAS C Release Evidence Gate

ID: `MAS-C-RELEASE-GATE-2026-07-08`

This gate applies to every MAS C feature before it is treated as releasable.

## Source And Target Guards

Run targeted guards for the touched scope, then run broader MAS checks at
checkpoint boundaries. Never run competing `xcodebuild` jobs at the same time.

Required categories:

- App Store target membership audit.
- Entitlements audit.
- Privacy manifest audit.
- Parked-lane symbol and resource scan.
- MAS compile/test.
- Feature-specific source guards.
- Manual runtime proof for UI, storage, sync, source ingest, or permissions.

## Suggested Commands

Regenerate project when project files change:

```bash
xcodegen generate
```

Build MAS target:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' build 2>&1 | xcbeautify
```

Run MAS tests:

```bash
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -destination 'platform=macOS' test 2>&1 | xcbeautify
```

Inspect entitlements:

```bash
plutil -p Epistemos/Epistemos-AppStore.entitlements
```

Inspect privacy manifest:

```bash
plutil -p Epistemos/Resources/PrivacyInfo.xcprivacy
```

Scan a built app for parked-lane symbols and helper names:

```bash
APP=.derived-data-mas/Build/Products/Release/Epistemos.app
strings "$APP/Contents/MacOS/Epistemos" | rg -n 'OpenChamber|ExperimentalAgent|1Code|Kindred|goosed|goose |node|python|chromium|browser-use|stdio MCP'
find "$APP" -maxdepth 5 -type f | rg -n 'goose|goosed|node|python|chromium|OpenChamber|ExperimentalAgent|Kindred|1code'
```

Symbol names that remain for in-process MAS bridge compatibility must be
documented with owner gate, App Review explanation, and no-subprocess evidence.

## Evidence Pack Per Feature

Each feature should leave:

- intent checkpoint
- file list touched
- tests/builds run
- deferred verification-debt ledger, if batching occurred
- screenshots or manual notes for UI
- vault fixture before/after for storage edits
- source/legal table for external data
- App Review notes for entitlements, privacy, networking, and user data
- open risks

## Release Blockers

Block release if any are true:

- MAS archive contains a forbidden helper/runtime.
- App Store target links or bundles parked surface resources.
- Entitlement cannot be justified by live MAS behavior.
- Privacy manifest does not match current code.
- A source integration uses scraping, paywall bypass, forbidden data, or
  unapproved commercial API terms.
- Storage truth can diverge silently from vault files.
- Agent edits can write without approval, provenance, undo, or audit trail.

