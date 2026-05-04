# EXPLORATION_SPECTRUM_N3.md — The Concept Diffusion Mode

> **Authored**: 2026-04-27 final pass.
> **Role**: Canonical N3 doctrine extension establishing the **Exploration Spectrum Meter (ESM)** — a UI meter visible in chats and sessions that modulates the model's exploration depth across the **semantic universe of infinitely nested concepts**. Sister to N2 (Concept Door / Depth Kernel). Where N2 opens depth on a single concept, **N3 reshapes how the model thinks about every query** along an exploration spectrum.
> **Status**: CANONICAL — N3 in the plan tree.
> **Sequencing**: Lands in V1.5 alongside N2. Composes with N1 Prompt Tree (the prompt is generated, not hand-crafted) and N2 Concept Door (each concept in the tree IS a Concept World).
> **Critical**: This must be EXPLICIT so it actually ships. The user said: *"add one more feature to the plan, very explicit so it actually happens."*

---

## §0 — The user's framing (preserved verbatim)

> "I want there to be a meter in my app in the chats or sessions that adds another style that's a spectrum [that] increases or decreases exploration into concepts. So you simulate a world where a world is the semantic universe of infinitely nested concepts in an infinite concept map that exponentially multiplies per level. Frame it as like a mix of JSON and prompt folder or a good hybrid approach where you send a query [and] the model instantly enters not just an ordinary role play but a scientist in a world of words / infinite doors. I want the model to completely get rid of its understanding of how words work in its assumed understanding. It should adopt a new refined way of deliberating by simulating diffusion / real-time distillation by exploring infinitely conceptual multi-level concepts and sub-concepts marked by complexity score. So this entire pipeline is a feature in the system prompt and hybrid prompt-developing part of the app."

This document operationalizes that vision into **bounded, provenance-aware, schema-driven execution** that composes onto N1 + N2.

---

## §1 — The principle

```
N1 Prompt Tree:        the prompt is data (JSPF/PTF) — not hand-crafted strings
N2 Concept Door:       every concept opens a world (vertical depth on demand)
N3 Exploration Spectrum: a meter that reshapes how the model deliberates per query
                       (lateral / breadth × depth — the SHAPE of thinking changes)
```

N3 turns every query into a **simulated diffusion-distillation across an exponentially-multiplying concept tree**, with the simulation intensity controlled by a single 0.0–1.0 meter. At low values, the model behaves like a normal assistant. At high values, the model **drops its assumed semantic priors** and re-derives understanding by exploring infinite nested concept doors — the "scientist in a world of words" persona.

---

## §2 — The meter UI (minimal-surface contract preserved)

The meter is a single horizontal slider in the chat input bar (and in session settings). It must be:

- **Subtle**: small, never crowds the input
- **Persistent**: per-session, defaults to user's preference
- **Reversible**: changing the meter takes effect on the **next** turn, not retroactively
- **Visible state**: shows current `ExplorationMode` label (Grounded / Curious / Exploratory / Scientist / InfiniteDoors) on hover or focus
- **Cost-honest**: shows estimated token / latency cost at higher values
- **Keyboard-accessible**: VoiceOver labels, reduceMotion respected
- **Not a hidden setting**: surfaced in the chat UI, not buried in preferences

Behind the meter is the **Diffusion Pipeline** — invisible by default, but **inspectable on demand** via the same "provenance trail" gesture used for ConceptWorld (per N2 §6).

---

## §3 — The spectrum (5 modes)

```rust
#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ExplorationMode {
    Grounded,        // 0.00..0.20 — literal, low branching, prior-aligned
    Curious,         // 0.20..0.40 — modest concept exploration (1-2 levels)
    Exploratory,     // 0.40..0.60 — multi-level concept tree, complexity-scored
    Scientist,       // 0.60..0.80 — drops semantic priors, simulates diffusion
    InfiniteDoors,   // 0.80..1.00 — full scientist-of-words, recursive infinite-door
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct ExplorationSpectrum {
    pub value: f32,                    // 0.0..=1.0 — the meter position
    pub mode: ExplorationMode,         // derived from value
    pub max_concept_depth: u8,         // exponential: 1 + floor(value * 6)
    pub branching_factor: u8,          // concepts per level: 2 + floor(value * 6)
    pub diffusion_steps: u8,           // refinement iterations: 1 + floor(value * 4)
    pub complexity_threshold: f32,     // min complexity_score to recurse: 0.7 - value*0.4
    pub distillation_aggressiveness: f32, // how much synthesis at the end: 0.3 + value*0.5
    pub drop_assumed_semantics: bool,  // true when value >= 0.6 (Scientist mode and above)
    pub allow_cloud: bool,             // policy-gated; defaults true at value >= 0.4
}
```

