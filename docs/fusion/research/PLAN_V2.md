# Epistemos PLAN v2
## Hardened Architecture, Research-Fused Roadmap, and Codex-Executable Guidance

## 1. Mission

Epistemos is a local-first cognitive operating system for notes, code, graph memory, tools, and agentic execution.

It is not:
- a single-model chatbot
- a thin AI wrapper
- only a coding agent
- only a PKM with AI bolted on

It is a system that must:
- reason over a knowledge substrate
- route work to the right runtime
- keep actions and compute inspectable
- preserve local control
- support later bounded compute steering
- support later bounded adaptation
- stay stable under Apple-Silicon memory constraints

The main market problem it solves is:
**turn fragmented personal knowledge into a usable, inspectable reasoning environment instead of leaving it scattered across notes, code, files, and chats.**

## 2. Design Doctrine

### 2.1 Core doctrine
Optimize for:
- internal coherence
- hardware realism
- bounded complexity
- failure containment
- inspectability
- phased delivery

Do not optimize for:
- novelty for its own sake
- giant feature surfaces early
- speculative architecture without telemetry
- multi-agent theatrics
- invisible magic

### 2.2 Definition of “fault-proof”
“Fault-proof” here means:
- fail explicitly
- fail reversibly
- fail observably
- never silently switch backends
- never silently mutate knowledge or weights

## 3. Non-Negotiable Architectural Laws

### 3.1 Rust remains sovereign
Rust is the sole authority for:
- routing
- lifecycle
- cancellation
- budget enforcement
- safety and policy
- fallback
- runtime resolution
- agent communication permissions
- escalation approval
- telemetry and audit

### 3.2 Public runtime contract remains stable
The stable public boundary remains:
- `load_model`
- `unload_model`
- `generate`
- `cancel`
- `stats`
- `set_policy`
- `embed`
- `adapt`
- `image_generate`

### 3.3 Apple Silicon is bandwidth-first
Treat Apple Silicon as:
- unified memory
- shared memory controller
- memory-movement constrained

Preserve:
- serial GPU -> SSD -> GPU in streamed/fallback paths
- no speculative expert prefetch during active decode
- trust-the-OS-page-cache behavior
- no assumption that overlapping I/O with compute is automatically good

### 3.4 No silent behavior
No silent:
- backend switching
- cloud escalation
- adaptation
- mask application
- sidecar activation
- fallback

Everything important must be surfaced in telemetry and summaries.

## 4. Layered System Architecture

### 4.1 Interface Layer
User-facing surfaces:
- chat
- notes
- graph
- code/editor
- future image and voice panels

### 4.2 Knowledge Layer
The knowledge substrate includes:
- markdown vault
- notes
- backlinks
- entities
- graph structure
- code files
- source references
- future persistent memory objects
- future skills / recipes

### 4.3 Control Plane
Owned by Rust.

Responsibilities:
- request classification
- runtime resolution
- policy resolution
- execution plan construction
- capability checking
- fallback decisions
- budget enforcement
- safety gating
- telemetry emission
- audit logging
- agent hierarchy governance
- overseer integration

### 4.4 Execution Plane
Owned by runtimes.

Responsibilities:
- model load/unload
- generation
- embedding
- later image generation
- later structured mask execution
- later KV policy execution
- later expert budget execution
- phase/state reporting

### 4.5 Adaptation Plane
Separate from main generation.

Responsibilities later:
- LoRA micro-updates
- bounded helper-model adaptation
- chunked update scheduling
- anchor state
- canary validation
- rollback
- adaptation telemetry

Rules:
- MLX-first
- helper-model-first
- no base-weight mutation
- no silent learning
- no default main-chat adaptation

### 4.6 Oversight Plane
Detached supervisory intelligence.

Responsibilities:
- planning
- critique
- review
- explanation
- intervention recommendation
- periodic auditing
- cost/safety review

## 5. Runtime Architecture

### 5.1 Runtime split
Keep the sibling runtime structure:
- `gguf`
- `mlx`
- `remote`

#### GGUF
Primary role:
- main local text generation
- primary reasoning path
- larger inference-first local chat models
- quantized reasoning backbones

#### MLX
Permanent role:
- embeddings
- rerankers
- classifiers
- KAN helper modules
- helper models
- LoRA / micro-TTT experiments
- summarization helpers
- memory-compression helpers
- image generation
- Apple-native small models

#### Remote
Reserved for later:
- escalation
- planner role
- optional external reasoning support

