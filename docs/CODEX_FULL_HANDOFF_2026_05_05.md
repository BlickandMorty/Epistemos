---
state: canon
canon_promoted_on: 2026-05-05
covers: comprehensive open-work handoff to Codex after the 2026-05-05 canon-hardening session (85 commits)
read-with: docs/SESSION_RETROSPECTIVE_2026_05_05.md (read-this-first index)
---

# Codex Full Handoff — 2026-05-05

> **Mission:** Codex picks up here and executes every open item below.
> The 2026-05-05 canon-hardening session reached a point where all
> remaining substantive work either (a) needs Codex's authority to
> verify or sign off, (b) is a state:candidate brief that needs Codex
> implementation per the canon promotion protocol, or (c) is a
> pre-merge blocker that needs cleanup before this branch can ship to
> main.
>
> **Authority:** Codex is the final overseer per the user's
> 2026-05-05 standing instruction:
>
> > "for the codex handoff i truly want codex to like before act as if
> > work has not been doe becasue it hasnt been verified by ut. it is
> > the final overseer of all work particualr the work it has not
> > checked or work it has not signed off on."
>
> Treat every commit since `7a063f4a` as **not-yet-shipped** until
> independently verified. The `_release_` WRV state is gated on Codex
> verification per the canon-hardening protocol.

---

## TL;DR — top-of-mind for this Codex pass

**Pre-merge blocker resolved by Codex continuation:** the ~126
project-wide clippy issues across 5 crates were cleaned without API
refactors and re-verified under the CI-style `-D warnings` gates.
**§1 below records the closure and the non-API-change constraint.**

**External-verification gates:** CD-004 (V2.1 8.A-8.G authority flip
prerequisites) is BLOCKED on Codex independent verification. CD-008
full closure now has full `xcodebuild test` + Rust all-targets / Pro
feature / doctrine lint / replay gates Codex-verified. The
`tower-lsp` + `tree-sitter` semantic LSP path is also verified through
Rust and Swift focused tests. The remaining CD-008 gap is runtime UI
smoke for the live editor affordance and any biometric/Sovereign Gate
flow that requires real user approval. **§2 below has the checklist.**

**State:candidate items held for sign-off** (3 briefs, ~40+ hours of
implementation work remaining): B1-B3 phase work (Phases 21-25 +
W7-A through W7-J + W8 + W6-A through W6-I). The Static/Dynamic
discriminator was promoted to canon and implemented by Codex
continuation. A1 redb persistence slices 1-4 also landed behind an
opt-in feature; only A1 slice 5 authority wiring remains pending.
**§3 below has each remaining one with sign-off questions.**

**Held-for-sign-off small items**: provenance_ledger architectural
drift. Tirith Pro-gating and the orphan-tool source decision have
been resolved by Codex continuation. **§4 below.**

**Other Open APP_ISSUES** (P0/P1): SwiftUI hot-loop, model install
detection, Opus 4.1 Main Chat regression, idle memory regression.
**§5 below.**

**Tier-1 doctrine lifts from B-bonus briefs are landed** (15
doctrine additions, no runtime code). **§6 below records the exact
canonical locations.**

---

## §1 — Resolved pre-merge blocker: project-wide clippy debt

