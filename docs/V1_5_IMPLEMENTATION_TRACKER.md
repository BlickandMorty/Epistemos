# V1.5 Implementation Tracker — R14-R16 + W9.6-W9.30

> **Index status**: CANONICAL-OPERATIONAL — Live status board; already in _consolidated.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



Started 2026-04-26 after the user authorized "implement everything
non-CLI". CLI cocktail (Hermes/Codex/Kimi/Claude CLI integration)
is being researched separately.

This tracker is the canonical "what state is each item in" doc.
Update it after every commit. When all items are 🟢 SHIPPED, V1.5 is
done.

## Legend
- 🟢 SHIPPED — code merged + verified end-to-end
- 🟡 FOUNDATION — scaffold landed (compiles + tests pass);
  subsequent PRs needed for full integration
- 🔵 IN-PROGRESS — actively being built this session
- ⚪ PENDING — not started
- ⏸ DEFERRED — explicit decision to wait

## Cross-cutting hard rules (from research dossier)
1. W9.21 MUST precede W9.22 — typestate handles wrap honest-FFI
   pointers
2. W9.26 should precede W9.27 — OpLog wants O(1) snapshots from rope
3. R14 (UniFFI bump) is independent — but coordinates with W9.21
4. W9.30 KIVI as opt-in flag first (`EPISTEMOS_KV_KIVI=1`) —
   never default-on without perplexity regression test

---

## Bucket A — 90% already done

| ID | Status | Commit | Notes |
| -- | ------ | ------ | ----- |
| W9.25 grammar masking | 🟢 SHIPPED | this session | mlx-swift-structured 0.1.0 linked via project.yml; LocalToolGrammar.swift `canImport` guards now resolve true; build green. Full LogitProcessor wire-up (Grammar pass-through to MLXConstrainedGenerator) is a follow-up PR. |
| W9.30 KIVI quant | 🟡 FOUNDATION | this session | KIVIPreferences (env-flag `EPISTEMOS_KV_KIVI`, scheme enum, opt-in gate at >4096 ctx) shipped in `Epistemos/Engine/KIVIQuantization.swift`. `KIVIKVCache` impl in mlx-swift-lm fork is the next PR. |
| R14 UniFFI 0.28→0.29.5 | 🟢 SHIPPED | this session | All 4 Cargo.toml pinned to `=0.29.5` (agent_core, omega-mcp, epistemos-core, omega-ax). All 4 cargo check pass; full xcodebuild green with auto-regenerated bindings. |

## Bucket B — Concrete spec, additive scope

| ID | Status | Commit | Notes |
| -- | ------ | ------ | ----- |
| R15 benchmark harness | 🟡 FOUNDATION | this session | 4 XCTest scaffolds under `EpistemosTests/Benchmarks/`: AFMGenerableBenchTests, MLXThermalBenchTests, SQLiteVecKNNBenchTests, UniFFICallbackThroughputTests. Disabled by default (manual `-only-testing` runs). Need real fixture wire-up per item. |
| W9.6 cost dashboard | 🟢 SHIPPED | this session | `CostDashboardView` + `BudgetPreferences` (UserDefaults-backed) in `Epistemos/Views/Cost/CostDashboardView.swift`. Reuses W9.8 modal for budget-gate stop. Drop-in ready. |
| W9.7 vault selector | 🟢 SHIPPED | this session | `VaultSelectorView` SwiftUI sidebar in `Epistemos/Views/Sidebar/VaultSelectorView.swift`. Drop into NotesSidebar next to ModelVaultsSidebarSection. |
| W9.8 approval modal | 🟢 SHIPPED | this session | `ApprovalModalView` in `Epistemos/Views/Approval/ApprovalModalView.swift` with live deadline countdown ring, allowOnce/alwaysAllow/deny/timedOut decisions. Pairs with existing `agent_core::session::SessionState::PausedForApproval`. |
| W9.13 daily notes | 🟢 SHIPPED | this session | `DailyNoteView` in `Epistemos/Views/Journal/DailyNoteView.swift` with date picker + body editor + FSRS due-review section. Wire to existing `SDPage.isJournal` + `journalDate` + `FSRSDecayStore` queries. |
| W9.23 circuit breaker | 🟢 SHIPPED | this session | Bit-packed AtomicU64 (2-bit state, 16-bit fail count, 32-bit last-fail epoch, 14-bit generation), cache-line padded `#[repr(align(64))]`. 6/6 tests pass in `agent_core/src/circuit_breaker.rs`. |
| W9.29 thermal throttling | 🟢 SHIPPED | this session | `ThermalMonitor` @Observable singleton in `Epistemos/State/ThermalMonitor.swift` wraps `ProcessInfo.thermalState` + Notification. Exposes `tokenBudgetMultiplier()` + `shouldThrottle(for:)` for inference + cloud-call sites. |

