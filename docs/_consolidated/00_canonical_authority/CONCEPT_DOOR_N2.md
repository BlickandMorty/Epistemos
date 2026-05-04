# CONCEPT_DOOR_N2.md — The Depth Kernel

> **Authored**: 2026-04-27 final pass.
> **Role**: Doctrine extension establishing **Concept Door / Depth Kernel** as the missing depth primitive in Epistemos. Sits in the canonical authority chain between `01_DOCTRINE.md` (philosophy) and `03_EXECUTION_MAP.md` (per-item depth). Cross-referenced from `MASTER_FUSION.md §16`.
> **Status**: CANONICAL — N2 in the plan tree (companion to N1 Prompt Tree).
> **Sequencing**: Does NOT block V1 (Halo). Lands in V1.5 alongside Raw Thoughts + typed artifact spine. Composed from existing systems — does NOT introduce a parallel architecture.

---

## §0 — The user's framing (preserved verbatim)

> "Simulate a world where every concept is a world where you press it and that world has infinite insights about the sub-subjects of that concept. Each door is limitless, you can go as deep as you'd like to uncover infinite knowledge. Please implement this way of understanding the depth of a true exoskeleton cog system. That is also minimal."

This document operationalizes that vision into bounded, provenance-aware execution.

---

## §1 — The principle: minimal surface, infinite depth

Epistemos's interface stays **calm and minimal**. The depth is hidden until summoned. Every concept is **pressable**. When pressed, it opens a world.

```
Halo            answers: "what nearby memory matters right now?"
Concept Door    answers: "what is the world inside this concept?"
ClaimLedger     answers: "can I still trust this world?"
Retraction      answers: "what changed since I last believed this?"
```

Together: the cognitive exoskeleton.

---

## §2 — Definition

A **Concept Door** is an interaction primitive available across existing surfaces:

| Surface | Concept Origin |
|---|---|
| Editor | selected text, paragraph, heading, wikilink |
| Note title | the note as concept |
| Graph | node, edge label, community cluster, "god node" |
| Search results | each hit |
| Code editor | symbol, type, function, module |
| Run trace | event, tool call, model output, claim |
| Artifact inspector | claim, evidence, contradiction, skill |
| Command palette | typed concept query |
| `@` mentions / slash commands | inline concept reference |

Opening the door produces a **Concept World**: a typed artifact (NOT a generated markdown blob) with structured facets, provenance, and bounded next-doors.

---

## §3 — Canonical schemas

### 3.1 — `ConceptRef` (Rust)

```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum ConceptRef {
    TextSelection {
        text: String,
        artifact_id: Option<String>,
        block_id: Option<String>,
    },
    Artifact { artifact_id: String },
    GraphNode { node_id: String },
    Claim { claim_id: String },
    Evidence { evidence_id: String },
    CodeSymbol { file_id: String, symbol_id: String },
    RunEvent { run_id: String, event_id: String },
}
```

### 3.2 — `ConceptWorld` (Rust)

```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ConceptWorld {
    pub id: String,                                    // ULID
    pub root_ref: ConceptRef,
    pub title: String,
    pub summary: String,                               // < 200 words
    pub depth_budget: DepthBudget,
    pub facets: Vec<ConceptFacet>,
    pub claims: Vec<ClaimRef>,
    pub evidence: Vec<EvidenceRef>,
    pub contradictions: Vec<ContradictionRef>,
    pub related_artifacts: Vec<ArtifactRef>,
    pub implementation_paths: Vec<ImplementationPath>,
    pub open_questions: Vec<OpenQuestion>,
    pub next_doors: Vec<ConceptDoor>,
    pub provenance: ProvenanceRef,
    pub retraction_status: RetractionStatus,
    pub created_at_ms: i64,
    pub schema_version: u32,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ConceptDoor {
    pub id: String,
    pub label: String,
    pub target: ConceptRef,
    pub door_kind: DoorKind,
    pub expected_value: String,
    pub cost_estimate: CostEstimate,
    pub risk: DoorRisk,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DoorKind {
    Definition,
    Evidence,
    Counterargument,
    Implementation,
    History,
    CodePath,
    RelatedMemory,
    MathematicalForm,
    FailureMode,
    ResearchTrail,
    PersonalRelevance,
    NextAction,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct DepthBudget {
    pub max_depth: u8,
    pub max_nodes: u16,
    pub max_tokens: u32,
    pub allow_cloud: bool,
    pub allow_web: bool,
    pub allow_codebase_search: bool,
}
```