**Logged:** `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-05-05-001 (P1)

**Closure:** Codex continuation cleaned the lint debt without
API-changing refactors. The FFI pointer lint is intentionally allowed
at the Rust boundary with a `SAFETY` explanation rather than changing
the exported Swift-facing ABI to `unsafe fn`.

**Verified gates now pass:**

| Crate | Command | Result |
|---|---|---|
| `agent_core` | `cargo clippy --manifest-path agent_core/Cargo.toml --target aarch64-apple-darwin -- -D warnings` | PASS |
| `agent_core` Pro+lsp | `cargo clippy --manifest-path agent_core/Cargo.toml --no-default-features --features pro-build,lsp-runtime --target aarch64-apple-darwin -- -D warnings` | PASS |
| `epistemos-core` | `cargo clippy --manifest-path epistemos-core/Cargo.toml --target aarch64-apple-darwin -- -D warnings` | PASS |
| `omega-mcp` | `cargo clippy --manifest-path omega-mcp/Cargo.toml --target aarch64-apple-darwin -- -D warnings` | PASS |
| `omega-ax` | `cargo clippy --manifest-path omega-ax/Cargo.toml --target aarch64-apple-darwin -- -D warnings` | PASS |
| `graph-engine` | `cargo clippy --manifest-path graph-engine/Cargo.toml --target aarch64-apple-darwin -- -D warnings` | PASS |

**Constraint preserved:** no too-many-args API refactors and no large
`Err` boxing were performed without explicit sign-off.

---

## §2 — External-verification gates (Codex authority required)

### CD-004 — V2.1 8.A-8.G authority flip BLOCKED

**From `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md`:**

> May 4 plan and DAG doctrine require Phase 1-7 readiness and
> authority gates before Phase 8 can be treated as canonical
> authority. Do not mark V2.1 8.A-8.G as release-shipped until Codex
> verifies prerequisites, mirror coverage, replay parity, and
> authority flip criteria.

**What Codex must verify before unblocking:**

1. **Phase 1-7 prerequisites** — read the May 4 plan and the DAG
   doctrine; confirm all listed prerequisites are satisfied in main.
2. **Mirror coverage** — `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md`
   claims 4 of 4 live-write mirrors wired (Provenance evidence/claim,
   Procedural, Skills via snapshot-on-load) + CompanionMirror dormant
   by design. **Verify this independently.** Run a session that
   exercises every legacy write path; confirm each emits a mirror
   write to `cognitive_dag_store`.
3. **Replay parity** — Phase 8.F replay (`epistemos-trace
   verify-replay`) must produce byte-identical merkle roots across
   `InMemoryDagStore` and the opt-in redb backend before redb becomes
   the live dispatch store. A1 slices 1-4 prove store-level
   Merkle/snapshot parity; dispatch/replay parity remains the slice 5
   authority question.
4. **Authority flip criteria** — doctrine §10 two-week CI green
   window must complete before flipping. With CI not running on
   feature branches today (see §1), this gate is effectively
   blocked until either (a) the branch merges to main, OR (b) CI
   trigger is extended to feature branches.

**Codex action:** decide whether to (i) sign off CD-004 now, (ii)
require additional substrate before sign-off (and what), or (iii)
adjust the authority-flip criteria.

### CD-008 — Full-app verification MOSTLY CLOSED

**Closed before Codex continuation:**

| Surface | Result |
|---|---|
| `cargo test --lib` (agent_core, default features) | 879 / 879 |
| `cargo test --lib --features lsp-runtime` | 891 / 891 |
| `cargo test` (graph-engine) | 2522 / 2522 (8 ignored) |
| `cargo test` (omega-mcp) | 143 / 143 |
| Xcode `Epistemos` test-build | TEST BUILD SUCCEEDED |

**Closed by Codex continuation:**

| Surface | Result |
|---|---|
| `cargo test --manifest-path agent_core/Cargo.toml --all-targets` | PASS — default feature all-targets, including lib, bins, integration tests, example harness |
| `cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features pro-build,lsp-runtime --all-targets` | PASS — Pro+lsp feature all-targets, including 1014/1014 lib tests plus bins/integration tests |
| `cargo test --manifest-path epistemos-core/Cargo.toml --all-targets` | PASS — 378/378 lib, uniffi bin 0/0, sqlite-vec integration 5/5 with 1 manual ignored baseline |
| `cargo test --manifest-path omega-mcp/Cargo.toml --all-targets` | PASS — 143/143 lib plus uniffi bin 0/0 |
| `cargo test --manifest-path omega-ax/Cargo.toml --all-targets` | PASS — 12/12 lib plus uniffi bin 0/0 |
| `cargo test --manifest-path graph-engine/Cargo.toml --all-targets` | PASS — 2522/2522 lib, 8 ignored, graph FFI baseline bench harness succeeded |
| `cargo run --manifest-path agent_core/Cargo.toml --bin epistemos_doctrine_lint -- "$(pwd)"` | PASS — ALL GATES PASS, doctrine §5 verified |
| `generate_sample_epbundle` + `epistemos_trace verify-replay` | PASS — v2 bundle verified, DAG merkle `ea2e4ac0c13b04f7a638b4714862fc6536fd9833c305456f28f1473e79d5ba9c` |
| `.epdoc` focused Swift test + Computer Use smoke | PASS — New Doc visible on Landing, Notes sidebar New Document button visible, click opened an untitled document window |
| Full `xcodebuild test` | PASS — `/tmp/epistemos-codex-full-test-rerun-1778019268.xcresult`, result `Passed`, 5,739 total tests, 0 failed, 49 skipped |
| Semantic LSP focused tests | PASS — `cargo test --manifest-path agent_core/Cargo.toml --features lsp-runtime lsp_runtime --lib` 17/17 and Swift focused `RustLSPTransportTests` + `LSPClientTests` 17/17; hover/definition travels through the Rust `tower-lsp` + `tree-sitter` kernel |
| Computer Use runtime smoke | PASS/PARTIAL — Landing, Notes/editor, Settings Diagnostics, and Authority approval preview render and respond; preview denied without changing permissions |

**Still required (runtime/manual):**

1. **Manual runtime smoke** of the live LSP editor affordance. The
   semantic transport is verified through Rust and Swift tests, but
   this pass did not drive the visual code-editor hover/definition UI.
2. **Biometric/Sovereign Gate prompts that require real user approval**
   remain user-time only. The non-destructive Authority approval preview
   rendered and was denied safely.

**Why manual:** the remaining LSP item is a GUI affordance check, not
a semantic-kernel gap. Biometric approval flows still require human
inspection and approval behavior on the real Mac.

**Codex action:** ship the remaining Computer Use/manual runtime
smoke where possible, then mark any un-drivable biometric/Sovereign
Gate prompts as needing user-time on a real Mac.

---

## §3 — State:candidate items held for sign-off

Per the canon promotion protocol installed today
(`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`), doctrine-shaping
work goes through `state: candidate` (a brief that surveys the
substrate, recommends a path, queues sign-off) BEFORE landing as
`state: canon`. The 2026-05-05 session held 5 candidate briefs
without implementing them — Codex/user sign-off is required before
implementation lands.

### 3.1 — A1: redb persistent DagStore backend — PARTIAL LANDED

**Brief:** `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md`

**Closure so far:** Codex continuation implemented durable
`RedbDagStore` behind `cognitive-dag-redb`, using current `redb`
4.1.0 and JSON value bytes. The earlier bincode recommendation was
falsified by tests because the existing `Node` / `Edge` serde shape
requires `deserialize_any`.

**Verified:** redb focused 8/8, feature-enabled cognitive DAG
144/144, default cognitive DAG 136/136, default clippy, and redb
feature clippy all pass.

| Slice | What |
|---|---|
| 1 | LANDED — Cargo dep (`redb` 4.1.0) + `RedbDagStore` module behind `cognitive-dag-redb` |
| 2 | LANDED — put_node + get_node + durability proof across reopen |
| 3 | LANDED — put_edge with CD-005 capability binding + edges_from/edges_to via redb multimaps |
| 4 | LANDED — merkle_root + snapshot parity vs `InMemoryDagStore` |
| 5 | PENDING — dispatch wiring to a vault/App Group path; default still OFF until authority verification |

**Remaining sign-off question:** when `cognitive-dag-redb` is enabled,
should dispatch open `<vault>/.epistemos/cognitive_dag.redb` and mirror
every legacy write into redb now, or should redb remain a parity/replay
backend for one more verification cycle?

### 3.2 — Static/Dynamic discriminator (Q2 recommendation) — RESOLVED

**Brief:** `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md`

**Closure:** Codex continuation promoted this brief to `state: canon`
and implemented Option C + B. `NodeKind::is_dynamic_rooted()` is now
the canonical code-level discriminator, doctrine §2.2 names the
static/dynamic-rooted invariant, and the exhaustive node-kind test
pins the two dynamic-rooted variants (`Companion`, `Model`).

**Verified:**
- `cargo test --manifest-path agent_core/Cargo.toml cognitive_dag::node::tests::dynamic_rooted_discriminator_covers_all_variants --lib`
- `cargo clippy --manifest-path agent_core/Cargo.toml --target aarch64-apple-darwin -- -D warnings`

**Why:** the user asked 2026-05-05: "Artifact primitive that
distinguishes Static Note from Dynamic AI Weight." Survey shows the
distinction is already in the substrate (8 of 10 NodeKind variants
are static, 2 dynamic-rooted via Companion/Model). Recommendation:
Option C + Option B together — add a method, document the rule, no
new wrapper type.

**Scope landed:** method + 1 test + doctrine paragraph.

```rust
// agent_core/src/cognitive_dag/node.rs — append to NodeKind impl block:

