# Fused Audit View — Blocker-Centric Cross-Reference

> **Status**: DERIVED VIEW (not source of truth) — rebuilt from `CANONICAL_AUDIT_LOG.md` (deep architectural drift; 3 passes 2026-04-26 → 2026-04-27) + `CRITIQUE_LOG.md` (rolling per-commit auditor; 14 passes on 2026-04-27).
> **Authoritative**: the source logs win on any conflict. This is a single-pane consolidation.
> **Last sync**: 2026-04-27T15:00:00Z. Score: **14 Blockers + 1 Major drift + 1 partial-resolved** open / 49 audited.

---

## §1 — Recently RESOLVED (kept logged for resolution-trail)

| ID | One-line description | Resolved by commit | Architectural lens (CANONICAL_AUDIT) | Per-commit lens (CRITIQUE) |
|---|---|---|---|---|
| **D5** | Substrate durability — `PRAGMA journal_mode=WAL` + `F_FULLFSYNC` on every commit | `6d78593b` | Pass #2 RESOLVED — `oplog.rs:144` + `oplog.rs:186` + `storage/vault.rs:110-115`; 2 verifying pragma tests; 708/708 cargo green | Open since CANONICAL Pass #1; not separately tracked in CRITIQUE per-commit |
| **D4** | Hermes 36B OOM on 16 GB Mac (~18 GB at 4-bit exceeds ceiling) | `8e4e018d` + `4c0c7e17` | Pass #2 RESOLVED — `fallbackPrimaryAgentModel = .qwen3_8B4Bit`; opt-in 36B gated to ≥32 GB; 6 invariant tests; `LocalTextModelID.estimated4BitWeightsGB` for all 46 model cases | Pass #12+ tracked the in-flight stash; resolved by ship |
| **D1 + W9.27 schema** | BLAKE3 Merkle chain + `prev_hash BLOB(32)` column | `fe97e512` | Pass #2 RESOLVED — domain-separated `compute_chain_link`; reopen restores chain tip; 5 new + 713 total cargo tests | Not separately tracked |
| **N1 Phase 1** | Prompt Tree (JSPF + PTF) cache-telemetry wire to W9.6 dashboard | `b8d779ca` + `af0a0f21` + `12183f29` | (N1 is Bucket N, not D-series; tracked in CRITIQUE) | Pass #14 RESOLVED — 3-PR ladder: AgentResultFFI cache fields → EventStore session_metrics columns → SpendDashboardHost render |
| **W9.6 dashboard `entries: []`** | Cost dashboard chrome stub (no real data) | `af0a0f21` | Pass #2 PARTIAL-RESOLVED — `SpendDashboardHost` mounted at `AgentSectionDetailView.swift:135`; cache-hit-rate row live with color tinting; provider name + per-session USD columns still placeholder | Pass #1 finding closed at Pass #14 |
| **W9.29 ThermalMonitor orphan** | `ThermalMonitor.shared` had zero callers | `336a5f0c` | (Caught at CANONICAL Pass #1) | Pass #1 → Pass #2 CLEAN — `MLXInferenceService.swift:38` calls `ThermalMonitor.currentTokenBudgetMultiplier()` |
| **StructureRegistry orphan** | Registry had no readers | `33995d25` | (Not in CANONICAL) | Pass #1 → Pass #2 CLEAN — `StructuredSurfacesView.swift:51,53` reads registry; mounted at `AgentSectionDetailView.swift:128` |

---

## §2 — STILL OPEN — priority order (post Pass #3 reconciliation)

Numbered by the priority queue in CANONICAL_AUDIT_LOG Pass #3 §"Updated priority queue".

| # | ID | Description | Architectural lens (CANONICAL) | Per-commit lens (CRITIQUE) | Required fix | Files / verification |
|---|---|---|---|---|---|---|
| 4 | **W9.21 PR4** | Honest FFI — Swift consumer cutover; 4 honest_handle modules exist with **zero non-test Swift consumers**. Orphan-scaffolding pattern violates Doctrine §6 #14 even with WRV_EXEMPT. | Pass #1 Blocker; persists Pass #3 | Pass #2 noted "FOUNDATION discipline OK pending PR3+PR4" | Cut `RustShadowFFIClient.swift:39` to `shadow_handle_open_at` / `shadow_handle_search` honest-handle exports (already shipped in `dcc5521f` PR1). Graph-engine PR3 deferred indefinitely per `b5a80dca` analysis (Metal hot-path Mutex tradeoff). | `grep -rn "shadow_handle_open_at\|shadow_handle_retain\|shadow_handle_release" Epistemos/` should hit non-test Swift |
| 5 | **W9.8** | NSAlert → ApprovalModalView; production approval at `ChatCoordinator.swift:2844` still uses NSAlert; ApprovalModalView mounted only in Settings preview | Pass #1 Blocker; persists Pass #3 | Pass #1 noted "preview-only wire"; persists Pass #14 | Wire `agent_core::session::PausedForApproval` → `StreamingDelegate` → `ApprovalQueue` → `ApprovalModalView` for real agent runs. Add XCTest. | `grep -n "ApprovalModalView" Epistemos/App/ChatCoordinator.swift` should hit production path |
| 6 | **AnyView violations** | Doctrine §6 #6 forbids `AnyView` in render hot paths; ~14 violations across `Settings/SettingsView.swift:2851-2864`, `Graph/HologramOverlay.swift:103-243`, `Graph/HologramSearchSidebar.swift:701, 717`, `Graph/GraphFirstOpenTitle.swift:106, 114` | Pass #1 Warning (cross-cutting #6); persists Pass #3 | Not separately tracked | Hand-replace AnyView with typed view-builder enums or specific view types. Don't wait for W9.15 routing macro. | `grep -rn "AnyView" Epistemos/Views/ \| wc -l` target: 0 |
| 7 | **W9.27 PR3.5** | OpLogFFIClient.swift; `OpLog::open_persistent` has zero Swift consumers despite schema being right post-`fe97e512` | Pass #1 Blocker (schema portion RESOLVED at PR3); orphan-scaffolding remains | Not separately tracked | Mirror `RopeFFIClient` pattern; add `Epistemos/Engine/OpLogFFIClient.swift` + VaultIndexActor subscription | `grep -rn "OpLog\|oplog" Epistemos/` should find production caller |
| 8 | **W9.26 PR4** | NoteFileStorage rope migration; `RopeFFIClient.swift` has **zero non-test callers**; orphan-scaffolding | Pass #1 Blocker; persists Pass #3 | Pass #2 noted PR3 shipped FOUNDATION; "WRV clock running for PR4" | Migrate `Epistemos/Sync/NoteFileStorage.swift` (49 KB) + `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (63 KB) to use rope handle | `grep -rn "RopeFFIClient" Epistemos/ \| grep -v Test` should hit production |
| 9 | **W9.22** | Concrete typestate wrappers; `Lifecycle<T,S>` generic exists with **zero concrete consumers**; no `MlxSession`, `HermesProcess`, `AFMPoolEntry` per dossier | Pass #1 Blocker; persists Pass #3 | Not separately tracked | Build the 3 concrete wrappers using both honest-FFI handles (W9.21) + Lifecycle. OR demote item to ⚪ PENDING. | `grep -rn "Lifecycle<" agent_core/src/ Epistemos/ \| grep -v test` should find concrete uses |
| 10 | **Drift A (NEW)** | `Epistemos/Engine/CommandCenterRequestCompiler.swift:64-80` resolves context refs + runtime selection + tool permission + execution policy + routing — every decision PLAN_V2 §3.1 says belongs to Rust. **Phase 5 exit criterion #4 unaddressed; doctrine §3.1 violation; biggest single architectural drift.** | NEW Pass #3 Blocker (cited from `PHASE_6_CLARK_HANDOFF` + `CLAUDE_CANONICALIZATION_REDO_HANDOFF`) | Not in CRITIQUE | New Rust FFI `compile_command_center_request(...)` in `agent_core/src/command_center.rs` + `bridge.rs`. Swift becomes parser + UI binder only. Land behind feature flag for one release cycle before removing legacy. | Tests: explicit-brain-choice parity, unavailable-brain truthfulness, allowlist parity, inspector-diagnostics parity |
| 11 | **Drift B (NEW)** | Three-router architecture: `Epistemos/LocalAgent/ConfidenceRouter.swift` + `agent_core/src/routing.rs` + `epistemos-core/src/agent_runtime/routing.rs` | NEW Pass #3 Major (architectural duplication, not Blocker) | Not in CRITIQUE | Decide canonical (per CLAUDE.md FILE MAP: `agent_core/src/routing.rs`). Migrate loser logic; delete dead file. Make Swift's `ConfidenceRouter` a pure classifier feeding the Rust router. Run 50+ sample queries; assert same decision within tolerance. | `grep -rn "fn route\|func route" Epistemos/ agent_core/ epistemos-core/` |
| 12 | **W9.6 budget_gate** | Cost-cap → ApprovalModal flow does not exist | Pass #1 Blocker (DoD item 3) | Not separately tracked | Wire budget cap to fire ApprovalModal with `tool_name = "budget_gate"` + `args_json` carrying current spend + cap | `grep -rn "budget_gate" agent_core/src/` |
| 13 | **W9.30** | KIVIKVCache in wrong package; `Epistemos/Engine/KIVIQuantization.swift` env-flag scaffold; **mlx-swift-lm fork untouched** (where `KIVIKVCache: QuantizedKVCacheProtocol` must live per dossier line 1278) | Pass #1 Blocker | Not separately tracked | Ship `KIVIKVCache` in `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift` (sibling to `QuantizedKVCache`); extend `GenerateParameters.kvScheme` enum at Evaluate.swift:1560 | `grep -n "KIVIKVCache\|KVQuantScheme" LocalPackages/mlx-swift-lm/...KVCache.swift Evaluate.swift` |
| 14 | **W9.25 grammar masking** | `mlx-swift-structured` linked but `isFullyConstraining = false` at `MLXConstrainedGenerator.swift:34`; soft EOS only — real grammar masking unimplemented | Pass #1 Blocker (status overstated as 🟢 SHIPPED) | Not separately tracked | Replace `JSONSchemaLogitProcessor` with `GrammarMaskedLogitProcessor`; flip `isFullyConstraining = true` | `grep -n "isFullyConstraining" Epistemos/Omega/Inference/MLXConstrainedGenerator.swift` |
| 15 | **D2** | 7-verb MCP graph boundary missing. Research mandates `search_semantic / search_fulltext / get_node / traverse / create_node / create_edge / commit_session`. Actual `omega-mcp/src/vault.rs` exports: `read_file / write_file / list_files / search_notes / execute_vault_tool`. Different surface entirely. | Pass #1 Blocker (architectural primitive); persists Pass #3 | Not in CRITIQUE | Either ship the 7-verb dispatcher OR document existing surface as the chosen alternative + update doctrine | `grep -rn "search_semantic\|create_node\|commit_session" omega-mcp/src/` |
| 16 | **D3** | Closed A2UI catalog absent. `Epistemos/A2UI/` directory does not exist. `A2UIValidationFailure` audit-finding type does not exist. Doctrine §6 #4 has zero enforcement. | Pass #1 Blocker; persists Pass #3 | Not in CRITIQUE | Build closed catalog with Phase 1 NoteCard component per execution map §D3 | `ls Epistemos/A2UI/` should exist |
| 17 | **D9** | Skills as graph nodes — `agent_core/src/tools/skills.rs:258` writes to filesystem (`~/.hermes/skills/`) directly. No MCP intercept. No graph node creation. No `Skill` node type in substrate. | Pass #1 Blocker | Not in CRITIQUE | Build the MCP intercept per execution map §D9; add `Skill` node type | `omega-mcp/src/skills.rs` should exist |
| 18 | **D11** | `epistemos-trace` CLI does not exist. Doctrine §5.1 mandates separate `epistemos-provenance-standard` repo with CLI binary (verify, replay, lint, diff). Only in spec docs. | Pass #1 Blocker (open-standard moat depends on it) | Not in CRITIQUE | Either ship D11 (separate repo) OR explicitly label "moat strategy abandoned for V1.5" in PLAN_V2 | `grep -rn "epistemos-trace" /Users/jojo/Downloads/Epistemos/ --include="*.toml"` |
| 19 | **KEYSTONE: Provenance plane** | `MutationEnvelope`, `ProposedEnvelope`, `ClaimLedger`, `RetractionPropagated` — **zero hits across all Rust + Swift code**. Doctrine §3 keystone primitive 100 % absent. Doctrine §1 (four planes), §2.1 (envelope split), §2.5 (one ledger five projections), §5.2 (ReplayBundle byte-equivalence), and the 7-verb MCP `commit_session` verb are all hollow without it. | Pass #1 Blocker (named **largest unimplemented architectural debt**); persists Pass #3 | Not in CRITIQUE | Either build the provenance plane (`commit_envelope`, `retraction_propagation` in `agent_core/src/provenance/ledger.rs`) OR explicitly mark in PLAN_V2 that the provenance plane is V2 work | `grep -rn "MutationEnvelope\|ClaimLedger\|RetractionPropagated" agent_core/ Epistemos/` should find non-zero |

---

## §3 — Operational notes (NOT drift; preserved so future sessions don't relitigate)

From CANONICAL_AUDIT_LOG.md Pass #3 (`docs/architecture/` reconciliation pass):

- **Note A — Swift 6 strict-concurrency cascade-error trap**: a single Swift 6 data-race violation in ONE test file cascades ~50 unrelated `@const`/`@section` macro errors across other test files in the same compilation batch. Don't chase the cascade — trace back to the recent test edit with a `@Sendable` closure or `note.userInfo` capture. Source: `PHASE_7_CODEX_AUDIT_HANDOFF_2026_04_15.md §3.1`.
- **Note B — `image_generate` is no longer drift**: PHASE_6 Drift 3 (FAL cloud-only vs PLAN_V2 §5.1 MLX-first) was resolved by §16 amendment to PLAN_V2. Current §16: cloud image generation is explicit opt-in only, never silent fallback. FAL provider with explicit `provider: "fal"` opt-in is now canonical.
- **Note C — `codex/runtime-input-audit` perf fixes are baseline**: fenced `tool_call` parser fix, MLX unload Metal-working-set release, cloud direct-stream manifest tightening, essay-vs-note phrasing escalation, Mini Chat Tools-mode pill, deferred Apple hybrid embedding lookup, dangling fenced-language marker suppression — all baseline. NOT drift. Source: `PERF_REPAIR_REPORT_2026_04_21.md`.
- **Note D — Phase 6 / 6.5 / 7 closures intentionally deferred (does NOT block V1.5)**: substantial code in tree but formal closures depend on manual runtime verification (real outbound credentials + macOS permissions) the operator chose to defer. V1.5 work is **orthogonal** to those phase closures.
- **Note E — V1_DECISION performance budget targets (synced 2026-04-27 from `/Downloads/ambient/`)**: ambient corpus's `EPISTEMOS_V1_DECISION.md` (now in `00_canonical_authority/ambient_V1_DECISION.md`) ships a concrete performance budget table that any recall-related Blocker should be measured against. End-to-end recall pass: <25ms target, 40ms hard ceiling. MainActor work per recall update: <1ms p99, 2ms ceiling. Metal frame budget at 120Hz: <6ms target, 8.33ms ceiling. **6-state Halo FSM** (Dormant → Sensing → Available → Open → EditingNote / SummarizingChat) is the canonical state model for the Phase H feature. **V1 scope ruling**: V1 = MAS sandboxed Halo+Shadows release only; V1.5 = post-V1 broader item set. Use these numbers when triaging W9.6/W9.8/W9.21/W9.22/W9.26/W9.27 etc. for whether they actually move the user-visible perf bar.
- **Note F — Deterministic performance hard constraints (synced 2026-04-27 from `/Downloads/opt/`)**: `perf_DETERMINISTIC_PERFORMANCE_PLAN.md` (now in `20_canonical_research/`) ships 5 hard constraints that should govern any new perf work: NO hot-path serialization (>100 Hz events use `repr(C)` ring buffer); NO main-thread Metal compilation (PSOs from `MTLBinaryArchive`); NO string-keyed dispatch in inner loops (phf or compile-time enum); NO allocation in render frames (bumpalo arenas reset per frame); EVERY optimization ships with a signpost + CI p99 assertion. Sprint 0 (signposts + GRDB pragmas + LTO) is high-value low-risk; should ship before more feature work lands.

---

## §4 — Recommended ship order (next 3 commits — non-conflicting; suitable for parallel `isolation: "worktree"` agents)

From CANONICAL_AUDIT_LOG.md Pass #2 §"Recommended ship order":

1. **W9.21 PR4 Swift consumer cutover** (Lane C, Swift, ~1.5 hr) — closes longest-standing orphan-scaffold pattern.
2. **W9.8 NSAlert → ApprovalModalView** (Lane C, Swift, ~2 hr) — production approval-modal wire.
3. **AnyView 16-violation cleanup** (Lane A, Swift, ~2 hr) — doctrine §6 #6 enforcement.

These touch disjoint files; safe for parallel worktree builders.

---

## §5 — Where to look for full context

- Strategic / architectural-drift view: `CANONICAL_AUDIT_LOG.md` (3 deep passes, 836 lines).
- Per-commit / WRV-violation view: `CRITIQUE_LOG.md` (14 hourly passes, 1715 lines).
- Per-item file:line + WRV expectations: `00_canonical_authority/03_EXECUTION_MAP.md`.
- Live status: `V1_5_IMPLEMENTATION_TRACKER.md`.

---

## §6 — Last sync

2026-04-27T15:00:00Z — derived from CANONICAL_AUDIT_LOG.md Pass #3 + CRITIQUE_LOG.md Pass #14. Re-sync this view whenever either source log gains a new pass.