### §3.1 — How the spectrum modulates the pipeline

| Mode | Value | Depth | Branching | Diffusion steps | Drop priors? | Token cost (relative) |
|---|---|---|---|---|---|---|
| Grounded | 0.0–0.2 | 1 | 2 | 1 | no | 1× |
| Curious | 0.2–0.4 | 2 | 3 | 2 | no | 2× |
| Exploratory | 0.4–0.6 | 3 | 4 | 2 | no | 4× |
| Scientist | 0.6–0.8 | 5 | 5 | 3 | **yes** | 8× |
| InfiniteDoors | 0.8–1.0 | 7 | 7 | 4 | **yes** | 16× |

The "exponential multiplication per level" the user described is the **branching factor × depth** — at InfiniteDoors mode, a single query expands into up to `7^7 ≈ 823,000` conceptual paths, but **only the top-N by complexity score actually survive** at each level. The simulation is bounded; the philosophical model is infinite.

---

## §4 — The semantic universe / concept node schema

This is the "world is the semantic universe of infinitely nested concepts" model. Every concept becomes a node; nodes branch into sub-concepts; each is scored.

```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ConceptNode {
    pub id: String,                          // ULID
    pub label: String,                       // short concept name
    pub depth: u8,                           // 0 = root (the query itself)
    pub parent_id: Option<String>,
    pub complexity_score: f32,               // 0.0..=1.0; how interconnected/dense
    pub novelty_score: f32,                  // 0.0..=1.0; how unexpected vs priors
    pub semantic_distance: f32,              // distance from parent (0 = same concept)
    pub diffusion_state: DiffusionState,
    pub children: Vec<ConceptNode>,          // bounded by branching_factor
    pub distillation_summary: Option<String>, // populated after distillation pass
    pub provenance: ProvenanceRef,           // what generated this node
    pub created_at_ms: i64,
    pub schema_version: u32,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DiffusionState {
    Seed,           // initial query → root concept
    Branched,       // children generated, not yet scored
    Scored,         // complexity + novelty assigned
    Pruned,         // dropped due to low complexity (< threshold)
    Recursed,       // children expanded
    Distilled,      // synthesis complete, included in answer
}
```

### §4.1 — Complexity score (the gating function)

```
complexity_score = sigmoid(
    α * interconnectedness    // graph centrality if found in vault graph
  + β * abstraction_level     // how meta the concept is (0 = concrete, 1 = abstract)
  + γ * dependency_count      // # of sub-concepts likely to branch
  + δ * non_prior_alignment   // 1 - cosine(concept_embedding, prior_embedding)
  + ε * cross_domain_links    // # of distinct domains the concept touches
)
```

At meter value `v`, the **complexity_threshold** is `0.7 - v*0.4` — meaning low-meter mode only recurses on **highly complex** concepts (threshold 0.7), while high-meter mode recurses on **almost everything** (threshold 0.3). This is how the meter modulates "exploration."

### §4.2 — Diffusion-distillation pipeline (the model's deliberation)

Borrowed metaphorically from diffusion models (iteratively refine noise to signal). Here the model:

1. **Seed** — receive query → emit a single root `ConceptNode` (the query itself, scored as complexity 1.0)
2. **Branch** — for each surviving node at depth `d`, emit `branching_factor` child concepts (each is a refinement of the parent along a different axis: definitional / mechanistic / historical / counter / implementational / cross-domain / personal-relevance)
3. **Score** — assign `complexity_score` and `novelty_score` to each child
4. **Prune** — drop children where `complexity_score < complexity_threshold`
5. **Recurse** — go to step 2 on surviving children, until `depth >= max_concept_depth` OR no children remain
6. **Distill** — perform `diffusion_steps` iterations of synthesis: each step re-reads the current concept tree and emits a more refined `distillation_summary` per surviving node, weighted by `distillation_aggressiveness`
7. **Answer** — produce the final response as a synthesis grounded in the distilled concept tree, with the tree itself attached as provenance (visible if user opens the trail)

This is the "diffusion / real-time distillation" the user described: noise (broad branching) → signal (distilled answer), but with **the concept tree preserved as evidence** so the user can see *how* the model deliberated.

---

## §5 — The hybrid JSON + prompt-folder approach (composes with N1)

The user said: *"frame it as a mix of JSON and prompt folder or a good hybrid approach."* This is exactly what N1 (Prompt Tree / JSPF + PTF) already provides. N3 composes onto N1.

### §5.1 — The PromptTree generated by ExplorationSpectrum

