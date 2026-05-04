# Pre-V2 gap closure summary — 2026-05-04

Closes all 5 gaps from `PRE_V2_FULL_AUDIT_2026_05_04.md`. The substrate
is now ready for `RESUME SUBSTRATE V2`.

---

## Closure record

| Gap | Severity | Outcome | Commit(s) |
|---|---|---|---|
| **5 — CLAUDE.md drift + GENUI-DEFER** | LOW-MEDIUM | LOC numbers refreshed (137K→252K Swift, 94K→71K Rust, 115→346 test files); GENUI doctrine §9 deferral list updated to mark Hermes Expert Mode + Provenance Console as MIGRATED/SHIPPED; explicit note that 0 GENUI-DEFER markers in source today is correct | `99b2c15c` |
| **4 — Memory updates** | MEDIUM | 6 new memory entries created (Hermes Brand Doctrine, Honest Handle FFI, Provenance Console, Quick Capture salvage triage, Codex Recovery Handoff, Recovery Loop Findings, Pre-V2 Full Audit); 1 stale memory rewritten as SUPERSEDED (project_hackathon_focus_2026_05_03); 1 stale claim corrected in canonical_recovery_plan memory; MEMORY.md index updated | (memory files live outside git repo) |
| **1 — 9,947 lines uncommitted** | HIGH | Triaged into 4 logical commits: docs reclassification (281 files / 6,431 lines additive metadata), agent_core in-flight (54 files / 2,108 lines including pro-build feature gate canonicalization + RawThoughts RedactedThinking variant + session refinements + resources subsystem refactor), substrate engines + build scripts (25 files / 1,589 lines including knowledge_core/store.rs +808 V2.1 PRECURSOR work), residual hygiene (10 files / 117 lines + .gitignore for runtime lockfile). LocalPackages/mlx-swift-lm/ vendored fork left alone (separate discipline). | `f170a9e9`, `2ca663a1`, `3a46b0c6`, `9e0a0aa1` |
| **3 — 6 untriaged salvage subdirs** | MEDIUM | Companion triage doc shipped covering all 6 dirs in A/B/C/D tiers. **Critical surface: agent-a0550f9c/CANONICAL_AUDIT_LOG.md (76,848 bytes, 47-item audit, 17 BLOCKERS, dated 2026-04-26) lifted to V2.1 Phase 8 sub-plan input.** Doctrine §3 Retraction Propagation primitive named as missing keystone. Lane A's session_insights.rs verified-already-integrated (Agent 2's earlier finding was wrong). Hermes parity audit + skill porting guide flagged as Tier B reference for V2.1 tool decisions. | `edc04874` |
| **2 — Lane A session_insights.rs orphan** | HIGH (was) | **Verified-clean false alarm.** File exists at `agent_core/src/session_insights.rs` (672 LOC, evolved beyond salvage's 625), declared `pub mod session_insights;` at lib.rs:37, has FFI exposure (`SessionMetricsFFI`) and Swift consumer (`Epistemos/Views/Cost/CostDashboardView.swift`). Documented in Gap 1b commit message + Gap 3 triage doc. | (no commit needed — already integrated) |

---

## Build state at closure

- `xcodebuild Epistemos macOS`: BUILD SUCCEEDED
- `cargo check agent_core`: green (19.4s, no warnings of note)
- `cargo test agent_core --test hermes_runtime`: **15 passed, 0 failed**
- Working tree: clean except for vendored `LocalPackages/mlx-swift-lm/`
  fork (intentional)

---

## What this means for V2.1 (Cognitive DAG Phase 8)

Per `POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` §5 the wait-for-signal
contract still holds — V2.1 does not auto-start. When the user types
`RESUME SUBSTRATE V2`:

1. **First Phase 8.A deliverable should be the keystone primitive.** The
   `from-agent-a0550f9c/CANONICAL_AUDIT_LOG.md` audit names Doctrine §3
   Retraction Propagation as the missing keystone. The recovery
   commit `2ca663a1` landed `MutationRelationKind` enum +
   supporting infrastructure as the precursor; Phase 8.A should land
   the full `MutationEnvelope` + `ProposedEnvelope` + `ClaimLedger` +
   `RetractionPropagated` types.

2. **17 BLOCKERS from the canonical audit need a Phase 8 deliverable
   map.** Each blocker (W9.21 Honest FFI consumers / W9.27 OpLog
   prev_hash / D2 7-verb MCP boundary / D3 closed A2UI catalog / D5
   substrate durability / Faculty roster D4 36B model overcommit / etc)
   should map to a named Phase 8 deliverable.

3. **Tier A salvage modules are integration-ready throughout V2.1.**
   `format/`, `canon/`, `grammar/`, `undo/` from
   `from-vigorous-goldberg/` can land at any point in V2.1 as their
   own commits.

4. **Helios v3 + SCOPE-Rex remains the V3 ultimate goal.** The 5 gap
   closures here protect the V3 path from inheriting substrate debt.

---

## Audit pattern recommendation for future loops

The four-parallel-agent + ground-truth-verification pattern from this
audit caught 3 false-positives (GenUIDispatcher.swift exists, five-question
PR discipline IS canonical, 346 Swift test files exist). Future audits
should mirror this structure:

1. Personal quick inventory (5 min)
2. Dispatch 4 parallel Explore agents by domain (parallel, ~5 min each)
3. **Personal verification of every consequential claim** before synthesis
   (the verification step is non-negotiable — it caught all 3 false
   positives in this audit)
4. Synthesis doc with per-claim verification + closure ordering

---

## Stop point

The substrate is ready for `RESUME SUBSTRATE V2`. No wakeup scheduled.
The user's next message determines the next move:

- `RESUME SUBSTRATE V2` → V2.1 (Cognitive DAG Phase 8.A — start with
  Retraction Propagation primitive per the canonical audit's keystone
  finding)
- `RESUME RESEARCH TIER` → V3 (Helios v3 + SCOPE-Rex + Ternary substrate)
- Anything else → respond to the new request
