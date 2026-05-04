# 04 — Phases: Sequencing with Entry/Exit Gates

**Authority:** Subordinate to `01_DOCTRINE.md` and `02_BUILD_MATRIX.md`. Governs the
order in which work happens.

**Cadence target:** ~6 months from Phase 0 start to Phase 4 completion at solo
pace, with parallel open-standard track running from Phase 1 onward.

---

## Phase architecture overview

```
Time →

Phase 0 ────► Phase 1 ────► Phase 2 ────► Phase 3 ────► Phase 4
ship          vertical      horizontal    hardening     deferred
blockers      slice         UX            (Honest FFI)  research-grade
(1 week)      (2 weeks)     (3 weeks)     (4 weeks)     (open-ended)

         ┌──────────────────────────────────────────────────┐
         │   Parallel track: Open Provenance Standard       │
         │   - Schemas extracted as types stabilize         │
         │   - epistemos-trace CLI authored alongside       │
         │   - Reference providers built from Phase 2 on    │
         │   - Public launch coincides with Hermes          │
         │     hackathon submission (≤ May 4, 2026)         │
         └──────────────────────────────────────────────────┘
```

The parallel track is not optional. It runs from Phase 1 because the schemas it
publishes are the same schemas Phase 1's vertical slice produces. Delaying the
track means publishing schemas after they've drifted — the moat doesn't hold.

---

## Phase 0 — Ship blockers (1 week, P0)

**Goal:** ship the existing app. The dossier and architecture work has run ahead of
shipping; close that gap.

**Source of truth:** `/A+_RELEASE_ROADMAP.md` (in Epistemos repo root).

**Tasks:**

1. Exclude MOHAWK training data (47 MB) from `Copy Bundle Resources`.
2. Toggle `ShipGate.agentsEnabled = false` in `AppBootstrap.swift:22`.
3. Enable `SHIP_MODE=release` in build script. Verify per-crate exclusions.
4. Fix `runAgentSession` stub at `StreamingDelegate.swift:64-73`. Wire to
   `AgentViewModel.shared.runCloudAgent(...)` OR remove the call site if cloud is
   not in the v1 release scope.
5. Move embedding FFI off `MainActor` — replace with serial queue
   (`EmbeddingService.swift:218-225`). Eliminates 50–100 ms UI freeze.
6. CVDisplayLink background thread (`MetalGraphView.swift:692`). Eliminates graph
   stutter.
7. `@Query` debouncer in `NoteChatState`. Prevents AI streaming from cascading
   refetches.

**Entry criteria:**
- The doctrine docs (`docs/plan/00`–`05`) are written and reviewed.
- Test suite floor (2,679 tests) is green on `main`.
- `xcodebuild` produces a passing build of both targets.

**Exit criteria:**
- All 7 tasks complete with verification greps passing.
- App bundle <200 MB.
- Smoke test: open large vault, pan graph at 60 fps, AI streaming does not stutter.
- `AGENT_PROGRESS.md` updated with date + per-task completion line.
- A clean tag on `main`: `v1.0.0-pre-phase1` (no push to remote without explicit
  user approval).

**Risks:**
- Discovering that `SHIP_MODE=release` Cargo build has an undocumented dep.
  Mitigation: dry-run the release build before flipping defaults.
- Excluding `Omega/` (43 files) breaks an import. Mitigation: build twice — once
  with `Omega/` excluded, once with it included; diff for the missing symbol.

**Estimated effort:** ~50 LOC across 7 files. 1 person-week, comfortable.

---

## Phase 1 — Vertical slice (2 weeks)

**Goal:** prove the doctrine spine works end-to-end with one provable improvement
to one user-visible surface. Validate the hot/cold split, retraction primitive,
and no-silent-behavior contract on real code.

**Tasks (Bucket A from the dossier):**

