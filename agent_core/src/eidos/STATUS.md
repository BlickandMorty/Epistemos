# Eidos V0 — Status Snapshot

Living one-screen scan for future contributors. Updated when material new ground is broken; for granular history, `git log --oneline -- agent_core/src/eidos/`.

**Branch:** `codex/t10-eidos-v0-2026-05-18`
**Spec source:** `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T10
**Design doc:** `docs/EIDOS_V0_CLOSED_CITATION_DESIGN_2026_05_18.md`

## Acceptance bar — fully met

- [x] `EidosRetriever` trait with the seven canonical retrieval modes + two operator-extension modes (9 total).
- [x] Every emitted hit carries `source_id` + `document_id` + provenance + manifest binding.
- [x] Closed-citation contract: `EidosContextPacket::validate_citation` (single) + `validate_citations` (batch).
- [x] F-Eidos-ClosedCitation falsifier with canonical fixture corpus + JSON-serializable witness + failure tagged enum.
- [x] Swift mirror types declared (`Epistemos/Eidos/Eidos.swift`) + Swift Testing tests (`EpistemosTests/Eidos*Tests.swift`).
- [x] Cross-language parity fixture pinned (Rust serde ↔ Swift Codable byte-equal on a canonical packet).
- [x] Wire-format case forms PascalCase-locked for both `EidosRetrievalMode` and `EidosSourceKind`.

## Cross-language wire-format symmetry — all 4 contract types

The Rust ↔ Swift JSON wire format is now end-to-end symmetric for every type a future `EidosBridge` FFI will carry. Each row links the Rust serde pin and the Swift Codable decode test that consumes the exact same bytes:

| Contract type             | Rust pin (parity / types)                                          | Swift mirror (EidosParityTests)                                  |
|---------------------------|--------------------------------------------------------------------|------------------------------------------------------------------|
| `EidosContextPacket`      | `parity::canonical_packet_serializes_to_pinned_bytes`              | `canonicalPacketDecodes`                                         |
| `EidosCitation`           | embedded in the packet round-trip + closed-citation pins           | `canonicalPacketDecodes` + `closedCitationContractAgainstCanonicalPacket` |
| `CitationError`           | `types::tests::citation_error_serializes_with_external_tag`        | `citationErrorDecodesRustWireShape` + `citationErrorEncodeRoundTrip` |
| `Vec<(usize, CitationError)>` | `types::tests::batch_failure_byte_equal_pin_for_two_error_canonical_input` | `batchCitationErrorDecodesRustWireShape` + `batchCitationErrorRoundTrip` |

Each lockstep pair fires exactly one test on drift, distinguishing which side broke the contract. The acceptance-bar "Swift mirror types declared" floor is exceeded — the mirror is now wire-format-validated, not just type-declared.

## Modes shipped (10)

| Mode                    | Backend type                              |
|-------------------------|-------------------------------------------|
| `Lexical`               | `lexical::InMemoryLexicalIndex`           |
| `Semantic`              | `semantic::InMemorySemanticIndex`         |
| `Hybrid` (2-way)        | `hybrid::HybridRetriever<L, S>`           |
| `Hybrid` (N-way)        | `hybrid_n::HybridRetrieverN`              |
| `RawArchive`            | `raw_archive::InMemoryRawArchive`         |
| `CodeSymbol`            | `code_symbol::InMemoryCodeSymbolIndex`    |
| `GraphNeighborhood`     | `graph_neighborhood::InMemoryGraphNeighborhood` |
| `ClaimEvidence` (mem)   | `claim_evidence::InMemoryClaimEvidence`   |
| `ClaimEvidence` (ledger)| `ledger_backed_claim_evidence::LedgerBackedClaimEvidence` |
| `Recency`               | `recency::InMemoryRecencyIndex`           |
| `ProvenanceVerified`    | `provenance_verified::ProvenanceVerifiedRetriever<R>` |

## Cross-terminal W-rows

| Row    | Status                                                                       |
|--------|------------------------------------------------------------------------------|
| W-46   | NOT-STARTED (Swift bridge facade — needs FFI plumbing)                       |
| W-47   | NOT-STARTED (ChatCoordinator emit-gate wiring through `validate_citations`)  |
| W-48   | NOT-STARTED (Brain Panel "Retrieved by Eidos" surface)                       |
| W-49   | **RUST-LANDED** (commit `ce69d4f28`; 9 tests; snapshot-isolated)            |
| W-50   | NOT-STARTED (DagBackedGraphNeighborhood)                                     |
| W-51   | NOT-STARTED (ShadowBackedSemanticIndex via epistemos-shadow HNSW)            |

Source: `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` §4b.

## Test surface

- ~217 unit tests in `agent_core/src/eidos/*`, all green.
- Falsifier corpus: 11 retrievers × 6 queries = 66 fake-citation rejection sites + 5 contract invariants (provenance manifest match, provenance mode match, legitimate citation accepted, fabricated rejected, confidence ∈ [0,1], span byte_end ≤ body, NaN confidence caught).
- Stability guard: 20-run determinism on the falsifier.
- Stress: kitchen-sink Hybrid_N (10 distinct backend shapes), 100-retriever Hybrid_N, 200-doc Lexical, 1000-occurrence Lexical.
- Edge cases pinned: empty corpus per retriever, empty query.text per mode, Unicode (Cyrillic + ZWJ emoji + Han), NUL byte, top_k = `u16::MAX`, top_k = 0, retraction propagation across snapshots, AtRisk-claim-still-emits, ledger empty-id boundary, no-evidence claim, commit-retract-recommit lifecycle, self-loop graph edge, all-empty Hybrid_N, asymmetric inner Hybrid_N, k-divergence Hybrid_N.

## Open research questions

See design doc §11. Top three by schema impact:
1. **Embedding-model identity in the manifest** — pin via new field, or rely on caller discipline?
2. **RRF k = 60** — inherited from `epistemos-shadow`; tune for personal-vault retrieval?
3. **Provenance verification source-of-truth** — signed ledger, claim-status, or per-chunk witness?

## Next concrete deliverables

1. W-46 Swift bridge FFI — needs Swift project bring-up and disk for xcodebuild.
2. W-47 ChatCoordinator wiring — gates on W-46.
3. W-48 Brain Panel surface — also gates on W-46.

The retrieval substrate is ready. Wiring is the next phase.
