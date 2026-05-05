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

**Pre-merge blocker (P1):** ~126 clippy issues across 5 crates will
fail the CI clippy gate (ci.yml:122-131) on the next PR to main.
Pre-existing, not a regression from this session, but blocking.
**§1 below has the full breakdown + recommended cleanup approach.**

**External-verification gates:** CD-004 (V2.1 8.A-8.G authority flip
prerequisites) is BLOCKED on Codex independent verification. CD-008
full closure needs full xcodebuild test pass + cargo test --all-targets
+ manual runtime smoke. **§2 below has the verification checklist.**

**State:candidate items held for sign-off** (5 briefs, ~50 hours of
implementation work, ZERO LOC landed without explicit Codex/user
authorization): A1 redb persistent backend, Static/Dynamic
discriminator, B1-B3 phase work (Phases 21-25 + W7-A through W7-J +
W8 + W6-A through W6-I). **§3 below has each one with sign-off
questions.**

**Held-for-sign-off small items**: tirith Pro-gating, 3 orphan file
deletions (904 LOC), provenance_ledger architectural drift. **§4
below.**

**Other Open APP_ISSUES** (P0/P1): SwiftUI hot-loop, model install
detection, Opus 4.1 Main Chat regression, idle memory regression.
**§5 below.**

**Tier-1 doctrine lifts pending from B-bonus briefs** (15 doctrine
additions, no code, ~5-15 lines each): **§6 below.**

---

## §1 — Pre-merge blocker: project-wide clippy debt (~126 issues, P1)

**Logged:** `docs/APP_ISSUES_AUTO_FIX.md` ISSUE-2026-05-05-001 (P1)

**Symptom:** `cargo clippy --target aarch64-apple-darwin -- -D warnings`
fails per crate. CI workflow at `.github/workflows/ci.yml:122-131`
runs this exact command for each crate (`graph-engine`, `epistemos-core`,
`omega-ax`, `omega-mcp`, `agent_core`) and will fail hard on the
next PR to main.

**Why hasn't been caught:** CI's `on:` trigger is `push: [main]` or
`pull_request: [main]`. The `feature/landing-liquid-wave` branch has
never run CI — only `release.yml` has. The clippy gate hasn't fired
yet on this branch's commits.

**Per-crate scope:**

| Crate | Errors under `-D warnings` |
|---|---|
| agent_core | 42 (1 hard error + 41 warnings) |
| epistemos-core | 54 |
| omega-mcp | 16 |
| omega-ax | 8 |
| graph-engine | 6 |
| **Total** | **~126** |

**The 1 hard error** (must-fix even without `-D warnings`):

`agent_core/src/etl/ffi.rs:180` — `etl_queue_free_string` is a
`pub extern "C" fn` that does `CString::from_raw(ptr)` but the
function itself isn't marked `unsafe`. Lint:
`clippy::not_unsafe_ptr_arg_deref`. The unsafe block inside is fine;
the lint wants the function signature itself to be `unsafe`. Traces
back to commit `666aa9ba` (R16 ETL foundation).

**Recommended cleanup approach:**

1. **Per-crate, not all-at-once.** Each crate is its own `Cargo.toml`
   workspace member. Run `cargo clippy --fix --lib --target
   aarch64-apple-darwin` per crate first to apply mechanical fixes,
   then manually address what remains.
2. **Skip API-changing fixes.** Don't refactor too-many-args functions
   or box large `Err` variants without explicit user sign-off — those
   are API changes.