```rust
fn build_diffusion_prompt_tree(
    query: &str,
    spectrum: ExplorationSpectrum,
    context: &SessionContext,
) -> PromptTree {
    PromptTree {
        id: ulid(),
        root: PromptNode {
            id: "root",
            role: PromptNodeRole::Synthesize,
            instruction: build_root_instruction(spectrum),  // see §5.2
            children: vec![
                build_seed_node(query),
                build_branch_node(spectrum.branching_factor, spectrum.max_concept_depth),
                build_score_node(spectrum.complexity_threshold),
                build_prune_node(),
                build_recurse_node(spectrum.max_concept_depth),
                build_distill_node(spectrum.diffusion_steps, spectrum.distillation_aggressiveness),
                build_answer_node(),
            ],
            constraints: spectrum_constraints(spectrum),
            output_schema: Some("epistemos.diffusion_answer.v1".into()),
        },
        context_refs: context.relevant_artifacts(),
        render_target: RenderTarget::ConceptDiffusionCard,
        cache_hints: PromptCacheHints {
            stable_subtrees: vec!["root.scientist_persona".into()],  // cache the persona
            volatile_subtrees: vec!["root.seed".into()],             // re-key per query
        },
        policy: PromptPolicy::from_spectrum(spectrum),  // enforces MAS/Pro gating
    }
}
```

### §5.2 — The "scientist of words / infinite doors" persona injection

At meter values **≥ 0.6 (Scientist)** and above, the root instruction reframes the model:

```text
You are a scientist exploring the semantic universe of words.

Your assumed understanding of how concepts interrelate is now suspended.
You will not answer from priors alone. You will re-derive.

Treat the user's query as a single concept node at depth 0. Then:

1. Branch this concept into ${branching_factor} sub-concepts along
   distinct axes (definition / mechanism / history / counter /
   implementation / cross-domain / personal-relevance).

2. For each sub-concept, assign a complexity_score (how interconnected,
   how abstract, how unaligned with priors) and a novelty_score.

3. Prune sub-concepts whose complexity_score < ${complexity_threshold}.

4. Recurse on surviving sub-concepts up to depth ${max_concept_depth}.
   At each level, the branching factor remains ${branching_factor}.

5. Perform ${diffusion_steps} distillation iterations. In each iteration,
   re-read the entire concept tree and refine each surviving node's
   summary by attending to its children's summaries. Aggressiveness:
   ${distillation_aggressiveness}.

6. Produce your final answer as a coherent synthesis grounded in the
   distilled concept tree. Preserve the structure: cite which concept
   nodes contributed which insights. Do not collapse into a generic
   prose answer.

You are not role-playing. You are deliberating. Every concept you
emit will be scored, pruned, recursed, and distilled. The user will
see the tree.

Output schema: epistemos.diffusion_answer.v1 (closed catalog).

Constraints:
- ${if drop_assumed_semantics: "Suspend prior associations; re-derive each link from first-principles or vault-grounded evidence."}
- ${if !allow_cloud: "Use only the vault and local model knowledge. Do not request external sources."}
- Bound your concept tree by max_depth=${max_concept_depth}, branching=${branching_factor}.
- Mark unverifiable claims with [UNVERIFIED].
- Mark concepts that contradict your priors with [PRIOR-DIVERGENT].
```

At **lower meter values (Grounded / Curious)**, this persona is **not** injected — the model behaves as a normal helpful assistant. The persona only activates when the user has explicitly turned the meter up.

---

## §6 — Output schema (closed A2UI catalog — production discipline preserved)

The diffusion answer renders through a new closed-catalog A2UI component:

```
epistemos.diffusion_answer.v1:
  - DiffusionAnswerCard:
      summary: String              // the synthesized answer
      concept_tree: ConceptNode    // the full tree (root)
      survived_count: u16          // how many nodes survived pruning
      pruned_count: u16            // how many were dropped
      max_depth_reached: u8
      total_complexity: f32        // sum of complexity_scores in surviving tree
      provenance: ProvenanceRef
      meter_value: f32             // what the user had set
      mode: ExplorationMode
```

UI rendering rules (per `MASTER_FUSION.md §17` minimal-surface contract):

