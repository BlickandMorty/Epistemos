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
- agent command center
- future image and voice panels

#### Agent Command Center
The interface layer should expose a dedicated Agent Command Center rather than hiding agentic delegation behind a blank landing canvas.

Purpose:
- make agent capabilities discoverable
- separate authoring mode from delegating mode
- provide a keyboard-first command surface for agent workflows
- move advanced agentic controls out of the general main-chat surface and into one dedicated, inspectable home

Interaction model:
- a dedicated Agent home in the Home / landing surface, reachable from a fourth top-toolbar icon and a global shortcut
- a global shortcut to summon the command surface instantly
- a dimmed, receding background with a centered glass command bar
- slash commands for modes, commands, skills, models, and tool presets
- at-mentions for explicit context attachment
- inline capability pills for MCP servers, tools, and runtime restrictions
- an inline brain / provider selector that stays native to Epistemos rather than feeling like a generic web chat
- a low-latency floating suggestion box that follows `/` and `@` input in real time
- a right-side inspector panel for plan/review/summary, active context, enabled tools/skills, selected brain, and live execution state
- the dedicated Agent home becomes the primary surface for advanced agent workflows that may already exist in main chat:
  - model / brain picker
  - plan mode
  - review / summarize / debug modes
  - slash-command invocation
  - skill selection
  - tool / MCP restriction toggles
  - execution inspection and review panels

Architectural requirements:
- a dedicated `AgentCommandCenterState` as an `@Observable` Swift state object
- keybind routing that can surface the command center without destroying current selection or editor context
- a reusable low-latency suggestion menu engine for `/` and `@`
- direct wiring from command-center capability toggles into the Rust control plane, MCP dispatcher, and tool registry
- a token-aware input parser that can segment free text, slash commands, at-mentions, inline capability toggles, selected model/provider state, and task scope into a normalized command draft
- a registry-backed suggestion source for:
  - modes such as ask / debug / plan / research / review
  - commands such as read-branch / summarize / review / explain
  - skills discovered from local skill registries
  - models / brains
  - MCP servers
  - local tools
  - explicit context providers
- a right-side panel state model that can render:
  - current mode / command intent
  - selected brain / provider
  - attached contexts
  - active skill, tool, and MCP restrictions
  - execution preview / plan summary
  - live run diagnostics or action stream when a task is executing
- a full binding pipeline from SwiftUI command state into Rust request compilation so the UI is not cosmetic:
  - slash / mention parsing happens in Swift
  - the normalized request is compiled into a control-plane request
  - Rust applies capability handshake, policy, MCP/tool restrictions, and routing truth
  - execution state flows back into the right-side inspector and output surface
- provider- and agent-aware output styling so different brains or local agents feel native and inspectable rather than like one generic chat stream
- use Cursor, Antigravity, and OpenCode as interaction references, but translate them into an Apple-native Epistemos surface rather than copying web-chat styling directly
- treat main chat as the lightweight conversational surface and the Agent home as the full agentic control surface, so the same controls are not duplicated across both places unless there is a deliberate minimal shortcut
- any graph-originated Agent Command Center request must carry real graph context into the normalized command request and Rust compile path:
  - graph node id
  - backing source id when present
  - node type
  - node label
  - current graph workspace route
  - the user's prompt
- Graph Chat receivers must be idempotent and lifecycle-safe; repeated bootstrap, presentation, or workspace navigation must not register duplicate observers, duplicate deliveries, or leaked notification tokens

The command center is a user-facing delegation surface, not a second control plane. Rust still owns routing, policy, permissions, and runtime truth.

#### Graph Workspace and Graph Chat
The graph workspace is a first-class working environment, not only a visualization.
It may open graph-native note pages, folder pages, inspectors, and graph-local
chat surfaces, but it must remain a projection over canonical app state rather
than becoming a second app.

Graph Chat rules:
- Graph Chat is a contextual intent surface for selected nodes, open pages,
  focused folders, or current subgraphs.
- Graph Chat must not create a competing chat architecture.
- Graph Chat requests must flow through the same Agent Command Center / Rust
  request-compilation truth as other agent requests unless an explicitly
  documented graph-only executor is added later.
- A graph-chat bridge that only prefills a composer is incomplete; it must also
  attach graph context to the submitted command.
- Unsupported node types should select or inspect rather than route to fake note
  pages or empty error destinations.

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

### Defer image generation for launch
Image generation is not launch-critical for the notetaking / cognitive-OS wedge.
The product-critical visual lane is vision understanding: screenshots, whiteboards,
PDF pages, charts, OCR, and source-grounded analysis.

