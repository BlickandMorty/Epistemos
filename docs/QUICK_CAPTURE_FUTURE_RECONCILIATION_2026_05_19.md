---
state: quick-capture-future-reconciliation
created_on: 2026-05-19
purpose: Continuity-of-knowledge doc — exactly what's still locked on the Quick Capture branch, what conditions must hold before we come back, and a step-by-step reconciliation playbook a future Claude/Codex can pick up cold.
---

# Quick Capture — Future Reconciliation Plan

## Snapshot

- **Branch:** `claude/vigorous-goldberg-3a2d35`
- **Branch HEAD SHA (pinned for reproducibility):** `0e0234d9f1032942a6d1e49ffa25ecb2c28bebca`
- **Original design oracle (already on main):** `docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` (3,715 lines)
- **Salvage so far:** 104 files, ~12,900 lines across 4 commits (see "Already salvaged" below)
- **Total branch additions:** ~22,000 lines of net-new code
- **Still locked on branch:** ~9,000+ lines of code we deliberately did NOT cherry-pick

## The Quick Capture original 12-phase plan — what landed where

| Phase | Description | Status on main |
|-------|-------------|----------------|
| **0.5** | First-run vault bootstrap | ✅ **Salvaged** — `Epistemos/Vault/FirstRunBootstrap.swift` + test |
| **1** | Hybrid file formats `.mem`/`.soul`/`.skill`/`.intent` + typed schemas | ✅ Schemas salvaged (8 v1 JSON files); format/ parsers locked (diverged) |
| **2** | GBNF/llguidance compiler + Tool registry | ✅ Tool trait + 74-tool catalog salvaged into `tools_v2/`; grammar/ compiler locked (diverged) |
| **2C** | Variant runner + circuit breaker | ✅ Salvaged — `tools_v2/breaker.rs` + `tools_v2/runner.rs` |
| **2D** | Semantic cache layer | ✅ Salvaged — `cache/mod.rs` (SQLite-backed) |
| **2E** | Canary native `reason.think` Tool impl | ✅ Salvaged — `tools_v2/reason_think.rs` |
| **3** | `structure.route_folder` 4-variant ladder (medoid / GBNF / concept-anchor / defer) | ❌ **Locked** — depends on diverged `route/` module |
| **4** | Try-Heal-Retry + circuit breakers + heal-event log | ❌ **Locked** — depends on diverged `heal/` module |
| **5** | Native skills (Spotlight + Vision + voice) | ❌ Not built on this branch |
| **6** | Local inference (MLX-Swift + MLX-Structured) + ModelLease | ❌ Not built on this branch |
| **6.5** | Per-model benchmark + calibration | ❌ Not built on this branch |
| **7** | Model Workspace Protocol + NightBrain orchestrator | ❌ **Locked** — depends on diverged `nightbrain/` module |
| **8** | Intent→Effect bridge + universal undo + observability | ❌ **Locked** — depends on diverged `effect/`, `undo/`, `format/intent.rs` modules |
| **9** | Capture surface (Swift UI) | ❌ Not built on this branch |
| **11** | Phase-by-phase implementation sequence (orchestrator) | ❌ Mostly docs, see plan |
| **12.5** | Skill discovery (auto-propose `.skill.json` after multi-tool composition) | ✅ Salvaged — `skill_discovery/mod.rs` |

## Already salvaged — 4 commits

| SHA | Date | Files | Lines | Concept |
|-----|------|-------|-------|---------|
| `53b2ee3beb` | 2026-05-19 | 17 | 2,420 | Foundations: skill_discovery, lifecycle, browser_engine, bootstrap, util, schemas×8, FirstRunBootstrap.swift |
| `19c66c4190` | 2026-05-19 | 77 | 4,636 | Full Tool trait + 74 typed v2_catalog wrappers + legacy_adapter (in `tools_v2/` parallel namespace) |
| `d6ba5ee74d` | 2026-05-19 | 2 | 4,064 | Original 3,715-line implementation plan + session protocol doc |
| `2bd11bc756` | 2026-05-19 | 8 | 1,782 | Variant runner + circuit breaker + semantic cache + reason.think canary + `jsonschema` dep |

