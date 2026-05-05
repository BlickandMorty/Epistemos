# Live File Compiler Doctrine — Wave 7 (2026-05-04)

**Status**: CANON · Restores Wave 7 to canonical-track status after the
`CANONICAL_DRIFT_AUDIT_2026_05_04.md` flagged it as drifted to indefinite
deferral. The Live File Compiler stays the single most important
architectural primitive after the Provenance Plane (which already
shipped) — without it Epistemos has no executable knowledge, only
indexed documents.

**Source**: `docs/fusion/research/FINAL_SYNTHESIS.md` §1 (the breakthrough
section) + `docs/fusion/research/quickcapture-addenda/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md`
(with FINAL_SYNTHESIS overrides).

**Gating**: Wave 7 lands AFTER V2.7 (multi-agent ACS), BEFORE V3
(Helios + SCOPE-Rex + Ternary). Distinct from V2.x because Live Files
require the Cognitive DAG (V2.1) + XPC mastery (V2.4) + Simulation
v1.7+ (V2.5) to all be stable first. Estimated 8-12 weeks once gating
clears.

---

## §1. The thesis (one paragraph)

Markdown is **not** the executable. The executable is the **compiled,
signed `LivePlan.v1`** that the Live File Compiler emits from the
markdown source. The runtime executes the signed plan; it never
executes the markdown directly. `is_live: true` is **intent**;
`Compiled` is **runtime permission**; the **signed plan hash** is
**execution authority**. These three are different artifacts and must
never be conflated. Mutating the markdown invalidates the signature
and the plan goes stale; the user sees a "this Live File needs
recompilation" prompt before any further execution.

---

## §2. The five non-negotiable invariants

Lifted verbatim from FINAL_SYNTHESIS §1 + §1.2. These are the
contracts that distinguish a real Live File system from a markdown-
auto-execute footgun:

1. **`is_live: true` is intent, not authority.** The signed plan hash
   is authority.
2. **Capabilities are declared in the LivePlan, not derived from the
   markdown's vibe.** "Never edit code" in prose is *advisory*;
   `capabilities.edit_code: false` in the LivePlan is *enforced*.
3. **Schema validation gates execution.** A LivePlan with malformed
   bounds, contradictory triggers, or escalated capabilities (more
   than the parent vault permits) is rejected at compile time. The
   runtime never sees it.
