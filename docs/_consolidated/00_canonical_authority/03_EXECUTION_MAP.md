# 03 — Execution Map: Per-Item Detail

**Authority:** Subordinate to `01_DOCTRINE.md`, `02_BUILD_MATRIX.md`, `04_PHASES.md`.
For each item: doctrine alignment, research-doc references, files to touch (with line
numbers verified against the codebase as of 2026-04-26), tests-must-stay-green,
telemetry surface required, definition of done.

**How to read an entry.** Every agent picking up an item MUST read the entry in full,
follow the "research mandates" verbatim, and treat the "definition of done" as the
exit gate.

---

## Item index

### R-series (research/infrastructure from the dossier)
- [R14 — UniFFI 0.28 → 0.29.5](#r14--uniffi-028--0295)
- [R15 — Benchmark harness](#r15--benchmark-harness)
- [R16 — ETL crawler (deferred)](#r16--etl-crawler-deferred)

### W9-series (Tier 4 features from the dossier)
- [W9.6 — Cost dashboard + budget gate](#w96--cost-dashboard)
- [W9.7 — Vault sidebar selector](#w97--vault-selector)
- [W9.8 — Approval modal](#w98--approval-modal)
- [W9.10 — TurboQuant KV (deferred)](#w910--turboquant-deferred)
- [W9.11 — Personalized embeddings (deferred)](#w911--personalized-embeddings-deferred)
- [W9.12 — Orphan rediscovery (deferred)](#w912--orphan-rediscovery-deferred)
- [W9.13 — Daily notes + FSRS](#w913--daily-notes--fsrs)
- [W9.14 — Block references (deferred)](#w914--block-references-deferred)
- [W9.15 — Routing macro (deferred)](#w915--routing-macro-deferred)
- [W9.21 — Honest FFI](#w921--honest-ffi)
- [W9.22 — Typestate Islands](#w922--typestate-islands)
- [W9.23 — Bit-packed circuit breaker](#w923--circuit-breaker)
- [W9.24 — Metal zero-copy buffers (deferred)](#w924--metal-zero-copy-deferred)
- [W9.25 — Grammar masking](#w925--grammar-masking)
- [W9.26 — B-tree rope (deferred)](#w926--b-tree-rope-deferred)
- [W9.27 — Append-only OpLog (deferred)](#w927--append-only-oplog-deferred)
- [W9.28 — Blelloch scan (deferred research)](#w928--blelloch-scan-deferred-research)
- [W9.29 — Thermal-aware throttle](#w929--thermal-aware-throttle)
- [W9.30 — KIVI 2-bit KV quant](#w930--kivi-2-bit-kv-quant)

### D-series (doctrine-emergent items from `01_DOCTRINE.md` and the final v2 research)
- [D1 — BLAKE3 Merkle-chained RunEventLog](#d1--blake3-merkle-chained-runeventlog)
- [D2 — 7-verb MCP graph boundary](#d2--7-verb-mcp-graph-boundary)
- [D3 — Closed A2UI catalog](#d3--closed-a2ui-catalog)
- [D4 — Faculty roster lock-in](#d4--faculty-roster-lock-in)
- [D5 — Substrate durability discipline](#d5--substrate-durability-discipline)
- [D6 — Hierarchical concept extraction (deferred)](#d6--hierarchical-concept-extraction-deferred)
- [D7 — FSRS-6 + raw-thought decay (deferred)](#d7--fsrs-6--raw-thought-decay-deferred)
- [D8 — Night Brain + Morning Consolidation (deferred)](#d8--night-brain--morning-consolidation-deferred)
- [D9 — Skills as graph nodes](#d9--skills-as-graph-nodes)
- [D10 — Speculative decoding (deferred research)](#d10--speculative-decoding-deferred-research)
- [D11 — `epistemos-trace` CLI (parallel track)](#d11--epistemos-trace-cli-parallel-track)
- [D12 — BoltFFI investigation (deferred research, UNVERIFIED)](#d12--boltffi-investigation-unverified)

### N-series (novel additions emerged after the dossier locked)
- [N1 — Prompt Tree (JSPF + PTF) + StructureRegistry-driven prompt composer](#n1--prompt-tree-jspf--ptf--structureregistry-driven-prompt-composer)

---

## Standing rules (apply to every entry below)

**WRV gate is mandatory** per `00_AUTHORITY_AND_ANTI_DRIFT.md §4.7`:
- Every item must be **Wired** (production caller exists, verifiable via grep), **Reachable** (documented user gesture sequence), **Visible** (UI element or session-insight surface).
- The PR must include a "WRV proof" block.
- Exempt items are flagged inline below with `WRV_EXEMPT:` and a justification. The exempt set is closed:
  - **R14** (UniFFI bump) — `WRV_EXEMPT: infrastructure` (no user-facing surface; build hygiene only).
  - **R15** (Benchmark harness) — `WRV_EXEMPT: test-only` (does not ship in either app target).
  - **D5** (Substrate durability discipline) — `WRV_EXEMPT: infrastructure` (corruption detection raises errors when triggered, but normal operation is invisible).
  - **W9.21** (Honest FFI) — `WRV_EXEMPT: infrastructure` (architectural; no user gesture).
  - **W9.22** (Typestate Islands) — `WRV_EXEMPT: infrastructure` (compile-time only).
  - **W9.23** (Circuit breaker) — NOT exempt; the breaker state must be visible (provider status pill).
  - **W9.24** (Metal zero-copy) — `WRV_EXEMPT: infrastructure` (perf-only).
  - **W9.27** (OpLog) — NOT exempt at the feature level (time-travel UI is the visible surface), exempt at the substrate level only when it has no user-facing time-travel affordance yet.
  - All other items: NOT exempt. WRV must verify.

**Auto-research is mandatory** per `00_AUTHORITY_AND_ANTI_DRIFT.md §3`. Every term, library, version, file path, line number, or benchmark figure not in context must be verified by `Read`/`Grep`/`WebFetch` before being asserted.

---

## Entry conventions

Each entry uses this template:

```
### <ID> — <Title>

**Phase:** <0-4 | parallel> | **Targets:** <MAS | Pro | both> | **Risk:** <Low|Med|High>
**Doctrine refs:** <01_DOCTRINE.md sections>
**Build matrix:** <02_BUILD_MATRIX.md row references>
**Phase plan:** <04_PHASES.md section>

**Files to touch (verified):** <paths with line numbers>

**Research mandates:** <files in /Advice, /final, /final v2; web-fetch URLs;
                       internal grep targets>

**Tests must stay green:** <named tests + new tests required>

**Telemetry surface required:** <where the user sees the behavior>

**Definition of done:** <checklist beyond the mandatory §4 gates>

**Notes / risks:** <gotchas, prior-attempt context>
```

Verification gates from `00_AUTHORITY_AND_ANTI_DRIFT.md §4` are implicit in every DoD —
do not restate them. The `Definition of done` section adds *item-specific* gates only.

---

# R-series

## R14 — UniFFI 0.28 → 0.29.5

**Phase:** 1 | **Targets:** Both | **Risk:** Low-Med
**Doctrine refs:** §6 non-negotiable #11 (no `DispatchQueue.main.sync` in callbacks)
**Build matrix:** Both targets; UniFFI is shared
**Phase plan:** `04_PHASES.md` Phase 1

**Files to touch (verified):**
- `agent_core/Cargo.toml` (uniffi pin)
- `epistemos-core/Cargo.toml`
- `omega-mcp/Cargo.toml`
- `omega-ax/Cargo.toml`
- `patch-uniffi-bindings.py` (post-processor; add `nonisolated` annotation pass for Sendable conformances)
- `Epistemos/Engine/RustShadowFFIClient.swift`
- `Epistemos/Engine/RustEventRingClient.swift`
- `Epistemos/Engine/EventDrain.swift`
- `Epistemos/Engine/AgentGrepService.swift`
- `Epistemos/Bridge/StreamingDelegate.swift`

**Note:** `epistemos-shadow/Cargo.toml` does NOT need bumping — uses `@_silgen_name` raw FFI.

**Research mandates:**
- Read: `~/Downloads/final v2/deep-research-report (4).md` (UniFFI section, lines ~104-108)
- Read: dossier section "R14 — UniFFI 0.28 → 0.29.5" in user's pasted research
- WebFetch: https://github.com/mozilla/uniffi-rs/releases/tag/v0.29.5 (verify the changelog is what we expect)
- Grep: `UniffiCustomTypeConverter` across the repo — must return zero hits before bump

**Tests must stay green:**
- All `agent_core` tests
- All Swift bridge tests (`*BridgeTests`, `RustShadowFFI*Tests`)
- Cross-FFI streaming tests must pass with no regressions

**Telemetry surface required:** none (infrastructure-only change)

**Definition of done:**
- [ ] `cargo tree -p uniffi` shows exactly `0.29.5` for all four crates
- [ ] Generated bindings rebuild cleanly; no warnings about method-checksum changes
- [ ] `patch-uniffi-bindings.py` correctly emits `nonisolated` on Sendable callback protocols
- [ ] Smoke test: a Hermes provider invocation completes round-trip without callback deadlock
- [ ] No `[UNVERIFIED]` claims remain in the PR description regarding UniFFI behavior

**Notes / risks:**
- Issue #2818 (SwiftPM target separation) is **not fixed in 0.29.5**. The headline
  rebuild-perf benefit does not land. Frame this internally as hygiene, not perf.
- Do NOT bump to 0.30/0.31 — method checksum changes warn (per dossier §305).

---

## R15 — Benchmark harness

**Phase:** 2 | **Targets:** Pro (development build only; not shipped) | **Risk:** Low
**Doctrine refs:** §4 (hardware budget — verifiable claims need numbers); §0 verdict
**Build matrix:** Dev/CI only; not in either shipping target
**Phase plan:** `04_PHASES.md` Phase 2 exit criterion (must exist before W9.30 perplexity gate is credible)

**Files to touch (verified):**
- `bench/src/uniffi_throughput.rs` (new)
- `bench/src/sqlite_vec_knn.rs` (new)
- `EpistemosTests/Benchmarks/AFMGenerableBenchTests.swift` (new)
- `EpistemosTests/Benchmarks/MLXThermalBenchTests.swift` (new)
- `EpistemosTests/Benchmarks/SQLiteVecKNNBenchTests.swift` (new)
- `EpistemosTests/Benchmarks/UniFFICallbackThroughputTests.swift` (new)
- Existing `bench/src/morning_session.rs`, `bench/src/model2vec_bench.rs` (extend, don't rewrite)
- `Epistemos/Engine/PowerGate.swift` (existing — wire `ProcessInfo.thermalState` into bench loop)

**Research mandates:**
- Read: dossier "R15 — Benchmark harness"
- Read: `~/Downloads/final v2/Epistemos Hackathon_ Deep Research Plan.txt` (perf targets)
- WebFetch: Apple WWDC23/24 sessions on thermal management (canonical thermal state docs)

**Tests must stay green:** existing benchmarks must continue running

**Telemetry surface required:** benchmark results emitted as JSON to `benchmarks/results/<date>.json` (not in shipping app)

**Definition of done:**
- [ ] `swift test --filter Benchmarks` runs all 4 new benchmark test files
- [ ] `cargo bench` produces stable Criterion output for `bench/` crate
- [ ] Thermal-pressure run: 5+ minute MLX inference loop produces a tok/s decay curve
- [ ] sqlite-vec KNN at 100k vectors: p50/p95/p99 captured
- [ ] AFM `@Generable` round-trip latency captured for small/medium/large schemas
- [ ] CI does not run these (they take >10 min); manual invocation only

**Notes / risks:** thermal benchmarks must skip on battery (`IOPSGetTimeRemainingEstimate`).

---

## R16 — ETL crawler (deferred)

**Phase:** 4 | **Targets:** MAS (gated) + Pro | **Risk:** High
**Doctrine refs:** §4 (6 GB budget — background jobs must yield); §6 non-negotiable #1 (no silent behavior — sidecars need UI distinction)
**Build matrix:** MAS limited to bookmark scope; Pro unrestricted
**Phase plan:** `04_PHASES.md` Phase 4 (gated)

**Files to touch (verified):**
- `agent_core/src/etl/mod.rs` (NEW module — NOT a separate crate)
- `agent_core/src/etl/walker.rs` (new)
- `agent_core/src/etl/hash.rs` (new)
- `agent_core/src/etl/jobs.rs` (new)
- `agent_core/src/etl/afm.rs` (new — Swift callback bridge)
- `Epistemos/Engine/ShadowVaultBootstrapper.swift` (extend existing 267 LOC)
- `Epistemos/Engine/RustEtlFFIClient.swift` (new)
- `Epistemos/Engine/AFMSidecarGenerator.swift` (new — uses existing AFMSessionPool)
- `epistemos-shadow/src/lib.rs` — 3 new FFI exports: `etl_enqueue_walk`, `etl_pause`, `etl_status`

**Cargo additions** (Apr 2026 verified pins from dossier):
```
apalis = "=1.0.0-rc.7"
apalis-sql = { version = "0.7.3", features = ["sqlite"] }
ignore = "0.4.25"
xxhash-rust = { version = "0.8.15", features = ["xxh3", "const_xxh3"] }
tokio-util = "0.7"
```

**Research mandates:**
- Read: dossier "R16 — Phase 13 ETL Rust crawler"
- Read: `~/Downloads/final v2/deep-research-report (4).md` (ETL pipelines section)
- Read: `~/Downloads/Advice/Perplexity paper.md` (architecture)
- WebFetch: https://github.com/geofmureithi/apalis (confirm `1.0.0-rc.7` API stability)

**Tests must stay green:** all existing `ShadowVaultBootstrapper*` tests

**Telemetry surface required:**
- ETL state visible in Settings → "Background Indexing" row (running/paused/stopped, files processed count)
- AFM-generated `.epistemos.json` sidecars are `xattr`-marked AND visible in the editor with a "model-derived" badge (per `02_BUILD_MATRIX.md §7`)
- ETL pause on battery surfaces in UI ("Paused — on battery")

**Definition of done:**
- [ ] Crawler walks 100k notes vault in <60 seconds (xxh3 hash + queue)
- [ ] AFM sidecar generation: <5 sec per note, throttled to one in flight
- [ ] Battery + thermal pause via `PowerGate.shouldDefer()` and IOPS APIs
- [ ] Memory pressure: `DispatchSourceMemoryPressure` `.warning` halts the crawler within 100 ms
- [ ] MAS variant: enforce security-scoped bookmark boundary (cannot escape granted scope)
- [ ] Sidecar files do NOT pollute search results unless user opts in
- [ ] `xattr -p com.epistemos.modelDerived <file>` returns "true" on every sidecar

**Notes / risks:**
- Code-file exclusion: must NOT generate sidecars for `.swift`, `.rs`, `.py`, etc.
- Cycle detection on circular symlinks.
- Sandbox: in MAS, must error gracefully if user revokes bookmark mid-run.

---

# W9-series

## W9.6 — Cost dashboard

**Phase:** 2 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §6 #1 (no silent behavior — every cloud call surfaces); §6 #5 (no silent fallback)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 2 task 2

**Files to touch (verified):**
- `agent_core/src/session_insights.rs` (already tracks `estimated_cost_usd` — add budget hook)
- `agent_core/src/agent_loop.rs` (check budget before each tool call)
- `agent_core/src/providers/pricing.rs` (NEW — pricing tables checked into source)
- `Epistemos/Views/Chat/CostDashboardView.swift` (new)
- `Epistemos/Views/Settings/BudgetSettingsSection.swift` (new)
- `Epistemos/State/BudgetPreferences.swift` (new — UserDefaults-backed)

**Research mandates:**
- Read: dossier "W9.6 — Cost dashboard + per-session budget gate"
- Read: `~/Downloads/Advice/claude advice.md` (provider pricing context)
- WebFetch: https://www.anthropic.com/pricing (verify Claude Sonnet 4.6 / Opus 4.6 prices)
- WebFetch: https://docs.perplexity.ai/guides/pricing (verify Sonar Pro)

**Tests must stay green:** existing `SessionInsightsTests`

**Telemetry surface required:**
- Cost dashboard visible in main chat surface
- Budget cap reached → uses W9.8 approval modal (do NOT silently pause)
- Cost field populated on every `SessionInsight` event

**Definition of done:**
- [ ] Provider pricing table includes Claude Sonnet 4.6, Claude Opus 4.6, Perplexity Sonar Pro, Codex, Gemini, Kimi/Moonshot, all with `last_verified_iso8601` field
- [ ] Cost ±5% accurate against provider's own usage report (integration test against real API key, gated by `EPISTEMOS_RUN_BILLING_INTEGRATION_TESTS=1`)
- [ ] Budget cap fires the W9.8 approval modal with `tool_name = "budget_gate"` and `args_json` carrying current spend + cap
- [ ] Cost data NEVER leaves the device — no telemetry to remote
- [ ] Per-month aggregate stored in app support directory (NOT Keychain — not security-sensitive)

**Notes / risks:** providers change pricing without notice — the `last_verified_iso8601` column makes drift visible.

---

## W9.7 — Vault selector

**Phase:** 2 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §1 (substrate plane — multiple vaults per model)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 2 task 5

**Files to touch (verified):**
- `Epistemos/Models/ModelVaultRegistry.swift` (already exists — verify per memory)
- `Epistemos/Views/Sidebar/VaultSelectorView.swift` (new)
- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` (already exists — extend as selector site)

**Research mandates:**
- Read: dossier "W9.7 — Vault sidebar selector"
- Read: `~/Downloads/final/Episdemo Master Architecture Brief + Claude Brainstorm Prompt.md` (vault per model context)

**Tests must stay green:** existing vault registry tests

**Telemetry surface required:** active vault visible in title bar

**Definition of done:**
- [ ] Switch vault in <100 ms (no full SwiftData container swap on every key)
- [ ] Switching the model auto-switches the vault if "linked" toggle is on (default off)
- [ ] Recents list (last 5 vaults) accessible via keyboard shortcut
- [ ] MAS path: handle gracefully if user revokes bookmark of a vault mid-session

---

## W9.8 — Approval modal

**Phase:** 2 | **Targets:** Both — REQUIRED | **Risk:** Med
**Doctrine refs:** §6 #1, #5; whole §3 (retraction needs approval surface for user-initiated retractions)
**Build matrix:** Both targets ✅ (mandatory for both)
**Phase plan:** `04_PHASES.md` Phase 2 task 1

**Files to touch (verified):**
- `agent_core/src/session.rs:208` (struct `PausedForApproval` exists ✅)
- `agent_core/src/agent_loop.rs` (verify `request_approval` call site)
- `Epistemos/Bridge/StreamingDelegate.swift` (forward pause event)
- `Epistemos/Views/Approval/ApprovalModal.swift` (new)
- `Epistemos/Views/Approval/InlineApprovalCard.swift` (new — preferred for in-app)
- `Epistemos/State/ApprovalQueue.swift` (new)

**Research mandates:**
- Read: dossier "W9.8 — Approval modal"
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (approval architecture)
- WebFetch: Anthropic's Computer Use approval flow docs

**Tests must stay green:** existing agent-loop pause tests

**Telemetry surface required:**
- Inline card in chat for in-app approvals
- System notification + modal when app backgrounded
- Audit log appended at `<session>/approvals.jsonl`
- Countdown timer visibly ticks (`deadline_secs` — pause if user reading)

**Definition of done:**
- [ ] Inline card renders mid-stream without breaking the stream
- [ ] Approval/denial dedupes by `args_json` hash within session (no re-prompt on retry)
- [ ] Auto-deny on timeout if app backgrounded (system notification, no auto-approve)
- [ ] Audit log JSONL appendable from concurrent sessions without corruption
- [ ] Pro path: shell-exec approval shows command preview deterministically generated in Rust
- [ ] MAS path: covers vault deletion, network calls to new providers, irreversible writes

---

## W9.10 — TurboQuant (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §4 (6 GB budget — alt to W9.30 KIVI)
**Build matrix:** Both targets ✅; opt-in flag
**Phase plan:** `04_PHASES.md` Phase 4 — gated

**Files to touch (verified):** same as W9.30; sibling `TurboQuantKVCache` class

**Research mandates:**
- Read: dossier "W9.10 — TurboQuant"
- Read: `~/Downloads/final v2/deep-research-report (4).md` (TurboQuant section)
- Read: `~/Downloads/final v2/compass_artifact_wf-c2d78e2f...md` (KV-quant doctrine)
- WebFetch: https://github.com/arozanov/turboquant-mlx (verify Swift port viability)
- WebFetch: TurboQuant ICLR 2026 paper

**Tests must stay green:** all MLX inference tests; W9.30 perplexity regression

**Telemetry surface required:** "KV: 3-bit TurboQuant" in `ModelAboutSheet`

**Definition of done:**
- [ ] Vendoring `arozanov/turboquant-mlx` proven over hand-port
- [ ] Perplexity regression < 0.1 vs FP16 baseline
- [ ] Memory math validated against Qwen3.5 7B at 32K context
- [ ] Mutually exclusive with KIVI — only one KV scheme active per session

**Notes / risks:** ONLY if KIVI proves insufficient on real workloads. Pick one; not both.

---

## W9.11 — Personalized embeddings (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** High (eval methodology)
**Doctrine refs:** §4 (1 ms embedding inference target)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 4

**Files to touch (verified):**
- `Epistemos/Engine/PersonalizedEmbeddingTrainer.swift` (new)
- `Epistemos/Engine/NightBrainScheduler.swift` (extend)
- `Epistemos/Engine/EmbeddingService.swift` (existing — swap in personalized model)

**Research mandates:**
- Read: dossier "W9.11 — Create ML personalized embeddings"
- Read: `~/Downloads/final v2/deep-research-report (4).md` (embeddings strategy)
- WebFetch: macOS 26 Create ML text embedding APIs

**Tests must stay green:** existing `EmbeddingService` tests; net new eval suite

**Telemetry surface required:** "Personalized model in use" badge in Settings

**Definition of done:**
- [ ] Training pipeline runs overnight without OOM on 16 GB
- [ ] Personalized model beats `bge-small-en-v1.5` on user-specific link-prediction held-out set
- [ ] Inference latency: <1 ms per 384-dim embedding
- [ ] Update cadence: nightly retraining; incremental otherwise

**Notes / risks:** eval methodology is the failure mode — if "better" cannot be proven, do NOT default to personalized.

---

## W9.12 — Orphan rediscovery (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §3 (retraction primitive complements orphan detection); §6 #1 (Night Brain digest is observable)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 4 — depends on **D8** (Night Brain) and ideally W9.27 (OpLog) for time-travel queries

**Files to touch (verified):**
- `Epistemos/Engine/NightBrainScheduler.swift` (existing — add `OrphanRediscoveryJob`)
- `Epistemos/Engine/OrphanKnowledgeRediscovery.swift` (new)
- `Epistemos/Views/DailyBriefing/OrphanRediscoverySection.swift` (new)
- `agent_core/src/recall.rs` (extend with `find_orphans()` query)

**Research mandates:**
- Read: dossier "W9.12 — Orphan Knowledge Rediscovery"
- Read: `~/Downloads/final v2/deep-research-report (4) copy 2.md` (cognitive memory features)

**Tests must stay green:** all `recall` and `NightBrain` tests

**Telemetry surface required:** orphan digest in morning briefing; click-through to source

**Definition of done:**
- [ ] Algorithm: HNSW similarity to recent activity × low link degree → score
- [ ] Confidence threshold tunable; default avoids both noise and banalities
- [ ] AFM `@Generable` produces 2-3 sentence "why this matters" annotation per surfacing
- [ ] Job respects Focus Mode (does not surface during DnD)

---

## W9.13 — Daily notes + FSRS

**Phase:** 2 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §1 (substrate — `SDPage.isJournal` already exists per memory)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 2 task 6

**Files to touch (verified):**
- `Epistemos/Views/Journal/DailyNoteView.swift` (new)
- `Epistemos/Views/Journal/JournalCalendarSidebar.swift` (new)
- `Epistemos/Engine/FSRSDecayStore.swift` (existing — add `notesDueForReview(date:)`)
- `Epistemos/Models/SDPage.swift` (existing — `isJournal` and `journalDate` already defined per memory)

**Research mandates:**
- Read: dossier "W9.13 — Daily Notes UI + FSRS surfacing"
- WebFetch: FSRS-6 algorithm spec (https://github.com/open-spaced-repetition/fsrs4anki/wiki)

**Tests must stay green:** existing FSRS tests

**Telemetry surface required:** "Today's review queue: N notes" card on daily note

**Definition of done:**
- [ ] Calendar sidebar handles 10+ years without view-tree rebuild
- [ ] FSRS due-review queue paginated by review difficulty
- [ ] Daily note auto-creates on first edit, NOT on app launch (avoids journal pollution)
- [ ] Backlinks render `[[2026-04-26]]` as journal-day node type in graph

---

## W9.14 — Block references (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** High
**Doctrine refs:** §1 (substrate plane — block IDs are graph nodes)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 4 — depends on W9.26 (rope) for cheap snapshots

**Files to touch (verified):**
- `js-editor/src/extensions/block-id.ts` (new)
- `js-editor/src/extensions/block-transclusion.ts` (new)
- `Epistemos/Sync/NoteFileStorage.swift` (existing — add block-ID metadata sidecar)
- `Epistemos/Engine/BlockReferenceIndex.swift` (new)
- `agent_core/src/storage/vault.rs` (extend with block-ref edges)

**Research mandates:**
- Read: dossier "W9.14 — Block References + Transclusion"
- Read: `~/Downloads/final v2/compass_artifact_wf-c2d78e2f...md` (block-ref doctrine)

**Tests must stay green:** all editor tests

**Telemetry surface required:** transclusion edit propagation visible in real time

**Definition of done:**
- [ ] Block IDs preserved across split/merge edits
- [ ] `((id))` renders as live transclusion (real-time edit propagation)
- [ ] Cycle detection: depth limit + DFS detection
- [ ] Storage: HTML comment `<!-- id:abc123 -->` for portability

---

## W9.15 — Routing macro (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §6 #6 (no `AnyView` in render hot paths)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 4 — gate on profiling proving the AnyView penalty matters at current view count

**Files to touch (verified):**
- New macro target in `Package.swift`
- `EpistemosMacros/RouteMacro.swift` (new)
- `Epistemos/Navigation/RouteRegistry.swift` (new)
- Refactor `Epistemos/App/RootView.swift`

**Research mandates:**
- Read: dossier "W9.15 — Static compile-time view routing macro"
- WebFetch: WWDC sessions on AttributeGraph diff cost

**Tests must stay green:** all view tests

**Telemetry surface required:** none (perf-only)

**Definition of done:**
- [ ] Profile-justified: AnyView penalty measured before macro is built
- [ ] Macro produces `route(to:) -> some View` static dispatch
- [ ] Dynamic routes (open note by ID) handled via generic association
- [ ] No regression in screen transition times

**Notes / risks:** doctrine §6 #6 already forbids AnyView on render hot paths — this macro may be redundant if discipline holds.

---

## W9.21 — Honest FFI

**Phase:** 3 | **Targets:** Both | **Risk:** Med-High
**Doctrine refs:** §1 (substrate — durable FFI invariants); §6 (no UAF, no double-free)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 3 task 1

**Files to touch (verified):**
- `epistemos-shadow/src/lib.rs:102-260` (rip global `RwLock<Option<Backend>>`; return `*const ShadowEngine`)
- `syntax-core/src/ffi.rs:60` and `:75`
- `substrate-core/src/ffi.rs:57` and `:67`
- `substrate-rt/src/lib.rs:61` and `:146`
- `graph-engine/src/lib.rs` lines 573, 585, 1521, 1548, 1870, 1983, 2062, 2095, 2435, 2448
- Swift consumers: `RustShadowFFIClient.swift`, `SyntaxCoreService.swift`, `RustEventRingClient.swift`, `KnowledgeCoreBridge.swift`, `GraphEngine.swift`, `EventStore.swift`, `EventDrain.swift`

**Concrete pattern** (verify in PR):
```rust
// epistemos-shadow/src/lib.rs
#[unsafe(no_mangle)]
pub extern "C" fn shadow_open_at(path: *const c_char) -> *const ShadowEngine {
    let backend = RealBackend::open(unsafe { c_str(path)? })?;
    Arc::into_raw(Arc::new(ShadowEngine { backend }))
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_retain(p: *const ShadowEngine) {
    if !p.is_null() { Arc::increment_strong_count(p); }
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_release(p: *const ShadowEngine) {
    if !p.is_null() { Arc::decrement_strong_count(p); }
}
```

**Research mandates:**
- Read: dossier "W9.21 — Honest FFI"
- Read: Rustonomicon § raw-pointer arithmetic + ownership
- WebFetch: https://doc.rust-lang.org/nomicon/

**Tests must stay green:** entire 2,679-test suite + new TSan stress test

**Telemetry surface required:** none (architectural)

**Definition of done:**
- [ ] Grep `Box::into_raw` returns ZERO hits in the 5 affected crates
- [ ] TSan stress run: 30 minutes of agent activity, no warnings
- [ ] miri pass on FFI test cases
- [ ] All Swift consumers use `~Copyable` handle struct OR retain/release-wrapping `final class`
- [ ] PR split: (1) shadow; (2) syntax-core + substrate-core + substrate-rt; (3) graph-engine; (4) Swift cutover

**Notes / risks:** one wrong `decrement_strong_count` is UAF. Mitigation: PR-by-PR landing with full TSan between each.

### Progress (revised 2026-04-27)

- **PR1** ✅ shipped in `dcc5521f` — `epistemos-shadow/src/honest_handle.rs` with `shadow_handle_open_at / _retain / _release / _search`. Coexists with the legacy global-state API.
- **PR2** ✅ shipped in `b2e4899d` — `substrate-rt`, `substrate-core`, `syntax-core` honest_handle modules. 12 new unit tests across the 3 crates (3+4+5), all green; full per-crate test suites green (14/14, 11/11, 47/47). All three crates have a clean Send+Sync story (substrate-rt via internal `CachePadded<Mutex<Producer/Consumer>>`; substrate-core via internal `RwLock<Inner>+RwLock<Vec<AppAction>>+RwLock<usize>`; syntax-core wrapped in `Arc<Mutex<SyntaxDocument>>` because tree-sitter::Parser is Send-not-Sync).
- **PR3** 🟡 design analysis (2026-04-27, blocking implementation):
  - `graph-engine` has 10 raw-pointer sites but only **4 are amenable to honest-handle** (`Engine` create/destroy at 573/585; `KnowledgeCore` create/destroy at 2435/2448). The other 6 sites are one-shot ownership transfers (boxed slices for search results; per-string `CString::into_raw` returns) — Box is correct, NOT honest-handle candidates.
  - `Engine` holds raw `*mut c_void` Metal device + layer pointers and is consumed via `&mut *engine` macros from Swift's main thread for rendering. Wrapping in `Arc<Mutex<Engine>>` would gate every Metal render call behind a Mutex — exactly the wrong tradeoff for the 120fps rendering hot path. The current single-thread-from-Swift contract IS the right pattern for Metal-bound state. **Defer Engine honest-handle indefinitely; document the contract instead.**
  - `KnowledgeCore` holds `SharedRingBuffer + DatalogStore + HashMap` with `&mut self` operations across 20+ FFI exports. A faithful honest-handle migration here means wrapping the entire operation FFI surface in `Mutex<KnowledgeCore>`-acquiring wrappers (~400-600 LOC of pure FFI rewrite). Doable but bigger than a contained PR. **Open question for the next session: is the per-op Mutex acquire (~100ns uncontended) acceptable on the KnowledgeCore reactive-FFI hot path? KnowledgeCore is IPC-shaped (publish/drain), so yes — but a benchmark on the existing `*mut KnowledgeCore` path would set the bar.**
- **PR4** Swift `~Copyable` consumer cutover — gated on PR3 outcome. If PR3 ships only the `KnowledgeCore` migration, PR4 cuts over `KnowledgeCoreBridge.swift`; the Swift `GraphEngine.swift` stays on the existing `*mut Engine` pattern.
- **W9.21 series provisional declaration:** the 4 honest-handle modules shipped in PR1+PR2 cover all crates where the pattern is clearly correct. `graph-engine` is the architectural outlier — its existing single-thread-from-Swift contract for Metal state IS the right pattern, and the doctrinal payoff (W9.22 Typestate Islands) does NOT depend on graph-engine being migrated. The cross-cutting rule "W9.21 must precede W9.22" is satisfied at PR2.

---

## W9.22 — Typestate Islands

**Phase:** 3 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §1 (substrate — lifecycle correctness at compile time)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 3 task 2 — **MUST** come after W9.21

**Files to touch (verified):**
- `agent_core/src/runtime/mlx_session.rs` (NEW)
- `Epistemos/Engine/AFMSessionPool.swift` (PooledSession → typestate)
- `Epistemos/Engine/MLXInferenceService.swift` (LocalMLXRequest typestate-wrapped)
- `Epistemos/Omega/Inference/MLXConstrainedGenerator.swift`
- `Epistemos/Omega/Inference/ReasoningLoopService.swift`
- `Epistemos/LocalAgent/LocalAgentLoop.swift`
- `Epistemos/Engine/LSPServerProcess.swift` (Spawned → Initialized → Serving → ShutDown)

**Concrete pattern:**
```rust
// agent_core/src/runtime/mlx_session.rs (NEW)
pub struct Loaded;  pub struct Warm;  pub struct Generating;  pub struct Disposed;
pub struct MlxSession<S> { inner: Arc<MlxInner>, _state: PhantomData<S> }
impl MlxSession<Loaded> {
    pub fn warm_up(self) -> MlxSession<Warm> { /* prefill */ self.transition() }
}
// Disposed has zero methods → calling .step() on it is a compile error.
```

**Research mandates:**
- Read: dossier "W9.22 — Typestate Islands for MLX/subprocess lifecycles"
- WebFetch: https://github.com/state-machine-future/state_machine_future
- Read: Swift Evolution SE-0437 (`~Copyable` actor compatibility)

**Tests must stay green:** entire test suite + new compile-fail tests

**Telemetry surface required:** none

**Definition of done:**
- [ ] Spike done first: `~Copyable` returning across actor boundaries — if blocked, switch `AFMSessionPool` to `final class + Mutex`
- [ ] Compile-fail tests: a commented `// EXPECTED FAIL:` test proves `step()` on `Disposed` fails to compile
- [ ] Three lifecycles wrapped: MLX, AFM session pool, LSP subprocess
- [ ] No runtime-perf regression (typestate is pure compile-time)

---

## W9.23 — Circuit breaker

**Phase:** 2 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §1 (provider plane — hot path latency)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 2 task 3

**Files to touch (verified):**
- `agent_core/src/resilience.rs` OR `agent_core/src/circuit_breaker.rs` (find / create)
- `agent_core/src/providers/claude.rs` + `perplexity.rs` (call sites)

**Research mandates:**
- Read: dossier "W9.23 — Bit-packed circuit breaker"
- WebFetch: https://docs.rs/crossbeam/latest/crossbeam/utils/struct.CachePadded.html

**Tests must stay green:** existing `circuit_breaker_tests` if present

**Telemetry surface required:** breaker state (closed/open/half-open) visible in provider status pill in UI

**Definition of done:**
- [ ] Single `AtomicU64` packs: 2 bits state, 16 bits failure count, 32 bits last-fail epoch, 14 bits generation
- [ ] Crossbeam `CachePadded` to avoid false sharing
- [ ] Per-call latency: <10 ns (vs ~50 ns for Mutex)
- [ ] No-silent-fallback rule: when breaker opens, UI shows the breaker state — system does NOT silently route to alternate provider

---

## W9.24 — Metal zero-copy (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §4 (perf budget — UMA may make this a no-op gain)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 4 — **profile first**

**Files to touch (verified):**
- `Epistemos/Engine/MetalGraphView.swift`
- `Epistemos/Engine/MetalRuntimeManager.swift`
- `agent_core/src/graph_buffers.rs` (new)

**Research mandates:**
- Read: dossier "W9.24 — Metal zero-copy graph buffers"
- WebFetch: https://developer.apple.com/documentation/metal/mtldevice/makebuffer(bytesnocopy:length:options:deallocator:)

**Tests must stay green:** all graph tests

**Telemetry surface required:** none

**Definition of done:**
- [ ] Profile demonstrates `bytesNoCopy` wins on UMA before code lands
- [ ] Lifetime: dealloc runs after `MTLCommandBuffer` completion
- [ ] Page-aligned Rust alloc via `posix_memalign(4096)`

**Notes / risks:** Apple Silicon UMA may render this a no-op. Profile is gating.

---

## W9.25 — Grammar masking

**Phase:** 1 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §6 #4 (closed catalog — grammar masking is the structural enforcement); §0 verdict (vertical slice)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 1 task 2 — **the lowest-risk Bucket A item, the worked-example task prompt**

**Files to touch (verified):**
- `project.yml` — add `mlx-swift-structured` SwiftPM dep + `MLXStructured`, `CMLXStructured`, `JSONSchema`
- `Epistemos/LocalAgent/LocalToolGrammar.swift:3-4, 7-9` — remove `canImport` guards once package linked
- `Epistemos/Omega/Inference/MLXConstrainedGenerator.swift` — replace `JSONSchemaLogitProcessor` with `GrammarMaskedLogitProcessor`; flip `isFullyConstraining = true`
- `Epistemos/Engine/MLXInferenceService.swift` — already accepts a `LogitProcessor`; just forward
- `Epistemos/LocalAgent/LocalAgentLoop.swift` — wire `structuredGenerator` so `ToolCallingPlan.backend == .mlxStructured` takes the masked path

**Research mandates:**
- Read: dossier "W9.25 — Grammar-constrained logit masking"
- Read: `~/Downloads/final v2/deep-research-report (4).md` (Structured Output section)
- Read: `~/Downloads/final/EPISTEMOS_HERMES_MANIFESTO.md`
- WebFetch: https://github.com/ml-explore/mlx-swift-structured (verify package readiness)
- Verify: `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift` `LogitProcessor` protocol still has 3 hooks (`prompt`, `process`, `didSample`)

**Tests must stay green:** all `MLXTokenIterator*Tests`, `LocalAgent*Tests`

**Telemetry surface required:**
- "Grammar masking active" indicator in `ModelAboutSheet`
- `AgentEvent.GrammarMaskApplied { schema_id, backend }` emitted on every constrained generation
- `LocalToolGrammar` falls back to `omegaSoftGuidance` ONLY with a visible UI badge — no silent fallback

**Definition of done:**
- [ ] `mlx-swift-structured` linked in both Pro + MAS targets
- [ ] `canImport` guards removed; release build compiles with `MLXStructured` available
- [ ] Tokenizer roundtrip test: Qwen 3.5 BPE + Hermes-3 vocab both produce byte-equivalent `tokens_to_string`
- [ ] All Hermes-3 tool-call plans output structurally valid `<tool_call>{...}</tool_call>` blocks (no retry loops in 100 trials)
- [ ] AFM `@Generable` schemas: validate parity between AFM and grammar-masked local emissions
- [ ] Telemetry surface visible per mandate

---

## W9.26 — B-tree rope (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** Med-High
**Doctrine refs:** §1 (substrate — note storage)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 4 — gates W9.14 + W9.27

**Files to touch (verified):**
- `Epistemos/Sync/NoteFileStorage.swift` (49,524 bytes)
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (63,934 bytes)
- `agent_core/src/rope/` (NEW module — 4-6 entry points)
- UniFFI bindings (new/insert/delete/snapshot/utf16_to_byte/byte_to_utf16)
- `Epistemos/Models/SDPage.swift` body persistence path

**Cargo addition:**
```
crop = { version = "0.4", features = ["utf16-metric"] }
```

**Research mandates:**
- Read: dossier "W9.26 — B-tree rope"
- Read: `~/Downloads/final v2/compass_artifact_wf-c2d78e2f...md` (rope doctrine)
- WebFetch: https://docs.rs/crop/latest/crop/

**Tests must stay green:** all editor tests

**Telemetry surface required:** none

**Definition of done:**
- [ ] crop with `utf16-metric` confirmed available
- [ ] Insertion/deletion <1 ms on 1 MB document
- [ ] WKWebView UTF-16 ↔ Rust UTF-8 conversion: O(log n) verified
- [ ] Single source of truth: rope authoritative, JS bundle stateless
- [ ] No cursor jumps in editor due to UTF-16 offset bugs

---

## W9.27 — Append-only OpLog (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** High (migration risk)
**Doctrine refs:** §3 (retraction propagation lives on OpLog substrate); D1 (BLAKE3 chain pairs naturally)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 4 — depends on W9.26

**Files to touch (verified):**
- `agent_core/src/storage/vault.rs` (18,259 bytes — add `oplog` module)
- `agent_core/src/storage/oplog.rs` (NEW)
- `agent_core/src/replay.rs` (NEW)
- `Epistemos/Views/Graph/MetalGraphView.swift` (subscribe to op stream)
- `Epistemos/Models/SDGraphNode.swift` + `SDGraphEdge.swift` + `SDPage.swift` (treat as projections)
- `Epistemos/Sync/VaultIndexActor.swift` (consume oplog events)
- `Epistemos/Graph/GraphState.swift`

**Research mandates:**
- Read: dossier "W9.27 — Append-only OpLog"
- Read: `~/Downloads/final v2/deep-research-report (4).md` (operation logs section)
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (provenance plane)
- WebFetch: https://github.com/automerge/automerge (compare; doctrine: hand-roll first)

**Tests must stay green:** ENTIRE existing storage suite + migration test

**Telemetry surface required:** "Time-travel: <date>" affordance in the graph view

**Definition of done:**
- [ ] Hand-rolled, NOT automerge (single-writer for now)
- [ ] Schema: `epistemos_oplog(seq INTEGER PRIMARY KEY, payload BLOB, prev_hash BLAKE3)`
- [ ] Migration: snapshot-then-replay, dry-run on copy of real vault, idempotent
- [ ] Snapshot cadence: every 1000 ops + on app shutdown
- [ ] Feature flag `EPISTEMOS_GRAPH_OPLOG=1` for opt-in rollout

**Notes / risks:** **migration is the moment user data is lost**. Do this on a real-vault dry run with verifiable forward+backward replay before merging.

---

## W9.28 — Blelloch scan (deferred research)

**Phase:** 4 | **Targets:** Both | **Risk:** High
**Doctrine refs:** §0 verdict (Mamba-2 only if on active roadmap, not research backlog)
**Build matrix:** Both targets ✅; gated
**Phase plan:** `04_PHASES.md` Phase 4 — gate on Mamba-2 roadmap activation

**Files to touch (verified):**
- `Epistemos/Shaders/Mamba2/inter_chunk_scan.metal` (existing 253 LOC)
- `Epistemos/Engine/MetalRuntimeManager.swift` (add `interChunkScanBlellochPipeline`)
- `agent_core/src/storage/ssm_state.rs`
- `EpistemosTests/Mamba2MetalRuntimeTests.swift`

**Research mandates:**
- Read: dossier "W9.28 — Blelloch scan in Metal"
- Read: `~/Downloads/final v2/deep-research-report (4) copy.md` (SSM section)
- WebFetch: Mark Harris "Parallel Prefix Sum (Scan) with CUDA" (canonical Blelloch)
- WebFetch: Kieber-Emmons "Efficient Parallel Prefix Sum in Metal" (Apple Silicon adapt)
- WebFetch: WWDC20 session 10632

**Tests must stay green:** all Mamba2 tests; numerical parity tests

**Telemetry surface required:** none

**Definition of done:**
- [ ] Replaces Phase-2 sequential scan, NOT the FPG-aware reduce-then-scan in `inter_chunk_scan.metal`
- [ ] Numerical parity vs current scan: <1e-4 abs delta in FP16
- [ ] Apple Silicon FPG quirk acknowledged in shader header

**Notes / risks:** prior Mamba/SSM attempts in the repo failed (per `WAVE_9_POLISH_AND_NATIVE.md` line 244). Ship Phase 1+2 first; Mamba-2 is research backlog.

---

## W9.29 — Thermal-aware throttle

**Phase:** 2 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §4 (perf budget); §6 #5 (no silent fallback — must NOT silently swap to smaller model)
**Build matrix:** Both targets ✅
**Phase plan:** `04_PHASES.md` Phase 2 task 4

**Files to touch (verified):**
- `Epistemos/State/ThermalMonitor.swift` (new)
- `Epistemos/Engine/MLXService.swift` (consult thermal before each inference)
- `agent_core/src/circuit_breaker.rs` (FFI in thermal signal)

**Research mandates:**
- Read: dossier "W9.29 — Thermal-aware breaker throttling"
- WebFetch: WWDC sessions on thermal management; `ProcessInfo.thermalState` docs

**Tests must stay green:** all MLX inference tests

**Telemetry surface required:**
- "Thermal: <state>" pill in main UI
- Throttle activation visible (rate limit, not model swap)

**Definition of done:**
- [ ] `ProcessInfo.thermalState` notification wired to `agent_core` breaker via UniFFI shared atomic
- [ ] Throttle = rate limit on token emission (NEVER silent model swap)
- [ ] Battery-aware: more aggressive on battery, less on AC
- [ ] Test methodology: reproducible thermal pressure via concurrent CPU load

---

## W9.30 — KIVI 2-bit KV quant

**Phase:** 1 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §4 (6 GB budget — KIVI mandatory >8K context)
**Build matrix:** Both targets ✅; opt-in flag `EPISTEMOS_KV_KIVI=1`
**Phase plan:** `04_PHASES.md` Phase 1 task 3

**Files to touch (verified):**
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift:700-951` (sibling `KIVIKVCache: QuantizedKVCacheProtocol`)
- `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/Evaluate.swift:1560` (extend `GenerateParameters` with `kvScheme: KVQuantScheme`)
- `Epistemos/Engine/MLXInferenceService.swift` (surface `LocalMLXRequest.kvScheme`)
- `Epistemos/State/InferenceState.swift`
- `Epistemos/Views/Chat/ModelAboutSheet.swift` (display "KV: 2-bit KIVI")

**Existing reference impl** (do NOT move into runtime path):
- `epistemos-core/src/instant_recall/kv_cache_quant.rs` (676 LOC) — recall layer reference

**Research mandates:**
- Read: dossier "W9.30 — KIVI per-channel/per-token KV quantisation"
- Read: `~/Downloads/final v2/deep-research-report (4).md` (KIVI section, ~99-103)
- Read: `~/Downloads/final v2/compass_artifact_wf-c2d78e2f...md` (KV-quant doctrine)
- WebFetch: KIVI paper https://arxiv.org/abs/2402.02750
- Verify file: `RotatingKVCache.toQuantized` `fatalError` (do NOT combine sliding window + KIVI in v1)

**Tests must stay green:** all `MLXTokenIterator*Tests`

**Telemetry surface required:**
- `ModelAboutSheet` displays "KV: 2-bit KIVI" when active
- `SessionInsight.kv_scheme` field populated
- AgentEvent emitted on first quantization in a session

**Definition of done:**
- [ ] `KIVIKVCache` implemented as sibling, K per-channel + V per-token
- [ ] `GenerateParameters.kvScheme` enum: `.affine` (default) | `.kivi` (opt-in) | `.turboQuantV4V2` (future, W9.10)
- [ ] Tokenizer-state and prompt-cache files (`savePromptCache` / `loadPromptCache`, KVCache.swift line 1168) include `KIVIKVCache` in dispatch table
- [ ] Perplexity regression test on Qwen3.5 7B held-out prompts: <0.1 absolute delta vs FP16 baseline
- [ ] If perplexity gate fails, flag stays opt-in only — no default activation
- [ ] Memory math validated: ~58 MB at 8K vs ~448 MB FP16

**Notes / risks:** swap-in replacement affects every inference. Mitigation: `EPISTEMOS_KV_KIVI=1` opt-in first; perplexity gate before default flip.

---

# D-series (doctrine-emergent)

## D1 — BLAKE3 Merkle-chained RunEventLog

**Phase:** 1 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §3 (retraction propagation needs cryptographic chain); §1 (substrate plane)
**Build matrix:** Both targets ✅ (substrate-level, not target-gated)
**Phase plan:** Phase 1 prerequisite — must exist before W9.25 ReplayBundle export demo lands

**Files to touch:**
- `agent_core/src/provenance/run_event_log.rs` (NEW)
- `agent_core/src/provenance/blake3_chain.rs` (NEW)
- `agent_core/src/storage/vault.rs` (extend `commit_envelope` with chain link)
- `epistemos-core/Cargo.toml` (`blake3 = "1.5"`)

**Research mandates:**
- Read: `~/Downloads/final v2/compass_artifact_wf-c2d78e2f...md` (BLAKE3 Merkle chain section)
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (provenance plane)
- WebFetch: https://docs.rs/blake3/latest/blake3/

**Tests must stay green:** all storage tests; net new chain integrity tests

**Telemetry surface required:** chain hash visible in session insights / replay bundle manifest

**Definition of done:**
- [ ] Every `MutationEnvelope` carries `prev_hash: [u8; 32]` and is hashed into `next_hash`
- [ ] Chain stored as a new GRDB table: `provenance_chain(seq INTEGER PRIMARY KEY, prev_hash BLOB, next_hash BLOB, envelope_id BLOB)`
- [ ] `epistemos-trace verify` validates the entire chain on a `.epbundle`
- [ ] Tampering with any envelope makes the chain detectably invalid

---

## D2 — 7-verb MCP graph boundary

**Phase:** 1 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §1 (substrate plane exposes graph verbs); §5.1 (open standard exposes the same surface)
**Build matrix:** Both targets ✅; MAS limited to in-process clients
**Phase plan:** Phase 1 — required for Hermes provider invocation in vertical slice

**The 7 verbs:**
1. `search_semantic(query, top_k)` — HNSW vector recall
2. `search_fulltext(query, top_k)` — tantivy BM25
3. `get_node(id)` — by ULID
4. `traverse(from_id, edge_filter, depth)` — graph walk
5. `create_node(typed_node)` — typed insertion
6. `create_edge(from_id, to_id, kind)` — typed relation
7. `commit_session(envelope)` — atomic transaction with retraction propagation + BLAKE3 link

**Files to touch:**
- `omega-mcp/src/dispatcher.rs` (existing — verify the 7 verbs)
- `omega-mcp/src/catalog.rs` (existing)
- `omega-mcp/src/vault.rs` (existing)
- New binary: `epistemos-hermes-mcp` (Pro target only) — exposes the 7 verbs over STDIO for Hermes

**Research mandates:**
- Read: `~/Downloads/final v2/Epistemos Hackathon_ Deep Research Plan.txt` (MCP boundary section)
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt`
- WebFetch: MCP 2025-11-25 spec https://modelcontextprotocol.io/specification/

**Tests must stay green:** all `omega-mcp` tests

**Telemetry surface required:** every MCP verb invocation emits AgentEvent

**Definition of done:**
- [ ] All 7 verbs exposed via MCP tools with schemars-derived JSON schemas
- [ ] `epistemos-hermes-mcp` binary builds in Pro target
- [ ] Hermes session round-trips: `search_semantic` → `traverse` → `create_node` → `commit_session` works end-to-end with telemetry
- [ ] Schema fidelity: tools advertise types matching Rust signatures exactly

---

## D3 — Closed A2UI catalog

**Phase:** 1 (initial) → 2 (expansion) | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §6 #4 (no fallback inspector); §2.3 (closed catalog ruling)
**Build matrix:** Both targets ✅
**Phase plan:** Phase 1 (`NoteCard` only) → Phase 2 (full ~25 components)

**Initial Phase 1 set (1 component):**
- `NoteCard` — renders a Claim with evidence + retraction status

**Phase 2 expansion set (target ~25):**
- `ToolCallCard`, `ThinkingTrace`, `ApprovalDialog`, `EvidenceTable`, `AuditFindingCard`, `ReplayTimeline`, `GraphPulseEvent`, `Scratchpad`, `Planner`, `TodoList`, `ClaimCard`, `RetractionBadge`, `ProviderRunCard`, `BudgetGauge`, `KvSchemeIndicator`, `ThermalIndicator`, `MorningBriefing`, `OrphanRediscoveryCard`, plus ~7 more as scoped

**Files to touch:**
- `Epistemos/A2UI/Catalog.swift` (NEW — closed enum)
- `Epistemos/A2UI/Validator.swift` (NEW — schemars-validated emissions)
- `Epistemos/A2UI/Components/NoteCard.swift` (Phase 1)
- `agent_core/src/a2ui/schemas.rs` (NEW — schemars-derived schemas)

**Research mandates:**
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (A2UI protocol)
- Read: `~/Downloads/final v2/Epistemos Hackathon_ Deep Research Plan.txt` (A2UI v0.9)
- WebFetch: A2UI v0.9 envelope shape `[UNVERIFIED]` — verify or mark unverified

**Tests must stay green:** all UI tests

**Telemetry surface required:** validation failures emit `AuditFinding` (no silent rejection)

**Definition of done:**
- [ ] Catalog is a Swift enum — no `AnyView`, no fallback case
- [ ] Unknown schema → `A2UIValidationFailure` audit finding (visible in audit log)
- [ ] schemars-derived schemas exported as part of the open standard's published JSON Schemas
- [ ] No `AnyView` in any component — verified by lint rule

---

## D4 — Faculty roster lock-in

**Phase:** 1 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §4 (6 GB budget; faculty roster baked in)
**Build matrix:** Both targets ✅; some models Pro-only if they require subprocess
**Phase plan:** Phase 1 — model selection committed before grammar masking lands

**The roster (16 GB Mac realistic budget):**
| Role | Model | RAM | Notes |
|---|---|---|---|
| Primary | `Hermes-3-Llama-3.1-8B-4bit` (MLX) | ~3.5 GB | The flagship local model |
| Drafter (W9.x — D10) | `Llama-3.2-1B-4bit` (MLX) | ~700 MB | Speculative decoding partner |
| Embeddings | `bge-small-en-v1.5` (Core ML / MLX) | ~100 MB | 384-dim |
| Utility | Apple Foundation Models (3B, AFM) | ~0 MB resident | Neural Engine; macOS 26+ |

**Total resident:** ~4.3 GB (Hermes 3.5 + bge 0.1 + AFM 0 + drafter only when speculative active 0.7) — leaves ~1.7 GB for KV cache + GRDB + UI in the 6 GB realtime budget.

**Files to touch:**
- `Epistemos/Engine/ModelCatalog.swift` (NEW or existing — lock the roster)
- `Epistemos/Models/ModelProfile.swift` (existing)
- `agent_core/src/providers/local_mlx.rs` (existing — verify model IDs match)

**Research mandates:**
- Read: `~/Downloads/final v2/compass_artifact_wf-c2d78e2f...md` (faculty roster section, exec verdict)
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (hardware realism)
- WebFetch: HuggingFace model cards for Hermes-3-Llama-3.1-8B-4bit, Llama-3.2-1B-4bit, bge-small-en-v1.5
- WebFetch: Apple Foundation Models docs (`@Generable` API surface, macOS 26+)

**Tests must stay green:** all model-load tests

**Telemetry surface required:** `ModelAboutSheet` shows the active roster

**Definition of done:**
- [ ] Roster locked in `ModelCatalog`
- [ ] Memory math verified empirically: load all 4, measure resident
- [ ] Eviction-on-load policy: only one chat-primary at a time; bge always loaded; AFM zero-cost
- [ ] No 30B+ models offered in UI (per dossier "memes on this device")

---

## D5 — Substrate durability discipline

**Phase:** 0/1 | **Targets:** Both | **Risk:** Low
**Doctrine refs:** §1 (substrate plane); §6 (no silent corruption)
**Build matrix:** Both targets ✅
**Phase plan:** Phase 0 audit + Phase 1 enforcement

**The discipline:**
- GRDB SQLite in **WAL mode** (already standard).
- **`F_FULLFSYNC`** on every transaction commit (verify it's actually wired — dossier mentions it but verify).
- **`DenseSlotMap` generational arena** for entity lifecycles in `substrate-core` Rust crate.
- **No corruption tolerance**: a corrupt commit aborts the session and surfaces an error.

**Files to touch:**
- `agent_core/src/storage/vault.rs` (verify F_FULLFSYNC wiring)
- `substrate-core/src/lib.rs` (verify DenseSlotMap usage)
- New audit test: `provenance_durability_tests`

**Research mandates:**
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (durability discipline)
- WebFetch: https://www.sqlite.org/wal.html
- WebFetch: https://docs.rs/slotmap/latest/slotmap/

**Tests must stay green:** all storage tests

**Telemetry surface required:** corruption detection raises a visible error (no silent recovery)

**Definition of done:**
- [ ] `PRAGMA journal_mode = WAL` verified on every connection
- [ ] `fcntl(F_FULLFSYNC)` on each commit (Apple's strongest fsync) — verified via `ktrace` audit
- [ ] DenseSlotMap usage grep verified
- [ ] Crash-injection test: kill -9 mid-commit, restart, verify integrity
- [ ] Provenance chain (D1) detects any tampered state

---

## D6 — Hierarchical concept extraction (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** High (requires solid AFM @Generable patterns)
**Doctrine refs:** §3 (substrate gains structure); §4 (AFM as utility)
**Build matrix:** Both targets ✅
**Phase plan:** Phase 4

**The feature:**
- AFM `@Generable` extracts hierarchical concepts: e.g., "basal ganglia" nested under "neuroscience" nested under "biology"
- Replaces flat tags / "garbage nouns and verbs"
- Edges in the substrate include `:kindOf`, `:partOf`, `:exemplarOf`

**Files to touch:**
- `Epistemos/Engine/HierarchicalConceptExtractor.swift` (new)
- `agent_core/src/cognition/ontology.rs` (new)
- `agent_core/src/storage/vault.rs` (new edge kinds)

**Research mandates:**
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (hierarchical concepts section)
- Read: `~/Downloads/final v2/deep-research-report (4) copy 2.md` (cognitive features)

**Tests must stay green:** all storage + cognition tests

**Telemetry surface required:** concept hierarchy visible in graph view; user can correct mis-extractions

**Definition of done:**
- [ ] AFM `@Generable` schema for `Concept { name, parent_name, kind }`
- [ ] Idempotent extraction: re-running on same note doesn't duplicate
- [ ] User can correct hierarchy; corrections persist as Claims with `Evidence`
- [ ] Hierarchy visible in graph view as nested clusters

---

## D7 — FSRS-6 + raw-thought decay (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §3 (retraction primitive — decay is a soft retraction); §4 (memory metabolism)
**Build matrix:** Both targets ✅
**Phase plan:** Phase 4

**The feature:**
- FSRS-6 epoch decay on retrieval weight (NOT deletion — never delete)
- Raw-thought nodes decay faster than committed notes
- Decay affects retrieval ranking in HNSW + BM25 fusion (RRF re-weighting)

**Files to touch:**
- `Epistemos/Engine/FSRSDecayStore.swift` (existing — extend for raw-thought nodes)
- `agent_core/src/storage/vault.rs` (decay weight column)
- `agent_core/src/recall.rs` (decay-aware ranking)

**Research mandates:**
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (memory metabolism)
- Read: `~/Downloads/final v2/deep-research-report (4) copy 2.md`
- WebFetch: FSRS-6 spec

**Tests must stay green:** all recall tests

**Telemetry surface required:** decay state visible per-node in inspector

**Definition of done:**
- [ ] `decay_weight` field on every node, updated nightly
- [ ] HNSW recall pre-multiplies by decay weight
- [ ] User can "freshen" a node (reset decay) explicitly
- [ ] Decay never deletes; only down-weights

---

## D8 — Night Brain + Morning Consolidation (deferred)

**Phase:** 4 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §3 (retraction propagation runs nightly across the graph); §4 (background jobs yield under pressure)
**Build matrix:** Both targets ✅; MAS in bookmark scope
**Phase plan:** Phase 4 — depends on D6, D7, W9.27

**The feature:**
- Nightly job consolidates raw thoughts → notes via AFM @Generable summarization
- Identifies orphans (W9.12 dependency)
- Recomputes hierarchical concept graph (D6)
- Re-runs decay (D7)
- Generates morning digest

**Files to touch:**
- `Epistemos/Engine/NightBrainScheduler.swift` (existing — extend)
- `Epistemos/Engine/MorningConsolidation.swift` (new)
- `Epistemos/Views/DailyBriefing/MorningBriefingView.swift` (new — A2UI component)

**Research mandates:**
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (Night Brain section)
- Read: `~/Downloads/final v2/deep-research-report (4) copy 2.md`

**Tests must stay green:** all NightBrain + scheduler tests

**Telemetry surface required:** morning briefing surfaced; what was consolidated visible

**Definition of done:**
- [ ] Job runs only when on AC + thermal nominal + memory pressure normal
- [ ] Resume after interruption: `NightBrainState` JSON checkpoint
- [ ] Morning briefing renders as an A2UI `MorningBriefing` component
- [ ] User can disable per-feature (consolidation, decay, hierarchical re-extract)

---

## D9 — Skills as graph nodes

**Phase:** 2 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §1 (substrate — Hermes' file-backed skills get rerouted into graph); §2.2 (Hermes-as-provider)
**Build matrix:** Both targets ✅; Hermes ACP local subprocess Pro-only (per `02_BUILD_MATRIX.md`)
**Phase plan:** Phase 2

**The feature:**
- Hermes' skills system writes to flat markdown by default. Intercept and reroute to graph nodes via MCP `create_node(type: Skill)`.
- Two-phase: graph canonical body + `SKILL.md` mirror for compatibility.

**Files to touch:**
- `omega-mcp/src/skills.rs` (new — intercepts Hermes skill writes)
- `agent_core/src/storage/vault.rs` (new node type `Skill`)
- `Epistemos/Views/Faculty/HermesLanding*` (existing — surface skills as nodes)

**Research mandates:**
- Read: `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` (Hermes faculty section)
- Read: `~/Downloads/final v2/Epistemos Hackathon_ Deep Research Plan.txt`

**Tests must stay green:** all MCP and Hermes-related tests

**Telemetry surface required:** every skill creation visible as `AgentEvent.SkillCreated`

**Definition of done:**
- [ ] Skill node type in substrate
- [ ] MCP intercept replaces filesystem writes for `~/.hermes/skills/`
- [ ] `SKILL.md` mirror written for compatibility (graph is canonical)
- [ ] Skills surface in graph view as nodes; clicking opens execution context

---

## D10 — Speculative decoding (deferred research)

**Phase:** 4 | **Targets:** Both | **Risk:** Med
**Doctrine refs:** §4 (faculty roster includes drafter); 150 tok/sec target
**Build matrix:** Both targets ✅
**Phase plan:** Phase 4 — perf optimization gated on profiling

**The feature:**
- Use `Llama-3.2-1B-4bit` as draft model speculative-decoding `Hermes-3-Llama-3.1-8B-4bit`
- Target: 150 tok/sec sustained on M2 Pro 16 GB

**Files to touch:**
- `LocalPackages/mlx-swift-lm/...` — speculative decoding entry points (verify)
- `Epistemos/Engine/MLXInferenceService.swift`

**Research mandates:**
- Read: `~/Downloads/final v2/compass_artifact_wf-c2d78e2f...md` (faculty roster + speculative)
- WebFetch: speculative decoding paper (DeepMind 2023) https://arxiv.org/abs/2302.01318
- WebFetch: mlx-swift-lm speculative decoding API surface (verify exists)

**Tests must stay green:** all MLX tests

**Telemetry surface required:** "Speculative decoding active" badge; tok/sec measurement

**Definition of done:**
- [ ] Tok/sec measured before/after; gain documented
- [ ] Quality unchanged (output exactly equivalent or accept-rate ≥ 60%)
- [ ] Drafter model RAM cost ~700 MB; only loaded when speculative active

---

## D11 — `epistemos-trace` CLI (parallel track)

**Phase:** Parallel — Phase 1+ | **Targets:** Open standard (separate distribution) | **Risk:** Med
**Doctrine refs:** §5 (open Provenance Standard)
**Build matrix:** Not bundled with either app target
**Phase plan:** `04_PHASES.md` — Open Provenance Standard parallel track

**The deliverable:** A standalone CLI binary in the open `epistemos-provenance-standard` repo with four verbs (verify, replay, lint, diff).

**Files to touch (in the new open repo, NOT the app repo):**
- `epistemos-trace/Cargo.toml`
- `epistemos-trace/src/main.rs`
- `epistemos-trace/src/verify.rs`
- `epistemos-trace/src/replay.rs`
- `epistemos-trace/src/lint.rs`
- `epistemos-trace/src/diff.rs`

**Research mandates:**
- Read: `01_DOCTRINE.md §5` (the Open Provenance Standard)
- Read: `~/Downloads/Advice/claudy research.md` (CLI design references)

**Tests must stay green:** N/A (new project)

**Telemetry surface required:** CLI exit codes documented; stderr for diagnostics; stdout for machine-readable output

**Definition of done:**
- [ ] `epistemos-trace verify <bundle.epbundle>` exits 0/1 + diagnostic output
- [ ] `epistemos-trace replay <bundle>` produces byte-equivalent state hash on two machines
- [ ] `epistemos-trace lint <bundle>` catches: dangling references, dependency cycles, schema-version skew
- [ ] `epistemos-trace diff <a> <b>` semantic graph delta
- [ ] Distributed via Homebrew tap + GitHub releases

---

## D12 — BoltFFI investigation (UNVERIFIED)

**Phase:** 4 (research only) | **Targets:** Both (if proven) | **Risk:** [UNVERIFIED]
**Doctrine refs:** §1 (substrate plane — perf-critical FFI)
**Build matrix:** Investigative; do NOT migrate before verification
**Phase plan:** Phase 4 — research investigation only

**The claim** (from `~/Downloads/final v2/App Moats, AI Integration, and Master Plan.txt` and `~/Downloads/final v2/Epistemos Hackathon_ Deep Research Plan.txt`):
- BoltFFI generates zero-copy bindings; primitives passed as raw values; complex structures via shared memory pointers
- Microbenchmarks claim: empty function call <1 ns BoltFFI vs >1400 ns UniFFI (1000× speedup)
- 10k-element struct array: ~62 µs BoltFFI vs ~12.8 ms UniFFI

**Status: `[UNVERIFIED]`**
- Crate not located via standard registry search
- May be project-specific, vendor-private, or not yet published
- Numbers are extraordinary and require independent benchmark replication

**Research mandates (do NOT integrate without these):**
- WebSearch: "BoltFFI Swift Rust" / "BoltFFI crate"
- WebSearch: any benchmark replications by independent parties
- WebSearch: any GitHub repo named `boltffi`, `bolt-ffi`, or similar
- If found: read the source, verify the safety story (lifetime, soundness)
- If not found within 1 hour of investigation: mark `[UNVERIFIED, NOT FOUND]` and shelve

**Tests must stay green:** N/A (investigative)

**Telemetry surface required:** N/A

**Definition of done (research-only — no code lands):**
- [ ] Existence verified or marked unfound
- [ ] If verified: independent benchmark replication of the 1000× claim
- [ ] If verified: soundness audit (`miri`, `cargo-careful`) on the bindings
- [ ] If verified: a written migration plan for `epistemos-shadow` (the most FFI-heavy crate) is drafted as a separate W-item
- [ ] If unverified: this entry is updated to "abandoned" with a one-line summary

**Notes / risks:** the existing UniFFI 0.29.5 path (R14) is the baseline. Do NOT attempt BoltFFI migration without verification; the claimed numbers are too good to act on without proof.

---

# Cross-reference table

| Phase | Items |
|---|---|
| 0 | (A+_RELEASE_ROADMAP — see `04_PHASES.md`) |
| 1 | R14, W9.25, W9.30, D1, D2, D3 (initial), D4, D5 |
| 2 | R15, W9.6, W9.7, W9.8, W9.13, W9.23, W9.29, D3 (expansion), D9 |
| 3 | W9.21, W9.22 |
| 4 | R16, W9.10, W9.11, W9.12, W9.14, W9.15, W9.24, W9.26, W9.27, W9.28, D6, D7, D8, D10, D12 |
| Parallel | D11 (open standard CLI; aligned to Phase 1+); **N1 (Prompt Tree)** |

---

# N-series

## N1 Phase 1 — Cache telemetry follow-up

**Status:** ⚠️ blocked on substrate discovery (2026-04-27)

The Phase 1 follow-up to N1 (wire `cached_tokens_share` into the W9.6 cost
dashboard via `SessionInsight`) was attempted in this session and surfaced a
**substrate problem** that needs to be fixed before this PR can land:

- `agent_core/src/session_insights.rs` (655 LOC) is an **orphan source file** —
  it defines `SessionMetrics` + `AggregatedStats` + `SessionMetricsFFI` +
  `InsightsReportFFI` with `#[derive(uniffi::Record)]` and a complete test
  suite (12 `#[test]` functions), but **is not declared in `agent_core/src/lib.rs`**.
  Verified via `grep -rn 'session_insights' agent_core/src/` → only matches
  inside the file itself.
- Consequence: nothing in `agent_core` compiles this file. The
  `#[derive(uniffi::Record)]` proc-macro never runs against these types. The
  Swift side that supposedly consumes `SessionMetricsFFI` per
  `Epistemos/State/EventStore.swift:261` is reading a different struct
  (probably `ReasoningTrajectoryMetricsFFI` per the trajectory-metrics path
  in `ChatCoordinator.swift:2316`).
- The file was added in commit `465a3c30` ("Complete Hermes parity
  provider-chain and session persistence work") and never wired in.

**Fix required before N1 Phase 1 can ship:**

1. Decide whether `session_insights.rs` is the canonical destination for cache
   telemetry OR whether the existing `ReasoningTrajectoryMetricsFFI` path
   (already wired Rust↔Swift via `result.trajectoryMetrics` and
   `EventStore.saveSessionMetrics`) is the right anchor.
2. If `session_insights.rs` is the right home: add `pub mod session_insights;`
   to `agent_core/src/lib.rs`, fix any latent compile errors revealed by
   actually building it, and only THEN extend it with `cache_read_input_tokens`
   + `cached_tokens_share`.
3. If `ReasoningTrajectoryMetricsFFI` is the right anchor: extend that struct
   instead and trace the Swift side back to the W9.6 dashboard.

**No code shipped this session for N1 Phase 1** — the verification gate
(running the new tests via `cargo test`) caught that the source file isn't in
the build. Per `00_AUTHORITY_AND_ANTI_DRIFT.md §4.7` WRV gate, attempting to
ship into an orphan file would itself be the failure mode the gate exists to
prevent.

---

## N1 — Prompt Tree (JSPF + PTF) + StructureRegistry-driven prompt composer

**Phase:** parallel | **Targets:** Both | **Risk:** Med

**Doctrine refs:** §6 #1 (no silent behavior — every prompt audit-able), §6 #14 (no orphan scaffolding — N1 ships with one fully-wired call site or it doesn't ship), §2.5 (cognition layer = one substrate with read-only projections), §6 #5 (no silent fallback — every prompt the agent sends has a typed, registered shape)

**Build matrix:** Both targets. The composer + renderer are pure Swift; cache-control hints are Anthropic-specific but degrade silently for providers without prompt caching (OpenAI Responses API, AFM, MLX local — none of which support Anthropic's `cache_control`).

**Phase plan:** `04_PHASES.md` parallel track (lands when one Builder session has bandwidth; doesn't block any Phase 0–3 deliverable).

### Concept

Two formats, one composer:

**JSPF (JSON-Schema Prompt Format)** — a typed `Prompt` value (`Codable + Sendable + Hashable`) with the canonical fields:

```swift
struct Prompt: Codable, Sendable, Hashable {
    var version: Int                       // schema version (start at 1)
    var id: String                         // stable id; doubles as cache key
    var identity: IdentitySection?         // system role / persona
    var tools: [ToolSpec]                  // available tools (subset of full registry)
    var memory: MemorySection?             // recent chats, relevant notes, ontology refs
    var task: TaskSection                  // the active ask
    var constraints: [ConstraintSection]   // hard rules, capability gates
    var output_schema: OutputSchema?       // expected response shape (links to StructureRegistry)
    var cache_hints: CacheHints            // which subtrees are stable enough to cache
}
```

**PTF (Prompt Tree Format)** — the same data laid out as a directory:

```
<vault>/.epistemos/prompts/<session>/<turn>/
  ├── identity.json        — stable per session (cacheable)
  ├── tools.json           — stable per session (cacheable)
  ├── memory/
  │   ├── recent_chats.json  — churns turn-by-turn
  │   ├── relevant_notes.json
  │   └── ontology.json    — stable per vault (cacheable)
  ├── task.json            — churns per turn
  ├── constraints.json     — stable per session (cacheable)
  └── output_schema.json   — stable per task type (cacheable)
```

The PTF is the on-disk projection of the JSPF. The user (and the local LLM via MCP) can browse the tree, swap individual files, and see exactly what shape was sent on every turn.

### Why this matters

1. **Token savings via prompt caching.** Anthropic's prompt cache (≥1024 tokens, 5-minute TTL) gives 90 % off on cached portions. Mark identity + tools + ontology + constraints + output_schema as cacheable; only memory.recent_chats + task churn turn-by-turn. Realistic savings: 60-80 % of input tokens on agent loops with stable identity.
2. **Composability.** Subtrees compose deterministically. Building a "summarize this note" prompt = identity (vault-scoped) + tools (none) + task (note ref) + output_schema (Summary). Tools rarely change; identity rarely changes; only task is fresh.
3. **Auditability.** Every prompt sent is on disk; users + audit agents can inspect exact shape.
4. **Pre-flight validation.** Composer checks against `StructureRegistry` so unknown output schemas fail at compose time, not at parse time.
5. **Test isolation.** Subtrees are unit-testable independently.

### Files to touch (verified)

NEW Swift files:
- `Epistemos/Engine/PromptTree.swift` — typed `Prompt` + `PromptNode` enum + `PromptComposer`
- `Epistemos/Engine/PromptRenderer.swift` — render to Anthropic Messages / OpenAI Responses / AFM `@Generable` / MLX local-grammar formats
- `Epistemos/Engine/PromptCache.swift` — Anthropic `cache_control` hint generator + per-provider degradation
- `Epistemos/Engine/PromptTreePersister.swift` — serialize PTF to `<vault>/.epistemos/prompts/<session>/<turn>/`

EXISTING files to wire (the WRV anchor):
- `Epistemos/App/ChatCoordinator.swift` — first agent turn must use the composer end-to-end (so this doesn't ship as scaffolding)
- `Epistemos/Engine/StructureRegistry.swift` — extend with prompt-shape descriptors so the composer can validate against it

NEW doc:
- `docs/PROMPT_AS_DATA_SPEC.md` — format spec, extension rules, provider compat matrix

### Research mandates

- Anthropic prompt cache docs: https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching (verify 90 % discount + 5-min TTL + 1024-token minimum + breakpoint semantics — current as of Apr 2026)
- Read existing prompt-assembly call sites in `agent_core/src/agent_loop.rs`, `Epistemos/App/ChatCoordinator.swift` (the system that gets replaced)
- Read `Epistemos/Engine/StructureRegistry.swift` (this file) — N1 extends it with prompt shapes
- Read `docs/STRUCTURING_AUDIT.md` — every input that becomes a prompt section maps to one of the audit rows

### Tests must stay green

- All existing chat / agent loop tests
- New `PromptTreeTests` covering: composition, schema validation against StructureRegistry, cache-hint generation, per-provider rendering, PTF round-trip (compose → persist → parse → render → identical)

### Telemetry surface required

- A "Prompt shape" inspector in the Trace Inspector view (DEBUG only initially) showing the rendered tree for the most recent turn
- A counter in `SessionInsight` for cached-token-share so the user can see prompt-cache hit rate
- The PTF directory itself is browsable from Finder (each turn is a folder; raw JSON files inside)

### Definition of done

- [ ] `Prompt` + `PromptNode` types in `PromptTree.swift` with full Codable + Hashable conformance
- [ ] `PromptComposer.compose(...)` produces a typed `Prompt` from inputs
- [ ] `PromptRenderer` renders identical `Prompt` to Anthropic Messages, OpenAI Responses, AFM `@Generable`, and MLX local-grammar formats; round-trips preserve semantics
- [ ] `PromptCache.hints(for: Prompt)` returns `cache_control` markers for the top-N stable subtrees, capped at Anthropic's 4-breakpoint limit
- [ ] PTF persistence writes to `<vault>/.epistemos/prompts/<session>/<turn>/` and round-trips cleanly
- [ ] **WRV proof**: `ChatCoordinator` first agent turn uses the composer end-to-end. Verifiable via `Grep` for `PromptComposer.compose` in `ChatCoordinator.swift`. User-visible: cached-token-share counter in session insights surfaces a real (>0 %) hit rate after the second turn of any session.
- [ ] `StructureRegistry` extended with at least 4 prompt-shape entries (identity, tools, task, output_schema) so the catalog reflects the new schemas
- [ ] `docs/PROMPT_AS_DATA_SPEC.md` written; format spec + extension rules + provider compat matrix
- [ ] No legacy prompt-assembly path is removed in this PR — both paths coexist behind a feature flag (`EPISTEMOS_PROMPT_TREE=1` or a Settings toggle) until the ChatCoordinator wire is battle-tested
- [ ] Unit tests pass; build green on both MAS and Pro targets

### Notes / risks

- **Provider differences are real.** AFM `@Generable` is its own thing (Swift macros, not JSON over HTTP). MLX local has no prompt-cache concept. The renderer must treat each provider as its own degraded surface — never assume a feature.
- **PTF on disk is non-trivial.** Per-turn directories add inode pressure on long sessions. Cap at N most recent turns + GC older ones via NightBrain.
- **Don't over-cache.** Anthropic's cache is 5-min TTL; if your "stable" subtree changes every 6 minutes you pay the write cost without getting the read benefit. Composer must measure cache-hit rate and degrade hints if hit rate < 30 %.
- **WRV is the reason this lands or doesn't.** If the foundation ships without ChatCoordinator wiring, kill the PR. This item exists specifically to combat the orphan-scaffold pattern; it must walk the talk.
- **Reuses StructureRegistry pattern**: every prompt schema gets a registry entry so the local LLM can ask "what shapes do you send?"

---

## Last updated

2026-04-27 — Added N-series. N1 (Prompt Tree / JSPF + PTF + StructureRegistry composer)
locked into the plan as a parallel-track item. Ready-to-paste prompt at
`docs/plan/prompts/N1_prompt_tree.md`.

2026-04-26 — Initial creation. 21 W/R items + 12 D items mapped with research refs,
files-to-touch, telemetry mandates, and definition-of-done gates. Final v2 research
incorporated. BoltFFI flagged `[UNVERIFIED]`.