impl NodeKind {
    pub fn is_dynamic_rooted(&self) -> bool {
        match self {
            NodeKind::Companion { .. } | NodeKind::Model { .. } => true,
            NodeKind::Note { .. }
            | NodeKind::Claim { .. }
            | NodeKind::Evidence { .. }
            | NodeKind::Skill { .. }
            | NodeKind::Tool { .. }
            | NodeKind::Procedure { .. }
            | NodeKind::Event { .. }
            | NodeKind::Capability { .. } => false,
        }
    }
}
```

Plus 1 unit test pinning the classification per variant + a §2.2
doctrine paragraph explaining the static/dynamic-rooted distinction.

### 3.3 — B1: Biometric / Tamagotchi / Brain-Export phase work (Phases 21-25)

**Brief:** `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md`

**Map vs main (already partially present):**

- **Phase 21 (Biometric substrate)** — `Epistemos/Security/CapabilityBridge.swift`
  + `SovereignGate` exist; Session Authority Token + 8 always-fresh
  categories NOT yet in main.
- **Phase 22 (Confidence meter + 70% re-learn)** — NOT in main.
- **Phase 23 (Tamagotchi + Tactical UI)** — NOT in main; lives in
  simulation worktree per memory.
- **Phase 24 (Cloud-as-teacher distillation lab)** —
  `KnowledgeFusion/CloudKnowledgeDistillationService.swift` exists;
  Lab UX + PII sluice + catastrophic-forgetting eval are new.
- **Phase 25 (Brain Export)** — NOT in main; gated on legal review.

**Sign-off questions for user (5 total per brief):**
1. Tier-1 lifts (5 doctrine additions) land as one PR or 5 separate slices?
2. The 8 "always-fresh-biometric" categories — accept verbatim from B1 §1.3 or curate?
3. The "Tactical mode required for Pro distribution" stance — canonical default or per-customer?
4. Brain Export legal review — recommended legal partner, or out of scope for canon work?
5. Should the build-order Phase 21–25 queue go to Codex's deliberation queue immediately or after the next CD-004 V2.1 8.H authority flip?

### 3.4 — B2: Live Files + Substrate phase work (Phases W7-A through W7-J + W8)

**Brief:** `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md`

**Map vs main:**

- **Phase W7-A through W7-G** (Live File state machine + Stateful
  Rotor + Cognitive Weight + dual-mode format + closed-grammar
  conditions + cron-for-AI + Vector Universe) — all NOT in main.
- **Phase W7-H + W7-I (subprocess elimination)** — `MoLoRA Python` +
  `QLoRA Python` subprocesses still exist in main:
  - `Epistemos/KnowledgeFusion/MoLoRA/MoLoRAInferenceService.swift:53`
  - `Epistemos/KnowledgeFusion/Training/QLoRATrainer.swift:50`
  - **Direct doctrine §2.2 invariant #2 reinforcement** (Hermes
    subprocess was already removed 2026-05-05; MoLoRA + QLoRA are
    the remaining structural debt).
- **Phase W7-J (cleanup)** — `OrphanSubprocessCleanup.swift` +
  `PythonEnvironmentManager.swift` delete themselves when W7-H + W7-I
  ship.
- **Phase W8 (Eidos Plus deliberation engine)** —
  `Epistemos/KnowledgeFusion/Autoresearch/AutoresearchLoop.swift`
  exists but the deliberation engine doesn't.

**Sign-off questions for user (5 total per brief):**
1. MoLoRA + QLoRA port (W7-H + W7-I) priority — Pro-only or Core
   given the doctrine alignment?
2. Live Files file-format convention — `.epdoc` extension or `.md`
   with header sniffing?
3. Cognitive Weight slider — per-file UI in Settings or
   inline-in-editor floating control?
4. Stateful Rotor's <5ms tick budget — `assert!` or
   `tracing::warn!` (production should NOT crash under thermal
   throttling)?
5. Cron-for-AI parser — lift `english-to-cron` crate or roll our own
   bounded grammar (closed-grammar discipline argues for the latter)?

### 3.5 — B3: Obscura Browser + Eidos Search phase work (Phases W6-A through W6-I)

**Brief:** `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`

**Map vs main:** ZERO of the substrate is in main today. Entirely
net-new feature surface across:

- **W6-A through W6-D** (Obscura Cargo dep + deno_core + UniFFI
  bridge + SwiftUI browser surface) — Pro tier.
- **W6-E through W6-H** (Eidos vault HNSW + Metal cosine + LLM
  rerank + closed-vocab citation grammar) — mixed Core/Pro.
- **W6-I** (tool catalog additions) — Pro/Core mix.

**Sign-off questions for user (5 total per brief):**
1. The Obscura crate is a public GitHub repo (h4ckf0r0day/obscura) —
   has it been audited for security posture beyond what the addendum
   claims?
2. Eidos vs ShadowSearchService — merge into one search surface or
   stay as two complementary systems?
3. Closed-vocabulary citation grammar binding — single PR or staged
   W6-G first?
4. Metal-cosine re-rank kernel — new kernel under `Epistemos/Shaders/`
   or reuse existing Mamba-2 / LandingWave patterns?
5. The "stealth posture" feature flag — does it conflict with the C5
   doctrine ("visual layers project; they do not invent state")?

---

## §4 — Held-for-sign-off small items

### 4.1 — Tirith Pro-gating (B5 follow-up)

**Source:** `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` §"Items needing
verification" → "tirith.rs:268"

**Codex continuation status:** resolved. `agent_core::tirith` is now
behind `#[cfg(feature = "pro-build")]`, and the approval caller that
invokes `TirithClient` is also Pro-only. MAS/default builds retain the
in-process pattern gate but no longer compile the dormant Tirith
subprocess scanner surface.

