# Cognitive DAG Visualizer - 2026-05-27

Status: Wave 4 follow-up slice, read-only UI projection.

## Scope

This slice adds a lightweight canvas overlay that shows live Cognitive DAG node and edge totals plus the top node/edge kind counts exposed by `SubstrateHealthUnifiedClient.snapshot()`.

It does not mutate retrieval, claims, notes, graph physics, or editor state.

## No-Orphan Check

Motion: Project / Compress / Recall. The Rust substrate count snapshot is projected into a compact graph surface.

UAS: The panel reads the existing Cognitive DAG count mirror carried by unified substrate health. It does not mint new addresses.

Plane: Verification/UI plane. The panel is an observability surface for W-26, not an execution path.

Residency: CurrentApp SwiftUI overlay backed by the in-process Rust FFI snapshot. No subprocess or remote path.

WBO: No approximation budget is claimed. The displayed values are direct counts and a shortened Merkle root preview.

Witness: `substrate_health_unified_json` remains the source witness. Swift source guards assert the panel reads that snapshot, updates at 1 Hz, and stays outside `MetalGraphView`.

Falsifier: `F-ACS-Anchor-Addressing` remains the named DAG-addressing falsifier. This panel is intentionally read-only and should stay orange/status-only until product-path measurement says otherwise.

Tier: T1 MAS-safe because it is UI-only, read-only, and has no data migration.

Rollback: Remove `CognitiveDagVisualizerPanel.swift`, its graph-route mount, this audit doc, and the focused tests. No persisted data is changed.

## Performance Guardrails

- The overlay is mounted by `GraphWorkspaceContainer`, not by `MetalGraphView`.
- The model refreshes at 1 Hz with `Task.sleep`, not per frame.
- Rows are pre-sorted and capped to five node kinds and five edge kinds.
- The panel only assigns SwiftUI state when the projected model actually changes.
- No `TimelineView` or `repeatForever` animation is used.

## Validation

Required before merge:

- `git diff --check`
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCognitiveDagVisualizerGate test -only-testing:EpistemosTests/CognitiveDagVisualizerPanelTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet`
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosCognitiveDagVisualizerGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