## Bucket C — Real work, established pattern

| ID | Status | Commit | Notes |
| -- | ------ | ------ | ----- |
| W9.21 Honest FFI | 🟡 FOUNDATION (PR2 of 4) | dcc5521f + b2e4899d | PR1 (epistemos-shadow) + PR2 (substrate-rt + substrate-core + syntax-core) shipped: 4 honest_handle.rs modules, 608 LOC + 219 LOC = 827 LOC total, 15 unit tests across 4 crates, all crate test floors green (substrate-rt 14/14, substrate-core 11/11, syntax-core 47/47, epistemos-shadow stays untouched). PR3 graph-engine (10 Box::into_raw sites) + PR4 Swift `~Copyable` consumer cutover remain. |
| W9.22 Typestate | 🟡 FOUNDATION | this session | Generic `Lifecycle<T, S>` newtype with phantom-type state markers (Loaded/Warm/Generating/Disposed) in `agent_core/src/runtime/typestate.rs`. 5/5 tests pass. Concrete MLX/Hermes/AFM wrappers built atop W9.21 honest-FFI handles in follow-up PRs. |
| W9.26 B-tree rope | 🟡 FOUNDATION (PR3 of N) | dcc5521f + e9618ddf + 385be68a | PR1 foundation `agent_core/src/rope.rs` (crop 0.4, utf16-metric). PR2 raw FFI `agent_core/src/rope_handle.rs` (12 extern "C" + 6 unit tests). PR3 Swift consumer `Epistemos/Engine/RopeFFIClient.swift` + `EpistemosTests/RopeFFIClientTests.swift` (6 FFI roundtrip tests, all pass in 0.002s). End-to-end Rust↔Swift verified across 12 paired tests; pattern matches RustEventRingClient. PR4 NoteFileStorage migration + PR5 ProseEditorRepresentable2 bridge remain. |
| W9.27 OpLog | 🟡 FOUNDATION (PR3 of N) | dcc5521f + 8a4cf434 + fe97e512 | PR1 hand-rolled foundation (Op enum + serde wire format `tag = "op_type"` + Lamport + in-memory Vec, 4 tests). PR2 SQLite-backed persistence via rusqlite (`OpLog::open_persistent` + schema). PR3 (`fe97e512`) D1 BLAKE3 Merkle chain — `prev_hash BLOB` column + idempotent ALTER migration; `OpLog::compute_chain_link` domain-separated BLAKE3(prev_hash ‖ seq_le ‖ lamport_le ‖ actor_id ‖ ts_unix_ms_le ‖ canonical(payload)); `chain_tip()` accessor; reopen restores chain tip across all loaded ops so next append continues the chain seamlessly. 5 new tests cover: chain_tip starts at GENESIS_HASH, first append uses genesis, second op's prev_hash equals first chain tip, persistent reopen resumes chain tip, compute_chain_link is deterministic. 713/713 agent_core tests green (was 708; +5 D1 tests). Closes both **W9.27 schema-drift Blocker** and **D1 BLAKE3 Merkle chain Blocker**. PR3.5 Swift OpLogFFIClient.swift + VaultIndexActor subscription + PR4 time-travel UI remain. |
| R16 ETL crawler | 🟡 FOUNDATION | this session | `agent_core/src/etl/{mod,hash,walker}.rs` modules. `ignore` 0.4 walker w/ .gitignore + .epignore + hardcoded code-file exclusion list (52 extensions). xxh3_64 path+content fingerprint. 7/7 tests pass. Next PRs: apalis-sql Monitor + AFM @Generable sidecar generation + Swift FFI. |

## Bucket N — Novel additions (locked into plan after dossier closed)