**Verification:** default/MAS clippy passed, Pro+lsp clippy passed,
default lib tests passed 871/871, and Pro+lsp lib tests passed
1014/1014.

### 4.2 — Orphan source files in `agent_core/src/tools/`

**Source:** `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` §"Orphan source
files (action required)"

**Codex continuation status:** resolved. `code_execution.rs` and
`graph_query.rs` were removed after a reachability + replacement
audit. `code_execution.rs` was an unregistered local subprocess
runner; `graph_query.rs` was superseded by the wired `tools/graph.rs`
implementation. `note_tools.rs` was promoted rather than deleted,
because it contained unique PKM/note scaffold.

**Resolution:**
| File | LOC | Status |
|---|---|---|
| `agent_core/src/tools/code_execution.rs` | 105 | Deleted as proven-dead local subprocess runner |
| `agent_core/src/tools/graph_query.rs` | 276 | Deleted as superseded by `tools/graph.rs` |
| `agent_core/src/tools/note_tools.rs` | 523 | Declared as `tools::note_tools`, registered through `register_phase_two_note_tools()`, and protected by R.5 for template writes |

**Total remaining: 0 LOC of orphan source.**

**Verification:** `agent_core` clippy passed with `-D warnings`, and
the full lib test suite passed 882/882 after promotion. New tests pin
note-tool registration, `note_template.output_path` resource inference,
and denial of ungranted template writes.

