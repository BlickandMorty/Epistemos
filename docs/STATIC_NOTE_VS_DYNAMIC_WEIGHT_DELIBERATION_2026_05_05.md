---
state: canon
candidate_promoted_on: 2026-05-05
canon_promoted_on: 2026-05-05
implemented_on: 2026-05-05
question: "Artifact primitive that distinguishes Static Note from Dynamic AI Weight" (user, 2026-05-05)
companion_to: docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §2.2 substrate spine
deliberation_brief_template: docs/fusion/BUILDER_EXECUTION_PROMPT_2026_04_30.md §"Deliberation Brief Required"
---

# Static Note vs Dynamic AI Weight — canon implementation brief

> **State: canon.** Codex continuation implemented the recommended
> Option C + Option B on 2026-05-05: `NodeKind::is_dynamic_rooted()`
> is now the code-level discriminator, and doctrine §2.2 names the
> invariant. No wrapper enum was added.

## The user's question (2026-05-05)

> "An Artifact primitive that distinguishes Static Note from Dynamic AI Weight."

In the doctrine §2.2 substrate spine:

```
TypedArtifact → MutationEnvelope → RunEventLog / AgentEvent / GraphEvent → projections
```

`TypedArtifact` is the apex type, but the Swift implementation
(`Epistemos/Models/MutationEnvelope.swift`) and the Rust mirror
(`agent_core/src/mutations/envelope.rs`) treat all artifacts as
text-shaped (note bodies, edits, tool outputs). The user is asking
whether a top-level discriminator should distinguish:

- **Static** — content-addressed, immutable after capture (notes,
  raw thoughts, captures, code)
- **Dynamic** — model state that mutates over time (weights, KV
  cache, LoRA-light Companion deltas, activation steering vectors)

## Survey: what already encodes this distinction

The Cognitive DAG schema (`agent_core/src/cognitive_dag/node.rs:222-272`)
has 10 NodeKind variants. The static/dynamic split is **already
partially encoded**:

| NodeKind | Static / Dynamic | Why |
|---|---|---|
| `Note { body, author, mime }` | **Static** | Content-addressed by body bytes; immutable after insert. |
| `Claim { proposition, scope, source }` | **Static** | Same. |
| `Evidence { kind, payload, captured_at }` | **Static** | Snapshot at capture time. |
| `Skill { name, description, schema_version }` | **Static (per version)** | Schema-versioned. New versions are new nodes. |
| `Tool { id, surface, tier }` | **Static (per session)** | Tool registry is a set; mutations create new node IDs. |
| `Procedure { skill_ref, context_hash, outcomes }` | **Static (per outcome batch)** | Outcomes are appended via new procedure nodes. |
| `Event { kind, ts, session }` | **Static** | Timestamped event records; immutable. |
| `Capability { kind, scope, expiry }` | **Static (per issuance)** | Macaroon caveats produce new capabilities. |
| `Companion { profile, identity, persona }` | **Dynamic-rooted** | The Companion *node* is content-addressed, but the model state it points to mutates over time via `Deforms` edges. |
| `Model { weight_root, base_or_lora }` | **Dynamic-rooted** | The `WeightRoot` is a 32-byte content hash of the weight blob; the *blob itself* mutates via Sherry/QOFT/QDoRA continual learning, producing new `Model` nodes (LoRA lineage) that link to the base via `ModelLineage::Lora { parent, lora_path }`. |

**The dynamic-rooted variants (`Companion`, `Model`) handle mutation
by minting new content-addressed node IDs per state.** This is the
canonical pattern — the DAG never mutates a node in place; instead,
a new node is added with the new state, and a `Deforms` edge from
the old to the new captures the lineage.

## Three options for the user's discriminator question

### Option A: Add a top-level `Artifact { Static | Dynamic }` enum

Introduce a new top-level type in `node.rs`:

```rust
pub enum Artifact {
    Static(NodeId),   // points to a Note / Claim / Evidence / ...
    Dynamic(NodeId),  // points to a Companion / Model
}
```

**Pros:**
- Surfaces the distinction at the type system level.
- Lets dispatch / projection / UI code branch on the discriminator
  without pattern-matching all 10 NodeKind variants.

**Cons:**
- Adds a new type without changing any actual behavior — the lineage
  is already in `ModelLineage::Lora { parent }` and `Deforms` edges.
- Risk of drift: someone adds a new NodeKind variant and forgets to
  update the `Artifact` discriminator function, leading to silent
  miscategorization.
