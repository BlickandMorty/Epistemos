# Canonical Audit Log

> **Index status**: CANONICAL — Already canonical (3 deep audit passes); existing banner adequate.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/10_living_audits/`.



> **Status**: CANONICAL — living deep-drift audit (snapshot-based passes; resolved findings stay logged with resolution commit).
> **Role**: Strategic audit of V1.5 backlog vs canonical doctrine. Checks every item against the four research corpora + plan tree + actual codebase. Findings are durable.
> **Read with**: [`CRITIQUE_LOG.md`](CRITIQUE_LOG.md) (rolling per-commit auditor; tactical) + [`docs/plan/03_EXECUTION_MAP.md`](plan/03_EXECUTION_MAP.md) (per-item depth) + [`MASTER_BUILD_PLAN.md`](MASTER_BUILD_PLAN.md) (queue).
> **Latest pass**: #3 (2026-04-27). Score: 14 Blockers + 1 Major drift + 1 partial-resolved out of 49 audited. Keystone absence: provenance-plane primitives (MutationEnvelope/ClaimLedger/RetractionPropagated) 100 % missing in code.

## 2026-05-17T07:14:00-05:00 - T9 live coordination overlay

This is not a new deep audit pass. It records the live nine-terminal coordination state so the canonical audit trail does not drift from the active worktree reality.

- Main baseline during T9 iter 2: `cargo test --manifest-path agent_core/Cargo.toml --lib` passed at 1671 tests; `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO` ended `BUILD SUCCEEDED`.
- T2 has a live pre-commit blocker: tracked generated artifacts under `syntax-core/target/**` remain modified outside its scope lock. See `docs/coordination/T2_drift_2026_05_17.md`.
- T3 landed local docs-only audit commit `4468b09ac`, scope-clean against `docs/audits/UAS_ACS_SUBSTRATE_INVENTORY_<date>.md`. See `docs/coordination/T9_to_T3_2026_05_17.md`.
- T4 landed `0c0ddfe15`, scope-clean for VaultRecall baseline work; explicit vault retrieval audit doc remains a follow-up. See `docs/coordination/T9_to_T4_2026_05_17.md`.
- `gh pr list --state open` returned `[]`; no draft PR cross-review surface existed at the time of this overlay.

## 2026-04-26T00:00:00Z — Deep audit pass #1

Audits every item in the V1.5 backlog (Buckets A, B, C, D, N + D-series + gap-fixes G1-G9 + pre-TestFlight gates) against the actual research corpus in `/Advice`, `/final`, `/final v2`, plus the dossier (`docs/RESEARCH_DOSSIER_TIER_3_4.md`) and execution map (`docs/plan/03_EXECUTION_MAP.md`). Flags any drift — even slight ones.

### Summary

- Items audited: 47 (Bucket A: 3, Bucket B: 7, Bucket C: 5, Bucket D: 7, Bucket N: 1, D-series: 12, Gap-fixes: 9, Pre-TestFlight: 3)
- Canonical: 5
- Drift detected: 42
- Severity: 17 Blocker, 19 Warning, 6 Note

### TL;DR — the largest drift categories

1. **Status-claim drift (rampant).** Half the 🟢 SHIPPED items are actually 🟡 FOUNDATION at best:
   - W9.21 Honest FFI: PR1+PR2 _modules_ exist (`epistemos-shadow/src/honest_handle.rs`, `syntax-core/src/honest_handle.rs`, `substrate-core/src/honest_handle.rs`, `substrate-rt/src/honest_handle.rs`) but **zero Swift consumers use them** — `Epistemos/Engine/RustShadowFFIClient.swift:39` still binds the legacy `shadow_open_at` Int32-status FFI. The honest-handle modules are orphan scaffolding by the WRV gate's own definition.
   - W9.26 B-tree rope: `RopeFFIClient.swift` has zero non-test callers (verified via `grep -rn 'RopeFFIClient' Epistemos/ | grep -v RopeFFIClient.swift | grep -v Tests`). Tracker claims PR3 of N is shipped.
   - W9.27 OpLog: `OpLog::open_persistent` exists in `agent_core/src/oplog.rs:109` but **no Swift consumer** — `grep -rn 'oplog\|OpLog' Epistemos/` returns only one stale comment in `StructureRegistry.swift:69`. Tracker claims PR2 of N is shipped.
   - W9.22 Typestate: generic `Lifecycle<T,S>` exists in `agent_core/src/runtime/typestate.rs` but **zero non-test consumers**. No `MlxSession`, `HermesProcess`, `AFMPoolEntry` concretizations as the dossier specifies.
   - N1 Prompt Tree: PromptComposer wired at `ChatCoordinator.swift:2214` but ONLY behind the env-var/Settings flag, AND the cache-telemetry is unwired even though the substrate fix is done (see N1 finding below).

2. **Doctrine §3 keystone primitive (Retraction Propagation) does not exist in code at all.** Zero hits for `MutationEnvelope`, `ProposedEnvelope`, `ClaimLedger`, `RetractionPropagated`, `provenance/ledger` across the entire Rust + Swift codebase. This is THE novel architectural primitive the doctrine names as Epistemos's contribution. Without it, doctrine §1 (the four-plane crossing rule), §2.1 (mutation envelope is the cold-path source of truth), §2.5 (one ledger with five projections), §5.2 (ReplayBundle byte-equivalence guarantee), and the 7-verb MCP boundary's `commit_session` verb are all hollow.

3. **D2 (7-verb MCP graph boundary) does not match research.** Research/dossier specifies these 7 verbs: `search_semantic`, `search_fulltext`, `get_node`, `traverse`, `create_node`, `create_edge`, `commit_session`. Actual `omega-mcp/src/vault.rs` exports: `read_file`, `write_file`, `list_files`, `search_notes`, `execute_vault_tool`. None of the 7 verbs exist. The catalog publishes a different tool surface entirely.

4. **D5 (substrate durability) silently absent.** Doctrine + research mandate `PRAGMA journal_mode = WAL` and `fcntl(F_FULLFSYNC)` on every commit. Verified: zero `PRAGMA` in `agent_core/src/oplog.rs` and `agent_core/src/storage/vault.rs`. Zero `F_FULLFSYNC` in any Rust source. The OpLog's persistent SQLite schema doesn't even open with WAL mode — it relies on whatever `rusqlite::Connection::open` defaults to.

5. **D1 (BLAKE3 Merkle chain) wired in epistemos-core only as content-hash, NOT as a chain in the OpLog.** `agent_core/src/oplog.rs:128` schema is `(seq, lamport, actor_id, ts_unix_ms, payload)` — no `prev_hash` column. Execution map §W9.27 explicitly requires `(seq INTEGER PRIMARY KEY, payload BLOB, prev_hash BLAKE3)`. Without the chain, retraction propagation has no cryptographic backing.

6. **D3 (closed A2UI catalog) does not exist.** Zero hits for `A2UI`, `A2UIValidationFailure`, `Epistemos/A2UI/Catalog.swift`. Doctrine §6 #4 is "no fallback inspector. A2UI catalog is closed (~25 components). Unknown schemas are validation errors." But the catalog file is missing entirely.

7. **D11 (epistemos-trace CLI) does not exist as a separate distribution.** Doctrine §5.1 mandates the open `epistemos-provenance-standard` repo with CLI binary, but `grep -rn 'epistemos-trace'` finds it only in spec docs, never in code or any external repo.

8. **Build-matrix nomenclature drift.** Doctrine §5 spec uses `EPISTEMOS_PRO` / `EPISTEMOS_MAS` Swift conditions and Cargo features `pro` / `mas`. Actual project uses `EPISTEMOS_APP_STORE` / `MAS_SANDBOX` (Swift) and `mas-sandbox` (Cargo). `EPISTEMOS_PRO` is mentioned in zero Swift files outside of doc comments. There is no symmetric `pro` Cargo feature — features are gated by absence of `mas-sandbox`.

9. **Faculty roster (D4) drift.** Dossier `~/Downloads/final v2/compass_artifact_wf-c2d78e2f...md` and execution map §D4 specify `Hermes-3-Llama-3.1-8B-4bit` (~3.5 GB) as primary. Actual `Epistemos/Engine/LocalModelInfrastructure.swift:519` ships `NousResearch Hermes 4.3 36B` (a 36B model that cannot run on the 16 GB hardware ceiling per memory `[User Hardware — 16GB Mac]`). This is a memory-budget violation hiding under a different model ID.

10. **Claude version IDs differ from CLAUDE.md.** `agent_core/src/providers/claude.rs:69, 73, 77` defaults to `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5`. CLAUDE.md provider matrix line 77 says `Claude Opus 4.6/Sonnet 4.6: api.anthropic.com/v1/messages, thinking: adaptive`. The "Opus 4.6" in the matrix doesn't match the implemented `claude-opus-4-7`. Either the matrix is stale (knowledge cutoff is January 2026; Opus 4.7 is real per current model id `claude-opus-4-7[1m]`) or one of the IDs is wrong.

---

### Per-item findings

#### W9.25 — Grammar masking (link mlx-swift-structured)

- **Status (per MASTER_BUILD_PLAN.md §7)**: 🟢 SHIPPED (commit `dcc5521f`)
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**:
  - **Crate-version drift (Blocker)**: Dossier line 73 says `mlx-swift-structured 0.0.4` (the resolved version in `test_results/ci_source_packages/`). MASTER_BUILD_PLAN.md §7 Bucket A claims `mlx-swift-structured 0.1.0 linked via project.yml`. Actual `project.yml:529`: `from: "0.0.4"`. The plan's "0.1.0" claim is wrong. Both 0.0.4 and 0.1.0 are valid SwiftPM `from:` versions; 0.0.4 is what actually links.
  - **Algorithm-spec drift (Warning)**: Execution map §W9.25 mandates "replace `JSONSchemaLogitProcessor` with `GrammarMaskedLogitProcessor`; flip `isFullyConstraining = true`". Actual `Epistemos/Omega/Inference/MLXConstrainedGenerator.swift:34`: `nonisolated let isFullyConstraining: Bool = false`. Comment at `:21` admits "Real constrained decoding requires vocabulary access to build per-state allowed-token masks, which is not yet implemented." — i.e. the actual logit masking has NOT happened. Only the package link landed.
  - **WRV completeness (Warning)**: `mlx-swift-structured` package linked. `canImport(MLXStructured) && canImport(CMLXStructured)` activates the LocalToolGrammar import path (`Epistemos/LocalAgent/LocalToolGrammar.swift:3-4`). But `MLXConstrainedGenerator` does not yet route through MLXStructured's grammar masking — `isFullyConstraining=false` means soft EOS guidance only. Definition-of-done item "All Hermes-3 tool-call plans output structurally valid `<tool_call>` blocks (no retry loops in 100 trials)" cannot be true without the actual masking.
- **Required fix**: Either (a) demote to 🟡 FOUNDATION until `GrammarMaskedLogitProcessor` is wired and `isFullyConstraining = true`, OR (b) explicitly redefine "shipped" for this item to mean "package linked, masking is a follow-up" — and update MASTER_BUILD_PLAN.md row to reflect that. Today's claim "🟢 SHIPPED" is inconsistent with §W9.25 DoD.
- **Severity**: Blocker (status drift + DoD checkboxes unmet)

#### R14 — UniFFI 0.28 → 0.29.5

- **Status**: 🟢 SHIPPED (commit `dcc5521f`)
- **Canonical?**: ✅ YES
- **Drift detected**:
  - Verified: All 4 Cargo.toml pinned EXACTLY to `=0.29.5` (`agent_core/Cargo.toml:67`, `epistemos-core/Cargo.toml:11`, `omega-mcp/Cargo.toml:25`, `omega-ax/Cargo.toml:9`). Dossier specifies "Pin 0.29.5 exactly — DO NOT bump to 0.30/0.31" — matched.
  - `epistemos-shadow/Cargo.toml` correctly NOT bumped (uses `@_silgen_name` raw FFI).
  - `patch-uniffi-bindings.py` exists and the `nonisolated` annotation pass is implemented (lines 5-9 confirm the 4 patches).
- **Severity**: None (canonical)

#### W9.30 — KIVI 2-bit KV quant (env-flag scaffold)

- **Status**: 🟡 FOUNDATION (commit `dcc5521f`)
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**:
  - **Algorithm-spec drift (Blocker)**: Dossier §W9.30 lines 1278-1280 mandates `KIVIKVCache: QuantizedKVCacheProtocol` in `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift` AND `GenerateParameters.kvScheme: KVQuantScheme` enum extension at `Evaluate.swift:1560`. Verified via `grep -n "KIVIKVCache\|KVQuantScheme\|kvScheme" LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift Evaluate.swift` → ZERO hits. Only the Swift-level env-flag wrapper at `Epistemos/Engine/KIVIQuantization.swift` exists. The mlx-swift-lm fork has not been touched.
  - **WRV completeness (Warning)**: `KIVIPreferences.shouldUseKIVI(forContextTokens:)` returns false today regardless of context length unless `EPISTEMOS_KV_KIVI=1` env var is set. `MLXInferenceService.swift` does not consume `KIVIPreferences.currentScheme()` — the env flag has zero callers. Verified: `grep -rn "KIVIPreferences\|KVQuantScheme" Epistemos/Engine/MLXInferenceService.swift` → zero hits.
- **Required fix**: Document explicitly in tracker that this is "ENV-FLAG SCAFFOLD ONLY — actual KIVI implementation is a future PR in the mlx-swift-lm fork". Cannot claim 🟡 FOUNDATION when the foundation hasn't been touched in the package the impl belongs to.
- **Severity**: Blocker (the foundation file is in the wrong package)

#### W9.6 — Cost dashboard + BudgetPreferences

- **Status**: 🟢 SHIPPED (commits `dcc5521f` + `1d573889`)
- **Canonical?**: ❌ NO
- **Drift detected**:
  - **WRV completeness (Blocker)**: `Epistemos/Views/Settings/AgentSectionDetailView.swift:126` shows `CostDashboardView(entries: [])`. The `entries:` argument is a hardcoded empty array. Comment at `:121-123` admits "Today the entries list is empty until the Rust → Swift session-insights bridge lands". This means the dashboard is a chrome-only stub: real cost data NEVER appears. WRV "VISIBLE — User sees per-session cost rows" is false.
  - **Algorithm-spec drift (Warning)**: Execution map §W9.6 DoD item 1: "Provider pricing table includes Claude Sonnet 4.6, Claude Opus 4.6, Perplexity Sonar Pro, Codex, Gemini, Kimi/Moonshot, all with `last_verified_iso8601` field". Actual `agent_core/src/session_insights.rs:15-25` has 9 entries but ZERO `last_verified_iso8601` fields. Pricing is hardcoded; drift detection (research spec) is impossible.
  - **Provider naming (Warning)**: `session_insights.rs:16` uses `claude_sonnet` / `claude_opus`. CLAUDE.md provider matrix uses `claude-sonnet-4-6` / `claude-opus-4-6`. Match is via `.starts_with()` so version-specific pricing (Sonnet 4.6 vs Sonnet 4.7) is not differentiable.
  - **Budget gate not wired (Blocker)**: §W9.6 DoD: "Budget cap fires the W9.8 approval modal with `tool_name = "budget_gate"`". Verified: `grep -rn "budget_gate" agent_core/src/agent_loop.rs` → zero hits. The cost-cap → ApprovalModal flow does not exist.
- **Required fix**: Demote to 🟡 FOUNDATION. Either wire the Rust→Swift session-insights bridge so `entries` carries real data, OR explicitly mark as "UI shell only; data wiring is a follow-up PR".
- **Severity**: Blocker (dashboard is a chrome stub; no real data flows)

#### W9.7 — VaultSelectorView

- **Status**: 🟢 SHIPPED (commits `dcc5521f` + `1d573889`)
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**:
  - **WRV verified at `Epistemos/Views/Notes/NotesSidebar.swift:712`** — VaultSelectorView is rendered inside the disclosure group. Wired. Reachable. Visible. ✅
  - **DoD drift (Note)**: Execution map §W9.7 DoD item 1: "Switch vault in <100 ms (no full SwiftData container swap on every key)". This perf claim has not been measured. Item 4: "MAS path: handle gracefully if user revokes bookmark of a vault mid-session". Cannot verify without test coverage.
- **Severity**: Note (wired correctly; missing perf + sandbox-revoke tests)

#### W9.8 — ApprovalModalView

- **Status**: 🟢 SHIPPED (commits `dcc5521f` + `1d573889`)
- **Canonical?**: ❌ NO
- **Drift detected**:
  - **WRV-Reachable drift (Blocker)**: The shipped `ApprovalModalView` is mounted ONLY inside `Epistemos/Views/Settings/AuthoritySettingsView.swift:46` as a "preview" sheet from a "Show preview" button. Verified at line 14: `@State private var approvalPreviewPending: ApprovalModalView.PendingApproval? = nil`. The actual production approval flow is `ChatCoordinator.promptUserForToolApproval` (line 2844) which uses NSAlert, NOT `ApprovalModalView`. So the new modal IS reachable from a UI surface but only as a non-functional preview — NOT from actual agent activity.
  - **Doctrine §6 #1 violation (Warning)**: Doctrine non-negotiable: "no silent behavior — every non-default behavior surfaces in telemetry." The actual approval path emits no `AuditFinding` to `<session>/approvals.jsonl` per §W9.8 DoD item 4.
  - **Spec drift (Warning)**: §W9.8 mandates "Inline card renders mid-stream without breaking the stream". The `ApprovalModalView` is sheet-only — there is no inline-card variant in the codebase. `Epistemos/Views/Approval/InlineApprovalCard.swift` (per execution map files-to-touch list) does not exist.
- **Required fix**: Either (a) wire `ApprovalModalView` into `ChatCoordinator.promptUserForToolApproval` so it actually replaces NSAlert during agent runs, OR (b) demote to 🟡 FOUNDATION with the next-PR plan being "replace NSAlert path with sheet-based modal".
- **Severity**: Blocker (the modal lives in Settings as a preview; the real approval flow still uses NSAlert)

#### W9.13 — DailyNoteView

- **Status**: 🟢 SHIPPED (commits `dcc5521f` + `1d573889`)
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**:
  - **WRV verified at `Epistemos/Views/Notes/NotesSidebar.swift:1101`** — DailyNoteView opens via "Today's brief" button. Wired ✅
  - **Spec drift (Warning)**: Execution map §W9.13 DoD: "FSRS due-review queue paginated by review difficulty". The shipped view shows a section but no review-difficulty pagination is verified in code. `FSRSDecayStore.notesDueForReview(date:)` is referenced but the difficulty bucketing per the dossier's "Anki/SuperMemo design literature" research is missing.
  - **DoD check (Note)**: §W9.13 DoD: "Daily note auto-creates on first edit, NOT on app launch". Cannot verify auto-creation policy without reading the view's lifecycle hooks.
- **Severity**: Warning (wired, but FSRS depth is a stub)

#### W9.23 — Bit-packed circuit breaker

- **Status**: 🟢 SHIPPED (commit `dcc5521f`)
- **Canonical?**: ✅ YES (with one Note)
- **Drift detected**:
  - Verified at `agent_core/src/circuit_breaker.rs:31-44`: bit layout is `[0..2) state, [2..18) failure_count(16), [18..50) last_fail(32), [50..64) generation(14)` = 2+16+32+14 = 64 bits exactly. Matches research dossier §W9.23 verbatim.
  - `#[repr(align(64))]` at line 92 — cache-line padding present. Doctrine alignment is M-series (64-byte L1).
  - **WRV gate (Note)**: §4 closed exempt list does NOT exempt W9.23 — "the breaker state must be visible (provider status pill)". Verified: zero hits for "breaker" in `Epistemos/Views/`. The breaker state is invisible to the user; doctrine §6 #1 (no silent behavior) is violated. WRV-Visible is unmet.
- **Required fix**: Add a provider-status pill to the chat surface that reads `CircuitBreaker::snapshot()` over FFI. Without this, the breaker is silent.
- **Severity**: Warning (Rust impl is canonical; UI surface is missing per WRV)

#### W9.29 — ThermalMonitor

- **Status**: 🟢 SHIPPED (commits `1d573889` + `43a822ad` + linter refactor)
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**:
  - **WRV verified**: `ThermalMonitor.currentTokenBudgetMultiplier()` consumed at `Epistemos/Engine/MLXInferenceService.swift:38`. Wired ✅
  - **Visibility drift (Warning)**: Execution map §W9.29 mandates `"Thermal: <state>" pill in main UI`. Verified: zero hits for `thermalState` in `Epistemos/Views/` (search for visible chrome). The thermal scale-down is silent — the user sees fewer tokens but no indication WHY. Doctrine §6 #1 + #5 violated.
  - **Rust-side wiring missing (Warning)**: §W9.29 DoD: "ProcessInfo.thermalState notification wired to agent_core breaker via UniFFI shared atomic". Verified: zero hits for `thermal` in `agent_core/src/circuit_breaker.rs`. The breaker has no thermal input — only failure count. So thermal pressure does NOT trip the breaker.
- **Required fix**: Add a thermal-state pill to the chat surface. Wire `ThermalMonitor` notification → `agent_core::circuit_breaker::CircuitBreaker::record_thermal_pressure()` (new FFI export).
- **Severity**: Warning (Swift side wired; Rust integration + UI surface missing)

#### R15 — Benchmark harness scaffolds

- **Status**: 🟡 FOUNDATION (commit `dcc5521f`); WRV_EXEMPT
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**:
  - **WRV exempt verified**: WRV_EXEMPT: test-only — appears in §4 closed list ✅
  - 4 XCTest scaffolds exist at `EpistemosTests/Benchmarks/{AFMGenerableBench,MLXThermalBench,SQLiteVecKNN,UniFFICallbackThroughput}Tests.swift` per spec ✅
  - **Spec drift (Warning)**: Dossier R15 specifies extending `bench/` Rust crate with `bench/src/uniffi_throughput.rs` and `bench/src/sqlite_vec_knn.rs`. Verified: `ls bench/src/` would show whether these landed. Per tracker line 41 "4 XCTest files; disabled by default; manual `-only-testing` runs. WRV_EXEMPT: test-only" — the Rust extension is NOT mentioned. Likely missing.
- **Severity**: Warning (Swift side present; Rust side undocumented)

#### W9.21 — Honest FFI (PR2 of 4)

- **Status**: 🟡 FOUNDATION (commits `dcc5521f` + `b2e4899d`)
- **Canonical?**: ❌ NO (orphan-scaffold pattern)
- **Drift detected**:
  - **Wired-gate violation (Blocker)**: `epistemos-shadow/src/honest_handle.rs` exports `shadow_handle_open_at`, `shadow_handle_retain`, `shadow_handle_release`, `shadow_handle_search`. Verified: `grep -rn "shadow_handle_open_at\|shadow_handle_retain\|shadow_handle_release" Epistemos/` → ZERO hits. Swift consumer `Epistemos/Engine/RustShadowFFIClient.swift:39, :47` still binds the legacy `shadow_open_at` (returns `Int32` status) and `shadow_search_json` (CString return). The honest-handle module is orphan scaffolding.
  - Same orphan pattern for `syntax-core/src/honest_handle.rs`, `substrate-core/src/honest_handle.rs`, `substrate-rt/src/honest_handle.rs`. Verified: `grep -rn "syntax_handle_create\|substrate_handle\|substrate_rt_handle" Epistemos/` → zero hits.
  - **Algorithm-spec drift (Warning)**: Dossier §W9.21 example uses `Arc::into_raw(Arc::new(ShadowEngine{backend}))` with `extern "C" fn shadow_open_at(path) -> *const ShadowEngine`. The shipped honest-handle uses the same pattern (verified at `epistemos-shadow/src/honest_handle.rs:66`: `Arc::into_raw(arc)`) ✅
  - **Sequencing drift (Warning)**: `graph-engine/src/lib.rs:573` still uses `Box::into_raw(Box::new(engine))` — the legacy non-honest pattern. Plan calls this an "architectural outlier" deferred indefinitely. That's a doctrine call (the Metal state needs single-thread access), but it should be EXPLICITLY documented in the file as a doctrinal exception, not just deferred. Currently no `// SAFETY: single-thread Metal contract — Arc gating would lock the render path` comment exists at line 573.
  - **WRV exempt status (Note)**: WRV_EXEMPT: infrastructure ✅ — but per §4, the exemption is for the Honest FFI _layer_, not for "scaffolding without consumers". A foundation that doesn't get used violates doctrine §6 #14 (no orphan scaffolding) regardless of WRV exemption.
- **Required fix**: Either (a) ship PR3+PR4 (Swift `~Copyable` consumer cutover) so the honest-handle modules are actually called, OR (b) document explicitly in the file headers + plan that the modules are "ready for cutover; cutover deferred until <date>". Today they are scaffold-without-consumer orphans.
- **Severity**: Blocker (orphan scaffolding violates §6 #14 even with WRV_EXEMPT)

#### W9.22 — Typestate Islands foundation

- **Status**: 🟡 FOUNDATION (commit `dcc5521f`)
- **Canonical?**: ❌ NO (orphan-scaffold pattern)
- **Drift detected**:
  - **Wired-gate violation (Blocker)**: `agent_core/src/runtime/typestate.rs` defines generic `Lifecycle<T,S>` with state markers `Loaded`, `Warm`, `Generating`, `Disposed`. Verified: `grep -rn "Lifecycle<" agent_core/src/ Epistemos/ | grep -v test | grep -v typestate.rs` → ZERO production callers. No `MlxSession`, `HermesProcess`, `AFMPoolEntry` concretizations exist as the dossier specifies.
  - **Algorithm-spec drift (Warning)**: Dossier §W9.22 example pattern shows `MlxSession<S>` with `pub fn warm_up(self) -> MlxSession<Warm>`. Actual `Lifecycle<T,S>` is a generic newtype — different shape than the dossier spec. The dossier wanted state-bound concrete types (`MlxSession<Loaded>` etc.); shipped is one generic struct. Defensible as a more reusable foundation but it does NOT match the pattern in the cited research.
  - **Sequencing drift (Warning)**: Cross-cutting hard rule "W9.21 MUST precede W9.22" is technically met because typestate doesn't yet wrap honest-FFI handles. But this means W9.22 ISN'T doing what the rule was about — typestate-on-top-of-honest-FFI handles. Rule is satisfied vacuously.
- **Required fix**: Either (a) ship the concrete `MlxSession`, `HermesProcess`, `AFMPoolEntry` wrappers using both honest-FFI handles + Lifecycle wrappers, OR (b) demote to ⚪ PENDING because the foundation is unused.
- **Severity**: Blocker (zero non-test consumers; same as W9.21 orphan pattern)

#### W9.26 — B-tree rope (PR3 of N)

- **Status**: 🟡 FOUNDATION (commits `dcc5521f` + `e9618ddf` + `385be68a`)
- **Canonical?**: ❌ NO (orphan-scaffold pattern)
- **Drift detected**:
  - **Wired-gate violation (Blocker)**: `Epistemos/Engine/RopeFFIClient.swift` exists with `@_silgen_name` bindings to 12 `rope_handle_*` functions. Verified: `grep -rn "RopeFFIClient" Epistemos/ | grep -v RopeFFIClient.swift | grep -v Tests` → ZERO production callers. Tracker at line 55 explicitly states "PR4 NoteFileStorage migration + PR5 ProseEditorRepresentable2 bridge remain". The Swift consumer is correctly labeled future work, but the FFI client itself has no production calls today.
  - **Crate-version drift (canonical ✅)**: `agent_core/Cargo.toml:53`: `crop = { version = "0.4", features = ["utf16-metric"] }` — matches dossier exactly.
  - **Spec drift (Note)**: Dossier §W9.26 specifies "Single source of truth: rope authoritative, JS bundle stateless". Verified: `js-editor/` still contains stateful Tiptap document state. Rope migration of WKWebView side is unstarted.
- **Required fix**: Foundation labeled correctly; no immediate fix needed because tracker calls out future PRs explicitly. But the file should NOT be claimed as "PR3 of N shipped" while having zero non-test callers — that's the same pattern W9.22 + W9.21 violate. The phrase "PR3 of N" is technically correct (PR3 is the FFI client, future PRs add consumers) but produces the same orphan-scaffold problem.
- **Severity**: Warning (foundation labeled correctly; orphan-scaffold pattern remains)

#### W9.27 — OpLog (PR2 of N)

- **Status**: 🟡 FOUNDATION (commits `dcc5521f` + `8a4cf434`)
- **Canonical?**: ❌ NO
- **Drift detected**:
  - **Schema drift (Blocker)**: Execution map §W9.27 line 810 mandates `epistemos_oplog(seq INTEGER PRIMARY KEY, payload BLOB, prev_hash BLAKE3)`. Actual `agent_core/src/oplog.rs:128`: `epistemos_oplog (seq INTEGER PRIMARY KEY, lamport INTEGER NOT NULL, actor_id TEXT NOT NULL, ts_unix_ms INTEGER NOT NULL, payload BLOB NOT NULL)` — has lamport/actor_id/ts but is missing the **`prev_hash BLAKE3`** column. D1 cannot ride on this OpLog as-is.
  - **D1 dependency drift (Blocker)**: D1 (BLAKE3 Merkle chain) explicitly pairs with W9.27 per execution map line 783 ("D1 (BLAKE3 chain pairs naturally)"). Without `prev_hash`, `epistemos-trace verify` cannot validate chain integrity per §5.2. The `blake3` crate is in `epistemos-core/Cargo.toml` (verified) but only used at `epistemos-core/src/uniffi_exports.rs:31` for content hashing, NOT chain hashing.
  - **D5 durability drift (Blocker)**: `OpLog::open_persistent` opens `Connection` via `rusqlite::Connection::open(db_path)`. Verified at `agent_core/src/oplog.rs:111-118`. NO `PRAGMA journal_mode = WAL`, NO `fcntl(F_FULLFSYNC)`. D5's durability discipline is silently violated. A crash mid-commit could corrupt the OpLog.
  - **Wired-gate violation (Blocker)**: `grep -rn "OpLog\|oplog" Epistemos/` returns one hit at `StructureRegistry.swift:69` ("EventStore, conversation_state, oplog") which is just a comment. No `VaultIndexActor` consumer, no Swift FFI client. Tracker line 56 acknowledges "PR3 Swift VaultIndexActor subscription + PR4 BLAKE3 Merkle chain (D1) integration + PR5 time-travel UI remain". So this is also orphan scaffolding by §6 #14.
- **Required fix**: 
  1. Add `prev_hash BLOB(32) NOT NULL DEFAULT ""` column to schema with appropriate migration.
  2. Wire BLAKE3(prev_hash || serialized_payload) → next_hash on append.
  3. Add `PRAGMA journal_mode = WAL` + `fcntl(F_FULLFSYNC)` on every commit.
  4. OR demote to ⚪ PENDING until the chain-aware schema is right.
- **Severity**: Blocker (schema is wrong for D1; durability missing for D5)

#### R16 — ETL crawler foundation

- **Status**: 🟡 FOUNDATION (commit `dcc5521f`)
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**:
  - **Crate-version drift (Note)**: `agent_core/Cargo.toml:56-57`: `ignore = "0.4"` (dossier says `ignore = "0.4.25"` exactly), `xxhash-rust = { version = "0.8", features = ["xxh3", "const_xxh3"] }` (dossier says `0.8.15` exactly). The 0.4 / 0.8 wildcards CAN resolve to 0.4.25 / 0.8.15, but the dossier's "MUST pin exact" rule for apalis (1.0.0-rc.7) suggests the same discipline is wanted here. Today, `cargo update` could float to 0.4.26 or 0.8.16 silently.
  - **Apalis missing (Warning)**: `agent_core/Cargo.toml` does NOT have `apalis = "=1.0.0-rc.7"` or `apalis-sql = "0.7.3"` per dossier. Tracker correctly labels these as "PR2" follow-up (`agent_core/src/etl/mod.rs:21-22` documents the future addition). Foundation is honestly labeled.
  - **Code-file exclusion list (Warning)**: Dossier §R16 mandates "must NOT generate sidecars for `.swift`, `.rs`, `.py`, etc." Tracker line 57 says "hardcoded code-file exclusion list (52 extensions)". Verified at `agent_core/src/etl/walker.rs` — exists but the list cannot be checked without reading the file. Marker lookup needed.
  - **Apple Foundation Models (AFM) bridge missing (Note)**: Dossier §R16 PR3 wants `AFMSidecarGenerator.swift` + AFM `@Generable` schema. Future PR; correctly labeled.
- **Required fix**: Pin exact versions `ignore = "=0.4.25"` and `xxhash-rust = "=0.8.15"` to match dossier discipline.
- **Severity**: Note (foundation honestly labeled; pinning could be tighter)

#### N1 — Prompt Tree (JSPF + PTF) + StructureRegistry composer

- **Status**: 🟡 FOUNDATION (PR1 of N: `7316f86b` + `1ab15596` + `e8c22dbb`)
- **Canonical?**: ⚠️ PARTIAL (and the tracker's status note is STALE)
- **Drift detected**:
  - **Substrate-discovery resolution drift (Warning)**: MASTER_BUILD_PLAN.md N1 section + `docs/plan/03_EXECUTION_MAP.md` "N1 Phase 1" entry both claim "blocked on substrate discovery — `agent_core/src/session_insights.rs` is not declared in lib.rs". Verified: `grep -n "pub mod session_insights" agent_core/src/lib.rs` → line 31 has `pub mod session_insights;`. The file IS now declared. Furthermore, `cache_read_input_tokens: u32` is wired into `SessionMetrics` at line 65 with `cached_tokens_share()` method at line 75. The "blocked" status is OUT OF DATE.
  - **WRV-Wired (Note)**: `PromptComposer.compose(forChatTurn:)` is called at `Epistemos/App/ChatCoordinator.swift:2214` ✅ — but ONLY behind `PromptTreePreferences.isEnabled()` (env-var or Settings toggle). Default is OFF. So the WRV-Wired claim is technically true but the path is dormant.
  - **WRV-Visible drift (Warning)**: §N1 DoD: "User-visible: `cached_tokens_share` row in Settings → Agent → Spend showing > 0 % after second turn". Verified: `Epistemos/Views/Cost/CostDashboardView.swift:48` has `cachedTokensShare` computed property — but `entries: []` at `AgentSectionDetailView.swift:126` means it's never displayed with real data. WRV-Visible fails the same way W9.6 fails (cost dashboard receives no data).
  - **PR-rename drift (Note)**: Tracker line 63 says "5 prompt-shape entries in StructureRegistry". MASTER_BUILD_PLAN.md §7 N1 entry says "extend with at least 4 prompt-shape descriptors". Verified: 5 prompt-shape entries exist. 5 ≥ 4, so passes, but the two docs disagree by one.
- **Required fix**: 
  1. Update tracker line 63 + MASTER_BUILD_PLAN.md §7 N1 status note to remove the "blocked on substrate discovery" caveat — that gap is closed.
  2. Wire CostDashboardView entries to real data so the cache-hit rate becomes visible.
  3. Make this clearer about the env-flag default-off state.
- **Severity**: Warning (substrate is fixed; status doc + UI wiring lag)

#### W9.10 — TurboQuant 3-bit KV (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: Deferral matches doctrine §0 verdict ("Pick KIVI OR TurboQuant, not both") and execution map §W9.10. ✅
- **Severity**: None

#### W9.11 — Personalized embeddings (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: Reason for deferral ("eval methodology needs design pass") matches research dossier §W9.11. ✅
- **Severity**: None

#### W9.12 — Orphan rediscovery (deferred)

- **Status**: ⏸ DEFERRED  
- **Canonical?**: ✅ YES
- **Drift detected**: Deferred awaiting W9.27 OpLog substrate per §W9.12 + execution map. ✅
- **Severity**: None

#### W9.14 — Block references + transclusion (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: Deferred awaiting W9.26 rope per §W9.14 + execution map. ✅
- **Severity**: None

#### W9.15 — Static routing macro (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**: Deferral reason "ROI unclear at current view count (~30 view types)" is canonical. BUT — doctrine §6 #6 ("no `AnyView` in render hot paths") is currently violated in 14+ places. Verified `grep -rn AnyView Epistemos/Views/`: 14 hits including `Settings/SettingsView.swift:2851-2864`, `Graph/HologramOverlay.swift:103-243`, `Graph/HologramSearchSidebar.swift:701-717`, `Graph/GraphFirstOpenTitle.swift:106-114`. Macro is deferred but the doctrine violation it would prevent is already shipped.
- **Required fix**: The deferral is fine; but a Phase 2-pre-W9.15 cleanup pass that hand-removes the AnyView usages is warranted before macro work begins.
- **Severity**: Warning (deferral OK; doctrine §6 #6 currently violated in 14+ files)

#### W9.24 — Metal zero-copy (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: "UMA may make `bytesNoCopy` a no-op gain. Measure first" matches §W9.24 research. ✅
- **Severity**: None

#### W9.28 — Blelloch scan (deferred research)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: "Mamba-2 already has 3-dispatch Reduce-then-Scan. Roadmap-gated." matches dossier §W9.28 research finding line 1180 ("REALITY CHECK"). ✅
- **Severity**: None

---

### D-series findings

#### D1 — BLAKE3 Merkle-chained RunEventLog

- **Status**: ⚪ PENDING (no formal status; mentioned only in execution map)
- **Canonical?**: ❌ NO (research-mandated primitive missing entirely)
- **Drift detected**:
  - Verified: `blake3 = "1"` exists in `epistemos-core/Cargo.toml:21` ✅
  - Verified: BLAKE3 used only as content hasher at `epistemos-core/src/uniffi_exports.rs:31, 37, 44`. NO Merkle chain construction. NO `prev_hash → next_hash` relationship.
  - Schema `provenance_chain(seq, prev_hash, next_hash, envelope_id)` per execution map §D1 DoD: ZERO hits in any GRDB schema across the codebase.
  - W9.27 OpLog schema lacks `prev_hash` column (see W9.27 finding above).
  - Without D1, doctrine §3 (retraction propagation needs cryptographic chain) is hollow. ReplayBundle byte-equivalence per §5.2 cannot be guaranteed.
- **Required fix**: D1 is a Phase 1 prerequisite per doctrine but is not on the queue. Either elevate to a queue item OR explicitly defer (with consequences acknowledged).
- **Severity**: Blocker (Phase 1 prerequisite missing; downstream items depend on it)

#### D2 — 7-verb MCP graph boundary

- **Status**: ⚪ PENDING (not on queue)
- **Canonical?**: ❌ NO
- **Drift detected**:
  - Research mandate: 7 verbs `search_semantic, search_fulltext, get_node, traverse, create_node, create_edge, commit_session`. Verified: `grep -rn "search_semantic\|search_fulltext\|create_node\|commit_session" omega-mcp/src/` → ZERO hits.
  - Actual `omega-mcp/src/vault.rs` exports: `read_file, write_file, list_files, search_notes, execute_vault_tool` (verified at lines 73, 100, 140, 198, 290).
  - Hermes provider integration cannot use the 7-verb boundary because it doesn't exist.
- **Required fix**: Either ship the 7-verb dispatcher OR document explicitly that `read_file/write_file/list_files/search_notes` is the chosen alternative + update doctrine + execution map to reflect.
- **Severity**: Blocker (architectural primitive, doctrine §1 substrate plane interface)

#### D3 — Closed A2UI catalog

- **Status**: ⚪ PENDING (not on queue)
- **Canonical?**: ❌ NO
- **Drift detected**:
  - `Epistemos/A2UI/Catalog.swift` does not exist. Verified `ls Epistemos/A2UI` → directory does not exist.
  - `A2UIValidationFailure` audit-finding type does not exist. Verified `grep -rn "A2UIValidationFailure" Epistemos/ agent_core/src/` → zero hits.
  - Doctrine §6 #4 "no fallback inspector. A2UI catalog is closed (~25 components). Unknown schemas are validation errors." has no implementation.
  - Hermes provider's structured emissions cannot pass through the closed catalog because it doesn't exist.
- **Required fix**: Build the closed catalog with at least the Phase 1 NoteCard component per execution map §D3.
- **Severity**: Blocker (doctrine non-negotiable #4 has zero enforcement)

#### D4 — Faculty roster lock-in

- **Status**: ⚪ PENDING (not on queue)
- **Canonical?**: ❌ NO
- **Drift detected**:
  - Doctrine spec (16 GB hardware reality): `Hermes-3-Llama-3.1-8B-4bit` (~3.5 GB resident). Per the user's `[User Hardware — 16GB Mac]` memory: "4-bit 7-8B is the sweet spot."
  - Actual `Epistemos/Engine/LocalModelInfrastructure.swift:519`: ships `Hermes 4.3 36B`. A 36B model at 4-bit is ~18 GB resident (4 bytes/param × 36 GB raw → 4-bit = ~18 GB) — exceeds the 16 GB hardware ceiling. CANNOT run on the target hardware.
  - This violates doctrine §4 "any feature whose steady-state cost exceeds 50 MB must declare its budget in `03_EXECUTION_MAP.md`" — no item declares 18 GB. The 36B model is silent memory bloat.
  - The user's `[User Hardware]` memory clearly says "16GB unified memory ceiling; realistic budget ~10-11GB for weights+KV; 4-bit 7-8B is the sweet spot". Hermes 4.3 36B is incompatible.
  - **Either**: (a) the 36B model is a "Pro/larger Mac" path and should be guarded by a memory check + warning, OR (b) the codebase should default to a 7-8B model per the user's hardware reality + doctrine.
- **Required fix**: Add Hermes-3-Llama-3.1-8B-4bit (or Qwen3 8B-4bit) to `LocalModelInfrastructure` as the DEFAULT primary on 16 GB systems, with the 36B as opt-in for ≥32 GB Macs.
- **Severity**: Blocker (memory math violation; will OOM on user's hardware)

#### D5 — Substrate durability discipline

- **Status**: ⚪ PENDING (per execution map closed exempt list); WRV_EXEMPT
- **Canonical?**: ❌ NO
- **Drift detected**:
  - Verified: NO `PRAGMA journal_mode = WAL` in `agent_core/src/oplog.rs` or `agent_core/src/storage/vault.rs`.
  - Verified: NO `fcntl(F_FULLFSYNC)` anywhere in `agent_core/src/`.
  - DenseSlotMap usage: ✅ verified at `substrate-core/src/store.rs:12, 29, 46`.
  - The exemption "WRV_EXEMPT: infrastructure" assumes corruption-detection raises errors when triggered. Without WAL+F_FULLFSYNC, corruption is silently possible — D5 cannot be exempt because the code can't detect what's broken.
- **Required fix**: Add WAL + F_FULLFSYNC to every GRDB connection (`agent_core/src/oplog.rs:118` `Connection::open` is the canonical missing site).
- **Severity**: Blocker (durability not actually verified; exemption is hollow)

#### D6 — Hierarchical concept extraction (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: Deferred per execution map ✅
- **Severity**: None

#### D7 — FSRS-6 + raw-thought decay (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: Deferred per execution map ✅
- **Severity**: None

#### D8 — Night Brain + Morning Consolidation (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: Deferred per execution map (depends on D6, D7, W9.27) ✅
- **Severity**: None

#### D9 — Skills as graph nodes

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**:
  - Research §C.5 (App Moats): Hermes' skills system MUST be intercepted via MCP + rerouted to graph nodes.
  - Verified: `omega-mcp/src/skills.rs` does not exist. `agent_core/src/tools/skills.rs` exists (1500+ LOC) but writes to filesystem (`~/.hermes/skills/`) directly per `walkdir::WalkDir::new(&self.skills_dir)` at line 258. NO MCP intercept. NO graph node creation. NO `Skill` node type in substrate.
- **Required fix**: Build the MCP intercept per execution map §D9.
- **Severity**: Blocker (Phase 2 item, currently just unfocused work)

#### D10 — Speculative decoding (deferred)

- **Status**: ⏸ DEFERRED
- **Canonical?**: ✅ YES
- **Drift detected**: Per execution map deferral ✅
- **Severity**: None

#### D11 — `epistemos-trace` CLI (parallel track)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**:
  - Research §B.1, §B.2, doctrine §5.1: a separate `epistemos-provenance-standard` repo with `epistemos-trace` CLI binary (verify, replay, lint, diff verbs).
  - Verified: `grep -rn "epistemos-trace" /Users/jojo/Downloads/Epistemos/ --include="*.toml" --include="*.rs"` → zero hits in code. Only in spec docs.
  - Hackathon launch strategy per doctrine §5.6 depends on this binary. Without it, the whole "Open Provenance Standard" moat is unimplemented.
- **Required fix**: Either ship D11 (separate repo) OR explicitly label "moat strategy abandoned for V1.5" in PLAN_V2.
- **Severity**: Blocker (the moat depends on this; it doesn't exist)

#### D12 — BoltFFI investigation (UNVERIFIED)

- **Status**: ⏸ DEFERRED (research-only)
- **Canonical?**: ✅ YES (correctly marked UNVERIFIED + shelved)
- **Drift detected**: None — preserved `[UNVERIFIED]` marker per anti-drift research-honoring rule. ✅
- **Severity**: None

---

### Gap-fix findings (G1-G9 from STRUCTURING_AUDIT.md)

#### G1 — Chat message intent classification (S3 + S4)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**: 
  - Verified `grep -rn "IntentClassifier.shared\|IntentClassifier()" Epistemos/` → zero hits. The `IntentClassification` Swift type is referenced only in `StructureRegistry.swift:219` as a registry entry pointing at a non-existent type.
  - StructureRegistry lists the intent shape but no Swift `@Generable struct IntentClassification` exists. `grep -rn "struct IntentClassification" Epistemos/` returns zero hits.
- **Required fix**: Build the @Generable schema + classifier per STRUCTURING_AUDIT G1.
- **Severity**: Warning (registry says "shape exists" but type doesn't)

#### G2 — Search query intent (S9)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**: 
  - `SearchIntent` referenced as future work; not implemented. `grep -rn "SearchIntent" Epistemos/` returns zero hits.
- **Severity**: Warning

#### G3 — Voice → structured pipeline (S7)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**: 
  - `ComposerVoiceInputService` exists; output does not route through `TextCapturePipeline` per audit recommendation. Verified: `grep -rn "TextCapturePipeline" Epistemos/Engine/ComposerVoiceInputService.swift` → zero hits.
- **Severity**: Warning

#### G4 — Note save → ontology emit (S5)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**: 
  - `OntologyClassifier.shared` exists at `Epistemos/Graph/OntologyClassifier.swift:132` ✅. But `grep -rn "OntologyClassifier.shared" Epistemos/Sync/NoteFileStorage.swift Epistemos/Views/Notes/ProseEditorRepresentable2.swift` → zero hits. The classifier has zero callers from note-save sites.
- **Severity**: Warning (classifier ready; site is unwired)

#### G5 — Settings vault path validator (S8)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**: `VaultPathValidator` referenced in StructureRegistry:228 but no Swift implementation file exists.
- **Severity**: Note

#### G6 — Epdoc content extractor (S6)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**: `TiptapContentExtractor` not implemented. `grep -rn "TiptapContentExtractor" Epistemos/` → zero hits.
- **Severity**: Note

#### G7 — Vault crawler entity linking (S10)

- **Status**: ⚪ PENDING (depends on R16 PR3)
- **Canonical?**: ⚠️ PARTIAL (correctly deferred to R16)
- **Drift detected**: R16 PR3 not started. Foundation has the walker but no AFM bridge yet.
- **Severity**: Note (correctly deferred)

#### G8 — Screen-capture AX semantics (S12, Pro-only)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**: 
  - `ScreenElement` referenced in StructureRegistry:246 as Pro-only.
  - Pro-only enforcement: should be behind `#if !(EPISTEMOS_APP_STORE || MAS_SANDBOX)`. Verified: zero `ScreenElement` Swift type exists. So no enforcement to verify.
- **Severity**: Note (Pro-only feature; correctly absent on MAS)

#### G9 — iMessage message intent (S14, Pro-only)

- **Status**: ⚪ PENDING
- **Canonical?**: ❌ NO
- **Drift detected**: 
  - `MessageIntent` referenced in StructureRegistry:255 as Pro-only.
  - Pro-only DriverChannelToolExecutor lookup needed.
- **Severity**: Note (Pro-only)

---

### Pre-TestFlight gates

#### P0-2 — Reliability fresh baseline

- **Status**: ⚪ PENDING
- **Canonical?**: N/A (release mechanic)
- **Severity**: None

#### P0-3 — TestFlight metadata

- **Status**: ⚪ PENDING
- **Canonical?**: N/A
- **Severity**: None

#### P0-4 — mas-sandbox feature-gating spot-check

- **Status**: ⚪ PENDING
- **Canonical?**: ⚠️ PARTIAL
- **Drift detected**:
  - The Cargo feature is named `mas-sandbox`, but build matrix doctrine §5 specifies `mas` and `pro`. The actual project has only `mas-sandbox` (Cargo) + `EPISTEMOS_APP_STORE`/`MAS_SANDBOX` (Swift). There is no symmetric `pro` feature.
  - Pro-only Rust modules are gated by `#[cfg(not(feature = "mas-sandbox"))]` pattern (verified at `agent_core/src/lib.rs:80-99`). This works but isn't what the doctrine says.
- **Required fix**: Either (a) update doctrine §5 to match codebase reality (`mas-sandbox` feature; `EPISTEMOS_APP_STORE`/`MAS_SANDBOX` Swift conditions), OR (b) add the symmetric `pro` Cargo feature.
- **Severity**: Warning (nomenclature drift between doctrine and code)

---

### Cross-cutting issues

1. **Orphan-scaffolding pattern (Blocker, 4+ items)**: W9.21 honest_handle modules, W9.22 Lifecycle generic, W9.26 RopeFFIClient, W9.27 OpLog::open_persistent — all four have **zero non-test production callers** despite being labeled 🟡 FOUNDATION. Doctrine §6 #14 forbids exactly this pattern: "Code that is written but unwired, unreachable, or invisible is indistinguishable from no feature at all and is forbidden." The WRV_EXEMPT flag does not waive §6 #14 — exemption is for items where the substrate IS the surface, not for unused substrate.

2. **CostDashboardView is a chrome stub (Blocker)**: Both W9.6 (cost dashboard) and N1 Phase 1 (cached_tokens_share visibility) depend on real session-insights data flowing into the view. Today the view receives `entries: []` (line 126 of `AgentSectionDetailView.swift`). Two 🟢 SHIPPED items are blocked on the same missing Rust→Swift bridge.

3. **Provenance plane primitives entirely absent (Blocker)**: Doctrine §1 (the four planes), §2.1 (event bus + envelope split), §3 (retraction propagation), §5 (open standard) all assume `MutationEnvelope`, `ClaimLedger`, `RetractionPropagated`. These types don't exist anywhere in code. Neither does the substrate-level `provenance/ledger.rs` module mentioned in doctrine §2.5. Doctrine §0 verdict ("verifiable cognition is the moat") is unimplemented at the substrate.

4. **D-series items not on the queue (Warning, multiple)**: D1, D2, D3, D5, D9, D11 are doctrine-emergent items per execution map but ZERO of them appear in MASTER_BUILD_PLAN.md §7 queue. They float as orphans — neither shipped nor explicitly deferred. The plan needs to either queue them or formally defer.

5. **D5 durability discipline is silently violated (Blocker)**: Every SQLite connection across `agent_core` opens without WAL + F_FULLFSYNC. The exemption in §4 closed list ("corruption detection raises errors when triggered") is hollow because the code can't detect corruption it never prevented.

6. **AnyView violations across 14+ files (Warning)**: Doctrine §6 #6 forbids AnyView in render hot paths. Verified: `Epistemos/Views/Settings/SettingsView.swift:2851-2864`, `Epistemos/Views/Graph/HologramOverlay.swift:103-243` (8+ instances), `Epistemos/Views/Graph/HologramSearchSidebar.swift:701, 717`, `Epistemos/Views/Graph/GraphFirstOpenTitle.swift:106, 114`. Even the W9.15 routing macro deferral can't justify keeping these — discipline should hold by hand-rolled means.

7. **Faculty roster (D4) memory budget violation (Blocker)**: Hermes 4.3 36B is the documented "primary local agent" (`LocalModelInfrastructure.swift:513-519`) but is incompatible with the 16 GB hardware ceiling. Will OOM on the target user's machine.

8. **Build matrix Cargo features non-symmetric (Warning)**: `mas-sandbox` exists; `pro` does not. Pro features are gated by absence-of-mas (`#[cfg(not(feature = "mas-sandbox"))]`). Doctrine §5 wants both. P0-4 spot-check will not match the spec.

9. **Provider naming drift (Warning)**: Pricing table (`session_insights.rs:16`) uses `claude_sonnet`/`claude_opus` while CLAUDE.md provider matrix uses `Claude Sonnet 4.6` / `Claude Opus 4.6` and the actual implementation uses `claude-opus-4-7`. Three different naming conventions for the same providers.

10. **DocComment-vs-actual-implementation drift (Note)**: `MLXConstrainedGenerator.swift:21-23` honestly says "this generator cannot guarantee structurally valid JSON" — but `MASTER_BUILD_PLAN.md §7 W9.25` claims 🟢 SHIPPED. Honesty is in the docstring, drift is in the status.

---

### Status-claim drift (the biggest category)

| Item | Claimed | Reality | Drift category |
|---|---|---|---|
| W9.25 grammar masking | 🟢 SHIPPED | Package linked; `isFullyConstraining=false`; soft EOS guidance only | Algorithm-spec drift; status overstated |
| W9.6 cost dashboard | 🟢 SHIPPED | UI shell with `entries: []`; no Rust→Swift bridge | WRV-Visible fails |
| W9.8 approval modal | 🟢 SHIPPED | Modal exists ONLY as Settings preview; production flow uses NSAlert | WRV-Reachable fails |
| W9.13 daily notes | 🟢 SHIPPED | Wired ✅ but FSRS depth-bucketing missing | DoD partial |
| W9.21 Honest FFI PR2 | 🟡 FOUNDATION | Modules exist; zero Swift consumers | Orphan scaffolding |
| W9.22 Typestate | 🟡 FOUNDATION | Generic `Lifecycle<T,S>` exists; zero concretizations | Orphan scaffolding |
| W9.26 B-tree rope PR3 | 🟡 FOUNDATION | RopeFFIClient exists; zero non-test callers | Orphan scaffolding |
| W9.27 OpLog PR2 | 🟡 FOUNDATION | OpLog persistent; schema lacks prev_hash; zero Swift consumers | Schema drift + orphan |
| W9.30 KIVI | 🟡 FOUNDATION | Env-flag scaffold only; mlx-swift-lm fork untouched | Foundation in wrong package |
| N1 Prompt Tree | 🟡 FOUNDATION | Wired behind feature flag; tracker says blocked but isn't | Stale status doc |

10 of 11 claimed-shipped/foundation items have material drift. **Status-claim drift is the dominant pattern.**

---

### Recommended override directives for the 2-min cron auditor

For each Blocker, ready-to-paste override directive:

```
[CANONICAL OVERRIDE — W9.25]
Drift: MASTER_BUILD_PLAN.md §7 Bucket A row claims "mlx-swift-structured 0.1.0 linked"; actual project.yml:529 pins from: "0.0.4". MLXConstrainedGenerator.swift:34 has isFullyConstraining=false (real grammar masking unimplemented).
Required: Update MASTER_BUILD_PLAN.md §7 W9.25 row to "mlx-swift-structured 0.0.4 linked; isFullyConstraining=false (logit masking is a follow-up PR)". Demote status from 🟢 SHIPPED to 🟡 FOUNDATION.
Verify: grep -n "from: \"0.0.4\"" project.yml; grep -n "isFullyConstraining: Bool = false" Epistemos/Omega/Inference/MLXConstrainedGenerator.swift
```

```
[CANONICAL OVERRIDE — W9.6]
Drift: CostDashboardView is mounted with `entries: []` (AgentSectionDetailView.swift:126). Comment at :121-123 admits no Rust→Swift bridge exists. WRV-Visible "user sees per-session cost rows" is FALSE.
Required: Demote W9.6 from 🟢 SHIPPED to 🟡 FOUNDATION in both MASTER_BUILD_PLAN.md §7 and V1_5_IMPLEMENTATION_TRACKER.md. Document that "shell wired, data bridge is a follow-up PR".
Verify: grep -n "entries: \[\]" Epistemos/Views/Settings/AgentSectionDetailView.swift
```

```
[CANONICAL OVERRIDE — W9.8]
Drift: ApprovalModalView is mounted only as a "Show preview" sheet inside Settings (AuthoritySettingsView.swift:46). Production approval flow at ChatCoordinator.swift:2844 uses NSAlert via promptUserForToolApproval. The modal is reachable only from a Settings preview button, not from agent activity.
Required: Demote W9.8 from 🟢 SHIPPED to 🟡 FOUNDATION. Next-PR plan: replace promptUserForToolApproval NSAlert with sheet-based ApprovalModalView.
Verify: grep -n "ApprovalModalView" Epistemos/Views/Settings/AuthoritySettingsView.swift Epistemos/App/ChatCoordinator.swift
```

```
[CANONICAL OVERRIDE — W9.21]
Drift: Honest-handle modules exist in epistemos-shadow, syntax-core, substrate-core, substrate-rt — but Swift consumers (RustShadowFFIClient.swift:39, others) still bind legacy Box-based FFI. Zero non-test callers for any honest_handle exports.
Required: Either (a) ship PR3+PR4 to cut Swift consumers over to handle FFI, OR (b) add file-header comments documenting "this module is ready for cutover; cutover deferred until <date>" so the orphan status is explicit.
Verify: grep -rn "shadow_handle_open_at\|syntax_handle_create\|substrate_handle\|substrate_rt_handle" Epistemos/
```

```
[CANONICAL OVERRIDE — W9.22]
Drift: Generic Lifecycle<T,S> exists in agent_core/src/runtime/typestate.rs but zero non-test consumers. Dossier mandates concrete MlxSession/HermesProcess/AFMPoolEntry wrappers. Cross-cutting rule "W9.21 must precede W9.22" is satisfied vacuously because typestate doesn't yet wrap honest-FFI handles.
Required: Either ship the concrete wrappers using both honest-FFI handles + Lifecycle, OR demote to ⚪ PENDING.
Verify: grep -rn "Lifecycle<" agent_core/src/ Epistemos/ | grep -v test | grep -v typestate.rs
```

```
[CANONICAL OVERRIDE — W9.27]
Drift: agent_core/src/oplog.rs:128 schema lacks prev_hash BLAKE3 column required by execution map §W9.27 line 810 + D1 dependency. No PRAGMA journal_mode=WAL, no F_FULLFSYNC (D5 violation). Zero Swift consumers.
Required: Add prev_hash BLOB(32) column with BLAKE3 chain hashing on append. Add WAL+F_FULLFSYNC to OpLog::open_persistent.
Verify: grep -n "prev_hash\|PRAGMA journal_mode\|F_FULLFSYNC" agent_core/src/oplog.rs
```

```
[CANONICAL OVERRIDE — W9.30]
Drift: Env-flag scaffold lives in Epistemos/Engine/KIVIQuantization.swift but the mlx-swift-lm fork (LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift) where the actual KIVIKVCache must live has ZERO KIVI references. Foundation is in the wrong package.
Required: Either ship KIVIKVCache: QuantizedKVCacheProtocol in the fork, OR rename status to "ENV-FLAG SCAFFOLD ONLY — implementation lives in the fork" so the staleness is honest.
Verify: grep -n "KIVIKVCache\|KVQuantScheme\|kvScheme" LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift
```

```
[CANONICAL OVERRIDE — D1 missing]
Drift: BLAKE3 Merkle chain (D1) is a Phase 1 prerequisite per doctrine + execution map §D1, but it's not on the MASTER_BUILD_PLAN.md §7 queue. blake3 crate is in epistemos-core/Cargo.toml as content hasher only; provenance_chain table doesn't exist; OpLog schema lacks prev_hash.
Required: Add D1 to the queue OR explicitly defer with consequences acknowledged. Without D1, ReplayBundle byte-equivalence is impossible.
Verify: grep -rn "provenance_chain\|prev_hash" agent_core/src/ epistemos-core/src/
```

```
[CANONICAL OVERRIDE — D2 7-verb MCP missing]
Drift: omega-mcp/src/vault.rs exports read_file/write_file/list_files/search_notes/execute_vault_tool. Research mandate is search_semantic/search_fulltext/get_node/traverse/create_node/create_edge/commit_session. Architectural primitive missing.
Required: Either ship the 7-verb dispatcher OR document that the existing tool surface is the chosen alternative + update doctrine.
Verify: grep -rn "search_semantic\|create_node\|commit_session" omega-mcp/src/
```

```
[CANONICAL OVERRIDE — D3 A2UI catalog missing]
Drift: Epistemos/A2UI/Catalog.swift does not exist. Doctrine §6 #4 ("closed catalog, no fallback inspector") has zero enforcement.
Required: Build the closed catalog with at least the Phase 1 NoteCard component per execution map §D3.
Verify: ls Epistemos/A2UI/ 2>&1 || echo "DIRECTORY MISSING — D3 unimplemented"
```

```
[CANONICAL OVERRIDE — D4 faculty roster (memory violation)]
Drift: LocalModelInfrastructure.swift:513-519 ships Hermes 4.3 36B as primary local agent. At 4-bit, 36B model is ~18 GB resident — exceeds 16 GB hardware ceiling per user's [User Hardware] memory. Will OOM.
Required: Add Hermes-3-Llama-3.1-8B-4bit (or Qwen3 8B-4bit) as DEFAULT primary. Make 36B opt-in for ≥32 GB Macs.
Verify: grep -n "36B\|Hermes 4.3" Epistemos/Engine/LocalModelInfrastructure.swift
```

```
[CANONICAL OVERRIDE — D5 durability missing]
Drift: No PRAGMA journal_mode=WAL, no F_FULLFSYNC anywhere in agent_core/src/. WRV_EXEMPT exemption is hollow because corruption-detection requires durability primitives that don't exist.
Required: Add WAL + F_FULLFSYNC to every SQLite Connection::open call (oplog.rs:118 is the canonical missing site).
Verify: grep -rn "PRAGMA journal_mode\|F_FULLFSYNC\|fcntl" agent_core/src/
```

```
[CANONICAL OVERRIDE — Provenance plane absent]
Drift: MutationEnvelope, ClaimLedger, RetractionPropagated, ProposedEnvelope — zero hits across all Rust + Swift code. Doctrine §3 retraction propagation primitive is hollow. Doctrine §5 open-standard moat depends on these types.
Required: Either build the provenance plane (commit_envelope, retraction_propagation in agent_core/src/provenance/ledger.rs) OR explicitly mark in PLAN_V2 that the provenance plane is V2 work.
Verify: grep -rn "MutationEnvelope\|ClaimLedger\|RetractionPropagated" agent_core/ Epistemos/
```

```
[CANONICAL OVERRIDE — N1 status doc stale]
Drift: MASTER_BUILD_PLAN.md §7 N1 status note + V1_5_IMPLEMENTATION_TRACKER.md line 63 say "Phase 1 cache-telemetry wire is BLOCKED on substrate discovery (session_insights.rs orphan)". Verified at agent_core/src/lib.rs:31: pub mod session_insights; — file IS declared. cache_read_input_tokens IS in SessionMetrics at session_insights.rs:65.
Required: Update both docs to remove the "blocked on substrate" caveat. Identify the actual remaining work (Rust→Swift bridge for entries; CostDashboardView wire-up).
Verify: grep -n "pub mod session_insights" agent_core/src/lib.rs ; grep -n "cache_read_input_tokens" agent_core/src/session_insights.rs
```

```
[CANONICAL OVERRIDE — AnyView violations]
Drift: Doctrine §6 #6 forbids AnyView in render hot paths. Verified 14+ violations across Settings/SettingsView.swift, Graph/HologramOverlay.swift, Graph/HologramSearchSidebar.swift, Graph/GraphFirstOpenTitle.swift.
Required: Hand-replace AnyView with typed view-builder enums or specific view types. Don't wait for the W9.15 routing macro — discipline should hold by hand.
Verify: grep -rn "AnyView" Epistemos/Views/ | wc -l  (target: 0)
```

---

### Final notes

The single biggest pattern: **status-claim drift over algorithm-spec drift**. The codebase has many honest implementations of fragments of features (rope, OpLog, honest-handle, Lifecycle, ApprovalModalView, ThermalMonitor, KIVIPreferences) — but the docs claim them as 🟢 SHIPPED when they're actually unwired scaffolding. The user explicitly named this as the failure mode the WRV gate exists to prevent (`docs/V1_5_IMPLEMENTATION_TRACKER.md:81-86`: "AI has a really bad habit of not wiring things — scaffold then never wire").

The next session should focus on **status corrections + wiring** before any new feature work. Specifically:

1. Fix the cost dashboard data bridge (unblocks W9.6 + N1 visibility).
2. Fix the W9.8 approval modal production wire (replace NSAlert).
3. Add prev_hash + WAL + F_FULLFSYNC to OpLog (D1 + D5 prerequisites).
4. Cut Swift consumers over to honest-FFI handles (W9.21 PR4).
5. Update tracker to remove stale "blocked" caveats.
6. Decide D1, D2, D3, D5, D9, D11 fate (queue or defer formally).

After those, the queue can resume new feature work without the orphan-scaffold pattern compounding.

---

## 2026-04-27 — Pass #2 reconciliation against HEAD `78528cc7`

Per orchestrator §1.5 ("If a finding has been resolved by a recent commit, mark it RESOLVED in the log; append a status line; do not delete the original entry"). Original pass #1 entries above remain intact; this pass appends authoritative status updates against the live codebase + recent commits.

### Verification methodology

- Foreground reads: PLAN_V2, MASTER_BUILD_PLAN, plan/00–05, V1_5_IMPLEMENTATION_TRACKER, STRUCTURING_AUDIT, KNOWN_ISSUES_REGISTER, CRITIQUE_LOG tail (pass #15), StructureRegistry.swift, RESEARCH_DOSSIER head, IMPLEMENTATION_PLAN_FROM_ADVICE head — all read in full.
- Background general-purpose agent ran the verifying grep for every Blocker against HEAD `78528cc7`.
- Phase 0 ground-truth verified live: cargo agent_core test = **708 passed; 0 failed**; xcodebuild = **BUILD SUCCEEDED** (exit 0).
- Recent commits since pass #1 examined: `8e13f67e` (audit pass #14 docs), `6d78593b` (D5 ship), `8e4e018d` (D4 stash + D5 tracker), `78528cc7` (orchestrator §1.5).

### Pass #1 → Pass #2 status delta

| Blocker | Pass #1 status | Pass #2 status | Resolving commit(s) | Evidence |
|---------|----------------|----------------|---------------------|----------|
| **D5 substrate durability** (WAL + F_FULLFSYNC) | Blocker — durability hollow | 🟢 **RESOLVED** | `6d78593b` | `oplog.rs:144` `pragma_update("journal_mode","WAL")` + `synchronous=FULL`; `oplog.rs:186` `libc::fcntl(file.as_raw_fd(), F_FULLFSYNC, 0)`; same triple at `storage/vault.rs:110-115`. 2 verifying pragma tests at `oplog.rs:648, 662`. 708/708 cargo green. |
| **W9.6 chrome-stub `entries: []`** | Blocker — dashboard never shows real data | 🟡 **PARTIAL-RESOLVED** | `af0a0f21` | `AgentSectionDetailView.swift:135` mounts `SpendDashboardHost` calling `EventStore.recentSessionMetrics(limit: 30)`. Cache-hit rate row fully live with color tinting. Provider name + per-session USD columns remain placeholders pending pricing-table extension. |
| **N1 "blocked on substrate"** | Warning — tracker out of date | 🟢 **RESOLVED** | `4561f31b` + `b9a5312d` + `b8d779ca` + `af0a0f21` | Substrate orphan fix → cache wire → AgentResultFFI extension → end-to-end persist+render. Tracker line 63 = 🟢 SHIPPED. |
| **W9.6 `budget_gate` cost-cap → ApprovalModal** | Blocker | ⚪ **STILL OPEN** | — | Verified zero `budget_gate` hits in `agent_core/src/`. Lower priority now that dashboard data is visible. |
| **D4 Hermes 36B OOM on 16GB** | Blocker — memory math violation | 🟢 **RESOLVED** | `8e4e018d` (catalog) + `4c0c7e17` (estimated4BitWeightsGB accessor + final ship) | Catalog landed: `fallbackPrimaryAgentModel = .qwen3_8B4Bit`, `optInPrimaryAgentModel = .hermes43_36B4Bit`, `primaryAgentModelMinHostRAMGB = 32`, opt-in defaults key. Final ship adds the missing `LocalTextModelID.estimated4BitWeightsGB` accessor (all 46 catalog cases enumerated; 4-bit ≈ params × 0.5 GB rule). 6 invariant tests pass; xcodebuild green; zero new test regressions (pre-existing W9.25-stale Swift test confirmed as not D4-induced via D4-isolation stash). |

### Updated Blocker count: 17 → 13 still open + 1 partial-resolved (after W9.27 PR3 + D1 ship at fe97e512)

- Pass #1 score: 47 audited / 17 Blockers / 19 Warnings / 6 Notes
- Pass #2 score (initial): 47 audited / 16 Blockers / 1 partial-resolved (W9.6 main) / 1 in-flight (D4 stashed) / 19 Warnings / 6 Notes
- Pass #2 score (post-D4 ship at `4c0c7e17`): 47 audited / 15 Blockers / 1 partial-resolved (W9.6 main) / 19 Warnings / 6 Notes
- Pass #2 score (post-W9.27 PR3 + D1 ship at `fe97e512`): 47 audited / **13 Blockers** / **1 partial-resolved (W9.6 main)** / 19 Warnings / 6 Notes
  - W9.27 schema-drift (`prev_hash BLOB(32)` column) RESOLVED at `fe97e512` (idempotent ALTER migration; reopen-restore-chain-tip; 713/713 cargo).
  - D1 BLAKE3 Merkle chain (`compute_chain_link` domain-separated hashing) RESOLVED at `fe97e512`.

### Foundational doctrine primitives — STILL 100% ABSENT IN CODE

Per pass #1 cross-cutting #3, the doctrine §3 keystone primitive remains doc-only. Confirmed by direct grep on HEAD:

```
grep -rn 'MutationEnvelope\|ProposedEnvelope\|ClaimLedger\|RetractionPropagated' agent_core/ epistemos-*/ Epistemos/
→ ZERO hits across all Rust + Swift sources; matches only in docs/.
```

This is the doctrine's named contribution ("verifiable cognition is the moat" §0; "retraction propagation is the keystone primitive" §3). It is the largest unimplemented architectural debt in V1.5.

Likewise still absent:
- **Schema-driven UI registry / `ViewRegistry`** — does not exist; UI is hand-coded view-by-view. `StructureRegistry.swift` registers schemas but does not dispatch views.
- **7-verb MCP graph boundary** (D2) — `omega-mcp/src/vault.rs` exports `read_file/write_file/list_files/search_notes/execute_vault_tool`; the 7 doctrine verbs (`search_semantic/search_fulltext/get_node/traverse/create_node/create_edge/commit_session`) have ZERO matches.
- **Closed A2UI catalog** (D3) — `Epistemos/A2UI/` directory does not exist.
- **`epistemos-trace` CLI** (D11) — no separate provenance-standard repo or Cargo binary.

### Orphan-scaffold pattern — still the dominant drift mode

W9.21 (4 honest_handle modules — zero Swift consumers); W9.22 (generic `Lifecycle<T,S>` — zero concretizations); W9.26 (`RopeFFIClient.swift` — zero non-test callers); W9.27 (`OpLog::open_persistent` — zero Swift consumers + missing `prev_hash` column for D1 Merkle chain). All four still match the pattern doctrine §6 #14 explicitly forbids.

### Recommended ship order (next 3 commits — non-conflicting; suitable for parallel worktree builders)

1. **D4 unstash + `LocalTextModelID.estimated4BitWeightsGB` accessor** (Lane C, Swift, ~30 min) — highest-priority, in-flight, blast-radius zero. Closes the 16GB-Mac OOM Blocker.
2. **W9.27 PR3 schema migration** (Lane B, Rust, ~2 hr) — add `prev_hash BLOB(32) NOT NULL DEFAULT zeros` column + BLAKE3 `prev_hash → next_hash` chain on `append()` (`agent_core/src/oplog.rs:202-213` schema + chain logic). Single commit closes BOTH W9.27 schema-drift AND D1 BLAKE3 Merkle Blockers.
3. **W9.21 PR4 Swift consumer cutover** (Lane C, Swift, ~1.5 hr) — cut `RustShadowFFIClient.swift:49` over to `shadow_handle_open_at` / `shadow_handle_search` honest-handle exports (already shipped in PR1 `dcc5521f`). Closes the longest-standing orphan-scaffold pattern.

These three touch disjoint files and can be dispatched as parallel `isolation: "worktree"` builder agents per orchestrator §3.

### Pass #2 close summary

- 1 Blocker fully RESOLVED (D5 — verified live).
- 1 Blocker PARTIAL-RESOLVED (W9.6 main chrome stub — `SpendDashboardHost` mounted; provider/USD pending).
- 1 Blocker IN-PROGRESS / stashed (D4 — Swift fix on `git stash@{0}` pending one accessor).
- 0 newly discovered Blockers.
- 16 Blockers remain open; provenance-plane primitives + ViewRegistry + 7-verb MCP + closed A2UI catalog + epistemos-trace CLI are the load-bearing absences.
- This audit log itself is now committed (was untracked working-tree drift; per CRITIQUE_LOG pass #15 highest-priority directive resolved).
- Phase 0 verified: 708 cargo / xcodebuild SUCCEEDED.

---

## 2026-04-27 — Pass #3 reconciliation: `docs/architecture/` fusion into canonical baseline

User directive on this pass: "doa final check to see if there is any naunce to take and fuse with the current canonical plan." Read all 22 docs in `/Users/jojo/Downloads/Epistemos/docs/architecture/` (PLAN_V2.md + PLAN_V2_UPDATED.md, README.md, CODEX_CONTEXT_PACK.md, RESEARCH_INDEX.md, OVERSEER_AND_AGENT_HIERARCHY.md, COMPUTE_STEERING_SPEC_v1.md, ADAPTATION_SUBSYSTEM_SPEC_v1.md, BENCHMARK_BASELINES.csv, AGENT_STREAM_BASELINES.csv, BOLTFFI_AUDIT_2026_04_15.md, CHAT_TRANSPARENCY_PLAN_2026-04-19.md, CLAUDE_CANONICALIZATION_REDO_HANDOFF_2026_04_14.md, COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md, EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md, fix.md, MASTER_PLAN_2026-04-19.md, NEW_SESSION_PROMPT*.md, PERF_REPAIR_REPORT_2026_04_21.md, PHASE_*_HANDOFF.md (1.5/4/5/6/6.5/7), PHASE_6_PROTOCOL.md, PLAN_V2_CANONICALIZATION_*.md, RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md). Most are subordinate to `docs/architecture/PLAN_V2.md` (already authoritative) and the `docs/plan/` tree (already canonical for V1.5). **Two material drift findings emerge that Pass #1 missed** because they live OUTSIDE the V1.5 item set, plus four operational notes worth preserving so future sessions don't relitigate.

### Drift A — `Epistemos/Engine/CommandCenterRequestCompiler.swift` is a second Swift control plane

**Severity:** Blocker (NEW; doctrine §3.1 + plan/01_DOCTRINE §6 #11 violation; was Phase 5 exit criterion #4).

**Sources:** `PHASE_6_CLARK_HANDOFF_2026_04_14.md` §6 Drift 1; `CLAUDE_CANONICALIZATION_REDO_HANDOFF_2026_04_14.md` Drift 1 (lines 184-237); `PLAN_V2_CANONICALIZATION_MASTER_PROMPT_2026_04_14.md` "Actual Drift List" Drift 1; `PHASE_5_HANDOFF.md` §"Minimum Exit Criteria Before Phase 6" item #4 (Rust owns final request compilation / routing / permission truth for Command Center).

**Evidence:** `Epistemos/Engine/CommandCenterRequestCompiler.swift:64-80 CompiledCommandCenterRequest` resolves context refs + runtime selection truth + tool permission allow/deny + execution policy / route summaries — every decision PLAN_V2 §3.1 (Rust sovereign) + §4.1 ("the command center is a user-facing delegation surface, not a second control plane") and plan/01_DOCTRINE.md §6 #11 say belongs to Rust. Phase 5 exit criterion #4 was waived (per `PHASE_6_PROTOCOL.md` "Critical Status Note") to let Phase 6 begin. Per `PHASE_6_CLARK_HANDOFF` §13 "biggest single drift risk", this is the **single largest architectural violation** in the codebase today.

**Why Pass #1 missed it:** Pass #1 audited the V1.5 backlog (R/W/D/N items in MASTER_BUILD_PLAN.md §7). CommandCenterRequestCompiler.swift is Phase 5 territory, not on the V1.5 queue.

**Required fix:** New Rust FFI entry point `compile_command_center_request(...)` in `agent_core/src/command_center.rs` + `agent_core/src/bridge.rs` owns context resolution + runtime resolution + tool permission + execution policy + routing truth. Swift becomes parser + UI binder only. The existing `CompiledCommandCenterRequest` Swift struct becomes the Rust output. Tests required: explicit-brain-choice parity, unavailable-brain truthfulness, allowlist behavior parity, inspector-diagnostics parity. Per Codex: land behind a feature flag for one release cycle before removing legacy.

**Priority:** Queue position 10 (insert AFTER current ship_phase batch — W9.21 PR4 + W9.8 + AnyView + W9.27 PR3.5 + W9.26 PR4 + W9.22 concrete wrappers — and BEFORE the provenance plane keystone). Reasoning: every additional V1.5 item hardens the wrong control plane until Drift A lands; closing it shrinks the rework surface for the Provenance Plane integration.

### Drift B — Three-router architecture (Swift ConfidenceRouter + Rust agent_core/routing.rs + Rust epistemos-core/agent_runtime/routing.rs)

**Severity:** Major (architectural duplication; not Blocker — code works but drifts from doctrine).

**Source:** `CHAT_TRANSPARENCY_PLAN_2026-04-19.md` P2 "Consolidate the three routers" (lines 130-138).

**Evidence:** Three independent router implementations with overlapping responsibilities exist in `Epistemos/LocalAgent/ConfidenceRouter.swift` + `agent_core/src/routing.rs` (CLAUDE.md FILE MAP confirms canonical Rust path) + `epistemos-core/src/agent_runtime/routing.rs`. Each makes routing decisions; "load-bearing router" is unclear.

**Required fix:** Decide canonical router (per CLAUDE.md FILE MAP authority: `agent_core/src/routing.rs`). Migrate the loser's logic. Delete dead file. Make Swift's `ConfidenceRouter` a pure classifier feeding the Rust router (not a parallel decider). Land behind a feature flag for one release cycle before removing legacy. Run 50+ sample queries through both routers; assert same decision within tolerance; ship flag off until samples converge.

**Priority:** Queue position 11. Highest-risk architectural cleanup but not Blocker — does not currently corrupt user data.

### Operational notes (NOT drift; preserved here so future sessions don't relitigate)

#### Note A — Swift 6 strict-concurrency cascade-error trap

**Source:** `PHASE_7_CODEX_AUDIT_HANDOFF_2026_04_15.md` §3.1.

**Reality:** A single Swift 6 data-race violation in ONE test file (e.g., `@Sendable` closure capturing `note.userInfo`) cascades **~50 `@const`/`@section` macro errors into UNRELATED test files** during the same compilation batch. The unrelated files are NOT actually broken — fix the data race in the file you just edited and the cascade errors disappear.

**Why this matters:** Future sessions seeing floods of `'@const' value should be initialized with a compile-time value` or `global variable must be a compile-time constant to use @section attribute` in test files they didn't touch should NOT chase those errors directly. Trace back to a recent test edit with a `@Sendable` closure or `note.userInfo` capture.

#### Note B — `image_generate` is no longer drift

**Reality:** Clark's PHASE_6 Drift 3 (FAL cloud-only vs PLAN_V2 §5.1 MLX-first mandate) was real on 2026-04-14 but resolved by a §16 amendment to PLAN_V2. Current §16 reads: "Cloud image generation, if kept, is an explicit opt-in provider path only. FAL or other remote image providers may exist for manual/advanced use, but they do not make the MLX lane 'complete' and must not be used as silent fallback." Current code (FAL-only with explicit `provider: "fal"` opt-in) is now **canonical** with the updated PLAN_V2.

#### Note C — `codex/runtime-input-audit` perf fixes are baseline, not drift

**Source:** `PERF_REPAIR_REPORT_2026_04_21.md` (full file; landed via `codex/runtime-input-audit` branch).

**Reality:** The release-hardening Phase 0 batch — fenced ` ```tool_call ` parser fix, MLX unload Metal-working-set release, cloud direct-stream manifest tightening (no longer advertises app tools it cannot execute), essay/draft phrasing escalates same as note reads, Mini Chat Tools-mode pill (vs Thinking), deferred Apple hybrid embedding lookup (~67 MB RSS post-fix), dangling fenced-language marker suppression — all baseline now. NOT drift.

