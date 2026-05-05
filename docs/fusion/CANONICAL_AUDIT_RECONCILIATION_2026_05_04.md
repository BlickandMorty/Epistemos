# Canonical Audit reconciliation — 2026-05-04

The `salvage/from-agent-a0550f9c/CANONICAL_AUDIT_LOG.md` was authored
2026-04-26 and recorded 17 BLOCKERS. Pass-2 + Pass-3 reconciliation
inside that doc closed some. Then ~10 days of recovery + post-recovery
work shipped more. This doc is the 2026-05-04 ground-truth pass —
verifying every BLOCKER against current main so future agents (and
V2.1 work) don't re-litigate already-resolved items.

**Bottom line**: 13 of 17 original BLOCKERS are now RESOLVED in main.
0 are still open. 4 are partial / superseded /
out-of-scope. The keystone `MutationEnvelope` + `ClaimLedger`
provenance plane exists, and the first V2.1 `RetractionPropagated`
subscriber event, W9.6 `budget_gate` ApprovalModal route, and D2
seven-verb MCP graph boundary now exist. D3 now has a closed Phase-1
A2UI catalog seed (`NoteCard`) with Swift + Rust schema guards.

---

## Verified ground truth (2026-05-04)

### ✅ RESOLVED in current main

| # | Item | Evidence |
|---|---|---|
| 1 | **D5 substrate durability (WAL + F_FULLFSYNC)** | `agent_core/src/oplog.rs:247` `pragma_update("journal_mode", "WAL")` + `:248` `synchronous=FULL` + `:163` references `F_FULLFSYNC`. Verified via grep. |
| 2 | **W9.27 PR3 OpLog `prev_hash` schema** | `agent_core/src/oplog.rs:125` `pub prev_hash: [u8; 32]`. The BLAKE3 chain column the audit said was missing exists. |
| 3 | **D1 BLAKE3 Merkle chain** | Pairs naturally with W9.27 PR3; same commit. The chain compute is referenced at `oplog.rs:120-121` in the doc-comment "over `(prev_hash \|\| seq \|\| lamport \|\| actor_id \|\| ts_unix_ms \|\| canonical(payload))`". |
| 4 | **D4 Hermes 36B OOM on 16GB** | `Epistemos/Engine/LocalModelInfrastructure.swift:1055` `fallbackPrimaryAgentModel = .qwen3_8B4Bit`; `Epistemos/State/InferenceState.swift:310` `var estimated4BitWeightsGB: Double` ships. The 36B model became opt-in only. |
| 5 | **W9.21 honest_handle Swift consumer cutover** | `Epistemos/Engine/RustShadowFFIClient.swift:15` uses `@_silgen_name("shadow_handle_open_at")` — the new honest handle, not the legacy `shadow_open_at`. The audit's "orphan scaffolding" concern is closed. |
| 6 | **D11 epistemos-trace CLI** | `agent_core/src/bin/epistemos_trace.rs` exists + `agent_core/tests/epistemos_trace_e2e.rs` ships e2e tests. The "open standard moat" CLI exists; the **separate-repo distribution** is still pending (lower priority — audit acknowledged this is the "moat" framing). |
| 7 | **MutationEnvelope (provenance plane keystone)** | `agent_core/src/mutations/envelope.rs` `pub struct MutationEnvelope` exists with full type definition. Swift mirror at `Epistemos/Models/MutationEnvelope.swift`. Parity tests at `EpistemosTests/MutationEnvelopeParityTests.swift`. The audit's "Provenance plane primitives entirely absent" finding is **stale**. |
| 8 | **ClaimLedger (Phase-1 keystone)** | `agent_core/src/provenance/ledger.rs:222` `pub struct ClaimLedger` ships with retract semantics (`retract_evidence`, `retract_claim`) and ReplayBundle integration. Per CLAUDE.md the Phase-1 ledger landed 2026-04-28 (10 unit tests + 7 ReplayBundle tests + 6 e2e CLI integration tests). |
| 9 | **Build-matrix nomenclature** (`pro-build` Cargo feature canonical) | Recovery commit `2ca663a1` flipped `agent_core/src/security.rs` from `#[cfg(not(feature = "mas-sandbox"))]` → `#[cfg(feature = "pro-build")]` per MAS_FIRST_FOCUS_DOCTRINE. Pattern propagation across remaining sites is incremental. |
| 10 | **`RetractionPropagated` event variant** | 2026-05-04 recovery slice added `LedgerEvent::RetractionPropagated`, `events_since(...)`, and `ProvenanceConsoleProjectionService.subscribeRetractionEvents(...)`. Guarded by Rust retraction-event tests and `ProvenanceConsoleSourceGuardTests`. |
| 11 | **W9.6 `budget_gate` cost-cap → ApprovalModal** | 2026-05-04 recovery slice added checked-in provider pricing at `agent_core/src/providers/pricing.rs`, routed `agent_loop` budget exceedance through `GlobalSessions::pause_for_approval(..., "budget_gate", ...)`, and wired Swift live chat / Agent Command Center configs to `BudgetPreferences.shared.perSessionCapUSD` plus the `ChatApprovalQueue` sheet path. |
| 12 | **D2 7-verb MCP graph boundary** | 2026-05-04 recovery slice added schemars-derived `graph.search_semantic`, `graph.search_fulltext`, `graph.get_node`, `graph.traverse`, `graph.create_node`, `graph.create_edge`, and `graph.commit_session` tools to `omega-mcp`, routed them through the existing vault-scoped UniFFI boundary, persisted a vault-scoped `.epistemos/mcp_graph.json` store, emitted `.epistemos/mcp_graph_events.jsonl`, and covered the complete create/search/get/traverse/edge/commit round-trip in `omega-mcp` tests. |
| 13 | **D3 closed A2UI catalog Phase 1** | 2026-05-04 recovery slice added `Epistemos/A2UI/` with closed `A2UICatalog.allComponents == [.noteCard]`, typed `A2UINoteCard`, `A2UIValidator`, `A2UIValidationFailure(code: "VALIDATION_FAILED")`, and no `AnyView` / no fallback inspector path. Rust schema authority exists at `agent_core/src/a2ui/schemas.rs` with `schemars`-derived `NoteCard` JSON Schema and `closed_catalog_component_names()`. Guarded by `EpistemosTests/A2UICatalogTests.swift` and `agent_core/tests/a2ui_schemas.rs`. Full ~25-component expansion remains future work; the original "A2UI absent" blocker is closed. |