MLX remains the future home for local image generation, but `image_generate`
must not block Phase 6 closure or the launch loop while no real Flux / MLX
Diffusion pipeline is wired.

### Update dependency preference
Do not anchor long-term planning on DiffusionKit because it is archived. Prefer active MLX-Swift paths such as `flux.swift` and similar maintained Apple-native stacks.

### Default execution mode
When image generation returns, it is:
- MLX sidecar first
- sequential by default
- not assumed to co-reside with main reasoning runtime
- hidden from normal user-visible catalogs until the local runtime lane actually works
- never silently rerouted to cloud

Cloud image generation, if kept, is an explicit opt-in provider path only. FAL or
other remote image providers may exist for manual/advanced use, but they do not
make the MLX lane "complete" and must not be used as silent fallback.

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
- dedicated Agent Command Center / agent home
- multimodal sidecars
- remote planner escalation with local guardrail preserved

Phase 5 is a product-intelligence phase, not a runtime-identity rewrite.

Rules:
- do not reopen the runtime split unless a concrete regression is found
- treat memory as explicit product state, not hidden model state
- treat skills as explicit artifacts, not prompt soup or silent weight drift
- treat workspace/profile separation as a permissions and namespace system, not only a UI grouping
- treat the Agent Command Center as the explicit delegation UX layer, not as a replacement for the control plane
- require the Agent Command Center to expose the full delegation stack visibly:
  - slash-command discovery
  - skill selection
  - context attachment
  - MCP/tool restrictions
  - brain/provider selection
  - right-side execution inspection
- migrate advanced agent affordances that already exist in main chat into the dedicated Agent home rather than maintaining two competing full-featured agent surfaces
- keep multimodal and remote extensions advisory, bounded, and inspectable

### Phase 6 — Communication and media closure
Deliver:
- `send_message`
- `vision_analyze`
- `text_to_speech`
- `imessage`
- `imessage_contacts`
- Swift channel registry / driver / settings integration
- explicit tool tiering and permission gates
- explicit failure for missing credentials, missing permissions, or unavailable runtimes
- no silent local-to-cloud escalation
- automated verification across Rust and Swift
- manual runtime verification with safe test destinations and OS permissions

Defer:
- local MLX image generation runtime
- user-visible `image_generate` catalog exposure

Phase 6 is closed only when communication, vision analysis, speech output,
iMessage routing, channel routing, automated tests, and manual runtime checks
are all truthful and verified. Image generation is not a Phase 6 closure gate
unless a real local MLX image pipeline is intentionally added.

### Phase 6.5 — Capture-to-memory launch wedge
After Phase 6 closure, prioritize the core Epistemos loop:

- voice or quick capture
- transcription
- structured note generation
- entity / task extraction
- graph write path
- source spans and evidence links
- trace / replay records
- optional follow-up actions through explicit tool gates

This wedge matters more than image generation because it makes Epistemos feel
like a local-first cognitive operating system rather than a generic AI workspace.

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

Persistent memory rules:
- memory objects must be explicit records, not opaque latent state
- every memory object must preserve provenance to notes, chats, files, or other source artifacts
- memory hydrate must be selective and policy-bounded, not a blind replay of all prior state
- memory consolidation must write structured, inspectable artifacts with timestamps and source links
- memory editing, correction, deletion, and rollback must be first-class operations
- no memory write may occur silently; important memory changes must be observable in telemetry or audit logs
- semantic, episodic, and procedural memory must remain distinguishable at the data-model level

### Skills
Add later:
- skill capture from successful workflows
- reusable recipes
- workflow registry
- task-conditioned skill retrieval

Skill rules:
- skills must be explicit registry objects, not hidden prompt fragments
- every skill must retain provenance to the workflow, examples, or evidence that created it
- skills should be versioned and auditable
- skill retrieval must be task-conditioned and policy-aware
- skill execution must respect workspace/profile permissions
- no skill may silently mutate memory, policies, or runtimes outside approved pathways

### Goal
Match or surpass Hermes by making memory:
- graph-native
- source-linked
- inspectable
- editable
- local-first
- integrated with notes, code, and project structure

The key product principle:
- Epistemos memory should behave like editable knowledge artifacts, not a hidden subconscious

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

