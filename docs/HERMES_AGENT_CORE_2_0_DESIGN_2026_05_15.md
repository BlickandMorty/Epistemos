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

### 4.2 V6.2 AnswerPacket binding — SHIPPED Option B (B2-M4)

**Source:** `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md` §"The race in concrete terms" + §"Two architectural options". PASS 2 audit row B2-M4 framed this as undecided ("Option A or B; no code landed"). **§5.0 reconciliation finding: Option B already shipped in commit `c0c14f98e` "helios v6.2 Option B: AnswerPacket id binds to ChatMessage end-to-end".** The audit row was stale at the time of writing; this section records the decision retroactively.

**The race the fix addresses.** `StreamingDelegate.onComplete` used to emit the V6.2 AnswerPacket inside an unstructured `Task { … emit(packet) }` while `continuation.yield(.complete)` ran synchronously on the same call. By the time `ChatState.recordCompletedTurn(...)` ran, the emit task might or might not have committed the packet — the new `assistantMessage.id` had no deterministic binding to the packet just emitted for it. On M-series Macs the actor hop is usually fast enough that the packet arrived first, but the binding was probabilistic, and a regenerate-then-resume pattern (two assistant messages completing in quick succession) could bind a bubble to the wrong packet.

**The decision: Option B (packetId threaded through the stream event).**

```swift
// AgentStreamEvent.complete gained an answerPacketId field:
case complete(
    stopReason: String,
    inputTokens: Int,
    outputTokens: Int,
    answerPacketId: String?,    // NEW — nil only if emit failed
    history: [[String: String]]?
)
```

`StreamingDelegate.onComplete` (Epistemos/Bridge/StreamingDelegate.swift:595-636) now: builds the AnswerPacket → `await AnswerPacketEmitter.shared.emit(packet)` → THEN `continuation.yield(.complete(..., answerPacketId: packet.id, ...))`. The packet is committed in the ring before the downstream consumer sees `.complete`, so `ChatCoordinator.handle(.complete)` (Epistemos/App/ChatCoordinator.swift:807, 2927) can deterministically stamp `answerPacketId` onto the new ChatMessage via `AgentChatState.completeProcessing(answerPacketId:...)` (Epistemos/State/AgentChatState.swift:366).

**Why Option B over Option A.** Option A ("LatestAnswerPacketSink mirroring `AnswerPacketEmitter.shared.last`, with timestamp matching") was rejected because the race still existed — it only added a heuristic ~10ms wait window before binding. Option B eliminates the race architecturally: the packet id is a structured field on the event itself, so the binding is deterministic regardless of actor-hop timing or regenerate-then-resume rate. The cost is exactly one field added to one enum case — minimal cross-cutting change.

**End-to-end paper trail.** The packet flows StreamingDelegate → AgentStreamEvent.complete (with `answerPacketId`) → ChatCoordinator.handle(.complete) → AgentChatState.completeProcessing → `ChatMessage.answerPacketId`. The per-bubble VRMLabelView reads `ChatMessage.answerPacketId` and resolves it via `AnswerPacketEmitter.shared.recentPackets()` — no timestamp matching, no probability, no flicker on scroll.

**Cross-links:**
- B2-M4 PASS 2 audit row.
- `docs/audits/V6_2_PER_BUBBLE_BINDING_RESEARCH_2026_05_12.md` — the source spec that drafted Option A vs B.
- Commit `c0c14f98e` (Option B end-to-end) · `9b1db4170` (InterruptScore bucket sampled into packet) · `0d757b57f` (attention_mode populated).
- §4.1 The five canonical AgentEvent variants — `.complete` is the variant this field lives on.
- §5.1 ExecutionReceipt — sibling per-turn provenance primitive that ExecutionReceipt is the per-tool-call counterpart of.

**Status:** SHIPPED. Reconciliation gate caught the staleness this iteration (the audit row predicted an undecided state; the codebase had shipped Option B 4 days before the audit was written).

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

### 5.1 ExecutionReceipt + Capability — SHIPPED provenance primitive

**Code:** `agent_core/src/effect/receipt.rs` (173 LOC). PASS 2 gap audit B2-H13.

Every governed tool invocation produces a signed **`ExecutionReceipt`** before the result flows back to the agent loop. The receipt is the on-the-wire proof that a specific tool ran with a specific capability set at a specific time, and its output hash is what downstream consumers (ClaimLedger, RunEventLog, Provenance Console) cite.

**`Capability` enum** — 4 variants encoding the capability axes the receipt cares about:

| Variant | Fields | Used for |
|---|---|---|
| `VaultPath { path, verb }` | vault-relative path + read/write/append verb | per-file capability narrowing (pairs with B2-H19 egress allowlist for the network analog) |
| `NetworkHost { host }` | host string | per-host network gate |
| `BiometricSession { ttl_secs }` | TTL seconds | SovereignGate biometric session window |
| `Other { name }` | free-form name | escape hatch for one-off capabilities pending a typed variant |

**`ExecutionReceipt` struct** — 8 fields with the canonical signing layout:

```rust
pub struct ExecutionReceipt {
    pub call_id: String,
    pub plan_hash: String,
    pub tool: String,
    pub input_hash: String,
    pub output_hash: String,
    pub timestamp: DateTime<Utc>,
    pub capabilities_used: Vec<Capability>,
    pub signature: String,
}
```

**Signing.** `ExecutionReceipt::sign<K: SigningKey>(…)` takes a generic `SigningKey` (currently `HmacSha256SigningKey` with 32-byte secret + manual HMAC-SHA256 implementation per RFC 2104). `verify()` returns `bool` with constant-time comparison (`diff |= signature[i] ^ expected[i]`). The signing payload is a deterministic length-prefixed concatenation of every field — same fields ⇒ same bytes, so signatures are reproducible.

**Deviation from PASS 2 audit spec (logged 2026-05-16):**
- Audit said "Ed25519 signature placeholder." **Actual: HMAC-SHA256.** Functional for same-machine verification (the secret stays in the host process); insufficient for **cross-machine** verifiability (no public/private split). When V1.x needs `.epbundle` replay on a different machine, swap `HmacSha256SigningKey` for an Ed25519 implementation behind the same `SigningKey` trait. The deviation is **not a regression** — current code does what's needed for current callers; Ed25519 is a forward-compat upgrade.
- Audit said `capability_hash` (single). **Actual: `capabilities_used: Vec<Capability>`** (list). The list shape is strictly richer — a hash discards which specific capabilities composed it. Keep the list.

**Cross-references:**
- `agent_core/src/cognitive_dag/edge.rs:144-163` — `capability_hash` (different concept, BLAKE3 hash of capability set for DAG-edge witness; same name, different layer)
- `agent_core/src/cognitive_dag/storage.rs:74+392` — `register_capability(_, capability_hash: Hash)` in the DAG storage trait
- `agent_core/src/resources/attachments.rs:13` — separate `pub enum Capability` for attachment-grant scope (different domain)
- `MASTER_FUSION §3.33` (Artifact Identity) — the artifact half of the same provenance story; ExecutionReceipt's `output_hash` is the bridge

### 5.2 Ephemeral capability tokens — request-time, one-shot, RunEventLog-bound (B2-H20)

**Source:** `docs/fusion/research/FINAL_SYNTHESIS.md §5.2` lines 421-429 (verbatim contract). PASS 2 audit row B2-H20 surfaced by audit-of-audit #3 at iter 30. This section fills the §5.2 reserved slot that 4 prior commits in the loop forward-pointed to (lines 1192 §13.5.10 · 1196 §13.5.10 crosslinks · 1394 §13.7 Guardrail · 1403 §13.7 crosslinks).

### The verbatim contract (FINAL_SYNTHESIS §5.2 lines 423-429)

> Every tool call receives a **one-shot capability token** issued by **Layer 4 (Immune)**. The token:
> - Encodes exactly the capabilities authorized for *this* call.
> - **Expires immediately on tool completion.**
> - Cannot be re-used or persisted.
> - Is logged in **RunEventLog** with the call it authorized.

"This means a tool that gains capability `network: localhost:obscura_port` cannot, ten seconds later, use that capability for a different call. It must request afresh and pass authorization again." (§5.2 line 429)

### The 3-layer security-token story (lifecycle)

The full audit chain layers from coarse-grained (long-lived) to fine-grained (per-call) to attestation (post-completion):

```
SovereignGate consent (long-lived per session)
        ↓
Macaroon issued (TTL-bounded, via agent_core/src/cognitive_dag/macaroons.rs)
        ↓
Ephemeral Capability Token (one-shot, RunEventLog-bound, expires-on-completion) ← B2-H20 / §5.2
        ↓
Tool executes (constrained to token's exact capability set)
        ↓
ExecutionReceipt signed (§5.1, completion-time attestation)
        ↓
Token expires (no reuse possible)
        ↓
RunEventLog entry sealed
```

### Distinct from three adjacent primitives

| Primitive | When | Scope | Lifetime |
|---|---|---|---|
| **§5.1 ExecutionReceipt** (B2-H13) | **Completion-time** signed log entry | Per-tool-call attestation of *what happened* | Permanent on-disk record |
| **§5.2 Ephemeral capability token** (B2-H20) | **Request-time** authorization | Per-tool-call permission fence for *what may happen* | One-shot — expires on tool completion (success OR failure) |
| **§7.5 Capability Lease** (B2-H10) | Pro-only XPC session | Zero-copy handle-binding for a data plane | Lease window (Pro tier only) |
| Macaroon (substrate) | Issued at user-approval moment | Reusable within TTL + scope caveats | Hours to days (TTL via `Caveat::ExpiryAfter`) |

**The gap §5.2 fills:** macaroons are reusable within their TTL; ExecutionReceipt is post-hoc. Without §5.2, a tool that obtained a macaroon for one purpose could in principle use it for a different call before the TTL elapsed. The ephemeral token narrows the macaroon's authority to **exactly this one invocation**, then dies — closing the request-time-authorization gap between consent (macaroon) and attestation (receipt).

### Substrate — builds on `agent_core/src/cognitive_dag/macaroons.rs`

The macaroon module (930 LOC, Phase 8.C, SHIPPED) provides the foundation:

- `Macaroon { root, caveats, signature }` with HMAC-chain signature.
- `Caveat` enum: `ScopePrefix { prefix }` · `ExpiryAfter { until_ts_ms }` · `ToolNameEq { tool }` · `AdditionalContext { ... }`.
- Operations: `issue` · `restrict` · `delegate` · `revoke`.
- `capability_hash_of(&Macaroon) -> Hash` for edge signing.
- Revocation cascade integration with Phase 8.B resonance propagation.

**What §5.2 adds (forward-staged, NOT-STARTED in code — `rg "ephemeral\|one.shot\|single.use" agent_core/src/cognitive_dag/macaroons.rs` returns zero hits):**