### 4.3 — `provenance_ledger()` architectural drift

**Source:** commit 90bdddee + `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md`
C2 row.

**Codex continuation status:** resolved without deleting scaffold or
creating a second authority. The dispatch helpers correctly mirror
claim/evidence writes to `cognitive_dag_store()` because the Cognitive
DAG is the provenance ledger after Phase 8.E. The legacy
`agent_core::bridge::provenance_ledger()` global remains as read-only
compatibility scaffold, but the visible Halo ribbon and Provenance
Console now source the live Rust provenance signal from
`RustCognitiveDagClient.stats()`. The UI labels the old bridge as
legacy context instead of presenting its empty counters as production
truth.

### 4.4 — Companion mirror dormant caller

**Source:** `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md`

**Finding:** `CompanionMirror`'s dispatch helper
`on_companion_registered` exists with full test coverage but has no
live caller — `CompanionRegistry` is only invoked from cognitive_dag
tests.

**Recommendation:** wire when companion lifecycle goes live (V2.x
continual-learning work — Sherry/Arenas/Companion families). Track
as a pending item; do not delete the dispatch helper.

---

## §5 — Open APP_ISSUES_AUTO_FIX items needing runtime work

From `docs/APP_ISSUES_AUTO_FIX.md`:

### ISSUE-2026-04-21-004: Idle memory regression (~500 MB) — P1, Open

