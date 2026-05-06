---
state: canon
canon_promoted_on: 2026-05-03
frontmatter_added_on: 2026-05-06
covers: typed content-addressed Merkle-rooted Cognitive DAG; Phase 8 meta-collapse over kernel doctrine Phases 1-7
---

# Epistemos Cognitive DAG Doctrine — One Schema For All Cognition — 2026-05-03

> **Successor doctrine.** This document extends `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md`
> with the deeper unification: the seven kernel subsystems collapse into one
> typed, content-addressed, Merkle-rooted cognitive DAG. **Do not implement
> until the kernel doctrine's Phases 1-7 are landed.** This is Phase 8 — the
> meta-collapse. Read in full before any DAG-touching PR.

---

## 0. Why a successor doctrine

The kernel doctrine answers: *how do we get from five fragmented agent loops
to one Rust kernel in one binary?* Answer: kernel + renderer + syscall +
sandbox-exec + capability layers, with one agent loop, one memory store, one
provenance ledger, one skill registry, one privilege boundary.

That's the unification at the **runtime** level.

This doctrine answers: *once we have the unified kernel, what is the deepest
unification at the **schema** level?* Answer: collapse the kernel's seven
internal subsystems (agent loop, skills, procedural memory, tools, provenance,
resonance, capabilities, companions, memory tiers, vault) into one typed
content-addressed cognitive DAG — and let every subsystem be a traversal
pattern over that DAG.

Two unifications. Different layers. Both required for *as complex as a brain,
as simple as an app, as fast as a jet*.

---

## 1. The schema

### 1.1 Node types (typed, content-addressed via BLAKE3)

```rust
// agent_core/src/cognitive_dag/node.rs

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum NodeKind {
    Note { body: String, author: AuthorRef, mime: MimeType },
    Claim { proposition: String, scope: ClaimScope, source: SourceRef },
    Evidence { kind: EvidenceKind, payload: EvidenceBlob, captured_at: Timestamp },
    Skill { name: String, description: String, schema_version: u32 },
    Tool { id: ToolId, surface: ToolSurface, tier: Tier },
    Procedure { skill_ref: NodeId, context_hash: ContextHash, outcomes: OutcomeList },
    Event { kind: AgentEventKind, ts: Timestamp, session: SessionId },
    Companion { profile: ModelProfile, identity: IdentityHash, persona: PersonaBlob },
    Capability { kind: CapabilityKind, scope: CapabilityScope, expiry: Option<Timestamp> },
    Model { weight_root: WeightRoot, base_or_lora: ModelLineage },
}

#[derive(Clone, Debug)]
pub struct Node {
    pub id: NodeId,           // BLAKE3(canonical_serialize(kind))
    pub kind: NodeKind,
    pub created_at: Timestamp,
    pub merkle_root: Hash,    // root including all incoming edges' hashes
}
```

**Every node is content-addressed.** `NodeId == BLAKE3(canonical_serialize(kind))`. Identical content → identical id. This gives us free deduplication, free integrity verification, and free distributed shareability. Same property as Git blobs and IPFS objects, applied to cognition.

### 1.2 Edge types (typed, Merkle-signed)

```rust
// agent_core/src/cognitive_dag/edge.rs

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum EdgeKind {
    DerivesFrom    { strength: f32 },                    // Claim → Evidence
    Contradicts    { tension: f32 },                     // Claim → Claim
    Invokes        { order: u32, args_template: String }, // Skill → Tool / Skill
    WitnessedBy    {},                                    // Event → Capability
    AuthorizedBy   {},                                    // Capability → SovereignSession
    RecordedBy     { step: u32 },                         // Procedure → Event
    OwnedBy        {},                                    // Companion → Procedure / Skill
    Deforms        { lora_path: PathBuf, weight_alpha: f32 }, // Companion → Model
    Caches         { tier: MemoryTier, score: f32 },      // MemoryTier → Node
    AnnotatedBy    { kind: AnnotationKind },              // any → Note
}

#[derive(Clone, Debug)]
pub struct Edge {
    pub from: NodeId,
    pub to: NodeId,
    pub kind: EdgeKind,
    pub created_at: Timestamp,
    pub signature: EdgeSignature,    // signs (from, to, kind) under issuing capability
}
```