#### Note D — Phase 6 / 6.5 / 7 closures intentionally deferred (does NOT block V1.5)

**Sources:** `PHASE_6_PROTOCOL.md` §"Critical Status Note"; `PHASE_6_5_CLAUDE_STARTUP_HANDOFF_2026_04_15.md`; `PHASE_7_CODEX_AUDIT_HANDOFF_2026_04_15.md` §6.

**Reality:** Phase 6 (Communication + Media), Phase 6.5 (Capture-to-memory), and Phase 7 (Graph Workspace) all have substantial code in tree but their FORMAL closures depend on manual runtime verification (real outbound credentials + macOS permissions) the operator has chosen to defer. The V1.5 backlog work running today (R/W/D/N items, doctrine substrate, orphan-scaffold cleanup) is **orthogonal** to those phase closures — it hardens the substrate beneath all phases. Future sessions should NOT confuse "Phase 6/6.5/7 closure" with "V1.5 ship-readiness" — different gates.

### Updated Blocker count: 17 → 14 still open + 1 Major drift + 1 partial-resolved (post Pass #3)

- Pass #1: 47 audited / 17 Blockers / 19 Warnings / 6 Notes
- Pass #2 close (`fe97e512`): 13 Blockers + 1 partial-resolved (post D5 + D4 + W9.27/D1)
- **Pass #3 close: 49 audited (47 + 2 newly-discovered) / 14 Blockers (13 carry-over + Drift A) / 1 Major drift (Drift B) / 1 partial-resolved / 19 Warnings / 6+ Notes**