User reports app idles around 500 MB (historically ~50 MB). Metal
working-set release (ISSUE-003) partially addresses post-unload, but
the initial boot footprint is still high.

**Suspected causes (not yet Instruments-profiled):**
1. `AppleHybridEmbeddingLookup()` in `GraphState.init()` eagerly
   loads `NLContextualEmbedding(.english)` (~40-100 MB) +
   `NLEmbedding.wordEmbedding(.english)` (~150 MB).
2. `PreparedRetrievalRuntimeConfiguration` retains parsed manifest
   descriptors after deferred load.
3. SwiftData `@Query` result caches in sidebars / chat views.
4. Tokenizer vocab / model-weight residency after first local turn.

**Codex action:** run Instruments → Allocations on a
launched-then-idle app and identify the top 10 persistent
allocations. NOT autonomous-session-fixable (needs Instruments).

### ISSUE-2026-04-22-001: SwiftUI hot-loop at 98-100% CPU — P0, Investigating

`docs/handoffs/2026-04-22-claude-to-codex-live-runtime-and-tunnel-findings.md`
§3 captures the diagnosis from sample + diff review of `97adbf83`.
Live build did not reproduce during walkthrough but has not been
stressed under memory pressure.

**Codex action:** stress-test under memory pressure to confirm or
refute the diagnosis.

### ISSUE-2026-04-22-002: Local model install detection misses 10+ hub directories — P1, Open

Hub directory at `~/Library/Application Support/Epistemos/Models/text/hub`
contains 12+ ready models but only 2 are detected as installed.
Suspected: hub-directory name ↔ `LocalModelCatalog.shippedModelIDs`
mismatch.

**Codex action (safe, no user approval):** grep for `installRecords`
/ `is_installed` / `hubDirectoryName` in `Epistemos/LocalAgent/`,
add a debug log printing each hub dir + the catalog ID it compared
against.

**Codex action (destructive, needs user approval):** extend the
matching rule to accept blob-only hub dirs OR add missing catalog
entries.

### ISSUE-2026-04-22-003: Qwen 3 unified picker never surfaces — P2, Open

Downstream of -002. Fix install detection, then the unified picker
engages automatically.

### ISSUE-2026-04-22-004: Opus 4.1 Main Chat outside-vault read produced "No response received" — P1, Open (inherited from Codex §5.2)

