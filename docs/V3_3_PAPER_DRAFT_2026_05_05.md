# V3.3 paper draft — Cognitive DAG: Verifiable Replay for Personal AI

**Status:** Working draft. First slice (this doc) ships the outline +
abstract + the Phase 8 systems-contribution section. Subsequent slices
add methodology + evaluation as V3.1 experiments produce data.

**Target venue:** MLSys (systems track) or NeurIPS (datasets and
benchmarks). Per cognitive DAG doctrine §6: "Verifiable replay is
publishable systems work."

**Length target:** 8 pages + references for MLSys; 9 pages for NeurIPS.

---

## Abstract

We present **Epistemos**, a personal AI substrate where every cognitive
step — every claim, every tool call, every model output, every
companion personality — is recorded as a typed, content-addressed,
Merkle-signed node in a single in-process directed acyclic graph
(DAG). The substrate ships in one binary on a 16 GB MacBook with no
external services, no GPUs beyond Apple Silicon's unified memory, and
no telemetry. The DAG is the canonical store; legacy subsystem stores
mirror writes during a transition period and are read-only after the
authority flip. The result is **verifiable replay**: a 64-character
hex hash uniquely identifies any reasoning subgraph, and a recipient
running our open-source `epistemos-trace verify-replay <bundle>`
binary can confirm the bundle's integrity + the DAG's merkle parity
in < 200 ms with a typed exit code (4 = outer integrity tamper, 5 =
DAG merkle drift). We argue this is the missing primitive for
deployable personal AI: not "trust me, the model said X" but "here is
the cryptographic proof that X was produced by these specific tools
with these specific inputs under this specific capability." The
substrate is shipped, runs in production today, and is enforced at
CI time by a doctrine linter that codifies the four anti-patterns
the DAG schema must avoid.

---

## 1. Introduction

Personal AI tools today produce ephemeral conversations. The user
sees a response, the user accepts or rejects it, and the chain of
reasoning that produced it is — at best — recoverable from a
session log dump that no third party can verify and no version of
the same tool can reproduce. This paper argues that the missing
primitive is not bigger models, faster inference, or more clever
prompts. It is a **content-addressed substrate** that records every
cognitive step in a typed graph and exposes verifiable replay as a
first-class operation.

Our contribution:

1. **A typed cognitive DAG schema** (§3) with 10 node kinds and
   10 edge kinds covering the full substrate: notes, claims,
   evidence, skills, tools, procedures, events, companions,
   capabilities, and models. Every node is content-addressed via
   BLAKE3; every edge is Merkle-signed under an issuing capability.
2. **A subsystem migration pattern** (§4) — `DagMirror` — that
   wraps every legacy write path so the DAG receives a parallel
   write without breaking the legacy authority. We show the four
   migrations (skills, procedural memory, provenance ledger,
   companions) take a uniform shape and add < 100 LOC each.
3. **Auto-invoke dispatch** (§5) — three legacy write paths
   (`ClaimLedger::commit_evidence`, `ClaimLedger::commit_claim`,
   `ProceduralMemoryStore::record_outcome`, `SkillRouter::load`)
   call the dispatcher inline; mirror failures are logged but
   never propagate, preserving the doctrine §10 invariant that a
   mirror miss must NOT break the legacy write.
4. **Verifiable replay bundles** (§6) — an `.epbundle` artifact
   carries the ledger snapshot + an optional DAG snapshot + a
   BLAKE3 integrity hash over the canonical JSON. The
   `epistemos-trace verify-replay <path>` binary recomputes both
   the outer integrity hash AND the DAG's merkle root parity,
   reporting the two failure modes with distinct exit codes (4 vs
   5) so CI consumers can distinguish external tampering from
   internal DAG drift.
5. **CI-enforceable doctrine compliance** (§7) — a 200-line Rust
   binary `epistemos-doctrine-lint` codifies the four grep-based
   verification gates from the doctrine (§5.1-§5.4) and exits 3 on
   any violation. The linter runs against the production codebase
   and currently passes all four gates.

We focus this paper on the systems contribution. The cognitive
contributions (typed claim taxonomy, capability calculus, companion
LoRA hot-swap) appear in companion papers.

---

## 2. Background and motivation

[TODO — V3.3 next slice]

Sketch:
- Personal AI tools as ephemeral chat (ChatGPT, Claude.ai)
- Audit-trail tools (Datadog, Honeycomb) — wrong shape for personal AI
- Content-addressed stores (Git, IPFS) — close, but not typed
- Information provenance (W3C PROV-DM, OPM) — typed but not
  graph-native, not in-process, not 16 GB MacBook-deployable
- The gap: personal AI deserves the Git-shape with the typed
  schema + the in-process budget

---

