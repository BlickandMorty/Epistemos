# F-BodyReadChecksum-ReleaseBlockerCard - 2026-06-07

North-star sentence: Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof.

## Status

PASS metadata-only L1/T1 source-card witness.

- Command: `Tools/falsifiers/f_body_read_checksum_release_blocker_card.sh`
- Artifact: `artifacts/falsifiers/body_read_checksum_release_blocker_card/result.json`
- Falsifier ID: `F-BodyReadChecksum-ReleaseBlockerCard`
- Cursor: `body_read_checksum_release_blocker_card`
- Next source-card cursor: `search_index_release_blocker_card`
- Upstream: `F-RuntimePerformancePolicy-ReleaseBlockerCard`
- Family source: `body_read_checksum`
- Deterministic address: `sha256:521a969d4746b60eb324f8ad080a3c85f5b88a6cb29d3e882b41feb43809a2ac`

## What This Proves

This witness consumes the runtime-performance release-blocker card and the
release-audit failure-family source card, then binds the retained
`body_read_checksum` blocker to exact body/readable-block/editor/graph/prompt/
cache freshness surfaces before large-model replay, Gemma QAT tournaments, KV
reuse, prompt-cache reuse, or AnswerPacket evidence can be trusted.

Measured evidence:

- Retained issue count: `1`
- Source refs: `12`
- Required invariants: `15`
- Focused commands: `5`
- Rejected red fixtures: `33`
- Body/model/cache/provider bytes loaded or read: `0`

## Bound Source Refs

- `Epistemos/Models/SDPage.swift`
- `Epistemos/Sync/NoteFileStorage.swift`
- `EpistemosTests/PhaseR3BodyReadParityTests.swift`
- `Epistemos/Engine/EpdocDocument.swift`
- `Epistemos/Sync/ReadableBlocksIndex.swift`
- `Epistemos/State/NoteChatState.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `Epistemos/Views/Notes/AIPartnerService.swift`
- `Epistemos/Bridge/StreamingDelegate.swift`
- `EpistemosTests/NoteChatStateTests.swift`
- `EpistemosTests/ResourceRuntimeRegressionTests.swift`
- `EpistemosTests/RuntimeValidationTests.swift`

## Required Invariants

- Managed sidecar remains the first source-of-truth lane.
- R3 resource-gateway parity remains preserved.
- Blank managed body remains authoritative where policy says so.
- Front-matter behavior is recorded instead of assumed.
- Unicode and multibyte digest stability is required.
- Live editor text requires editor snapshot sequencing.
- Readable-block projections require their own digest.
- Graph/evidence projections require their own digest.
- Prompt assembly requires its own digest.
- Cache/KV reuse requires a cache salt digest before reuse.
- AnswerPacket carries a visible freshness caveat.
- Artifacts retain no raw body, prompt, or model token text.
- Body-read parity is not model-quality proof.
- No L2/L3/product-green promotion is allowed.
- No model/runtime/cache/provider bytes are touched.

## Rejected False Promotions

The witness rejects missing upstream proof, wrong upstream cursor, wrong family,
zero retained issue count, missing source refs, duplicate source refs, missing
freshness invariants, missing body/readable/graph/prompt/cache digests, hidden
cache authority, raw body/prompt/token artifact leakage, hidden AnswerPacket
caveats, L2/L3/product green claims, live dense-70B claims, model/runtime/cache
byte leaks, and provider calls.

## Layer Truth

- L1 architecture cursor: source-card side ladder advanced for this blocker.
- L2 product route: not advanced; capability kernel remains
  `vault_research_route_with_packetized_mitigation`.
- L3 user-facing / WRV: not advanced; runtime freshness, large-model route
  usability, release readiness, and user-facing large-model capability remain
  red until focused tests, fresh logs, runtime evidence, rollback, and
  AnswerPacket proof pass.

## Next

The next side-card unit is `search_index_release_blocker_card`. The guard-owned
product cursor remains
`small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe`.
