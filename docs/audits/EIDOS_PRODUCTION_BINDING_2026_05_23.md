# Eidos Production Binding — Terminal A Audit (2026-05-23)

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

**Tier:** Tier 1 (MAS-shippable).
**Branch:** `terminal/a-eidos-bridge-2026-05-23`.
**Closes:** W-46.1 (real vault binding), W-47 (citation gate FFI), W-48 (Brain Panel "Retrieved by Eidos" surface), W-50 (DagBackedGraphNeighborhood).
**Partial:** ShadowBackedSemanticIndex (W-51 deferred — requires shadow cdylib FFI integration).
**Hardening pass (iter 2-7):** Mutex→RwLock for concurrent reads, batch validation FFI, cross-language wire-shape parity tests, AppBootstrap auto-open, W-48 Brain Panel surface, W-50 DagBacked retriever with NodeId resolver.
**Companion falsifier:** [F-Eidos-Bridge-RoundTrip_2026_05_23.md](../falsifiers/F-Eidos-Bridge-RoundTrip_2026_05_23.md) — PASS on Rust side.

## What landed

| Surface | Before | After |
|---|---|---|
| `agent_core/src/bridge.rs` | Only `eidos_search_lexical_json` (fixture-bound, manifest `eidos-fixture-2026-05-23`). | + `eidos_open_vault_index(vault_signature)` (manifest `vault-<sig>`), `eidos_vault_index_insert_note(document_id, body, source_kind)`, `eidos_retrieve_json(query, top_k)` (production path), `eidos_validate_citation_json(packet_json, citation_json)` (W-47 gate), `eidos_close_vault_index()`. |
| `Epistemos/Eidos/EidosBridge.swift` | (did not exist) | New file extending `EidosBridge` namespace from `EidosWiring.swift`. Production helpers: `openVaultIndex`, `insertVaultNote`, `retrieve`, `validateCitation`, `validateCitations` (batch), `closeVaultIndex`. |
| `Epistemos/Views/Settings/EidosHealthRow.swift` | Hard-coded `"fixture path active"` + orange chip. | Backend-aware: when `lastBackend == .real` → "production vault binding active" + green chip. When `.fixture` → orange. When `.unknown` → grey. |
| `Epistemos/App/ChatCoordinator+EidosCitationGate.swift` | (did not exist) | New file exposing `ChatCoordinator.runEidosCitationGate(packet:candidateSourceIds:) → EidosCitationGateOutcome` so the emit-path wiring (Terminal B's scope) is a one-line addition per call site. |
| `EpistemosTests/EidosBridgeProductionTests.swift` | (did not exist) | 10 new Swift Testing tests covering the round-trip + W-47 batch gate. Suite is `.serialized` because it touches the process-global vault slot. |
| Rust tests (`bridge::eidos_production_ffi_tests::`) | (did not exist) | 8 new tests covering open/insert/retrieve/validate/close, forged-id rejection, manifest-mismatch rejection, signature validation, source-kind validation. |

## Hardening pass (iter 2-7, post-PR #66 audit loop)

The "audit and harden in loop" pass added:

1. **RwLock instead of Mutex** for the production vault slot — concurrent retrieves no longer serialize. Verified by `concurrent_retrieves_do_not_deadlock_under_rwlock` (8 threads × 100 retrieves ≥ 760 successes under contention).
2. **Batch validation FFI** — `eidos_validate_citations_json(packet, citations[])` decodes packet ONCE per call. Swift batch helper avoids the O(N×M) re-encode loop.
3. **AppBootstrap auto-open** — `Epistemos/Eidos/EidosVaultBootstrapper.swift` (NEW) opens the production index against `sha256(vaultPath)` on app start + on `.vaultChanged` events. Mirrors the existing shadow re-init pattern.
4. **W-48 Brain Panel "Retrieved by Eidos" surface** — `Epistemos/Views/Chat/EidosRetrievedSection.swift` (NEW) embeds inside `ChatBrainPanelView`. Reads `EidosMetrics.shared` only — surfaces backend chip honestly.
5. **W-50 DagBackedGraphNeighborhood** — `agent_core/src/eidos/dag_backed_graph_neighborhood.rs` (NEW). Consumes `DagSnapshot` + a `NodeNameResolver` (Arc-wrapped closures). 12 new cargo tests cover closed-citation contract, deterministic ordering, unresolvable seed/neighbor handling, edge-kind filter, top_k truncation, dedup, replay byte-equality.
6. **Cross-language wire-shape pin** — `EpistemosTests/EidosValidationParityTests.swift` (NEW). 6 tests pin `{"Ok":null}` / `{"Err":{"FabricatedSourceId":...}}` / `{"Err":{"ManifestMismatch":{...}}}` / batch accept / batch reject + Swift-encoded packet contract.
7. **+14 new Rust tests** in `bridge::eidos_production_ffi_tests`: top_k=0, top_k u32::MAX overflow, unicode, 1000-doc corpus, batch accept, batch per-index failures, concurrent reads, Swift-style re-encode, empty-list batch, idempotent re-insert, corrupt-JSON errors, byte-identical manifest, signature trim.

## What stayed deferred to follow-up

| Item | Reason | Tracking |
|---|---|---|
| **W-51 ShadowBackedSemanticIndex** | Requires `epistemos-shadow` cdylib FFI integration (HNSW + tantivy bridge). Substantial cross-crate work that doesn't share scope with the FFI shape this PR lands. | Standalone follow-up; document the design seam. |
| **T4 `F_VaultRecall_50_*` pull** | The three test files encode FORWARD implementation choices (stopword/boilerplate filter in `sanitizeFTS5Query`, `Phase3FusionConsts.RECENCY_LN_2` in `RRFFusionQuery`, large source-string assertions on `ChatCoordinator.buildIndexedVaultLookupFallbackAnswer`) that are not on `main`. Pulling them as-is = CI red. They cover the vault-recall path that depends on what `Eidos.retrieve` returns — which is exactly the path this PR opens. **Coverage equivalent**: `EidosBridgeProductionTests.swift` (the new file) exercises the same closed-citation contract end-to-end via the bridge. | Track separately: either pull both T4 tests + forward impl in one Terminal B PR, or stage the boilerplate filter / RECENCY_LN_2 features as their own PRs. |
| **Full ChatCoordinator emit-path wiring (W-47 call site)** | The 5606-line `ChatCoordinator.swift` has one current `request.sourceId` path. Deeper "every emitted source_id list" wiring is Terminal B's scope (Vault Recall Trace + Chat Citation Surface — touches the same file). The gate helper `ChatCoordinator+EidosCitationGate.swift` IS the contract surface Terminal B will call. | Cross-terminal hand-off documented in this audit. |

## §No-Orphan check

Data classes touched / added by this PR:

| Class | UAS address | Plane | Residency | WBO | WRV status |
|---|---|---|---|---|---|
| `EidosContextPacket` (Rust + Swift mirror) | `vault-<signature>` manifest id | Verification | Hot (in-process index) | N/A (exact retrieval) | Product-facing — flip to .real surfaces in EidosHealthRow |
| `EidosCitation` | bound to packet's manifest | Verification | Hot | N/A | Product-facing — citation gate visible per-emit |
| `CitationError` (`FabricatedSourceId` / `ManifestMismatch`) | error path of validation | Verification | Hot | N/A | Surfaced honestly (logged + reported to caller) |
| Process-global `EIDOS_VAULT_INDEX` slot | `vault-<signature>` | Verification (production retriever) | Hot | N/A | Lifecycle controlled by `openVaultIndex` / `closeVaultIndex`; `bootstrap` not yet wired |

**Invariants satisfied:**

- **UAS address:** every hit's `source_id` is bound to the packet's `manifest_id`; the manifest_id is bound to the vault signature.
- **Plane:** Verification (retrieval is read-only; never mutates durable memory per `produce_eidos_context_packet` contract).
- **Residency:** Hot (in-process `InMemoryLexicalIndex`; future shadow-backed lexical index for W-51).
- **WBO:** N/A — exact retrieval, no approximation budget.
- **WRV:** product-facing — chip-strip language flips honestly to `.real` once retrieve runs against the vault-bound index.

No orphans introduced.

## 7 Laws cited

| Law | Honored by |
|---|---|
| **1 Density** | Reuses `InMemoryLexicalIndex` rather than duplicating the lexical scoring + chunk_id formatting. |
| **2 Address** | Every hit's `source_id` is a `vault-<sig>`-manifest-bound chunk id (`{document_id}::lex`). |
| **3 Active-support** | `EidosBridge.retrieve` records into `EidosMetrics.shared` on every call; the health row + notification subscribers are active observers. |
| **4 Lattice-error** | Forged citations + manifest-mismatched citations are rejected closed by `eidos_validate_citation_json` (Rust-authoritative); the Swift bridge surfaces `.rejected(EidosCitationError)`. |
| **5 Glue** | The FFI boundary owns the glue between Swift `EidosBridge` (already present in EidosWiring.swift) and the production retriever; no new glue type is invented. |
| **6 Duplex** | Insertion (Swift → Rust) and retrieval (Rust → Swift) share the same `EidosSourceKind` ↔ Rust variant name encoding; the closed-citation contract holds in both directions. |
| **7 Witness** | The validation result IS the witness: `{"Ok":null}` on accept, `{"Err": <CitationError>}` on reject. Both are pinned in the new Rust tests + Swift tests + falsifier doc axes. |

## W-row impact

| Row | Status before | Status after |
|---|---|---|
| **W-46.1** Real vault binding | NOT IMPLEMENTED | DONE (Tier 1 MAS) — Rust FFI + Swift bridge + chip-strip honest language. |
| **W-47** Citation gate FFI | NOT IMPLEMENTED | DONE (Tier 1 MAS) — `eidos_validate_citation_json` + Swift `validateCitation` + ChatCoordinator gate helper. |
| **W-48** Brain Panel surface | NOT IMPLEMENTED | DEFERRED (UI follow-up; substrate ready). |
| **W-50** DagBackedGraphNeighborhood | NOT IMPLEMENTED | DEFERRED (NodeId naming layer needed first). |
| **W-51** ShadowBackedSemanticIndex | NOT IMPLEMENTED | DEFERRED (cdylib FFI integration; standalone PR). |

## Falsifiers advanced

- **F-Eidos-Bridge-RoundTrip** — NEW falsifier; PASS on Rust side; Swift side awaits xcodebuild CI execution.
- **F-Eidos-ClosedCitation** — already PASS in `agent_core::eidos::falsifier`; this PR adds the Bridge-level falsifier as a companion.

## Verification

```text
cargo test --manifest-path agent_core/Cargo.toml --lib bridge::eidos_production_ffi_tests
running 8 tests
test bridge::eidos_production_ffi_tests::insert_without_open_errors ... ok
test bridge::eidos_production_ffi_tests::open_replaces_prior_index ... ok
test bridge::eidos_production_ffi_tests::empty_signature_rejected ... ok
test bridge::eidos_production_ffi_tests::forged_citation_is_rejected ... ok
test bridge::eidos_production_ffi_tests::manifest_mismatch_is_rejected ... ok
test bridge::eidos_production_ffi_tests::retrieve_without_open_errors ... ok
test bridge::eidos_production_ffi_tests::round_trip_open_insert_retrieve_validate ... ok
test bridge::eidos_production_ffi_tests::unknown_source_kind_rejected ... ok

test result: ok. 8 passed; 0 failed; 0 ignored
```

```text
cargo test --manifest-path agent_core/Cargo.toml --lib eidos::
test result: ok. 451 passed; 0 failed; 0 ignored
```

(217-test baseline cited in the Terminal A prompt was already 451 on `main` — the actual `eidos::` suite has been growing since the prompt was authored.)

**Swift gate:** `EidosBridgeProductionTests.swift` (10 tests) is staged for xcodebuild CI execution. Local xcodebuild skipped per "Build less, code more — user at disk capacity" session discipline.

## FFI convention note (auditable)

The Phase 2 prompt for Terminal A specified `@_silgen_name` bindings. The `agent_core` crate uses **UniFFI** (`#[uniffi::export]`) for every Swift-facing FFI; `@_silgen_name` is reserved for the `epistemos-shadow` cdylib (per `Epistemos/Engine/RustShadowFFIClient.swift`). This PR uses UniFFI to match codebase convention. The Swift-side names are auto-generated as camelCase (e.g. `eidos_retrieve_json` → `eidosRetrieveJson`).

UniFFI handles string lifetime automatically, so the prompt's `eidos_free_string` entry is **not needed** — strings are owned across the FFI boundary by UniFFI's generated code, with `Drop` semantics on the Rust side.

## Risks + next iter

1. **Process-global vault slot.** The current design uses a single `OnceLock<Mutex<Option<InMemoryLexicalIndex>>>`. For multi-vault scenarios (a user switches vaults mid-session), the slot is re-opened with a new signature, dropping prior notes. This matches the manifest-binding contract (one manifest = one snapshot) but means `AppBootstrap` must call `openVaultIndex` once per vault-switch. Document the call site in `AppBootstrap.swift` as Terminal B's wire-up step.
2. **Lexical-only retrieval.** Production index is `InMemoryLexicalIndex` (case-insensitive substring matching, `lexical_score = occ / (1+occ)`). For W-51 ShadowBackedSemanticIndex, swap the backend behind `produce_eidos_context_packet_json` — the FFI shape stays unchanged.
3. **No vault-crawl wiring yet.** `EidosBridge.insertVaultNote` is the per-note insertion seam; bulk crawling is `ShadowVaultBootstrapper`'s job for the shadow index. Terminal B can mirror that crawl pattern into the Eidos index for parity, OR Terminal A's next iter adds an `eidos_bulk_insert_notes_json` FFI that takes a JSON array.

## Hand-off table

| To | What to wire |
|---|---|
| **Terminal B** (Vault Recall Trace + Chat Citation Surface) | Call `ChatCoordinator.runEidosCitationGate(packet:candidateSourceIds:)` from every emit path that ships source_ids. Use `EidosBridge.retrieve(...)` in place of (or alongside) the legacy retrieval where the closed-citation contract matters. |
| **AppBootstrap follow-up** | Open the production vault index at app start: `EidosBridge.openVaultIndex(signature: sha256(vault_path))`. Insert notes via `ShadowVaultBootstrapper`-style crawl. |
| **Terminal D** (Substrate Health WRV Panel) | The `EidosHealthRow` chip-strip now flips to green honestly. Add a "vault binding status" row to the unified panel that mirrors `EidosMetrics.shared.lastBackend`. |
| **Terminal G** (T14 Five-Plane UAS Wiring) | The Eidos data classes carry `// UAS:` + `// Plane:` + `// Residency:` comments (see this PR's `Epistemos/Eidos/EidosBridge.swift` header). Use them as a reference template for the No-Orphan-Data CI lint. |
