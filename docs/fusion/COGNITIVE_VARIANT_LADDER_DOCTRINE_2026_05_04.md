# Cognitive Variant Ladder Doctrine — No-LLM-First (2026-05-04)

**Status**: CANON · Restores the Plan §1.4 No-LLM-First variant ladder
discipline to canonical-track status after the
`CANONICAL_DRIFT_AUDIT_2026_05_04.md` flagged it as DRIFTED + PARTIAL
— the route-capture domain implements it (`agent_core/src/route/`)
but the broader principle is missing from `dispatcher.rs` and any
new tool route added without it silently violates the canon.

**Source**: `docs/fusion/research/PLAN_V2.md` + the salvaged
`docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`
§1.4. The principle predates V2; it just never got lifted into a
standalone doctrine doc.

**Gating**: applies retroactively to every existing tool route AND
every future tool route. No phasing. The variant ladder is a
discipline, not a feature.

---

## §1. The thesis (one sentence)

**Inside the local path, every variant ladder MUST start with a
deterministic, non-LLM variant whenever one exists.** The escalation
order is strict: deterministic Rust → embedding lookup / centroid
match → small classical model (NLI, BERT, distilled) → small local
LLM (1.5B–3B) → mid local LLM (7B–8B) → [cloud, only by §1.3
explicit opt-in].

A tool that has an LLM as its first variant is **rejected at code
review** unless the author proves no deterministic predecessor
exists. The proof must be in the PR description; absent proof, the
PR is sent back.

---

## §2. The strict escalation order (canonical)

```
Tier 1 — DETERMINISTIC RUST          (no model; pure function or table)
  ↓ falls through if Tier 1's confidence < FLOOR_T1 or returns None
Tier 2 — EMBEDDING / CENTROID MATCH  (deterministic given the index;
                                      no generative LLM)
  ↓ falls through if Tier 2's confidence < FLOOR_T2 or returns None
Tier 3 — SMALL CLASSICAL MODEL       (NLI, BERT, distilled; not
                                      generative)
  ↓ falls through if Tier 3's confidence < FLOOR_T3
Tier 4 — SMALL LOCAL LLM (1.5B–3B)   (generative; grammar-bound
                                      output)
  ↓ falls through only if Tier 4 fails or user explicitly opts in
Tier 5 — MID LOCAL LLM (7B–8B)       (generative; grammar-bound)
  ↓ falls through only on §1.3 opt-in (explicit /cloud, ⌥-submit,
    ladder-fully-fallen-through, or provably-out-of-local-capacity)
Tier 6 — CLOUD                        (last resort; user must have
                                      cloud-allowed in Settings)
```

Every tier above Tier 1 is OPTIONAL — many tools skip directly from
Tier 1 to Tier 4 if Tiers 2-3 don't apply. The constraint is on
ORDER, not on every tier being populated.

---

## §3. The five worked examples (lifted from QUICK_CAPTURE_IMPLEMENTATION_PLAN §1.4)

These are the canonical examples. Every new tool's variant ladder
should be defensible against the shape of one of these:

1. **`vault.search`** — Variant A: FTS5/Tantivy lexical (Tier 1);
   Variant B: embedding semantic (Tier 2); Variant C: RRF hybrid
   (Tier 1 + Tier 2 fusion); Variant D: escalate to LLM (Tier 4).
   The LLM never runs when the lexical hit set has ≥3 strong matches.

2. **`structure.route_capture`** — Variant A: centroid cosine (Tier
   2); Variant B: GBNF-classify (Tier 4 with grammar binding);
   Variant C: concept-anchored placement (Tier 1 deterministic);
   Variant D: defer (Tier 1 sentinel). REFERENCE IMPLEMENTATION
   today: `agent_core/src/route/`. The deterministic backstops at
   `route/variant_b_classifiers.rs` + `route/variant_c_providers.rs`
   are the canonical "Tier 1 backstop" pattern.

3. **`knowledge.cite_find`** — Variant A: embedding nearest-neighbor
   (Tier 2); Variant B: deberta-v3-mnli NLI classifier (Tier 3 — a
   150MB classical model, not an LLM); Variant C: local LLM with
   citations grammar (Tier 4); cloud only on explicit override.

4. **`knowledge.summarize`** — Variant A: extractive (TextRank,
   Tier 1, no LLM); Variant B: LLM abstractive (Tier 4); Variant C:
   cloud only on long-output override.

