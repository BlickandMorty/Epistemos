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

Canonical home: **design doc §12** carries the prose version of this surface; STATUS.md is the contributor-facing snapshot. A drift detector keeps both pinned in lock-step (see `hardening_tests::status_md_lists_all_backends_and_w_rows` and `design_doc_section_12_wire_format_summary_lists_all_four_contract_types`).

### Falsifier outcome types — Rust + Swift bidirectional

Both falsifier outcome types are now mirrored on the Swift side. `FEidosClosedCitationWitness` is straightforward Codable; `FalsifierFailure` has a hand-rolled Codable that consumes the Rust-side `serde(tag = "variant")` internal-tag JSON bytes verbatim.

| Falsifier outcome type           | Rust pin                                                                  | Swift mirror   |
|----------------------------------|---------------------------------------------------------------------------|----------------|
| `FEidosClosedCitationWitness`    | `falsifier::tests::witness_json_round_trips_serialize_then_deserialize` + `witness_decodes_canonical_pinned_json_bytes` | `EidosFalsifierWitness` + `EidosParityTests.falsifierWitnessDecodesRustWireShape` |
| `FalsifierFailure`               | `falsifier::tests::failure_json_round_trips_across_canonical_variants` + `failure_decodes_canonical_pinned_json_bytes` + `failure_serialize_pins_exact_bytes_for_every_variant` | `EidosFalsifierFailure` + `EidosParityTests.falsifierFailureDecodesRustWireShape` (6 non-NaN variants) + `falsifierFailureHitConfidenceFiniteDecodes` + `falsifierFailureUnknownVariantTagErrors` |

Both Rust types are `Serialize + Deserialize` and survive byte-equal Rust-side round-trip. The `FalsifierFailure::HitConfidenceOutOfRange.confidence: f32` field has a documented exception: NaN serializes to JSON `null` and is therefore explicitly not round-trip-safe (finite values round-trip cleanly on both sides). The Swift mirror enum carries `Float` for the confidence field — `null` decode fails the same way the Rust decode fails, preserving the asymmetry contract. Unknown variant tags from a future Rust-side rename surface as Swift `DecodingError` rather than silent fallback.

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