**Every edge is Merkle-signed.** The signature binds `(from, to, kind)` under the capability that issued it. This is what makes provenance verifiable: you can prove an edge was created by a session that held a specific capability granted by Sovereign Gate.

### 1.3 Storage layer

```
agent_core/src/cognitive_dag/storage.rs

trait DagStore {
    fn put_node(&self, node: Node) -> Result<NodeId, DagError>;
    fn get_node(&self, id: NodeId) -> Result<Option<Node>, DagError>;
    fn put_edge(&self, edge: Edge) -> Result<EdgeId, DagError>;
    fn edges_from(&self, node: NodeId, kind: Option<EdgeKindSelector>) -> Result<Vec<Edge>, DagError>;
    fn edges_to(&self, node: NodeId, kind: Option<EdgeKindSelector>) -> Result<Vec<Edge>, DagError>;
    fn merkle_root(&self) -> Result<Hash, DagError>;     // root of the entire store
    fn snapshot(&self) -> Result<DagSnapshot, DagError>; // for export / replay
}
```

**Backend candidates:** `sled` (pure-Rust, ACID-ish, simple) or `redb` (pure-Rust, ACID, mmap-friendly, recommended for App Group container compat). NOT SQLite — SQLite is for relational queries; the DAG is graph-native. NOT RocksDB — too heavy for a single binary; LSM-tree compactions are noisy on 16GB Macs.

---

## 2. The seven subsystems as traversal patterns

### 2.1 Agent loop = scheduler + traversal

The kernel's agent loop is a graph traversal scheduler. A turn begins with a *root Event node* (the user input). The loop walks `invokes` edges (resolving `Skill` → `Tool` chains), creates new nodes for tool outputs, attaches new `Event` nodes for each step, and continues until a `Stop` event terminates the traversal.

```rust
async fn agent_loop_turn(input: NodeId, session: SessionId) -> Result<NodeId, AgentError> {
    let root = dag.put_node(Event { kind: TurnStart, session, ts: now() })?;
    let mut frontier = vec![root];
    while let Some(node) = frontier.pop() {
        for edge in dag.edges_from(node, Some(EdgeKindSelector::Invokes))? {
            let result = invoke(edge).await?;          // Tool / Skill / inner traversal
            let result_node = dag.put_node(result.into())?;
            dag.put_edge(Edge { from: node, to: result_node, kind: RecordedBy { step: ... }, .. })?;
            frontier.push(result_node);
        }
        if should_stop(&frontier, session) { break; }
    }
    Ok(root)
}
```

**Result:** the entire turn's reasoning is a subgraph rooted at `root`. Replay = re-walk that subgraph.

### 2.2 Skills registry = subgraph index

A `Skill` is a node. Its `invokes` edges enumerate the steps. The "registry" is just an index from `skill.name` → `NodeId`. To register a skill: insert the `Skill` node, insert `Invokes` edges to its steps. To execute: BFS from the skill node along `Invokes`.

**Composition is free.** A skill that invokes another skill is just an `Invokes` edge to a `Skill` node. No special "skill-of-skills" abstraction needed.

### 2.3 Procedural memory = `RecordedBy` edge cache

When a `Procedure` node is created, it references the `Skill` it implements and links to all the `Event` nodes that were generated. Retrieval = "give me the 3 closest Procedures to this context" — a similarity search over `Procedure.context_hash` (an embedding of the invocation context). Decay = weighting older Procedures less in the similarity search.

### 2.4 Provenance ledger = the DAG itself

The DAG is the provenance ledger. Every action emits an `Event` node. Every `Event` is `WitnessedBy` a `Capability`. Every `Capability` is `AuthorizedBy` a Sovereign Gate session. The audit trail is just `dag.edges_from(event, AuthorizedBy)`. The Merkle root over the entire DAG gives a tamper-evident snapshot.