## Still locked on branch — the reconciliation work

### Diverged modules (branch has DIFFERENT and often MORE code than main)

These modules exist on both branch and main with significantly different implementations. To salvage requires file-by-file decision-making informed by current canon.

| Module | Branch lines | Main lines | Branch-Main | Branch focus |
|--------|--------------|------------|-------------|--------------|
| `agent_core/src/effect/` | 2,145 | 722 | **+1,423** | Full Intent→Effect dispatcher + VaultIntentApplier + ConceptGraphApplier + MemoryApplier + ExecutionReceipt |
| `agent_core/src/route/` | 2,157 | 1,498 | **+659** | 4-variant routing ladder (variant_a embedding/medoid, variant_b GBNF, variant_c concept-anchor + create_folder + merge support, variant_d defer-is-a-feature) |
| `agent_core/src/heal/` | 1,326 | 679 | **+647** | Try-Heal-Retry + circuit breaker + Diagnostician trait + GiveUpDiagnostician + heal-event log |
| `agent_core/src/format/` | 1,209 | 571 | **+638** | `.mem`, `.soul`, `.skill`, `.intent` typed parsers |
| `agent_core/src/canon/` | 587 | 243 | **+344** | Alias resolution + concept canonicalization |
| `agent_core/src/undo/` | 579 | 266 | **+313** | Universal undo log (full intent→effect inverse logging) |
| `agent_core/src/grammar/` | 208 | 87 | **+121** | GBNF/llguidance compiler (single source of truth from JSON schemas) |
| `agent_core/src/nightbrain/` | 334 | 949 | **−615** | **Main is more advanced here** — Cohort A evolved nightbrain further |

**Total locked code in diverged modules: ~4,200 lines branch-only.**

### Modules only on branch (no main version)

| Module | Lines | Why deferred |
|--------|-------|--------------|
| `agent_core/src/workspace/` | 525 | Needs `ulid` crate added to Cargo.toml (small additive change). Self-contained. Easy salvage when ready. |

### Modified existing tools/ files (22 files)

The branch modifies these existing files in main's `tools/` to add `impl Tool` blocks (the typed Tool trait):
`apple.rs`, `browser.rs` (if exists), `channel_contacts.rs`, `chunk_reduce.rs`, `clarify.rs`, `communication.rs`, `computer_use.rs` (if exists), `delegate_task.rs`, `discovery.rs`, `filesystem.rs`, `graph.rs`, `imessage.rs`, `imessage_contacts.rs`, `inference.rs`, `intelligence.rs`, `knowledge.rs`, `macos.rs`, `media.rs`, `memory.rs`, `registry.rs`, `scheduling.rs`, `skills.rs`, `terminal.rs`, `todo.rs`, `trajectory.rs`, `web.rs`, `web_fetch.rs`, `workspace_search.rs`

Each modification adds an `impl Tool for XHandler` block at the bottom of the file via `impl_tool_via_legacy_handler!` macro. **These are not blocking — T11 Phase 2 fusion will add these (or equivalent) when it wires the typed dispatch path.**

### Other small files

| Path | Lines | Notes |
|------|-------|-------|
| `agent_core/src/tools/capture.rs` | ~50 | Capture tool (clipboard/voice/screenshot). Depends on `bridge::AgentEventDelegate` (exists on main). Could go in tools_v2/. |
| `agent_core/src/bin/heal_eval.rs` | ~100 | CLI binary for 30-case heal-recovery evaluation. Depends on diverged heal module. |
| `agent_core/src/bin/route_eval.rs` | ~100 | CLI binary for route variant evaluation. Depends on diverged route module. |
| `agent_core/eval/route_v1.jsonl` | ~? | Eval fixture data for route_eval. Useful if route_eval is salvaged. |
| `agent_core/souls/diagnostician.soul.{json,md}` | ~? | Hermes-era diagnostician "soul" pattern. **Skip** — Hermes purged. |