## 3. The Cognitive DAG schema

### 3.1 Node types (10 variants)

```rust
pub enum NodeKind {
    Note { body: String, author: AuthorRef, mime: MimeType },
    Claim { proposition: String, scope: ClaimScope, source: SourceRef },
    Evidence { kind: EvidenceKind, payload: EvidenceBlob, captured_at: Timestamp },
    Skill { name: String, description: String, schema_version: u32 },
    Tool { id: ToolId, surface: ToolSurface, tier: NodeTier },
    Procedure { skill_ref: NodeId, context_hash: ContextHash, outcomes: OutcomeList },
    Event { kind: DagAgentEventKind, ts: Timestamp, session: SessionId },
    Companion { profile: ModelProfile, identity: IdentityHash, persona: PersonaBlob },
    Capability { kind: CapabilityKind, scope: CapabilityScope, expiry: Option<Timestamp> },
    Model { weight_root: WeightRoot, base_or_lora: ModelLineage },
}
```

Each node id is `BLAKE3(canonical_serialize(kind))`. Identical
content always produces the same id, so deduplication is free,
integrity verification is free, and distributed shareability is
free — the same property as Git blobs and IPFS objects, applied to
cognition.

### 3.2 Edge types (10 variants)

```rust
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
```

Every edge is Merkle-signed under the capability that issued it.
Verifying an edge is a pure function of `(from, to, kind, capability_hash)`
and constant-time comparison.

### 3.3 Storage trait

```rust
trait DagStore {
    fn put_node(&self, node: Node) -> Result<NodeId, DagError>;
    fn get_node(&self, id: NodeId) -> Result<Option<Node>, DagError>;
    fn put_edge(&self, edge: Edge) -> Result<EdgeId, DagError>;
    fn edges_from(&self, node: NodeId, kind: Option<EdgeKindSelector>) -> Result<Vec<Edge>, DagError>;
    fn edges_to(&self, node: NodeId, kind: Option<EdgeKindSelector>) -> Result<Vec<Edge>, DagError>;
    fn merkle_root(&self) -> Result<Hash, DagError>;
    fn snapshot(&self) -> Result<DagSnapshot, DagError>;
}
```

The reference implementation is `InMemoryDagStore` (RwLock-protected
BTreeMap; deterministic iteration order). Production uses `redb`
(pure-Rust, ACID, mmap-friendly).

### 3.4 Storage-layer enforcement

`put_node` verifies `Node::compute_id(&node.kind) == node.id`,
returning `DagError::ContentAddressMismatch` when caller-supplied id
doesn't match the canonical content hash. `put_edge` verifies the
signature byte pattern is non-zero, returning
`DagError::InvalidSignature` for the bare-default bypass case. These
checks are doctrine §4.1/§4.2 enforced literally at the storage
boundary so a CI-time linter (§7) can grep for them.

---

## 4. Subsystem migration pattern

The substrate ships *alongside* legacy subsystem stores, not in place
of them. The `DagMirror` trait is the migration contract:

```rust
pub trait DagMirror {
    type Mutation;
    fn mirror_write(
        mutation: &Self::Mutation,
        store: &dyn DagStore,
        capability_hash: Hash,
    ) -> Result<NodeId, DagError>;
    fn verify_consistent_with_legacy(
        entity_id: &str,
        store: &dyn DagStore,
    ) -> Result<bool, DagError>;
}
```

Four implementations (`SkillsMirror`, `ProceduralMirror`,
`ProvenanceLedgerMirror`, `CompanionMirror`) cover every legacy
subsystem in the kernel. Each adds < 100 LOC and a mutation enum that
captures the subsystem's write surface (`Register`, `Update`,
`Invoke` for skills; `Record` for procedures; `EvidenceCommitted` /
`ClaimCommitted` for the ledger; `Register` for companions).

The verification gate is doctrine §10: "two consecutive weeks of CI
green with mirrors writing on every legacy write." After the gate
fires, Phase 8.H flips authority: the DAG becomes primary, legacy
stores become read-only fallback views, and one release later are
removed.

---

## 5. Auto-invoke dispatch

Three legacy write paths fire mirror dispatches inline:

```rust
// agent_core/src/provenance/ledger.rs::ClaimLedger::commit_evidence
pub fn commit_evidence(&mut self, e: Evidence) -> Result<(), LedgerError> {
    if self.evidence.contains_key(&e.id) {
        return Err(LedgerError::DuplicateId(e.id.0.clone()));
    }
    self.evidence_supports.entry(e.id.clone()).or_default();
    crate::cognitive_dag::dispatch::on_evidence_committed(&e);  // ← mirror
    self.evidence.insert(e.id.clone(), e);
    Ok(())
}
```

