# Halo V1 Visible Panel Actions PR3 Deliberation - 2026-05-02

## Claim

The Halo panel is code-mounted and domain refresh is live, but rows still make
their important affordances too implicit. This slice makes each result visibly
actionable while preserving the existing closure surface and source provenance.

## Approved Write Set

- `Epistemos/Views/Halo/ShadowPanelContent.swift`
- `EpistemosTests/HaloUITests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- this deliberation file

## Forbidden

- No protected editor files.
- No graph, Rust, FFI, generated bindings, Xcode project, entitlement, or build
  artifact edits.
- No new retrieval path, no synchronous search, no per-keystroke work.
- No product-ready/manual-runtime claim.

## Test Gate

Add a failing Halo UI source guard requiring:

- source provenance to render directly in the row;
- visible `Open`, `Edit`, and `Summarise` row actions;
- domain-appropriate action gating for note versus chat hits.

Then run the focused Halo UI/controller tests and source audits.

## Result

- Red confirmed in `/tmp/epistemos-halo-v1-visible-actions-pr3-red-20260502.log`.
- Green confirmed in
  `/tmp/epistemos-halo-v1-visible-actions-pr3-green-20260502.log`: 17 Halo UI
  tests passed, including the new visible provenance/action-row source guard.
- Known Xcode package-plugin noise still appears after `TEST SUCCEEDED` for
  SwiftLint on CodeEdit packages; it did not fail the selected test run.