Workspace/profile rules:
- workspace boundaries must enforce memory namespaces, not only presentation boundaries
- action permissions must be profile-scoped and inspectable
- shared global memory must be explicit and intentionally bridged into profile-local views
- profile-local memory must not leak silently across workspaces
- executable workspaces must declare their allowed tools, sidecars, and escalation permissions
- browser, system, code, and knowledge contexts should be separable so the user can reason about what each profile can see and do

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
- `mlx` is permanent and owns embeddings, helper models, adaptation, future local image generation, and Apple-native auxiliary workloads.
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
- image generation = deferred MLX sidecar mode, hidden until real local runtime support exists

Phase 5 product constraints:
- persistent memory must be source-linked, editable, and reversible
- skills must be explicit artifacts with provenance and versioning
- workspace/profile ontology must enforce namespaces and permissions
- multimodal and remote extensions must remain explicit, bounded, and observable

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

## 22. BoltFFI Hot-Path Migration Audit

### 22.1 Intent
Epistemos should move toward a BoltFFI-first native data plane wherever it
creates real user-visible performance, latency, memory, or smoothness wins.

This is not a mandate to rewrite every bridge for ideology. It is a mandate to
audit every Swift/Rust boundary, measure cost, and migrate the surfaces where
UniFFI, JSON-over-FFI, C FFI shims, or missing FFI boundaries are constraining
the product.

Preferred long-term direction:
- BoltFFI for hot data planes
- UniFFI only for cold control-plane calls where ergonomics matter more than throughput
- XPC or process boundaries where isolation matters more than raw transfer speed
- shared memory or chunked payload references for very large local payloads
- no duplicate Swift control plane introduced during migration

### 22.2 Non-negotiable rules
- Rust remains the control-plane authority.
- BoltFFI must not create a second routing, permission, or runtime decision layer in Swift.
- No migration may remove explicit permission gates, telemetry, cancellation, or fail-closed behavior.
- No hot-path optimization may hide unsupported capability, silently reroute backend, or widen cloud escalation.
- Every migrated surface needs before/after benchmarks and parity tests.
- Keep UniFFI where the call is low-frequency and type ergonomics are more valuable than raw throughput.
- Prefer stable ABI structs, typed handles, borrowed buffers, and preallocated output buffers over JSON strings on hot paths.
- Never pass large graph, code-editor syntax, transcript, screenshot, or agent-event payloads as repeatedly serialized JSON if a typed buffer or shared-memory path is feasible.
- Embedding and vector payloads are not part of the first BoltFFI migration wave; keep them on the existing retrieval path unless a later benchmark shows a concrete user-visible bottleneck.

### 22.3 Required audit scope
Run a dedicated FFI audit across:

- existing UniFFI exports in `agent_core`, `epistemos-core`, `omega-mcp`, and `omega-ax`
- current C FFI graph-engine bridge surfaces
- JSON-over-FFI calls such as command-center compile, tool execution results, session graphs, topology, and memory payloads
- Swift-only hot paths that could benefit from moving computation or transfer into Rust
- local Swift/Rust streaming paths for agents, tool calls, trace events, MCP payloads, graph updates, and capture pipelines
- no-FFI surfaces where Swift is doing high-volume transformation that Rust could own more efficiently

The audit output must classify every boundary as:
- `keep_uniffi`
- `boltffi_candidate`
- `boltffi_priority`
- `shared_memory_candidate`
- `xpc_or_process_boundary`
- `defer_no_measured_gain`

### 22.4 Highest-priority BoltFFI candidates

#### Graph and visual data plane
Graph is the first serious candidate because the user can feel latency, jitter,
and allocation churn directly.

Audit and likely migrate:
- node and edge batch transfer
- graph position snapshots
- physics update buffers
- hover, selection, and neighborhood result batches
- graph search result batches
- SDF label instance payloads
- page-subgraph and global-graph delta application
- renderer-facing structs where copy count affects frame time

Goal:
- fewer bridge allocations
- fewer JSON/string payloads
- stable typed buffers for node IDs, positions, colors, sizes, edge endpoints, labels, and search hits
- no per-frame allocations caused by bridge marshalling

#### Agent and tool-event data plane
The agent system should keep Rust as authority, but high-volume event transfer
should be audited for BoltFFI.

Audit and likely migrate:
- agent stream events
- token deltas and thinking deltas
- tool-call start/input/output events
- trace/replay event batches
- command-center diagnostics snapshots
- tool catalog and permission catalog payloads
- session lineage and session-browser summaries

Keep or defer:
- command-center compile can remain cold-path UniFFI or JSON-over-FFI until profiling proves it matters
- provider route preview can remain UniFFI unless it becomes high-frequency UI traffic
- destructive tool approval requests must preserve explicit audit semantics even if the transport changes

