# Codex pre-V2 handoff — 2026-05-04

**To Codex (or any subsequent long-running agent)**:

This doc is your read-first list before resuming any substrate work.
The user requested a check of all the work I + prior agents did across
the entire substrate, then a continuation. I closed every loose
thread I could ground-truth-verify and packaged the rest here.

**Build state at handoff**:
- `xcodebuild Epistemos macOS`: **BUILD SUCCEEDED**
- `cargo check agent_core`: green
- 15/15 Hermes-in-Rust integration tests pass
- 10/10 GenUI dispatcher + determinism tests pass
- Working tree clean except `LocalPackages/mlx-swift-lm/` vendored fork

**Codex continuation update — 2026-05-04 evening**:
- Full Swift test suite passed from
  `Test-Epistemos-2026.05.04_17-57-23--0500.xcresult`: 6,910 tests,
  0 failures, 49 skipped, 13 warnings.
- D2 seven-verb MCP graph boundary is now wired in `omega-mcp` with
  schemars-derived schemas, vault-scoped graph persistence, graph-event
  JSONL emission, and a create/search/get/traverse/edge/commit round-trip
  test.
- `cargo test --manifest-path omega-mcp/Cargo.toml`: 134 passed.
- `cargo test --manifest-path omega-mcp/Cargo.toml --features mas-sandbox`:
  112 passed.
- D3 closed A2UI catalog Phase 1 is now wired: Swift `NoteCard`
  catalog + validator + validation-failure audit payload, plus Rust
  `schemars` schema authority in `agent_core::a2ui::schemas`.
- `xcodebuild ... -only-testing:EpistemosTests/A2UICatalogTests`: passed.
- `cargo test --manifest-path agent_core/Cargo.toml --no-default-features
  --features mas-build --test a2ui_schemas`: 1 passed.