Main Chat Agent-mode tool loop for Opus 4.1 ends without a
`.complete` event after tool execution. Same prompt in Mini Chat
succeeds.

**Codex action:** re-run the same prompt on Opus 4.7 and Sonnet 4.6
on the latest build with Console logs capturing every `.complete` /
`.error` event. If the pattern reproduces across all Anthropic
models, inspect `Epistemos/App/ChatCoordinator.swift` main-agent
path for the silent-stream-ending bug.

---

## §6 — Resolved Tier-1 doctrine lifts from B-bonus briefs

Codex continuation landed the 15 Tier-1 doctrine additions in
`docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md`. These are
contracts only: no B1/B2/B3 runtime implementation is claimed shipped.

### From B1 (BIOMETRIC_TAMAGOTCHI_BRAINEXPORT) — 5 lifts

1. **Session Authority Token contract** → §4.2 (Sovereign Gate).
2. **Confidence meter doctrine** → Annex A.17.
3. **UI mode toggle** (Pixel mode / Tactical mode) → §4.0.
4. **Accessory metaphor doctrine** (LoRAs as equipment) → Annex A.5.
5. **Brain Artifact contract** → §3 (Tier Matrix).

### From B2 (LIVE_FILES_AND_SUBSTRATE) — 5 lifts

6. **Cell-organism metaphor as design generator** → Annex A.18.
7. **Determinism gradient (Cognitive Weight)** → §2.2 + §4.0.
8. **Stateful Rotor + sub-5ms discipline** → §7 + §6 no-polling rule.
9. **Closed-grammar conditional logic** → §6 no `eval`/JS/Python/shell rule.
10. **Subprocess audit closure (MoLoRA + QLoRA ports)** → §2.2 engine-embed invariant.

### From B3 (OBSCURA_BROWSER) — 5 lifts

11. **Three structural reasons subprocess fails** → §2.2.
12. **Library-embed pattern as canonical engine integration** → §2.2.
13. **Closed-vocabulary citations** → §6 + Annex A.13.
14. **V8 dedup discipline (`[patch.crates-io]`)** → §9.
15. **Eidos thesis (local-first inversion of Exa)** → §4.3 + Annex A.13.

**Remaining work:** B1/B2/B3 code implementation remains in §3 as
state:candidate phase work requiring deliberation briefs and normal
verification. The doctrine lifts are no longer a sign-off blocker.

---

## §7 — Ongoing canonical hygiene (no sign-off needed; safe to do)

These are autonomous-safe items Codex can do without sign-off:

1. **Re-run all 4 CI gates locally** before sign-off:
   - B1 doctrine linter — `cargo run --bin epistemos_doctrine_lint -- "$(pwd)"` from agent_core
   - B2 verify-replay — `cargo run --example generate_sample_epbundle -- /tmp/cv.epbundle && cargo run --bin epistemos_trace -- verify-replay /tmp/cv.epbundle` from agent_core
   - B3 Pro-build feature surface — `cd agent_core && cargo build --no-default-features --features pro-build,lsp-runtime && cargo test ...`
   - B4 lsp-runtime feature — `cd agent_core && cargo test --features lsp-runtime`
   - **Already locally green at session end** (commit 8ab10991), but Codex should re-verify.

2. **Don't commit dirty benchmark JSONs** (CD-009 procedural). The
   7 dirty files in `git status` are local test/build re-runs from
   earlier this session — they're NOT intentional baseline updates.

3. **Auto-memory check** — review entries in
   `~/.claude/projects/.../memory/` (specifically
   `project_canon_hardening_2026_05_05.md` and
   `feedback_session_start_git_status.md` added this session) and
   confirm they're aligned with Codex's understanding.

---

## §8 — Closing line (verification posture)

Per the user's standing instruction, every commit since `7a063f4a`
on `feature/landing-liquid-wave` is **not-yet-shipped** until Codex
independently verifies. The 85 commits this session are
**verified-by-Claude only**. Codex's pass IS the truth.

