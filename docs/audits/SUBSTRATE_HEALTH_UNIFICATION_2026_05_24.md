# Substrate Health Unification Audit - 2026-05-24

Terminal: D
Track: P6 + T22 + W-29
Tier: Tier 1 MAS
Primary law: Law 7 Witness

## Audit

Settings previously mixed substrate rows into the general Diagnostics section, which made fixture, status-only, and production-wired states visually easy to misread. Terminal D moved the substrate cluster into one Settings destination and kept row-level evidence explicit.

Rows unified under `SubstrateHealthPanel`:

- Eidos, Vault Recall, Search Fusion, Editor Bundle
- Local Agent Diagnostics, Active Constellation, System G, AnswerPacket
- F-ULP, Lattice/WBO, ACS Admission, EML Observatory, UAS/ACS, Cognitive DAG Counts, Plane Placement, Cognitive Weight Classes, Substrate Drift Monitor

## Build

Implemented:

- `substrate_health_unified_json()` in `agent_core/src/bridge.rs`.
- New Swift support mirror: `SubstrateHealthSupport.swift`.
- New rows: `EmlObservatoryHealthRow`, `UasAcsHealthRow`, `CognitiveDagCountsHealthRow`, `PlanePlacementHealthRow`, `CognitiveWeightClassHealthRow`, `SubstrateDriftMonitorHealthRow`.
- 1 Hz refresh on new rows and existing substrate rows.
- Shared falsifier links below every panel row.
- W-30 W1-W4 cognitive-weight badges.
- W-33 drift monitor readout combining WBO accounting, DAG root, and UAS copy counters.

## Verify

Passed:

- `RUSTUP_TOOLCHAIN=stable cargo +stable test --manifest-path agent_core/Cargo.toml substrate_health_unified_json_surfaces_honest_terminal_g_dependency`
- `RUSTUP_TOOLCHAIN=stable CONFIGURATION=Debug TARGET_NAME=Epistemos bash build-agent-core.sh`
- `git diff --check` over the Terminal D file set.

Attempted:

- `RUSTUP_TOOLCHAIN=stable xcodebuild -scheme Epistemos -destination 'platform=macOS' build` stopped on local signing: missing `Mac Development` certificate for team `3BNL2669SL`.
- `RUSTUP_TOOLCHAIN=stable xcodebuild -scheme Epistemos -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build` reached Swift compile and failed in an unrelated dirty-worktree batch containing `Epistemos/App/ChatCoordinator.swift`. The current worktree also contains unrelated Terminal B/E edits and active Xcode/cargo jobs, so no Terminal D source failure was isolated from that run.

Live screenshot: not captured in this dirty multi-terminal worktree because the app build could not produce a launchable signed product here. This is an explicit acceptance gap, not a claimed pass.

## Harden

Honest posture rules applied:

- No missing subsystem reports green.
- EML Observatory reports FFI reachability but keeps SAE live stream unwired.
- UAS/ACS reports taxonomy, residency, and copy counters but keeps production anchor lookup blocked.
- Plane Placement is green only when Terminal G / T14 five-plane fields are
  present and counted through `substrate_health_unified_json`; otherwise the
  row degrades to FFI-unavailable or dependency-blocked state.
- Cognitive Weight badges are visible taxonomy only; policy enforcement remains unwired.
- Drift Monitor is monitor-only until an F-WBO-DriftLedger PASS artifact exists.

## 7 Laws

- Law 1 Density: one dense panel replaces scattered diagnostic rows.
- Law 2 Address: UAS/ACS and DAG rows expose address taxonomy, residency tiers, and root identity instead of anonymous status.
- Law 3 Active-support: 1 Hz refresh keeps rows live without claiming active authority where only read-only probes exist.
- Law 4 Lattice-error: Lattice/WBO and drift rows surface accounting and non-pass state.
- Law 5 Glue: Settings links each row to its falsifier and W-row.
- Law 6 Duplex: MAS UI observes Rust substrate state through FFI without adding hidden cloud fallback.
- Law 7 Witness: every row carries chip-strip posture and falsifier evidence.

## No-Orphan Check

Data classes touched:

- Settings substrate health snapshots
- UAS/ACS taxonomy and copy counters
- Cognitive DAG counts and Merkle root
- Plane placement summary
- WBO drift/accounting counters
- AnswerPacket and agent runtime health surfaces

Five invariants:

- UAS address: surfaced through UAS/ACS taxonomy and DAG root; no new orphan payload class is created.
- Plane: PlanePlacement row counts live DAG planes after Terminal G/T14 lands;
  unavailable FFI falls back to an explicit non-green state.
- Residency: UAS row shows `current_app`, `verified_floor`, and `capability_ceiling` residency tags.
- WBO if approximate: Lattice/WBO and Drift Monitor show WBO accounting and never mark F-WBO pass by default.
- WRV if product-facing: all rows in the panel include `VerifiedFloorChipStrip` and falsifier links.

Waiver:

- Before Terminal G/T14, Plane Placement had a dependency waiver. On the T14
  branch this waiver is retired for DAG `NodeKind` plane counts only; model
  internals and KV runtime telemetry remain out of scope.

## W-Rows and Falsifiers

Advanced:

- W-07 EML Observatory
- W-10 UAS/ACS and Plane Placement dependency visibility
- W-24 DAG node UAS/ACS anchor fields
- W-28 live DAG plane-placement visibility
- W-14 AnswerPacket witness channel
- W-21 Vault Recall
- W-26 Cognitive DAG Counts
- W-29 Substrate Health Panel unification
- W-30 Cognitive Weight Classes
- W-33 Substrate Drift Monitor

Linked/unblocked for visibility:

- `docs/falsifiers/F-ULP-Oracle_2026_05_17.md`
- `docs/falsifiers/F-UAS-ZeroCopy-Spine_2026_05_17.md`
- `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md`
- `docs/falsifiers/F-ACS-AnchorLookup_2026_05_24.md`
- `docs/falsifiers/F_WBO_DRIFT_LEDGER_2026_05_18.md`
- `docs/falsifiers/F-VaultRecall-50_2026_05_17.md`
- `docs/falsifiers/F_EIDOS_CLOSED_CITATION_2026_05_18.md`
- `docs/falsifiers/F-ActiveAssembly-Minimal_2026_05_17.md`
- `docs/falsifiers/F-ShadowFirst-PageEscalation_2026_05_17.md`

## Tier Report

- Tier 1 MAS: Settings panel, read-only FFI snapshot, WRV chip strips, falsifier links.
- Tier 2 Pro flagged-off: no Pro runtime path added.
- Tier 3 Research: EML research-only observatory calls remain feature-gated; MAS fallback reports no live stream.
- Vault: no speculation promoted; model-internal neural assembly telemetry
  remains outside the MAS plane-placement claim.