**No separate ring buffer.** No separate event store. The DAG is the store. The Provenance Console is a UI projection of `dag.recent_events()`.

### 2.5 Resonance Gate = continuous truth propagation

Each `Claim` node has a current truth value (Kleene K3: True / False / Indeterminate). When a new `Evidence` node is added with a `DerivesFrom` edge to the Claim, the gate re-evaluates. When a `Contradicts` edge appears, both claims may flip to Indeterminate.

**Propagation:** when claim X flips, the gate walks `Reverse(DerivesFrom)` from X — every claim whose evidence chain *includes* X is re-evaluated. Cascading invalidation. Spreadsheet for truth.

```rust
fn propagate_truth_change(changed: NodeId) -> Result<Vec<NodeId>, DagError> {
    let mut affected = vec![changed];
    let mut frontier = vec![changed];
    while let Some(node) = frontier.pop() {
        for edge in dag.edges_to(node, Some(EdgeKindSelector::DerivesFrom))? {
            let dependent = edge.from;
            if recompute_truth(dependent)? != cached_truth(dependent)? {
                affected.push(dependent);
                frontier.push(dependent);
            }
        }
    }
    Ok(affected)
}
```

### 2.6 Capability lattice = `AuthorizedBy` edge type system

Capabilities are nodes. They're issued by Sovereign Gate sessions (`AuthorizedBy` edge to a session root node). They're consumed by Events (`WitnessedBy` edge from Event to Capability).

**Compositional grants** (Macaroon-style):
- Issue: `Capability { kind: ToolInvoke("vault.write"), scope: vault_x, expiry: 1h }`
- Restrict: derive a sub-capability with tighter scope (`vault_x/notes/2026/`)
- Delegate: hand to a Companion (`OwnedBy` edge from Companion → Capability)
- Revoke: insert a `Revoked` node with a `Contradicts`-equivalent edge; resonance propagation invalidates dependent Events

### 2.7 Companions = `Deforms` nodes

Companion = `Companion` node + `Deforms` edge to a `Model` node. The `Deforms` edge carries the LoRA path and weight. Multiple companions share one base `Model` node; only their LoRA diffs vary.

```
Model (base, 4GB)
   ▲ Deforms{lora=lora_a.safetensors, alpha=1.0}
   │
   Companion("Sage")
   
   ▲ Deforms{lora=lora_b.safetensors, alpha=1.0}
   │
   Companion("Orb")
```

50 companions × 50MB LoRAs + 1 × 4GB base = 6.5GB total. Vs 50 × 4GB = 200GB without sharing. **The DAG schema makes the Companion Farm economically real on 16GB Macs.**

### 2.8 Memory tiers = `Caches` edge index

Each `MemoryTier` (L0 Exact Hot through L_SE Self-Evolving) has `Caches` edges to nodes it currently holds. Promotion = new `Caches` edge. Eviction = remove `Caches` edge (the node itself stays in the cold store). Tier policy = which nodes get promoted based on access frequency.

---

## 3. The kernel ABI extension (Phase 8 surface)