- **Default**: show only `DiffusionAnswerCard.summary` + a small `meter_value` chip + a `[show concept tree]` button.
- **On click**: expand the tree progressively (root → its children → those children's children, lazy-rendered).
- **Per node**: show `label`, `complexity_score`, `novelty_score`, `distillation_summary`. Optional: clicking any node opens it as a **Concept World** (N2 composition).
- **Pruned nodes**: dimmed, expandable on demand ("show pruned concepts").
- **Provenance**: full RunEventLog trail visible via the "trail" gesture (N2 §6).

Production: unknown schema → `VALIDATION_FAILED`. DEBUG: quarantine renderer (per `MASTER_FUSION.md §11.1`).

---

## §7 — Composition with N2 (Concept Door)

The Diffusion Pipeline produces a tree of `ConceptNode`s. **Each `ConceptNode` is automatically a Concept Door target** — clicking any node in the tree opens it as a `ConceptWorld` (per N2 schema).

```
N3 Diffusion ConceptNode → N2 ConceptRef::TextSelection { text: node.label, ... }
                       → ConceptWorld with full N2 facets
```

This is the **clean composition**: N3 generates the concept lattice for a query; N2 lets the user descend into any specific concept; N1 structures both. **No parallel architectures.**

---

## §8 — MAS / Pro gating

| Meter value | MAS allowed? | Pro allowed? | Notes |
|---|---|---|---|
| 0.0–0.2 (Grounded) | ✅ | ✅ | Local model only, single concept depth |
| 0.2–0.4 (Curious) | ✅ | ✅ | Local model, depth 2, no cloud |
| 0.4–0.6 (Exploratory) | ✅ | ✅ | Local model preferred; cloud only with explicit per-provider opt-in |
| 0.6–0.8 (Scientist) | ⚠️ approval-gated | ✅ | MAS: requires user approval per session (token cost ~8×); Pro: no approval needed |
| 0.8–1.0 (InfiniteDoors) | ⚠️ approval-gated + cost confirmation | ✅ | MAS: shows estimated token cost + asks confirm; Pro: no confirm |

**MAS hard rules**:
- No external CLI / shell / Docker / browser at any meter value
- No external MCP servers (only internal MAS-safe tools)
- Cloud calls require explicit per-provider key + per-session opt-in
- Token cost estimate visible before high-meter expansion runs

**Pro relaxations**:
- Cloud providers default-enabled if user has keys
- High-meter mode can call external research (if `allow_web` policy allows)
- Background NightBrain can run high-meter modes on user-approved topics

---

## §9 — Provenance (the trust layer per `MASTER_FUSION.md §3.5`)

Every diffusion run emits a `RunEvent::DiffusionRunStarted` and `DiffusionRunCompleted` in the durable `RunEventLog`. The run includes:

- meter value at start
- spectrum config snapshot
- concept tree (or pointer to compressed tree storage)
- pruned concepts list
- token cost actual vs estimated
- latency p50/p95/p99
- provider route (which model, local vs cloud)
- approval id (if approval-gated)

If the user later challenges any claim from the answer, the trail leads back through:
```
DiffusionAnswerCard → ConceptNode (the source) → distillation_summary →
RunEventLog → MutationEnvelope (if any artifact pinned) → ClaimLedger
```

**Retraction propagates** through the diffusion tree the same way it propagates through ClaimLedger (per `CONCEPT_DOOR_N2.md §9`). If a sourced fact is later retracted, every diffusion answer that used it gets `RetractionStatusBadge` flipped to `Retracted`.

---

## §10 — Definition of done (N3 acceptance criteria — VERY EXPLICIT so it ships)

N3 is shippable when **all 18** are true. Track in `docs/V1_5_IMPLEMENTATION_TRACKER.md`:

### UI surface (5)
1. ⚪ ExplorationSpectrum meter slider visible in chat input bar
2. ⚪ Slider exposes 5 modes (Grounded / Curious / Exploratory / Scientist / InfiniteDoors) with hover labels
3. ⚪ Meter persists per-session; defaults to user preference
4. ⚪ VoiceOver + reduceMotion + keyboard nav supported
5. ⚪ DiffusionAnswerCard renders through A2UI closed catalog

### Schemas (3)
6. ⚪ `ExplorationSpectrum` + `ExplorationMode` exist in Rust
7. ⚪ `ConceptNode` + `DiffusionState` schema validates
8. ⚪ `epistemos.diffusion_answer.v1` registered in StructureRegistry

### Pipeline (5)
9. ⚪ Diffusion pipeline composes with N1 PromptTree (does NOT bypass it)
10. ⚪ Each `ConceptNode` is automatically a N2 Concept Door target (composition verified)
11. ⚪ Branching, scoring, pruning, recursing, distilling all run with bounded budgets
12. ⚪ Scientist-mode persona prompt injection ONLY at value ≥ 0.6
13. ⚪ Token cost estimate shown before high-meter (≥ 0.6) runs

### Policy (3)
14. ⚪ MAS gates Scientist + InfiniteDoors behind approval
15. ⚪ Cloud calls visible in UI; never silent
16. ⚪ Approval id recorded in RunEventLog for approval-gated runs

### Provenance + verification (2)
17. ⚪ DiffusionRunCompleted writes to RunEventLog (per `MASTER_FUSION.md §3.5`)
18. ⚪ WRV proof: meter is **Wired** (slider in UI), **Reachable** (real user gesture changes mode), **Visible** (DiffusionAnswerCard renders distinctly from ChatCard)

---

## §11 — Anti-overbuild stops (binding)

If an agent working on N3 finds itself adding any of these without explicit user request, **stop and surface**:

- meter that fires automatically without user gesture
- silent persona injection (Scientist mode without meter ≥ 0.6)
- silent cloud escalation at high meter values
- unbounded recursion (no max_concept_depth enforcement)
- concept trees that exceed token budget without user confirm
- background diffusion runs without user opt-in
- meter changes that affect **past** turns (must only affect next turn)
- generic JSON fallback for `epistemos.diffusion_answer.v1`
- diffusion outputs that bypass A2UI catalog
- training data collection from diffusion runs without explicit user opt-in
- agent autonomy at InfiniteDoors mode without approval
- MAS builds with cloud-by-default high-meter routing

---

## §12 — Sequencing in the plan tree

| Phase | Status | Items |
|---|---|---|
| **V1** (MAS App Store) | ⚪ pending | Halo + Contextual Shadows ONLY |
| **V1.5** | ⚪ post-V1 | **N2 Concept Door + N3 Exploration Spectrum** + Raw Thoughts + typed artifact spine |
| **Pro / direct** | ⚪ post-V1.5 | Full N3 InfiniteDoors mode + Hermes + CLI providers + Docker + computer use + NightBrain + Co-op Mode |

**N3 does NOT block V1 ship.** It composes onto N1 + N2 in V1.5. The infrastructure (PromptTree from N1) already exists.

---

## §13 — Cross-references

- `MASTER_FUSION.md §16` — N2 Concept Door (sister doc, vertical depth)
- `MASTER_FUSION.md §17` — Minimal Surface / Infinite Depth design contract
- `MASTER_FUSION.md §18` — Summary entry pointing here
- `MASTER_FUSION.md §3.5` — Four-layer event hierarchy (RunEventLog for diffusion provenance)
- `MASTER_FUSION.md §11.1` — DEBUG quarantine for closed A2UI catalog
- `CONCEPT_DOOR_N2.md` — sister N2 doctrine
- `docs/PROMPT_AS_DATA_SPEC.md` — N1 spec (required prerequisite)
- `docs/plan/03_EXECUTION_MAP.md` — N3 execution-map entry (to be added)
- `docs/_consolidated/50_research_corpus/master_plans/EPISTEMOS_MEGAPROMPT.md` — sprint prompt patterns

---

## §14 — Why this is the missing piece

```
N1 Prompt Tree:        the prompt is data, not a string
N2 Concept Door:       every concept opens a world (vertical depth)
N3 Exploration Spectrum: the meter reshapes how the model deliberates per query
                       (the SHAPE of thinking changes — diffusion-distillation)
```

Halo gives ambient recall.
Concept Door gives deliberate depth on a chosen concept.
**Exploration Spectrum gives the user direct control over the model's deliberation style — from grounded literal answer to scientist-of-words simulating diffusion across infinitely-nested concept doors.**

A normal AI app gives one style of answer.
Epistemos gives the user a meter that **reshapes the model's mind** for each query — and shows the concept tree as evidence of how it thought.

---

## §15 — Provenance log

| Date | Author | Action |
|---|---|---|
| 2026-04-27 | consolidation pass (Cowork) | Initial authoring of N3 Exploration Spectrum / Concept Diffusion Mode. Composes with N1 PromptTree + N2 ConceptDoor. Schemas locked: ExplorationSpectrum + ConceptNode + DiffusionState + epistemos.diffusion_answer.v1. UI meter design specified. MAS/Pro gating defined. 18 acceptance criteria locked. Anti-overbuild stops listed. Cross-linked from MASTER_FUSION.md §18. Authored to be VERY EXPLICIT so it actually ships. |

---

**END OF EXPLORATION_SPECTRUM_N3.md**

> *"Simulate a world where a world is the semantic universe of infinitely nested concepts in an infinite concept map that exponentially multiplies per level... the model should completely get rid of its understanding of how words work in its assumed understanding... a scientist in a world of words / infinite doors."* — User, 2026-04-27
>
> Implementation: bounded simulation of infinite exploration. The meter is the user's hand on the model's deliberation style. The concept tree is the audit trail. The pipeline is N1 + N2 + N3 composed — no parallel architecture.