- 321 unit tests in `agent_core/src/eidos/*`, all green.
- Falsifier corpus: 12 retrievers × 6 queries = 72 fake-citation rejection sites + 5 contract invariants (packet/retriever manifest match, hit-provenance manifest match, hit-provenance mode match, legitimate-citation accepted, fabricated-citation rejected) plus 2 hit-shape checks (confidence ∈ [0,1] inclusive endpoints pinned iter 92, with NaN caught and serialize→null pinned iter 66; span byte_start ≤ byte_end with zero-width accepted, past-body accepted, inverted rejected). Nested PV-over-Hybrid_N case added iter 60.
- Stability guard: 20-run determinism on the falsifier across both consecutive runs (same Vec) and freshly-rebuilt fixtures (rebuild on every iteration). Witness invariant to retrieved_at_unix_ms across t=0, T0, +200B ms, u64::MAX (iter 75).
- Bidirectional serde for both falsifier outcome types — round-trip pin + canonical pinned-bytes decode pin + per-variant byte-equal serialize pin for `FalsifierFailure`. NaN f32 confidence asymmetry pinned (serialize→null, decode→Err).
- Falsifier early-exit determinism pinned at THREE levels: retriever-loop short-circuit (surface — iter 81; invocation-count — iter 99), query-loop short-circuit (surface — iter 83; invocation-count — iter 103), success path calls retrieve exactly once per pair (iter 101).
- Stress: kitchen-sink Hybrid_N (10 distinct backend shapes), 100-retriever Hybrid_N, 200-doc Lexical, 1000-occurrence Lexical.
- Span contract codified at 3 corners: zero-width `[n,n)` accept (iter 84), inverted `n>m` reject as HitSpanInvalid (iter 86), past-body `m>body.len()` accept-by-design (iter 90 — EidosHit doesn't carry body).
- Scoring formulas algebraically pinned by-example at all 4 surfaces: Recency `1/(1+age_days)` at 5 ages (iter 100), Lexical `n/(1+n)` at 4 counts (iter 102), Semantic cosine at 4 angles (iter 104), Hybrid 2-way `rrf_sum/max_rrf` at single-mode rank-1 = 0.5 + both-rank-1 = 1.0 (iter 105 + existing). Hybrid_N `1/N` normalization curve pinned at 8 points across the canonical N range: single-mode 1/N at N=1/2/3/4 (iters 82, 105, 107, 112) AND saturation at N=1/2/3/4 (iters 82, 105, 116, 118). Score component pass-through pinned at all 4 wrapper-retriever surfaces: PV preserves every inner field (iter 95), Hybrid_N N=1 (iter 82), Hybrid 2-way exact-value (iter 97), Hybrid_N N=3 Lex+Sem+Recency under max-merge (iter 110). `k` parameter triple-pinned for both Hybrid 2-way and Hybrid_N: default = `RRF_K_DEFAULT = 60`, getter via `with_k`, scoring-effect verified at mixed-rank cases (iters 108, 109). `RRF_K_DEFAULT = 60` cross-language pin via drift detector that reads Swift `Phase3FusionConsts.K_RRF` directly (iter 125). `EidosQuery::new` + `with_vector` + `with_since` field shapes pinned (iters 111, 113, 115). Module docstring audit + drift-detector locks complete across 5 surfaces: recency formula accuracy (iter 117), lexical mode-count (iter 119), semantic mode-count (iter 121), falsifier 5-invariant list (iter 122), and broader stale-seven sweep across raw_archive/provenance_verified/retriever/types + historic test rename (iter 126). Lex/sem mode-count drift detector (iter 123) + falsifier 5-invariant drift detector (iter 124) + full-directory stale-seven sweep detector (iter 126) lock all corrections.
- Edge cases pinned: empty corpus per retriever incl. LedgerBackedClaimEvidence W-49 (iter 89), empty query.text per mode, Lexical+Hybrid+HybridRetrieverN empty-needle defer against populated corpus (iter 67), Semantic Some(vec![]) ≡ None defer + Semantic-ignores-query.text asymmetry vs Lexical (iter 70), Recency with_since(0) ≡ no-since hit equivalence (iter 98), Unicode (Cyrillic + ZWJ emoji + Han), NUL byte both directions (iter 73), top_k = `u16::MAX`, top_k = 0 incl. fusion (iter 87), retraction propagation across snapshots, AtRisk-claim-still-emits, ledger empty-id boundary, no-evidence claim, commit-retract-recommit lifecycle, self-loop graph edge + mixed ordering (iter 76), all-empty Hybrid_N, asymmetric inner Hybrid_N, k-divergence Hybrid_N, Hybrid_N N=1 saturation (iter 82), Hybrid + Hybrid_N RRF-tie-break (iters 77, 79), Recency since_unix_ms inclusive floor (iter 80) + u64::MAX type-boundary (iter 93), Recency top_k × tied-ts (iter 85), Recency filter-then-rank multi-match (iter 96), Recency confidence-cap under clock skew (iter 78), PV multi-admit byte-equal (iter 74), CodeSymbol dedup first-write-wins (iter 88), Hybrid_N manifest-mismatch first-offending-index (iter 94).
- Closed-citation contract hardening (iters 127-166) — 36 pins around `EidosContextPacket::validate_citation` + `validate_citations` covering the named edge cases (unicode normalization, duplicate dedup, fake IDs rejected, empty vault empty packet not error) and adjacent corners. Five adversarial smuggling vectors independently pinned: NFC/NFD canonical-equivalence (iter 127), ZWSP/invisible-char injection (iter 133), Cyrillic-Latin homoglyph (iter 137), whitespace padding (iter 140), low-codepoint control-character injection (iter 154) — all rejected with byte-strict diagnostic preservation, plus a meta drift-detector that locks the five named-vector test functions against silent removal (iter 146, extended in iter 154 to require all 5, extended in iter 158 to lock the taxonomy count at 5 AND verify STATUS.md mentions all 5 short labels in lock-step). Contract-shape pins: input-list duplicate-preservation no auto-dedup (iter 128), end-to-end empty-vault zero-citation gate is Ok(()) (iter 129), `ManifestMismatch` precedes `FabricatedSourceId` short-circuit (iter 130), error-list returns in input-index ascending order across mixed-variant batch (iter 131), `citable_source_ids` is 1:1 hit-aligned without dedup (iter 132), `CitationError` two-variant exhaustive-match drift detector + size ceiling at 64 bytes (iter 134, extended in iter 160 to bound payload bloat), `Display` format exact + invisible-char escape-rendering visibility (iter 135), idempotent + cross-packet deterministic across byte-equal instances (iter 136), `any()` iteration covers ALL hits including last-position (iter 138), `EidosCitation` JSON wire-format pinned + byte-faithful round-trip across all 5 smuggling vectors (iter 139, extended in iter 155). Wire-asymmetry pins: empty-payload citations smuggled past `EidosChunkId::new`'s guard via serde wire still get rejected by the gate (iter 142), `EidosCitation` JSON deserialize contract — missing/wrong-type fields error, extra fields silently forward-compat (iter 143). Closed-citation contract surface pins: hit metadata (confidence/span/kind/score/provenance) irrelevant to validation — only source_id + manifest_id bytes matter (iter 144), `EidosCitation` equality conjunctive on BOTH fields across full 2×2 truth table + size ceiling at 64 bytes (iter 145, extended in iter 161 to bound payload bloat), position-equivalence — `validate_citation` invariant under hit permutation across canonical/reversed/shuffled orderings (iter 148), `CitationError` + `Result<(), CitationError>` + `Vec<(usize, CitationError)>` Send+Sync compile-time for chat-layer FFI bridge (iter 152), `validate_citations` is the canonical list-lift of `validate_citation` — Ok iff every singular is Ok AND error list matches singular-per-index pairwise (iter 162). Cross-mode contract sweep complete across all 9 canonical retrieval modes (`EidosRetrievalMode::CANON_ALL`) AND across both concrete ClaimEvidence retrievers: direct retrievers Lexical/Semantic/Recency/CodeSymbol/RawArchive (iter 147), derived retrievers Hybrid/ProvenanceVerified/LedgerBackedClaimEvidence (iter 149), GraphNeighborhood (iter 150), Hybrid_N N-way fusion canonical home for heterogeneous-retriever citations (iter 153), InMemoryClaimEvidence (iter 164 — parallel to iter 149's ledger-backed variant since both are concrete ClaimEvidence retrievers with distinct emission code paths). 9-of-9 mode-count pinned against silent canon expansion via assertion on CANON_ALL.len(). Concurrency: compile-time Send+Sync (iter 152) and runtime soundness — 4 worker threads × 100 mixed validate calls all produce results byte-identical to the single-threaded baseline (iter 165), catches interior-mutability regressions that would race at runtime. Scale: 1000-hit packet validates citations at first/middle/LAST positions Ok + a 1000-citation batch validates Ok (1M inner comparisons; iter 166), surfaces fixed-buffer / take(N) / quadratic regressions that 25-hit pins miss. Catalog self-consistency: STATUS.md ↔ actual `#[test]` count drift detector reads STATUS.md and asserts the count claim matches the actual attribute count across `agent_core/src/eidos/*.rs` (iter 157), surfacing catalog drift on the very next test run — this drift detector caught STATUS.md lags in iters 162/164/165/166's runs automatically. 5-vector taxonomy locked across four catalog sites — per-vector tests, iter 146 drift detector + array length, iter 155 wire round-trip array, STATUS.md catalog phrase — adding a 6th vector requires lock-step updates surfaced via test failures (iter 158).

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