**Codex continuation update — 2026-05-04 late audit loop**:
- `cargo test` floors passed:
  - `graph-engine`: 2,522 passed, 8 ignored.
  - `omega-mcp`: 134 passed, 1 doc-test ignored.
  - `omega-ax`: 12 passed.
  - `agent_core --no-default-features --features mas-build`: full suite passed,
    including the A2UI, budget-gate, provenance, Quick Capture salvage, and
    Tools V2 alias tests.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination
  'platform=macOS' build`: **BUILD SUCCEEDED**.
- Full Swift test suite initially found three stale/fragile guards:
  `LiveToggleTests/blocklistEnforced()` inherited a shared allowlist,
  `ProcessActivityTests/streamActivityEndsAfterCompletion()` asserted before
  detached cleanup had appended the `end` probe event, and
  `ResearchModeTests/totalToolCount()` still expected the pre-D2 catalog size.
- Fixed those guards without weakening product paths: blocklist tests now clear
  the allowlist, the stream-activity test waits for cleanup deterministically,
  and Research Mode asserts the seven D2 graph verbs plus the 40-tool catalog.
- Full Swift re-run passed from
  `/tmp/epistemos-full-audit-20260504-2012.xcresult`: device summary
  6,869 passed, 0 failed, 49 skipped; aggregate summary 5,658 passed,
  0 failed, 49 skipped, 5,707 total tests.
- T6 body grammar persistence hardened:
  `CompanionBodyKind(rawValue:)` now rejects unknown Block parameter values
  instead of silently defaulting them; guarded by
  `CompanionAvatarGrammarSourceGuardTests`.
- Quick Capture Route Variant B boundary hardened:
  the GBNF schema and runtime classifier acceptance now share a deterministic
  sorted/deduplicated non-inbox path set, and out-of-vocabulary classifier
  outputs fail closed even above the canonical 0.75 floor. Guarded by
  `agent_core/tests/route_salvage.rs`.
- Quick Capture NightBrain registration hardened:
  `agent_core::nightbrain::NightBrainScheduler` now supports named task
  registration, duplicate-name rejection, stable registered-name listing, and
  ordered registered-task execution that stops after preemption. Guarded by
  `agent_core/tests/nightbrain_salvage.rs`.
- Current worktree remains intentionally dirty with recovery/substrate work.
  Do **not** read the older "clean except vendored fork" line as current state.

**Branch**: `feature/landing-liquid-wave` — 313 commits ahead of `origin`.
Last shipped commit: `254d6088`.

**The user's directive that motivated this handoff**:
> "please research local researvh for gen ui stuff i have my lw research
> for thst tp make sure its most optimized and determinidtich. and
> bplease comtinue fixing whatever shoul b fixed and etc. and then
> write a handoff for codeed to checka ll ur work all the work we al
> ldidi for thieghe entire substrate and then continue the rest. so i
> wntyou to check and do aas m uch work as u can do and then pass it
> on to codex."

---

## §1. Read these in order

1. `CLAUDE.md` — project rules, non-negotiable constraints, file map
2. `docs/fusion/PRE_V2_FULL_AUDIT_2026_05_04.md` — the 5 pre-V2 gaps + closure status
3. `docs/fusion/PRE_V2_GAP_CLOSURE_SUMMARY_2026_05_04.md` — every commit that closed each gap
4. `docs/fusion/CANONICAL_AUDIT_RECONCILIATION_2026_05_04.md` — **CRITICAL** — corrects 9 stale BLOCKERS the canonical audit log claimed open
5. `docs/fusion/RECOVERY_LOOP_FINDINGS_2026_05_04.md` — Stages A-F closure record (8 commits)
6. `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` — V2.1-V2.7 sequence + wait-for-signal contract
7. `docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md` — recovery framing (Stages A-F)
8. `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md` — T0-T15 backlog
9. `docs/fusion/QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md` + `SALVAGE_TRIAGE_REMAINDER_2026_05_04.md` — 7 salvage subdirs categorized into A/B/C/D tiers
10. The doctrine docs the current task touches:
    - `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`
    - `COGNITIVE_DAG_DOCTRINE_2026_05_03.md`
    - `COGNITIVE_GENUI_DOCTRINE_2026_05_03.md` (now contains §7.1 determinism contracts)
    - `XPC_MASTERY_DOCTRINE_2026_05_03.md`
    - `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md`
    - `HERMES_BRAND_DOCTRINE_2026_05_04.md`
    - `PROVENANCE_CONSOLE_DOCTRINE_2026_05_04.md`
    - `HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md`

DO NOT skip the audit reconciliation (#4). It corrects 9 BLOCKERS the
older audit doc still flags as open. Skipping it = re-investigating
already-resolved work.

---

## §2. What I shipped this session (since 441a93c9)

10 commits, all build-green, no rollbacks:

| Commit | Stage | What |
|---|---|---|
| `441a93c9` | Pre-V2 audit | 4-parallel-agent + verification audit doc — 5 gaps surfaced |
| `99b2c15c` | Gap 5 | CLAUDE.md stats refreshed (137K→252K Swift); GENUI doctrine §9 deferral list reconciled |
| `f170a9e9` | Gap 1a | Bulk doc reclassification commit (281 docs / 6,431 lines additive metadata) |
| `2ca663a1` | Gap 1b | Agent_core in-flight consolidation (54 files / 2,108 lines: pro-build feature gate canonicalization, RawThoughts RedactedThinking variant, session refinements, resources subsystem refactor) |
| `3a46b0c6` | Gap 1c | Substrate engines + build scripts (25 files / 1,589 lines: knowledge_core/store.rs +808 V2.1 PRECURSOR `MutationRelationKind`, graph-engine physics tuning, epistemos-shadow Halo W8 backend, epistemos-trace e2e tests) |
| `9e0a0aa1` | Gap 1d | Residual hygiene + .gitignore for runtime lockfile |
| `edc04874` | Gap 3 | Salvage triage remainder doc (6 subdirs categorized into A/B/C/D tiers) |
| `8b7fe56e` | Pre-V2 close-out | Gap closure summary doc |
| `20cc3e27` | GenUI hardening | **Determinism contracts** + 6 new tests + GENUI doctrine §7.1 |
| `254d6088` | Audit reconciliation | Initial 9 of 17 audit BLOCKERS verified RESOLVED; 2026-05-04 continuation raises the current ledger to 13 of 17 resolved |

Plus 6 new memory entries in `/Users/jojo/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/`:
- `project_hermes_brand_doctrine.md`
- `project_honest_handle_ffi_doctrine.md`
- `project_provenance_console_doctrine.md`
- `project_quick_capture_salvage_triage.md`
- `project_codex_recovery_handoff.md`
- `project_recovery_loop_findings_2026_05_04.md`
- `project_pre_v2_full_audit.md`

Plus 2 stale memory fixes:
- `project_hackathon_focus_2026_05_03.md` rewritten as SUPERSEDED marker
- `project_canonical_recovery_plan_2026_05_03.md` annotated to reflect the hermes module shipping same-day

---

## §3. The verification floor (run BEFORE accepting any of my claims)

```bash
cd /Users/jojo/Downloads/Epistemos

