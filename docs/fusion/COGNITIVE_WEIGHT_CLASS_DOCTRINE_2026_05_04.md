# Cognitive Weight Class Doctrine — 4-tier (2026-05-04)

**Status**: CANON · Restores the four-tier weight class system to
canonical-track status after the `CANONICAL_DRIFT_AUDIT_2026_05_04.md`
flagged it as drifted to monolithic search tuning. The Cognitive
Weight Class system distinguishes **Semantic Gravity** (which
documents pull attention) from **Policy Authority** (which documents
constrain action). The current Halo / RRF k=60 work covers Semantic
Gravity; this doctrine restores Policy Authority.

**Source**: `docs/fusion/research/FINAL_SYNTHESIS.md` §3 (full
codification) + §0 audit-row 4 (the correction call-out).

**Gating**: 4-tier semantics ship in two phases:
- **Phase W1** (V2.5+): all four classes are read-only metadata on
  documents. Retrieval bias + context placement are honored. Policy
  authority is NOT yet enforced.
- **Phase W2** (Wave 7 alongside Live Files): `policy_grade`
  authority is enforced on tool calls; the partner doctrine
  (`LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md`) ships the signed-plan
  + capability-validation path that gates promotion to `policy_grade`.

---

## §1. The thesis (one sentence)

**Semantic Gravity pulls attention; Policy Authority controls action;
do not confuse the two.** A document that is read often (high
retrieval priority) is not the same as a document the user has
elevated to law (policy-grade). Conflating these is the
"old file accidentally too powerful" failure mode FINAL_SYNTHESIS §3
warns against.

---

## §2. The four tiers (canonical table)

Lifted verbatim from FINAL_SYNTHESIS §3:

```
┌────────────┬─────────────────────┬──────────────┬──────────────┬─────────────┐
│ Class      │ Range               │ Retrieval    │ Context      │ Policy      │
│            │                     │ priority     │ placement    │ authority   │
├────────────┼─────────────────────┼──────────────┼──────────────┼─────────────┤
│ Soft       │ 0.00–0.30           │ +0–10%       │ trailing     │ none        │
│ memory     │                     │              │              │             │
├────────────┼─────────────────────┼──────────────┼──────────────┼─────────────┤
│ Preferred  │ 0.31–0.60           │ +10–30%      │ inline       │ none        │
│ context    │                     │              │              │             │
├────────────┼─────────────────────┼──────────────┼──────────────┼─────────────┤
│ Strong     │ 0.61–0.85           │ +30–60%      │ above-fold   │ advisory    │
│ project    │                     │              │              │ (UI hint)   │
│ anchor     │                     │              │              │             │
├────────────┼─────────────────────┼──────────────┼──────────────┼─────────────┤
│ Policy-    │ 0.86–1.00           │ +60–100%     │ immutable    │ ENFORCED    │
│ grade      │                     │              │ system       │ (gates      │
│ control    │                     │              │ block        │ tools)      │
│ vector     │                     │              │              │             │
└────────────┴─────────────────────┴──────────────┴──────────────┴─────────────┘
```

The numeric ranges are normative — they MUST sum to [0,1] without
gaps or overlap. The retrieval-priority percentages are also
normative — they're how the RRF / Halo retrieval surface honors the
class.

---

## §3. The five gates promoting to `policy_grade`

Per FINAL_SYNTHESIS §3, promoting a Live File (or any document) to
`policy_grade` requires ALL FIVE:

1. **Schema validation** against `policy_grade.v1.json`
2. **Capability validation**: the document's declared capabilities
   must be a subset of the parent vault's trust zone
3. **User-visible diff**: "this file is becoming policy-grade. It
   will be able to constrain tool behavior. Show me what changes."
4. **Signed plan hash**: the `policy_grade` flag is captured in the
   LivePlan; mutating the markdown invalidates the signature
5. **Revocation path**: `cmd-shift-R` revokes any document's
   `policy_grade` status instantly

A `policy_grade` document that fails ANY of these is silently
demoted to `strong_project_anchor`. The runtime never honors
unsigned policy authority.