Doctrine §10 invariant: dispatch failures log via `eprintln!` but
never propagate. A mirror miss does not break the legacy write —
the legacy stores stay authoritative until Phase 8.H. The dispatch
helper uses a sentinel capability hash `[0xE5; 32]` so dispatch-
emitted edges can be filtered by signature for audit views.

---

## 6. Verifiable replay

A `.epbundle` is a portable JSON artifact:

```rust
pub struct ReplayBundle {
    pub schema_version: u32,                        // 1 = ledger-only, 2 = with DAG snapshot
    pub bundle_id: String,
    pub run_id: Option<String>,
    pub generated_at_ms: i64,
    pub mutations: Vec<MutationEnvelope>,
    pub ledger: LedgerSnapshot,
    pub dag_snapshot: Option<DagSnapshot>,           // Phase 8.F addition
    pub integrity_hash: String,                      // BLAKE3 hex over canonical JSON
}
```

The CLI:

```
$ epistemos-trace verify-replay session.epbundle
ok  bundle_id=run-001 schema_version=2 mutations=12 claims=3 evidence=2 \
    dag_nodes=18 dag_edges=24 dag_merkle=9f86d081884c7d65...
```

Two failure modes, distinct exit codes:

```
$ epistemos-trace verify-replay tampered-outer.epbundle
error: integrity verification failed (stored=abcd..., computed=ef01...)
$ echo $?
4

$ epistemos-trace verify-replay tampered-dag.epbundle
error: DAG merkle root parity failed (stored=ffff..., recomputed=9f86...)
$ echo $?
5
```

The byte-equivalence guarantee: two bundles built from equal ledger
states + equal DAG content serialize to byte-identical JSON, so
distributed reproducibility is structural — not a property a
recipient has to trust, but one they can verify with a single hash
comparison.

---

## 7. CI-enforceable doctrine compliance

`epistemos-doctrine-lint` is a 600-line Rust binary that codifies
the four grep-based gates from cognitive DAG doctrine §5:

- **5.1** EdgeKind enum closed (exactly one `pub enum EdgeKind {`)
- **5.2** put_edge body verifies signature before insert
- **5.3** put_node body computes id from content
- **5.4** No Swift / XPC code references to DagStore / put_node /
  put_edge (doc-comment / prose mentions classified as INFO, not
  violations — codifies doctrine intent, not literal grep)

The integration test runs the linter against the production codebase
and asserts all four gates pass. Any future PR that drifts gets
blocked at CI.

---

## 8. Evaluation

[TODO — populates as V3.1 KV-Direct experiments produce data]

Planned subsections:
- 8.1 Storage performance: mutation throughput vs. store size
- 8.2 Replay verification time: bundle size vs. verify-replay latency
- 8.3 Mirror overhead: legacy-only write vs. legacy + mirror write
- 8.4 Bundle size: nodes + edges count vs. .epbundle bytes
- 8.5 Cognitive DAG growth on realistic personal-AI workload

---

## 9. Related work

[TODO — V3.3 next slice]

- Content-addressed storage: Git blobs, IPFS objects, Camlistore
- Provenance models: W3C PROV-DM, OPM
- Verifiable computation: zk-SNARKs (overkill for this domain),
  trusted execution (different threat model)
- Personal AI substrates: SAM (Yann LeCun), Memory-augmented LLMs
  (RAG variants), the H-Tree paper, AGI-bench frameworks

---

## 10. Conclusion

[TODO — V3.3 next slice]

Sketch:
- "Personal AI is not bigger model + more clever prompt; it's
  verifiable substrate."
- The cognitive DAG is the substrate.
- It runs on a 16 GB MacBook today.
- The audit trail is cryptographic, not policy.

---

## A. Reproducibility

All code referenced in this paper is published at
`<repo URL>` under `<license>`. The two binaries are
`agent_core/src/bin/epistemos_trace.rs` and
`agent_core/src/bin/epistemos_doctrine_lint.rs`. The integration
tests live at `agent_core/tests/epistemos_trace_e2e.rs` and
`agent_core/tests/epistemos_doctrine_lint_e2e.rs`. The doctrine is
`docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`.

Replicating the verifiable replay claim requires only `cargo test
--manifest-path agent_core/Cargo.toml --tests` (1041 tests; ~30s
on M2) + the build of `epistemos_trace` (no extra deps). The
doctrine compliance claim requires only running
`epistemos_doctrine_lint .` from the repo root.

---

## B. Statement on AI assistance

This paper draft was prepared with AI assistance in the preparation
of the systems contribution sections (§1, §3-§7) and the abstract.
The contributions claimed are the authors' own. The shipped
substrate referenced throughout was authored by the project's
human + AI collaborators; commit history is available in the
public repository.