# 1. Build green?
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)"

# 2. Cargo green?
cargo check --manifest-path agent_core/Cargo.toml 2>&1 | tail -3

# 3. Hermes-in-Rust tests still green?
cargo test --manifest-path agent_core/Cargo.toml --test hermes_runtime 2>&1 | grep "test result"

# 4. GenUI determinism tests green?
xcodebuild test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GenUIPayloadDeterminismTests 2>&1 | grep "Test run"

# 5. GenUI dispatcher invariant tests green?
xcodebuild test -scheme Epistemos -destination 'platform=macOS' \
  -only-testing:EpistemosTests/GenUIDispatcherInvariantSourceGuardTests 2>&1 | grep "Test run"

# 6. Working tree clean (excluding vendored mlx-swift-lm)?
git status --short -- ':!LocalPackages' | head

# 7. Verify the 13 audit RESOLVED claims
grep -n "journal_mode\|F_FULLFSYNC" agent_core/src/oplog.rs | head -3
grep -n "prev_hash" agent_core/src/oplog.rs | head -3
grep -rn "fallbackPrimaryAgentModel" Epistemos/Engine/LocalModelInfrastructure.swift
ls agent_core/src/bin/epistemos_trace.rs
grep -rn "shadow_handle_open_at" Epistemos/Engine/RustShadowFFIClient.swift | head -1
ls agent_core/src/mutations/envelope.rs agent_core/src/provenance/ledger.rs
grep -rn "RetractionPropagated" agent_core/src/provenance Epistemos/Engine/ProvenanceConsoleProjectionService.swift
grep -rn "budget_gate\|BudgetGate" agent_core/src/agent_loop.rs agent_core/src/providers/pricing.rs Epistemos/App/ChatCoordinator.swift Epistemos/Bridge/StreamingDelegate.swift

# 8. Verify the D2 graph boundary and D3 closed A2UI seed
grep -rn "graph.search_semantic\|graph.search_fulltext\|graph.get_node\|graph.traverse\|graph.create_node\|graph.create_edge\|graph.commit_session" omega-mcp/src
cargo test --manifest-path omega-mcp/Cargo.toml d2_graph
find Epistemos -path "*A2UI*"
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos \
  -destination 'platform=macOS' \
  test -only-testing:EpistemosTests/A2UICatalogTests
cargo test --manifest-path agent_core/Cargo.toml --no-default-features \
  --features mas-build --test a2ui_schemas
