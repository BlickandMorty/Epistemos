# F-GraphFilterVisibilityFocusedRepairPacket - 2026-06-08

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS as metadata-only T1/L1 architecture evidence.

Artifact:
`artifacts/falsifiers/graph_filter_visibility_focused_repair_packet/result.json`

Command:
`Tools/falsifiers/f_graph_filter_visibility_focused_repair_packet.sh`

## What This Proves

`F-GraphFilterVisibilityFocusedRepairPacket` consumes
`F-ReleaseAuditAutomatedChecksClosureMatrix` and binds the top retained release
audit family, `graph_filter_visibility`, to a focused repair map.

The packet preserves:

- Upstream closure matrix pass and next cursor
  `graph_filter_visibility_focused_repair_packet`.
- Retained family: `graph_filter_visibility`.
- Retained issue count: 34.
- Repair rank: 1.
- Source refs: `Epistemos/Models/GraphTypes.swift`,
  `Epistemos/Graph/FilterEngine.swift`, Pass 120 of the deep research
  synthesis, and the closure-matrix artifact.
- Test refs: `FilterEngineComprehensiveTests.swift`,
  `ResourceExhaustionTests.swift`, `ConcurrencyEdgeCaseTests.swift`, and
  `VaultLifecycleResetTests.swift`.
- Focused command templates: 4.
- Repair anchors: 7.
- Required invariants: 10.
- Source truth markers: 7.
- Source text bytes read: 28305.
- Red fixtures rejected: 29.
- Deterministic focused repair packet address:
  `sha256:fe09fbc5253aaffaeaea88097245ca865a2d0eeea349e0e20cc9727516e06ed8`.
- Next cursor: `graph_filter_visibility_focused_identifier_proof`.

## Source Truth

The witness binds current source semantics rather than changing product code:

- `GraphNodeType.visibleCases` means graph-visible cases except `.block`.
- `GraphNodeType.defaultActiveCases` intentionally excludes `.folder`.
- `FilterEngine` initializes and compares against `defaultActiveCases`.
- `showAllTypes()` restores `defaultActiveCases`.
- `resetForVaultLifecycle()` restores `defaultActiveCases` and clears focus,
  search, and model filters.
- Folder remains an explicit opt-in path through `setType` or `toggleType`.

## Hard Boundaries

This is a focused repair packet, not a focused repair proof.

The witness rejects:

- Green upstream or wrong upstream cursor claims.
- Wrong family, zero issue count, or wrong repair rank.
- Missing source refs, test refs, repair anchors, or invariants.
- Source truth that makes folder default-on.
- Product source patch requirements.
- Swift test execution claims.
- Focused identifier proof or focused repair proof claims.
- Full `xcodebuild_test` pass claims.
- Treating focused tests as a replacement for the full rerun.
- Treating the source card as repair proof.
- L2/L3/T4/product green claims.
- Live dense 70B claims.
- Hidden route authority, Eidos route authority, or route mutation.
- Model, graph-runtime, or command byte loads.

## What Did Not Advance

- L2 capability route: unchanged and red.
- L3 user-facing/runtime/release readiness: unchanged and red.
- T4/T5 green: no.
- Product source: unchanged by this witness.
- Swift tests: not executed by this witness.
- Full `xcodebuild_test`: not rerun by this witness.
- Large-local-model runtime: not proven.
- Live dense 70B: rejected.

Correct phrasing: "L1 graph-filter focused repair packet architecture proof advanced; product capability / user surface did not."

## Next

The next safe unit is `graph_filter_visibility_focused_identifier_proof`, which
must bind valid Swift Testing identifiers and nonzero executed-test evidence
before any focused repair or release-audit closure claim can promote.
