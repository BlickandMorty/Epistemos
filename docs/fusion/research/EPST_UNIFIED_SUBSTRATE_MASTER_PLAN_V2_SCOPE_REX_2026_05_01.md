# Epistemos Unified Substrate Master Plan V2 — SCOPE-Rex Integration

Date: 2026-05-01  
Purpose: update the existing Epistemos fusion bundle with the latest SCOPE-Rex / ODSC² research while preserving the verified Core release path.

## 0. Executive decision

The substrate is good to work on, but only after one correction: SCOPE-Rex is a V1.5/Pro/R&D substrate layer, not a replacement for the current Core V1 release lane.

The final architecture should be described as:

> Epistemos is a verifiable cognition substrate. The model proposes. Rex governs. The app owns memory, claims, tools, policy, provenance, retrieval, and replay.

The updated spine is:

```text
TypedArtifact
  -> MutationEnvelope
  -> RunEventLog
  -> AgentEvent
  -> GraphEvent
  -> WitnessedState / ClaimGraph / FeatureFingerprint
  -> Halo | Graph | Theater | Audit | Research Mode
```

The new SCOPE-Rex layers do not delete the older spine. They deepen it.

## 1. Source anchors from new research

### SCOPE-Rex OSPC — Final Fusion Architecture
Core excerpt:

> “A local 7B–30B model becomes more useful than cloud chat for personal agentic work not by being smarter in raw reasoning, but by owning durable context, verified memory, deterministic traces, inspectable features, contracted tool use, cheap adapter specialization, sleep-cycle consolidation, and layered residency governance.”

Adopt this as the long-term product moat, but rephrase product claims as “local models become stronger for user-specific work,” not “local beats cloud everywhere.”

### SCOPE-Rex Omega
Core excerpt:

> “Treat ‘inter-dimensional reasoning’ as cross-space consistency, not as mystical extra dimensions.”

Canonical state spaces:

```text
token space
latent-feature space
claim space
proof space
tool/world state
persistent memory
agent runtime state
authorization state
```

This is the correct replacement for “infinite context.”

### ODSC² / OSFT + PSOFT + coSO verification
Core corrections:

- PSOFT is single-task, not continual learning.
- coSO is gradient projection + Frequent Directions sketching, not trajectory optimization.
- OSFT has capacity and SVD overhead limits.
- “zero forgetting,” “infinite tasks,” and “infinite recursion” must be cut from product claims.

This research is valuable because it prevents the substrate from becoming fantasy language.

## 2. Updated substrate layers

```text
L9  Safety & Authority       Capability envelopes, tool contracts, biometric/approval gates
L8  Consolidation            GRPO priors, harness evolution, PSOFT adapters, future OSFT/coSO
L7  Residency Governor       Decides where knowledge/skills live
L6  Memory Substrate         Semantic ledger, claim graph, HCache/KV refs, feature fingerprints
L5  Agent Runtime            Tools, MCP, traces, evaluator loops, repair loops
L4  Claim & Ontology         Claim extraction, evidence constraints, Z3/Kani/proof obligations
L3  Feature Observatory      SAE fingerprints, repetition detection, failure features, steering research
L2  Model Substrate          AFM, Qwen/Gemma/MLX, verifier models, optional cloud teacher
L1  Execution Substrate      Swift actors, Rust kernel, UniFFI, MLX/CoreML/Metal
L0  Hardware                 Apple Silicon UMA, CPU/GPU/ANE via public APIs, SSD, Secure Enclave
```

## 3. The real “infinite context” design

Do not build around literal infinite context or raw KV snapshots as canonical memory.

Build:

```text
M = M_semantic + M_feature + M_hidden + M_kv
```

Where:

- `M_semantic`: durable facts, claims, sources, decisions, artifacts, provenance.
- `M_feature`: feature fingerprints, SAE signatures, repetition/failure patterns.
- `M_hidden`: optional hidden-state restoration / HCache-style research lane.
- `M_kv`: active short-term working state only.

Product claim:

> Epistemos creates unbounded external cognition, not infinite neural context.

## 4. Residency Governor — the actual invention

Every behavior, memory, tool pattern, workflow improvement, adapter, and learned correction must be assigned to a residency level.

```rust
pub enum Residency {
    TransientContext,   // temporary, session-only
    RetrievalMemory,    // semantic ledger / claim graph
    FeatureRule,        // SAE/logit/routing rule, reversible
    HarnessRule,        // runtime/harness behavior, versioned
    GrpoPrior,          // training-free experience prior
    PsoftAdapter,       // task-local learned adapter
    OsftCore,           // future durable identity consolidation
    CloudDistilled,     // distilled from cloud teacher, local copy
    Quarantine,         // never promote
}

pub struct ResidencySignal {
    pub repeat_count: u32,
    pub verification_score: f32,
    pub runtime_gain: f32,
    pub forgetting_risk: f32,
    pub safety_risk: f32,
    pub privacy_sensitivity: f32,
    pub evidence_strength: f32,
}
```

Policy:

```text
if unsafe or private -> Quarantine / biometric gate
if unverified -> TransientContext
if repeated and useful -> RetrievalMemory or FeatureRule
if repeated and measurable -> GrpoPrior / HarnessRule
if domain-local and stable -> PsoftAdapter
if cross-domain, stable, repeatedly verified -> future OSFTCore
```

