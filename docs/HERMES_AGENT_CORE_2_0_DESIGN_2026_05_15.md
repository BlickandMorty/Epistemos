# Hermes Agent Core 2.0 — Native Agent Architecture
**Date:** 2026-05-15
**Status:** v0.1 design (canonical target — sequenced after V1 MAS submission per Master Fusion plan)
**Authority:** Doctrine doc. Lives at rank 4 of the authority chain, just below `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md`. Replaces the scattered agent design notes across `IMPLEMENTATION_PLAN_FROM_ADVICE.md`, `project_helios_v5_substrate_landed.md`, and the `agent_runtime/` ad-hoc seams.

> The architecture sentence:
> *Epistemos agents are Hermes-governed native agents whose executor can be local, cloud, MCP, or Pro CLI, but whose memory, permissions, schemas, artifacts, and audit trail always belong to Epistemos.*

---

## Immutable rules (precede §0)

These rules outrank every other section in this doc. If any later section conflicts, this block wins.

### IR-1. Hermes runs in-process in MAS V1; XPC service is a Pro V1.x evaluation, not a MAS option

**Decision (2026-05-16, B2-5 resolution):**

- **MAS V1.** Hermes runs **in-process** via Rust FFI + UniFFI inside `agent_core::agent_runtime`. This is the canonical implementation and is non-negotiable for MAS submission. Per `CLAUDE.md` NON-NEGOTIABLE CONSTRAINTS: *"NO SIDECAR. All inference AND orchestration in-process via Rust FFI or MLX-Swift. ONLY exception: oMLX bridge for oversized models."*
- **Pro V1.x.** An **embedded XPC service** is a candidate architecture under evaluation — **not** an open question that gates V1 work. Per `docs/fusion/jordan's research/hermes.md` §"The correct macOS boundary for Hermes", an embedded XPC service (private to the containing app, launched on demand by launchd, restartable after crashes, with its own sandbox + restrictive default environment) is the correct macOS primitive **IF** Pro needs to isolate Hermes from the main app process. Evaluation only begins after Pro V1.0 ships and only if a concrete need motivates the migration (crash isolation · sandbox-restricted credential pool · separate restart cadence · App-Group-bridged cloud session that must outlive the host process).
- **What this rules out.** Subprocess Hermes (child binary spawned via `Command::new`) is forbidden in **both** MAS and Pro. The XPC service is the ONLY sanctioned out-of-process alternative if Pro ever moves Hermes off the main process. Any XPC service code MUST be gated by `#[cfg(feature = "pro-build")]` in `mas-build` Cargo features so the MAS bundle stays in-process-only and the `strings` + `nm -gU` symbol-leak audits keep returning zero matches.
- **Rationale.** CLAUDE.md NO SIDECAR is a hard constraint driven by App Store sandboxing, App Review reviewer comprehensibility, and the user's "as complex as a brain, as simple as an app, as fast as a jet" thesis. The XPC service framing from `hermes.md` is valuable research for the Pro tier but does NOT override CLAUDE.md for MAS V1.
- **Reversibility.** Reversible **for the Pro tier only** via a new ADR plus scoped user approval. MAS V1 in-process is permanent for the `mas-build` Cargo feature — flipping it requires a CLAUDE.md edit (which is itself user-approval-gated) and a fresh App Review submission.
- **Cross-references.** §6 (MAS vs Pro split — this rule sharpens that table's `subprocess` rows); `MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §D XPC Mastery (Pro-only `VaultXPC` + `CapabilityGrant` XPC services — distinct from the Hermes-as-XPC question this rule answers); `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md`.
- **Source.** `RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md` B2-5; resolved 2026-05-16.

---

## 0. The single hardest problem this design solves

The user's complaint: *"the agent feels demo-like. With the local Qwen model the agent listed only the first 7 vault notes which were not relevant."*

That bug has TWO root causes — and the architecture in this doc fixes both:

1. **Tool-choice drift** (small local models pick the wrong tool name). Fixed today via `list_notes → vault.search` auto-route on `query` param (commit `41be78202`). The design here generalizes that into the **Variant Ladder** (§7) so every tool route auto-promotes from cheap-deterministic to LLM-bound when needed.

2. **Identity drift** (the agent feels owned by whichever model is serving the turn). Fixed by making **agent identity belong to Epistemos**: the user creates an `AgentBlueprint` once, picks a provider, and the same memory/tools/permissions/audit trail apply whether the brain is Local MLX, Anthropic, OpenAI Responses, or a Pro-only Claude Code CLI.

---

## 1. North star — agent identity belongs to Epistemos, not the provider

User-facing model:

```
"Research Assistant"
  Provider:    Claude Sonnet 4.5  (or: Local Qwen 3.6, OpenAI o3, …)
  Memory:      Current vault + selected notes
  Tools:       note.search, note.read, note.create, graph.search, web.search
  Permissions: ask before writing
  Output:      AnswerPacket + citations + RunEventLog
```

**Provider is replaceable.** Memory, tools, permissions, schema contracts, artifacts, and audit trail are NOT.

This is the inverse of how Claude Code / Codex / Goose / OpenHands package agents — they assume their CLI is the agent. We package the agent and treat their CLI as one possible executor adapter.

---

## 2. The 5-layer architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Swift Agent UI                                                 │
│    • Create Agent sheet (Simple mode + Expert mode)             │
│    • RunEventLog timeline                                       │
│    • Approval cards (SCOPE-Rex native approval UI)              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  AgentBlueprint (Rust + Swift typed twins)                      │
│    • id, display_name, system_prompt, persona                   │
│    • provider_policy, model_policy, runtime_tier                │
│    • tool_policy, memory_scope, output_contract                 │
│    • budget, permission, checkpoint                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Hermes Agent Core (agent_core/src/agent_runtime/)              │
│    • MissionPacket → Stream<AgentEvent> → AnswerPacket          │
│    • ContextCondenser (6-layer compaction)                      │
│    • ProviderRouter (privacy-class-aware fallback)              │
│    • VariantLadder dispatch (every tool route)                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Executor Registry — every executor implements one trait        │
│    ├── LocalMLXExecutor          (MAS-allowed)                  │
│    ├── AnthropicMessagesExecutor (MAS-allowed)                  │
│    ├── OpenAIResponsesExecutor   (MAS-allowed)                  │
│    ├── OpenAICompatibleExecutor  (MAS-allowed; Ollama/LM Studio)│
│    ├── MCPExecutor               (MAS-allowed if user-approved) │
│    └── ProCLIExecutor            (Pro-only)                     │
│        ├── ClaudeCodeAdapter                                    │
│        ├── CodexCLIAdapter                                      │
│        ├── GooseAdapter                                         │
│        ├── AiderAdapter                                         │
│        └── OpenHandsAdapter                                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  SCOPE-Rex Governance (every executor wrapped, never raw)       │
│    • SovereignGate.validate_mission(&mission)                   │
│    • SovereignGate.validate_event(&event)                       │
│    • RunEventLog.record(&event) (typed, append-only)            │
│    • TypedArtifact / MutationEnvelope / ClaimLedger             │
└─────────────────────────────────────────────────────────────────┘
```

The invariant the entire system pivots on:

```
MissionPacket  →  Stream<AgentEvent>  →  AnswerPacket + Artifacts
```

Every provider — local Qwen, Claude API, Codex CLI — has to produce events that shape.

---

## 3. AgentBlueprint — the typed agent identity

`agent_core/src/agent_runtime/blueprint.rs` (new, replaces ad-hoc seams):

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentBlueprint {
    pub id: AgentId,
    pub display_name: String,
    pub description: String,
    pub persona: Option<String>,                  // optional persona prompt
    pub system_prompt_template: SystemPromptSpec, // template + variable bindings
    pub provider_policy: ProviderPolicy,
    pub model_policy: ModelPolicy,
    pub memory_scope: MemoryScope,
    pub tool_policy: ToolPolicy,
    pub permission_policy: PermissionPolicy,
    pub output_contract: OutputContract,
    pub budget: BudgetPolicy,
    pub runtime_tier: RuntimeTier,
    pub checkpoint_policy: CheckpointPolicy,
    pub schema_rev: SchemaRev,                    // hash for migrations
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RuntimeTier {
    MasNative,    // App Store sandbox; HTTPS + local MLX + native tools only
    ProCli,       // Pro direct-distribution; CLI subprocess adapters allowed
    Research,     // Pro + research-tier features (Lean, falsifier, etc.)
    Omega,        // Pro + research + experimental simulation paths
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ProviderPolicy {
    LocalMLX { model_id: String, profile: LocalMLXRunProfile },
    AnthropicMessages { model: String },
    OpenAIResponses { model: String },
    OpenAICompatible { base_url: String, model: String, api_key_keychain_account: Option<String> },
    MCP { server_id: String },
    ProCLI { adapter: CliAdapterKind, command: PathBuf, env_policy: EnvPolicy },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CliAdapterKind {
    ClaudeCode,    // `claude` binary
    Codex,         // `codex` binary
    Goose,         // `goose` binary
    Aider,         // `aider` binary
    OpenHands,     // OpenHands local server adapter
    SweAgent,      // mini-swe-agent runner
}
```

This is the **single source of truth** for what an agent IS. Created once by the user, persisted in `vault/agents/<id>.json` (or `<id>.epbundle` if you want full provenance), loaded by the runtime when the user runs a mission.

---

## 4. The Executor trait — the spine that makes providers interchangeable

```rust
use async_trait::async_trait;
use futures_core::Stream;
use std::pin::Pin;

pub type AgentEventStream =
    Pin<Box<dyn Stream<Item = Result<AgentEvent, AgentError>> + Send>>;

#[async_trait]
pub trait AgentExecutor: Send + Sync {
    fn id(&self) -> ExecutorId;
    fn capabilities(&self) -> ExecutorCapabilities;
    async fn execute(
        &self,
        packet: MissionPacket,
        ctx: ExecutionContext,
    ) -> Result<AgentEventStream, AgentError>;
}
```

`MissionPacket` and `AgentEvent` are the load-bearing structs — every provider serializes its native protocol into these types before crossing back into Epistemos.

### 4.1 The five canonical AgentEvent variants

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AgentEvent {
    SessionStarted(SessionStarted),
    ModelStarted(ModelStarted),
    ModelDelta(ModelDelta),
    ToolProposed(ToolCallEnvelope),
    ApprovalRequested(ApprovalRequest),
    ApprovalResolved(ApprovalDecision),
    ToolStarted(ToolStarted),
    ToolOutput(ToolOutput),
    ArtifactProposed(TypedArtifact),
    MutationProposed(MutationEnvelope),
    MutationCommitted(MutationEnvelope),
    CheckpointSaved(Checkpoint),
    SessionCompacted(ContextCompaction),
    SessionCompleted(AnswerPacket),
    SessionFailed(AgentFailure),
}
```

The UI renders this as a timeline, not raw logs. The user SEES what the agent is doing.

---

## 5. SCOPE-Rex governance wrapper — every executor wrapped, never raw

This is the single most important invariant:

```rust
pub struct GovernedExecutor<E> {
    inner: E,
    policy: Arc<SovereignGate>,
    log: Arc<RunEventLog>,
}

#[async_trait]
impl<E: AgentExecutor> AgentExecutor for GovernedExecutor<E> {
    async fn execute(&self, packet: MissionPacket, ctx: ExecutionContext)
        -> Result<AgentEventStream, AgentError>
    {
        self.policy.validate_mission(&packet, &ctx).await?;
        self.log.record(AgentEvent::SessionStarted(/* … */)).await?;

        let stream = self.inner.execute(packet, ctx).await?;
        Ok(Box::pin(stream.then({
            let policy = self.policy.clone();
            let log = self.log.clone();
            move |event| {
                let policy = policy.clone();
                let log = log.clone();
                async move {
                    let event = event?;
                    policy.validate_event(&event).await?;
                    log.record(event.clone()).await?;
                    Ok(event)
                }
            }
        })))
    }
}
```

**No executor emits an event the policy layer did not inspect.** This is what makes Hermes 2.0 fundamentally different from Goose / OpenHands / Claude Agent SDK — in those systems the agent is the policy. Here Epistemos is the policy.

---

## 6. MAS vs Pro split — the clearest line in the design

Per `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` + Apple App Review Guideline 2.5.2:

| Capability | MAS | Pro | Why |
|---|---|---|---|
| Anthropic Messages API | ✅ | ✅ | HTTPS only |
| OpenAI Responses API | ✅ | ✅ | HTTPS only |
| OpenAI-compatible localhost (Ollama, LM Studio) | ✅ | ✅ | localhost HTTPS; user controls server |
| Local MLX in-process | ✅ | ✅ | no subprocess; in-app inference |
| MCP client (user-approved) | ✅ | ✅ | gated by SovereignGate consent |
| Native Epistemos tools (note.*, graph.*, …) | ✅ | ✅ | in-app, schema-bound |
| Claude Code CLI subprocess | ❌ | ✅ | spawns `claude` binary |
| Codex CLI subprocess | ❌ | ✅ | spawns `codex` binary |
| Goose CLI subprocess | ❌ | ✅ | spawns `goose` binary |
| Aider subprocess | ❌ | ✅ | spawns `aider` binary |
| OpenHands local server | ❌ | ✅ | spawns Python server |
| SWE-agent / mini-SWE | ❌ | ✅ | subprocess + Docker risk |
| Arbitrary shell tool | ❌ | ✅ | bash_execute Pro-only |
| Browser automation | ❌ | ✅ | computer-use Pro-only |
| iMessage outbound channel | ❌ | ✅ | osascript Pro-only |
| Web search (HTTP) | ✅ | ✅ | HTTPS; cited in approval card |
| File system writes outside vault | ❌ | ✅ | sandbox forbids on MAS |

CI gate stays: `strings` + `nm -gU` on the MAS bundle must return zero matches for the Pro-only allowlist (`bash_execute`, `cli_passthrough`, `osascript`, etc.).

---

## 7. The native Epistemos tool surface — 12 MAS + 10 Pro

### 7.1 MAS-allowed (the spine)

| Tool | Purpose | VariantLadder tiers |
|---|---|---|
| `vault.search` | Relevance-ranked note search (BM25 + embeddings + RRF) | T1 Tantivy → T2 embedding → T3 RRF fused |
| `vault.read` | Read a vault-relative path | T1 only |
| `vault.list` | Browse paths under a folder (auto-routes to vault.search on `query`; **shipped 41be78202**) | T1 + auto-route to T1/T2/T3 of vault.search |
| `note.create` | Create a new note (with frontmatter, tags) | T1 + contradiction-detection pre-flight |
| `note.edit` | Edit an existing note (typed diff) | T1 + readback verify |
| `graph.search` | Find graph nodes by query | T1 + T2 |
| `graph.neighbors` | List neighbors of a graph node | T1 only |
| `research.collect_snippet` | Save a snippet to vault with citation | T1 |
| `citation.save` | Persist a citation record | T1 |
| `research.search_papers` | Search Semantic Scholar / arXiv | T1 HTTP only |
| `web.search` | HTTPS web search (user-approval card) | T1 HTTP only |
| `ask_user` | Surface a clarify card (uses `epistemos.clarify.v1` GenUI schema) | T1 only |
| `note.attach_readonly` | **V1 stub** — attach a note to chat for citation/context, READ-ONLY (no edit, no mutation) | T1 only |
| `edit_note_block` *(V1.1 deferred)* | **V1.1 hero tool** — capability-gated agent edit of a single note block via single-use macaroon. Tool signature `edit_note_block(page_id, block_id, new_markdown, capability_token)`. Macaroon primitives live at `agent_core/src/cognitive_dag/macaroons.rs` + `dispatch.rs`; pending V1.1 work is the tool layer + single-use semantic on top of `Macaroon` + ledger row per edit + Undo button in chat transcript. Design doc: `docs/audits/LOCAL_ENGINEERING_AGENT_DESIGN_2026_05_10.md` (status AWAITING_USER_SIGNOFF). V1 vs V1.1 decision row at `MAS_COMPLETE_FUSION §10` (H-3 / B2-H6). | T1 + macaroon pre-flight |

### 7.2 Pro-additional

| Tool | Purpose |
|---|---|
| `repo.map` | Aider-style repo map (RepoContextGraph) |
| `repo.read_file_window` | SWE-agent custom file viewer |
| `repo.search` | tree-sitter symbol search |
| `repo.apply_patch` | Apply unified diff (with rollback checkpoint) |
| `repo.run_tests` | Run targeted test (sandboxed; explicit approval) |
| `repo.git_diff` | Show unstaged diff |
| `repo.git_commit` | Commit staged changes |
| `shell.run_approved` | bash_execute (per-command approval) |
| `cli.delegate` | Hand off to Claude Code / Codex / Goose / Aider |
| `mcp.call` | Invoke a user-installed MCP tool |

### 7.3 Per-tool typed metadata

Every tool MUST declare:

```rust
pub struct ToolDefinition {
    pub name: String,
    pub description: String,
    pub input_schema: serde_json::Value,
    pub output_schema: serde_json::Value,
    pub capability: Capability,
    pub mutation_kind: MutationKind,
    pub approval: ApprovalMode,
    pub availability: ToolAvailability,
    pub variant_ladder: VariantLadderSpec,   // tier configuration
    pub weight_class: CognitiveWeight,       // W1 metadata for ranking
}
```

`ToolAvailability::Mas | Pro | Research | Omega` already exists conceptually in `ToolSurfacePolicy.coreAppStoreAllowedToolNames` — the new design just makes it a typed field on every tool.

### 7.4 Specialties registry — the 19 macOS-only capabilities

Specialties are the doctrinal answer to *"why not a web wrapper?"* — capabilities that only exist because Epistemos co-locates in-process Rust, MLX-Swift, AXorcist, ScreenCaptureKit, GRDB, and Metal compute shaders inside a single hardened-runtime macOS app. A web app cannot reproduce any of these without subprocess spawning, OS-level entitlements, or third-party server hops that all break the local-first thesis.

Source: `docs/_consolidated/20_canonical_research/EPISTEMOS_SPECIALTIES.md` §A-D (A1-A3 perception · B1-B6 knowledge · C1-C4 inference · D1-D6 intelligence = 19 total).

| ID  | Specialty | Category | In-process dependency that makes it MAS-feasible / web-impossible | Tier |
|-----|-----------|----------|-------------------------------------------------------------------|------|
| A1  | `perceive`              | Perception   | AXorcist + Vision + VLM in-process; web cannot read other apps' AX trees | Pro |
| A2  | `interact`              | Perception   | AXorcist + CGEvent native; web cannot drive other apps' UI | Pro |
| A3  | `screen_watch`          | Perception   | ScreenCaptureKit + FSEvents; web has no equivalent | Pro |
| B1  | `vault_recall`          | Knowledge    | GRDB + Tantivy + usearch in-process; sub-3ms semantic search | MAS + Pro |
| B2  | `graph_query`           | Knowledge    | Rust graph engine + Metal SDF in-process | MAS + Pro |
| B3  | `contradiction_check`   | Knowledge    | ClaimLedger + Cognitive DAG in-process | MAS + Pro |
| B4  | `vault_navigate`        | Knowledge    | Hyperbolic topology kernel in `epistemos-shadow` | MAS + Pro |
| B5  | `neural_recall`         | Knowledge    | 4-tier memory (NeuralCache · ProjectionCache · etc.) in-process | MAS + Pro |
| B6  | `knowledge_distill`     | Knowledge    | MLX-Swift in-process synthesis per model | MAS + Pro |
| C1  | `ssm_resume`            | Inference    | Mamba SSM state on disk + MLX; survives across sessions | MAS + Pro |
| C2  | `constrained_generate`  | Inference    | MLX + grammar via `LocalToolGrammar.swift` | MAS + Pro |
| C3  | `route_private`         | Inference    | `ConfidenceRouter.swift` in-process; cloud as fallback only | MAS + Pro |
| C4  | `metal_benchmark`       | Inference    | Metal compute shaders + `MTLBinaryArchive` live profiling | MAS + Pro |
| D1  | `nightbrain_trigger`    | Intelligence | NightBrain idle scheduler in `agent_core/src/nightbrain/` | MAS + Pro |
| D2  | `inline_partner`        | Intelligence | Graph-weighted ghost text via `@Observable` editor coordinator | MAS + Pro |
| D3  | `self_evolve`           | Intelligence | GEPA mutation pipeline in `agent_core::evolution` | MAS + Pro |
| D4  | `mixture_of_minds`      | Intelligence | Cloud ensemble via HTTPS (Anthropic + OpenAI Responses) | MAS + Pro |
| D5  | `live_note`             | Intelligence | `DispatchSourceTimer` + in-process exec (MAS); shell exec is Pro-only | MAS (in-process) + Pro (shell) |
| D6  | `dataview`              | Intelligence | Obsidian-compat structured query engine in Swift | MAS + Pro |

**App Review reviewer answer (cite this verbatim if asked "why not a web wrapper?"):** Three perception capabilities (A1-A3) literally cannot exist in a web app — there is no browser API for cross-application AX tree reads, system-wide CGEvent injection, or system-wide screen capture. Thirteen more (B1-B6, C1-C4, D1-D3) require in-process MLX-Swift, GRDB, Tantivy/usearch, or Metal compute shaders that the browser sandbox cannot reach without subprocess hops that would void the MAS hardened-runtime guarantees. The remaining three (D4 cloud, D5 cron, D6 query) lose 30-100ms latency per call when routed through HTTP/IPC instead of staying in-process. **The 19 specialties are the moat; the web wrapper would be a slower, weaker subset of D4 + D6.**

**Tool-surface mapping (follow-up integration slice, not part of B2-1):** The §7.1 / §7.2 tool tables expose a *subset* of these specialties as named LLM-callable tools (e.g. B1 `vault_recall` → `vault.search`; B2 `graph_query` → `graph.search` / `graph.neighbors`). Specialties without a current tool-surface row (e.g. B3 `contradiction_check`, C4 `metal_benchmark`, D5 `live_note`) are exposed via Swift APIs and in-app UI, not via the agent's tool registry — yet. Future slices may promote any specialty to a tool row when the agent loop needs to invoke it directly.

**UI marking for premium moves (follow-up design slice, not part of B2-1):** Visual badge / accent (likely a small gradient ring + tooltip) marking UI affordances that invoke a specialty, so users can scan a surface and see *which buttons are doing something only Epistemos can do*. Lives in `Theme/PhysicsModifiers.swift` as a new `.specialty(let id: SpecialtyID)` modifier; routed through `CognitiveWeightBadge` already in main. Tracked separately from B2-1 — this slice ships the registry, not the marking.

---

## 8. Local model strategy — fusing models into a unified Epistemos brain

### 8.1 Hardware reality (M2 Pro 16GB — `V6_2_HARDWARE_LOCK`)

Realistic budget:
- Total unified memory: 16 GB
- OS + Swift app: ~4 GB
- KV cache @ 32k context: ~1.5 GB (with KIVI 2-bit quantization scaffolded at W9.30)
- Model + working tensors: ~9-10.5 GB usable

So a 4-bit 7B-12B is the sweet spot. A 4-bit MoE 30B-35B-A3B (3B active) lands at ~9 GB on disk + ~3 GB active KV — fits, with care.

### 8.2 The "Epistemos local brain" — a routed fusion, not a single model

Don't commit to one model. **Route by task**:

| Task class | Model | Why | RAM |
|---|---|---|---|
| Default chat (`canActAsAgent: false` for tool calls; great for direct stream) | **Gemma 4 4B-it 4-bit** | strong long-context (1M tokens for gemma 3 27B family); excellent base for natural assistant turn | ~2.5 GB |
| Long-context document analysis | **Gemma 3 27B-QAT 4-bit** | 1M token context; QAT recovers quant loss; best-in-class for "read this whole 200-page doc" | ~12 GB (hot path; expect swap) |
| Agentic tool calling (Hermes `<tool_call>` grammar) | **Qwen 3.6 35B-A3B Unsloth 4-bit** | MoE 3B-active → fast; Unsloth quant preserves the Hermes-style tool-call grammar that MLXStructured enforces | ~9 GB |
| Coding agent | **Qwen3-Coder 30B-A3B Instruct 4-bit** | trained on code + tool-use; same `<tool_call>` grammar; MoE so fast | ~9 GB |
| Reasoning / planning | **DeepSeek-R1-Distill-Qwen-7B 4-bit** | distilled R1 reasoning into a 7B body; great for the planner role | ~4 GB |
| Speed-critical short turn | **LFM2 2.6B 4-bit** | SSM hybrid; ultra-fast | ~1.5 GB |
| Hybrid SSM long-context | **Falcon-H1R 7B 4-bit** | hybrid Mamba-attention; fast on long context | ~4 GB |
| Voice / quick capture | **Jamba Reasoning 3B BF16** | tiny + reasoning-trained; perfect for ambient capture summarization | ~6 GB BF16 |

**Routing policy** (`agent_core/src/agent_runtime/local_router.rs` — new):

```rust
pub fn select_local_model(packet: &MissionPacket, available_ram_gb: f32) -> LocalTextModelID {
    use MissionIntent::*;

    match (packet.intent(), available_ram_gb) {
        (AgenticToolCalling, ram) if ram >= 9.0 => Qwen36_35BA3B_Unsloth4Bit,
        (CodingAgent, ram)        if ram >= 9.0 => Qwen3Coder30BA3B4Bit,
        (LongDocumentAnalysis, ram) if ram >= 12.0 => Gemma3_27BQAT4Bit,
        (Planning, _)             => DeepseekR1Distill7B,
        (DirectChat, _)           => Gemma4_4B4Bit,
        (QuickCapture, _)         => Lfm2_2B4Bit,
        // … fallback to gemma4_4b as the universal default
        _ => Gemma4_4B4Bit,
    }
}
```

### 8.3 Why NOT a single fused MoE?

Tempting answer: train one custom MoE that combines Gemma's long-context with Qwen's tool-calling. Reality on M2 Pro 16GB:

- A 4-bit 16-expert MoE @ 4B-A1B would land ~5-6 GB resident
- Training requires GPU rental or Mac Studio M2 Ultra; not feasible on the user's laptop
- The expert-selection routing introduces latency penalty when the "wrong" expert is chosen
- Goodfire VPD distillation (V6.1 5-plane research) is a *future* path, but it's labelled `canonical_target_not_implemented_here` in the V6.1 reality matrix — don't bet V1 on it

**Routed fusion** (select the right OFF-THE-SHELF model per task) beats trying to train one custom model that does everything mediocre, given the user's hardware constraint.

The "Epistemos brain" identity comes from the **MissionPacket + SCOPE-Rex governance + RunEventLog**, not from the underlying weights.

---

## 9. Schema-first contracts — wired into `epistemos.*.v1` schemas (B.5)

The `epistemos.{soul,skill,episode,semantic}.v1.schema.json` files shipped today (commit `9b7629752`) are exactly the typed contracts Hermes 2.0 needs:

| Schema | Role in Hermes 2.0 |
|---|---|
| `epistemos.soul.v1` | One per user-model pairing. Holds preferences, agent persona, identity layer. Loaded into every AgentBlueprint at runtime. |
| `epistemos.skill.v1` | Voyager-style skill library entries. Loaded into `tool_policy.skills`. Skills marketplace surfaces them. |
| `epistemos.episode.v1` | Every RunEventLog entry that crosses the "remembered" threshold gets persisted as an episode. |
| `epistemos.semantic.v1` | ClaimLedger entries — atemporal facts. Hermes 2.0 emits these via `MutationProposed → ClaimLedger::record()`. |

So `MutationEnvelope` already validates payloads against these schemas — every `AgentEvent::ArtifactProposed` / `MutationProposed` flows through that validator.

---

## 10. Variant Ladder integration (B.1) — the universal dispatch shape

`agent_core/src/variant_ladder/mod.rs` (marked SCAFFOLD-ONLY today in commit `06819a33a`) becomes the canonical dispatch path for every tool route in Hermes 2.0.

```rust
let ladder: VariantLadder<SearchQuery, SearchResults> = VariantLadder::new()
    .tier_1(deterministic_tantivy_bm25)    // floor ≥ 0.85
    .tier_2(embedding_search)              // floor ≥ 0.75
    .tier_3(rrf_fused_search)              // floor ≥ 0.70
    .tier_4(grammar_bound_llm_search)      // escalate only on user opt-in
    .escalate_on_empty(false)              // RCA-A3 default
    .log_to(provenance_console);

let result = ladder.dispatch(query, ctx).await?;
```

Every `tool.execute()` becomes:

```rust
async fn execute(&self, input: Value, ctx: ExecutionContext) -> Result<String, ToolError> {
    self.variant_ladder.dispatch(input, ctx).await
}
```

This is how we make the agent feel "smart" — not by giving it a bigger model, but by making every tool capable of escalating from cheap-deterministic to LLM-bound when needed, AND of staying cheap when not.

---

## 11. The work shipped this week explicitly maps into Hermes 2.0

| Shipped 2026-05-13/14/15 | Hermes 2.0 surface |
|---|---|
| LockBusy retry + read-only fallback (`f7f3c273a`) | Foundation: vault writer reliability is the prerequisite for `note.create` / `note.edit` in any executor. |
| Gemma/Mistral excluded from `canActAsAgent` (`930b86989`) | `ProviderPolicy::LocalMLX` capability layer. Gemma stays available for `DirectChat` intent; only blocked for `AgenticToolCalling`. |
| `epistemos.{soul,skill,episode,semantic}.v1` schemas (`9b7629752`) | The typed contracts §9 describes. |
| `/image` hidden until provider lands (`e48205e3b`) | Honest capability gating — Hermes 2.0 follows the same rule for every executor. |
| Graph hide on note route (`2e356269b` + `8e371de91`) | Surface-isolation discipline. Same pattern for executor-specific UI panels. |
| Orphan scaffold quarantine (`06819a33a`) | Cleared `variant_ladder/`, `KaTeXSnippets`, `KIVIQuantization` so they can be promoted cleanly when Hermes 2.0 wires them. |
| Vault Organizer V1 known-limitation tooltip (`8547c0aa9`) | Honesty surface — same rule applies to executor capabilities. |
| CodeFileService canonical fix-pass collapse (`504c2696d`) | First example of "the structural fix is in place; the design doc names it canonically" — exactly the discipline Hermes 2.0 demands across all 30+ tools. |
| `list_notes` auto-route to `vault.search` (`41be78202`) | First concrete instance of Variant Ladder dispatch — tool auto-promotes from path-list (T1) to relevance-ranked (T1/T2/T3 of vault.search) on intent signal. |

All forward-compatible. Hermes 2.0 doesn't require rewriting any of these.

---

## 12. The 6-week implementation timeline (post-V1-MAS-submission)

Per Master Fusion Plan §B + §D acceptance bars, Hermes 2.0 starts AFTER:
- ✅ Phase A V1 ship gates resolved (user side)
- ✅ Phase B core items (B.1 Variant Ladder retrofit, B.4 reasoning cap, B.5 schemas) merged
- ✅ Phase C core items (C.1, C.7, C.8, C.11, C.12, C.16, C.17) merged
- ✅ Phase D Stage 1 (D.1 VaultXPC + D.2 CapabilityGrant) merged
- ✅ V1 MAS submitted

Then Hermes 2.0 lands in 6 weeks:

| Week | Goal | Artifacts |
|---|---|---|
| **1** | Make agents actually run | `AgentBlueprint`, `MissionPacket`, `AgentEvent`, `AgentExecutor` trait, `AnthropicMessagesExecutor`, `OpenAIResponsesExecutor`, Swift run sheet, `RunEventLog` timeline. **Pass:** user runs one agent and sees streamed events. |
| **2** | Native tools | `note.search` / `note.read` / `note.create` / `note.edit` / `graph.search` / `ask_user` + tool approval UI. **Pass:** agent creates a note from current note context. |
| **3** | SCOPE-Rex governance | `GovernedExecutor` wrapper, `SovereignGate.validate_*`, `RunEventLog` schema, `MutationEnvelope` enforced on every artifact. **Pass:** no tool executes without policy gate + event log. |
| **4** | Local model path | `LocalMLXExecutor`, `OpenAICompatibleExecutor` (Ollama / LM Studio), provider router, Keychain BYOK. **Pass:** same agent runs on cloud OR local provider; routing decided by `ProviderPolicy`. |
| **5** | Repo tools (Pro only) | `RepoContextGraph` (Aider-style repo map), `repo.read_file_window` (SWE-agent custom viewer), `repo.apply_patch` with rollback checkpoint. **Pass:** agent proposes patch but cannot apply without approval. |
| **6** | Pro CLI adapters | `ClaudeCodeAdapter`, `CodexCLIAdapter`, `GooseAdapter`, `AiderAdapter`, `OpenHandsAdapter`, Pro-only entitlement gate. **Pass:** Pro build launches Claude Code as governed executor; MAS build cannot import the module. |

**MVP shipped at end of Week 2:** "Run Native Research Agent" on a note → outline + 3 citations + propose new note → user approves save → `AnswerPacket` returned + RunEventLog timeline shown.

---

## 13. Tests + acceptance bars

```rust
// 1. Smoke test
"Create a note called Agent Test with one sentence"
  → AgentEvent::ToolProposed(note.create)
  → ApprovalRequested → ApprovalResolved::Approved
  → ToolStarted → ToolOutput
  → ArtifactProposed(TypedArtifact)
  → MutationCommitted → SessionCompleted(AnswerPacket)
  → Note visible in UI
  → RunEventLog has the full timeline

// 2. Tool denial test
"Delete all notes"
  → ToolProposed(note.delete_many) [doesn't exist; ApprovalDecision::DeniedByPolicy]
  → SovereignGate denies
  → SessionFailed(AgentFailure::PolicyDenial)
  → User sees denial card; no mutation

// 3. Provider fallback test
Anthropic unavailable
  → ProviderRouter falls back to OpenAI (or local) per policy
  → RunEventLog records the fallback decision
  → User sees "fallback to local Qwen" badge

// 4. Schema conformance test
LLM emits malformed AnswerPacket
  → MutationEnvelope rejects with SchemaViolation
  → SessionFailed(AgentFailure::SchemaConformance)
  → No silent markdown fallback

// 5. Pro CLI gating test
MAS build attempts CliExecutor
  → compile-time `#[cfg(feature = "pro-build")]` excludes the module
  → If somehow runtime: CapabilityDenied error
  → MAS bundle leak audit passes (zero matches)

// 6. Patch rollback test
Agent proposes patch
  → ApprovalResolved::Approved
  → repo.apply_patch creates checkpoint
  → Lint/test fail
  → checkpoint restored
  → UI shows rollback card with reason
```

---

## 13.5 Distillation from 2026-05-15 second research wave (refines §8 + §10)

A second pass of cross-research (Goose multi-provider Rust core / OpenHands typed-event SDK / SWE-agent ACI / Aider repo-map ranking / OpenClaw channel gateway) returned five concrete refinements to the design above. None of them changes the §1 architecture sentence; all of them sharpen specific sections.

### 13.5.1 Refined local-model lineup — benchmark-grounded, not just RAM-grounded

The §8.2 table was RAM-budget-driven. The new research backs that with HumanEval scores + adds three models we don't currently expose in `LocalTextModelID`. Adding them to the enum is V2.x work (new model HuggingFace IDs + capability rows); cataloging them as doctrine targets here unblocks that work later.

| Task class | Recommended (new) | HumanEval (cited) | RAM 4-bit | In catalog today? |
|---|---|---|---|---|
| Coding agent — primary | **Qwen 3.5 7B** | ~76/100 | ~5-6 GB | ❌ (we have 35B-A3B Unsloth, not 3.5 7B) |
| Coding agent — backup | **Qwen3-Coder 30B-A3B** | grammar-bound | ~9 GB | ✅ |
| Reasoning / planning | **Phi-4 14B** | strong | ~8 GB | ❌ (V2.x add) |
| Quick sub-tasks | **Phi-4-mini 3.8B** | light reasoning | ~2.5-4 GB | ❌ (V2.x add) |
| Default chat | Gemma 4 4B (kept) | natural assistant | ~2.5 GB | ✅ |
| Speed-critical | LFM2 2.6B (kept) | SSM hybrid | ~1.5 GB | ✅ |
| Tiny QA / translation | **Nemotron Nano 4B** | tiny | ~3-4 GB | ❌ (V2.x add) |
| Long doc analysis | Gemma 3 27B QAT (kept) | 1M token context | ~12 GB | ✅ |

Action: when the Hermes 2.0 implementation lands (post-V1), the V2.x model catalog expansion adds Phi-4 14B / Phi-4-mini 3.8B / Nemotron Nano 4B as `LocalTextModelID` cases with capability rows. Until then, the `select_local_model` router in §8.2 uses the available substitutes (Qwen 3.6 35B-A3B Unsloth where Qwen 3.5 7B would have been; DeepSeek-R1-Distill 7B where Phi-4 14B would have been).

### 13.5.2 The 4-layer local brain (refines §8 routing)

The second wave made the routing-by-task-class pattern explicit as a 4-layer architecture:

```
┌────────────────────────────────────────┐
│  Controller (Rust — Hermes Agent Core) │   selects sub-task + executor
│  • MissionPacket.intent()              │
│  • select_local_model(packet, ram)     │
└────────────────────────────────────────┘
                  ↓
   ┌──────────────┬────────────────┬────────────────┐
   ↓              ↓                ↓                ↓
┌─────────┐  ┌─────────┐    ┌─────────┐      ┌─────────┐
│Reasoning│  │ Coding  │    │  Tiny   │      │ Chat    │
│Phi-4 14B│  │Qwen 3.5 │    │Phi-4    │      │Gemma 4  │
│ (8 GB)  │  │ 7B (6GB)│    │mini /   │      │ 4B      │
│         │  │         │    │Nemotron │      │(2.5GB)  │
└─────────┘  └─────────┘    └─────────┘      └─────────┘
   plan        edit          quick QA          direct
   outline     patch         translation       stream
```

The `Controller` (Rust) chooses which "brain" answers a turn. A single agent run can hop between brains: outline (Reasoning) → write code (Coding) → polish (Reasoning) → name suggestions (Tiny). Because the entire stream still flows through MissionPacket → AgentEvent → SCOPE-Rex, the user sees one timeline; the model swap is invisible at the audit layer.

This is the practical answer to "should I train one custom MoE?" — no. **Route between off-the-shelf specialists** that already exist on HuggingFace + MLX-community.

### 13.5.3 Contextual retrieval — wire it through the existing Halo Shadow stack

The "first 7 irrelevant notes" bug had ONE specific fix today (commit `41be78202` — `list_notes` auto-routes to `vault.search`). The second research wave reframes the WHY: every agent retrieval should be a RAG-style pipeline (embedding + BM25 hybrid), not a list-and-pray.

We already have the substrate:
- `Epistemos-shadow` (Rust crate, BM25 + HNSW + RRF fusion at k=60)
- `RRFFusionQuery.swift` (Swift mirror + `SearchFusionMetrics`)
- `RustShadowFFIClient` (production FFI)
- `ShadowVaultBootstrapper` (crawls `<vault>/notes/**/*.md` + `<vault>/chats/**/*.json`)

So the work isn't to BUILD retrieval. The work is to make every agent retrieval tool **route through Shadow by default** — which is exactly what the §B.1 Variant Ladder retrofit accomplishes for `vault.search`. The B.2 tool registry (committed `c2b7eaab5`) already documents which tools populate T1/T2/T3 (BM25 / embedding / RRF-fused).

This locks the pattern: every retrieval tool's Variant Ladder MUST include the Shadow fusion path at T3. Tools that don't (e.g. `vault.list` pre-auto-route) are stamped with the alphabetical-not-relevance disclaimer.

### 13.5.4 Repo map ranking — PageRank-by-dependency-graph, not just file order

§5 of the design + §B.1 retrofit reference Aider's repo-map but didn't pin the ranking algorithm. The second research wave makes it explicit:

> Aider's docs explain that it sends a concise map of key files, classes, methods, signatures, and relevant symbols to the model, then ranks the map by dependency graph relevance and token budget.

For `repo.map` (Pro tool — §7.2), this means:

```rust
pub fn rank_repo_context(
    graph: &RepoContextGraph,
    query: &str,
    changed_files: &[PathBuf],
    token_budget: usize,
) -> RepoMapSlice {
    // 1. lexical query match (T1 BM25 over symbol names + signatures)
    // 2. changed-file proximity (BFS from `changed_files` over `Imports` / `Calls` edges)
    // 3. dependency centrality (PageRank with damping=0.85 over the directed
    //    edge graph — same heuristic Aider uses)
    // 4. symbol importance (boost public exports + types + tests)
    // 5. token budget packing (greedy fill to budget, dropping
    //    lower-scoring entries first)
    todo!() // V2.x implementation lands in Pro repo tools (Week 5 of the timeline §12)
}
```

This is doctrine — the actual code lives in a new `epistemos-repo-map` crate per §15 layout. Pinning the algorithm now means the V2.x PR has a single sentence to satisfy.

### 13.5.5 OpenClaw channel-gateway pattern — gated post-V1.1

The second wave surfaces OpenClaw's idea of a multi-channel gateway (iMessage / Slack / Discord / etc. as agent inbound channels). Already in the Substrate Track Register as **Phase K — iMessage as Channel** with Pro-only workspace-scoped dispatch profiles. **Stays excluded from V1**; the design here points at it without owning it.

### 13.5.6 Net update to the §13 acceptance bars

Add **test #7 to §13**:

```rust
// 7. RAG retrieval relevance test
"Find notes about state space models in my vault"
  → AgentEvent::ToolProposed(vault.search) [NOT list_notes]
  → vault.hybrid_search returns RRF-fused top-N
  → results have score ≥ FLOOR_T3 (0.70)
  → user sees relevance-ranked notes (not alphabetical first-N)
```

This pins the user's specific reported bug ("Qwen listed only 7 irrelevant notes") into the acceptance bar so any future regression fails CI.

### 13.5.7 Per-model Knowledge Vaults + cloud distillation lab

**Source:** `docs/_consolidated/20_canonical_research/CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md` §1-2 + §File-Structure + §UI-Integration · PASS 2 gap audit B2-H6.

Every model — local (Qwen 3.5 / Phi-4 / Apple Intelligence) and cloud (Claude Opus / Claude Haiku / GPT) — gets its own **Knowledge Vault** at `~/Library/Application Support/Epistemos/model_vaults/<model-id>/` containing **two layers**:

**Layer 1 — Base Knowledge (compiled offline by NightBrain).** Static facts distilled from the user's vault into a model-specific token budget. Files per vault:

| File | Purpose | Token budget |
|------|---------|--------------|
| `knowledge_profile.md` | Domain map · entity graph · writing-style fingerprint | Cloud ~2000 · Local ~800 · Apple Intelligence ~500 |
| `concept_index.md` | Top N concepts with one-line definitions (N scales with budget) | embedded |
| `active_context.md` | Rolling 7-day window of recent material | embedded |
| `instructions.md` | **User-authored preferences — editable directly from Notes sidebar** | unbounded; reviewer-visible |
| `meta.json` | `{ last_compiled, note_count, content_hash, distillation_run_id }` | n/a |
| `history/<date>.json` | Per-day snapshots for `epistemos-trace`-style replay | n/a |

**Layer 2 — Dynamic Retrieval (per query).** At call-time the Variant Ladder's `vault.search` (T3 hybrid RRF, §10.x) injects top-K relevance hits as system-prompt prefix material. Cloud models get a bigger K; Apple Intelligence gets K=1 because its 4096 hard cap leaves no headroom. The Base Knowledge layer **does not get re-fetched** per turn — it lives in the cached prefix per `B2-H12` prompt-tree.

**Per-model token-budget table** (matches §8.2 local-brain routing):

| Model class | Base Knowledge budget | Dynamic Retrieval K | Notes |
|---|---|---|---|
| Claude Opus / Sonnet (cloud) | ~2000 tok | K=10 | Full distillation; prompt-cache breakpoint at base-knowledge boundary so it amortizes across turns |
| GPT-5 / Gemini (cloud) | ~2000 tok | K=10 | Same pattern, different provider router. ProviderRouter §13.6.5 gates which base-knowledge file to load |
| Qwen 3.5 4B (local) | ~800 tok | K=3 | Constrained context; concept_index is top-20 only |
| Phi-4 / Phi-4-mini (local) | ~800 tok | K=3 | Same as Qwen |
| Nemotron Nano 4B (local, controller) | ~600 tok | K=2 | Tiny brain layer per §13.5.2 4-layer routing |
| Apple Intelligence (system) | ~500 tok | K=1 | 4096 hard limit; minimal profile + one retrieved snippet |

**NightBrain integration (Wave 8.4).** `cloud_knowledge_distillation` task body (currently NoOp per Atlas Drift Log row 1) compiles `knowledge_profile.md` + `concept_index.md` + rolls `active_context.md` per model on user-quiesced ≥3 min idle + ≥8 GB free. Each compilation writes a `history/<date>.json` snapshot. `meta.json.content_hash` lets the runtime detect when a model's base knowledge has drifted from the vault and trigger re-compilation.

**UI integration.** Notes sidebar gets a "Model Vaults" section header collapsing the per-model directories; clicking opens `instructions.md` in the Tiptap editor so the user edits model-specific prompts directly. **No new tool**; the existing `note.create` / `note.edit` paths handle the writes because the vaults are just folders. Honesty discipline: when `instructions.md` is present, the system-prompt prefix MUST cite it explicitly so the user can tell which message came from their own preferences vs the model's training.

**Why this row is load-bearing:** the per-model split is the architectural answer to "why is Claude smarter on my codebase than Qwen?" The user perception that "the model knows me" requires a stable, editable, per-model knowledge surface. Without this section, V1's local-vs-cloud quality gap reads as a model-capability problem; with it, the user has a direct lever to close that gap by editing `instructions.md`.

**Boundaries:**
- **What this is**: per-model knowledge vault layout + compilation pipeline + UI surface.
- **What this is NOT**: a memory / RAG replacement — the canonical retrieval path stays `vault.search` Variant Ladder (§10.x). Knowledge Vaults are PREFIX context, not search substrate.
- **Crosslinks:** §13.5.3 (Contextual retrieval — wires `vault.search` into the prefix) · §13.5.4 (Repo map ranking — analogous pattern for code repos) · §13.6.4 (Multi-model orchestration — picks which model's vault to load per turn) · §13.6.5 (ProviderRouter — single dispatch point with vault-load side-effect).

---

## 13.6 Distillation from 2026-05-15 third research wave — Hermes-spine convergence

The third research wave was three independent traces (Unified Local Agent Framework / Integrated Agent Architecture / Hermes-Spine Design) that all converged on the same architecture. Convergence from independent sources is itself a doctrine signal — when three traces independently land on "single Rust agent loop + typed events + schema-driven tools + Aider-style repo map + provider-agnostic executor trait + governance wrapper + MAS/Pro split," it stops being a design choice and starts being a discovered invariant.

What §13.6 contributes that wasn't already in §1-§13.5:

### 13.6.1 The GovernedExecutor pattern (sharpens §3 + §4)

§3 declared the `AgentExecutor` trait. §13.6 makes the **wrapper pattern** explicit: every concrete executor is itself wrapped by a `GovernedExecutor` that runs the SCOPE-Rex policy + RunEventLog write before and after every tool call. The trait stays the same; the policy fold-over is mandatory.

```rust
struct GovernedExecutor<E: AgentExecutor> {
    inner: E,
    policy: PolicyChecker,
    log: Arc<RunEventLog>,
}

#[async_trait]
impl<E: AgentExecutor> AgentExecutor for GovernedExecutor<E> {
    async fn execute(&self, packet: MissionPacket, ctx: ExecutionContext)
        -> Result<Pin<Box<dyn Stream<Item=Result<AgentEvent,AgentError>> + Send>>, AgentError>
    {
        let stream = self.inner.execute(packet, ctx).await?;
        Ok(Box::pin(self.log.clone().wrap_stream(stream, self.policy.clone())))
    }
}
```

The doctrine rule: **no executor is registered with `ProviderRouter` unwrapped**. Constructor of every executor returns `Arc<GovernedExecutor<Self>>`, not `Arc<Self>`. This is enforced by a source-guard test (Week 1 deliverable): `rg "register_executor.*Box::new" agent_core/src/ | grep -v Governed` must return zero matches.

### 13.6.2 Tool schemas compile into multiple targets

§9 declared tool contracts. §13.6 makes the **multi-target codegen** explicit: one `ToolDefinition` produces:

| Target | Output | Used by |
|---|---|---|
| Anthropic Messages | `tools[]` JSON with `name + description + input_schema` | `AnthropicExecutor` |
| OpenAI Responses | `tools[]` JSON with `type: "function"` shape | `OpenAIResponsesExecutor` |
| Local GBNF grammar | Compiled `*.gbnf` for `LocalToolGrammar.buildToolCallingPlan` | `LocalMLXExecutor` (Qwen 3.6 / Gemma 4) |
| Pro CLI args | argv synth (e.g. `--prompt=$1`, `--json-out`) | `ClaudeCLIExecutor`, `CodexCLIExecutor` |
| Swift UI form | SwiftUI form bindings via `JSONSchema` decoder | Tool-input editing UI (Pro Settings) |
| MCP tool list | `tools/list` response shape per MCP spec | `MCPBridge` (Swift) |

Single source of truth = `ToolDefinition { name, input_schema, output_schema, requires_approval, availability }`. Codegen lives in `agent_core/src/tools/codegen/` (new module — Week 2 deliverable). This means a tool added in one place becomes available in every provider/UI surface automatically; no drift between Anthropic's tool block and the local Qwen grammar.

### 13.6.3 ACI discipline — lint/test before write

§5 (Repo map) mentioned Aider's edit loop. §13.6 makes the ACI rule from SWE-agent explicit: **every code-mutation tool runs lint + tests before writing**. Not as a follow-up; as part of the tool's contract.

For `ApplyPatch`:

```rust
pub struct ApplyPatchArgs {
    pub patch: String,            // unified-diff
    pub run_checks_before_commit: Vec<CheckSpec>,  // ["build", "unit", "lint"]
    pub rollback_on_check_failure: bool,           // default true
}

pub struct ApplyPatchResult {
    pub success: bool,
    pub commit_sha: Option<String>,    // None if rolled back
    pub check_outcomes: Vec<CheckOutcome>,
    pub diff_preview: String,           // short_diff_preview for UI
    pub verified: bool,                 // verify_file_readback
    pub rolled_back: bool,
    pub rollback_reason: Option<String>,
}
```

Source-guard test: every code-mutation tool definition in `tools/registry.rs` must declare `requires_post_check: true` in its metadata. (Doctrine pin lives in `agent_core/src/tools/registry.rs:tests`.)

### 13.6.4 Multi-model orchestration within a single turn

§13.5.2 introduced the 4-layer brain. §13.6 makes the **intra-turn model-swap** explicit: the Controller may swap models within a single user turn based on the current sub-task.

```
user: "research state space models and draft a brief"
  │
  ├─ Controller dispatch:
  │
  ├─ Reasoning brain (Mistral Small 7B or Phi-4 14B if RAM permits)
  │   → outline sections [planning sub-task]
  │
  ├─ Retrieval (Tier 1-3 via Shadow + RRF)
  │   → fetch top-N notes [no LLM]
  │
  ├─ Coding brain (Qwen 3.6 35B-A3B Unsloth via MLX)
  │   → if a draft includes code snippets / analysis
  │
  ├─ Reasoning brain (same Phi-4 14B)
  │   → synthesize draft + polish
  │
  └─ Tiny brain (Gemma 4 4B)
      → suggest filename / tags / cite-list
```

User sees one timeline. AgentEvent stream stamps each ToolCall + ModelDelta with the underlying executor ID so the Provenance Console can show "this paragraph came from Phi-4 14B, this code from Qwen 3.6, this tag from Gemma 4 4B." This is the practical fulfillment of "Epistemos is the guardian; the model is just a brain."

### 13.6.5 ProviderRouter is the single dispatch point

§4 declared executors. §13.6 names the dispatch surface: `ProviderRouter` (in `agent_core/src/provider/router.rs`, new). The router consults:

1. `MissionPacket.preferred_executor` (user UI selection — Settings > Agents > [agent_name] > Provider)
2. `MissionPacket.intent_class` (Controller's sub-task class)
3. `PolicyContext` (MAS forbids CLI; Pro permits)
4. Runtime availability (model loaded? cloud reachable? CLI installed?)

Selection is logged into the AgentEvent stream as `RouterDecided { selected: ExecutorId, alternatives: Vec<ExecutorId>, reason: String }` so the audit trail captures why a particular executor was chosen for a given turn.

The MAS/Pro split:

```rust
fn select_executor(packet: &MissionPacket, ctx: &PolicyContext) -> Result<ExecutorId, RouterError> {
    let preferred = packet.preferred_executor.clone();
    match preferred {
        ExecutorId::ClaudeCli | ExecutorId::CodexCli | ExecutorId::GeminiCli | ExecutorId::KimiCli => {
            ctx.permission.require_pro()
                .map_err(|_| RouterError::ExecutorRequiresProBuild { id: preferred.clone() })?;
            // Pro-only path
        }
        _ => {}  // MAS-safe path
    }
    // ... availability checks, fallback to default brain if preferred is unavailable
    Ok(preferred)
}
```

Source-guard test: `cargo test --manifest-path agent_core/Cargo.toml --features mas-build provider::router::mas_forbids_cli_executors` proves the MAS feature flag rejects all CLI executors at compile + runtime time.

### 13.6.6 Net update to §12 timeline

Add **Week 0 (pre-Week 1)** — Provider abstraction lift:

- Lift Goose's `Provider` enum pattern (block/goose Rust source) into `agent_core/src/provider/`. This is a 1-day spike, not a port — just enough to give us the multi-provider registry shape before Week 1 lands the `MissionPacket → AgentEventStream` loop.
- Define `ToolDefinition` codegen module skeleton (Week 2 detailed work; Week 0 sets the trait shape so Week 1 executors can speak it).

Net plan stays 6 weeks total; Week 0 is internal, not a delivery week.

### 13.6.7 Architecture sentence — third-wave reinforced

The §16 sentence holds. The third wave specifically reinforces the second half:

> *Epistemos agents are Hermes-governed native agents whose executor can be local, cloud, MCP, or Pro CLI, but whose memory, permissions, schemas, artifacts, and audit trail always belong to Epistemos.*

The third wave's convergence on `GovernedExecutor` + multi-target tool codegen + 4-layer local brain orchestration directly serves the second half. No design changes; tighter implementation contracts.

---

## 14. Open questions deliberately deferred

1. **Sub-agents (Claude Agent SDK pattern)**. The design includes `AgentEvent::ToolProposed → agent.spawn_subagent` but the implementation is post-V1.
2. **Multi-agent ACS** (V2.7 per `post_recovery_v2_plan`). Same.
3. **Context condenser** (OpenHands-style 6-layer compaction). Implementation lives in `agent_core/src/compaction.rs` today; needs to be wired into the `AgentExecutor` lifecycle in Week 3.
4. **Repo map ranking** (Aider's graph-centrality algorithm). Rust port lives in `epistemos-repo-map` crate (new); Week 5 deliverable.
5. **MCP marketplace** (OpenClaw / Goose extensions). Post-V1; needs SovereignGate consent UI.
6. **Goodfire VPD distillation** for a custom Epistemos brain MoE. V6.1 research-tier; explicitly NOT on the V1 path.

---

## 15. Cross-references

- `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` — overall sequencing
- `docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md` — Atlas of primitives
- `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` — §10 source
- `docs/fusion/COGNITIVE_KERNEL_DOCTRINE_2026_05_03.md` — kernel collapse philosophy
- `docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md` — Wave F XPC services that Hermes 2.0 will run inside
- `docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` — Pro gating discipline
- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` — FFI contracts
- `agent_core/schemas/README.md` — typed contracts
- `agent_core/src/agent_runtime/` — current in-process agent runtime (this design supersedes its ad-hoc seams)
- `agent_core/src/variant_ladder/mod.rs` — typed dispatch seam (orphan; promoted to canonical here)

---

## 16. Architecture sentence (for repetition)

> *Epistemos agents are Hermes-governed native agents whose executor can be local, cloud, MCP, or Pro CLI, but whose memory, permissions, schemas, artifacts, and audit trail always belong to Epistemos.*

That sentence is the test for every PR touching the agent surface. If a change makes a provider's identity bleed into Epistemos, reject the change.

---

*— End of Hermes Agent Core 2.0 design v0.1. 16 sections. Lands AFTER V1 MAS submission per the Master Fusion Plan sequencing.*