1. **R14 — UniFFI 0.28 → 0.29.5 + Sendable patches.** Hygiene only — do NOT sell
   internally as the rebuild-perf win. The SwiftPM target separation (#2818) is
   not in 0.29.5; that benefit doesn't land. Add the `nonisolated` annotation pass
   to `patch-uniffi-bindings.py`. ~50 LOC handwritten + ~5K regenerated.
2. **W9.25 — Grammar masking (mlx-swift-structured).** Link the package in
   `project.yml`, remove `canImport` guards in `LocalToolGrammar.swift:3-4` and
   `:7-9`, flip `isFullyConstraining` to true in `MLXConstrainedGenerator.swift`.
   Tokenizer parity test (Qwen 3.5 BPE round-trip).
3. **W9.30 — KIVI 2-bit KV quant (opt-in flag).** Sibling class to existing
   `QuantizedKVCache` at `LocalPackages/mlx-swift-lm/Libraries/MLXLMCommon/KVCache.swift:700-951`.
   Activated via `EPISTEMOS_KV_KIVI=1` only. Perplexity regression test on Qwen
   3.5 7B is the gating artifact, not the code. UI: "KV: 2-bit KIVI" indicator in
   `ModelAboutSheet`.
4. **First retraction primitive landing.** Implement `commit_envelope()` with
   retraction propagation in `agent_core/src/provenance/ledger.rs` (new module).
   Deliberately scoped: only one Claim type and one Evidence type — enough to prove
   the substrate works. Subsequent items extend the type set.
5. **First A2UI surface render.** `NoteCard` component renders a Claim with its
   evidence list and current retraction status. Validates the closed-catalog rule.
6. **First ReplayBundle export.** A button in the chat surface emits a `.epbundle`
   for a completed run. `epistemos-trace verify` (Phase-1 milestone of the parallel
   track) consumes it and exits 0.

**Entry criteria:**
- Phase 0 exit criteria met.
- The 4 plane boundaries from `01_DOCTRINE.md §1` have placeholder modules in
  `agent_core/`. The first ledger commit must compile against real types.

**Exit criteria:**
- All 6 tasks complete.
- New tests: at least 3 unit tests for retraction propagation (direct retraction,
  transitive retraction at depth 1, cycle detection rejection); 2 tests for
  ReplayBundle byte-equivalence.
- Existing test floor (2,679) still green.
- Demo: from a fresh session, run a Hermes provider invocation, see live
  `AgentEvent`s in the UI, see the resulting Claim rendered as `NoteCard`,
  manually retract a piece of evidence, watch the dependent Claim flip to
  `AT_RISK` in real time.
- KIVI perplexity regression test: less than 0.1 perplexity delta on a held-out
  prompt set vs FP16 baseline; otherwise the flag stays `EPISTEMOS_KV_KIVI=1`
  opt-in only.
- Documentation: `docs/plan/03_EXECUTION_MAP.md` per-item entries marked `done`.

**Risks:**
- Tokenizer mismatch between Qwen 3.5 BPE and Hermes-3 vocab causes grammar
  masking to misfire. Mitigation: roundtrip test in CI.
- KV-quant regression on user's specific corpus. Mitigation: opt-in flag stays
  off by default until perplexity gate passes.
- Retraction propagation depth>16 on dense Claim graphs. Mitigation: bounded
  walk policy already in `01_DOCTRINE.md §3.3`.

**Estimated effort:** ~3K LOC. 2 person-weeks at solo pace.

---

## Phase 2 — Horizontal expansion (3 weeks)

**Goal:** widen the spine. Multiple A2UI components, multiple provider runs in
flight, the approval contract enforced everywhere. The product becomes usable for
real work.

**Tasks:**

1. **W9.8 — Approval modal.** Inline card for in-app approvals; system notification
   fallback for backgrounded app. Audit log to `<session>/approvals.jsonl`.
   Required for both MAS and Pro per `02_BUILD_MATRIX.md §7`.
2. **W9.6 — Cost dashboard + per-session budget gate.** Reuse W9.8 modal as the
   gate UX. Pricing tables checked into source (`agent_core/src/providers/pricing.rs`).
3. **W9.23 — Bit-packed AtomicU64 circuit breaker.** Replaces `RwLock<...>` in the
   provider hot path. ~5 ns vs ~50 ns for Mutex. Crossbeam `CachePadded` for
   false-sharing avoidance.
4. **W9.29 — Thermal-aware throttle.** Pairs with W9.23. `ProcessInfo.thermalState`
   notifications. Back-pressure mechanism: rate-limit token emission, do NOT
   silently swap to a smaller model (no-silent-fallback rule).
5. **W9.7 — Vault selector (model-vault registry).** Sidebar UI that switches
   between per-model vaults. SwiftUI 6.2 `EnvironmentValues` for the active vault
   handle.
6. **W9.13 — Daily notes UI + FSRS surfacing.** Calendar sidebar +
   `notesDueForReview(date:)` query against the existing FSRSDecayStore.
7. **More A2UI components.** `ToolCallCard`, `ThinkingTrace`, `ApprovalDialog`,
   `EvidenceTable`, `AuditFindingCard`. Each component schemars-derived, each
   added with a dedicated test that exercises the closed-catalog validator.
8. **More provider implementations.** Bring up Claude API, Perplexity, AFM
   `@Generable` providers behind the unified `Provider` trait.

**Entry criteria:**
- Phase 1 exit criteria met.
- The retraction primitive has run successfully on at least one round-trip
  Hermes session.
- The first `ReplayBundle` export has been validated by `epistemos-trace`.

**Exit criteria:**
- 8 tasks complete.
- The approval contract is unbroken: every irreversible action in either target
  surfaces W9.8 modal.
- Cost dashboard accurately tracks at least 2 cloud providers (verify against
  provider's own usage report; tolerance ±5%).
- Circuit breaker proves out under fault injection — provider A is forced to fail,
  the breaker opens, the user sees the breaker state in the UI, the system does
  NOT silently route to provider B without surfacing.
- Test floor + new tests: at least 25 net new tests across the 8 tasks.

**Risks:**
- Provider API drift between when the pricing table was checked in and when the
  user runs against current prices. Mitigation: monthly verification ritual; the
  pricing table includes a `last_verified` ISO 8601 stamp.
- Cost dashboard shows wrong numbers because the provider sends usage in a new
  field. Mitigation: a tolerance-bound integration test that hits the provider
  with a tiny prompt and reconciles against the provider's own usage report.
- Approval modal fires too often, training the user to dismiss without reading.
  Mitigation: dedupe by `args_json` hash within a session per `01_DOCTRINE.md`.

**Estimated effort:** ~8K LOC. 3 person-weeks.

---

## Phase 3 — Hardening (4 weeks)

**Goal:** make the substrate unbreakable. Honest FFI + Typestate Islands + the
remaining sandbox machinery.

**Tasks:**

1. **W9.21 — Honest FFI.** Five Rust crates rewritten to `Arc::into_raw` +
   `~Copyable` Swift wrappers: `epistemos-shadow`, `syntax-core`, `substrate-core`,
   `substrate-rt`, `graph-engine`. ~1100 LOC + ~12 files. Ship as 4 PRs:
   (a) `epistemos-shadow` headline; (b) `syntax-core` + `substrate-core` +
   `substrate-rt`; (c) `graph-engine`; (d) Swift `~Copyable` consumer cutover.
2. **W9.22 — Typestate Islands.** MUST come after W9.21. Spike actor-vs-class
   compatibility for `~Copyable`-returning methods first. ~650 LOC. Three
   typestate lifecycles: MLX session, Hermes subprocess (Pro), AFM session pool.
3. **Sandbox tier C wiring (Pro).** `bollard 0.19` ephemeral container provider.
   Per-session approval. `--network=none` enforced.
4. **Sandbox tier D wiring (Pro).** `portable-pty 0.9` + `rexpect 0.6` host shell
   provider. Per-command approval.
5. **Per-target Cargo features finalized.** `agent_core`'s `mas` and `pro`
   features cleanly partition the codebase. CI builds both.
6. **Performance pass.** Swift 6.2 `.defaultIsolation(MainActor.self)` on the UI
   target; nonisolated Rust-bridge target. `AsyncThrowingStream` cancellation
   propagation: `withTaskCancellationHandler` → UniFFI `cancel_all` → tokio
   `CancellationToken` cascade → `child.kill` on subprocess.

**Entry criteria:**
- Phase 2 exit criteria met.
- The system has been used on real work for at least 1 week with no UAF or
  ownership-related crashes.

**Exit criteria:**
- TSan stress run is clean for 30 minutes of agent activity.
- The 5 Rust crates' FFI surfaces are uniform: no raw `Box::into_raw` paths
  remain (grep gates this).
- Typestate compile-time guarantees: a static test (commented `// EXPECTED FAIL:`)
  proves calling `step()` on `Disposed` is a compile error.
- Pro target builds with all 4 sandbox tiers; MAS target builds with only A+B.
- CI runs both targets per PR.

**Risks:**
- W9.21 misuse: a single wrong `decrement_strong_count` is UAF. Mitigation: TSan
  CI run; miri (where applicable); 30-minute stress test gate.
- Typestate + actor isolation pain in Swift 6.2. Mitigation: spike first; if
  `~Copyable` cannot return across actor boundaries, switch to `final class +
  Mutex<...>` per the dossier note.

**Estimated effort:** ~3K LOC across 5 crates + Swift consumers. 4 person-weeks.

---

## Phase 4 — Deferred (research-grade, gate on user need)

**Goal:** items that survive doctrine but require either substantial scope or
research that doesn't pay off until evidence demands it.

**Tasks (gated, not all required):**

- **W9.10 — TurboQuant KV quant.** ONLY if KIVI proves insufficient on real user
  workloads. Vendor `arozanov/turboquant-mlx` rather than hand-port the paper.
- **W9.11 — Personalized embeddings (Create ML).** Only if BM25 + HNSW recall
  proves insufficient at scale. Eval methodology nontrivial.
- **W9.12 — Orphan rediscovery (Night Brain digest).** Depends on W9.27 OpLog.
- **W9.14 — Block references / transclusion.** Depends on W9.26 rope.
- **W9.15 — Routing macro.** Only if AnyView profiling proves it's the bottleneck
  on real screens (the doctrine forbids AnyView on render hot paths anyway, so
  this may be redundant).
- **W9.24 — Metal zero-copy buffers.** Profile UMA first; may be a no-op gain on
  Apple Silicon.
- **W9.26 — B-tree rope.** Required if and when documents > 100 KB lag
  noticeably.
- **W9.27 — Append-only OpLog.** Required for time-travel debugging and
  multi-device sync. Migration risk demands its own session.
- **W9.28 — Blelloch scan in Metal for Mamba-2.** Gate on Mamba-2 being on the
  active roadmap, not just research backlog.
- **R16 — ETL crawler.** Defer until vault-as-context is a real feature. Until
  then, on-demand AFM sidecars in the editor are sufficient.

**Entry criteria for any item:**
- Phase 3 exit criteria met.
- Profiling or user feedback identifies the item as the next leverage point.
- Item is added to the active sprint with a written justification.

**Exit criteria:** per-item, per the corresponding entry in `03_EXECUTION_MAP.md`.

**Risks:** premature investment. Each item in this phase has a sibling that's
deferred for the same reason — most users will never need them. Don't pre-build.

---

## Parallel Track — Open Provenance Standard

**Owner:** runs alongside Phases 1–4. Same engineer. Different repo.

**Phase-aligned milestones:**

| Stage | Aligned with | Deliverable |
|---|---|---|
| Standard skeleton | Phase 1 | `epistemos-provenance` crate skeleton + JSON Schema export from real types. `epistemos-trace verify` minimal viable. |
| Conformance suite | Phase 2 | First version of `epistemos-conformance` test fixtures. Hermes reference provider passes. |
| Public launch | Hermes hackathon (≤ May 4, 2026) | Repo public. Apache 2.0 license. README + spec site. Demo: native app emits `.epbundle`, `epistemos-trace verify` exits 0 on stage. |
| Reference providers | Phase 3 | `epistemos-provider-claude-code`, `-codex`, `-gemini`, `-openhands`. Each passes its conformance run. |
| Distribution | Continuous | Homebrew tap for `epistemos-trace`. crates.io for crates. PyPI + npm for SDKs. |

**Constraints:**
- Schemas in the open standard MUST be byte-equivalent to the schemars output of
  the closed app's types. Drift is the failure mode.
- The closed app uses these crates as Cargo dependencies — never forks them
  internally.
- License conflicts: open standard is Apache 2.0; native app uses crates that may
  have other licenses. Audit at every release.

**Risks:**
- Schemas drift between open repo and closed app. Mitigation: a CI job in the
  closed app runs `cargo metadata` against the open standard's published version
  on every PR.
- Hackathon submission slips and the launch ritual gets compromised. Mitigation:
  the standard repo can launch independently of the app demo. They are decoupled
  enough that one can ship without the other.

---

## Sequencing rules (non-negotiable)

These dependencies are hard. Do NOT attempt to parallelize across them:

1. **W9.21 → W9.22.** Honest FFI before Typestate (typestate wraps the new handles).
2. **W9.26 → W9.27.** Rope before OpLog (oplog wants O(1) snapshots).
3. **W9.26 → W9.14.** Rope before block references.
4. **W9.27 → W9.12.** OpLog before orphan rediscovery (time-travel queries).
5. **R14 is independent.** Bumps any time, but coordinates with W9.21 since both
   touch FFI.
6. **W9.30 KIVI before W9.10 TurboQuant.** Pick one substrate; only swap to
   TurboQuant if KIVI is insufficient.
7. **Phase 0 ships before any Phase 1 task starts.** No exceptions. Shipping the
   existing app is the prerequisite for further work.

---

## Last updated

2026-04-26 — Initial creation. Phase 0–4 with parallel open-standard track.