```rust
// Proposed addition to Caveat enum (forward-staging shape):
pub enum Caveat {
    ScopePrefix { prefix: String },
    ExpiryAfter { until_ts_ms: u64 },
    ToolNameEq { tool: String },
    AdditionalContext { /* ... */ },

    // NEW (B2-H20):
    /// One-shot — bound to a single RunEventLog entry; the token
    /// can be verified at most ONCE for the bound run_event_id,
    /// and verification consumes it (via the run-event sealing
    /// flow). Composes orthogonally with ScopePrefix + ToolNameEq.
    OneShot { run_event_id: NodeId },
}

/// Issue an ephemeral capability token by restricting a parent
/// macaroon to a single RunEventLog entry. Layer 4 (Immune) call site.
pub fn issue_ephemeral(
    parent: &Macaroon,
    run_event_id: NodeId,
    tool: &str,
    scope: &str,
) -> Macaroon {
    parent
        .restrict(Caveat::OneShot { run_event_id })
        .restrict(Caveat::ToolNameEq { tool: tool.into() })
        .restrict(Caveat::ScopePrefix { prefix: scope.into() })
}

/// Verify-and-consume — must be called exactly once per
/// ephemeral token. Subsequent calls fail.
pub fn verify_and_consume_ephemeral(
    token: &Macaroon,
    run_event_id: NodeId,
    log: &mut RunEventLog,
) -> Result<(), VerifyError> { /* ... */ }
```

The `Caveat::OneShot { run_event_id }` addition is the minimal substrate change. Everything else (ScopePrefix, ToolNameEq, ExpiryAfter composition) already exists.

### Composition rule with existing caveats

When an ephemeral token is verified, ALL caveats must pass:

1. `OneShot { run_event_id }` — token has NOT been previously consumed for this run_event_id.
2. `ScopePrefix { prefix }` — the call's vault path / network host matches the prefix.
3. `ToolNameEq { tool }` — the call's tool name matches exactly.
4. `ExpiryAfter { until_ts_ms }` — the parent macaroon's TTL has not elapsed (defense-in-depth: ephemeral tokens also respect their parent's TTL).

A single failure rejects the call. Successful verification consumes the OneShot — the next attempted verify returns `VerifyError::AlreadyConsumed`.

### Layer 4 (Immune) issuance hook

Per FINAL_SYNTHESIS §5.2: issuance is the Layer 4 / Immune call site. In Hermes 2.0 terms this maps to the **Guardrail role** in the Multi-Overseer-4 hierarchy (§13.7) — Guardrail issues ephemeral tokens BEFORE Planner-decided tool calls execute, and verifies them at the AgentExecutor boundary. The Guardrail row in §13.7 (line 1394) already cites "§B2-H20 ephemeral tokens (request-time)" in its toolkit list.

### V1 / Pro / Post-V1 boundary

- **V1 MAS:** Macaroon substrate ships (already in main, Phase 8.C). Ephemeral one-shot caveat: **NOT-STARTED**. V1 web tools rely on §0 rule 6 + rule 7 framework + AgentBlueprint capability budget for coarse-grained gating.
- **V1.x (alongside SovereignGate hardening):** `Caveat::OneShot { run_event_id }` variant added to `agent_core/src/cognitive_dag/macaroons.rs` + `issue_ephemeral` + `verify_and_consume_ephemeral`. AgentExecutor wraps every tool dispatch in `verify_and_consume_ephemeral` before the call, releases on completion.
- **Wave 9+:** Auto-research loops (§13.5.10) consume per-fetch ephemeral tokens — every external fetch in the morning auto-research workflow goes through SovereignGate consent → macaroon → ephemeral token → fetch → ExecutionReceipt, per the §13.5.10 line 1192 crosslink that already exists.

### Why this is forward-staging not §5.0 catch

audit-of-audit #3 (iter 30) correctly surfaced that the audit chain had a request-time-authorization gap between macaroons (reusable within TTL) and ExecutionReceipts (post-hoc). Macaroon substrate exists; the `OneShot` caveat extension does NOT. This section writes the doctrine the audit predicted needed writing — including the verbatim source-spec contract, the 3-layer lifecycle, the substrate addition shape, and the composition rule. The 4 forward-pointers from prior commits (lines 1192/1196/1394/1403) now resolve to this real destination.

### Cross-references

- B2-H20 PASS 2 audit row.
- `docs/fusion/research/FINAL_SYNTHESIS.md §5.2` lines 421-429 — canonical source.
- `agent_core/src/cognitive_dag/macaroons.rs` (930 LOC, Phase 8.C SHIPPED) — substrate foundation.
- §5.1 ExecutionReceipt (B2-H13) — completion-time attestation; ephemeral token is the request-time counterpart.
- §7.5 Capability Lease (B2-H10) — Pro-only XPC handle binding; orthogonal scope.
- §13.7 Multi-Overseer Guardrail role — issuance + verification site.
- §13.5.10 Auto-research loops — per-fetch consumer (line 1192 + 1196 cross-links).
- MAS_COMPLETE_FUSION §0 rule 8 (B2-H19) — sibling forward-staged security primitive on the same FINAL_SYNTHESIS §5 page (egress.rs gates network access, ephemeral tokens gate authorization).
- MASTER_FUSION §3.42 DP gate (B2-M14) — sibling forward-staged Wave 9+ privacy primitive on the same FINAL_SYNTHESIS §5 page.

---

### 5.3 Five-Plane formalism — RuntimePlane canonical enum (B2-M6)

**Source:** `Epistemos V6_1 — Final Synthesis Lock` PART 3 + HELIOS V6.1 §3. PASS 2 audit row B2-M6 framed this as "canonicalization deferred"; **§5.0 reconciliation finding: `RuntimePlane` enum is already canonical in `epistemos-research/src/five_planes.rs` and load-bearing** in `v6_1_stream_surface.rs` + `v6_1_execution_policy.rs`. This section records the doctrine cross-reference into Hermes 2.0's provenance vocabulary that the audit identified as missing.

**The orthogonal axes.** Tri-stream is the *product* organization (MAS · Pro · Vault per §6). Five Planes is the *runtime* organization. They are orthogonal: every stream contains the same five planes with different surface-area exposed. The full surface is a 5 × 3 = 15-cell matrix enumerated as `ALL_FIFTEEN_CELLS` at `epistemos-research/src/v6_1_stream_surface.rs:142-157`.

**The five planes** (canonical numbering per `RuntimePlane::plane_number(self) -> u32`):

| # | Plane | Substrate | What lives here |
|---|---|---|---|
| 1 | **State** | Recurrent semantic spine (Mamba-2 / Granite-4-H / Falcon-Mamba); semiseparable block scan. | Default cost; semantic continuity; carries the running narrative. |
| 2 | **Episodic** | Exact recall pages. | Atlas · tool traces · pinned quotes · ClaimLedger entries · theorem witnesses · file-line anchors. |
| 3 | **Assembly** | Runtime routing language; symbolic-then-learned. | Gate3 · cortical packets · Connectome anchors · Variant Ladder dispatch (§10). |
| 4 | **Controller** | Small high-leverage executive surfaces. | write / forget / admit / route / norm / safety gates · speculative-accept · kernel-promotion. |
| 5 | **Verification** | Audit substrate. | WBO · ClaimKind · AnswerPacket · VRM labels · sheaf-residual · witness logs · ReplayBundle · ExecutionReceipt (§5.1) sits here. |

**Mapping into Hermes 2.0 provenance vocabulary.** The audit's framing was "could standardize `ClaimLedger` / `ReplayBundle` / `VerificationPlane` vocabulary." The mapping is:

- `ClaimLedger` (`agent_core/src/provenance/ledger.rs`) → **Plane 2 Episodic** (claims are exact-recall facts) AND **Plane 5 Verification** (each claim is audit-attestable). Bi-plane is intentional — claims bridge episodic exact recall and verification audit.
- `ReplayBundle` (`agent_core/src/provenance/replay.rs`) → **Plane 5 Verification** primarily; cross-plane in that it snapshots state from all 5 planes at a session boundary.
- `ExecutionReceipt` (§5.1) → **Plane 5 Verification** (per-tool-call attestation).
- `AnswerPacket` (V6.2 §S3.5) → **Plane 5 Verification** (rendered chip in VRMLabelView).
- `MutationEnvelope` (in `epistemos.semantic.v1` schema) → **Plane 4 Controller** (write/admit gate envelope).
- `AgentBlueprint` (§3) → **Plane 3 Assembly** (it IS the symbolic routing language for an agent identity).
- `Variant Ladder` dispatch (§10) → **Plane 3 Assembly** (tool-dispatch routing).
- Skills + Loop Profiles (§13.8) → **Plane 3 Assembly** (compose tool calls + provider dispatches into a symbolic routing structure).

**Every plane has a plane-specific kernel and plane-specific theorem.** The 5 × T1-T44 theorem set per `helios v6.2.md` §1.3 partitions theorems by plane; this section doesn't enumerate the theorems (that's V6.1/V6.2 doctrine substrate, beyond the Hermes 2.0 scope) but the partitioning is what lets future provenance work cite **(plane, theorem-id, claim-id)** as a triple instead of just **(claim-id)**.

**§5.0 reconciliation — what was actually missing.** The audit framed B2-M6 as "canonicalization deferred." Verification on disk showed:

- ✅ Enum exists with full doctrine comments — `epistemos-research/src/five_planes.rs:36-52` (5 variants · `serde(rename_all = "snake_case")` · `Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize`).
- ✅ Plane numbering is canonical — `RuntimePlane::plane_number(self) -> u32` returns 1..5.
- ✅ Load-bearing in `v6_1_stream_surface.rs` (`stream_surface(stream, plane) -> StreamSurfaceLevel` dispatches off `RuntimePlane`).
- ✅ Wired into `v6_1_execution_policy.rs` via `use crate::five_planes::ProductStream`.
- ❌ **Hermes 2.0 design doc did NOT mention `RuntimePlane`** — the canonical agent-architecture doctrine had no cross-link to the Five-Plane formalism, leaving the vocabulary unconnected from the runtime design.

This section closes that gap. The enum stays in `epistemos-research` (Lane 3 RESEARCH-ONLY, `--features research` build). Hermes 2.0 doctrine now references it so future provenance / governance / observability work has a stable plane-coordinate to cite.

**V1 / Pro / Post-V1 boundary:** Lane 3 RESEARCH-ONLY today — the enum exists but is not consumed by V1 shipping code paths. V1.x integration trigger: when ClaimLedger gains a per-claim `plane: RuntimePlane` field (currently single-plane assumption), or when the Provenance Console UI surfaces plane-coordinate filters. Until then, this section is doctrine alignment.

**Cross-links:**
- `epistemos-research/src/five_planes.rs` — enum source.
- `epistemos-research/src/v6_1_stream_surface.rs:142-157` — `ALL_FIFTEEN_CELLS` 5×3 matrix.
- `epistemos-research/src/v6_1_execution_policy.rs` — `ProductStream` companion.
- B2-M6 PASS 2 audit row.
- §5.1 ExecutionReceipt — Plane 5 Verification member.
- §10 Variant Ladder — Plane 3 Assembly member.
- §13.8 Loop Profiles (B2-M1) — Plane 3 Assembly member.
- MASTER_FUSION §3.16 Helios kernels — sibling V6.1/V6.2 substrate row.
- MASTER_FUSION §3.18 Provenance ledger (Phase 1) — Plane 5 substrate.
- `docs/audits/HELIOS_SUBSTRATE_INVENTORY_2026_05_12.md` — drift-discovery context (drift gate commit `9e19bcf08` 2026-05-12).

### 5.4 Intent → Effect dispatch + Applier subsystem — SHIPPED (B2-M10)

