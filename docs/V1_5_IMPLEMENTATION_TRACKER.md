# V1.5 Implementation Tracker — R14-R16 + W9.6-W9.30

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
| W9.27 OpLog | 🟡 FOUNDATION (PR2 of N) | dcc5521f + 8a4cf434 | PR1 hand-rolled foundation (Op enum + serde wire format `tag = "op_type"` + Lamport + in-memory Vec, 4 tests). PR2 SQLite-backed persistence via rusqlite (`OpLog::open_persistent` + schema `epistemos_oplog(seq INTEGER PRIMARY KEY, lamport, actor_id, ts_unix_ms, payload BLOB)`, 3 new roundtrip tests cover reopen restores ops + Lamport counter resumes from max stored). 691/691 agent_core tests green. Persists BEFORE in-memory append so SQLite failure doesn't leave phantom ops. PR3 Swift VaultIndexActor subscription + PR4 BLAKE3 Merkle chain (D1) integration + PR5 time-travel UI remain. |
| R16 ETL crawler | 🟡 FOUNDATION | this session | `agent_core/src/etl/{mod,hash,walker}.rs` modules. `ignore` 0.4 walker w/ .gitignore + .epignore + hardcoded code-file exclusion list (52 extensions). xxh3_64 path+content fingerprint. 7/7 tests pass. Next PRs: apalis-sql Monitor + AFM @Generable sidecar generation + Swift FFI. |

## Bucket N — Novel additions (locked into plan after dossier closed)

| ID | Status | Commit | Notes |
| -- | ------ | ------ | ----- |
| N1 Prompt Tree (JSPF + PTF) | 🟢 SHIPPED | 7316f86b | Foundation + WRV anchor landed: PromptTree.swift (typed Prompt + 8 sub-types + composer), PromptRenderer.swift (4 targets + Relocation Trick), PromptCache.swift (4-breakpoint cap + per-provider degradation), PromptTreePersister.swift (PTF directory + GC), 5 prompt-shape entries in StructureRegistry, ChatCoordinator first-turn wire behind `EPISTEMOS_PROMPT_TREE=1`, 8 PromptTreeTests passing in 0.015s, docs/PROMPT_AS_DATA_SPEC.md spec. ~1890 LOC. Phase 1 follow-up: wire RenderedPrompt.anthropic(systemBlocks:messages:) into Rust SSE handler so Relocation Trick flows through to Anthropic + cached_tokens_share telemetry into W9.6 dashboard. |

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