5. **`vault.tag_infer`** — Variant A: regex over title (Tier 1);
   Variant B: KNN over tag-centroid embeddings (Tier 2); Variant C:
   LLM closed-vocab (Tier 4); D returns empty.

---

## §4. The two enforcement mechanisms

### §4.1 Code review gate

PRs adding new tool routes must include a `## Variant Ladder` section
in the PR description with:

- The full ladder (which Tiers populated, which skipped + why)
- The deterministic Tier 1 implementation (link to function)
- The escalation thresholds (FLOOR_T1, FLOOR_T2, …)
- An example input that EXERCISES Tier 1 only (proves it's reachable)
- An example input that escalates to higher tiers (proves the gate
  works)

Absent the section, the PR is rejected. This is the same shape as
the five-question PR discipline (Stage / GenUI route / Sovereign /
Pro impact / TEMP-FREE-TIER) — additive, not replacing.

### §4.2 Source guard tests

Every new tool route ships a contract test in `agent_core/tests/`
(or `EpistemosTests/`) that asserts the variant ladder structure
holds. The reference test pattern is at
`agent_core/src/route/variant_b_classifiers.rs::tests::keyword_overlap_picks_best_match`
+ `keyword_overlap_defers_below_floor` — the deterministic
implementation must produce a usable answer for the happy path AND
defer cleanly when below floor.

---

## §5. Implementation seam (this commit)

Ships a small Rust trait at `agent_core/src/variant_ladder/` that
formalizes the contract every tool route's ladder honors:

- `LadderTier` enum (Deterministic / Embedding / Classical /
  SmallLLM / MidLLM / Cloud) — matches §2 ordering
- `LadderVariant<Output>` trait — single method `try_resolve(input)
  -> Option<Output>`. Returning `None` means "fell through to next
  tier."
- `VariantLadder<Output>` struct — holds an ordered Vec<Box<dyn
  LadderVariant>>. `resolve(input)` walks the ladder; first variant
  to return `Some` wins.
- `LadderLog` — an audit log of which tier resolved each call. Feeds
  the Provenance Console so the user can see "Tier 1 deterministic
  picked this" vs "fell through to Tier 4 LLM."

The route-capture pipeline already implements this shape ad-hoc;
this seam codifies it so future tool routes can plug into the same
contract instead of inventing a new shape per tool.

These are NOT mandatory for existing routes — refactoring them is
incremental work. They ARE mandatory for new routes added after
this commit.

---

## §6. The escalation gate (Tier 4+ requires user policy)

Tiers 4-6 (any LLM) require either:
- The user explicitly opted in (Settings → "Allow Tier-N escalation")
- OR a slash command explicitly requested it (`/cloud`, `/heavy`,
  etc.)
- OR the lower tiers all returned `None` AND the tool's `escalate_on_empty`
  flag is true (default: false — most tools should defer instead of
  escalate)

This makes the No-LLM-First posture the default, not the exception.
A naive new tool that escalates to LLM on every call is forced to
opt in to that behavior explicitly.

---

## §7. Acceptance bar for new tool routes

A PR adding a new tool route is considered canon-compliant when:

1. PR description has the `## Variant Ladder` section per §4.1
2. Tier 1 deterministic variant exists OR PR proves it's impossible
3. Source guard test pattern from §4.2 ships
4. `escalate_on_empty: true` is justified in the PR if used
5. The five-question PR discipline (Stage / GenUI route / Sovereign /
   Pro impact / TEMP-FREE-TIER) is also honored

Pre-existing tool routes that violate the ladder discipline are
flagged in `docs/fusion/CANONICAL_AUDIT_RECONCILIATION_2026_05_04.md`
for incremental cleanup. They don't break today; they just collect
a tech-debt marker until refactored.

---

## §8. Cross-references

```
docs/fusion/research/PLAN_V2.md                                            ← canon source (Plan §1.4)
docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md ← original framing
docs/fusion/research/FINAL_SYNTHESIS.md                                    ← cross-references variant ladder in §1 + §2
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md                        ← kernel-side enforcement point
agent_core/src/route/variant_b_classifiers.rs                              ← REFERENCE Tier 1 backstop
agent_core/src/route/variant_c_providers.rs                                ← REFERENCE Tier 1+2 backstops
agent_core/src/variant_ladder/                                             ← typed seam (this commit)
```