```rust
// agent_core/src/bridge.rs — Phase 8 additions

// DAG access (read paths)
fn dag_get_node(node_id: String) -> Result<Option<NodeFFI>, AgentErrorFFI>;
fn dag_edges_from(node_id: String, kind: Option<String>) -> Result<Vec<EdgeFFI>, AgentErrorFFI>;
fn dag_edges_to(node_id: String, kind: Option<String>) -> Result<Vec<EdgeFFI>, AgentErrorFFI>;
fn dag_subgraph(root_id: String, max_depth: u32) -> Result<SubgraphFFI, AgentErrorFFI>;
fn dag_merkle_root() -> Result<String, AgentErrorFFI>;

// DAG export / import (replay + sharing)
fn dag_export_subgraph(root_id: String) -> Result<Vec<u8>, AgentErrorFFI>;
fn dag_import_subgraph(bytes: Vec<u8>) -> Result<ImportReportFFI, AgentErrorFFI>;
fn dag_verify_replay(export_bytes: Vec<u8>) -> Result<ReplayVerificationFFI, AgentErrorFFI>;

// Resonance propagation observation
fn dag_subscribe_truth_changes(filter: TruthFilterFFI) -> Result<TruthStreamHandle, AgentErrorFFI>;

// Capability calculus
fn dag_issue_capability(parent: String, scope: ScopeFFI, expiry: u64) -> Result<String, AgentErrorFFI>;
fn dag_restrict_capability(parent: String, tighter_scope: ScopeFFI) -> Result<String, AgentErrorFFI>;
fn dag_revoke_capability(cap_id: String) -> Result<RevocationReportFFI, AgentErrorFFI>;

// Companion deformation
fn dag_create_companion(base_model: String, lora_path: String, persona: String) -> Result<String, AgentErrorFFI>;
fn dag_companion_swap(companion_id: String) -> Result<SwapReportFFI, AgentErrorFFI>; // hot LoRA swap
```

**The agent loop and tool registry surfaces (`submit_turn`, `list_skills`, etc. from the kernel ABI §3) stay unchanged.** They become *callers* of these DAG primitives internally. Swift sees the same ABI; the kernel reorganizes around the DAG.

---

## 4. Anti-patterns specific to the DAG (additional to kernel doctrine §9)

### 4.1 No edges without signatures

Every edge must be `Merkle`-signed under a held capability. An unsigned edge means an unauthorized mutation; the kernel must reject it at the storage layer (`put_edge` returns `DagError::UnsignedEdge`).

### 4.2 No nodes without content addresses

Every node's `id` is derived from its content. A node inserted with a manually-assigned id is a violation; the storage layer must compute the id and reject any pre-set id mismatch.

### 4.3 No ad-hoc edge types

The `EdgeKind` enum is closed. Adding a new edge type requires a doctrine PR (this document). No "string-typed edges" or "metadata edges with arbitrary kind". This keeps the schema tractable for verification.

### 4.4 No DAG state outside the kernel

Swift doesn't store DAG nodes locally. XPC services don't cache DAG state. The kernel is the only DAG owner; everything else is a viewer.

### 4.5 No retroactive DAG mutation

Append-only. To "delete" a node, you insert a `Tombstone` node with a `Contradicts` edge to the original. To "edit" a node, you insert a new node and a `Revises` edge. The DAG is git-shaped: history is permanent.

---

## 5. Verification gates (additional to kernel doctrine §10)

```bash
# 5.1 — DAG schema is closed
grep -rn 'enum EdgeKind' agent_core/src/cognitive_dag/
# expected: exactly one definition; all variants doctrine-listed

# 5.2 — All edges signature-checked at insertion
grep -rn 'fn put_edge' agent_core/src/cognitive_dag/storage.rs
# expected: contains explicit signature verification before insertion

# 5.3 — Content-addressing enforced
grep -rn 'fn put_node' agent_core/src/cognitive_dag/storage.rs
# expected: computes node_id from content; rejects pre-set mismatched ids

# 5.4 — No DAG storage outside kernel
grep -rn 'DagStore\|put_node\|put_edge' Epistemos/ XPCServices/ --include='*.swift'
# expected: zero hits (Swift only reads via FFI projections)

# 5.5 — Merkle root reproducibility
cargo test -p agent_core --test cognitive_dag_merkle_root
# expected: identical content → identical root, across 1000 random insertion orders

# 5.6 — Replay verification round-trip
cargo test -p agent_core --test cognitive_dag_replay
# expected: export(subgraph) → import(bytes) → identical merkle root + identical truth values
```

---

## 6. The pure win — what the DAG genuinely unlocks for users

**1. Verifiable replay.** Export a session as `.epbundle` (existing format extended with DAG subgraph). Recipient runs `epistemos-trace verify session.epbundle` → sees: yes, this conversation's outputs match the model + tools + evidence claimed. No other personal-AI app can prove this.