### 3.3 — `ConceptDoorMode` (action surface)

```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConceptDoorMode {
    Peek,        // local summary, no mutation; reversible; cheap
    Open,        // temporary ConceptWorld view; no durable mutation unless user pins
    Pin,         // save ConceptWorld as artifact; writes MutationEnvelope
    Deepen,      // run retrieval + synthesis under visible budget
    Challenge,   // search contradictions, invalid evidence, stale claims
    Implement,   // convert into ImplementationPlan
    Research,    // Pro-only OR explicit cloud/web opt-in
}
```

---

## §4 — Infinite depth, bounded execution

The philosophical model is infinite. The implementation must be bounded. **Never implement unbounded recursion.**

```
Depth 0: local summary / exact source context (immediate, no model call)
Depth 1: nearest notes, claims, evidence, related code symbols (local, ≤ 50ms)
Depth 2: synthesis, contradictions, missing evidence (local model, ≤ 2s)
Depth 3: external research / model council / implementation plans (visible budget; explicit user gesture)
Depth 4+: requires explicit user approval OR scheduled deep research (NightBrain)
```

Each door expansion **must declare**:
- cost (token estimate, latency estimate)
- source scope (vault-only, vault+web, vault+cloud, vault+code)
- provider route (which model, which tool)
- risk (read-only, mutation, irreversible)
- reversibility (`Reversible` / `PartiallyReversible` / `Irreversible`)
- provenance (prompt tree id, run id)

**No silent deepening. No silent web. No silent cloud. No silent mutation.**

---

## §5 — Mechanism: composes existing systems, does NOT create a parallel one

Concept Door is **not a new app mode**. It is a depth action that composes:

```
PromptTree (N1)              ← structures the model call
+ StructureRegistry          ← validates the output schema
+ AgentEvent                 ← projects the result to UI
+ MutationEnvelope           ← persists durable state when Pinned
+ ClaimLedger                ← tracks claim/evidence trust
+ A2UI closed catalog        ← renders ConceptWorldCard etc.
+ Graph search               ← finds related artifacts
+ Contextual Shadows         ← seeds nearby memory
+ Artifact router            ← routes user to source on click
= Concept Door
```

When Concept Door fires, it **compiles into a `PromptTree`** — not raw prompt strings. The prompt composer must be StructureRegistry-driven so that each provider does not invent its own prompt shape.

```rust
pub struct PromptTree {
    pub id: String,
    pub root: PromptNode,
    pub context_refs: Vec<ContextRef>,
    pub render_target: RenderTarget,
    pub cache_hints: PromptCacheHints,
    pub policy: PromptPolicy,
}

pub struct PromptNode {
    pub id: String,
    pub role: PromptNodeRole,
    pub instruction: String,
    pub children: Vec<PromptNode>,
    pub constraints: Vec<String>,
    pub output_schema: Option<String>,
}

pub enum PromptNodeRole {
    Define, Retrieve, Compare, Challenge,
    Synthesize, Implement, Verify, Summarize,
}
```

---

## §6 — UI rules (the minimal-surface contract applied)

Default presentation:

```
selected concept
→ subtle affordance (Halo or context menu item)
→ open Concept Door
→ compact world panel (NSPanel non-activating)
→ expandable facets (3–7 max default)
→ graph path / evidence trail
→ next-door chips
```

**Do not** show everything at once.

Preferred ConceptWorldCard layout:
- one-line summary
- 3–7 facets
- evidence confidence indicator
- contradiction flag (red banner if any)
- next-door chips (≤ 5 default)
- provenance button (opens RunEventLog trail)
- "deepen" action
- "challenge" action
- "make implementation plan" action

The panel must:
- not steal editor focus
- support keyboard navigation
- support VoiceOver (every Halo state has a label)
- respect `accessibilityReduceMotion`
- degrade calmly if index unavailable

---

## §7 — A2UI catalog additions (closed catalog discipline preserved)

New A2UI components (closed catalog — production rejects unknown schemas with `VALIDATION_FAILED`):

```
ConceptWorldCard
FacetList
EvidenceStack
ContradictionBanner
NextDoorChips
DepthBudgetPill
ProvenanceTrailButton
RetractionStatusBadge
ImplementationPathCard
OpenQuestionList
```