**Source:** PASS 2 audit row B2-M10 framed this subsystem as living in `docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/effect/`. **§5.0 reconciliation finding: the entire 6-file subsystem is already in main at `agent_core/src/effect/`**, registered at `agent_core/src/lib.rs:19` (`pub mod effect;`). Audit was stale — this section records the doctrine retroactively.

### The architecture in one sentence

User intent flows through the agent loop → emitted as a typed `Intent` → routed by `IntentDispatcher` to the correct typed `Applier` → produces a typed `Effect` (success) + `PriorState` (for reversal) **or** a typed `ApplyError` (failure surface for the heal loop) → wrapped in a signed `ExecutionReceipt` (§5.1) → returned up the agent loop.

### The 6 files in main (722 LOC total)

| File | LOC | Role |
|---|---|---|
| `agent_core/src/effect/mod.rs` | 161 | Module entry · `Effect` enum (8 variants) · `PriorState` (2) · `Inverse` (8 variants + `is_reversible()`) · `ApplyError` (typed failure surface) · `Capability` re-export |
| `agent_core/src/effect/dispatcher.rs` | 83 | `IntentDispatcher` — routes `Intent` → typed Applier; the central seam |
| `agent_core/src/effect/concept_applier.rs` | 86 | `ConceptGraphApplier` — concept graph mutations (create/alias/retract) |
| `agent_core/src/effect/memory_applier.rs` | 82 | `MemoryApplier` — soul/session persistence; produces `MemoryWrote` |
| `agent_core/src/effect/vault_applier.rs` | 138 | `VaultIntentApplier` — file I/O on the vault (write/move/delete with shadow) |
| `agent_core/src/effect/receipt.rs` | 172 | `ExecutionReceipt` + `Capability` + `HmacSha256SigningKey` (§5.1's per-tool-call attestation lives here) |

### Effect taxonomy — 8 success variants

```rust
pub enum Effect {
    VaultWrote   { path, body_sha256, bytes_written },  // file create or overwrite
    VaultMoved   { from, to },
    VaultDeleted { path, shadow_path },                 // soft-delete with shadow copy
    ConceptCreated  { canonical_name },
    ConceptAliased  { canonical_name, alias },
    MemoryWrote     { entry_id },
    NoopApplied  { reason },                            // intent was valid but redundant
    Aborted      { reason },                            // applier vetoed (capability / guard)
    Reversed     { /* metadata */ },                    // an Inverse was applied
}
```

### Reversal / Undo discipline — the Inverse pairing

Every `Effect` has a paired `Inverse` (or `Inverse::NotReversible`):

| Effect | Inverse |
|---|---|
| `VaultWrote` (new file) | `Inverse::DeleteVault { path }` |
| `VaultWrote` (overwrite — `PriorState::WroteOverExisting`) | `Inverse::RestoreVaultContent { path, body }` |
| `VaultMoved` | `Inverse::MoveVault { from: to, to: from }` (swap) |
| `VaultDeleted` | `Inverse::RestoreVaultFromShadow { path, shadow_path }` |
| `ConceptCreated` | `Inverse::RetractConcept { canonical_name }` |
| `ConceptAliased` | `Inverse::RemoveConceptAlias { canonical_name, alias }` |
| `MemoryWrote` | `Inverse::TombstoneMemory { entry_id }` |
| `NoopApplied` / `Aborted` / `Reversed` | `Inverse::NotReversible` |

`Inverse::is_reversible()` predicate distinguishes "can be undone" from "must be re-derived." This is the **Undo backbone** for B-3 Confidence Meter's biometric re-learn path (V1.1 deferred) and for the V1.1 H-3 `edit_note_block` macaroon's per-edit ledger row.

### Typed failure surface — feeds the heal loop

```rust
pub enum ApplyError {
    InvalidIntent(String),            // schema-rejected before dispatch
    IoError(String),
    PermissionDenied(String),         // capability / SovereignGate gate
    Conflict(String),                 // optimistic-concurrency / version skew
    BreakerOpen,                      // ← B2-M9 cross-reference: variant's circuit breaker tripped
    PermanentFailure(String),
    // ... see effect/mod.rs for full set
}
```

The `ApplyError::BreakerOpen` variant is exactly the link to **B2-M9 Pre-Flight Health Check Gate (VARIANT_LADDER §12)**. When a CircuitBreaker is `Open`, `IntentDispatcher` short-circuits to `BreakerOpen` rather than calling the Applier; the heal loop then walks to the next variant per §12.2 dispatch pseudocode.

### Mapping into the Five-Plane formalism (§5.3)

Per §5.3 plane assignments — each Applier lives on a specific plane:

| Applier | Plane |
|---|---|
| `VaultIntentApplier` | **Plane 4 Controller** (write/forget/admit gates; vault is the canonical write target) |
| `ConceptGraphApplier` | **Plane 4 Controller** (graph mutation gates) — feeds Plane 2 Episodic for exact recall after |
| `MemoryApplier` | **Plane 4 Controller** (write-side) feeding **Plane 1 State** (the recurrent semantic spine) and **Plane 2 Episodic** (recall pages) |
| `ExecutionReceipt` (in `receipt.rs`) | **Plane 5 Verification** (per-tool-call attestation; same as §5.1) |

The Applier types are the canonical citizens of Plane 4 — they are how the runtime mutates state under SCOPE-Rex governance.

### §5.0 reconciliation — what the audit row got wrong

| Audit claim | Verification |
|---|---|
| "Source: `docs/fusion/salvage/from-vigorous-goldberg/agent_core_src/effect/` (2145 LOC across 6 files)" | The 6 files are in MAIN at `agent_core/src/effect/`, 722 LOC, registered at `agent_core/src/lib.rs:19`. The salvage citation is the ORIGIN, not the current location. Audit's "2145 LOC" likely counts salvage-version annotations that didn't survive the main-merge curation. |
| "Dispatcher routes Effect → typed Applier" | Confirmed: `IntentDispatcher` in `effect/dispatcher.rs`. |
| "ConceptApplier / MemoryApplier / VaultApplier" | Confirmed: `ConceptGraphApplier` (concept_applier.rs:86) · `MemoryApplier` (memory_applier.rs:82) · `VaultIntentApplier` (vault_applier.rs:138). |
| "Receipt-based" | Confirmed: `ExecutionReceipt` from receipt.rs:172 (same primitive as §5.1). |
| "Typed failure surface feeding heal loop" | Confirmed: `ApplyError` enum with `InvalidIntent / IoError / PermissionDenied / Conflict / BreakerOpen / PermanentFailure` variants. |
| Destination "MASTER_FUSION §2.x OR new doc INTENT_EFFECT_APPLIER_ARCHITECTURE.md" | Doctrine row lives in Hermes 2.0 §5.4 (this section). New standalone architecture doc not required — the typed surface is small enough to live in the agent-architecture canon. |

**Why this is a §5.0 catch:** the audit predicted a salvage-resident missing subsystem; verification first showed the entire substrate is wired in main with module registration, public re-exports, and tight integration into the §5.1 ExecutionReceipt path AND the §12 CircuitBreaker doctrine just landed. The audit row was framed as if the salvage location was the canonical home. Doctrine row now records main's actual state retroactively.

### V1 / Pro / Post-V1 boundary

- **MAS V1:** Effect subsystem is ALREADY SHIPPED. Vault + Concept + Memory Appliers all consumed by the agent runtime. No additional V1 work.
- **V1.1:** The Reversal/Undo path (via `Inverse` + `is_reversible()`) is the substrate for B-3 Confidence Meter's re-learn-on-low-confidence path and for the V1.1 `edit_note_block` macaroon's per-edit Undo row (H-3 / B2-H6).
- **Pro V1.x:** Additional Applier types may be added (e.g. `ScreenCaptureApplier` for ScreenCaptureKit mutations · `AXApplier` for AXorcist mutations). All inherit the same `IntentDispatcher → Applier → Effect/Inverse/ApplyError` contract.

### Cross-references

- B2-M10 PASS 2 audit row.
- `agent_core/src/effect/{mod,dispatcher,concept_applier,memory_applier,vault_applier,receipt}.rs` — the 6 files (722 LOC).
- `agent_core/src/lib.rs:19` — `pub mod effect;` registration.
- §5.1 ExecutionReceipt — `receipt.rs` is shared between §5.1 and this section.
- §5.3 Five-Plane formalism — Applier plane assignments (Plane 4 Controller primary).
- VARIANT_LADDER §12 Pre-Flight HealthCheck Gate (B2-M9) — `ApplyError::BreakerOpen` is the cross-link surface.
- MAS_COMPLETE_FUSION §10 B-3 Confidence Meter — V1.1 consumer of the `Inverse` Undo backbone.
- MAS_COMPLETE_FUSION §10 H-3 / B2-H6 EditPage macaroon — V1.1 consumer using `VaultIntentApplier` write path.

---

## 6. MAS vs Pro split — the clearest line in the design

Per `MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md` + Apple App Review Guideline 2.5.2:

| Capability | MAS | Pro | Tunnel (B2-H18) | Why |
|---|---|---|---|---|
| Anthropic Messages API | ✅ | ✅ | — | HTTPS only |
| OpenAI Responses API | ✅ | ✅ | — | HTTPS only |
| OpenAI-compatible localhost (Ollama, LM Studio) | ✅ | ✅ | — | localhost HTTPS; user controls server |
| Local MLX in-process | ✅ | ✅ | — | no subprocess; in-app inference |
| MCP client URL/SSE (user-approved) | ✅ | ✅ | **B.1** | HTTP/SSE transport; gateway-friendly; gated by SovereignGate consent |
| Native Epistemos tools (note.*, graph.*, …) | ✅ | ✅ | — | in-app, schema-bound |
| Claude Code CLI subprocess | ❌ | ✅ | **C** | spawns `claude` binary |
| Codex CLI subprocess | ❌ | ✅ | **C** | spawns `codex` binary |
| Goose CLI subprocess | ❌ | ✅ | **C** | spawns `goose` binary |
| Aider subprocess | ❌ | ✅ | **C** | spawns `aider` binary |
| OpenHands local server | ❌ | ✅ | **C** | spawns Python server |
| SWE-agent / mini-SWE | ❌ | ✅ | **C** | subprocess + Docker risk |
| Arbitrary shell tool | ❌ | ✅ | **A** | bash_execute Pro-only |
| MCP client stdio (subprocess) | ❌ | ✅ | **B.2** | spawns user-installed MCP server binary |
| Browser automation | ❌ | ✅ | — | computer-use Pro-only (AX + ScreenCaptureKit) |
| iMessage outbound channel | ❌ | ✅ | — | osascript Pro-only |
| Web search (HTTP) | ✅ | ✅ | — | HTTPS; cited in approval card |
| File system writes outside vault | ❌ | ✅ | — | sandbox forbids on MAS |

CI gate stays: `strings` + `nm -gU` on the MAS bundle must return zero matches for the Pro-only allowlist (`bash_execute`, `cli_passthrough`, `osascript`, etc.).

### 6.1 The 4-Tunnel taxonomy (B2-H18)

**Source:** `docs/capability-tunnels.md` (219 lines, canonical in main). PASS 2 audit row B2-H18 surfaced that the table above flattened the Pro-tier surface into individual rows without the **organizing taxonomy** that explains why exactly those Pro features exist. The 4-Tunnel framing answers the reviewer-equivalent question: "why these 4 Pro features instead of a different 4?"

| Tunnel | Transport | What it carries | MAS-shippable? |
|---|---|---|---|
| **Tunnel A** — Universal shell | local subprocess (bash) | `bash_execute` arbitrary commands with scoped + per-command approval | ❌ Pro-only — hardened-runtime + sandbox forbid arbitrary shell |
| **Tunnel B.1** — URL MCP | HTTP / SSE | MCP server endpoints reachable via URL; gateway-friendly | ✅ MAS — HTTPS-only is App-Store-clean under §0 rule 6 |
| **Tunnel B.2** — stdio MCP | local subprocess (MCP binary) | user-installed MCP servers that speak stdio rather than HTTP/SSE | ❌ Pro-only — subprocess transport (per CLAUDE.md NO SIDECAR carve-out: user-installed MCP servers are allowed in Pro, never in MAS) |
| **Tunnel C** — CLI passthrough | local subprocess (CLI binary) | Claude Code · Codex · Goose · Aider · OpenHands · SWE-agent etc. | ❌ Pro-only — each spawns a vendor CLI |

**The orthogonality claim** (per `capability-tunnels.md` §"Combining tunnels"): the four tunnels are **independent capability axes**, not a single ordered list. A Pro user might enable Tunnel A + Tunnel B.1 but not Tunnel C; another might enable Tunnel C + Tunnel B.2 but not Tunnel A. The Pro entitlement isn't a single switch — it's 4 independent switches, each with its own gate / tier / approval discipline per `capability-tunnels.md` §"Gates, tiers, approval".

**Why Tunnel B.1 is the only MAS-shippable tunnel:** all transport is HTTP/SSE over `URLSession`, which is exactly what §0 rule 6 + `Epistemos-AppStore.entitlements`'s `com.apple.security.network.client = true` already permits. No subprocess, no JS runtime, no JIT-execution surface beyond the existing MLX shader compilation defended in §0 rule 7. The other three tunnels carry subprocess execution and are gated to Pro by the MAS sandbox + hardened runtime constraints.

**Reviewer answer** (citable verbatim): "The Pro tier adds 4 orthogonal capability axes (Tunnel A shell · Tunnel B.2 stdio-MCP · Tunnel C CLI passthrough · plus computer-use / channel automation). MAS keeps only Tunnel B.1 URL-MCP — all other Pro capabilities require subprocess execution that Apple's hardened-runtime + App Sandbox constraints forbid for App Store apps."

### Cross-references (§6 + §6.1)

- `docs/capability-tunnels.md` — canonical 219-line source with §"Gates, tiers, approval" + §"What each tunnel is NOT" + §"Combining tunnels".
- B2-H18 PASS 2 audit row.
- §0 rule 6 — MAS uses URL-fetch + WKWebView only; no in-process JS runtime (Tunnel B.1 is the only fully-HTTP tunnel and therefore MAS-clean).
- §0 rule 7 — JIT entitlement defense (Tunnel A / B.2 / C all require Hardened Runtime relaxations that stay Pro-only).
- §7.4 Specialties registry — the 19 macOS-only capabilities consumed by these tunnels.
- `MAS_COMPLETE_FUSION §Phase D` Wave F XPC Mastery — Pro-tier XPC services that host the subprocess-bearing tunnels.

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

### 7.4.1 Provider Wire-Contract Registry Notes

| Provider surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Gemini (`gemini_flash`, `gemini_pro`) | HTTPS `streamGenerateContent` through `GeminiProvider` | ✅ MAS + Pro — URLSession/reqwest HTTPS only, no subprocess | D.2.1 reconciled current Gemini 2.5 API contract on 2026-05-16: `gemini-2.5-flash` / `gemini-2.5-pro`, `https://generativelanguage.googleapis.com/v1beta/models`, `x-goog-api-key` API-key header or Google OAuth bearer, function declarations, `thinkingConfig.includeThoughts` → streamed `thought: true` parts → `ThinkingDelta`. Full provider ledger: `docs/providers/gemini.md`. |
| Kimi / Moonshot (`kimi`, `kimi_latest`, `kimi_k2`, `kimi_thinking`) | HTTPS Chat Completions through `OpenAICompatibleProvider` | ✅ MAS + Pro — URLSession/reqwest HTTPS only, no subprocess | D.2.2 wired current Kimi API contract on 2026-05-16: `kimi-k2.6` default, `https://api.moonshot.ai/v1`, `MOONSHOT_API_KEY`, OpenAI-compatible tools, `reasoning_content` → `ThinkingDelta`. Full provider ledger: `docs/providers/kimi.md`. |
| Codestral (`codestral`, `codestral_latest`) | HTTPS Chat Completions through `OpenAICompatibleProvider` | ✅ MAS + Pro — URLSession/reqwest HTTPS only, no subprocess | D.2.5 wired current Codestral contract on 2026-05-16: `codestral-latest` on `https://codestral.mistral.ai/v1`, `CODESTRAL_API_KEY` with `MISTRAL_API_KEY` fallback, OpenAI-compatible tools, no provider-specific thinking extension. Full provider ledger: `docs/providers/codestral.md`. |
| OpenRouter (`openrouter`, arbitrary `provider/model` slugs) | HTTPS Chat Completions through `OpenAICompatibleProvider` | ✅ MAS + Pro — URLSession/reqwest HTTPS only, no subprocess | D.2.6 reconciled current OpenRouter gateway contract on 2026-05-16: `https://openrouter.ai/api/v1`, `OPENROUTER_API_KEY`, OpenAI-compatible tools, `HTTP-Referer` + `X-OpenRouter-Title` attribution headers, OpenRouter `reasoning` request object from `AgentConfig`, and plaintext `delta.reasoning` / `delta.reasoning_content` → `ThinkingDelta`. Full provider ledger: `docs/providers/openrouter.md`. |
| xAI Grok (`xai`, `grok`, `grok_latest`, `grok-4.3`) | HTTPS Chat Completions through `OpenAICompatibleProvider` | ✅ MAS + Pro — URLSession/reqwest HTTPS only, no subprocess | D.2.3 reconciled current xAI contract on 2026-05-16: `https://api.x.ai/v1`, `XAI_API_KEY`, `grok-4.3` default, 1M context, OpenAI-compatible tools, and `delta.reasoning_content` → `ThinkingDelta`. Queue wording named Grok-2/Grok-3, but official xAI docs retired `grok-3` on 2026-05-15 12:00 PM PT and redirect deprecated text slugs to `grok-4.3`; Epistemos pins the explicit current model. Full provider ledger: `docs/providers/grok.md`. |
| Together AI (`together`, `together_latest`) | HTTPS Chat Completions through `OpenAICompatibleProvider` | ✅ MAS + Pro — URLSession/reqwest HTTPS only, no subprocess | D.2.7 reconciled current Together OpenAI-compatible contract on 2026-05-16: `https://api.together.ai/v1`, `TOGETHER_API_KEY`, `meta-llama/Llama-3.3-70B-Instruct-Turbo` default at 131,072 context tokens, OpenAI-compatible tools, and Together reasoning-model `delta.reasoning` → `ThinkingDelta`. Full provider ledger: `docs/providers/together.md`. |

### 7.4.2 Tunnel C CLI Passthrough Receipt Contract

| CLI surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Claude Code / Codex / Gemini / Kimi CLI (`claude_code`, `codex`, `gemini`, `kimi`) | Tunnel C subprocess through `agent_core::tools::cli_passthrough` | ❌ Pro-only — subprocess transport behind `#[cfg(feature = "pro-build")]` | D.2.4 reconciled on 2026-05-16. The shared runner now applies `harden_cli_subprocess`, captures stdout/stderr through bounded async pipes (`10 MiB` per stream), kills on timeout, and returns a JSON receipt for every completion: `tool`, `binary`, `success`, `exit_code`, `stdout`, `stderr`, `stdout_truncated`, `stderr_truncated`, `mode = "cli_passthrough"`. Nonzero exits are returned as receipts rather than hidden in free-form text. |
| Goose CLI (`goose`) | Tunnel C subprocess through `agent_core::tools::cli_passthrough` | ❌ Pro-only — subprocess transport behind `#[cfg(feature = "pro-build")]` | D.4 wired on 2026-05-16. The wrapper invokes Goose's official headless task path (`goose run --no-session -t <task>`), can pass provider/model overrides and built-in extensions, requests `--output-format json` by default, and preserves the shared `harden_cli_subprocess` runner and JSON receipt shape. Sources: `https://goose-docs.ai/docs/guides/running-tasks/`, `https://goose-docs.ai/docs/getting-started/installation/`. |
| Aider CLI (`aider`) | Tunnel C subprocess through `agent_core::tools::cli_passthrough` | ❌ Pro-only — subprocess transport behind `#[cfg(feature = "pro-build")]` | D.4 wired on 2026-05-16. The wrapper invokes Aider's official single-message scripting mode (`aider --message <task>`), preserves the shared `harden_cli_subprocess` runner and JSON receipt shape, defaults to `--yes-always` for non-interactive execution, and defaults to `--no-auto-commits --no-dirty-commits` so Epistemos keeps explicit host commit discipline. Sources: `https://aider.chat/docs/scripting.html`, `https://aider.chat/docs/config/options.html`, `https://aider.chat/docs/install.html`. |
| OpenHands CLI (`openhands`) | Tunnel C subprocess through `agent_core::tools::cli_passthrough` | ❌ Pro-only — subprocess transport behind `#[cfg(feature = "pro-build")]` | D.4 wired on 2026-05-16. The wrapper invokes OpenHands' official headless automation path (`openhands --headless --json -t <task>`), preserves the shared `harden_cli_subprocess` runner and JSON receipt shape, and keeps OpenHands credentials/config in OpenHands' own local config rather than inherited environment variables. Sources: `https://docs.openhands.dev/openhands/usage/cli/headless`, `https://docs.openhands.dev/openhands/usage/cli/command-reference`, `https://github.com/OpenHands/OpenHands-CLI/blob/main/README.md`. |
| mini-SWE-agent CLI (`mini_swe_agent`) | Tunnel C subprocess through `agent_core::tools::cli_passthrough` | ❌ Pro-only — subprocess transport behind `#[cfg(feature = "pro-build")]` | D.4 wired on 2026-05-16. The wrapper invokes mini-SWE-agent's current local CLI (`mini --yolo --task <task>` by default), can pass model/config overrides, preserves the shared `harden_cli_subprocess` runner and JSON receipt shape, and keeps mini-SWE-agent credentials/config in its own local configuration rather than inherited provider API-key environment variables. Sources: `https://mini-swe-agent.com/latest/usage/mini/`, `https://mini-swe-agent.com/latest/quickstart/`, `https://swe-agent.com/latest/usage/cli/`. |

### 7.4.3 Tunnel B.2 stdio MCP Gate

| MCP surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| User-installed stdio MCP servers (`agent_core::mcp::client` + `agent_core::tools::stdio_mcp`) | Tunnel B.2 subprocess through `tokio::process::Command` | ❌ Pro-only — local subprocess transport behind `#[cfg(feature = "pro-build")]` | D.1.2 reconciled on 2026-05-16. The MAS-clean `agent_core::mcp::url_servers` module remains always compiled for Tunnel B.1 URL MCP discovery. The stdio client module is now exported only in `pro-build`, matching the already Pro-gated `stdio_mcp` tool registry path. Source-guard: `mcp::tests::stdio_mcp_client_module_is_pro_gated`. |

### 7.4.4 D.3 Git MCP Read-Only Contract

| MCP surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Git repository inspection (`git.status`, `git.diff`, `git.log`) | Local Git subprocess through `omega-mcp::git` | ❌ Pro-only — `omega-mcp` compiles the executor out under `mas-sandbox` | D.3 wired on 2026-05-16. The executor validates `repo_root` as an existing Git worktree, runs `/usr/bin/git -C <repo> --no-pager`, exposes no mutating verbs, rejects absolute/traversing/option-like diff pathspecs, clamps retained stdout/stderr to 1 MiB, and uses the shared omega subprocess hardener that scrubs provider API keys before child launch. UniFFI entry point: `execute_git_tool(repo_root, tool_name, args_json)`. |

### 7.4.5 D.3 GitHub MCP Read-Only Contract

| MCP surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| GitHub repository inspection (`github.repo`, `github.issues`, `github.pulls`, `github.releases`) | HTTPS GET requests through `omega-mcp::github` to GitHub REST | ✅ MAS-compatible transport — no subprocess; Swift MAS allow-list surfacing remains Terminal A scope | D.3 wired on 2026-05-16. The executor validates owner/repo slugs before URL construction, rejects credentials in tool arguments, uses `GITHUB_TOKEN`/`GH_TOKEN` only when the host injects them, sets GitHub's versioned REST headers, exposes only GET endpoints, filters pull requests out of `github.issues`, normalizes issue/PR/release/repo output, and returns JSON `ToolResult` receipts through UniFFI entry point `execute_github_tool(tool_name, args_json)`. Source docs: GitHub REST `GET /repos/{owner}/{repo}`, `GET /repos/{owner}/{repo}/issues`, `GET /repos/{owner}/{repo}/pulls`, and `GET /repos/{owner}/{repo}/releases`. |

### 7.4.6 D.3 Memory MCP Schema Contract

| MCP surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Vault-scoped memory store (`memory.put`, `memory.get`, `memory.search`, `memory.list`) | Local filesystem inside the selected vault via `omega-mcp::memory` | ✅ MAS-compatible local vault I/O — no subprocess, no network | D.3 wired on 2026-05-16. The executor stores JSONL under `<vault>/.epistemos/memory/`, accepts only the four canonical schema revs (`epistemos.soul.v1`, `epistemos.skill.v1`, `epistemos.episode.v1`, `epistemos.semantic.v1`), validates required keys, rejects unknown top-level fields, enforces 12-char lowercase ids, caps records at 256 KiB, and keeps episode/semantic payloads append-only. This is a schema-guarded MCP persistence surface; full Rust schema mirrors and `MutationEnvelope` call-site validation remain in `agent_core/src/schemas/mod.rs` + `agent_core/src/mutations/`. UniFFI entry point: `execute_memory_tool(vault_root, tool_name, args_json)`. Source schemas: `agent_core/schemas/epistemos.*.v1.schema.json`. |

### 7.4.7 D.3 Filesystem MCP Canonical-Name Contract

| MCP surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Vault-scoped filesystem tools (`file.read`, `file.write`, `file.list`, `file.search`) | Local filesystem inside the selected vault via `omega-mcp::vault` | ✅ MAS-compatible local vault I/O — no subprocess, no network | D.3 reconciled on 2026-05-16. §5.0 found the vault executor already handled read/write/list/search under legacy and vault aliases, but the MCP catalog did not advertise canonical dotted file tools and `file.search` was not accepted by `execute_vault_tool`. The catalog now exposes `file.read`, `file.write`, `file.list`, and `file.search`; legacy names remain for archived callers; the executor routes `file.search` through the existing mmap-backed vault markdown search. Safety boundary remains vault-root scoping with traversal rejection and hidden-directory exclusion during recursive search. |

### 7.4.8 D.3 Web Search MCP Contract

| MCP surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Web search (`web.search`) | HTTPS GET through `omega-mcp::web_search` to Brave Search or Kagi Search | ✅ MAS-compatible transport — no subprocess; user approval and Swift allow-list surfacing remain host policy | D.3 reconciled on 2026-05-16. Queue wording named Bing/Brave/Kagi, but Bing Search APIs retired on 2025-08-11, so this slice wires only current official backends: Brave `https://api.search.brave.com/res/v1/web/search` with `X-Subscription-Token`, and Kagi `https://kagi.com/api/v0/search` with `Authorization: Bot`. `execute_web_search_tool(tool_name, args_json)` rejects credentials in tool arguments, requires explicit `provider`/`WEB_SEARCH_PROVIDER` when both backends are configured, clamps query/filter/limit inputs, normalizes provider results to `title`, `url`, `snippet`, `published`, and returns a JSON `ToolResult` receipt. |

### 7.4.9 D Self-Audit: Mixture-of-Minds Gemini Direct Call

| Tool surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| `intelligence.mixture_of_minds` Gemini contributor (`agent_core::tools::intelligence::ask_gemini`) | HTTPS `generateContent` direct call to Google Gemini | ✅ MAS-compatible transport, but Pro/tool-policy gated as `intelligence.mixture_of_minds` | D self-audit reconciled on 2026-05-16. §5.0 found the primary `GeminiProvider` correctly wired to Gemini 2.5 with header-based auth, while the D4 cloud ensemble helper still called retired `gemini-1.5-pro` and placed the API key in the URL query. The helper now uses `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent` and sends the key via `x-goog-api-key`. Source guard: `tools::intelligence::tests::mixture_gemini_uses_current_endpoint_without_url_key` under `pro-build`. |

### 7.4.10 D Self-Audit: Legacy Provider Source Comments

| Provider surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Claude, OpenAI, and Perplexity first-party provider modules | HTTPS provider adapters in `agent_core/src/providers/{claude,openai,perplexity}.rs` | ✅ MAS + Pro — reqwest HTTPS only, no subprocess | D self-audit reconciled on 2026-05-16. §5.0 found the newer provider modules already started with required `//! Source:` comments, but legacy Claude/OpenAI/Perplexity modules did not. The modules now start with official API source comments for Anthropic Messages/tool-use/extended-thinking, OpenAI Responses/function-calling/reasoning/streaming, and Perplexity Sonar chat completions. Source guards: `module_starts_with_official_source_comments` in each provider test module. |

### 7.4.11 D Self-Audit: Terminal Shell Subprocess Hardening

| Tool surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| `terminal` / `shell.run_approved` foreground and background shell execution | Tunnel A subprocess through `agent_core/src/tools/terminal.rs` | ❌ Pro-only — shell subprocess behind `#[cfg(feature = "pro-build")]` | D self-audit reconciled on 2026-05-16. §5.0 sampled D-owned subprocess surfaces and found `terminal.rs` still used a private env sanitizer around `sh -lc` instead of the canonical `agent_core::security::harden_cli_subprocess` helper used by Tunnel C. `build_command` now calls the shared hardener before spawn, so foreground and background terminal commands inherit only the canonical subprocess allow-list, keep provider secrets out of child env, and preserve the shared `kill_on_drop` / process-group behavior. Source guard: `tools::terminal::tests::terminal_uses_canonical_subprocess_allowlist` under `pro-build`. |

### 7.4.12 D Self-Audit: Gemini Pro Thinking-Budget Drift

| Provider surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Gemini 2.5 request generation (`agent_core/src/providers/gemini.rs`) | HTTPS `streamGenerateContent` through `GeminiProvider` | ✅ MAS + Pro — reqwest HTTPS only, no subprocess | D self-audit reconciled on 2026-05-16 after sampling D.2 provider commits. Current Google Gemini docs say 2.5 Flash can disable thinking with `thinkingBudget: 0`, while 2.5 Pro cannot disable thinking with a zero budget. `gemini_request_body_for_model` is now model-aware: Flash no-thinking turns send `thinkingBudget: 0`; Pro no-thinking turns omit `thinkingConfig`; enabled thinking still sends `includeThoughts = true` so streamed `thought: true` parts map to `ThinkingDelta`. Source guard: `providers::gemini::tests::pro_no_thinking_turns_omit_zero_budget_because_pro_cannot_disable_thinking`. |

### 7.4.13 D Self-Audit: Kimi OpenAI-Compatible Source Prologue

| Provider surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| Kimi / Moonshot factory path (`agent_core/src/providers/openai_compatible.rs`) | HTTPS Chat Completions through `OpenAICompatibleProvider` | ✅ MAS + Pro — reqwest HTTPS only, no subprocess | D self-audit reconciled on 2026-05-16 after sampling the D.2 Kimi provider commit. §5.0 found the implementation and `docs/providers/kimi.md` used the current Moonshot contract, but the module-level `//! Source:` prologue only listed other OpenAI-compatible providers while Kimi source URLs lived beside the constructor. The prologue now includes Kimi API overview, model list, and K2.6 quickstart official sources so source-comment drift is fail-loud at module scope. Source guard: `providers::openai_compatible::tests::module_prologue_includes_moonshot_source_comments`. |

### 7.4.14 D Self-Audit: omega-mcp Subprocess Secret Denylist

| MCP surface | Tunnel / transport | MAS-shippable? | Contract note |
|---|---|---|---|
| `omega-mcp` subprocess helper (`omega-mcp/src/subprocess.rs`) | Local subprocess wrapper used by omega MCP executors such as read-only Git MCP | ❌ Pro-only for subprocess-backed executors; `mas-sandbox` excludes the executor path | D self-audit reconciled on 2026-05-16. §5.0 sampled D-owned subprocess hardening and found omega's private denylist lagged behind `agent_core::security` provider aliases. The hardener now explicitly blocks auth-mode and alternate provider-secret env vars including `OPENAI_AUTH_MODE`, `OPENAI_CLIENT_VERSION`, `ANTHROPIC_AUTH_MODE`, `GOOGLE_AUTH_MODE`, `GOOGLE_PROJECT_ID`, `GLM_API_KEY`, `KIMI_API_KEY`, `DEEPSEEK_API_KEY`, `MINIMAX_API_KEY`, and `GROQ_API_KEY`, in addition to the previously covered keys. Source guard: `subprocess::tests::denylist_contains_agent_core_provider_secret_aliases` in `omega-mcp`. |

### 7.5 Capability Lease + handle-based data sharing (Pro-only zero-copy plane)

**Scope gate:** Pro-tier only per **IR-1** (Immutable rules, top of doc). MAS V1 is in-process via Rust FFI; XPC is a Pro V1.x evaluation. This section is design doctrine for **if/when** Hermes lands as an embedded XPC service — it does not ship in MAS, ever, in current form.

**Source:** `docs/fusion/jordan's research/hermes.md` §"zero-copy inside the local data plane" + PASS 2 gap audit B2-H10. Apple Developer reference: `https://developer.apple.com/documentation/xpc/creating-xpc-services` (modern doc preferred over the archived 2016 BPSystemStartup guide per audit-of-audit #1 note).

**Doctrine — "Pass handles, not payloads."** The XPC control plane carries tiny typed messages (task IDs · provider selections · capability leases · offsets · hashes · patch envelopes). The data plane never moves bytes through the XPC mailbox; it passes **handles** that the Hermes service dereferences locally via the four primitives below.

**Four handle primitives:**

| Handle | Purpose | Backing store | Lifecycle |
|---|---|---|---|
| **Blob ID in substrate** | Reference to a content-addressed blob in `epistemos-shadow` substrate (BLAKE3-prefixed). Reader fetches by ID. | `<vault>/.epcache/shadow/blobs/<hash>` | Immutable; eviction by Halo Shadow GC |
| **`xpc_shmem` region** | Ephemeral shared-memory region created with `xpc_shmem_create()` for one-turn payloads (e.g. agent-streamed tokens that must reach a UI consumer faster than IPC mailbox cycle). | Anonymous Mach VM, refcounted across processes | Until last refcount drops; auto-cleaned on Hermes service exit |
| **File descriptor (`xpc_fd_create`)** | Read-only access to an immutable on-disk artifact (e.g. a `.epdoc` manifest the agent needs to cite). | Existing filesystem inode | Hermes service `dup`s + closes on its own schedule |
| **Mmap offset** | Range-restricted view into an already-mmapped vault index segment (e.g. one Tantivy segment + offset/length). | `mmap()`-mapped vault region | Lives as long as the mapping; range enforced by capability check |

**Consent + lease model.** Epistemos owns the consent moment — when the user approves an action (vault read · file attach · cloud-send), the consent records a **`CapabilityLease`** that binds:
- the specific handle (blob ID / shmem region / fd / mmap offset)
- the specific scope (read-only / write / single-use / TTL)
- the specific recipient (Hermes service · which session · which turn)
- the specific revocation trigger (turn ends · session ends · user revokes · TTL expires)

Hermes gets **only the lease's narrowly-scoped access** for the active task — never the underlying vault path or the raw blob handle. When the lease expires, Hermes's access vanishes without Hermes having to cooperate.

**Integration with macaroon primitives.** The lease pattern composes with the existing macaroon infrastructure at `agent_core/src/cognitive_dag/macaroons.rs` + `dispatch.rs`. Per `agent_core/src/cognitive_dag/dispatch.rs:28-132`, the macaroon types (`issue` · `restrict` · `Caveat` · `Macaroon` · `system_mirror_macaroon` · `derive_mirror_macaroon`) already model capability narrowing with caveat composition. A `CapabilityLease` is an XPC-extended macaroon: the base macaroon carries the abstract capability (read · write · ttl), the lease binds it to a specific handle primitive at the XPC boundary.

```rust
// Sketch (Pro V1.x, not V1):
struct CapabilityLease {
    macaroon: Macaroon,        // existing primitive — carries Caveat chain
    handle: HandlePrimitive,   // one of the 4 above
    scope: LeaseScope,         // read_only / write / single_use / ttl
    expires_at: Option<Instant>,
    issued_to: HermesSessionId,
}

enum HandlePrimitive {
    BlobId { hash: Blake3Hash },
    ShmemRegion { name: String, byte_length: usize },
    FileDescriptor { fd: RawFd },
    MmapRange { base: *const u8, offset: usize, length: usize },
}
```

**Why this matters.** Without handle-based sharing, the only way an XPC-isolated Hermes can act on vault data is to copy the data through the XPC mailbox per call. For a 5K-note vault + agentic-loop chain-of-thought that re-reads 30 notes per turn, that's 30× the egress copy. Handles + leases keep the data plane zero-copy while keeping the control plane auditable.

**Boundaries:**
- This is the **Pro V1.x evaluation surface for IR-1.** MAS V1 in-process needs NO handle/lease primitive — every read is a direct `Arc<T>` deref.
- **NOT a SovereignGate replacement.** SovereignGate is the action-class biometric (per §B.3 of `MAS_COMPLETE_FUSION`); CapabilityLease is the per-handle XPC-boundary control. They compose: SovereignGate consent issues the macaroon → macaroon issues the lease → lease grants the handle → handle dereferences the payload.
- **NOT a `vault.search` replacement.** `vault.search` returns content; CapabilityLease returns access. The tool layer remains unchanged.

**Crosslinks:** IR-1 (Immutable rules — XPC vs in-process decision) · §7.1 (MAS-allowed tools — none of these touch handles) · §7.2 (Pro-additional tools — most could benefit from lease binding) · `agent_core/src/cognitive_dag/macaroons.rs` + `dispatch.rs` (existing macaroon primitives this composes with) · PASS 2 B2-H10 (this row) · `MAS_COMPLETE_FUSION §D` (XPC Mastery — distinct from this layer; `VaultXPC` + `CapabilityGrant` are their own services).

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

### 13.5.8 Spectral hallucination detection — Laplacian eigenvalues of attention maps

**Source:** PASS 2 gap audit B2-H7 + `docs/fusion/jordan's research/kimis deep research/ternary_spectral_architecture.converted.md` §3 · `EPISTEMOS_MASTER_ARCHITECTURE.md` Layer 2. External validation (audit-of-audit iter 10): **Bazarova et al., "Hallucination Detection in LLMs Using Spectral Features of Attention Maps"** — [arXiv:2502.17598](https://arxiv.org/abs/2502.17598), EMNLP 2025 (the **LapEigvals** method); later improved by **EigenTrack** [arXiv:2509.15735](https://arxiv.org/abs/2509.15735).

**The core observation.** Memories — and the attention maps that route over them — have coordinates on a latent manifold. Compute the **graph Laplacian** `L = D − W` of an attention map (treating the map as a weighted adjacency matrix) and look at its top-k eigenvalues. When the **spectral gap collapses** (top eigenvalues bunch together, no longer well-separated), information stops mixing properly through the attention heads — the model is producing tokens whose attention pattern looks degenerate. Empirically this correlates strongly with hallucination.

**The acceptance threshold.** LapEigvals on TriviaQA reaches **AUROC 88.9%** with top-k Laplacian eigenvalues of the attention map alone — no external retrieval, no second model. EigenTrack tightens the bound further by tracking eigenvalue *trajectories* across decode steps rather than a static snapshot. **Doctrine acceptance**: when this lands in Epistemos, the test suite pins AUROC ≥ 0.85 on a held-out trivia/factual subset as the regression floor.

**Operational integration shape** (Wave 9+ research-tier — does **NOT** ship in V1):

```
                         decode step t
            ┌────────────────────────────────────────────┐
            │  Hermes 2.0 §13.5 Instant Recall (B2-H3)   │
            │  ↓ Mamba-2 state prefilled from top-3 hits │
            └────────────────────────────────────────────┘
                                ↓
            ┌────────────────────────────────────────────┐
            │  Attention map A_t  (per layer, per head)  │
            └────────────────────────────────────────────┘
                                ↓
            ┌────────────────────────────────────────────┐
            │  L_t = D − W   (graph Laplacian of A_t)    │
            │  λ_1, λ_2, …, λ_k  (top-k eigenvalues)     │
            └────────────────────────────────────────────┘
                                ↓
            ┌────────────────────────────────────────────┐
            │  spectral_gap = λ_2 − λ_1                  │
            │  if spectral_gap < THRESHOLD → flag turn   │
            │     as low-confidence; route to B-3        │
            │     Confidence Meter; consider re-prefill  │
            │     state from a different vault subset    │
            └────────────────────────────────────────────┘
```

**Integration with already-shipped pieces:**
- **B2-H3 §13.5.7 Instant Recall** provides the Mamba state whose attention spectrum gets monitored. The spectral check is what *closes the loop* on the "is the prefilled state actually helping?" question.
- **B-3 Confidence Meter** (the simple-form `ConfidenceBadge` shipping in V1 per `MAS_COMPLETE_FUSION §10`) is the natural consumer. When the spectral gap collapses, the confidence score that backs the badge drops below 70% and the V1.1 biometric-gated re-learn fires.
- **`ClaimLedger`** (provenance) records the spectral metric per turn so post-hoc audits can correlate spectral collapse with downstream retraction.

**Why this is research-tier, not V1:**
- Requires per-decode-step access to raw attention maps. Anthropic / OpenAI APIs don't expose these. Only local MLX models (Qwen 3.5 / Phi-4 / Nemotron Nano) can provide them today.
- Even on local models, computing eigenvalues per step adds non-trivial latency unless we cache the Laplacian decomposition across steps.
- The 88.9% AUROC is on TriviaQA — needs validation on the user's actual vault domain before being a load-bearing gate.

**Scope explicitly NOT covered by this section:**
- The full Laplace-Beltrami manifold-learning frame (broader differential-geometry treatment from `EPISTEMOS_MASTER_ARCHITECTURE.md` Layer 2). That's a deeper research-tier doc; this section lands the operational technique only.
- Cross-attention vs self-attention monitoring strategy.
- Per-layer vs per-head aggregation (literature uses per-head means; EigenTrack picks per-layer trajectories).

**Crosslinks:** §13.5.3 (Contextual retrieval) · §13.5.7 (Per-model Knowledge Vaults — vault choice affects which attention map you monitor) · `MASTER_FUSION §3.34` (Instant Recall — the upstream that produces the attention map) · `MAS_COMPLETE_FUSION §10` B-3 row (Confidence Meter — downstream consumer of the spectral signal).

### 13.5.9 MLX Model Selection Matrix — per memory tier

**Source:** PASS 2 gap audit B2-H17 + `docs/_consolidated/google-research-pack-2026-03-18/00-google-master-prompt.md §B`. Pairs with §13.5.1 (task-class lineup) and §8.1 (hardware reality / `V6_2_HARDWARE_LOCK`).

§13.5.1 picked models by **task class** (coding agent · reasoning · quick sub-tasks · default chat · etc.). §8.1 pinned the **hardware reality** for the V1 target (M2 Pro 16GB unified memory). This sub-section is the **per-memory-tier matrix** — when the user has more RAM than the V1 target, which models become available and which strategy (always-hot vs on-demand load) applies.

**Three hardware tiers** (Apple Silicon RAM SKUs):

| Tier | RAM | Apple SKU examples | OS+UI budget | KV @ 32k | Model headroom |
|---|---|---|---|---|---|
| **T1 (V1 lock)** | 16-24 GB | M1 / M2 / M3 base · M2 Pro 16GB **(V1 lock)** | ~4 GB | ~1.5 GB | ~9-10 GB usable |
| **T2** | 32-48 GB | M-series Pro/Max mid-range | ~4 GB | ~1.5 GB | ~26-43 GB usable |
| **T3** | 64-128 GB | M-series Max/Ultra · Mac Studio · Mac Pro | ~6 GB | ~1.5-3 GB | ~56-119 GB usable |

**Per-tier model availability** (4-bit MLX quantization unless noted; disk footprint reported as headline-spec, actual on-disk may vary ±20% with tokenizer + safetensors metadata):

| Model | RAM @ 4-bit | Disk | T1 (16-24 GB) | T2 (32-48 GB) | T3 (64+ GB) | Strategy |
|---|---|---|---|---|---|---|
| LFM2 2.6B | ~1.5 GB | ~1.5 GB | ✅ always-hot | ✅ always-hot | ✅ always-hot | Speed-critical fallback |
| Gemma 4 4B | ~2.5 GB | ~2.5 GB | ✅ always-hot | ✅ always-hot | ✅ always-hot | Default chat |
| Phi-4-mini 3.8B (V2.x) | ~2.5 GB | ~2.5 GB | ✅ on-demand | ✅ always-hot | ✅ always-hot | Quick sub-tasks |
| Qwen 3.5 7B (V2.x) | ~5-6 GB | ~5 GB | ⚠️ on-demand only · evict-others | ✅ always-hot | ✅ always-hot | Coding primary |
| Nemotron Nano 4B (V2.x) | ~3-4 GB | ~3 GB | ✅ on-demand | ✅ always-hot | ✅ always-hot | Tiny QA / controller |
| Phi-4 14B (V2.x) | ~8 GB | ~8 GB | ❌ exceeds T1 budget | ✅ on-demand | ✅ always-hot | Reasoning |
| Qwen3-Coder 30B-A3B | ~9 GB | ~17 GB (MoE) | ❌ disk size + memory exceed T1 | ✅ on-demand | ✅ always-hot | Coding backup (grammar-bound) |
| Gemma 3 27B QAT | ~12 GB | ~14 GB | ❌ exceeds T1 budget | ⚠️ on-demand only · evict-others | ✅ always-hot | Long doc (1M ctx) |
| DeepSeek-R1-Distill 7B | ~5 GB | ~5 GB | ✅ on-demand | ✅ always-hot | ✅ always-hot | T1 substitute for Phi-4 14B reasoning |

**Strategy column legend:**
- **always-hot** = model stays resident in unified memory between calls. Sub-200ms first-token latency.
- **on-demand** = `MLXInferenceService.performLoad()` on first call · `performUnload()` after idle TTL (currently 4s @ 16GB / 6s @ 24GB / 10s @ 36GB / 15s @ 64GB+ per 2026-04-28 perf hardening). First call cold-loads; subsequent calls warm.
- **on-demand only · evict-others** = the model is large enough that loading it must evict every other resident model first. Suitable for batch / planning calls; not suitable for fast-turn chat.

**V1 scope.** V1 ships the T1 lineup only. The `LocalTextModelID` enum (per CLAUDE.md FILE MAP) currently exposes Qwen 3.6 35B-A3B Unsloth · Gemma 4 4B · Gemma 3 27B QAT · LFM2 2.6B (plus DeepSeek-R1-Distill 7B as the reasoning substitute). Phi-4 / Phi-4-mini / Qwen 3.5 7B / Nemotron Nano 4B land in V2.x per §13.5.1 action note.

**T2/T3 tiers in V1.** When a user runs Epistemos on a 32 GB+ or 64 GB+ Mac, the same `LocalTextModelID` enum is exposed; the `ConfidenceRouter` / `select_local_model` upgrades the routing decisions automatically because the available-headroom signal lets bigger models slot into always-hot. **No tier-specific UI surface ships in V1** — the matrix above is documentation, not a Settings → Hardware → Tier picker.

**Pro distribution implication.** Users with T2/T3 hardware are likely the Pro audience (paid distribution); the matrix justifies a Pro-only model catalog expansion as a value differentiator post-V1.

**Crosslinks:** §8.1 (hardware reality) · §8.2 (epistemos local brain routing) · §13.5.1 (refined model lineup by task class) · `CLAUDE.md` FILE MAP `LocalTextModelID` · `MASTER_FUSION §3.2` Residency Governor (the per-tier matrix is a residency-decision input — bigger headroom shifts the rate-distortion frontier).

### 13.5.10 Auto-research loops — vault-applied "wins applied / wins not applied / discoveries to investigate" daily report

**Source:** PASS 1 gap audit H-10 + `~/Documents/Epistemos-QuickCapture/LIVE_FILES_AND_SUBSTRATE_ADDENDUM.md §5` (Karpathy auto-research pattern). Pairs with PASS 1 M-2 Eidos Plus deliberation engine (queued for the same Hermes 2.0 §13.5 distillation block) and PASS 2 B2-M14 differential-privacy gate.

**The Karpathy pattern.** An auto-research agent runs continuously in the background reading new external research (papers · blog posts · changelogs · social signals from a trusted feed), evaluating each piece against the user's vault for relevance, and producing a **daily report** with three sections:

1. **Wins applied** — research findings that the agent automatically applied to the user's vault (writes to `instructions.md` per `§13.5.7 Per-model Knowledge Vaults`, edits to existing notes, new concept-index entries). Each win cites: source URL + agent confidence + vault delta (what changed) + rollback handle. **Auto-applied** because confidence ≥ doctrine threshold; user reviews the daily report and can reject any win via the Undo button (V1.1 per `B-3` Confidence Meter).
2. **Wins not applied** — research findings that scored above relevance threshold but below the auto-apply confidence threshold. Each is presented as a one-tap "apply" / "ignore" / "ask me more" choice. Drives the user's daily research-review habit.
3. **Discoveries to investigate** — research findings that scored relevant but raise questions the agent cannot resolve alone (e.g. "this paper contradicts your note from 2026-04-12 about X — which one is correct?"). Routed to the chat composer for an interactive resolution session.

**Integration shape** (post-V1, NightBrain-scheduled):

```
                NightBrain idle scheduler (Wave 8)
                          ↓
            cloud_knowledge_distillation task  ←  (canonical name in
                          ↓                       agent_core::nightbrain
                          ↓                       per Atlas Drift Log row 1)
                          ↓
        Auto-research agent fetches external research candidates
                          ↓
        Eidos Plus deliberation engine (M-2) — scores each candidate
                          ↓
        B2-M14 differential-privacy gate (ε ≤ 0.5) — only Laplace-noised
                          ↓                            telemetry leaves the
                          ↓                            local boundary
                          ↓
        Apply confidence threshold → wins_applied / wins_not_applied /
                                      discoveries split
                          ↓
        Daily report written to <vault>/.epistemos/auto-research/<date>.md
                          ↓
        User reviews report (V1.1 via Confidence Meter full form)
```

**Cross-link with NightBrain B.9 canonical names.** The NoOp `cloud_knowledge_distillation` task (Atlas Drift Log row 1) is the natural home for the auto-research scheduling. When that task body lands real implementation (per Master Fusion Plan §B.9 follow-up), it runs the Karpathy loop above on a φ-spaced cadence (per `MASTER_FUSION §3.35` golden-ratio scheduling) so the auto-research loop doesn't collide with other NightBrain observation lanes.

**B-1 Live Files dependency.** The "wins applied" half — auto-writes to the vault — requires the Live File substrate (Wave 7, PASS 1 B-1, V1.1 defer per `MAS_COMPLETE_FUSION §10`). Without Live Files, auto-research can produce reports but cannot auto-apply changes safely. V1 ships the **read-only daily report** path (the agent can READ the vault and propose changes); V1.1 ships the **auto-apply** path once Live Files lands.

**Boundaries:**
- **NOT a replacement for `vault.search`** — vault.search is the relevance-retrieval primitive the auto-research agent uses internally; auto-research adds the "research outside the vault" pre-fetch step that vault.search alone doesn't do.
- **NOT a replacement for ClaimLedger** — each "win applied" creates a ClaimLedger entry citing the external research as the evidence; ClaimLedger tracks provenance, auto-research generates the new claims.
- **NOT a SovereignGate replacement** — every external fetch in the auto-research loop goes through SovereignGate consent + B2-H20 ephemeral capability token. Auto-research does not bypass user approval; it batches the approvals into a once-a-day choice.

**V1 scope.** V1 ships **none** of this. V1.1 ships **read-only daily reports** (no auto-apply). V2.x ships full auto-apply once Live Files (B-1), Confidence Meter full form (B-3), and Eidos Plus deliberation (M-2) all land. The doctrine row exists to ensure the pieces compose correctly when implementation begins, not to commit V1 to scope it cannot ship.

**Crosslinks:** §13.5.7 (Per-model Knowledge Vaults — auto-research writes to `instructions.md`) · §13.5.3 (Contextual retrieval — auto-research uses `vault.search` internally) · `MASTER_FUSION §3.35` (golden-ratio NightBrain scheduling) · `MAS_COMPLETE_FUSION §10` B-1 Live Files (auto-apply dependency) · `MAS_COMPLETE_FUSION §10` B-3 Confidence Meter (review surface) · PASS 1 M-2 Eidos Plus deliberation (relevance scoring) · PASS 2 B2-M14 differential privacy (telemetry gate) · PASS 2 B2-H20 ephemeral capability tokens (per-fetch gate) · Atlas Drift Log row 1 `cloud_knowledge_distillation` (NightBrain canonical name).

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

## 13.7 Multi-Overseer hierarchy — 4-role decomposition of policy enforcement

**Source:** PASS 1 gap audit H-4 + `docs/fusion/research/OVERSEER_AND_AGENT_HIERARCHY.md` + `docs/fusion/research/kimi-latest/hermes_gateway_architecture.md §L6`.

§5 declared a single `GovernedExecutor` that wraps every concrete executor and runs the SCOPE-Rex policy + RunEventLog write before and after every tool call. This sub-section makes the Overseer **a typed 4-role decomposition** within that wrapper, distinct from treating Overseer as a monolithic feature. The decomposition gives Pro V1.x sub-agent orchestration a clean place to attach policy responsibilities.

**The 4 Overseer roles** (cooperating responsibilities, not separate processes):

| Role | Responsibility | What it produces | What it consumes |
|---|---|---|---|
| **Planner** | Decompose user intent into a tool plan + subgoal tree. Owns the agent's *forward* shape. | `MissionPacket.intent_decomposition` · subgoal DAG · provider+model selection per subgoal | `MissionPacket.intent()` · current `AgentBlueprint` · `ProviderRouter` capability table |
| **Guardrail** | Hard-block tool calls that violate consent / capability / cost gates BEFORE execution. Owns *pre-execution refusal*. | Block / Allow / Require-Approval verdict per `AgentEvent::ToolProposed` | SovereignGate state · `CapabilityLease` (§7.5) · `Capability` enum (§5.1) · current cost telemetry vs budget cap (§B2-H14) |
| **Critique** | Inspect tool results + intermediate reasoning for incoherence / hallucination / drift AFTER execution. Owns *post-execution sense-making*. | ClaimLedger entries · spectral-detection signal (§13.5.8) · SAE feature flags (§3.36) · ConfidenceBadge value | `AgentEvent::ToolResult` · ClaimLedger state · attention-map access (local models only) |
| **Budget** | Enforce cost + time + token caps; route to cheaper providers / smaller models when budget pressure rises. Owns *resource-bound decision-making*. | provider/model downgrade decisions · early-stop signals · budget-exhaust notifications | per-session cost telemetry (§B2-H14) · `pricing.rs::current_spend_usd` · time-since-mission-start · turn count |

**Cooperation pattern** (single agent turn):

```
user intent
   ↓
Planner            → subgoal_1 / subgoal_2 / ... / subgoal_N + provider per subgoal
   ↓ (each subgoal)
Budget             → does subgoal fit budget? if no, downgrade or split
   ↓
ToolProposed event
   ↓
Guardrail          → consent / capability / cost-gate / cap-leases-valid?
                     if Allow → continue; if Block → AgentEvent::ToolBlocked + Planner re-plan; if Require-Approval → SovereignGate
   ↓
executor runs tool
   ↓
ToolResult event
   ↓
Critique           → coherent? hallucination signature absent? confidence ≥ threshold?
                     if yes → ClaimLedger Active entry; if no → ClaimLedger NeedsRevalidation + Planner re-plan
   ↓
next subgoal OR mission complete
```

**Why this is multi-role, not multi-agent.** Per `OVERSEER_AND_AGENT_HIERARCHY.md`, the 4 roles execute as a single process inside `GovernedExecutor` — they share state via the same `AgentBlueprint` + `MissionPacket` + `RunEventLog`. **Sub-agents (Claude Agent SDK pattern)** are a separate concept: each sub-agent has its own Overseer-4. The role decomposition lets one Overseer-4 supervise N sub-agents without role explosion (each sub-agent's 4 roles report to the parent's 4 roles via the same `AgentEvent` stream).

**Mapping onto existing primitives:**

| Overseer role | Existing primitive (today) | Future primitive (Pro V1.x) |
|---|---|---|
| Planner | `MissionPacket.intent()` + `ProviderRouter` §13.6.5 | sub-agent Planner-graph (post-V1) |
| Guardrail | `SovereignGate.validate_*` + §5 SCOPE-Rex governance wrapper + §7.5 Capability Lease (Pro) + §B2-H20 ephemeral tokens (request-time) | per-subagent Guardrail with parent veto |
| Critique | `ClaimLedger` retraction propagation + §13.5.8 spectral detection (post-V1 local-only) + §3.36 SAE AUC ≥ 0.90 (research-tier) | Critique-as-second-model (cloud or larger local) |
| Budget | `pricing.rs::estimate_cost_usd` + Settings → Agent → Spend §B2-H14 (already shipped) | Budget-aware Planner that splits subgoals by cost |

**Boundaries:**
- **NOT separate from SCOPE-Rex.** SCOPE-Rex is the **mechanism** (policy gate fold-over per executor); Overseer-4 is the **role taxonomy** for what the policy decides. They compose: SCOPE-Rex fires the 4 roles in order per `AgentEvent`.
- **NOT separate from §13.6.5 ProviderRouter.** ProviderRouter is the dispatch point Planner uses to pick a provider; Overseer-4 says *which role* makes the dispatch decision (Planner does the provider pick, Budget can override it under pressure).
- **NOT a sub-agent hierarchy.** Sub-agents have their own Overseer-4 each. Cross-link with §14 "Open questions deliberately deferred" #1 (Sub-agents post-V1) and #2 (Multi-agent ACS V2.7).

**Crosslinks:** §5 SCOPE-Rex governance wrapper (Overseer-4 is the role taxonomy inside) · §5.1 ExecutionReceipt (Guardrail uses Capability enum) · §5.2 Ephemeral capability tokens (B2-H20, Guardrail issues + verifies these) · §7.5 Capability Lease (Pro-only XPC handle-binding the Guardrail leases out) · §13.5.7 Per-model Knowledge Vaults (Planner picks the vault) · §13.5.8 Spectral detection (Critique consumes the signal) · §3.36 SAE Observatory (Critique composite acceptance bar) · §B2-H14 Cost telemetry (Budget reads pricing data) · `docs/RECURSIVE_GOVERNANCE_VIABLE_SYSTEMS_MODEL_2026_05_15.md` (Beer VSM, B2-H9 — Overseer-4 is the Hermes-specific instantiation of VSM S3 Control + S4 Intelligence + S5 Policy; S1 Operations is the executor itself, S2 Coordination is the GovernedExecutor wrapper).

**V1 scope.** All 4 roles already exist as primitives in main today (per the mapping table). The post-V1 work is making them **typed** (currently they're implicit in policy-check call-sites) and **per-subagent** (currently one Overseer-4 per agent run). V1 ships the role doctrine in this section; V1.x makes the roles explicit `OverseerRole` enum entries on the `GovernedExecutor` interface.

---

## 13.8 Hermes Vault + Editable Workflows — Loop Profiles (B2-M1)

**Source:** `docs/_consolidated/70_design_implementation/EPISTEMOS_HERMES_MANIFESTO.md` §IV "The Editable Brain" — "The user does not write Swift to add a feature to Hermes. The user writes a loop profile."

### What it is

Hermes maintains a small region of the substrate it can read and write itself: **the Hermes Vault**. Distinct from the user's note vault. Contents:

- **Skills** (already exist as `agent_core/src/agent_runtime/` procedural memory; this section formalizes them as vault-resident).
- **Persona files** — the agent's running identity bundle (also referenced by §13.5.7 Per-model Knowledge Vaults; same artifact class, different consumer).
- **Memory summaries** — compaction outputs that survive across runs.
- **Loop Profiles** — user-authored multi-step reasoning structures, the focus of this section.

A **Loop Profile** is user-authored code defining a recurrent reasoning structure. It lives as a typed node in the cognitive DAG (B2-M1 is a doctrine row; the node kind addition is a forward-stage task — see "V1 scope" below). Invoked on a target artifact (RawThought / Note / ImplementationPlan / Claim / Recall / etc.), Hermes loads the profile and runs the loop against that target.

The Manifesto's canonical example:

```
loop profile: deepen-thought
  on: RawThought
  steps:
    1. embed target.body; query graph for k=20 nearest
    2. for each near node: extract claim; assert relation to target
    3. dispatch synthesis to claude with all assertions
    4. write result as ImplementationPlan node; edge to target
    5. if convergence(target.depth) < threshold: goto 1
```

This is a real artifact, written in either a small declarative DSL **or** in Python via the `execute_code` tool, persisted in the vault, versioned through the graph's natural history.

### How this differs from adjacent concepts (the §5.0 reconciliation answer)

Loop Profiles overlap *visually* with several already-doctrinated primitives. The differences are sharp:

| Adjacent primitive | What it does | Why Loop Profiles are different |
|---|---|---|
| `AgentBlueprint` (§3) | Typed Rust+Swift identity (provider/model/policy/tools/persona). Compile-time. | AgentBlueprint says *who* the agent is. Loop Profile says *what reasoning loop* runs against a specific artifact. One Blueprint can invoke many Loop Profiles. |
| Variant Ladder (§10) | Per-tool tier dispatch (T1 lexical / T2 embedding / T3 RRF). Routes a single tool call across cheap→expensive backends. | Variant Ladder is single-tool, multi-tier. Loop Profile is multi-step, possibly multi-tool. A step inside a Loop Profile may itself dispatch through the Variant Ladder. |
| Auto-research loops (§13.5.10) | System-emitted periodic loops that emit "wins applied / wins not applied / discoveries to investigate" daily reports to the vault. | Auto-research loops are SYSTEM-authored and SYSTEM-triggered (φ-spaced NightBrain schedule, §3.35). Loop Profiles are USER-authored and USER-triggered against a target. Sibling pattern, opposite ownership. |
| Skills (in `agent_runtime`) | Compact reusable tool-invocation macros. | A Skill is a deterministic sequence callable from one step. A Loop Profile composes Skills + tool calls + provider dispatches + convergence checks into a recurrent loop. A Loop Profile step can call a Skill. |
| Cognitive DAG (Phase 8) | Typed graph store with 10 NodeKind + 10 EdgeKind. | The Loop Profile node is a new NodeKind (`LoopProfile`); invocation records produce `Derives` edges from input artifact → output artifact via the profile node. The DAG is the persistence + provenance substrate, not the loop itself. |

### Schema (proposed)

```rust
pub struct LoopProfile {
    pub id: NodeId,                    // ULID, DAG node
    pub name: String,                  // e.g. "deepen-thought"
    pub on: ArtifactKind,              // RawThought | Note | Plan | Claim | Recall | ...
    pub body: LoopBody,                // DSL or Python
    pub convergence: Option<ConvergenceRule>,
    pub vault_path: VaultPath,         // e.g. <vault>/.hermes/profiles/deepen-thought.epoch
    pub version: u32,                  // versioned through graph history
    pub authored_by: AuthorIdentity,   // user | system | imported
}

pub enum LoopBody {
    Dsl(LoopProfileDsl),               // small declarative DSL (V1 read-only viewer surface)
    Python(String),                    // executed via execute_code (Pro-only, V1.1)
}

pub struct LoopProfileDsl {
    pub steps: Vec<LoopStep>,
}

pub enum LoopStep {
    EmbedAndQuery { source: BodyField, k: usize, kind: RetrievalKind },
    ToolCall { name: String, args: serde_json::Value },
    DispatchToProvider { provider: ProviderKey, model: ModelKey, prompt_template: String },
    WriteNode { kind: ArtifactKind, body_template: String, edges: Vec<EdgeSpec> },
    Goto { step: usize, when: ConvergenceCheck },
}
```

The schema is a **proposal frozen in this doctrine row** — landing it in `agent_core/schemas/` is a post-V1 task; this row keeps the shape stable so future implementers don't reinvent it.

### V1 scope (MAS vs Pro)

| Tier | What ships in V1 | What lands V1.1+ |
|---|---|---|
| **MAS V1** | Read-only viewer for any Loop Profile node already in the vault (rendered as a syntax-highlighted code block in the note view). The viewer is `LoopProfileView.swift` (forward-staged; not yet on disk). DSL evaluation runtime: NOT in V1. Python `execute_code`: NOT in V1 (and never in MAS — Five Laws Law 5 forbids in-process Python). | Read-only stays MAS-V1.1; no execution path in MAS ever. |
| **Pro V1.x** | Full DSL evaluator in Rust (within `agent_core::agent_runtime`); Python step path via the existing `execute_code` tool. Profile authoring UI (Settings → Hermes Vault → Loop Profiles). | Profile import/export · cross-vault sharing · convergence-rule library. |

Both tiers: Loop Profile nodes are graph-versioned; users can clone/fork from existing profiles even before the evaluator ships (read-only viewing + manual cloning are forward-compatible).

### Capability discipline

A Loop Profile is itself a capability-bearing artifact. When invoked:

1. The Overseer-4 (§13.7) governs the step list under SCOPE-Rex.
2. The profile inherits the **calling AgentBlueprint's capability budget** — it cannot escalate to tools its parent Blueprint lacks.
3. Each `DispatchToProvider` step is a discrete `ExecutionReceipt` row (§5.1) tagged with `loop_profile_id` + `step_index` so the run is fully replayable.
4. Python steps require the Pro entitlement check at evaluator entry; in MAS the step is replaced by a "Python step not available in MAS" placeholder ledger row rather than silently skipped.

### Forward-stage tasks (not in V1)

- New `NodeKind::LoopProfile` in `agent_core/src/cognitive_dag/node.rs` (today there are 10 NodeKinds; this would be the 11th — schema-versioned migration required).
- `LoopProfileEvaluator` in `agent_core/src/agent_runtime/loop_profiles/` (new module).
- `LoopProfileView.swift` Read-only viewer.
- Authoring UI (Settings → Hermes Vault).
- Convergence rule library (`ConvergenceRule::DepthThreshold` · `::SimilarityCeiling` · `::CountLimit` · etc.).

None of these block V1. The doctrine row + this section anchor the design so future work doesn't reinvent the shape.

### Cross-links

- B2-M1 PASS 2 audit row.
- `docs/_consolidated/70_design_implementation/EPISTEMOS_HERMES_MANIFESTO.md` §IV — canonical source.
- §3 AgentBlueprint — the typed identity a Loop Profile runs *under*.
- §7.4 Specialties registry — capabilities a Loop Profile step can call.
- §10 Variant Ladder — what a single tool-call step internally dispatches through.
- §13.5.7 Per-model Knowledge Vaults — sibling vault-resident artifact (persona files).
- §13.5.10 Auto-research loops — sibling loop pattern, system-authored not user-authored.
- §13.7 Multi-Overseer — policy enforcement layer for the step list.
- B2-M2 Control Plane API (the surface that *exposes* Loop Profiles as first-class UI objects post-V1.1).

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