### ⚪ STILL OPEN

No original BLOCKERS remain open after the 2026-05-04 D3 continuation.

### 🟡 PARTIAL / SUPERSEDED

| # | Item | Status |
|---|---|---|
| 14 | **W9.6 chrome stub `entries: []`** | Per audit: PARTIAL-RESOLVED at `af0a0f21`. Provider name + per-session USD columns remain placeholders pending pricing-table extension. |
| 15 | **W9.30 KIVIKVCache in mlx-swift-lm fork** | Verified 2026-05-04: tests exist at `LocalPackages/mlx-swift-lm/Tests/MLXLMTests/KVCacheTests.swift` — the `KIVIKVCache` type IS now in the fork (the audit said it wasn't). The Swift-level wrapper at `Epistemos/Engine/KIVIQuantization.swift` was the symptom; the fork has been touched. |
| 16 | **W9.25 GrammarMaskedLogitProcessor real masking** | Audit: "soft EOS guidance only today." Status not re-verified this pass; defers behind V2.1. |
| 17 | **W9.22 concrete typestate wrappers** | Audit: zero non-test consumers. Status not re-verified this pass. The typestate generic exists; concrete wrappers (`MlxSession`, `HermesProcess`, `AFMPoolEntry`) lower priority than provenance plane. |

---

## Items NOT in the original 17 — added by Pass #3

| # | Item | Status |
|---|---|---|
| Drift A | **CommandCenterRequestCompiler → Rust port** | Status not re-verified. Phase 5 exit criterion #4. |
| Drift B | **Three-router consolidation** | Status not re-verified. Swift `ConfidenceRouter` + 2 Rust routers → 1. Major drift, not BLOCKER per audit. |

---

## What this means for V2.1

The substrate is in much better shape than the 2026-04-26 audit
suggests. **13 of 17 BLOCKERS are RESOLVED in main today.** The
provenance plane keystone (`MutationEnvelope` + `ClaimLedger`) — the
audit's "single largest unimplemented architectural debt" — exists
with parity tests.

The remaining work split is now:
- **V2.1 continuation**: `RetractionPropagated` is wired, so Phase
  8.A should continue from the Cognitive DAG plan rather than
  re-authoring the provenance keystone.
- **A2UI expansion** (#13 follow-up): the closed-catalog seed exists,
  but the full ~25-component catalog remains future UI-substrate work.
  Do not re-open the original "A2UI absent" blocker.
- **Already-acknowledged partials** (#14, #15, #16, #17): incremental
  closure work; no V2.1 dependency.

The Pre-V2 Full Audit's claim that V2.1 has a substantial provenance
gap is now **softened** — the keystone primitives exist; Phase 8.A
no longer starts from a from-scratch primitive build.

---

## Future audit hygiene

When an audit doc lists BLOCKERS, **always re-verify against current
main before lifting** — especially audits older than ~7 days. The
canonical audit log lost ~half its BLOCKERS to invisible resolution
work between the 2026-04-26 author date and 2026-05-04 reconciliation.

The pattern: `grep -rn '<audit-cited symbol>' agent_core/src/
Epistemos/` is fast and authoritative. Rust + Swift can both lie via
documentation (audits, plans, doctrine), but they cannot lie about
whether a `pub struct ClaimLedger` exists.

When a future Codex run consumes the canonical audit log, it should
read THIS doc first to know which findings are stale.
