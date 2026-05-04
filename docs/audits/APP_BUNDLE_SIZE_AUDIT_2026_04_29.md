# App Bundle Size Audit - 2026-04-29

Scope: automated bundle-size probe after Patch 44's `.epdoc` editor resource prune. This is not a final App Store size claim because the Release build could not complete under current disk pressure.

## Verdict

Partial PASS for the `.epdoc` editor resource payload. BLOCKED for final Release-size proof.

## Evidence

- Patch 44 gate: `/tmp/epistemos_tiptap_bundle_prune_patch44_gate.log`
  - Source `Epistemos/Resources/Editor`: 1.1M
  - Built Debug MAS `Contents/Resources/Editor`: 1.1M
  - No root-level flattened editor duplicates
  - No stale plain JS/CSS counterparts for `.br` assets
  - No KaTeX `.ttf` or `.woff` files
- First Debug MAS size probe: `/tmp/epistemos_mas_bundle_size_audit_patch45_probe.log`
  - Invalid as a shipping-size baseline because it used an existing DerivedData app contaminated by `EpistemosTests.xctest` and XCTest frameworks.
- Clean Debug MAS build marker: `/tmp/epistemos_mas_size_audit_fresh_build_patch45.log`
  - Contains `** BUILD SUCCEEDED **`.
  - Wrapper exit was not authoritative because the command used Bash `PIPESTATUS` under zsh and ended with `PIPESTATUS[0]: parameter not set`.
- Clean Debug MAS size probe: `/tmp/epistemos_mas_bundle_size_audit_patch45_clean_probe.log`
  - `TEST_PLUGIN_PRESENT:0`
  - App bundle: 650M
  - `Contents/MacOS`: 404M
  - `Contents/Frameworks`: 237M
  - `Contents/Resources`: 8.6M
  - Largest files:
    - `Contents/MacOS/Epistemos.debug.dylib`: 404M
    - `Contents/Frameworks/libagent_core.dylib`: 103M
    - `Contents/Frameworks/libepistemos_shadow.dylib`: 75M
    - `Contents/Frameworks/libepistemos_core.dylib`: 40M
    - `Contents/Frameworks/libomega_mcp.dylib`: 10M
- Release MAS size build attempt: `/tmp/epistemos_mas_release_size_audit_build_patch45.log`
  - Failed before size measurement with `No space left on device` while extracting package artifacts.
  - xcodebuild exit: 74.
- Disk cleanup:
  - Removed only the temporary DerivedData directories created by this audit:
    - `/tmp/epistemos-mas-size-audit-dd`
    - `/tmp/epistemos-mas-release-size-audit-dd`
  - After cleanup: `/tmp/epistemos_patch45_disk_pressure_after_cleanup.log` shows 6.2Gi free.

## Findings

| Severity | Finding | Evidence | Required action |
|---|---|---|---|
| P1 | Final Release app size is still unproven | Release build failed with disk pressure before product size could be measured | Re-run Release App Store build with enough free disk and capture top-resource table |
| P1 | Debug app size is dominated by debug binary/Rust dylibs, not resources | Clean Debug probe: 404M `Epistemos.debug.dylib`, 237M `Frameworks`, 8.6M `Resources` | Do not optimize resource files further until Release proof shows they matter |
| P2 | First size probe was contaminated by test artifacts | `EpistemosTests.xctest` and XCTest frameworks were present in reused DerivedData app | Use fresh DerivedData for every size audit |
| P2 | `.epdoc` editor resources are no longer a top bundle-size concern | Clean Debug resources show `Editor` at 1.1M | Lazy chunking/tree-shaking remains optional performance work, not immediate size-blocker |

## Next Gate

Run a Release App Store size proof only after freeing enough disk:

```bash
bash -lc 'set -euo pipefail
DD=/tmp/epistemos-mas-release-size-audit-dd
LOG=/tmp/epistemos_mas_release_size_audit_build.log
rm -rf "$DD"
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos-AppStore -configuration Release -destination "platform=macOS" -derivedDataPath "$DD" build CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
printf "EXIT:%s\n" "$rc" | tee -a "$LOG"
exit "$rc"'
```

Then capture:

```bash
APP=/tmp/epistemos-mas-release-size-audit-dd/Build/Products/Release/Epistemos.app
du -sh "$APP" "$APP/Contents"/*
find "$APP" -type f -size +10M -print0 | xargs -0 du -h | sort -hr | head -n 80
du -sh "$APP/Contents/Resources"/* 2>/dev/null | sort -hr | head -n 80
du -sh "$APP/Contents/Frameworks"/* 2>/dev/null | sort -hr | head -n 80
```