## Come-back trigger conditions

Do NOT attempt reconciliation until ALL of the following are true:

### Must-have conditions

1. **Current Cohort A merged into main.** All 9 active T-terminals (T09, T10, T11, T12, T17B, T18B, T21, T23B, T5) have shipped their Phase 1 work and merged. This means main has its stable, canon-aligned version of `effect/`, `heal/`, `route/`, `nightbrain/`, `format/`, `canon/`, `undo/`, `grammar/`.

2. **Prior cohort (T1-T9 from 2026-05-16) merged or formally rejected.** Their work touches some of the same modules.

3. **T11 Phase 2 fusion shipped (or its scope is clear).** T11 owns the typed-tool dispatch surface. Its design choices will determine whether `tools_v2/` gets adopted as-is, refactored, or replaced. Reconciling the branch's modified `tools/*.rs` files (adding `impl Tool` blocks) only makes sense after T11 Phase 2.

4. **V2 master plan refreshed.** Re-read `docs/V2_PROGRESS_MASTER_PLAN_2026_05_18.md` to confirm current Cohort A is finished and the V2 architecture phases 2-5 (merge, integration, falsifier evidence, product wiring) have begun.

### Nice-to-have conditions

5. **`workspace/` salvaged first** (small standalone task before deep reconciliation — see below).
6. **T17B's tier vocabulary canonical** — affects `format/`, `canon/`, and possibly `cache/` design choices.
7. **T18B's ACS admission types canonical** — affects `effect/` (admission gate before mutation).

## When you come back — the reconciliation playbook

Hand this section to a fresh Claude/Codex session along with `docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` as the design oracle.

### Step 1 — re-audit branch vs main

```bash
# Confirm branch SHA hasn't moved
git -C /Users/jojo/Downloads/Epistemos rev-parse claude/vigorous-goldberg-3a2d35
# Should match: 0e0234d9f1032942a6d1e49ffa25ecb2c28bebca

# Re-run line-count comparison for diverged modules
for mod in heal route format nightbrain effect canon undo grammar; do
  branch_lines=$(git -C /Users/jojo/Downloads/Epistemos show "claude/vigorous-goldberg-3a2d35:agent_core/src/$mod/mod.rs" 2>/dev/null | wc -l)
  main_lines=$(git -C /Users/jojo/Downloads/Epistemos show "main:agent_core/src/$mod/mod.rs" 2>/dev/null | wc -l)
  echo "$mod: branch=$branch_lines main=$main_lines"
done
```

### Step 2 — workspace quick win first

Before deep reconciliation, do the easy standalone salvage:

```bash
cd /Users/jojo/Downloads/Epistemos
# Add ulid to Cargo.toml (1 line near jsonschema):
#   ulid = "1.1"
# Bring workspace/:
git checkout claude/vigorous-goldberg-3a2d35 -- agent_core/src/workspace/mod.rs
# Add `pub mod workspace;` to lib.rs (alphabetical, between util and types or wherever fits)
# cargo check
```

### Step 3 — per-module reconciliation (heal/, route/, format/, effect/, canon/, undo/, grammar/)

For each diverged module, follow this loop:

```
For module M in [heal, route, format, effect, canon, undo, grammar]:
  3a. Read branch M's mod.rs + sub-files
  3b. Read main M's mod.rs + sub-files  
  3c. Read the corresponding phase in docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md
  3d. Compare:
       - What types/functions does branch have that main doesn't?
       - What types/functions does main have that branch doesn't?
       - Where do they overlap with DIFFERENT signatures? (canon-defining choice)
  3e. Decide one of:
       (a) Keep main's version as-is, archive branch's design notes in docs/
       (b) Replace main's module wholesale with branch's (only if main has zero unique value)
       (c) MERGE: cherry-pick specific functions/types from branch into main's module
  3f. If (c) chosen: 
       - Identify the specific functions/types to cherry-pick
       - Bring them as additions to main's module
       - Update tests
       - cargo check, cargo test -p agent_core <module>
       - Commit with clear "feat(<module>-reconcile-quick-capture): <what>" message
```

