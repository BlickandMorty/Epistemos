---
state: agent_manageable_architecture_canon
created_on: 2026-05-30
purpose: Drift-control register for agents working across the Epistemos substrate architecture.
authority_order:
  - current code plus passing verification logs
  - docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md
  - docs/audits/UNFINISHED_ARCHITECTURE_AND_BEST_COMBO_MANIFEST_2026_05_30.md
  - docs/audits/ARCHITECTURE_NO_GAP_BUILD_ORDER_2026_05_28.md
  - this register for naming and ownership discipline
---

# Agent-Manageable Architecture Canon - 2026-05-30

This register exists so unattended agents do not keep creating new names,
parallel memory systems, or "almost the same" search/citation/runtime layers.
It does not replace current source truth. It maps the user's latest synthesis
to stable build rules that agents can apply before editing.

## Final Canon Sentence

Epistemos is:

```text
one substrate, three motions, five authority fields, visible proof
```

Definitions:

| Term | Canonical meaning | Agent check |
|---|---|---|
| One substrate | UAS + ACS + WBO/LatticeBudget + SCOPE-Rex + Eidos + ActiveAssembly + AnswerPacket. | Do not build a detached app, agent, memory, search, proof, or model stack. Plug into the substrate. |
| Three motions | Lift/Ingest, Project/Compress/Recall, Mutate/Promote. | Name which motion the change implements. |
| Five authority fields | RuntimePlane, ResidencyTier, WBO/error budget, WitnessRef/proof, RouteProfile/dispatch route. UAS address is the identity that carries them. | New durable objects must declare these fields or an explicit exemption. |
| Visible proof | User-visible evidence, route, admission, run event, claim label, and rollback where relevant. | A hidden green status is not enough. Surface WRV: Wired, Reachable, Visible, Verified. |

## Current Work Split

| Work lane | Owner right now | Safe scope |
|---|---|---|
| Deep substrate stack | Detached architecture heartbeat loop in `Tools/audits/epistemos_architecture_heartbeat_loop.sh`. | Rust UAS/ACS/WBO/falsifier/planner work, one small verified commit per loop. |
| Product evidence surface | Interactive Codex/user-directed agents. | Swift chat, Eidos evidence cards, AnswerPacket/provenance visibility, focused tests. |
| Theme/font bundle | Separate user-mentioned theme/font agent. | Do not edit from architecture agents unless user explicitly resumes it. |
| Heavy runtime probes | Nobody by default. | No 70B, 128K, mmap/SSD stress, full Metal, or live heavy MLX/GGUF probe until crash-safe harness gates allow it. |

The architecture loop may advance the deeper stack, but it is not magic
completion. It must still leave code, focused verification, commit evidence,
and an honest next-row cursor. Other agents must check loop status before
touching Rust/substrate files.

## Canonical Organ Registry