This is the most profound update from the new research. It gives Epistemos a lawful way to “learn” without turning every interaction into weight mutation.

## 5. What is buildable now vs deferred

### Buildable now

- Rust semantic kernel: ledger, claims, contracts, governor.
- Claim graph and Merkleized evidence ledger.
- Training-Free GRPO-style experience library as context/harness, not weights.
- Harness versioning and trace collection.
- Feature fingerprint storage, initially with light telemetry; Qwen-Scope deep hooks later.
- Local MLX inference under a model ladder.
- Apple Foundation Models for structured controller/tool-calling where available.
- Core ML stateful models for packaged stateful helper models where useful.
- Z3/Kani as verifier layers for selected invariants/tool contracts.

### V1.5 / Pro buildable with care

- Verified Research Mode.
- Observatory Mode for Qwen-family models.
- Brain Time Machine as semantic replay, not raw KV dump.
- HCache/KV compression experiments.
- PSOFT adapter training as offline Pro research.
- DSC adapter composition if a working implementation is validated.

### Research-only

- OSFT at scale on Apple Silicon.
- coSO for LLM agents.
- full SAE steering in production.
- private ANE APIs.
- activation steering as hot-path correction.
- raw sparse-texture KV trees.
- claims of zero forgetting / infinite memory / deterministic AGI.

## 6. Updated Epistemos product modes

### Core V1 / App Store

Purpose: trust, local-first vault intelligence.

- Chat + bounded Agent.
- Halo / Contextual Shadows.
- Resource Runtime, grants, verified writes.
- Local-first, optional BYOK cloud off by default.
- No shell, Docker, external CLI passthrough, or Pro capability tunnels.
- App Intents / Spotlight / Control Center quick capture can be added as native polish.

### V1.5

Purpose: turn memory into a research-grade substrate.

- PromptTree.
- Concept Door.
- Exploration Spectrum.
- Local Analysis Mode.
- Verified Research Mode.
- Claim kernel.
- Residency Governor.
- semantic Brain Time Machine.

### Pro

Purpose: full autonomy and power-user agent workflows.

- Hermes.
- Claude Code / Codex / Gemini CLI passthrough.
- Docker/devcontainers.
- MCP stdio/HTTP servers.
- browser/computer-use.
- Simulation Theater.
- Live Files.
- adapter training / consolidation lab.

## 7. Updated model stack

### Core controller

Apple Foundation Models / Apple Intelligence path where available:

- structured tool selection
- safe vault actions
- summaries
- entity extraction
- guided generation

### Local worker

Qwen/Gemma/MLX stack:

- Qwen: strongest default local worker for tool-use and reasoning.
- Gemma: document/multimodal/prose helper.
- tiny classifier/router: 0.5B–1B if available and proven fast.
- verifier model: small model used after generation.

### Cloud teacher

Claude/OpenAI/Gemini/Kimi/etc. are teachers and heavy workers, not the identity of the app.

Use cloud to:

- solve hard tasks
- generate training traces
- produce adapters or exemplars
- audit local outputs
- create ground truth for local evaluation

## 8. Verified Research Mode — first SCOPE-Rex vertical slice

Input:

```text
User asks a research question over a vault, document, codebase, or project.
```

Pipeline:

```text
retrieve context -> draft answer -> extract claims -> classify claims -> verify what can be verified -> label unsupported claims -> repair answer -> commit artifact
```

UI output:

```text
Verified
Plausible but unverified
Speculative
Blocked / needs source / needs user approval
```

This is the fastest demo that proves SCOPE-Rex without waiting for OSFT/PSOFT/coSO.

## 9. Updated build sequence

Do not implement SCOPE-Rex before release truth is stable.

1. Phase 0: verified floor and worktree inventory.
2. Phase 1: finish current Liquid Wave slice.
3. Phase 2: Quick Capture spine merge.
4. Phase 3: Core/App Store release closure.
5. Phase 4: Halo V1 proof.
6. Phase 5: Resource Runtime closure.
7. Phase 6: V1.5 typed artifacts / PromptTree / Concept Door.
8. Phase 7: SCOPE-Rex Rust kernel prototype.
9. Phase 8: Verified Research Mode.
10. Phase 9: Feature Observatory and Brain Time Machine.
11. Phase 10: Pro adapter lab / PSOFT / OSFT / coSO research.

## 10. What to tell Codex now

Codex should not start with OSFT, PSOFT, coSO, private ANE, or activation steering.

Codex should start with:

```text
Create a SCOPE-Rex design branch only after Phase 0 is complete.
Implement a non-invasive Rust semantic kernel skeleton:
- rex-kernel/ledger.rs
- rex-kernel/governor.rs
- rex-kernel/claims.rs
- rex-kernel/contracts.rs
- rex-kernel/safety.rs
- rex-memory/semantic.rs
- rex-adapt/grpo.rs
- rex-bridge/rex.udl
Wire only one user-facing vertical slice: Verified Research Mode.
No hot-path Python. No direct weight mutation. No private APIs. No broad refactor.
```

## 11. Final decision

The new research is profound and good, but it is not a license to rewrite Epistemos.

It should update the doctrine like this:

> Epistemos V1 proves verifiable cognition through Halo, typed artifacts, Resource Runtime, and local-first vault intelligence. SCOPE-Rex V1.5/Pro turns that substrate into a witnessed research brain through claim graphs, feature observability, residency governance, and trace-based harness evolution.

That is good to go.