### Step 4 — modified tools/*.rs reconciliation

For each of the 22 modified tools/*.rs files:

```
If T11 Phase 2 fusion has shipped `tools_v2` as the canonical dispatch:
  - The `impl_tool_via_legacy_handler!` macro is already in tools_v2/mod.rs
  - For each tool, just need to invoke the macro in either tools_v2/ or tools/ 
  - Branch's per-file modifications can guide the typed schema for each tool
  
Else if T11 Phase 2 chose a different design:
  - The branch's modifications are reference-only
  - Discard the modified-tool diffs; keep main's tools/*.rs unchanged
```

### Step 5 — final cleanup

- Update `docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md` to mark which phases finally landed
- Delete this `QUICK_CAPTURE_FUTURE_RECONCILIATION_2026_05_19.md` doc (it has served its purpose)
- Optionally archive `claude/vigorous-goldberg-3a2d35` branch — its work is fully reconciled

## Anti-loss safeguards

To guarantee no Quick Capture code is ever truly lost:

1. **Branch is preserved in `.git/refs/heads/` forever** unless explicitly deleted. Don't delete it.
2. **SHA pinned in this doc.** Even if someone force-resets the branch, the SHA `0e0234d9f1032942a6d1e49ffa25ecb2c28bebca` can be used directly: `git checkout 0e0234d9f1...`
3. **3,715-line plan doc is on main** as the canonical design reference, surviving any branch deletion.
4. **This reconciliation doc is on main** — it survives even if the branch is somehow lost (which shouldn't happen).
5. **For absolute paranoia:** create a git tag pointing at the branch HEAD so it survives even branch deletion:
   ```bash
   git tag -a quick-capture-snapshot-2026-05-19 0e0234d9f1032942a6d1e49ffa25ecb2c28bebca -m "Pre-reconciliation snapshot of Quick Capture branch"
   git push origin quick-capture-snapshot-2026-05-19
   ```

## Estimated effort to reconcile everything

Rough estimate, assuming Cohort A has merged + canon is stable:

| Task | Effort |
|------|--------|
| Step 2 workspace quick win | 15 minutes |
| Step 3 per-module reconciliation (×7 modules, file-by-file) | 4–8 hours |
| Step 4 modified-tools reconciliation (×22 files) | 2–4 hours (mostly skipping if T11's design differs) |
| Step 5 cleanup + docs | 1 hour |
| **Total** | **8–14 hours of focused reconciliation work** |

## TL;DR for a future session

```
You are inheriting the Quick Capture salvage program. The original Quick Capture branch
(claude/vigorous-goldberg-3a2d35 @ SHA 0e0234d9f1032942a6d1e49ffa25ecb2c28bebca) had a
12-phase architectural vision. We have already salvaged ~12,900 lines of foundations,
typed Tool catalog, runtime spine, and the 3,715-line design plan.

What's still locked: ~4,200 lines of branch-only code in 7 diverged modules
(effect/, route/, heal/, format/, canon/, undo/, grammar/) where branch has more code
than main, AND workspace/ (525 lines) which doesn't exist on main.

DO NOT attempt reconciliation until:
  - Current Cohort A is merged into main (T09, T10, T11, T12, T17B, T18B, T21, T23B, T5)
  - T11 Phase 2 fusion has shipped its canonical typed-tool dispatch
  - V2 master plan reflects "merge phase complete"

When you come back: read docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md for design intent,
then follow Steps 1-5 above. Total estimated effort: 8-14 hours of focused work.

Branch is preserved. Plan doc is on main. SHA is pinned. Nothing decays.
```