DEBUG-only quarantine for unknown schemas (per `MASTER_FUSION.md §11.1`) — must not compile into ReleasePro or ReleaseMAS.

---

## §8 — MAS / Pro gating

### MAS allowed (V1.5+)

Concept Door supports up to **Depth 2** in MAS using:
- local Tantivy + usearch index
- local graph
- local Model2Vec embeddings
- local AFM / MLX inference (in-process only)
- cloud APIs only with explicit user opt-in (per provider key)
- no shell, no Docker, no external CLI subprocess
- no broad filesystem access beyond user-granted vault

### Pro deepening paths (Depth 3+)

Pro can deepen Concept Door through:
- Hermes (UX-privileged, integration-privileged, **not substrate-sovereign**)
- CLI providers (Claude Code, Codex, Gemini, Kimi)
- shell + Docker + browser + computer use
- external MCP servers
- long-running research (NightBrain)

Pro **still must obey**: visible provider route, approval policy, provenance, retraction, no silent fallback, no silent cloud escalation, no hidden token scraping, no unbounded recursion.

**One concept primitive. Two policy profiles.**

---

## §9 — Retraction propagation (the trust layer)

Any Concept World containing claims/evidence must expose retraction status:

```rust
pub enum RetractionStatus {
    Valid,
    AtRisk,
    Retracted,
    NeedsRevalidation,
}

pub struct RetractionPropagated {
    pub from_claim_id: String,
    pub to_claim_id: String,
    pub depth: u8,
    pub status: RetractionStatus,
    pub reason: String,
}
```

When evidence is invalidated:
- dependent claims update transitively
- Concept Worlds referencing those claims update
- UI surfaces the change (RetractionStatusBadge becomes red)
- **no silent stale worlds**

A Concept World without retraction awareness is just another generated page. **Do not build that.**

---

## §10 — Definition of done (N2 acceptance criteria)

N2 is shippable when **all** are true:

1. ✅ `ConceptRef` enum exists in Rust
2. ✅ `ConceptWorld` schema validates against StructureRegistry
3. ✅ `ConceptDoorMode` action surface exists in Swift
4. ✅ At least ONE production trigger surface (e.g., editor selection → context menu → "Open as Concept Door")
5. ✅ `PromptTree` integration: Concept Door compiles into a PromptTree (or N1 is explicitly the upstream prerequisite)
6. ✅ `ConceptWorldCard` renders through A2UI closed catalog
7. ✅ Unknown schemas fail with `VALIDATION_FAILED` in production
8. ✅ DEBUG quarantine exists for schema-coverage testing (excluded from ReleasePro/MAS)
9. ✅ MAS policy blocks Pro-only deepening paths (`Research` mode, `Deepen` Depth 3+)
10. ✅ Retraction status appears in ConceptWorld UI
11. ✅ Every durable Concept World write goes through `MutationEnvelope` (the four-layer event hierarchy from `MASTER_FUSION.md §3.5`)
12. ✅ WRV proof: each ConceptWorld surface is **Wired** (UI exists), **Reachable** (real user gesture triggers it), **Visible** (renders without modal)
13. ✅ Tests cover: schema validation, four ConceptDoorModes (Peek/Open/Pin/Deepen), MAS/Pro policy gating, retraction propagation
14. ✅ Performance: Peek + Open complete within `MASTER_FUSION.md §17.3` budgets (recall pipeline < 25ms p50)
15. ✅ No unbounded recursion (depth-budget enforced at the planner layer)

---

## §11 — Anti-overbuild stops (binding)

If an agent working on N2 finds itself adding any of these without explicit user request, **stop and surface**:

- arbitrary recursive infinite expansion
- auto-web research on every concept
- auto-cloud calls from selection (without explicit policy + approval)
- giant always-open concept sidebar
- model-generated SwiftUI
- generic JSON fallback (production)
- Hermes Python bundling in MAS
- shell-backed concept deepening in MAS
- Docker-backed research in V1
- computer use from Concept Door in V1
- silent claim creation
- silent artifact pinning (Pin requires user gesture)
- unbounded graph traversal
- persistent ConceptWorld creation without user action

**The interface is minimal. The depth is consentful.**

---

## §12 — Sequencing in the plan tree