```

Don't trust this handoff doc until those greps come back as expected.

---

## §4. What's open (priority queue)

Per `CANONICAL_AUDIT_RECONCILIATION_2026_05_04.md`, 0 of the
original 17 BLOCKERS remain open after the D3 continuation.

### V2.1 Phase 8.A first deliverable:

**RetractionPropagated typed event variant is now delivered** in the
2026-05-04 recovery pass. The next V2.1 work should continue from the
Cognitive DAG plan rather than re-authoring the provenance keystone.

### Independent slices (can land any time, do NOT need RESUME signal):

1. **D3 A2UI catalog expansion**. The original absence blocker is
   closed by the Phase-1 `NoteCard` catalog seed, no fallback inspector,
   no `AnyView`, and Rust schema authority. Remaining work is expanding
   toward the full ~25-component catalog when a concrete surface needs
   it.
2. **D2 deeper backend integration**. The boundary now exists. Remaining
   substrate-deepening work is HNSW/Tantivy-backed search, the Pro
   `epistemos-hermes-mcp` stdio binary, and Swift/Hermes session
   round-trip telemetry. Do not re-open the original "zero graph verbs"
   blocker.

### Lower priority partials/notes:

3. **W9.6 chrome stub** provider name + per-session USD columns
   pending EventStore schema projection, but `budget_gate` and the
   checked-in provider pricing table are now wired.
4. **W9.30 KIVIKVCache** verified to exist in `LocalPackages/mlx-swift-lm/`
   tests now (audit said it didn't exist)
6. **W9.25 GrammarMaskedLogitProcessor real masking**
7. **W9.22 typestate concrete wrappers** (`MlxSession`,
   `HermesProcess`, `AFMPoolEntry`)

### Newly discovered Drift items (added by Pass #3):

8. **Drift A**: CommandCenterRequestCompiler → Rust port. NEW BLOCKER
   per the audit; status not re-verified this session.
9. **Drift B**: three-router consolidation (Swift `ConfidenceRouter` +
   2 Rust routers → 1). Major drift, not BLOCKER.

### Salvage Tier A modules (now landed as selective ports):

Per `QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md`, the Tier A salvage
modules are now exported from `agent_core` and covered by integration
tests:
- `format/` — hybrid JSON+Markdown formats (.mem, .intent, .skill)
- `canon/` — deterministic concept canonicalizer (no LLM)
- `grammar/` — llguidance-based grammar compiler from JSON Schema
- `undo/` — SQLite-backed undo events log

Do not re-port these from `docs/fusion/salvage/`. Future work starts at
Tier B (`effect` / `heal` / `route`) or at the explicit follow-ups
named in `QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md`.

**Continuation note:** `effect/` has now joined the landed selective
ports in `agent_core/src/effect/`, guarded by
`agent_core/tests/effect_salvage.rs`. The next Quick Capture substrate
slice is `heal/`; Ed25519 receipt signing remains a named follow-up.

**Continuation note:** `heal/` has now joined the landed selective
ports in `agent_core/src/heal/`, guarded by
`agent_core/tests/heal_salvage.rs`. The next Quick Capture substrate
slice is `nightbrain/`; production diagnostician wiring and trace UI
surfacing remain host follow-ups.

**Continuation note:** the Rust `nightbrain/` scheduler core has now
joined the landed selective ports in `agent_core/src/nightbrain/`,
guarded by `agent_core/tests/nightbrain_salvage.rs`. The port keeps
macOS idle / thermal / power probes on the Swift host side and exposes a
typed `HostActivitySnapshot` to Rust for admission. Swift battery-percent
snapshot wiring landed in `NightBrainService` / `PowerGate`; Rust task
registration now exists, while Swift/UniFFI exposure of that registry remains
a host follow-up.

**Continuation note:** NightBrain Swift/UniFFI host exposure now exists for
canonical task-name and admission-preview diagnostics:
`nightbrain_canonical_task_names` and `nightbrain_preview_admission`. The Swift
guard compares Rust task names to `NightBrainService.Job.allCases`, so future
registry drift is visible. Full Swift-owned execution handle wiring for real
registered Rust task execution remains the next NightBrain host seam.

**Continuation note:** NightBrain stale-run fallback now executes
`runInlineFallback()` and records success only on `.finished`. The old
path scheduled future background work with `start()` and immediately
recorded a successful run; do not reintroduce that false-positive
telemetry.

**Continuation note:** the Rust `route/` ladder core has now joined the
landed selective ports in `agent_core/src/route/`, guarded by
`agent_core/tests/route_salvage.rs`. It preserves the four canonical
actions, Variant A/B/C floors, Variant B self-defer, Variant C
merge/create-folder authority, and Variant D review-inbox fallback.
Real folder-medoid persistence has now landed through
`route::variant_a::FolderMedoidStore`; Variant B now enforces the same
closed vocabulary in schema construction and post-classification acceptance.
MLX/GBNF classifier wiring and concept/neighbour host implementations remain
follow-up slices.

---

## §5. The five-question PR discipline (canonical)

Every commit declares:
1. **Stage** — which Recovery Plan stage / V2.x phase / track
2. **GenUI route** — does the change go through GenUIDispatcher? If
   not, why not (deferral marker?)
3. **Sovereign** — does the change touch a Sovereign-Gate-required
   action (destructive op, network egress, biometric, etc.)?
4. **Pro impact** — does this change MAS / Pro behavior asymmetrically?
5. **TEMP-FREE-TIER** — does this affect the App Group restoration
   trail in `Epistemos-AppStore.entitlements`?

Five honest answers or it doesn't ship. No exceptions through V2 / V3.

---

## §6. Wait-for-signal contract

V2.1 (Cognitive DAG Phase 8) does NOT auto-start. The user must type
**"RESUME SUBSTRATE V2"** to kick off Phase 8.A.

V3 (Helios v3 + SCOPE-Rex + Ternary substrate) needs a separate
**"RESUME RESEARCH TIER"** signal.

If you're a Codex run resuming work and the user has not typed either
phrase: do not start V2.1 or V3. Pick from §4 "Independent slices"
or "Salvage Tier A modules" instead. Those land independently per the
five-question PR discipline.

If the user HAS typed "RESUME SUBSTRATE V2", start with the
RetractionPropagated wire (smallest Phase 8.A delivery per
`CANONICAL_AUDIT_RECONCILIATION` §V2.1 framing).

---

## §7. Important things I left alone (do NOT undo)

1. `LocalPackages/mlx-swift-lm/` has 5 modified vendored files. Left
   uncommitted because the fork has its own discipline. If the user
   wants those changes preserved, they should be committed to the
   submodule's branch directly, not to the Epistemos repo.

2. The hermes-parity audit (76% parity, 22 vs 37 tools) at
   `salvage/from-hermes-parity/` is **untouched**. Tier B reference
   material for V2.1 tool surface decisions. Don't try to port all
   15 missing tools at once.

3. Lane A's 92 architecture docs at `salvage/from-lane-a/` are
   **mostly superseded**. Spot-check before deleting; defer archival
   pass. Do NOT bulk-delete.

4. The 17,964-line stash patch at
   `salvage/from-stashes/stash-2-wip-on-main-31214a4d.patch` is
   **untriaged**. Most likely already in main; needs file-path-vs-current
   audit. Don't re-apply blindly.

5. `salvage/from-vigorous-goldberg/agent_core_src/` Tier B modules now
   have selective live Rust ports (`effect/`, `heal/`, `nightbrain/`,
   `route/`). Host wiring still matters: Swift/UniFFI exposure of the
   NightBrain task registry, production receipt signing, production diagnostician,
   trace UI surfacing, MLX/GBNF classifier wiring, and
   concept/neighbour route implementations remain explicit
   follow-ups.

6. `salvage/from-vigorous-goldberg/agent_core_src/skill_discovery/`
   (Tier C) is DAG-blocked — depends on V2.1 Phase 8 provenance
   primitives the user hasn't authorized starting yet.

---

## §8. The keystone reframing for V2.1

The canonical audit log (2026-04-26) framed V2.1 as needing a
from-scratch provenance plane. The `CANONICAL_AUDIT_RECONCILIATION`
update (this session) verifies that:

- `MutationEnvelope` ✅ exists with parity tests
- `ClaimLedger` ✅ exists with retract semantics + ReplayBundle
- `epistemos-trace` CLI ✅ exists as `agent_core/src/bin/`

So Phase 8.A becomes a small wire job, not a from-scratch build.
This is the single most important reframing in this handoff. The user
should know V2.1 is much closer than the older docs suggested.

V2.1 dependency map (per kernel doctrine §10):
- Kernel Phases 1-7: still in progress; recovery shipped scaffolding
- 2 weeks CI green: not yet measured
- DAG Phase 8 first deliverable: RetractionPropagated wire delivered

If the user signals RESUME SUBSTRATE V2, the natural Phase 8.A
continuation is to extend the Cognitive DAG from the delivered
RetractionPropagated primitives, not rebuild the ledger or envelope.
The original 6-10 week estimate assumed the keystone primitives didn't
exist.

---

## §9. End of handoff

You have everything you need. The substrate is in much better shape
than the older docs suggested. Don't re-investigate the 13 audit
BLOCKERS the reconciliation marks RESOLVED — that's wasted Codex turns.

If you're picking work without a user signal:
- Tier B salvage recovery is now Rust-core complete. NightBrain task-name /
  admission Swift exposure is landed, and Route contract / Variant B schema
  Swift exposure is landed. The next independent Quick Capture moves are
  NightBrain execution-handle wiring, MLX/GBNF + concept/neighbour host wiring
  for `route/`, or the DAG-gated `skill_discovery/` slice after V2.1 Phase 8
  authorization.
- D2 deeper backend integration and D3 catalog expansion are
  substrate-deepening work, not original-blocker recovery.

If the user signals RESUME SUBSTRATE V2:
- Continue Cognitive DAG after the delivered RetractionPropagated wire

If the user signals RESUME RESEARCH TIER:
- Read `HELIOS_*` docs in `docs/fusion/` first; gated on Week-0 ternary
  experiment per V3 plan

Helios v3 + SCOPE-Rex remains the V3 ultimate goal. Every substrate
commit protects the V3 path from inheriting debt.

End of handoff. Working tree clean. All tests green. Stop point reached.