4. **The compile step itself is gated** by Compile-Verify-Mint
   (`PLAN.md §17`). Generated LivePlans pass G1 (parse), G2 (intent
   classification — does the plan match the prose?), G3 (sandbox
   dry-run on a synthetic vault), G4 (permission manifest validation
   against the user's vault trust zones). A LivePlan that fails any
   gate is tombstoned.
5. **Don't poll Live Files; event-driven only with thermal/battery
   gating.** Live Files admit work only when an event fires AND
   eligibility checks (thermal nominal, battery >20% or AC,
   capability granted, budget remaining) all pass.

---

## §3. The 10-state Live File state machine

Per FINAL_SYNTHESIS §4 (refines the addendum's 5-state version):

```
[Static] ──user toggles live──► [LiveCandidate]
                                       │
                                  compile pass
                                       │
                                       ▼
                              [Compiled (signed)]
                                       │
                                event/schedule + eligibility
                                       │
                                       ▼
                                  [Eligible]
                                       │
                                  runner admits
                                       │
                                       ▼
                                   [Running]
                                       │
                          ┌────────────┼────────────┐
                          │            │            │
                       blocked      complete      unsafe
                          │            │            │
                          ▼            ▼            ▼
                      [Paused]   [Completed]  [Quarantined]
                          │            │            │
                       resume       artifacts   triage to user
                          │            │            │
                          ▼            ▼            ▼
                      (Running)  [Suspended]   (Revoked or
                                       │        Compiled after fix)
                                  schedule next
                                       │
                                       ▼
                                  [Eligible]

At any point: user revokes → [Revoked] (no future execution; markdown still readable)
```

**Critical invariants** (FINAL_SYNTHESIS §4 invariants — verbatim):
- `is_live: true` alone does NOT permit execution. It is user intent.
- `Compiled` state requires a signed plan. It is runtime permission.
- `Eligible` state requires triggers + thermal/battery/budget gates
  passed. It is execution authority.
- `Quarantined` is not failure; it's "user must look at this." Triage
  UI is the recovery path.
- `Revoked` is the kill switch — no future execution, but the
  markdown source remains readable. The user can re-toggle to live,
  which goes back through compile.

Implementation lives in `agent_core/src/live_files/state.rs` per
Wave 7. Modeled in `kani` (Rust formal verifier) for invariant
checking — no orphan states, no unreachable states, no race
conditions on transition.

---

## §4. The LivePlan.v1 schema (canonical)

Lifted from FINAL_SYNTHESIS §1.2; this is the contract:

```yaml
livefile_id: <BLAKE3 of source markdown>
source_uri: vault://path/to/file.md
plan_version: "1.0.0"
plan_hash: <BLAKE3 of compiled plan, signed by user's local key>
compiled_at: <ISO-8601>
expires_at: <optional cap; default 7 days>

cognitive_weight:
  class: preferred_context          # soft_memory | preferred_context | strong_project_anchor | policy_grade
  raw_score: 0.45                   # provider's raw weight, kept for audit
  policy_authority: false           # only policy_grade can be true
  retrieval_priority_boost: 0.18    # bounded by class
  context_placement: inline         # trailing | inline | above_fold | immutable_system

triggers:
  - event: vault.note_saved
    selector: "frontmatter.project == 'epistemos'"
  - schedule: cron("0 3 * * *")     # 3 AM daily
  - manual: true                    # user can run on demand

eligibility:
  thermal: nominal_required          # nominal | mild_ok | any
  battery: ac_or_above_30
  budget: { tokens: 25000, ms: 30000, usd: 0.05 }
  capabilities:
    read_vault: { scope: ["epistemos/**", "research/**"] }
    edit_code: false
    network: { allow: ["api.anthropic.com"], deny: "*" }
    spawn_subprocess: false

intent:
  summary: "Re-rank inbox notes by recency + relevance to current chat"
  steps:
    - type: search_vault
      query_template: "{{chat.last_user_message}}"
    - type: rerank
      method: hybrid_rrf
    - type: emit_artifact
      schema: ranked_note_list

# user-facing diff if mutated
prompt_for_changes:
  - field: capabilities.edit_code
    user_prompt: "This Live File now wants to edit code. Allow / deny."
  - field: capabilities.network.allow
    user_prompt: "Live File needs network access for {{host}}. Allow once / always / deny."
```

Every Live File compiles into one of these. Schema validation is
strict: extra fields, malformed bounds, or capability escalation
beyond the parent vault's trust zone all reject at compile time.

---

## §5. Implementation seam (this commit)

Ships a minimal Rust type stub at `agent_core/src/live_files/` that
establishes the canonical types so future Wave 7 work has a typed
landing pad — without attempting to build the whole compiler today.

Specifically lands:
- `LiveFileState` enum (the 10 states from §3)
- `CognitiveWeightClass` enum (the 4 tiers — see Cognitive Weight
  Class Doctrine for the full system)
- `LivePlanV1` struct skeleton (the schema fields from §4)
- `live_files_canonical_state_machine_invariants()` function returning
  a textual statement of the invariants — usable by future kani
  verifiers + by tests asserting docs and code agree

These are NOT functional implementations. They are the typed seam
that Wave 7 work plugs in behind. The point is: **no future agent can
silently re-derive Live File state names with different semantics** —
the contract is in code from day one.

---

## §6. Wave 7 acceptance bar

A Wave 7 PR that claims "Live Files shipped" must:

1. Compile + sign a real markdown file into a `LivePlanV1`
2. Round-trip the LivePlan through the schema validator (G1+G4)
3. Run the LivePlan in a sandbox dry-run (G3)
4. Execute the signed plan in production (NOT the markdown)
5. Show the user-visible diff prompt when `capabilities.network.allow`
   or `capabilities.edit_code` change
6. Honor the 10-state machine + invariants from §3
7. Pass `kani` formal verification on the state machine
8. Demonstrate the "markdown changed → plan goes stale → user sees
   recompilation prompt" path
9. Wire NightBrain (Wave 8 future) integration via the live scheduler
   established in commit `b0d229be`

If a PR ships a partial subset of these, it's NOT Wave 7 — it's Wave
7 prep. Mark it as such.

---

## §7. Cross-references

```
docs/fusion/research/FINAL_SYNTHESIS.md                  ← canon source
docs/fusion/research/quickcapture-addenda/
  LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md                   ← original addendum
docs/fusion/COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md ← partner doctrine
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md         ← V2.1 prerequisite
docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md ← V2.x sequence
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md       ← Wave 7 row added in this commit
agent_core/src/live_files/                               ← typed seam (this commit)
agent_core/src/provenance/ledger.rs                      ← downstream consumer (records LivePlan executions)
```