#### Capture, transcript, and evidence data plane
Phase 6.5 and later capture work should avoid building a beautiful note pipeline
on a slow bridge.

Audit and likely migrate:
- transcript segments
- source spans
- extracted task/entity batches
- evidence span payloads
- trace/replay capture events
- audio/STT result structs when they cross Swift/Rust frequently

Goal:
- voice -> note -> graph -> evidence should feel instant and native
- source spans and evidence chips should move as typed records, not ad hoc JSON blobs

#### Code editor and syntax data plane
The code editor is a first-class BoltFFI candidate only where a measured hot
path exists. The target is not a speculative full editor rewrite; it is a
native editor with a Rust-owned parsing/highlighting data plane where that
creates visible smoothness.

Audit and likely migrate after benchmarking:
- Rust tree-sitter / syntax token delta payloads
- dirty-range parse requests
- viewport-sized semantic token batches
- fold ranges
- diagnostic ranges
- diff and inline-review range payloads

Keep Swift / TextKit 2 or the current native editor layer responsible for:
- text input
- IME composition
- selection
- undo / redo
- accessibility
- native scrolling and editing behavior

Use Metal only where it clearly helps:
- minimap
- gutters
- diagnostics heatmaps
- diff overlays
- syntax/background decoration layers

Do not attempt full Metal text rendering unless benchmarks prove the native
TextKit / CodeEdit path cannot meet interaction targets.

#### Retrieval and memory payloads
Retrieval and memory are important product systems, but embedding vectors and
vector batches are intentionally removed from the first BoltFFI migration wave.

Default:
- keep embeddings and vector retrieval on the existing storage/retrieval path
- do not prioritize BoltFFI for sqlite-vec, embedding vectors, vector batches, or cold retrieval queries
- revisit only after graph memory v2 produces measured bridge overhead that is visible to users

Still audit for future strategy:
- graph memory and PPR result payloads
- source-linked memory record summaries
- contradiction and provenance result batches

Use shared memory or chunked references, not automatic BoltFFI migration, when
future retrieval payloads become too large for ordinary typed transfer.

#### MCP and external tool payloads
MCP transports remain MCP transports. BoltFFI should optimize local Swift/Rust
handoff around MCP, not replace the MCP protocol.

Audit and likely migrate:
- local MCP result objects
- large resource payload metadata
- screenshot and file-result references
- chunked MCP framing handoff
- tool schema batch transfer when the catalog grows

### 22.5 Measurement protocol
Before any migration, record:
- payload size
- call frequency
- allocation count
- Swift main-thread time
- Rust marshalling time
- end-to-end latency
- peak memory and copy count where measurable
- user-visible symptom, if any: frame hitch, delayed token, slow graph load, sluggish inspector, slow capture import

After migration, require:
- parity tests
- bridge safety tests
- benchmark delta
- memory/copy delta where measurable
- failure-path tests
- manual UI feel check for graph, agent streaming, or capture surfaces when relevant

Do not migrate a surface if:
- it is cold-path configuration
- it runs only on app startup
- it is not measurable
- it would complicate permission/audit semantics
- it would duplicate Rust authority in Swift

### 22.6 Suggested execution order

1. Inventory every Swift/Rust boundary.
2. Build a table of UniFFI, C FFI, JSON-over-FFI, shared-memory, XPC, and Swift-only hot paths.
3. Add microbenchmarks for graph snapshots, agent events, transcript spans, and code-editor syntax/highlighting payloads.
4. Pick one vertical slice first: graph data-plane transfer.
5. Build BoltFFI bindings for the selected slice only.
6. Keep the existing bridge behind a compatibility switch until parity and benchmarks pass.
7. Repeat for agent event streaming and code-editor syntax payloads.
8. Retire UniFFI surfaces only after the BoltFFI path is proven and the old path has no remaining callers.

### 22.7 Exit criteria
The BoltFFI migration program is complete only when:
- every FFI boundary has an explicit keep/migrate/defer decision
- graph hot-path transfer has been benchmarked and either migrated or explicitly justified
- agent event streaming has been benchmarked and either migrated or explicitly justified
- code-editor syntax/highlighting payloads have been benchmarked before any Rust/BoltFFI editor rewrite
- capture/transcript/evidence payloads have been benchmarked only if they become a measured hot path
- embedding/vector payloads remain deferred unless later benchmarks prove the existing retrieval path is user-visible bottleneck
- UniFFI remains only where it is intentionally cold-path or ergonomically superior
- no migration weakens Rust sovereignty, permission gates, audit logs, or local-first routing rules