**The doctrine §10 contract still holds:** nothing in this session
is claimed `released`. Everything is at WRV-state `verified` (locally
green) at best; `released` is gated on Codex sign-off.

**Three items are explicitly held for sign-off and Codex should NOT
auto-execute them without explicit user authorization:**

1. The 3 remaining state:candidate implementation briefs (§3 above)
   plus A1 slice 5 authority wiring.
2. Any future removal of scaffold that is not proven-dead past code.
3. Anything that crosses the canon promotion protocol's "doctrine-
   shaping work gets one explicit sign-off cycle before code lands"
   line.

**Three items Codex SHOULD auto-execute (autonomous canonical work):**

1. The remaining CD-008 runtime work (§2): live LSP editor-affordance
   smoke and biometric/Sovereign Gate user-time. Full `xcodebuild test` is already
   Codex-verified.
2. Continued source-guard and dead-code audits, preserving scaffold
   unless it is proven-dead past code or explicitly superseded.
3. Continued doctrine/code drift sweeps after each implementation
   slice, using §6 as the newly landed contract map.

**Two items genuinely BLOCKED externally:**

1. CD-004 V2.1 8.A-8.G authority flip — needs Codex's "I have read
   the May 4 plan + DAG doctrine + verified the prerequisites"
   sign-off (§2 above).
2. Brain Export legal review (B1 §5.4) — needs lawyer, not Codex.

---

## Cross-references (the canonical reading order Codex should follow)

1. `docs/SESSION_RETROSPECTIVE_2026_05_05.md` — read-this-first index
2. **This doc** (`docs/CODEX_FULL_HANDOFF_2026_05_05.md`)
3. `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` — detailed close-out
   with Codex drift register status table
4. `docs/CODEX_CANONICAL_DRIFT_AUDIT_2026_05_05.md` — Codex's own
   prior audit (now committed)
5. `docs/CODEX_VERIFICATION_HANDOFF_2026_05_05.md` — original
   verification ask
6. `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` — WRV / canon
   promotion / no-date-gates protocol
7. `docs/APP_ISSUES_AUTO_FIX.md` — runtime issues index; the former
   ISSUE-2026-05-05-001 clippy debt is now Verified Fixed
8. `docs/AGENT_PROGRESS.md` — full 2026-05-05 ledger (items 1-23)
9. **State:candidate briefs** (held for sign-off):
   - `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md`
   - `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md`
   - `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`
10. **Implemented canon briefs**:
    - `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md`
    - `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md`
11. **Standalone audits** (canonical, no further action):
    - `docs/MMAP_UTILIZATION_AUDIT_2026_05_05.md`
    - `docs/MIRROR_DISPATCH_COVERAGE_2026_05_05.md`
    - `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md`
    - `docs/CD_008_PARTIAL_CLOSURE_2026_05_05.md`
11. `docs/CANONICAL_UPGRADE_AUDIT_2026_05_05.md` — original 17-item audit
12. `docs/CANONICAL_ROADMAP_2026_05_05.md` — synthesis ledger
13. `docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md` — COMPLETE
    (15 C-blocks merged + 3 B-bonus blocks read-then-absorbed +
    ALL_DOCS_INDEX entry)

---

## Closing line

Codex sign-off is now the gating step for everything in this
handoff. The user's mandate: "stay canonical and exceed."
Implementation work is queued behind Codex authority + user
authorization per the canon promotion protocol installed today.

This branch (`feature/landing-liquid-wave`) is at 85 commits since
`7a063f4a` and at a clean stopping point. Working tree is clean
except 7 dirty CD-009 benchmark JSONs (do not commit). Lib build
emits zero `cargo build` warnings; 879/879 lib tests + 891/891 with
lsp-runtime + B1 doctrine linter ALL GATES PASS + B2 verify-replay
ok.

**Codex: act as if work has not been done. Verify everything. Sign
off only what you can independently confirm. Disclose what's still
blocked.**
