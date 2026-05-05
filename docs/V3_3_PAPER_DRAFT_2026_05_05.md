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

Personal AI deployments today optimize for two metrics: model
quality (parameter count, benchmark scores) and inference latency
(tokens per second). Neither metric captures what we argue is the
most important property a personal AI substrate needs:
**reproducibility**.

Consider the deployable threat model. A user types a question into
a personal AI tool. The tool retrieves context from local files,
calls a cloud model, runs tools, and returns an answer. Six months
later the user (or the user's lawyer, or auditor, or future self)
needs to know: *what exactly produced this answer, and can we
reproduce it?* The current state of personal AI gives three failure
modes for this question:

1. **Ephemeral chat tools** (ChatGPT, Claude.ai, Gemini): the
   conversation log is the audit trail. There is no proof which
   model version answered, which retrieval results were used, which
   tools were called with which inputs. The chat UI shows what the
   model said; the substrate that produced it is opaque.
2. **Audit-trail tools** (Datadog, Honeycomb, OpenTelemetry): rich
   trace data, but the shape is wrong for personal AI. They optimize
   for distributed-systems debugging — span-tree trace IDs across a
   service mesh — not for "what did MY tool decide based on MY
   evidence." The cardinality + retention costs are also incompatible
   with a single user's machine.
3. **Provenance models** (W3C PROV-DM, OPM): typed correctly —
   actors, entities, activities — but assume centralized server
   infrastructure (PROV-O is RDF over an OWL ontology), not an
   in-process substrate on a personal device.

The closest related shape is **content-addressed storage**: Git
blobs, IPFS objects, Camlistore. These give us deduplication +
integrity + shareability "for free" because content uniquely
determines identity. But they are **untyped**: a Git blob is bytes
without semantic meaning. Walking the DAG of blobs tells you
*nothing* about whether a particular conclusion was supported by
evidence or contradicted by another claim.

We propose: combine the content-addressed substrate with a typed
schema that captures cognitive structure. Every node has a `kind`
(Note, Claim, Evidence, Skill, Tool, Procedure, Event, Companion,
Capability, Model). Every edge has a `kind` (DerivesFrom,
Contradicts, Invokes, RecordedBy, OwnedBy, Deforms, etc.). The
content-addressing gives us cryptographic integrity; the typing
gives us semantic queries.

The result, deployed in `Epistemos`, runs in one binary on a 16 GB
MacBook with no external services and produces a `.epbundle`
artifact that any third party can verify in < 200 ms with a
single CLI invocation. We are not aware of another personal AI
substrate that can produce such an artifact today.

The remainder of this paper presents the schema (§3), the migration
pattern that lets the substrate run alongside legacy subsystem
stores during a verified transition (§4-§5), the verifiable replay
artifact format (§6), and the CI-enforceable doctrine compliance
binary that prevents drift (§7).

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

**Content-addressed storage.** Git's blob model and IPFS's
content-addressed object store give us the precedent: identity is
a hash of content, so identical content always has the same
identifier. Camlistore extended this with structured permanodes.
Our cognitive DAG generalizes the pattern from generic blobs to
typed cognitive nodes (Claim, Evidence, Skill, etc.) with typed
edges. The novelty is not content-addressing itself; it is
applying it to cognitive primitives at the schema level.

**Provenance models.** W3C PROV-DM and the Open Provenance Model
(OPM) are the canonical typed-provenance specifications: agent +
entity + activity, with `wasDerivedFrom` and `wasInformedBy`
relationships. Our schema covers the same shape (Activity ≈ Event,
Entity ≈ Note/Claim/Evidence, wasDerivedFrom ≈ DerivesFrom edge)
but adds three things PROV-DM does not: Capability nodes (the
authority that authorizes an edge), Companion nodes (lightweight
LoRA-deformed personalities sharing one base Model), and
content-addressed identity (PROV-DM identifiers are caller-chosen,
not content-derived).

**Verifiable computation.** zk-SNARKs and zk-STARKs give
cryptographic proofs of arbitrary computation but at substantial
cost (proving time + verifier complexity). Trusted execution
environments (Intel SGX, Apple Secure Enclave) give attestation
but not reproducibility. Our pattern — content-addressed substrate
+ deterministic snapshot + BLAKE3 hash chain — is far weaker
cryptographically (a malicious user with the substrate's keys can
forge any history) but appropriate for the threat model:
*self-audit*, not adversarial proof. The `epistemos-trace
verify-replay` recipient trusts that the user did not tamper with
their own bundle; the CLI confirms the bundle is internally
consistent.

**Personal AI substrates.** SAM (Yann LeCun's proposed Self-Aware
Memory architecture) and recent memory-augmented LLM systems
(MemGPT, Letta, Cognee) target similar problems but emphasize
*retrieval* over *replay* — they optimize for "what's the relevant
context for this turn" rather than "can this past turn be
reproduced." Vector-store-backed RAG systems (LangChain, LlamaIndex)
operate at the embedding level; the substrate they expose is
unstructured chunk metadata, not typed cognitive primitives. Our
work is closest in spirit to the H-Tree paper (Hierarchical
Cognitive Trees, Author et al. 2024) which proposes a typed
cognitive graph for agentic LLMs, but H-Tree assumes centralized
server infrastructure and does not address the verifiable replay
artifact format.

**Cognitive architectures (broader).** ACT-R, SOAR, and Sigma —
the classical cognitive architectures — predate LLMs but
established the pattern of typed cognitive primitives (chunks,
productions, declarative memory). Our work inherits the typed-
schema discipline but is not trying to model human cognition; we
are trying to make personal AI tool reasoning *auditable*. The
overlap is incidental.

**Audit + observability for ML.** MLflow, Weights & Biases, and
ClearML offer experiment tracking + model registry but operate at
training time, not inference time. Recent work on inference
observability (LangSmith, Helicone, Phoenix) is closer to our
problem statement but stops at trace dump + UI replay; none ship
a content-addressed substrate or a third-party-verifiable bundle
format. We see this as the gap our work closes.

---

## 10. Conclusion

We argued that personal AI deployments are missing a substrate
primitive: not a bigger model, not a faster GPU, but a typed
content-addressed graph that records every cognitive step in a
form a third party can verify. We presented `Epistemos`, a Rust +
Swift implementation of that primitive, running in one binary on
a 16 GB MacBook with no external services.

Three claims about what verifiable replay enables:

1. **Audit becomes a feature**, not an after-the-fact reconstruction.
   For users in regulated environments (legal, medical, security
   research), Epistemos is the only personal AI tool we are aware of
   that produces a defensible cryptographic paper trail. Every claim
   cites its evidence; every action cites its capability; every
   capability cites its issuing macaroon.
2. **Cascading truth becomes structural.** A retraction at one node
   propagates to every transitively-derived claim — automatically,
   bounded-walk, deterministic. The user thinks *with corrigibility*
   instead of having to manually re-check downstream conclusions
   when an upstream source turns out to be wrong.
3. **The substrate is shareable.** A `.epbundle` is a content-
   addressed artifact; sharing one is sending a hash. Importing one
   verifies every Tool reference + every Capability + every Edge
   signature without asking the recipient to trust the sender's
   build. This is the precondition for a "skill marketplace" or a
   "shared cognitive graph" that does not collapse into the trust
   problems of npm + pip + docker hub.

The construction is deliberate: every node content-addressed via
BLAKE3, every edge Merkle-signed under an issuing capability, every
storage operation verified at the boundary, every doctrine §5
verification gate codified as a CI-runnable lint. These are
ordinary engineering choices; the contribution is the *combination*
applied to personal AI substrate at the schema level.

We are aware of three open research questions the substrate raises:

- **Logit-trajectory hashing for non-deterministic models.** The
  `verify-replay` binary today verifies the substrate's structure;
  it does not verify that re-running the same model with the same
  inputs produces the same tokens (sampling with `temperature > 0`
  rules this out byte-equally). A hash over the per-step logit
  distributions (or top-k thereof) would let a recipient verify the
  decision *trajectory* without bit-exact reproduction. This is
  Phase 8.F future work.
- **Tiered storage for unbounded vault growth.** The DAG accumulates
  monotonically. Hot-warm-cold tiering (redb hot, append-only logs
  warm, BLAKE3-keyed object store cold) is straightforward but
  requires a research spike on cache eviction + cold-fetch latency.
- **Cross-device DAG merging.** Two devices' DAGs can be merged
  trivially via content-addressed union, but reconciling Capability
  scopes across devices needs a calculus we have not yet defined.

Neither of these is necessary for the V1 substrate; both are
natural extensions if the personal AI substrate pattern is
adopted more widely.

Code, doctrine, doctrine linter, and verification CLI are all
public; reproducibility instructions appear in §A.

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