- Doctrine §2.2 invariant #3 (Markov blanket via Rust ownership) is
  weakened: now there are TWO indirections (Artifact → NodeKind →
  fields) instead of one.

### Option B: Document the existing distinction in the doctrine

Add a §2.2 invariant addendum stating: "Static artifacts (Note,
Claim, Evidence, Skill, Tool, Procedure, Event, Capability) are
content-addressed and immutable after insert. Dynamic-rooted
artifacts (Companion, Model) mutate by minting new content-addressed
nodes; the lineage is captured by `Deforms` edges + `ModelLineage::Lora { parent }`."

**Pros:**
- Zero code change — just makes the existing invariant visible.
- No new drift surface (the doctrine is read by every deliberation
  brief; the linter can enforce the rule).
- Composable with the canon-hardening protocol's WRV pipeline (a
  future slice that adds a NodeKind variant has to declare its
  static/dynamic stance in the brief).

**Cons:**
- Less satisfying ergonomically — code that wants to filter by
  static/dynamic still pattern-matches the 10 variants.

### Option C: Add a `NodeKind::is_dynamic_rooted() -> bool` method

A middle ground: add a method on `NodeKind` that returns true for
`Companion` and `Model`, false for everything else. Plus a doctrine
note saying "the canonical static/dynamic discriminator is
`NodeKind::is_dynamic_rooted()`; any new NodeKind variant must
update this method and its test."

**Pros:**
- Single source of truth for the discriminator (the method body).
- Future variants are caught at compile time (the match is
  non-exhaustive without an `_` arm; we make it exhaustive so
  forgetting a variant is a build error).
- Doctrine readers see the rule via the method's doc comment.

**Cons:**
- Adds one method + one test, but no new types.
- Slightly more diffuse than option A.

## Implemented recommendation

**Option C + Option B together.** Added the
`NodeKind::is_dynamic_rooted()` method (option C) so code that
filters by mutability has a canonical entry point. Document the
distinction in doctrine §2.2 (option B) so the rule is visible to
deliberation briefs. Skip option A — a new wrapper type adds drift
surface without behavioral change.

## What this slice did

```rust
// agent_core/src/cognitive_dag/node.rs — append to NodeKind impl block:

impl NodeKind {
    /// Static vs dynamic-rooted classification.
    ///
    /// **Static** artifacts (Note, Claim, Evidence, Skill, Tool,
    /// Procedure, Event, Capability) are content-addressed and
    /// immutable after insert. New "versions" produce new node IDs.
    ///
    /// **Dynamic-rooted** artifacts (Companion, Model) carry a
    /// reference to mutable state (weight blob, persona blob, KV
    /// cache region). The *node* is content-addressed but the
    /// state it references mutates over time. The mutation surface
    /// is governed by `Deforms` edges + `ModelLineage::Lora { parent }`.
    ///
    /// Doctrine §2.2 invariant: the DAG never mutates a node in
    /// place. Dynamic-rooted artifacts express mutation as a new
    /// node + a `Deforms` edge, never as in-place state change.
    ///
    /// **Drift guard:** the match below is exhaustive — adding a
    /// new NodeKind variant without updating this method is a
    /// build error.
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

Plus one unit test that pins the classification for each of the 10
variants, and a doctrine §2.2 paragraph addition.

## Verification

Codex continuation verification:

- `cargo test --manifest-path agent_core/Cargo.toml cognitive_dag::node::tests::dynamic_rooted_discriminator_covers_all_variants --lib`
- `cargo clippy --manifest-path agent_core/Cargo.toml --target aarch64-apple-darwin -- -D warnings`

## Cross-refs

- Doctrine §2.2 substrate spine
- `agent_core/src/cognitive_dag/node.rs:222-272` (NodeKind enum)
- `agent_core/src/cognitive_dag/companions.rs` (Companion lifecycle + Deforms edges + LoRA estimates)
- `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` (DAG doctrine — the substrate this brief sits on top of)
- `docs/CANON_HARDENING_PROTOCOL_2026_05_05.md` (canon promotion protocol + WRV pipeline)
- The user's question that prompted this brief: `docs/CANONICAL_SWEEP_CLOSEOUT_2026_05_05.md` §"Two architectural questions raised by the user (2026-05-05)" Q2.

## Bottom line

The static/dynamic distinction the user asked about **is already in
the substrate** — eight NodeKind variants are static, two are dynamic-
rooted. The canonical exposure of that distinction is a small
`is_dynamic_rooted()` method + a doctrine paragraph, not a new
top-level type. That implementation is now landed and verified.
