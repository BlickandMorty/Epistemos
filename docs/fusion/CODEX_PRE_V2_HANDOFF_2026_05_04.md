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
| `254d6088` | Audit reconciliation | 9 of 17 audit BLOCKERS verified RESOLVED |

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

# 7. Verify the 9 audit RESOLVED claims
grep -n "journal_mode\|F_FULLFSYNC" agent_core/src/oplog.rs | head -3
grep -n "prev_hash" agent_core/src/oplog.rs | head -3
grep -rn "fallbackPrimaryAgentModel" Epistemos/Engine/LocalModelInfrastructure.swift
ls agent_core/src/bin/epistemos_trace.rs
grep -rn "shadow_handle_open_at" Epistemos/Engine/RustShadowFFIClient.swift | head -1
ls agent_core/src/mutations/envelope.rs agent_core/src/provenance/ledger.rs

# 8. Verify the 4 STILL OPEN claims
grep -rn "RetractionPropagated" agent_core/src/      # expect 0 hits
grep -rn "budget_gate\|BudgetGate" agent_core/src/tools/  # expect 0 hits in tools/
grep -n "search_semantic\|search_fulltext\|get_node\|traverse\|create_node\|create_edge\|commit_session" omega-mcp/src/vault.rs  # expect 0 hits
find Epistemos -path "*A2UI*"  # expect empty
```

Don't trust this handoff doc until those greps come back as expected.

---

## §4. What's open (priority queue)

Per `CANONICAL_AUDIT_RECONCILIATION_2026_05_04.md`, only 4 of the
original 17 BLOCKERS remain open:

### V2.1 Phase 8.A first deliverable (gated on user typing "RESUME SUBSTRATE V2"):

**RetractionPropagated typed event variant** — wire it onto the
existing `ClaimLedger` retract semantics. The keystone primitive
already exists; this is the smaller "extend with typed event +
subscriber API + extend ProvenanceConsoleProjectionService to read
the ledger" delivery. Approximate scope:
- 1 new event variant in `agent_core/src/provenance/ledger.rs` (the
  ledger emits today; just needs the typed wrap)
- 1 new subscribe API for downstream consumers (Swift
  ProvenanceConsole + future XPC service)
- Extend `ProvenanceConsoleProjectionService` to subscribe + project
- 2-4 unit tests for the event emission contract

This becomes much smaller than the audit framing because the
provenance plane keystone (`MutationEnvelope` + `ClaimLedger`) is
already shipped.

### Independent slices (can land any time, do NOT need RESUME signal):

1. **W9.6 budget_gate cost-cap → ApprovalModal flow**. Tool wiring
   in `agent_core/src/tools/` + ApprovalModal route. ~2-4 hours.
2. **D2 7-verb MCP graph boundary**. Replace `omega-mcp/src/vault.rs`
   tool surface with the 7 spec verbs (search_semantic / search_fulltext
   / get_node / traverse / create_node / create_edge / commit_session).
   ~1 day.
3. **D3 closed A2UI catalog**. Doctrinally consistent today (no
   catalog = no fallback needed). When a catalog ships, the closed
   contract activates. Probably defers behind V2.1.

### Lower priority partials/notes:

4. **W9.6 chrome stub** provider name + per-session USD columns
   pending pricing-table extension
5. **W9.30 KIVIKVCache** verified to exist in `LocalPackages/mlx-swift-lm/`
   tests now (audit said it didn't exist)
6. **W9.25 GrammarMaskedLogitProcessor real masking**
7. **W9.22 typestate concrete wrappers** (`MlxSession`,
   `HermesProcess`, `AFMPoolEntry`)

### Newly discovered Drift items (added by Pass #3):

8. **Drift A**: CommandCenterRequestCompiler → Rust port. NEW BLOCKER
   per the audit; status not re-verified this session.
9. **Drift B**: three-router consolidation (Swift `ConfidenceRouter` +
   2 Rust routers → 1). Major drift, not BLOCKER.

### Salvage Tier A modules (integration-ready today):

Per `QUICK_CAPTURE_SALVAGE_TRIAGE_2026_05_04.md`, these can land at
any point as their own commits (no DAG dependency):
- `format/` — hybrid JSON+Markdown formats (.mem, .intent, .skill)
- `canon/` — deterministic concept canonicalizer (no LLM)
- `grammar/` — llguidance-based grammar compiler from JSON Schema
- `undo/` — SQLite-backed undo events log

Recommended landing order: `format/` → `canon/` → `grammar/` → `undo/`.
Each is its own commit per the five-question PR discipline.

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

5. `salvage/from-vigorous-goldberg/agent_core_src/` Tier B modules
   (`nightbrain/`, `heal/`, `route/`, `effect/`) are gated on the
   named host wiring per the triage doc. Each has 1-2 specific Swift
   wiring pre-requisites. Don't import them without the wiring.

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
- DAG Phase 8 first deliverable: RetractionPropagated wire (small)

If the user signals RESUME SUBSTRATE V2, the natural Phase 8.A
delivery is:

1. Add `RetractionPropagated` event variant in `provenance/ledger.rs`
2. Add subscriber API on `ClaimLedger`
3. Extend `ProvenanceConsoleProjectionService` to subscribe + project
4. Add 2-4 unit tests for the event emission contract
5. Ship as one commit per five-question PR discipline

Estimated scope: 1-2 days, not the 6-10 weeks the V2 plan listed.
The original estimate assumed the keystone primitives didn't exist.

---

## §9. End of handoff

You have everything you need. The substrate is in much better shape
than the older docs suggested. Don't re-investigate the 9 audit
BLOCKERS the reconciliation marks RESOLVED — that's wasted Codex turns.

If you're picking work without a user signal:
- `format/` salvage Tier A integration is the lowest-risk, highest-clarity
  next move
- W9.6 budget_gate is the next biggest non-V2 fix
- D2 7-verb MCP boundary is the biggest architectural fix that doesn't
  need V2 doctrine

If the user signals RESUME SUBSTRATE V2:
- RetractionPropagated wire on existing ledger (1-2 days, small)

If the user signals RESUME RESEARCH TIER:
- Read `HELIOS_*` docs in `docs/fusion/` first; gated on Week-0 ternary
  experiment per V3 plan

Helios v3 + SCOPE-Rex remains the V3 ultimate goal. Every substrate
commit protects the V3 path from inheriting debt.

End of handoff. Working tree clean. All tests green. Stop point reached.