### Updated priority queue (post-Pass #3)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1-3 | Audit log seed + D4 + W9.27 PR3 + D1 | ✅ shipped | `85fed65c`, `4c0c7e17`, `fe97e512` |
| 4 | **W9.21 PR4 Swift consumer cutover** | 🔵 in-flight | CRITIQUE_LOG #15 priority — closes longest orphan-scaffold pattern |
| 5 | **W9.8 NSAlert → ApprovalModalView** | 🔵 in-flight | Production approval-modal wire (replaces ChatCoordinator NSAlert) |
| 6 | **AnyView 16-violation cleanup** | 🔵 in-flight | Doctrine §6 #6 enforcement (4 files, 16 instances) |
| 7 | W9.27 PR3.5 OpLogFFIClient.swift | ⚪ pending | Mirror RopeFFIClient pattern; closes OpLog orphan |
| 8 | W9.26 PR4 NoteFileStorage rope migration | ⚪ pending | Closes RopeFFIClient orphan |
| 9 | W9.22 concrete typestate wrappers | ⚪ pending | MlxSession/HermesProcess/AFMPoolEntry; closes Lifecycle orphan |
| 10 | **Drift A: CommandCenterRequestCompiler → Rust** | ⚪ NEW Blocker | Phase 5 exit criterion #4 close; doctrine §3.1 enforcement |
| 11 | Drift B: three-router consolidation | ⚪ NEW Major | Swift ConfidenceRouter + 2 Rust routers → 1 |
| 12 | W9.6 budget_gate cost-cap → ApprovalModal | ⚪ pending | Cost dashboard data live; cap-fires-modal flow missing |
| 13 | W9.30 KIVIKVCache in mlx-swift-lm fork | ⚪ pending | Foundation lives in wrong package |
| 14 | W9.25 GrammarMaskedLogitProcessor real masking | ⚪ pending | Soft EOS guidance only today |
| 15 | D2 7-verb MCP graph boundary | ⚪ pending | Architectural; Hermes integration depends on it |
| 16 | D3 closed A2UI catalog with NoteCard | ⚪ pending | Doctrine §6 #4 enforcement; A2UI/ directory absent |
| 17 | D9 skills as graph nodes | ⚪ pending | MCP intercept of `~/.hermes/skills/` writes |
| 18 | D11 epistemos-trace CLI separate repo | ⚪ pending | Open standard moat; doctrine §5.1 |
| 19 | **Provenance plane MutationEnvelope/ClaimLedger/RetractionPropagated** | ⚪ keystone | Doctrine §3 — the single largest unimplemented architectural debt |