---

## §3.1 The "Semantic Gravity vs. Policy Authority" boundary

This is the single rule that prevents tier confusion:

- **Retrieval priority + context placement** are derived from
  semantic relevance + the user's organic interaction. They can rise
  to `+60-100%` boost for `policy_grade` content WITHOUT the document
  having policy authority — because retrieval is read-only.
- **Policy authority** requires explicit signed-plan elevation. A
  `strong_project_anchor` document at retrieval-boost 0.85 still has
  `policy_authority: false` until it crosses the five gates in §3.

In code: any retrieval surface (Halo, RRF, semantic search) reads
`class` to compute boost. Only the policy enforcement surface
(Sovereign Gate, capability lattice) reads `policy_authority` — and
even then it cross-checks `signed_plan_hash` before honoring it.

---

## §4. Implementation seam (this commit)

Ships a minimal Rust type stub at
`agent_core/src/cognitive_weight/` that establishes the canonical
types so future Phase W1 + W2 work has a typed landing pad:

- `CognitiveWeightClass` enum (Soft / Preferred / StrongAnchor /
  PolicyGrade) with normative range checks
- `CognitiveWeight` struct (raw_score: f32, class:
  CognitiveWeightClass, policy_authority: bool,
  retrieval_priority_boost: f32, context_placement: ContextPlacement)
- `ContextPlacement` enum (Trailing / Inline / AboveFold /
  ImmutableSystem)
- `CognitiveWeight::from_raw_score(...)` — deterministic mapping from
  raw score to class per the §2 table; `policy_authority` always
  starts false (must be promoted via the §3 five gates)
- `CognitiveWeight::can_constrain_tools(&self, signed_plan_hash:
  Option<&[u8; 32]>) -> bool` — returns `true` only if `class ==
  PolicyGrade && policy_authority && signed_plan_hash.is_some()`

These are NOT a functional retrieval-bias implementation. They are
the typed contract surface that future Halo W2 + Wave 7 work plugs in
behind.

---

## §5. How current Halo / RRF surfaces interact

The current Halo work (`epistemos-shadow/src/`) implements retrieval
fusion via RRF k=60 + recency exp() boost. That stays — the doctrine
**adds metadata** that Halo can read (when populated) to apply the §2
priority boost on top of the RRF base score.

In Phase W1: documents without explicit `cognitive_weight` metadata
default to `class: Soft, raw_score: 0.0`. Retrieval behavior is
unchanged for them. Documents WITH metadata get the §2 boost stacked
on top of RRF.

In Phase W2: tool-call dispatch reads `policy_authority` from the
matching document's metadata + cross-checks `signed_plan_hash`
against the LivePlan ledger before honoring policy constraints.

---

## §6. Acceptance bar

A PR that claims "Cognitive Weight Class Phase W1 shipped" must:

1. Add the `CognitiveWeight` field to the canonical document
   metadata schema (the existing `EpistemosSidecar` shape is the
   right home)
2. Wire RRF retrieval to read the metadata + apply the §2 boost
3. Wire context-builder to honor `context_placement`
4. Demonstrate that two documents with identical RRF base score but
   different `class` get different final ranks (W1 acceptance test)
5. Honor the §3.1 boundary: `policy_authority: true` is silently
   downgraded to false in W1 (the runtime treats it as advisory only
   until W2 ships)

A PR that claims "W2 shipped" additionally requires the §3 five
gates + LivePlan signed-hash cross-check + revocation path.

---

## §7. Cross-references

```
docs/fusion/research/FINAL_SYNTHESIS.md                   ← canon source §3
docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md     ← partner doctrine (W2 gate)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md          ← Phase 8 sub-track (provenance for promotion events)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md        ← T8 (Halo) sub-track 4
agent_core/src/cognitive_weight/                          ← typed seam (this commit)
epistemos-shadow/src/backend/rrf.rs                       ← W1 retrieval-bias consumer
Epistemos/Models/EpistemosSidecar.swift                   ← W1 metadata carrier
```
