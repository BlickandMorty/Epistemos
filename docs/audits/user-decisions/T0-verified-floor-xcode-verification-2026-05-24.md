# T0 Verified Floor Xcode Verification Blocker

Date: 2026-05-24

Status: DECISION NEEDED

## Blocker

The Phase 2 Terminal T0 verified-floor implementation is wired and the source-level gates pass, but the final focused Xcode test run is blocked by local machine state:

- `/` reports 119 MiB available and 100% capacity.
- A fresh DerivedData path previously failed while compiling dependencies because the filesystem was full.
- The default Xcode path previously reported a build database lock.
- A normal signed test run also fails before compilation because the Mac Development signing certificate for team `3BNL2669SL` is not installed in this environment.

## Decision Needed

Pick one unblock path before rerunning the focused Xcode test:

1. Free several GB of local disk and rerun the focused test with signing disabled.
2. Authorize cleanup of the relevant Xcode DerivedData/build-cache directories, then rerun the focused test with signing disabled.
3. Install the missing signing certificate and free disk, then rerun the standard signed test path.

Recommended path: option 1. It avoids deleting unrelated local build caches and is enough for the focused `VerifiedFloorChipStripAuditTests` compile/test gate.

## Current Verified Gates

- Settings health-row source audit: 26 rows scanned, 0 green chip-strip violations.
- Dishonest green probe: detected.
- Doctrine lint: PASS, including T25 naming reconciliation.
- Rust lint unit tests: 12 passed.
- `git diff --check`: PASS.