### 5.2 Runtime resolution
Keep:
- `requested_runtime_kind?`
- `resolved_runtime_kind`

Rust decides final resolution.

## 6. Public Runtime Contract v1.1

Keep the current v1 contract shape, but extend it slightly.

### 6.1 Base request identities
Keep:
- `runtime_kind`
- `execution_mode`
- `model_id`
- `artifact_id`
- `requested_runtime_kind?`
- `resolved_runtime_kind`

### 6.2 Add reasoning profile
Add:
- `requested_reasoning_profile?`
- `resolved_reasoning_profile`

Profiles:
- `standard`
- `deep_graph`
- `adaptive`
- `experimental`
- `visual_sidecar`

### 6.3 Add execution policy reference
Add:
- `execution_policy_ref?`

This is opaque and Rust-owned.

It may reference:
- retrieval budget
- graph traversal depth
- compute budget
- expert budget
- mask policy
- KV policy
- adaptation permission
- sidecar activation

### 6.4 Model handle rules
Keep runtime-scoped handles:
- GGUF handles are GGUF-only
- MLX handles are MLX-only
- cross-runtime reuse fails deterministically

### 6.5 Pull-based stream stays
Keep:
- `poll_event`
- `poll_events`
- `close_stream`

Keep event ordering guarantees exactly as they already exist.

## 7. Capability Handshake Spec v1

Purpose:
- prevent “start execution, discover mismatch later”
- make unsupported advanced features explicit before execution
- keep routing deterministic

Expose capability flags through `stats()` or sibling runtime metadata:
- `supports_generate`
- `supports_embed`
- `supports_adapt`
- `supports_image_generate`
- `supports_structured_masking`
- `supports_dynamic_sparsity`
- `supports_spec_decode`
- `supports_streaming_from_ssd`
- `supports_tool_calls`

## 8. Compute Steering Spec v1

**Compute Steering = policy-driven selection of auxiliary modules, masks, and execution budgets under explicit telemetry.**

### 8.1 Inputs
- `compute_profile`
- `compute_budget`
- runtime capabilities
- context requirements
- optional overseer hints

### 8.2 `compute_profile`
Values:
- `standard`
- `deep_graph`
- `adaptive`
- `experimental`
- `visual_sidecar`

### 8.3 `compute_budget`
Fields:
- `max_wall_ms?`
- `max_tokens?`
- `max_io_bytes?`
- `max_adapt_steps?`
- `max_aux_calls?`

### 8.4 Internal output: `ExecutionGraph`
Rust builds a small DAG of declared steps, for example:
- `retrieve_context`
- `graph_score`
- `rerank_context`
- `compress_history`
- `select_mask`
- `generate_main`
- `adapt_helper`
- `image_sidecar`

### 8.5 Scheduling law
The ExecutionGraph scheduler must:
- preserve serial I/O invariant in GGUF streamed paths
- prioritize interactive latency over background jobs
- reject unsafe overlap
- reject unsupported nodes
- fall back cleanly

## 9. Adaptation Subsystem Spec v1

### 9.1 Add adaptation entities
- `adapt_session_id`
- `adapter_id`
- `update_chunking`
- `stabilizer`
- `rollback_ref`
- `canary_policy_ref`

### 9.2 Hard rules
- session-scoped only
- never silent
- delta-only
- helper-model-first
- MLX-first
- no primary-chat default adaptation
- no base-weight mutation

### 9.3 First viable implementation
LoRA micro-TTT on helper models:
- rank-limited adapters
- chunked updates
- anchor state
- canary validation
- rollback logs
- update norm caps

### 9.4 What it is for
- knowledge ingestion
- graph enrichment
- summarization helper improvement
- retrieval reranker improvement
- domain adaptation on helper models

## 10. Oversight Plane and Overseer Architecture

### 10.1 The overseer is a role, not a model family
Do not define:
- overseer = SSM
- overseer = one fixed provider
- overseer = one giant second brain

### 10.2 Overseer responsibilities
- task framing
- review
- critique
- explanation
- budget recommendation
- safety recommendation
- intervention requests
- periodic quality audits
- user-facing transparency about what the system is doing

### 10.3 Overseer decomposition

#### Planner Overseer
Role:
- high-level planning
- task framing
- review
- critique
- “what should happen next?”

Can later be:
- local strong model
- remote strong model
- hybrid

#### Guardrail Overseer
Role:
- local budget review
- safety checks
- confidence estimation
- “is this worth more compute?”
- “should this continue?”
- “should this write?”

