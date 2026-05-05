# Canonical Upgrade Audit — 2026-05-05

> **Question answered:** "What TRUE canonical upgrades could meaningfully
> strengthen the canon if we did them now?" Distinct from "what's left in
> the plan" — this is the ground-truth gap list between current code and
> what doctrine/CD-001..CD-009 actually demand.
>
> **Method:** read the canonical chain (CLAUDE.md → CODEX_CANONICAL_DRIFT_AUDIT
> → SUBSTRATE_V2_FINAL_CLOSEOUT → CODEX_VERIFICATION_HANDOFF →
> POST_RECOVERY_SUBSTRATE_V2_PLAN → COGNITIVE_DAG_DOCTRINE §1-§10 →
> COGNITIVE_KERNEL_DOCTRINE §11 → MAS_FIRST_FOCUS_DOCTRINE §3.1) and verify
> against current source. Findings ranked by canonical impact, not effort.
>
> **Honest assessment up front.** The substrate is in much better shape than
> the doctrine drift register suggests. Hermes removal is clean; Sovereign
> single-owner gate is clean; subprocess hardening is wide; LSP semantic path
> exists; capability-bound put_edge enforcement landed. The remaining
> upgrades cluster into three real themes: (1) **CI gates that exist as code
> but don't run**, (2) **Phase 8 prerequisites the doctrine §10 authority
> flip needs**, (3) **Pro→Core MAS-unlock work the kernel doctrine §5/§6
> describes but Phase 2/3/4 never actually shipped**. Everything else is
> grade-B polish.

---

## Verdict by category

| Cat | Theme | Open count | Net canonical weight |
|---|---|---|---|
| A | Doctrine-required-but-not-shipped | 7 | **HIGH** (8.H authority flip blockers + §5/§6 MAS unlocks) |
| B | Verification gate misses (code exists, not run) | 4 | **HIGH** (cheap; high signal) |
| C | Hardening / quality polish | 5 | MED |
| D | Test coverage gaps | 2 | MED |
| E | Cross-language consistency | 1 | LOW (already healthy) |
| F | Build / CI matrix | 4 | **HIGH** (cheap; high signal) |
| G | Documentation drift | 2 | LOW |

---

## A — Doctrine-required-but-not-shipped

### A1. Persistent DAG storage backend (`redb`) — DAG doctrine §1.3