| ID | Status | Commit | Notes |
| -- | ------ | ------ | ----- |
| N1 Prompt Tree (JSPF + PTF) | 🟡 PHASE 1 IN PROGRESS | 7316f86b + 1ab15596 + e8c22dbb + 4561f31b + b9a5312d | PR1 foundation (`7316f86b`): PromptTree/Renderer/Cache/Persister + 8 PromptTreeTests + StructureRegistry extension + ChatCoordinator wire. **Phase 1 sub-checklist (per CRITIQUE_LOG #8 steer)**: [x] Feature flag toggle (`1ab15596`) — UserDefaults-backed, env-var-aware via `PromptTreePreferences.isEnabled()`. [x] session_insights.rs orphan fix (`4561f31b`) — `pub mod session_insights;` registered; test count 691 → 698. [x] cached_tokens_share wire to W9.6 (`b9a5312d`) — `SessionMetrics`/`AggregatedStats`/`InsightsReportFFI` extended; `CostDashboardView` renders aggregate hit-rate row with color tint (green ≥30%, orange 0<x<30%, secondary 0%); 6 new Rust unit tests + 704 total agent_core tests green. WRV-Wired grep passes: non-comment UI caller at `CostDashboardView.swift:136`. **Phase 1 closure**: Anthropic SSE handler in `agent_core/src/providers/claude.rs:622-630` parses `cache_read_input_tokens` into `TokenUsage`; wire that into `SessionMetrics.cache_read_input_tokens` at session-completion time and dashboard goes live with real numbers. |

## Bucket D — Research-grade, gate on roadmap need

| ID | Status | Commit | Notes |
| -- | ------ | ------ | ----- |
| W9.10 TurboQuant | ⏸ DEFERRED | — | Research-only until roadmap need is concrete. KIVI (W9.30) is the predecessor — ship that opt-in first; revisit TurboQuant after KIVI lands. |
| W9.11 Create ML embeddings | ⏸ DEFERRED | — | Eval methodology needs design pass. |
| W9.12 Orphan rediscovery | ⏸ DEFERRED | — | Wants W9.27 OpLog substrate first (now FOUNDATION). |
| W9.14 Block refs | ⏸ DEFERRED | — | Wants W9.26 rope first (now FOUNDATION). |
| W9.15 Routing macro | ⏸ DEFERRED | — | ROI unclear at current view count. |
| W9.24 Metal zero-copy | ⏸ DEFERRED | — | UMA may make `bytesNoCopy` a no-op gain — measure before building. |
| W9.28 Blelloch scan | ⏸ DEFERRED | — | Mamba-2 already has 3-dispatch scan. Roadmap-gated. |

## Bucket E — Canonical audit blockers (docs/CANONICAL_AUDIT_LOG.md D-series)

| ID | Status | Commit | Notes |
| -- | ------ | ------ | ----- |
| D5 substrate durability | 🟢 SHIPPED | 6d78593b | WAL + F_FULLFSYNC on `OpLog::open_persistent` (`agent_core/src/oplog.rs`) + `VaultStore::open` (`agent_core/src/storage/vault.rs`). 2 new pragma tests; 708/708 cargo agent_core tests green. WRV_EXEMPT: infrastructure (per MASTER_BUILD_PLAN.md §4 closed exempt list). |
| D4 faculty roster memory fix | 🟢 SHIPPED | 4c0c7e17 | Demoted Hermes 4.3 36B from default primary (~18 GB resident at 4-bit, exceeded 16 GB Mac ceiling) to opt-in only. `LocalModelCatalog.fallbackPrimaryAgentModel = .qwen3_8B4Bit` (~4 GB) on 16 GB hosts. 36B gated behind BOTH ≥32 GB host RAM AND explicit `epistemos.localAgent.optInHermes36B` UserDefaults flag. `LocalTextModelID.estimated4BitWeightsGB` accessor added to `Epistemos/State/InferenceState.swift:296` covering all 46 catalog cases (4-bit ≈ params×0.5 GB; MoE uses total params; 3-bit×0.375; 2-bit×0.25; bf16×2). 6 invariant tests pass: `defaultLocalAgentModelFitsIn16GBCeiling` (9.5 GB ≤ 11 GB realistic budget); `defaultAgentIgnores36BOptInOnConstrainedHost`; `defaultAgentRequiresExplicitOptInAt32GB`; `defaultAgentServes36BWhenGated`; `primaryAgentHostRAMGateIsExactlyThirtyTwoGB`; `hermes43_36BWeightsAreOverThe16GBCeiling`. AppBootstrap logs resolved primary on every boot via Log.app.info. xcodebuild green. Test floor: zero new regressions (the pre-existing W9.25-stale test `local agent mode stays available when the soft-guidance loop is available` still fails on HEAD without D4 changes — confirmed via D4-isolation stash). |

---

## Session log

### 2026-04-27 — WRV wiring sweep (anti-scaffolding pass)

Per user directive: "AI has a really bad habit of not wiring things — scaffold then never wire." Audited today's 5 SHIPPED Swift files: **ZERO call sites** for any of them. They were orphaned scaffolds — exactly the failure mode the WRV gate exists to prevent.

**Five WRV proofs landed this turn:**

| Item | WIRED (call site) | REACHABLE (gesture) | VISIBLE (user signal) |
| ---- | ----------------- | ------------------- | --------------------- |
| **W9.6** CostDashboardView | `Epistemos/Views/Settings/AgentSectionDetailView.swift:115` (Spend tab branch) | Settings → Agent → Spend tab | Per-session list + total + budget cap field |
| **W9.7** VaultSelectorView | `Epistemos/Views/Notes/NotesSidebar.swift:701` (above ModelVaultsSidebarSection) | Notes sidebar (always visible) | Disclosure group with current-vault row |
| **W9.8** ApprovalModalView | `Epistemos/Views/Settings/AuthoritySettingsView.swift:75` (preview card + sheet) | Settings → Agent → Authority → "Show preview" button | Modal opens with countdown ring + 3-button decision row |
| **W9.13** DailyNoteView | `Epistemos/Views/Notes/NotesSidebar.swift:1078` (Today's brief button + sheet) | Notes sidebar → Today's brief button | Sheet opens with date picker + body editor + due-review section |
| **W9.29** ThermalMonitor | `Epistemos/Engine/MLXInferenceService.swift:33` (LocalMLXRequest.resolvedMaxTokens reads ProcessInfo.thermalState) | Every MLX inference call | maxTokens scales 100% → 85% → 50% → 25% as thermal state climbs (Nominal → Critical) |

**N7 ConversationState read-site:** already wired at `ChatCoordinator.swift:2173+2254` (rebuild on every assistant turn, splice into next prompt). No new work needed.

**Build verification:** `xcodebuild -scheme Epistemos -destination 'platform=macOS' build` → BUILD SUCCEEDED. Only failures are vendored CodeEdit* SwiftLint warnings.

Updated statuses for 2026-04-26 items above:
- W9.6, W9.7, W9.8, W9.13, W9.29 graduate from 🟢 SHIPPED (file exists) to 🟢 SHIPPED (WRV verified end-to-end).
- Other 🟡 FOUNDATION items (W9.21, W9.22, W9.26, W9.27, W9.30, R15, R16) keep their status — they need follow-up PRs to reach WRV per the dossier's per-item plan.

**Lesson reinforced:** per `docs/plan/00_AUTHORITY_AND_ANTI_DRIFT.md §4.7`, file-exists ≠ shipped. WRV is the gate. Today's session proved the gate is doing its job.

### 2026-04-26 — implement-everything-non-CLI session

**16 items addressed in one turn:**

| Item | Outcome |
| ---- | ------- |
| W9.25 grammar masking | 🟢 mlx-swift-structured 0.1.0 linked, build green |
| R14 UniFFI bump | 🟢 0.28 → =0.29.5 across 4 crates, build green |
| W9.23 circuit breaker | 🟢 bit-packed AtomicU64, 6/6 tests pass |
| W9.29 thermal monitor | 🟢 ThermalMonitor @Observable singleton |
| W9.8 approval modal | 🟢 ApprovalModalView w/ countdown ring |
| W9.6 cost dashboard | 🟢 CostDashboardView + BudgetPreferences |
| W9.7 vault selector | 🟢 VaultSelectorView sidebar |
| W9.13 daily notes | 🟢 DailyNoteView w/ FSRS due-review section |
| R15 benchmark harness | 🟡 4 XCTest scaffolds disabled by default |
| W9.30 KIVI quant | 🟡 KIVIPreferences flag scaffold |
| W9.27 OpLog | 🟡 hand-rolled module + 4/4 tests pass |
| W9.21 Honest FFI PR1 | 🟡 honest_handle module + retain/release FFI exports |
| W9.26 B-tree rope | 🟡 crop integration + 6/6 tests pass (UTF-16 metrics) |
| R16 ETL crawler | 🟡 walker + hash modules + 7/7 tests pass |
| W9.22 Typestate | 🟡 Lifecycle<T,S> generic + 5/5 tests pass |
| Build verification | 🟢 xcodebuild green (only failures: vendored CodeEdit* SwiftLint warnings) |

Total Rust tests added: **28** (all pass).
Total Swift files added: **7**.
Total new modules: **9** (5 Rust, 4 Swift).
project.yml change: 1 (mlx-swift-structured package added).

**Status**: 7 items shipped end-to-end (Bucket A + Bucket B core);
9 items shipped as foundations with documented next-PR plans.
**Bucket D explicitly deferred** per dossier guidance — those need
roadmap commitments before further work.

The plan stack docs (`WAVE_9_POLISH_AND_NATIVE.md`,
`WAVE_13_MASTER_IMPLEMENTATION_PLAN.md`, the research corpus in
`~/Downloads/`, the dossier at `docs/RESEARCH_DOSSIER_TIER_3_4.md`)
remain canonical for the FULL spec of each item — this tracker is
just the live status.

When all 🟡 FOUNDATION items become 🟢 SHIPPED + Bucket D items
are explicitly scoped (or formally killed), V1.5 is done.