#### SSM Memory Sidecar
Role:
- session compression
- memory distillation
- timeline summarization
- long-note condensation

This is the right place for SSM/Mamba by default.

### 10.4 Authority boundary
Overseers may:
- recommend
- critique
- redirect
- request verification
- deny adaptation
- suggest escalation

Overseers may not:
- silently switch backend
- silently mutate policy
- silently write to knowledge
- silently trigger remote execution

Rust still decides.

## 11. Hierarchical Agent Communication Layer

### 11.1 Roles
- **Overseer**
- **Main Agent**
- **Sub-agents**
- **Rust Control Plane**

### 11.2 Allowed topology
Allowed:
- overseer -> main agent
- main agent <-> overseer
- main agent -> sub-agents
- sub-agents -> main agent

Disallowed by default:
- sub-agent <-> sub-agent
- sub-agent -> overseer directly
- overseer -> sub-agent directly

### 11.3 Message protocol
All agent-to-agent messages must be structured:
- `message_id`
- `task_id`
- `parent_task_id?`
- `sender_role`
- `sender_id`
- `recipient_role`
- `recipient_id`
- `message_type`
- `instruction`
- `constraints`
- `budget_ref`
- `evidence_refs?`
- `confidence?`
- `requested_action`
- `timestamp`

### 11.4 Budget controls
Each interaction is bounded by:
- recursion depth
- child-agent count
- review rounds
- token budget
- wall-clock budget
- allowed tools
- escalation permission

### 11.5 Audit trail
Every message must be logged with:
- sender
- recipient
- purpose
- evidence
- confidence
- cost
- whether it changed the final result

## 12. KAN Placement

Use KAN for:
- graph edge scoring
- relationship typing
- retrieval reranking
- routing hints
- novelty / ambiguity / escalation-worthiness classification

Do not use KAN for:
- replacing the main LLM backbone
- core chat generation
- always-on continual-learning-heavy mainline usage

## 13. Masking / Pruning Placement

Correct progression:
1. DIET-style structured profiles
2. DIP-style dynamic pruning experiments
3. kernel-aware sparse execution
4. IFPruning-style learned mask predictor later

Rules:
- structured masks only
- dense fallback required
- mask compile must be visible
- masks must be kernel-executable
- quantization layout compatibility must be respected

## 14. MoE / SSD Streaming Placement

Use MoE for:
- selective specialization
- expert budgeting
- deep mode
- later bigger sparse local reasoning

Rules:
- belongs in the GGUF lane
- serial streaming invariant preserved
- no speculative expert prefetch during decode
- expert budgets visible in summaries
- no hidden expert inflation

## 15. SSM / Mamba Placement

Use SSM for:
- long-session compression
- rolling memory distillation
- timeline summarization
- long-document condensation
- SSM memory sidecar

Do not use SSM for:
- default planner overseer identity
- replacing the main runtime backbone now
- default main chat path

## 16. Visual / Multimodal Lane

### Keep image generation in MLX
That part stays.

### Update dependency preference
Do not anchor long-term planning on DiffusionKit because it is archived. Prefer active MLX-Swift paths such as `flux.swift` and similar maintained Apple-native stacks.

### Default execution mode
Image generation is:
- sidecar
- sequential by default
- not assumed to co-reside with main reasoning runtime

## 17. Revised Phase Roadmap

### Phase 1 — Stable runtime foundation
Deliver:
- one real `gguf` primary path
- `mlx` preserved
- Rust control-plane authority
- explicit fallback
- serial invariant enforcement
- telemetry
- clear runtime truthfulness
- engine/format compatibility audit first

Do not deliver:
- KAN in main path
- adaptation
- masking
- SSM memory sidecar
- image runtime
- active overseer execution

### Phase 1.5 — Scaffolding and truthfulness
Deliver:
- capability handshake
- reasoning profiles
- execution policy ref
- plan trace
- protocol scaffolding for agent messages
- overseer role scaffolding
- local guardrail skeleton
- KAN pilot off main path

### Phase 2 — Compute steering
Deliver:
- Compute Steering Spec v1
- DIET / DIP experiments behind flags
- expert budget classes
- KV policy abstraction
- mask compiler skeleton
- dense fallback on invalid mask

Do not deliver:
- learned mask predictor yet
- adaptation on primary runtime
- swarm-like multi-agent behavior