**2. Cascading truth.** User retracts a claim → every dependent claim auto-updates. "The article you cited was wrong" → every conclusion drawn from it now reads `Indeterminate` until you reground or accept the contradiction. This is *thinking with corrigibility*.

**3. Companions are real and cheap.** 50 companions sharing one base model = 6.5GB on disk vs 200GB. Each companion has its own personality (LoRA), its own procedural memory (`OwnedBy` edges to procedure nodes), its own permission set (`OwnedBy` edges to capabilities). They're not characters in a chat skin; they're typed agents with verifiable boundaries.

**4. Skill marketplace.** A skill is a content-addressed verifiable subgraph. Sharing one is sending a hash. Importing one is fetching the subgraph and verifying every Tool reference it points to. No "trust me, this Python script is safe" — the imported subgraph either passes the kernel's tier filter or it doesn't.

**5. Time travel.** `git log` your reasoning. `git bisect` when an idea changed. `git revert` a compromised capability and watch dependent state recompute. PKM as version-controlled cognition.

**6. Audit-as-a-feature.** For users in regulated environments (legal, medical, security research), Epistemos becomes the only personal AI tool that produces a *defensible* paper trail. Every claim cites its evidence. Every action cites its capability. Every capability cites its biometric witness.

---

## 7. The pure cost — what's hard

**1. ~6-10K LOC of new Rust** for the cognitive_dag module + traversal + Macaroon-style capability calculus + LoRA-light companion engine + replay verification. Substantial, not impossible. Estimated 4-8 weeks of focused work *after* the kernel doctrine ships.

**2. LoRA-light companion engine depends on MLX-Swift adapter API.** MLX-Swift's LoRA support exists but is research-grade. Hot-swapping LoRAs at inference time (Companion swap) needs a research spike before commitment.

**3. Replay verification is hard for non-deterministic LLM outputs.** Sampling with temperature > 0 means re-running the same prompt won't give byte-equal output. Mitigation: record the model's logits at each step (or a hash thereof); verify the *trajectory* of decisions, not the final string. This is a known technique but adds 3-5x storage to every Event.

**4. Performance overhead.** Every action becomes a graph mutation + Merkle update + signature verification. Budget ~50-200µs per Event. Acceptable if Events are coarse (one per tool call, not one per token). Verify with bench harness before committing.

**5. The DAG can grow without bound.** Vault nodes accumulate forever. Need a tiered storage strategy (hot in `redb`, warm in append-only logs, cold in compressed BLAKE3-keyed object store on disk). Out of scope for V1 but must be designed.

---

## 8. The order of operations

```
PRE-REQUISITES (must ship first)
  ✓ Kernel doctrine §11 Layer 1-6 (one Rust kernel, no parallel loops/stores)
  ✓ Phase 5 migration matrix (Pro→Core capability map)
  ✓ Phase 6 capability lattice consolidated
  ✓ AgentEvent enum stable
  ✓ Resonance Gate FFI bridge wired (already shipped: 07e33fed)
  ✓ Sovereign Gate single-owner verified

PHASE 8.A — DAG SCAFFOLD (Week 1)
  - agent_core/src/cognitive_dag/{node, edge, storage, merkle}.rs
  - Storage backend: redb
  - Tests: content-addressing, edge signing, merkle root reproducibility
  - 50+ unit tests; zero integration with existing subsystems yet

PHASE 8.B — RESONANCE PROPAGATION (Week 2)
  - Extend agent_core::resonance to walk DerivesFrom / Contradicts edges
  - Cascading invalidation
  - Tests: truth flip propagation across 1000-node test DAGs

PHASE 8.C — MACAROON CAPABILITIES (Week 3)
  - agent_core/src/cognitive_dag/macaroons.rs
  - Issue / restrict / delegate / revoke
  - Sovereign Gate session = capability root
  - Tests: composition algebra; revocation cascades

PHASE 8.D — LORA-LIGHT COMPANIONS (Week 4 — research spike)
  - MLX-Swift hot-swap research
  - Deforms edge with weight_alpha
  - Single-base, multi-LoRA storage
  - Tests: companion creation < 100ms; swap < 200ms

PHASE 8.E — SUBSYSTEM MIGRATION (Weeks 5-7)
  - Rewire Skills registry to use Skill nodes + Invokes edges
  - Rewire Procedural memory to use Procedure nodes + RecordedBy edges
  - Rewire Provenance ledger to use Event nodes (the DAG IS the ledger now)
  - Rewire Companions to use Companion + Deforms nodes
  - Old subsystem stores remain readable (backward compat) but writes go to DAG

PHASE 8.F — REPLAY VERIFICATION (Week 8)
  - epistemos-trace CLI extended with `verify-replay` subcommand
  - Export / import via .epbundle format
  - Logit-trajectory hashing for non-deterministic verification

PHASE 8.G — DOCTRINE LINTER (Week 9)
  - epistemos-doctrine-lint binary
  - Compile-time enforcement of DAG anti-patterns
  - CI integration

PHASE 8.H — DOCUMENT + SHIP (Week 10)
  - Author docs/COGNITIVE_DAG_USER_GUIDE.md
  - Public-facing materials: "Verifiable AI for your Mac"
  - Submit MLSys / NeurIPS systems track if math holds
```