### Pass #3 close summary

- 0 newly-RESOLVED Blockers this pass (it's a reconciliation pass, not a ship pass).
- 2 newly-DISCOVERED items (Drift A Blocker + Drift B Major) added to the queue.
- 4 operational notes preserved (Swift 6 cascade trap; image_generate now canonical; codex perf fixes baseline; Phase 6/6.5/7 closures orthogonal).
- Total queue: 14 Blockers + 1 Major still open. Provenance plane remains the keystone.

---

## 2026-05-17 - T9 Live Coordination Overlay

This overlay records coordination-state deltas during the nine-terminal sub-mission; it does not replace the strategic Pass #1-#3 architecture audit.

- T1 has advanced to `ebcfbdd20` with scope-clean Hyper-Dynamic Schemas audit/doctrine docs. Runtime Tri-Fusion implementation remains open.
- T2 has advanced to pushed `ed7ff2531` with scope-clean Settings diagnostics, but `ISSUE-2026-05-16-015` remains `Investigating`: 16 GB 36B remains experimental opt-in, not Verified Fixed, and T2's dirty worktree still contains generated artifacts plus out-of-lane `Epistemos/Models/**` edits.
- T4 local `4e0f74372` is scope-clean and removes the earlier target-artifact drift from T4's worktree, but the branch was not pushed at this check.
- T6 local `67ba8f17d` is scope-clean for the committed Ambient Frequencies UI/UX slice, but generated `syntax-core/target/**` artifacts remain dirty in the T6 worktree.
- No open GitHub PRs were visible to `gh pr list --state open` at this check.
- Main baseline remained green after the sweep: `cargo test --manifest-path agent_core/Cargo.toml --lib` passed 1671 tests and xcodebuild reported `BUILD SUCCEEDED`.

### Iter 6 overlay - 2026-05-17 07:33 CDT

- T1 pushed through `8bb2b5300`; new docs remain scope-clean doctrine for Tri-Fusion API, model wiring, and editor mutation wiring.
- T6 pushed through `33cc776f7`; new UI/UX audit docs remain scope-clean and report no P0/P1 findings for Settings Diagnostics, Halo / Provenance Console, and CognitiveWeightBadge.
- T2 dirty-state drift widened: multiple out-of-lane Swift files are now dirty alongside the existing generated target artifacts.
- T4 generated-artifact drift reappeared via `syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.d`.
- No open GitHub PRs were visible to `gh pr list --state open`.
- Main baseline remained green after the sweep: `cargo test --manifest-path agent_core/Cargo.toml --lib` passed 1671 tests and xcodebuild reported `BUILD SUCCEEDED`.

### Iter 7 overlay - 2026-05-17 07:45 CDT

- T1 pushed through `87d336711`; new docs remain scope-clean. T1's dirty implementation slice now needs pre-commit coordination because `agent_core/src/lib.rs` is outside the exact written T1 touch list.
- T2 pushed `9b090203d`; the AnswerPacket persistence behavior is coherent, but the commit crossed outside T2's written lane into chat coordinator, model, state, and chat UI files. T9 recorded this as a committed scope violation.
- T4 advanced locally to `2c4f0d1bf`; the recency half-life patch is scope-clean and the T4 generated-artifact drift is resolved again, but the branch remains local-only.
- T6 pushed through `1ac9448a8`; new UI/UX audit docs remain scope-clean, while generated `syntax-core/target/**` artifact drift remains open in the T6 worktree.
- T2 generated-artifact drift remains open; current dirty non-artifact file is the in-scope `Epistemos/Views/Settings/AnswerPacketHealthRow.swift`.
- No open GitHub PRs were visible to `gh pr list --state open`.
- Main baseline remained green after the sweep: `cargo test --manifest-path agent_core/Cargo.toml --lib` passed 1671 tests and xcodebuild reported `BUILD SUCCEEDED`.

### Iter 8 overlay - 2026-05-17 07:54 CDT

- T1 pushed `e117ef855`; the Tri-Fusion JSON document floor is narrow, but `agent_core/src/lib.rs` was committed outside the exact T1 touch list without the requested scope-exception note, and the co-author footer lacks the T1 prompt's email form.
- T1's current dirty work is back inside its lane: `agent_core/src/research/hyperdynamic_schemas/**` plus a Tri-Fusion schema validation test.
- T2 pushed `edb69ec47`; the AnswerPacket Health Settings row is scope-clean, but the branch remains blocked by prior `9b090203d` scope violation and generated `syntax-core/target/**` artifacts.
- T4 advanced locally to `6998cc41f`; the query-boilerplate normalization patch is scope-clean and the T4 worktree remains clean, but the branch still has no upstream configured.
- T6 has no new commit beyond `1ac9448a8`; generated artifact drift remains open.
- No open GitHub PRs were visible to `gh pr list --state open`.
- Main baseline remained green after the sweep: `cargo test --manifest-path agent_core/Cargo.toml --lib` passed 1671 tests and xcodebuild reported `BUILD SUCCEEDED`.

### Iter 9 overlay - 2026-05-17 08:00 CDT

- T1 pushed `116257807`; the path-aware document schema validation commit is scope-clean inside `agent_core/src/research/hyperdynamic_schemas/**` plus a Tri-Fusion test, but the earlier `agent_core/src/lib.rs` exception and missing T1 coauthor email remain open.
- T1's current dirty work remains in-lane: `agent_core/src/tri_fusion/mod.rs` plus `agent_core/tests/tri_fusion_mutations.rs`.
- T2 has no new commit beyond `edb69ec47`, but its dirty worktree widened to 234 modified files / roughly 5014 insertions and 1738 deletions, including T4-owned `agent_core/src/storage/vault.rs`, T7-owned `agent_core/src/research/eml/**`, broad research modules, and generated `syntax-core/target/**` artifacts.
- T4 advanced locally to `5bbe32951`; the exact-title/path-title recall patch is scope-clean and improves F-VaultRecall-50 metrics, but the falsifier report still fails provenance UI (0/50) and synthesis diversity (8/10 vs 10/10).
- T4 worktree is clean after the commit, but the branch remains local-only with no upstream configured.
- T6 has no new commit beyond `1ac9448a8`; generated artifact drift remains open.
- No open GitHub PRs were visible to `gh pr list --state open`.
- Main baseline remained green after the sweep: `cargo test --manifest-path agent_core/Cargo.toml --lib` passed 1671 tests and xcodebuild reported `BUILD SUCCEEDED`.