| Organ | Role | Allowed aliases or sublayers | Forbidden drift |
|---|---|---|---|
| UAS | Identity fabric for notes, graph nodes, claims, tool results, agent events, KV pages, model components, proofs, and projections. | UasAddress, UasKind, Ontological Address Space as semantic layer on top. | Do not call EML, MLX, or the vault the identity primitive. |
| RuntimePlane | Authority separation for State, Episodic, Assembly, Controller, Verification. | Five-plane runtime. | Do not mix model state, user notes, tool actions, and proofs without plane labels. |
| ResidencyTier | Where an object lives and what may claim it. | CurrentApp, VerifiedFloor, CapabilityCeiling, Research/Vault. | Do not promote research artifacts into product UI as shipped behavior. |
| WBO / LatticeBudget | Error, compression, quantization, semantic, and numeric drift accounting. | Lattice/WBO, T_W/T_K/T_R/T_Q/T_S/T_SE/T_num. | Do not make lattice replace UAS or ACS. |
| ACS | Admission and anchor layer. Produces allow/warn/defer/quarantine/reject verdicts and proofs. | ACSAdmission, AcsAnchor, SCOPERexAdmissionProof. | Do not treat ACS as only a settings row or health chip. |
| SCOPE-Rex | Governance spine for typed artifacts, mutations, claims, witnessed state, and run logs. | TypedArtifact, MutationEnvelope, ClaimGraph, RunEventLog. | Do not let tool calls or durable changes bypass witness records. |
| Eidos | Evidence gate and closed-citation contract. It validates which retrieved evidence may be cited and shapes agent-consumable evidence packets. | eidos.query, citation universe, closed citation, Eidos card. | Do not reduce Eidos to a generic search bar or create AgentCitation as a separate authority. |
| VaultRecall | Candidate retrieval contract over the user's vault. | vault.search, knowledge.recall, retrieval trace, RRF/BM25, future semantic/HNSW/Metal rerank. | Do not let agents browse the filesystem first for vault notes. App/vault retrieval comes first; Finder/file search is fallback or explicit-path only. |
| Halo | Ambient recall while the user types. | search/readable blocks, contextual note recall. | Do not make Halo the deliberate agent evidence gate. |
| Shadow | Semantic projection/index layer. | ShadowBackedSemanticIndex, ShadowProjection candidates. | Do not claim ShadowProjection product behavior without falsifier and WRV. |
| ActiveAssembly | Waking support-set selector before inference/action. | ActiveAssemblyPacket, ActiveAssemblySelector. | Do not claim it is product-wired until chat/agent/runtime consume it visibly. |
| PageGather | Sketch/residual/exact page selection and packetized retrieval primitive. | PageGather packetized floor, dense primary pending. | Do not treat packetized mitigation as dense primary PageGather. |
| RuntimeRouter / RouteProfile | Chooses model, support, WBO, route, witness, and fallback. | RouteProfile, LocalPolicy, model badges. | Do not let chat call a model without route evidence. |
| System G / AgentRuntime | Governed execution path from MissionPacket through AgentEvent and RunEventLog to AnswerPacket. | AgentBlueprint, MissionPacket, ExecutorTrait, LocalAgentLoop. | Do not recreate old Hermes subprocess branding or hidden agent memory. |
| AnswerPacket | User-visible final output envelope. | ClaimKind, citation IDs, evidence, provenance, VRM label. | Do not end at raw model text when evidence/provenance was used. |
| RunEventLog | Replayable action and tool timeline. | AgentEvent, TimelineView, replay. | Do not hide retries, failed searches, rejected admissions, or mutations. |
| MutationEnvelope | Durable change container. | rollback path, typed mutation, SCOPE-Rex witness. | Do not write user state without mutation/provenance/rollback path where applicable. |
| ClaimGraph / ClaimKind / VRM | Claim classification and truth labels. | Empirical, Mathematical, CodeInvariant, Causal, Speculative; Verified/Plausible/Speculative/Blocked. | Do not show green research claims without evidence and classification. |
| EML-IR | Elementary-function/proof chart inside the substrate. | EML Observatory, MathLab. | Do not call EML the whole substrate. UAS is the fabric. |
| F-ULP Oracle | Numerical falsifier for EML/Metal arithmetic floor. | fulp_oracle, Metal/ULP witness. | Do not collapse with EML-IR until ownership and witness path are proven. |
| KV-Direct / L3 SSD Oracle | Long-context KV/cache residency lane. | mmap-backed KV, NF4, residual patching, SSD spill. | Do not treat prompt-cache reload or metadata as KV-Direct pass. |
| WeightBlockManifest / ResidencyPlan | Safe non-executing path into 70B/local cocktail. | range hash, dry-run residency, provider reference manifest. | Do not load heavy model files from this lane before crash-safe measured probes. |
| Parameter Connectome | Research atlas for model mechanisms. | ParamAnchor, QKEdgeAnchor, rank-one components, SPD/VPD/SAE motifs. | Do not productize model-internal claims without falsifier and rollback. |
| Research Construction Engine | ProblemCard to ConstructionGraph to falsifier/proof. | ShadowProjection, ConstructionCard, LeanProofObligation. | Do not move ahead of measured runtime gates except as candidate artifacts. |
| HermesPromptCompatibility | Prompt/function-call format compatibility for Hermes-trained local models. | Hermes parity. | Do not revive Hermes Agent subprocess/UI overlay. That is dead. |

## Adapter Rules

These are hard rules for future agents:

1. `AgentSearch` may exist only as an adapter over VaultRecall plus Eidos.
2. `AgentMemory` may exist only as a view over RunEventLog, VaultRecall,
   UAS-addressed artifacts, and explicit memory writes.
3. `AgentCitation` may exist only as a consumer of Eidos citation universe IDs.
4. `file.search` and Finder-style lookup must not be the first move for vault
   notes. Use `eidos.query` first, then `vault.read` with a returned path.
5. Tool writes must produce or route toward MutationEnvelope, ACS verdict,
   provenance, and rollback when the change is durable.
6. Health rows must report stub, fixture, research, candidate, blocked, or
   production honestly. A health row is not proof by itself.

## Current Product Spine Target

The minimum path that makes the architecture legible is:

```text
chat/user intent
  -> MissionPacket or query intent
  -> ActiveAssembly support-set request
  -> VaultRecall candidate retrieval
  -> Eidos evidence/citation gate
  -> ACS admission where action or durable claim is involved
  -> RuntimeRouter/RouteProfile
  -> model/tool execution
  -> RunEventLog
  -> AnswerPacket
  -> Provenance Console / Eidos card / visible badges
```

Current source truth has pieces of this path, including `eidos.query` over the
vault recall trace backend. The backend status is intentionally honest:
`production_lexical_trace_semantic_pending`. Do not claim the full semantic
HNSW/Metal/rerank stack is complete until code and falsifiers prove it.

## Build Checklist For Any Architecture PR

Before editing, answer these in the commit message, test name, or handoff:

| Check | Required answer |
|---|---|
| Motion | Lift/Ingest, Project/Compress/Recall, or Mutate/Promote. |
| Organ | Which registry organ is being changed. |
| Identity | UAS address pattern or explicit UAS exemption. |
| Plane | RuntimePlane affected. |
| Residency | CurrentApp, VerifiedFloor, CapabilityCeiling, Research/Vault, or exemption. |
| Error budget | WBO/LatticeBudget term or reason no approximation is introduced. |
| Witness | RunEventLog, MutationEnvelope, ClaimGraph, falsifier artifact, test, or proof. |
| Admission | ACS verdict path or reason no admission applies. |
| Route | RouteProfile/RuntimeRouter path if model/tool execution is affected. |
| Visibility | User-visible surface or honest not-visible-yet label. |
| Verification | Focused test/falsifier/source guard run. |
| Rollback | Durable-state rollback path, dense/reference rollback, or not applicable. |

If an agent cannot answer these, it should stop claiming architecture progress
and either narrow the patch or record a skip reason.