- **What.** `cognitive_dag::storage::InMemoryDagStore` is the only impl;
  `cognitive_dag_store()` (dispatch.rs:45) is a `OnceLock<InMemoryDagStore>`.
  Doctrine §1.3 names `redb` as the recommended backend ("ACID, mmap-friendly,
  recommended for App Group container compat"). Today's DAG state is wiped
  on every process restart — replay bundles can verify session merkle
  roots, but the live DAG can't reload prior sessions, so cross-session
  cascading truth + git-bisect-cognition are aspirational.
- **Where.** `agent_core/src/cognitive_dag/storage.rs`,
  `agent_core/src/cognitive_dag/dispatch.rs:45`, `agent_core/Cargo.toml`
  (no `redb`/`sled` dep yet).
- **Effort.** 4-6 days (add dep, write `RedbDagStore: DagStore`, wire
  vault-rooted file path through bridge.rs, migration tests).
- **Canonical priority.** **Must-do for V2.1 8.H authority flip.** Without
  persistence the §10 acceptance bar ("two consecutive weeks of CI green
  with mirrors writing on every legacy write") is meaningless — every
  restart resets the mirror state.
- **Dependencies.** Coordinates with TEMP-FREE-TIER (no App Group) — store
  goes under `URL.applicationSupportDirectory/cognitive-dag.redb`, not the
  group container. Documented restoration path in MAS-First §4.5.2.
- **Risk.** Adds ~800 KB to `libagent_core.dylib`; perf budget is 16 MB so
  slack exists. Schema migration v0→v1 must round-trip through tests.

### A2. Real capability-bound `put_edge` verification (CD-005 follow-through)

- **What.** Today's `register_capability` + `verify_edge_against_registered_caps`
  (storage.rs:172) is real, but `dispatch.rs:62` registers ONE sentinel cap
  (`[0xE5; 32]`) that every auto-dispatch site reuses. So in production, "edge
  signature verification" reduces to "is the sig the sentinel pattern?" — a
  structural check, not a capability check. Per doctrine §1.2 + CD-005, every
  edge must bind to the *issuing* macaroon, not a system-wide constant.
- **Where.** `agent_core/src/cognitive_dag/dispatch.rs:76-78`,
  `agent_core/src/cognitive_dag/macaroons.rs` (full Macaroon::issue / verify
  / restrict / delegate exists but is never called outside its own tests).
- **Effort.** 2-3 weeks. Wire macaroon issuance through SovereignGate session
  start; thread the live macaroon hash into each `on_*_committed` dispatch
  path; rewrite `cognitive_dag_store()` initializer to register caps as they
  arrive instead of pre-registering the sentinel.
- **Canonical priority.** **Must-do for V2.1 8.H authority flip.** This is
  CD-005 from the drift register; doctrine §10 authority cannot flip while
  signature verification is sentinel-pattern-only.
- **Dependencies.** SovereignGate macaroon issuance handshake (Sovereign-side
  Phase 8.C wiring); macaroon root key persistence (Keychain).
- **Risk.** Edges already in the in-memory DAG would fail verification under
  the stricter rule. Migration: keep the sentinel as one of N accepted caps
  during the first week; deprecate after.

### A3. Auto-invoke dispatch coverage gaps (CD-006)

- **What.** Per CD-006: today's auto-dispatch fires from `commit_evidence`,
  `commit_claim`, `record_outcome`, `SkillRouter::load`. Missing call sites:
  - **Companion registration** — `cognitive_dag::companions::CompanionRegistry`
    writes Companion + Deforms edges natively, but the lifecycle layer
    above (Swift `CompanionState`, agent loop companion-swap events) doesn't
    fire `on_companion_registered`. The dispatch helper exists; the call
    site doesn't.
  - **Self-evolution events** — `agent_runtime::self_evolution` produces
    `SkillEvolutionCandidate` but never dispatches to a `SkillsMirror::Update`
    or a new `EvolutionMirror`. When self-evolution promotes a skill, the
    DAG should record a Skill node + an `Invokes`-derived subgraph + an Event
    with provenance back to the source procedures.
  - **ReplayBundle commit/import** — `to_epbundle_bytes` / `from_epbundle_bytes`
    exist but no dispatch fires when a session is exported or replayed.
    Doctrine §6 #1: "Every conversation is a DAG traversal trace" → import
    should add edges; export should fire an Event.
  - **Skill mutation events** — SkillRouter mutations beyond initial load
    (skill update / skill delete via Sovereign Gate) don't dispatch.
- **Where.** `agent_core/src/cognitive_dag/companions.rs`,
  `agent_core/src/agent_runtime/self_evolution.rs`,
  `agent_core/src/provenance/replay.rs`,
  `agent_core/src/skill_router.rs`.
- **Effort.** 1 week per missing dispatch site (4 weeks total) — pattern
  established by the existing 4 dispatches.
- **Canonical priority.** **Must-do for V2.1 8.H authority flip.** CD-006
  is named as an unverified blocker; doctrine §10's "two weeks CI green
  with mirrors writing on EVERY legacy write" demands full coverage.
- **Dependencies.** A2 (real capability binding) — otherwise these new
  dispatches will all use the sentinel too.
- **Risk.** Each new dispatch site is a potential test breakage if the
  legacy writers race. Pattern is fire-and-forget per existing sites.

### A4. WASM exec runtime — kernel doctrine §5 (the big MAS unlock)

- **What.** Kernel doctrine §5 is explicit: "wasmtime + Pyodide-WASM in-process
  with `com.apple.security.cs.allow-jit`" is the path that brings code execution
  into MAS. The doctrine declares it the largest Pro→Core migration in the
  matrix. Today: zero hits for `wasmtime`, `wasm_runtime`, or `exec_wasm` in
  agent_core. The native subprocess path (`tools/code_execution.rs`) still
  exists and is Pro-gated, but the MAS replacement was never written.
- **Where.** Doctrine reference: `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`
  §5.2 + §5.5. Implementation site (would-be):
  `agent_core/src/exec/wasm_runtime.rs` (does not exist).
- **Effort.** 3-4 weeks (wasmtime crate integration + Pyodide bundling +
  resource limits + entitlement audit + tool registration). Bundle weight
  +16 MB per doctrine §5.3.
- **Canonical priority.** Nice-to-have for V2.1 8.H, but **must-do for the
  Pro→Core migration matrix** the kernel doctrine §7 enumerates. Without
  this, "Code execution — Python user snippets / JavaScript user snippets /
  generic WASM modules" stay Pro-only forever.
- **Dependencies.** None hard; resource limits coordinate with the existing
  `harden_cli_subprocess` discipline (analogous limits via `wasmtime::ResourceLimiter`).
- **Risk.** JIT entitlement is a moderate App Review escalation; doctrine
  §5.4 already documented Option B (interpreter-mode fallback) for the
  defensive path.

### A5. In-process bundled MCP — kernel doctrine §6

- **What.** Doctrine §6.2 prescribes `omega-mcp/src/inproc/{vault_ops, search,
  fetch, think, todo, calc}.rs` so bundled MCPs run in-process; subprocess
  MCP path moves behind `cfg(feature = "pro-build")` for user-installed
  servers only. Today: `omega-mcp/src/` has no `inproc/` module; vault_ops /
  search / fetch / think / todo / calc are present as standalone files
  (`vault.rs`, `graph_tools.rs`, etc.) but the dispatcher pattern doesn't
  distinguish bundled-inproc from external-subprocess.
- **Where.** `omega-mcp/src/dispatcher.rs`, `omega-mcp/src/transport.rs`.
  Reference: kernel doctrine §6.2.
- **Effort.** 2-3 weeks (refactor existing handlers into `inproc/` module
  shape; add per-server dispatch decision in dispatcher).
- **Canonical priority.** **Must-do for the Pro→Core migration matrix.**
  Without this, bundled MCP servers technically run as subprocess on the
  MAS path too — App Sandbox blocks that, so today they probably bypass
  the dispatcher entirely. Verify behavior under the MAS-build target.
- **Dependencies.** Coordinates with A4 (WASM) — some MCP handlers may
  delegate to WASM exec for sandboxed user code.
- **Risk.** Refactor scope; existing tests against `dispatcher.rs` need to
  prove the inproc path is byte-equivalent to the subprocess path it
  replaces.

### A6. Hermes-in-Rust kernel — kernel doctrine §4 (Layer 5)

- **What.** Doctrine §4 enumerates 5 modules to land under
  `agent_core/src/hermes/` (prompt_format, function_call, skills,
  procedural_memory, self_evolution). Reality: `agent_core/src/agent_runtime/`
  contains `procedural_memory.rs` + `self_evolution.rs` + `function_call.rs`
  + `skills.rs` (via SkillRouter), so most of the work is done — just under
  a different module name. **The doctrine name is `agent_core::hermes`;
  the actual module is `agent_core::agent_runtime`.** Per CLAUDE.md, the
  Hermes prefix is reserved for Hermes-3 model format, not the subprocess.
  Document the doctrine→reality mapping or rename one to match.
- **Where.** `agent_core/src/agent_runtime/` (modules) vs doctrine
  `agent_core::hermes::*` (kernel doctrine §4 + §11 Layer 5).
- **Effort.** 1 day (documentation reconciliation) OR 2 weeks (full module
  rename).
- **Canonical priority.** Cosmetic if documented; high-readability if
  renamed. Doctrine vocabulary should track code vocabulary.
- **Dependencies.** None.
- **Risk.** Module rename touches every import site in agent_core;
  documentation reconciliation is zero-risk.

### A7. Five-XPC-service decomposition — XPC Mastery Doctrine §1.4

- **What.** XPC Mastery Doctrine §1.4 prescribes 5 services: Main + Vault +
  Agent + Provider + WASM. Today: `XPCServices/AgentXPC/` and
  `XPCServices/ProviderXPC/` exist as 2-file skeletons (`AgentService.swift`
  has one method that returns a parsed command envelope; ProviderXPC has
  `ProviderServiceStreamingProtocol` per V2.4 first slice). Vault, WASMExec
  not started. V2.4 production deployment is gated on $99/yr Apple
  Developer Program.
- **Where.** `XPCServices/`, `Epistemos/Bridge/ProviderServiceStreamingProtocol.swift`.
- **Effort.** 3-5 weeks for Vault + WASMExec skeletons; production deployment
  gated on paid team.
- **Canonical priority.** Per MAS-First §4.5.2: "every Hermes XPC service
  authored during the MAS-first sprint MUST pass data via XPC messages."
  Skeletons are required canonical optionality; production wiring is
  paid-team-gated.
- **Dependencies.** Paid Apple Developer Program for cross-target signing;
  A4 (WASM runtime) for WASMExec service.
- **Risk.** Free-tier signing limits prevent end-to-end test today; ship
  skeleton + mock per the V2.4 first-slice pattern.

---

## B — Verification gate misses (code exists, not enforced)

### B1. `epistemos-doctrine-lint` is shipped but never invoked

- **What.** `agent_core/src/bin/epistemos_doctrine_lint.rs` is a complete CI
  binary covering DAG doctrine §5.1-§5.4. It compiles, has its own test suite,
  and exits with typed exit codes. **Zero references in `.github/workflows/`,
  `scripts/`, `build-*.sh`, or `Epistemos.xcodeproj`.** A doctrine lint that
  doesn't run is just documentation.
- **Where.** `agent_core/src/bin/epistemos_doctrine_lint.rs`,
  `.github/workflows/ci.yml` (would-be invocation).
- **Effort.** 1 hour. Add 5 lines to `ci.yml` after the agent_core build:
  `cargo run --bin epistemos-doctrine-lint -- $GITHUB_WORKSPACE` and gate
  on exit code 0.
- **Canonical priority.** **Must-do for V2.1 8.H authority flip.** Doctrine §5
  is the verification spec; the linter is the only mechanical enforcer.
- **Dependencies.** None.
- **Risk.** Currently passing all 4 gates; adding to CI catches future drift.

### B2. `epistemos-trace verify-replay` is shipped but never invoked

- **What.** `agent_core/src/bin/epistemos_trace.rs` `verify-replay`
  subcommand exists with 5 typed exit codes (Phase 8.F deliverable). No
  build script, no CI step, no release-time gate calls it. Replay
  verification is foundational to the doctrine §6 #1 "verifiable replay"
  promise.
- **Where.** `agent_core/src/bin/epistemos_trace.rs`,
  `agent_core/src/provenance/replay.rs`. CI: `.github/workflows/ci.yml`.
- **Effort.** 2-3 hours. Add a CI step that builds a sample bundle in a
  test fixture (or pulls one from `tests/`) and runs `verify-replay` on it.
- **Canonical priority.** **Must-do for V2.1 8.H authority flip.** Doctrine
  §10 verification gate; without a release-time gate the "verifiable replay"
  capability has no enforced contract.
- **Dependencies.** A sample `.epbundle` fixture in `agent_core/tests/`.
- **Risk.** None — read-only verification.

### B3. Pro-build CI matrix coverage

- **What.** `.github/workflows/ci.yml` runs `cargo build` and `cargo test`
  with default features (= mas-build). The Pro feature surface
  (`cli_passthrough`, terminal, apple_apps, imessage, browser, etc.) is
  never compiled in CI. Per MAS-First §3.1: "CI must run BOTH" the MAS
  + Pro build invocations.
- **Where.** `.github/workflows/ci.yml`.
- **Effort.** 1-2 hours. Add a parallel job (or matrix entry) running
  `cargo build --no-default-features --features pro-build` + `cargo test
  --no-default-features --features pro-build,research`.
- **Canonical priority.** **Must-do** per the doctrine §3.1 verbatim
  requirement.
- **Dependencies.** None.
- **Risk.** Pro-only code may have stale compile errors from the active
  mas-first work; first run will surface them. That's the point.

### B4. `lsp-runtime` feature CI coverage

- **What.** `build-agent-core.sh` enables the `lsp-runtime` feature for
  both MAS + Pro Xcode builds. CI's `cargo build` invocation skips this
  feature (it would need `--features mas-build,lsp-runtime`). So the
  V2.3 LSP semantic path is built once for Xcode and never directly
  cargo-tested. Codex's verification log does run it; `ci.yml` does not.
- **Where.** `.github/workflows/ci.yml:60-77`, `build-agent-core.sh:23-27`.
- **Effort.** 1 hour. Add `--features lsp-runtime` to the test invocation.
- **Canonical priority.** Codex addendum 2026-05-05 explicitly notes Codex
  ran this; CI should match.
- **Dependencies.** None.
- **Risk.** None — already passing in Codex's local run.

---

## C — Hardening / quality polish

### C1. `dispatch.rs` should use `tracing::warn!`, not `eprintln!`

- **What.** `cognitive_dag/dispatch.rs` uses `eprintln!` for mirror failures
  with the comment "avoid pulling a tracing dep just for the mirror sites."
  But `tracing = "0.1"` is already a workspace dep (Cargo.toml:112) and
  used elsewhere (e.g., `tools/registry.rs`). Switch the 4 sites for
  observability parity (sampling, structured filtering, log levels).
- **Where.** `agent_core/src/cognitive_dag/dispatch.rs:84,107,144,194`.
- **Effort.** 30 min.
- **Canonical priority.** Nice-to-have. Improves diagnostic clarity when
  doctrine §10 mirrors start firing under production load.
- **Dependencies.** None.
- **Risk.** None.

### C2. `provenance_ledger()` Mutex → RwLock for read-heavy paths

- **What.** `bridge.rs:2891` exposes the global ClaimLedger behind
  `Mutex<ClaimLedger>`. Halo ledger ribbon polls every 1Hz; Settings →
  Diagnostics polls every 5s; FFI snapshot reads (`provenance_recent`,
  `provenance_subscribe`) are all reads. Writes are infrequent
  (`commit_evidence`, `commit_claim`). RwLock would let multiple readers
  proceed without serializing through the writer.
- **Where.** `agent_core/src/bridge.rs:2891-2974`,
  `agent_core/src/provenance/ledger.rs`.
- **Effort.** 1-2 hours.
- **Canonical priority.** Cosmetic for current load; matters if Halo +
  Settings + FFI subscribers all run simultaneously under heavy agent
  traffic.
- **Dependencies.** Verify ClaimLedger's internal mutators are
  &mut-bounded so RwLock<W> writes are still single-threaded.
- **Risk.** Low.

### C3. Workspace-level `[lints]` deny on production paths

- **What.** Only 5 files have `#![cfg_attr(not(test), deny(clippy::unwrap_used,
  clippy::expect_used, clippy::panic))]` (the two CLIs + provenance ledger +
  replay + lsp_runtime). The rest of agent_core uses `unwrap_or_default()`
  173 times — not all are wrong, but the discipline is per-file rather than
  workspace-wide. Cargo `[lints.clippy]` workspace section would let agent_core
  declare `unwrap_used = "warn"` (then upgrade to "deny" file-by-file).
- **Where.** `agent_core/Cargo.toml`, `Cargo.toml` (workspace root).
- **Effort.** 30 min for warn-level baseline; weeks for full deny migration.
- **Canonical priority.** Nice-to-have. CLAUDE.md "No try!, no force-unwraps,
  no print() in production paths" is currently per-file enforced.
- **Dependencies.** None.
- **Risk.** Many `unwrap_or_default()` calls are correct (default-on-missing
  semantics); blanket deny would be wrong without per-call review.

### C4. Default trait impl for `register_capability` invites silent skip

- **What.** `DagStore::register_capability` has a default no-op trait impl
  (storage.rs:77-79) "so non-capability-aware DagStore implementations
  remain valid." This means a future redb-backed store that forgets to
  override would silently accept any signature. Doctrine §1.2 wants
  capability binding to be a load-bearing invariant, not opt-in.
- **Where.** `agent_core/src/cognitive_dag/storage.rs:77-79`.
- **Effort.** 1 hour. Make the trait method required (no default) and add
  it to InMemoryDagStore + any future backend.
- **Canonical priority.** **Must-do for V2.1 8.H authority flip** when A1
  (redb backend) lands — otherwise the new backend would silently skip
  capability checks.
- **Dependencies.** A1.
- **Risk.** None today (only InMemoryDagStore exists); becomes load-bearing
  with A1.

### C5. Sentinel-only signature audit view

- **What.** Per dispatch.rs comment, the `0xE5` sentinel is "searchable
  across the codebase, structurally distinct from `0x00` and `0xFF` so
  dispatch-emitted edges can be filtered by signature for audit views." The
  audit view doesn't exist. A `dag_edges_by_signature(sig: &Hash)` FFI helper
  + a Settings → Diagnostics row showing "system-mirror edges N / capability-
  bound edges M" would make the dispatch coverage gap (A2/A3) observable.
- **Where.** Settings → Diagnostics (Swift side), bridge.rs FFI surface.
- **Effort.** 4-6 hours.
- **Canonical priority.** Useful for the §10 two-week CI green window — lets
  you see when capability coverage hits 100%.
- **Dependencies.** A2 (otherwise the audit shows 100% sentinel and 0%
  capability-bound).
- **Risk.** None.

---

## D — Test coverage gaps in canonical surfaces

### D1. Storage layer trait conformance tests

- **What.** Today's tests in `cognitive_dag/storage.rs` are tightly coupled
  to `InMemoryDagStore`. When A1 lands a `RedbDagStore`, every test must be
  duplicated. Better: a `dag_store_conformance!` macro that takes a `Box<dyn
  DagStore>` factory and runs the full battery against any backend.
- **Where.** `agent_core/src/cognitive_dag/storage.rs:382-705`.
- **Effort.** 4-6 hours.
- **Canonical priority.** Required when A1 lands; nice-to-have until then.
- **Dependencies.** None for the macro itself; A1 to make it valuable.
- **Risk.** None.

### D2. ReplayBundle round-trip with cap-bound edges

- **What.** `provenance/replay.rs` tests construct bundles with
  sentinel-signed edges. When A2 lands, replay round-trips need to verify
  capability binding survives serialization + deserialization (i.e., the
  cap hash is recoverable from the bundle, not just the edge sig).
- **Where.** `agent_core/src/provenance/replay.rs` test module.
- **Effort.** 2-3 hours.
- **Canonical priority.** Must-do alongside A2.
- **Dependencies.** A2.
- **Risk.** None.

---

## E — Cross-language consistency

### E1. K_RRF parity is good; broader audit warranted

- **What.** `K_RRF=60` parity between Rust (`epistemos-shadow/src/backend/rrf.rs:24`)
  and Swift (`Epistemos/Sync/RRFFusionQuery.swift:183`) is enforced by
  `RRFFusionQueryTests.swift`'s "K_RRF parity probe of Rust source" test.
  Pattern is good. **No new drift surfaces found in this sweep.** Notable
  near-misses checked:
  - `MAX_RETRACTION_WALK_DEPTH = 16` (provenance/ledger.rs) — no Swift
    consumer of the depth; no parity needed.
  - `Phase3FusionConsts` Swift mirrors only K_RRF (the rest of the fusion
    surface is Rust-internal).
  - DagSnapshot `SCHEMA_VERSION = 1` (storage.rs:106) — Swift consumes via
    JSON only, not via constant; survives version bumps via serde tag.
- **Where.** `epistemos-shadow/src/backend/rrf.rs`,
  `Epistemos/Sync/RRFFusionQuery.swift`.
- **Canonical priority.** No action needed.

---

## F — Build / CI canonical surface

### F1. CI doesn't run any agent_core feature combination explicitly

- See B3 + B4. CI build/test invocations omit `--features` flags entirely,
  picking up `default = ["mas-build"]`. Should explicitly run all three
  documented combinations from kernel doctrine §10.7:
  ```
  cargo test --no-default-features --features ""
  cargo test --no-default-features --features "pro-build"
  cargo test --no-default-features --features "pro-build,research"
  ```

### F2. Doctrine linter not wired into Xcode build phase

- **What.** Per doctrine §5 + Phase 8.G shipping log, the linter is meant to
  run on every CI invocation. It's a pure-Rust binary; integrating it as a
  pre-build script-phase in `Epistemos.xcodeproj` is straightforward
  (matches the build-agent-core.sh script-phase pattern).
- **Where.** `Epistemos.xcodeproj/project.pbxproj` (or, preferably, via
  `xcodegen` `project.yml`).
- **Effort.** 1-2 hours.
- **Canonical priority.** Must-do for local-dev parity with future CI.
- **Risk.** First run may surface 5.1-5.4 violations Codex hasn't seen; that
  is the point.

### F3. No release-time replay-bundle smoke test

- See B2. Should be in CI, ideally before the App Store bundle-size gate.

### F4. App Store entitlements file diff coverage in CI

- **What.** MAS-First §4.5 maintains TEMP-FREE-TIER markers in
  `Epistemos-AppStore.entitlements` (App Groups removed). No CI step asserts
  the entitlement file shape (e.g., "exactly these 7 keys present"). A drift
  here could quietly add an entitlement that the App Store reviewer rejects.
- **Where.** `Epistemos-AppStore.entitlements`,
  `Epistemos-AppStore-Info.plist`, CI.
- **Effort.** 2-3 hours. Write a small Python/shell entitlements assertion
  + run from CI.
- **Canonical priority.** Must-do before any App Store submission.
- **Dependencies.** None.
- **Risk.** None.

---

## G — Documentation drift

### G1. `docs/AGENT_PROGRESS.md` last touched 2026-04-28

- **What.** AGENT_PROGRESS.md mtime is 2026-04-28; substantial work landed
  2026-05-04 → 2026-05-05 (Hermes removal slices 1-4, V2.1 Phase 8.A-8.G,
  V2.3 LSP migration, V2.4 first slice, V3.2 first slice, V3.3 paper draft,
  Codex verification handoff). Per CLAUDE.md "Session Startup Protocol"
  step 2, agents read this doc to see what's done. **Stale by ~7 days of
  major work.** CRITIQUE_LOG.md noted historical drift here too.
- **Where.** `docs/AGENT_PROGRESS.md`.
- **Effort.** 1-2 hours.
- **Canonical priority.** Should be updated each session-end per the same
  protocol.
- **Risk.** None.

### G2. CLAUDE.md FILE MAP has no Cognitive DAG / Provenance / Doctrine-Lint section

- **What.** CLAUDE.md FILE MAP (lines 103-365) lists agent_core modules but
  ends at the 2026-04-28/29 perf wave. Missing canonical paths for:
  - `agent_core/src/cognitive_dag/` (10 files including macaroons)
  - `agent_core/src/provenance/{ledger,replay}.rs`
  - `agent_core/src/bin/{epistemos_trace,epistemos_doctrine_lint}.rs`
  - `agent_core/src/lsp_runtime/mod.rs`
  - `agent_core/src/agent_runtime/{procedural_memory,self_evolution,
    function_call,skills}.rs` (the post-Hermes-removal canonical path)
- **Where.** `CLAUDE.md`.
- **Effort.** 30 min.
- **Canonical priority.** Per CLAUDE.md "Detailed Docs (READ these, don't
  guess)" — the FILE MAP is the don't-guess surface; missing entries
  invite re-derivation.
- **Risk.** None.

---

## What looks fine — explicit non-findings

These were checked and ARE in good shape:

- **Sovereign Gate single-owner:** zero `LAContext` calls outside
  `Epistemos/Sovereign/`.
- **Subprocess discipline:** every `Command::new` in agent_core is either
  hardened via `harden_cli_subprocess` or Pro-cfg-gated. Swift uses no
  `Process()` / `NSTask`.
- **Hermes removal:** zero `hermes_subprocess` cfg gates; module rename to
  `agent_runtime` is clean; LocalAgent Hermes*.swift files preserved per
  doctrine.
- **Naming:** zero `Epistenos` typos in code.
- **Anti-patterns from CLAUDE.md DO NOT list:** no `try!`, no
  `DispatchQueue.main.sync` in active Swift, no `print()` in active Swift
  production paths.
- **DAG Swift gate (5.4):** only one Swift file references DagStore — and
  it's a doc comment in `RustCognitiveDagClient.swift`, not a code call.
  The doctrine intent is preserved.
- **`thiserror` adoption:** 8 typed-error modules; balance with String
  errors (14 returns) is acceptable for the surface.
- **Cross-language K_RRF parity:** test-enforced, healthy.

---

## Suggested execution order (if you want one)

If you want a single "do these and you've materially strengthened the
canon" list, ordered by canonical-impact-per-effort:

1. **B1** — wire `epistemos-doctrine-lint` into CI (1 hour, high signal)
2. **B2** — wire `epistemos-trace verify-replay` into CI (2-3 hours)
3. **B3 + B4** — full feature matrix in CI (2-3 hours)
4. **G1 + G2** — refresh AGENT_PROGRESS.md + CLAUDE.md FILE MAP (1-2 hours)
5. **C1** — eprintln → tracing in dispatch.rs (30 min)
6. **F2** — Xcode pre-build doctrine lint phase (1-2 hours)
7. **F4** — entitlements assertion in CI (2-3 hours)
8. **A1** — redb-backed DagStore (4-6 days; **enables 8.H**)
9. **C4** — required `register_capability` trait method (1 hour, paired with A1)
10. **A3** — fill the 4 missing auto-dispatch sites (4 weeks; **enables 8.H**)
11. **A2** — real capability binding through SovereignGate (2-3 weeks; **enables 8.H**)
12. **A4** — WASM exec runtime (3-4 weeks; **MAS unlock**)
13. **A5** — in-process bundled MCP (2-3 weeks; **MAS unlock**)
14. **A6** — `agent_runtime` ↔ doctrine `hermes` reconciliation (1 day OR 2 weeks)
15. **A7** — XPC service skeletons (3-5 weeks; **paid-team-gated**)

Items 1-7 are safe single-session wins (~1 day total). Items 8-11 unlock
the §10 authority flip the V2.1 stage is currently blocked on. Items 12-13
are the kernel doctrine §5/§6 MAS unlocks the V1 capability matrix
described but never shipped. Item 14 is doctrine reconciliation. Item 15
needs the Apple Developer Program enrollment.

---

## Final note

The biggest "TRUE canonical upgrade" available is **wiring the gates that
already exist** (B1-B4, F2, F4) — that's <1 day of work and would close
the gap between "we wrote it" and "we enforce it." Beyond that, the V2.1
8.H authority flip blockers (A1-A3 + C4) are the canon-load-bearing items;
everything else is canon-aligned hardening. The substrate is healthier than
the drift register makes it look — the linter exists, the replay binary
exists, the macaroon module exists, the tests pass. They just don't
all *run* in CI yet.