3. **For the hard error**: add `#[allow(clippy::not_unsafe_ptr_arg_deref)]`
   to `etl_queue_free_string` with a SAFETY comment explaining why
   the FFI function deliberately doesn't use the `unsafe fn`
   signature (Swift caller via UniFFI doesn't see the Rust `unsafe`).
4. **Verification:** after cleanup, run `cargo clippy --target
   aarch64-apple-darwin -- -D warnings` per crate; all must exit 0.

**Sign-off question for user:** authorize Codex to do this cleanup
in one PR (no API changes) before opening the next merge to main?

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
   InMemoryDagStore + the future redb backend (when A1 lands).
4. **Authority flip criteria** — doctrine §10 two-week CI green
   window must complete before flipping. With CI not running on
   feature branches today (see §1), this gate is effectively
   blocked until either (a) the branch merges to main, OR (b) CI
   trigger is extended to feature branches.

**Codex action:** decide whether to (i) sign off CD-004 now, (ii)
require additional substrate before sign-off (and what), or (iii)
adjust the authority-flip criteria.

### CD-008 — Full-app verification PARTIAL

**Closed by this session:**

| Surface | Result |
|---|---|
| `cargo test --lib` (agent_core, default features) | 879 / 879 |
| `cargo test --lib --features lsp-runtime` | 891 / 891 |
| `cargo test` (graph-engine) | 2522 / 2522 (8 ignored) |
| `cargo test` (omega-mcp) | 143 / 143 |
| Xcode `Epistemos` test-build | TEST BUILD SUCCEEDED |

**Still required (Codex must execute):**

1. **Full `xcodebuild test` pass** for the `Epistemos` scheme on
   `platform=macOS,arch=arm64` (not just `build-for-testing`). The
   Swift Testing suite of 346 test files was NOT exercised in this
   session. Command:
   ```
   ./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj \
     -scheme Epistemos -destination "platform=macOS,arch=arm64" \
     -derivedDataPath .derived-data-codex-verify \
     -clonedSourcePackagesDirPath .spm-cache \
     CODE_SIGNING_ALLOWED=NO -resultBundlePath TestResults.xcresult
   ```
2. **`cargo test --all-targets`** for every crate (this session
   targeted `--lib` for speed). Integration tests + bins + examples
   not run.
3. **Pro feature surface tests:**
   `cargo test --no-default-features --features pro-build,lsp-runtime`
   for agent_core. CI gate B3 covers this on every push (when CI
   runs); verify locally for sign-off.
4. **Manual runtime smoke** of: app bootstrap, Settings → Diagnostics
   panels (Cognitive DAG stats, Halo ledger ribbon, Search Fusion
   health row), LSP editor flow, Sovereign Gate prompts.

**Why manual:** the autonomous session can't drive the GUI; the
Diagnostics panels + Halo + LSP editor + Sovereign Gate are user-
visible surfaces that require human inspection of the rendering and
interaction behavior.

**Codex action:** run the test commands, capture raw logs, then
either ship the manual runtime smoke session yourself OR mark CD-008
as needing user-time on a real Mac.

---

## §3 — State:candidate items held for sign-off

Per the canon promotion protocol installed today
(`docs/CANON_HARDENING_PROTOCOL_2026_05_05.md`), doctrine-shaping
work goes through `state: candidate` (a brief that surveys the
substrate, recommends a path, queues sign-off) BEFORE landing as
`state: canon`. The 2026-05-05 session held 5 candidate briefs
without implementing them — Codex/user sign-off is required before
implementation lands.

### 3.1 — A1: redb persistent DagStore backend

**Brief:** `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md`

**Why:** today the only `DagStore` impl is `InMemoryDagStore`. A
reboot loses the entire Cognitive DAG. V2.1 Phase 8.H ("DAG authority
flip") cannot proceed without durable persistence.

**Scope:** 5 slices, ~5-9 hours implementation + 2-3 hours review.

| Slice | What |
|---|---|
| 1 | Cargo dep (redb 2.x + bincode) + skeleton `RedbDagStore` (unimplemented stubs) |
| 2 | put_node + get_node + durability proof test (insert / drop / reopen / read) |
| 3 | put_edge with CD-005 capability binding + edges_from/edges_to + parameterized parity tests vs InMemoryDagStore |
| 4 | merkle_root + snapshot byte-identity vs InMemoryDagStore |
| 5 | dispatch wiring + opt-in feature flag (`cognitive-dag-redb`), default OFF until verified |

**Test surface:** ~19 new tests on top of existing 132 cognitive_dag.

**Sign-off questions for user:**
1. Single unified slice or 5 slices with verification beats between each?
2. Approve the redb 2.x crate selection (vs sled / rocksdb / lmdb / roll-our-own)?
3. Default state for `cognitive-dag-redb` feature flag — OFF (safer) or ON (commits to redb as canonical)?

### 3.2 — Static/Dynamic discriminator (Q2 recommendation)

**Brief:** `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md`

**Why:** the user asked 2026-05-05: "Artifact primitive that
distinguishes Static Note from Dynamic AI Weight." Survey shows the
distinction is already in the substrate (8 of 10 NodeKind variants
are static, 2 dynamic-rooted via Companion/Model). Recommendation:
Option C + Option B together — add a method, document the rule, no
new wrapper type.

**Scope:** ~30 LOC + 1 test + doctrine paragraph.

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

**Sign-off questions for user:**
1. Approve Option C + B (method + doctrine paragraph) over Option A
   (top-level wrapper enum)?
2. Land in one slice or as two slices (method first, doctrine after)?

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

**Recommendation:** Pro-gate the `tirith` module + the `approval.rs:485`
caller behind `#[cfg(feature = "pro-build")]`.

**Why:** `tirith.rs:268` spawn is runtime-gated under MAS sandbox
(user-installed binary not in any sandbox-approved path → fallback
returns) but compile-reachable. Pro-gating removes the subprocess-
spawn surface from the MAS binary (App Review cleanliness) while
losing zero MAS capability.

**Sign-off:** approve Pro-gating of `agent_core::tirith` + caller?

### 4.2 — Three orphan source files in `agent_core/src/tools/`

**Source:** `docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md` §"Orphan source
files (action required)"

**Files:**
| File | LOC | Status |
|---|---|---|
| `agent_core/src/tools/code_execution.rs` | 105 | Not declared in lib.rs — doesn't compile, doesn't ship |
| `agent_core/src/tools/graph_query.rs` | 276 | Same |
| `agent_core/src/tools/note_tools.rs` | 523 | Same |

**Total: 904 LOC of orphan source.**

**Recommendation:** delete (matches user's explicit 2026-05-05
"if i dont need something get rid of it" directive on
LSPServerProcess deletion).

**Sign-off:** approve deletion of all three files?

### 4.3 — `provenance_ledger()` architectural drift

**Source:** commit 90bdddee + `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md`
C2 row.

**Finding:** `agent_core::bridge::provenance_ledger()` global is
never written to under current dispatch architecture. Every
dispatch helper's `mirror_write` writes to `cognitive_dag_store()`
instead. The provenance_ledger global was promoted from `Mutex` to
`RwLock` for read-heavy access — but it has no readers besides the 3
FFI sites that now use `.read()`.

**Codex action:** decide whether to (i) wire dispatch helpers to
also write to provenance_ledger (parallel mirror), (ii) delete the
provenance_ledger global since cognitive_dag_store is now
authoritative, or (iii) keep provenance_ledger as a dead canonical
fallback for future use.

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

## §6 — Tier-1 doctrine lifts pending from B-bonus briefs (15 items, no code, ~5-15 lines each)

These are doctrine additions that codify already-present capabilities
or set guardrails for future work. Each is small (5-15 lines into the
doctrine doc) but doctrine-shaping per the canon promotion protocol.

### From B1 (BIOMETRIC_TAMAGOTCHI_BRAINEXPORT) — 5 lifts

1. **Session Authority Token contract** → `EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2 (Sovereign Gate) addendum. The 8 always-fresh categories + the Authority/Expired/OutOfScope/WrongBinding/FreshBiometricRequired verdict enum.
2. **Confidence meter doctrine** → new doctrine Annex (A.17 candidate). 6 composite-confidence signals + 70% threshold + diagnose-first re-learn + bounded-budget rules.
3. **UI mode toggle** (Pixel mode / Tactical mode) → §4.0 (UX posture, the C4 entry) addendum. Tier-locked: Tactical required for Pro/enterprise.
4. **Accessory metaphor doctrine** (LoRAs as equipment) → Annex A.5 (continual learning) addendum. UX wrapper over QOFT/QDoRA/QPiSSA.
5. **Brain Artifact contract** → §3 (Tier Matrix) addendum. Compiled-binary + signed-bundle + license-keyed-fingerprint contract.

### From B2 (LIVE_FILES_AND_SUBSTRATE) — 5 lifts

6. **Cell-organism metaphor as design generator** → new doctrine Annex (A.18 candidate). Generates four design rules (autonomy, message-passing, apoptosis as feature, millions-of-cells homeostasis).
7. **Determinism gradient (Cognitive Weight) as canonical mechanism** → §4.0 (UX posture) addendum + §2.2 invariant #4 (tiered determinism) addendum.
8. **Stateful Rotor pattern + sub-5ms tick-budget contract** → §7 build-order graph entry + §6 forbidden ("no polling on the Live Files surface").
9. **Closed-grammar conditional logic** → §6 forbidden (no `eval`/JS/Python in user-composed Live File logic).
10. **Subprocess audit closure (MoLoRA + QLoRA ports)** → §2.2 invariant #2 addendum. Hermes already removed 2026-05-05; MoLoRA + QLoRA are the remaining structural debt.

### From B3 (OBSCURA_BROWSER) — 5 lifts

11. **Three structural reasons subprocess fails** (versioning skew, signing complexity, lifecycle race) → §2.2 invariant #2 addendum. Names the rationale for the existing invariant.
12. **Library-embed pattern as canonical engine integration** → §2.2 invariant #2 addendum. Same rule applies to any future engine integration (audio, video, OCR, etc.).
13. **Closed-vocabulary citations as anti-hallucination structural guarantee** → §6 forbidden ("hallucinated citations are structurally impossible") + Annex A.13 (Knowledge Sieve / Gap Winner Rule) addendum.
14. **V8 dedup discipline (`[patch.crates-io]`)** → new doctrine note in §9 Canonical Code Anchors. Forward-staging contract for when Obscura + deno_core land.
15. **Eidos thesis (local-first inversion of Exa)** → new doctrine note pairing with §4.3 (Halo). Halo = always-on contextual surface; Eidos = explicit-search surface.

**Codex action:** these lifts can land as a single doctrine PR (one
commit per lift, or one bundled commit) with NO code changes. They're
purely doctrine additions that codify future-implementation contracts.
Estimated: 1-2 hours total work; landing them now means future
implementation slices have canonical targets.

**Sign-off:** approve a doctrine-only PR landing all 15 lifts?

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

1. The 5 state:candidate implementation slices (§3 above).
2. The 3 orphan-file deletions in `agent_core/src/tools/` (§4.2 above).
3. Anything that crosses the canon promotion protocol's "doctrine-
   shaping work gets one explicit sign-off cycle before code lands"
   line.

**Three items Codex SHOULD auto-execute (autonomous canonical work):**

1. The clippy cleanup (§1) — pre-merge blocker, mechanical fixes
   only, no API changes.
2. The CD-008 verification commands (§2) — confirm local test green
   matches Codex's view; manual runtime smoke is human-time work.
3. The 15 Tier-1 doctrine lifts (§6) — purely doctrine additions, no
   code changes; can land as single PR.

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
7. `docs/APP_ISSUES_AUTO_FIX.md` — 6 Open issues including
   ISSUE-2026-05-05-001 clippy debt P1 + 4 runtime issues
8. `docs/AGENT_PROGRESS.md` — full 2026-05-05 ledger (items 1-23)
9. **State:candidate briefs** (held for sign-off):
   - `docs/A1_REDB_PERSISTENT_BACKEND_SCOPING_2026_05_05.md`
   - `docs/STATIC_NOTE_VS_DYNAMIC_WEIGHT_DELIBERATION_2026_05_05.md`
   - `docs/B1_BIOMETRIC_TAMAGOTCHI_BRAINEXPORT_LIFT_TARGETS_2026_05_05.md`
   - `docs/B2_LIVE_FILES_AND_SUBSTRATE_LIFT_TARGETS_2026_05_05.md`
   - `docs/B3_OBSCURA_BROWSER_LIFT_TARGETS_2026_05_05.md`
10. **Standalone audits** (canonical, no further action):
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