### Phase 3 — Adaptation + oversight helpers
Deliver:
- Adaptation Subsystem Spec v1
- MLX helper-model LoRA adaptation
- anchor / rollback / canary
- local guardrail overseer prototype
- SSM memory sidecar prototype

### Phase 4 — Advanced research features
Only if previous phases are stable:
- IFPruning-like learned mask predictor
- stronger planner overseer
- richer agent hierarchy
- advanced expert budgeting
- main-model adaptive experiments behind strict flags

### Phase 5 — Product-level intelligence extensions
- persistent memory
- skill accumulation
- workspace/profile ontology separation
- OpenClaw-like executable workspace behavior
- Hermes-like memory systems
- multimodal sidecars
- remote planner escalation with local guardrail preserved

## 18. Persistent Memory and Skills

### Persistent memory
Add later:
- session-start memory hydrate
- session-end memory consolidation
- memory search
- memory snapshots
- semantic / episodic / procedural memory separation
- source-linked memory objects
- inspectable memory editing

### Skills
Add later:
- skill capture from successful workflows
- reusable recipes
- workflow registry
- task-conditioned skill retrieval

### Goal
Match or surpass Hermes by making memory:
- graph-native
- source-linked
- inspectable
- editable
- local-first
- integrated with notes, code, and project structure

## 19. Workspace / Profile Ontology

Add later:
- isolated workspaces
- separate knowledge ontologies by profile
- shared global layer + profile-local layer
- profile-specific graph namespaces
- action permissions by profile
- browser/system profile separation
- executable workspaces

This is your OpenClaw-inspired path, but knowledge-first rather than gateway-first.

## 20. Failure Modes and Guardrails

### 20.1 Unsupported capability drift
Fix:
- capability handshake
- explicit policy denial
- no fake success

### 20.2 Serial invariant violation
Fix:
- execution state machine
- serial audit traces
- no I/O overlap in streamed paths

### 20.3 Poisoned adaptation
Fix:
- allowlisted inputs
- helper-model-first
- anchor + canary + rollback
- no direct chat-to-weight path

### 20.4 Mask instability
Fix:
- structured masks only
- compile-or-block
- dense fallback
- mask telemetry

### 20.5 Agent chatter explosion
Fix:
- hierarchy
- recursion caps
- budget caps
- message audit trail

### 20.6 Visual interference
Fix:
- sidecar mode
- explicit lifecycle
- no always-on co-residency

### 20.7 MLX/GGUF drift
Fix:
- preserve split
- don’t let GGUF eat helper lanes
- don’t let MLX pretend to be primary reasoning everywhere

## 21. Codex Context Pack

Use this at the start of future sessions:

Epistemos is a local-first cognitive operating system.

Non-negotiable truths:
- Rust is the sole control-plane authority.
- `gguf`, `mlx`, and later `remote` are sibling runtimes.
- `gguf` owns primary local text generation.
- `mlx` is permanent and owns embeddings, helper models, adaptation, image generation, and Apple-native auxiliary workloads.
- No silent backend rerouting.
- No runtime self-escalates to cloud.
- No mid-generation backend switching.
- Public runtime contract stays pull-based.
- Serial GPU->SSD->GPU invariant must hold in streamed/fallback paths.
- Trust the OS page cache.
- No speculative expert prefetch during active decode.
- Base weights stay immutable.
- Adaptation is bounded, reversible, MLX-first, and helper-model-first.

Architecture:
- Interface layer
- Knowledge layer
- Control plane
- Execution plane
- Adaptation plane
- Oversight plane

Overseer:
- The overseer is a supervisory role, not a fixed model family.
- Split conceptually into:
  - planner overseer
  - guardrail overseer
  - SSM memory sidecar
- SSM/Mamba belongs primarily to memory compression, not default planner identity.

Agent hierarchy:
- overseer -> main agent -> sub-agents
- sub-agents report upward
- no unrestricted swarm communication
- all inter-agent communication must be structured, budgeted, and logged

Research placement:
- KAN = graph/routing/reranking helper, not chat backbone
- TTT/LoRA = bounded MLX adaptation lane, not default main runtime behavior
- MoE = selective specialization and expert budgeting
- SSM/Mamba = memory compression helper lane
- image generation = MLX sidecar mode

Required specs beyond Backend Interface Spec v1:
1. Capability Handshake Spec
2. Compute Steering Spec
3. Adaptation Subsystem Spec

Implementation rule:
- audit first
- preserve MLX
- keep GGUF primary for main reasoning
- use explicit telemetry and fail closed
- do not widen scope casually