| Phase | Status | Items |
|---|---|---|
| **V1** (MAS App Store) | ⚪ pending ship | Halo + Contextual Shadows ONLY (per `ambient_V1_DECISION.md`) |
| **V1.5** | ⚪ post-V1 | **N2 Concept Door** + Raw Thoughts persistence + typed artifact spine |
| **Pro / direct** | ⚪ post-V1.5 | Hermes Expert Mode + CLI providers + Docker + computer use + NightBrain + Co-op Mode |

**N2 does NOT block V1 ship.** It composes onto Halo's foundation as deliberate-depth counterpart to ambient-recall.

---

## §13 — Cross-references

- `MASTER_FUSION.md §16` — summary doctrine entry pointing here
- `MASTER_FUSION.md §16.9` — implementation companion pointer (THE READ for N2 implementation)
- `MASTER_FUSION.md §17` — Minimal Surface / Infinite Depth design contract
- `MASTER_FUSION.md §3.5` — Four-layer event hierarchy (RunEventLog + MutationEnvelope + AgentEvent + GraphEvent)
- `MASTER_FUSION.md §11.1` — DEBUG quarantine exception for closed A2UI catalog
- `MASTER_FUSION.md §11.2` — Hermes terminology bridge
- `docs/plan/01_DOCTRINE.md` — provenance plane + retraction propagation primitives
- `docs/plan/03_EXECUTION_MAP.md` — N1 (Prompt Tree, SHIPPED) + N2 (this doc) entry
- `docs/PROMPT_AS_DATA_SPEC.md` — N1 spec; required prerequisite for N2 deepening
- `docs/_consolidated/50_research_corpus/master_plans/EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md` — moat audit (audit reference)

### §13.1 — Implementation companion (REQUIRED READ)

**`docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md`** is the canonical implementation plan for the typed-artifact spine that N2 sits on top of. It defines:

- `ArtifactKind` enum (7 kinds: ProseNote=1, Document=2, RawThought=3, Source=4, Code=5, Run=6, Output=7) — Rust + Swift mirrored
- `ArtifactHeader` + `ProvenanceBlock` schemas (ULID + content_hash + producer + derived_from + generated_by_run + tool_id)
- Repo inventory as of 2026-04-25 (Raw Thoughts 80% done via Patches 4+5; typed graph types 30% done; .epdoc + Document editor + block-level search + Epistemos Code surface NOT yet built)
- Single-line invariant: **"Filesystem is durable. Graph is rebuildable. Artifact identity is stable."**

When picking up N2 work, **read `COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` first** to know current state and what remains. The `ConceptRef` schema in this doc's §3.1 must use the `ArtifactKind` enum from there — do NOT re-define artifact taxonomy.

Additional architecture-spec context for related slices:
- `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` — FFI strategy when N2 needs Rust↔Swift data plane
- `docs/architecture/EPISTEMOS_RESEARCH_SYNTHESIS_AND_ACTION_PLAN.md` — benchmark harness is the absolute first step for any FFI work N2 might need
- `docs/architecture/OVERSEER_AND_AGENT_HIERARCHY.md` — when N2 deepening calls into agent runtime
- `docs/architecture/RELEASE_HARDENING_CANONICAL_PLAN_2026-04-20.md` — V1 ship constraints that gate N2 V1.5 timing

---

## §14 — Why this is the missing piece

```
Halo gives ambient recall.
Concept Door gives deliberate depth.
ClaimLedger gives trust.
Retraction propagation gives correction.
Provenance gives the audit trail.
```

That is the cognitive exoskeleton.

A normal AI app gives answers. **Epistemos lets every concept become a door, and every door has provenance.**

---

## §15 — Provenance log

| Date | Author | Action |
|---|---|---|
| 2026-04-27 | consolidation pass (Cowork) | Initial authoring of Concept Door / Depth Kernel as N2 doctrine extension. Composes existing N1 + StructureRegistry + AgentEvent + MutationEnvelope + ClaimLedger + A2UI + graph search + Contextual Shadows + artifact router. Cross-linked from MASTER_FUSION.md §16/§17. Does not block V1. |

---

**END OF CONCEPT_DOOR_N2.md**

> *"Each door is limitless, you can go as deep as you'd like to uncover infinite knowledge."* — User, 2026-04-27
>
> Implementation: minimal surface, infinite depth, bounded execution, visible provenance, retractable claims, policy-gated deepening, no silent magic.
