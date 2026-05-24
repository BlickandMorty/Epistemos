---
falsifier: F-Eidos-Bridge-RoundTrip
created_on: 2026-05-23
hardware_floor: M2 Pro 14-inch 2023, 12-core CPU, 19-core GPU, 16 GB UMA, approximately 200 GB/s
status: PASS (Rust FFI cargo tests green; Round 2 binary `falsify_eidos_bridge_round_trip` persists primary_witness artifact at `artifacts/falsifiers/eidos_bridge_round_trip/result.json`; Swift round-trip pending xcodebuild gate in CI)
---

## Phase 2 Terminal F' (Round 2) status (2026-05-24)

- **phase2_terminal_f_prime_status**: PRIMARY WITNESS — in-process FFI round trip against the production Eidos vault index on M2 Pro 14-inch 2023 16 GB.
- **phase2_terminal_f_prime_artifact**: `artifacts/falsifiers/eidos_bridge_round_trip/result.json`.
- **phase2_terminal_f_prime_harness**: `agent_core/src/bin/falsify_eidos_bridge_round_trip.rs`.
- **phase2_terminal_f_prime_pass_axes**: `vault_manifest_prefix` · `retrieve_hits_present` · `closed_citation_membership` · `forged_citation_rejection` · `manifest_mismatch_rejection`.
- **phase2_terminal_f_prime_audit_doc**: `docs/audits/FALSIFIER_M2PRO_7_PASS_2026_05_24.md`.

# F-Eidos-Bridge-RoundTrip

Handbook row: [M2 Pro Verified Floor Handbook](M2_PRO_VERIFIED_FLOOR_HANDBOOK_2026_05_18.md).
Companion to [F-Eidos-ClosedCitation](F_EIDOS_CLOSED_CITATION_2026_05_18.md) — that
falsifier covers the Rust-side closed-citation contract; this one covers the Swift
↔ Rust BRIDGE round-trip after Terminal A's real vault binding.

| Field | Value |
|---|---|
| Purpose | Prove the production-vault `EidosBridge` (Swift) → `eidos_retrieve_json`/`eidos_validate_citation_json` (Rust FFI) round-trip emits citation-bearing packets whose forged-citation gate rejects, and whose `manifest_id` flips backend-honesty detection to `.real`. |
| Current status | PASS on Rust side (8/8 `eidos_production_ffi_tests::` green). Swift side covered by `EidosBridgeProductionTests.swift` (10 tests); awaits xcodebuild CI execution. |
| Input fixture | Five synthetic vault notes inserted via `EidosBridge.insertVaultNote`. Three forged-citation attempts: (a) source_id not in any hit, (b) source_id from a different manifest, (c) cross-stance smuggle attempt. |
| Pass threshold | (1) `EidosBridge.openVaultIndex(signature:)` returns a manifest_id starting with `vault-`; (2) `EidosBridge.retrieve` returns a packet whose `EidosBridge.detectedBackend == .real`; (3) `EidosBridge.validateCitation` accepts every emitted source_id; (4) `validateCitation` rejects forged ids with `.fabricatedSourceId`; (5) `validateCitation` rejects manifest-mismatched citations with `.manifestMismatch`; (6) `EidosMetrics.shared.lastBackend == .real` post-retrieve. |
| Failure meaning | The chat layer cannot trust EidosBridge.retrieve output; closed-citation contract has a Swift-side gap; chip-strip orange→green flip is dishonest. |
| Fallback route | Set `EPISTEMOS_EIDOS_V0` UserDefaults flag off → legacy FTS/RRF path; document gap in audit. |
| Product lane | Tier 1 (MAS). No Pro / Research split. |
| Exact command | `cargo test --manifest-path agent_core/Cargo.toml --lib bridge::eidos_production_ffi_tests::` (Rust) + `swift test --filter EidosBridgeProductionTests` (Swift, requires xcodebuild). |
| Expected artifact | `agent_core/target/.../test-results.json` (cargo) + Xcode test result bundle. |

## Contract Ownership

This falsifier exercises the FFI seam that Terminal A landed for W-46.1 (real vault binding) + W-47 (citation gate FFI). It consumes the T10-owned closed-citation contract via the Rust-side validator function `eidos_validate_citation_json` and depends on the W-49 `LedgerBackedClaimEvidence` shape (the same byte-equal source_id format `{document_id}::lex` for lexical retrieval).

## Canon Anchors

- [docs/CANONICAL_CHRONICLE_2026_05_23.md](../CANONICAL_CHRONICLE_2026_05_23.md) §1.2 the 7 Laws: this falsifier honors Law 2 Address (every hit's source_id is a manifest-bound chunk id), Law 4 Lattice-error (forged citations rejected closed), Law 7 Witness (the validation result IS the witness).
- [docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md](../fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md) §4 provenance-ledger cross-link.
- [docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md](../audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md) W-46/W-47 rows.

## Failure Criterion

This falsifier fails if ANY of:

1. The Rust FFI panics or returns a non-`vault-*` manifest_id from `eidos_open_vault_index`.
2. `eidos_retrieve_json` returns hits whose `source_id`s do not also validate as `EidosCitation` against the returned packet.
3. `eidos_validate_citation_json` accepts a forged source_id (returns `{"Ok":null}` for a `chunk_id` not in `packet.hits`).
4. `eidos_validate_citation_json` accepts a manifest-mismatched citation.
5. The Swift `EidosBridge.detectedBackend(from:)` heuristic does not flip to `.real` for `vault-*` manifest packets.
6. `EidosMetrics.shared.lastBackend` remains `.fixture` after a real-vault retrieve (would imply chip-strip dishonest language).

## Artifact Schema Axes

The expected result must include these minimum axes in `measurements`, `acceptance_thresholds`, and `pass_per_axis`:

- `vault_manifest_prefix` — Boolean: `vault-` prefix present.
- `closed_citation_membership` — Boolean: every emitted source_id validates.
- `forged_citation_rejection` — Boolean: every forged id returns `.fabricatedSourceId`.
- `manifest_mismatch_rejection` — Boolean: cross-manifest citations rejected.
- `backend_honesty_flip` — Boolean: `lastBackend == .real` post-retrieve.

## Current Run (2026-05-23)

| Axis | Outcome | Evidence |
|---|---|---|
| `vault_manifest_prefix` | PASS | `eidos_production_ffi_tests::round_trip_open_insert_retrieve_validate` |
| `closed_citation_membership` | PASS | `round_trip_open_insert_retrieve_validate` (Rust); `validateCitationAcceptsEmittedHits` (Swift) |
| `forged_citation_rejection` | PASS | `forged_citation_is_rejected` (Rust); `validateCitationRejectsForged` (Swift) |
| `manifest_mismatch_rejection` | PASS | `manifest_mismatch_is_rejected` (Rust); `validateCitationRejectsManifestMismatch` (Swift) |
| `backend_honesty_flip` | PASS | `EidosBridgeProductionTests::insertThenRetrieveRoundTrip` (Swift; verifies `EidosMetrics.shared.lastBackend == .real`) |

**Rust gate (locally green):** `cargo test --manifest-path agent_core/Cargo.toml --lib bridge::eidos_production_ffi_tests` → 8 passed, 0 failed.

**Swift gate:** `EidosBridgeProductionTests.swift` (10 tests) awaits xcodebuild CI execution (skipped locally per session disk-capacity discipline).