---

## 9. The single sentence (canonical)

> **Epistemos is a typed cognitive DAG running in one binary, where every
> node is content-addressed, every edge is capability-gated, every truth
> value is continuously re-evaluated, every action is provenance-witnessed,
> and every personality is a lightweight deformation of one shared
> substrate.**

Six words a user can say: **typed cognitive DAG, one binary**.

Six words an investor can pitch: **verifiable AI on your own Mac**.

Six words a paper title can carry: **Cognitive DAGs as Substrate**.

---

## 10. Anti-pattern: do not implement before kernel doctrine ships

The DAG synthesis is profoundly tempting to start *now*, while the kernel
doctrine is still in motion. **Do not.** Implementing the DAG before the seven
subsystems are unified into one Rust kernel means simultaneously refactoring
across Swift, Python, parallel-Rust, and the in-tree research code — too
many variables changing at once. Doctrine order:

1. **Now (Codex sprint):** kernel doctrine Phases 1-7. Make the seven subsystems live in one Rust kernel.
2. **Then:** verify the seven subsystems are consistent and stable for two consecutive weeks of use. No regressions in the verification gates of `COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` §10.
3. **Then:** start Phase 8.A — DAG scaffold. The seven subsystems remain authoritative; the DAG runs alongside, mirroring writes for one week.
4. **Then:** Phase 8.B-G — propagate, capabilities, companions, migration, replay, linter.
5. **Then:** Phase 8.H — flip the switch; the DAG becomes authoritative; the seven legacy subsystems become read-only fallback views; one release later, removed.

Two compositions, in sequence, in one direction.

---

## Appendix A — Cross-references

```
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md      ← this doc
docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md   (predecessor — §13 references this doc)
docs/fusion/EPISTEMOS_RECONCEPTUALIZATION_2026_05_03.md
docs/fusion/EPISTEMOS_FUSION_HANDOFF_2026_05_03.md
docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md
docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md
CLAUDE.md
```

## Appendix B — Open research items

1. **MLX-Swift LoRA hot-swap latency.** Required for Companion swap < 200ms acceptance bar. Needs a small benchmark spike before committing.
2. **Logit-trajectory hashing.** Replay verification for non-deterministic outputs. Known technique, needs an implementation choice (full logit hash vs top-k logit hash vs decision-trajectory hash).
3. **DAG cold-storage strategy.** Tiered storage for unbounded vault growth. Out of scope for V1, must be designed by V2.
4. **Macaroon-style capability calculus prior art.** Investigate Tahoe-LAFS, Google's Macaroons paper, biscuit-auth crate for Rust. Pick canonical implementation pattern.
5. **Distributed sharing.** A content-addressed DAG is naturally shareable (like IPFS). Should Epistemos eventually support cross-device sync via DAG diff merging? V3 question.
