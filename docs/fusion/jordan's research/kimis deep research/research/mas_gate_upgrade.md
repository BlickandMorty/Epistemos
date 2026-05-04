# MAS Upgrade: The Resonance Gate for Multi-Agent Orchestration

**Document Version:** 1.0.0-MCR  
**Target:** Upgrading the Resonance Gate from single-token/claim filtering to full multi-agent orchestration governance.  
**Research Basis:** Kev's Dream Team [^3021^], NemoClaw [^3030^] [^3060^], Cursor 2.0/2.5 [^3024^] [^3037^], Claude Code Subagents/Agent Teams [^3034^] [^3038^] [^3039^] [^3095^] [^3099^], GodMode Skill [^3091^], A2A/MCP protocols [^3094^], and academic conflict-resolution literature [^3093^] [^3101^].

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Background: From Single-Token Gate to Multi-Agent Substrate](#2-background)
3. [Design Principles](#3-design-principles)
4. [Agent Registration](#4-agent-registration)
5. [Inter-Agent Communication](#5-inter-agent-communication)
6. [Task Delegation](#6-task-delegation)
7. [Conflict Resolution](#7-conflict-resolution)
8. [Self-Healing](#8-self-healing)
9. [Resource Allocation](#9-resource-allocation)
10. [Formal Specification (Rust)](#10-formal-specification-rust)
11. [Key Invariants (Enforced)](#11-key-invariants-enforced)
12. [Implementation Roadmap](#12-implementation-roadmap)

---

## 1. Executive Summary

The Resonance Gate was originally designed as a **single-token/claim verification layer**: every output from the AI substrate passed through a filter that checked coherence against ground truth. The MAS (Multi-Agent System) release expands this into a **multi-agent governance substrate** where the Gate becomes the central coordination and trust layer for an arbitrary number of agents operating in parallel.

This document defines the architecture, protocols, and Rust formalizations for:
- Agent registration with **Resonance Signatures**
- **Inter-agent communication** via zero-copy arenas and structured messages
- **Task delegation** with budget enforcement and model arbitrage
- **Conflict resolution** through the Evidence Supremacy Protocol
- **Self-healing** with heartbeat failure detection and automatic reassignment
- **Resource allocation** with token-scheduling and deadline enforcement

---

## 2. Background: From Single-Token Gate to Multi-Agent Substrate

### 2.1 What Changed

| Dimension | Original Gate | MAS Gate |
|---|---|---|
| Unit of analysis | Individual token / claim | Inter-agent message + agent state |
| Scope | Single agent output | Swarm of agents |
| Trust model | Binary (pass/fail per claim) | Gradient (resonance score per agent) |
| Communication | N/A (single stream) | Zero-copy arena + structured messages |
| Failure model | Output rejection | Agent termination + reassignment |
| Budget | Per-request cap | Per-agent + swarm-wide cap |
| Conflict | N/A | Evidence Supremacy Protocol |

### 2.2 Research-Driven Design Decisions

Our architecture synthesizes five dominant multi-agent patterns from the 2025-2026 ecosystem:

| Pattern | Key Insight | How We Adapt It |
|---|---|---|
| **Kev's Dream Team** [^3021^] | Orchestrator never does leaf work; model arbitrage; self-healing docs; always-on heartbeats | Agent roles are immutable at runtime; model selection is a first-class routing dimension; agents maintain `IDENTITY.md` equivalents |
| **NemoClaw** [^3030^] | Supervisor-worker YAML topologies; pluggable memory (KV/vector/graph); RBAC tool registry; behavioral guardrails | Hierarchical orchestration; tool permissions enforced at MCP layer; memory backends per agent class |
| **Cursor 2.0** [^3024^] | Git worktree isolation per agent; up to 8 parallel agents; async background agents; MoE routing | Worktree-based isolation for file-system agents; Composer-like task routing; background agent spawning |
| **Claude Code** [^3034^] [^3095^] | Markdown frontmatter agent definitions; automatic delegation; tool restriction via allow/deny lists; Agent Teams with shared task list + mailbox | Agent definitions as structured config; auto-delegation via description matching; peer mailbox system |
| **GodMode** [^3091^] [^3021^] | 5 predefined workflow templates; dual parallel quality gates; auto-routing "You say WHAT, AI decides HOW" | Workflow templates as first-class entities; parallel quality gates via fork-join semantics; trigger-based routing |

---

## 3. Design Principles

### 3.1 Core Axioms

1. **The Gate is the single point of trust.** Every agent registration, every message, every task assignment, and every contradiction passes through the Gate. No agent may communicate directly with another without Gate mediation.
2. **Orchestrator never does leaf work.** Following Kev's Dream Team [^3021^], the Orchestrator delegates and synthesizes only. It does not generate outputs, execute tools, or modify state. This prevents the orchestrator from becoming a bottleneck.
3. **Model arbitrage is a first-class primitive.** Following the cost insight from Dream Team, different tasks should route to different model backends. The Gate maintains a model registry and cost function per task type.
4. **Sub-agents are stateless at rest.** Following TheSethRose's OpenClaw config [^3021^], all context required for a task must be passed in the task message. Agents have no persistent memory across tasks unless explicitly granted via the memory substrate.
5. **Zero-trust at runtime.** Following NemoClaw's security layer [^3062^], every tool call is validated at the MCP layer. Permissions are just-in-time and task-scoped.
6. **Predefined workflows prevent reinvention.** Following GodMode [^3091^], the system ships with canonical workflow templates. New tasks are classified and routed to the appropriate template automatically.
7. **Parallel quality gates are mandatory for production tasks.** Following GodMode's dual-gate pattern, any task marked `critical` must pass two independent validation agents running in parallel.

### 3.2 Why These Patterns

- **Two-level hierarchies outperform flat and deep architectures** in behavioral consistency and task completion fidelity [^3100^]. We adopt a Root Orchestrator + Domain Subgraph pattern.
- **Unoptimized multi-agent systems consume 1.6x to 6.2x more tokens** than single agents on comparable tasks [^3100^]. Model arbitrage and budget enforcement are therefore non-negotiable.
- **A2A (Agent-to-Agent Protocol)** [^3094^] and **MCP (Model Context Protocol)** [^3094^] are the emergent industry standards. Our Gate is compatible with both: it exposes `/.well-known/agent.json` for A2A discovery and enforces MCP-style tool governance.

---

## 4. Agent Registration

### 4.1 Registration Flow

A new agent (local or external) registers with the substrate through the following protocol:

```
1. Agent generates Ed25519 keypair (agent-controlled)
2. Agent submits RegistrationRequest to Gate:
   - public_key
   - agent_definition (name, description, capabilities, model_preference)
   - requested_trust_tier (Observer / Worker / Specialist / Core)
   - resource_claims (max_tokens, max_memory, max_time)
   - network_address (optional, for external agents)
3. Gate computes Resonance Signature
4. Gate assigns initial trust_level based on tier + attestation
5. Gate writes agent to Agent Registry
6. Gate broadcasts AgentJoined event to all registered agents
```

### 4.2 Resonance Signature

Every agent has a **mandatory Resonance Signature** -- a composite fingerprint that captures the agent's identity, capabilities, and behavioral profile. The signature is used for:
- **Message authentication**: All inter-agent messages are signed with the agent's private key; the Gate verifies against the public key in the signature.
- **Capability discovery**: The Orchestrator routes tasks based on matching task requirements to agent capabilities in the signature.
- **Trust gradient**: The signature's `resonance_score` (0.0 to 1.0) is computed from the agent's historical accuracy, contradiction rate, and attestation from other agents.

**Components of the Resonance Signature:**

| Field | Description | Computed How |
|---|---|---|
| `public_key` | Ed25519 public key | Submitted at registration, never changes |
| `capabilities` | Ordered list of (skill, proficiency_score) | Agent declares; Gate validates through test tasks |
| `model_profile` | (backend_id, model_id, cost_per_1k_tokens) | Selected from Model Registry; arbitrage-aware |
| `resonance_score` | Aggregate trust metric [0.0, 1.0] | Weighted average: 40% task success rate, 30% contradiction resolution win rate, 20% peer attestation, 10% uptime |
| `revision_hash` | SHA-256 of agent definition + model_profile | Recomputed on any profile change; Gate audits drift |
| `last_attested` | Timestamp of most recent peer attestation | Updated when another agent vouches for this agent's output |

### 4.3 Trust Tiers

| Tier | Capabilities | Registration Requirements |
|---|---|---|
| **Observer** | Read-only access to public swarm state | None; auto-approved |
| **Worker** | Execute assigned tasks; no delegation | Minimum resonance_score >= 0.3 |
| **Specialist** | Execute tasks + spawn sub-tasks within domain | Minimum resonance_score >= 0.6; at least 50 completed tasks |
| **Core** | Full delegation rights; can modify Gate policy | Minimum resonance_score >= 0.85; human attestation required |

**Important:** The Orchestrator can kill and restart any agent **except Core** (Invariant 3). Core agents can only be terminated by a 2-of-3 human administrator quorum.

### 4.4 External Agent Registration (A2A Compatible)

External agents following the Google A2A protocol [^3094^] register by:
1. Publishing an Agent Card at `/.well-known/agent.json` on their domain.
2. Sending a `RegisterExternalAgent` message to the Gate with the card URL.
3. The Gate fetches the card, validates the `publicKey` against the card's `authentication` block, and creates a proxy Agent entry with `tier: Observer` initially.
4. After a probation period (10 successful tasks), the Gate may promote the agent to `Worker` or `Specialist`.

---

## 5. Inter-Agent Communication

### 5.1 Communication Primitives

The Gate supports three inter-agent communication primitives, selected based on message size, latency requirements, and durability needs:

| Primitive | Use Case | Backend |
|---|---|---|
| **Message** (structured envelope) | Task assignments, results, status updates, contradictions | Zero-copy arena + async channel |
| **Shared Memory** (append-only log) | Large artifact passing (code, documents, datasets); audit trails | Memory-mapped region per agent pair |
| **Signal** (fire-and-forert) | Heartbeats, kill signals, checkpoint requests | Direct async broadcast (no payload) |

### 5.2 The Zero-Copy Arena

Following the insight from Network-AI's blackboard pattern [^3021^] and the need to avoid unnecessary serialization overhead, the Gate manages a **zero-copy arena** for inter-agent messages:

- The arena is a single contiguous `mmap` region per swarm, divided into fixed-size slabs (4KB default).
- When Agent A sends a message to Agent B, the Gate writes the serialized message into a slab in the arena and passes Agent B a handle (offset + length + checksum).
- Agent B reads directly from the arena without copy. The slab is marked free once Agent B acknowledges receipt.
- For messages larger than one slab, a slab chain is allocated (singly-linked list in the arena header).

**Why zero-copy matters:** In multi-agent systems, message volume scales as O(n^2) in the worst case. Copying every message twice (sender -> Gate -> receiver) would dominate latency. The arena reduces this to near-zero for the data path.

### 5.3 Message Envelope Format

Every inter-agent message passes through the Gate. The envelope is:

| Field | Type | Description |
|---|---|---|
| `message_id` | UUIDv7 | Sortable by time; collision-resistant |
| `sender` | AgentId | Sender's registered agent ID |
| `recipient` | AgentId | `*` for broadcast; `orchestrator` for routing |
| `message_type` | enum | `Task`, `Result`, `Status`, `Contradiction`, `Heartbeat`, `Signal` |
| `task_id` | Option<UUID> | Links message to a specific task |
| `payload_hash` | SHA-256 | Hash of the payload body (for integrity) |
| `signature` | Ed25519 | Sender signs `message_id + sender + payload_hash` |
| `arena_handle` | ArenaHandle | Offset + length into the zero-copy arena |
| `timestamp` | u64 (ns since epoch) | For latency tracking and ordering |
| `ttl` | u32 (ms) | Time-to-live; Gate drops expired messages |

**Gate verification on every message:**
1. Signature validation against sender's public key.
2. TTL check (drop if expired).
3. Sender authorization check (does the sender have permission to send this message type?)
4. Payload hash verification (load from arena, recompute hash, compare).
5. Route determination (direct delivery, broadcast, or Orchestrator queue).

### 5.4 Heartbeat Protocol

Following Kev's Dream Team's "always-on" pattern [^3021^] and the insight that reactive chat is insufficient for production agents:

- Every agent MUST emit a `Heartbeat` signal to the Gate at a configurable cadence (default: 30 seconds).
- The heartbeat contains: `agent_id`, `current_task_id` (if any), `memory_usage_bytes`, `token_consumption_cumulative`, `agent_state` (`Idle`, `Working`, `Stalled`, `Panicked`).
- The Gate maintains a `LastSeen` map. If an agent misses 3 consecutive heartbeats, it is marked `Unresponsive`.
- The Orchestrator is notified immediately when any agent becomes `Unresponsive`.
- Heartbeats are lightweight signals (no payload body) to minimize overhead.

---

## 6. Task Delegation

### 6.1 Task Structure

A **Task** is the atomic unit of work in the MAS substrate. The Task struct is defined formally in Section 10.

**Task Lifecycle:**

```
Human / Trigger --> Orchestrator receives Goal
                    |
                    v
              Decompose into Task graph
                    |
                    v
              Gate assigns Resonance Score to each Task
                    |
                    v
              Orchestrator routes each Task to optimal Agent
                    |
                    v
              Agent executes (sends Heartbeats)
                    |
                    v
              Agent returns Result
                    |
                    v
              Gate validates Result
                    |
                    v
              If critical: parallel Quality Gates
                    |
                    v
              If contradiction: Evidence Supremacy Protocol
                    |
                    v
              Task marked Complete / Failed / Retried
```

### 6.2 Task Routing Logic

The Orchestrator's routing algorithm combines five factors:

1. **Capability match**: Does the agent's `capabilities` list include the task's required skills? Score: exact match = 1.0, partial = 0.5, none = 0.0.
2. **Current load**: How many tasks is the agent currently executing? Score: `1.0 / (1 + active_tasks)`.
3. **Historical success rate**: The agent's resonance_score for this specific task type. Computed from rolling window of last 20 tasks.
4. **Cost efficiency**: The agent's `model_profile.cost_per_1k_tokens` compared to other capable agents. Score normalized to [0.0, 1.0].
5. **Urgency compatibility**: The agent's max task duration vs. the task deadline. Score: `1.0` if deadline is comfortably within agent's max, `0.0` if impossible.

The **routing score** is a weighted sum:

```
routing_score = 0.35 * capability_match
              + 0.25 * (1.0 / (1 + active_tasks))
              + 0.20 * historical_success
              + 0.15 * cost_efficiency
              + 0.05 * urgency_compatibility
```

The Orchestrator selects the agent with the highest routing score. If no agent scores above 0.5, the task is queued for a new agent to be spawned (if budget allows) or escalated to the human operator.

### 6.3 Budget Enforcement

Budget exhaustion is a **hard termination trigger** (Invariant 4).

| Budget Type | Scope | Enforcement |
|---|---|---|
| `task_budget` | Per task | Gate tracks token consumption per task; if exceeded, agent receives `BudgetExhausted` signal and must halt within 5 seconds |
| `agent_budget` | Per agent (rolling 24h window) | Gate tracks cumulative tokens per agent; if exceeded, agent is prevented from accepting new tasks until window resets |
| `swarm_budget` | Entire swarm (global cap) | Gate tracks total consumption; if exceeded, only `Core` agents may execute; all others are suspended |
| `time_budget` | Per task | Task has a `deadline`; if not completed by deadline, Gate sends `DeadlineExceeded` and agent must return partial results |

**Budget tracking is real-time.** The Gate intercepts every tool call (via MCP layer) and increments counters before allowing the call to proceed. This prevents overruns that would occur with post-hoc accounting.

### 6.4 Workflow Templates

Following GodMode's pattern [^3091^], the Orchestrator ships with predefined workflow templates:

| Workflow | Pipeline | Trigger Pattern |
|---|---|---|
| **NewFeature** | `researcher -> architect -> builder -> [validator + tester] -> scribe` | User request contains "add", "implement", "create" |
| **BugFix** | `builder -> [validator + tester]` | User request contains "fix", "bug", "error", "crash" |
| **ApiChange** | `architect -> api_guardian -> builder -> [validator + tester] -> scribe` | File paths match `src/api/**`, `backend/routes/**`, `*.d.ts` |
| **Research** | `researcher -> report` | User request contains "research", "investigate", "compare" |
| **Release** | `scribe -> github_manager` | User request contains "release", "deploy", "publish" |
| **SecurityAudit** | `[auditor_1 + auditor_2 + auditor_3] -> arbiter` | File paths match `auth/**`, `crypto/**`, `security/**` |
| **Refactor** | `architect -> builder -> [validator + tester]` | User request contains "refactor", "restructure", "migrate" |

**Auto-routing:** The Orchestrator classifies incoming goals using a lightweight classifier (runs on the cheapest capable model). The classifier selects the workflow template, which then determines which agents are spawned and in what order.

### 6.5 Parallel Quality Gates

Following GodMode's dual-gate pattern [^3091^], any task with `criticality >= High` must pass parallel quality gates:

```
        @builder completes
              |
      +-------+-------+
      |               |
      v               v
 @validator       @tester
(Code Quality)  (UX / Integration)
      |               |
      +-------+-------+
              |
         SYNC POINT
              |
    +---------+---------+
    |                   |
 BOTH APPROVED      ANY BLOCKED
    |                   |
    v                   v
  next stage       @builder (fix)
```

- Both gates run in parallel on isolated worktrees (Git worktree per gate, following Cursor 2.0 [^3024^]).
- The sync point is a Gate-managed barrier: the task cannot proceed until both results are received.
- If either gate reports BLOCKED, the task is routed back to `@builder` with merged feedback.
- If both gates report APPROVED, the task proceeds to the next stage.

---

## 7. Conflict Resolution

### 7.1 The Problem

When two or more agents produce contradictory outputs for the same task or overlapping subtasks, the system must resolve the conflict deterministically. Simple majority voting is insufficient: research shows that majority-vote aggregation can bypass evidence-based evaluation, suppressing correct minority opinions [^3093^].

### 7.2 Evidence Supremacy Protocol

The **Evidence Supremacy Protocol (ESP)** is the Gate's mechanism for resolving contradictions across agents. It replaces naive voting with an **evidence-weighted arbitration** process inspired by fuzzy voting models [^3097^] and auditor-agent patterns [^3093^].

**ESP Steps:**

1. **Contradiction Detection**: After receiving multiple results for the same task (or overlapping claims), the Gate's `ContradictionDetector` computes a consistency score. If the score is below threshold (0.7), a contradiction is declared.

2. **Critical Conflict Point (CCP) Extraction**: Following the medical multi-agent auditing methodology [^3093^], the Gate extracts specific claims that are in direct conflict -- these are the CCPs.

3. **Evidence Gathering**: The Gate assigns an `Arbiter` agent (a high-resonance Specialist or Core agent) to gather evidence for each side of each CCP. The Arbiter may:
   - Request primary sources from the conflicting agents.
   - Spawn `Researcher` agents to independently verify claims.
   - Query the memory substrate for historical evidence.

4. **Evidence-Weighted Scoring**: Each CCP receives a score based on:
   - **Source quality**: Primary data > secondary analysis > agent inference (weights: 0.5, 0.3, 0.2)
   - **Agent resonance**: The historical accuracy of the agent making the claim (weight: 0.3)
   - **Cross-validation**: How many independent agents corroborate the claim (weight: 0.2)
   - **Recency**: More recent evidence scores higher (decay: `exp(-age_hours / 24)`) (weight: 0.1)

5. **Resolution**: The claim with the highest evidence-weighted score wins. The losing agent receives a `ContradictionResolved` message with the winning evidence and an explanation. The losing agent's `resonance_score` is penalized by a small factor (0.02 per lost contradiction, capped at 0.1 per task).

6. **Escalation**: If the evidence scores are within 0.05 of each other, the contradiction is escalated to a human operator (for Core-level tasks) or to a 3-judge panel of Specialist agents (for lower-tier tasks).

### 7.3 Arbiter Agent Selection

The Arbiter must be:
- A different agent class from the conflicting agents (to avoid shared model bias).
- From the `Specialist` or `Core` tier.
- Not currently overloaded (load factor < 0.7).
- The highest-resonance agent meeting the above criteria.

### 7.4 Preventing Echo Chambers

A known failure mode in multi-agent systems is **convergence toward flawed consensus** -- when all agents share the same model or the same training data, they may independently agree on an incorrect premise [^3093^]. The Gate prevents this through:

- **Model diversity requirement**: Contradiction resolution must involve agents from at least two different model backends.
- **Stochastic temperature variation**: When spawning verification agents, the Gate requests slightly higher temperature to encourage diverse reasoning paths.
- **Dissent preservation**: The ESP records the losing side's full reasoning in the audit trail, even when the majority wins. This prevents "loss of key correct information" [^3093^].

---

## 8. Self-Healing

### 8.1 Failure Detection

The Gate detects agent failures through three mechanisms:

| Mechanism | Trigger | Latency |
|---|---|---|
| **Heartbeat timeout** | 3 consecutive missed heartbeats | 90 seconds (default) |
| **Task timeout** | Task exceeds `deadline` | Deadline-dependent |
| **Panic signal** | Agent emits `Panicked` heartbeat or crashes | Immediate |
| **Quality gate failure** | Validator detects corrupted/catastrophically wrong output | Task-dependent |
| **Budget exhaustion** | Agent exceeds `task_budget` | Real-time |

### 8.2 Failure Classification

When a failure is detected, the Gate classifies it:

| Class | Description | Recovery Action |
|---|---|---|
| **Transient** | Network timeout, temporary model unavailability | Retry with exponential backoff (max 3 retries) |
| **Agent Fault** | Agent logic error, hallucination, tool misuse | Terminate agent, restart from last checkpoint, reassign task |
| **Resource Exhaustion** | Budget exceeded, memory pressure, token limit | Halt agent, reassign task to lower-cost agent |
| **Contradiction Cascade** | Agent's output conflicts with swarm consensus | Trigger ESP, penalize agent, reassign if agent is at fault |
| **Security Violation** | Agent attempts unauthorized tool call | Immediate kill, audit log, human alert, agent demoted to Observer |

### 8.3 Reassignment Protocol

When an agent fails and cannot be recovered:

1. The Gate marks the agent's current tasks as `Failed -- Agent Died`.
2. The Gate checks if the agent's worktree/checkpoint is recoverable. If so, it is transferred to the replacement agent.
3. The Orchestrator reruns the routing algorithm for each affected task, excluding the dead agent.
4. The replacement agent receives the task with the original context PLUS a `PreviousAttempt` field containing the dead agent's partial results and failure reason.
5. If no replacement agent is available and the task is critical, the Orchestrator may spawn a new agent instance (subject to swarm budget).
6. The dead agent is removed from the active agent pool. Its Resonance Signature is archived (not deleted) for audit purposes.

### 8.4 Checkpointing

Following Claude Code's checkpoint pattern [^3036^], the Gate supports automatic checkpointing:

- Before every task, the agent's state is snapshotted (memory, workspace, context window position).
- Checkpoints are stored in the arena as append-only logs.
- On failure, the replacement agent may resume from the last checkpoint instead of starting from scratch.
- Checkpoints are reference-counted: when all dependent tasks complete, the checkpoint is garbage-collected.

### 8.5 Self-Healing Documentation

Following Kev's Dream Team's "self-healing docs" pattern [^3021^], agents are encouraged to update their own instruction files when they learn new patterns:

- After each completed task, the agent may emit a `DocUpdate` proposal to the Gate.
- The Gate forwards the proposal to a `MetaReviewer` agent (a Core-tier agent specialized in documentation quality).
- If approved, the update is applied to the agent's profile in the Agent Registry.
- This creates a compounding quality improvement: agents that frequently encounter similar errors learn to avoid them by updating their own instructions.

---

## 9. Resource Allocation

### 9.1 Compute Dimensions

The Gate tracks three compute dimensions per agent and per swarm:

| Dimension | Unit | Enforcement |
|---|---|---|
| **Tokens** | Input + output tokens | Per-task cap, per-agent rolling window, swarm global cap |
| **Time** | Wall-clock seconds | Per-task deadline, per-agent session timeout |
| **Memory** | Bytes (arena + heap) | Per-agent RSS limit; Gate sends `MemoryPressure` signal at 80% |

### 9.2 Scheduling Algorithm

The Orchestrator uses a **Weighted Fair Queueing (WFQ)** variant for task scheduling:

- Each agent maintains a virtual time counter, incremented by the cost of each task it executes.
- When a task is ready to be assigned, the Orchestrator computes which capable agent would have the lowest virtual time after executing the task.
- The task is assigned to that agent.
- This ensures fair distribution of workload while still respecting capability constraints.

**Priority preemption:** Tasks with `criticality: Critical` may preempt lower-priority tasks. The preempted task is checkpointed and resumed when the critical task completes.

### 9.3 Model Arbitrage in Scheduling

The scheduling algorithm explicitly considers model cost:

- When multiple agents are capable of a task, the Gate computes a "cost-adjusted routing score" that divides the base routing score by the expected token cost.
- This naturally routes low-complexity tasks to cheaper models (e.g., Haiku for summarization, Flash for research) and high-complexity tasks to premium models (e.g., Opus for orchestration, Codex for security-sensitive code).

The cost function is configurable per deployment. Default weights:

| Model Class | Approximate Cost Ratio | Typical Use |
|---|---|---|
| Fast/Cheap (Haiku, Flash) | 1x | Search, summarization, simple lookups |
| Standard (Sonnet, GPT-4o) | 5x | Implementation, testing, validation |
| Premium (Opus, o3-mini, Codex) | 15x | Orchestration, security audits, complex architecture |
| Vision (Gemini Pro, Omni) | 10x | Image analysis, visual QA |

### 9.4 Token Budget Ceiling

Following Network-AI's budget ceiling pattern [^3021^], the Gate enforces hard ceilings:

- Each task declares its `budget` field upfront.
- The Gate tracks running consumption via MCP-layer interception.
- At 80% of budget: Gate sends `BudgetWarning` to agent.
- At 100% of budget: Gate sends `BudgetExhausted` and blocks further tool calls.
- At 110% of budget (grace overrun): Gate force-terminates the agent.
- The agent's unfinished output is still returned to the Orchestrator as a partial result.

---

## 10. Formal Specification (Rust)

This section defines the core types, traits, and structs in Rust. These are **design scaffolds** -- they compile as a coherent architecture but require implementation of the backing stores and protocol handlers.

### 10.1 Core Type Definitions

```rust
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime};
use uuid::Uuid;
use serde::{Deserialize, Serialize};
use ed25519_dalek::{PublicKey, Signature};

// ---------------------------------------------------------------------------
// 10.1.1 Identity and Trust
// ---------------------------------------------------------------------------

/// Unique identifier for an agent in the swarm.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AgentId(pub Uuid);

/// Trust tiers define what an agent is permitted to do.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum TrustTier {
    /// Read-only access to public swarm state.
    Observer,
    /// Can execute assigned tasks; cannot delegate.
    Worker,
    /// Can execute and spawn sub-tasks within domain.
    Specialist,
    /// Full delegation rights; policy modification. Cannot be killed by Orchestrator.
    Core,
}

/// A capability declaration: what the agent claims it can do, and how well.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Capability {
    pub skill: String,
    /// Proficiency score in [0.0, 1.0], validated by the Gate through test tasks.
    pub proficiency: f64,
}

/// Model backend profile for cost-aware routing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelProfile {
    pub backend_id: String,
    pub model_id: String,
    pub cost_per_1k_input_tokens: f64,
    pub cost_per_1k_output_tokens: f64,
    pub max_context_length: usize,
}

/// The mandatory Resonance Signature -- every agent must have one.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResonanceSignature {
    pub agent_id: AgentId,
    pub public_key: PublicKey,
    pub capabilities: Vec<Capability>,
    pub model_profile: ModelProfile,
    /// Aggregate trust metric in [0.0, 1.0].
    pub resonance_score: f64,
    /// SHA-256 of agent definition + model_profile. Recomputed on any change.
    pub revision_hash: [u8; 32],
    pub last_attested: SystemTime,
    pub trust_tier: TrustTier,
}

/// A message envelope -- every inter-agent message passes through the Gate.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub message_id: Uuid,
    pub sender: AgentId,
    pub recipient: AgentId, // Use AgentId::broadcast() for broadcast
    pub message_type: MessageType,
    pub task_id: Option<Uuid>,
    pub payload_hash: [u8; 32],
    pub signature: Signature,
    pub arena_handle: ArenaHandle,
    pub timestamp: SystemTime,
    /// Time-to-live in milliseconds.
    pub ttl_ms: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum MessageType {
    Task,
    Result,
    Status,
    Contradiction,
    Heartbeat,
    Signal(SignalType),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum SignalType {
    Kill,
    Checkpoint,
    BudgetWarning,
    BudgetExhausted,
    MemoryPressure,
    DeadlineExceeded,
}

/// Handle into the zero-copy arena.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArenaHandle {
    pub offset: usize,
    pub length: usize,
    pub checksum: u32,
}

// ---------------------------------------------------------------------------
// 10.1.2 Tasks
// ---------------------------------------------------------------------------

/// Criticality levels determine quality gate requirements.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Criticality {
    Low,
    Medium,
    High,
    Critical,
}

/// Budget envelope for a task or agent.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Budget {
    /// Max tokens (input + output) allowed.
    pub max_tokens: usize,
    /// Max wall-clock seconds allowed.
    pub max_time_secs: u64,
    /// Max memory bytes the agent may allocate.
    pub max_memory_bytes: usize,
}

/// The atomic unit of work.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub task_id: Uuid,
    /// Human-readable objective.
    pub objective: String,
    /// Detailed instructions, context, and constraints.
    pub instruction: String,
    pub budget: Budget,
    /// Hard deadline. Task is killed if exceeded.
    pub deadline: SystemTime,
    /// Minimum required capability for this task.
    pub required_capabilities: Vec<Capability>,
    /// Determines if parallel quality gates are required.
    pub criticality: Criticality,
    /// The workflow template this task belongs to (if any).
    pub workflow_template: Option<String>,
    /// If this task is a retry, contains the previous attempt's info.
    pub previous_attempt: Option<PreviousAttempt>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreviousAttempt {
    pub failed_agent_id: AgentId,
    pub partial_result: ArenaHandle,
    pub failure_reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskResult {
    pub task_id: Uuid,
    pub agent_id: AgentId,
    pub status: TaskStatus,
    pub output: ArenaHandle,
    pub tokens_consumed: usize,
    pub time_elapsed_secs: u64,
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TaskStatus {
    InProgress,
    Complete,
    Failed,
    Blocked,
    Cancelled,
}
```

### 10.2 The Agent Trait

```rust
// ---------------------------------------------------------------------------
// 10.2 Agent Trait -- what every agent must implement
// ---------------------------------------------------------------------------

/// Every agent in the substrate must implement this trait.
///
/// The Gate owns the agent's lifecycle (spawn, run, monitor, kill).
/// The agent is responsible for executing tasks and emitting heartbeats.
#[async_trait::async_trait]
pub trait Agent: Send + Sync {
    /// Return the agent's immutable Resonance Signature.
    fn signature(&self) -> &ResonanceSignature;

    /// Called by the Gate when a task is assigned to this agent.
    /// The agent must begin execution immediately and return a TaskResult.
    /// If the agent cannot accept the task, it must return a Result with an error.
    async fn accept_task(&self, task: Task, gate: Arc<dyn Gate>) -> Result<TaskResult, AgentError>;

    /// Called by the Gate at regular intervals to request a heartbeat.
    /// The agent must respond with its current state.
    async fn heartbeat(&self) -> Heartbeat;

    /// Called by the Gate when the agent must checkpoint its state.
    /// The agent must serialize its current context and return a handle.
    async fn checkpoint(&self) -> Result<ArenaHandle, AgentError>;

    /// Called by the Gate to restore from a checkpoint.
    async fn restore(&self, checkpoint: ArenaHandle) -> Result<(), AgentError>;

    /// Called by the Gate when the agent is being terminated.
    /// The agent must clean up resources and return within `timeout`.
    async fn shutdown(&self, reason: ShutdownReason, timeout: Duration);
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Heartbeat {
    pub agent_id: AgentId,
    pub current_task_id: Option<Uuid>,
    pub memory_usage_bytes: usize,
    pub token_consumption_cumulative: usize,
    pub state: AgentState,
    pub timestamp: SystemTime,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AgentState {
    Idle,
    Working,
    Stalled,
    Panicked,
    ShuttingDown,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ShutdownReason {
    BudgetExhausted,
    DeadlineExceeded,
    QualityGateFailed,
    SecurityViolation,
    ContradictionPenalty,
    OrchestratorCommand,
    SelfHealingRestart,
}

#[derive(Debug, Clone, thiserror::Error)]
pub enum AgentError {
    #[error("Task rejected: agent overloaded")]
    Overloaded,
    #[error("Task rejected: insufficient capability")]
    InsufficientCapability,
    #[error("Task failed: {0}")]
    ExecutionFailed(String),
    #[error("Checkpoint failed: {0}")]
    CheckpointFailed(String),
}
```

### 10.3 The Orchestrator Trait

```rust
// ---------------------------------------------------------------------------
// 10.3 Orchestrator Trait -- how tasks are routed, how health is monitored
// ---------------------------------------------------------------------------

/// The Orchestrator is the central coordinator of the swarm.
///
/// It does not execute tasks itself -- it only decomposes goals, routes tasks,
/// monitors agent health, and resolves conflicts.
#[async_trait::async_trait]
pub trait Orchestrator: Send + Sync {
    /// Receive a high-level goal and decompose it into a Task graph.
    async fn ingest_goal(&self, goal: Goal) -> Result<TaskGraph, OrchestratorError>;

    /// Given a ready task and the current swarm state, select the best agent.
    /// Returns the AgentId of the chosen agent.
    fn route_task(&self, task: &Task, swarm: &AgentSwarm) -> Result<AgentId, OrchestratorError>;

    /// Handle a completed task result. May trigger quality gates, ESP, or next stage.
    async fn handle_result(
        &self,
        result: TaskResult,
        swarm: Arc<dyn SwarmHandle>,
    ) -> Result<(), OrchestratorError>;

    /// Handle an agent failure (heartbeat timeout, panic, budget exhaustion).
    /// Must reassign tasks and optionally restart the agent.
    async fn handle_agent_failure(
        &self,
        agent_id: AgentId,
        failure: FailureReport,
        swarm: Arc<dyn SwarmHandle>,
    ) -> Result<(), OrchestratorError>;

    /// Monitor swarm health continuously. Runs as a background task.
    async fn health_monitor(&self, swarm: Arc<dyn SwarmHandle>);

    /// Enforce budget caps across the swarm. Runs as a background task.
    async fn budget_monitor(&self, swarm: Arc<dyn SwarmHandle>);
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Goal {
    pub goal_id: Uuid,
    pub description: String,
    pub requester: AgentId, // Can be a human proxy agent
    pub priority: Criticality,
    pub suggested_workflow: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskGraph {
    pub tasks: Vec<TaskNode>,
    pub edges: Vec<(Uuid, Uuid)>, // (from_task_id, to_task_id)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskNode {
    pub task: Task,
    pub dependencies: Vec<Uuid>,
    pub parallel_gates: Option<ParallelGates>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParallelGates {
    pub gate_agents: Vec<AgentId>, // e.g., [validator_id, tester_id]
    pub requires_all_approved: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FailureReport {
    pub agent_id: AgentId,
    pub failure_class: FailureClass,
    pub description: String,
    pub affected_task_ids: Vec<Uuid>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FailureClass {
    Transient,
    AgentFault,
    ResourceExhaustion,
    ContradictionCascade,
    SecurityViolation,
}

#[derive(Debug, Clone, thiserror::Error)]
pub enum OrchestratorError {
    #[error("No capable agent found for task")]
    NoCapableAgent,
    #[error("Swarm budget exhausted")]
    SwarmBudgetExhausted,
    #[error("Task graph cycle detected")]
    CyclicDependency,
    #[error("Goal classification failed")]
    ClassificationFailed,
    #[error("Agent {0} is Core -- cannot kill")]
    CannotKillCore(AgentId),
}
```

### 10.4 The AgentSwarm Struct

```rust
// ---------------------------------------------------------------------------
// 10.4 AgentSwarm -- collection of agents with routing table
// ---------------------------------------------------------------------------

/// The AgentSwarm is the runtime container for all registered agents.
/// It maintains the registry, routing table, budget ledger, and heartbeat state.
pub struct AgentSwarm {
    /// All registered agents, keyed by AgentId.
    registry: HashMap<AgentId, Arc<dyn Agent>>,
    /// Resonance signatures, keyed by AgentId.
    signatures: HashMap<AgentId, ResonanceSignature>,
    /// Routing table: pre-computed capability -> agent list for fast lookup.
    routing_table: HashMap<String, Vec<AgentId>>,
    /// Current tasks per agent.
    active_tasks: HashMap<AgentId, Vec<Uuid>>,
    /// Last heartbeat received per agent.
    last_heartbeat: HashMap<AgentId, Instant>,
    /// Budget ledger per agent (rolling 24h window).
    agent_budgets: HashMap<AgentId, BudgetLedger>,
    /// Swarm-wide budget ledger.
    swarm_budget: BudgetLedger,
    /// The zero-copy arena for inter-agent messages.
    arena: Arc<Arena>,
}

#[derive(Debug, Clone, Default)]
pub struct BudgetLedger {
    pub tokens_consumed: usize,
    pub window_start: SystemTime,
}

impl AgentSwarm {
    /// Register a new agent. Computes Resonance Signature and updates routing table.
    pub fn register(&mut self, agent: Arc<dyn Agent>) -> Result<(), SwarmError> {
        let sig = agent.signature().clone();
        let id = sig.agent_id;
        if self.registry.contains_key(&id) {
            return Err(SwarmError::AgentAlreadyRegistered(id));
        }
        // Build routing table entries from capabilities.
        for cap in &sig.capabilities {
            self.routing_table
                .entry(cap.skill.clone())
                .or_default()
                .push(id);
        }
        self.signatures.insert(id, sig);
        self.registry.insert(id, agent);
        self.agent_budgets.insert(id, BudgetLedger::default());
        Ok(())
    }

    /// Deregister an agent (called on failure, kill, or graceful exit).
    /// Archives the signature; removes from active routing.
    pub fn deregister(&mut self, agent_id: AgentId) -> Result<(), SwarmError> {
        let sig = self.signatures.remove(&agent_id)
            .ok_or(SwarmError::AgentNotFound(agent_id))?;
        self.registry.remove(&agent_id);
        self.active_tasks.remove(&agent_id);
        self.last_heartbeat.remove(&agent_id);
        // Archive the signature for audit.
        self.archive_signature(sig);
        // Rebuild routing table.
        self.rebuild_routing_table();
        Ok(())
    }

    /// Find all agents capable of a given skill, sorted by routing score.
    pub fn find_capable_agents(&self, skill: &str, task: &Task) -> Vec<(AgentId, f64)> {
        let mut scored = Vec::new();
        if let Some(candidates) = self.routing_table.get(skill) {
            for &id in candidates {
                if let Some(sig) = self.signatures.get(&id) {
                    let score = self.compute_routing_score(id, sig, task);
                    scored.push((id, score));
                }
            }
        }
        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
        scored
    }

    /// Compute routing score per Section 6.2.
    fn compute_routing_score(&self, id: AgentId, sig: &ResonanceSignature, task: &Task) -> f64 {
        let capability_match = sig.capabilities.iter()
            .filter(|c| task.required_capabilities.iter().any(|r| r.skill == c.skill))
            .map(|c| c.proficiency)
            .max_by(|a, b| a.partial_cmp(b).unwrap())
            .unwrap_or(0.0);

        let active = self.active_tasks.get(&id).map(|v| v.len()).unwrap_or(0);
        let load_factor = 1.0 / (1.0 + active as f64);

        // Historical success rate from resonance score (could be specialized per skill).
        let historical_success = sig.resonance_score;

        // Cost efficiency: cheaper is better. Normalize by max cost in registry.
        let max_cost = self.signatures.values()
            .map(|s| s.model_profile.cost_per_1k_output_tokens)
            .fold(0.0, f64::max);
        let cost_efficiency = if max_cost > 0.0 {
            1.0 - (sig.model_profile.cost_per_1k_output_tokens / max_cost)
        } else {
            1.0
        };

        // Urgency compatibility.
        let deadline_duration = task.deadline.duration_since(SystemTime::now())
            .unwrap_or(Duration::ZERO);
        let max_time = Duration::from_secs(task.budget.max_time_secs);
        let urgency = if max_time > Duration::ZERO {
            (deadline_duration.as_secs_f64() / max_time.as_secs_f64()).min(1.0)
        } else {
            1.0
        };

        0.35 * capability_match
            + 0.25 * load_factor
            + 0.20 * historical_success
            + 0.15 * cost_efficiency
            + 0.05 * urgency
    }

    fn archive_signature(&mut self, _sig: ResonanceSignature) {
        // Archive to persistent store for audit trail.
        // Implementation: write to append-only log.
    }

    fn rebuild_routing_table(&mut self) {
        self.routing_table.clear();
        for (id, sig) in &self.signatures {
            for cap in &sig.capabilities {
                self.routing_table
                    .entry(cap.skill.clone())
                    .or_default()
                    .push(*id);
            }
        }
    }
}

#[derive(Debug, Clone, thiserror::Error)]
pub enum SwarmError {
    #[error("Agent {0} already registered")]
    AgentAlreadyRegistered(AgentId),
    #[error("Agent {0} not found")]
    AgentNotFound(AgentId),
    #[error("Swarm budget exhausted")]
    BudgetExhausted,
}
```

### 10.5 The Upgraded Resonance Gate

```rust
// ---------------------------------------------------------------------------
// 10.5 Upgraded Resonance Gate -- handles multi-agent signatures,
// inter-agent resonance scores, swarm coherence
// ---------------------------------------------------------------------------

/// The Gate is the central trust and mediation layer.
/// Every agent registration, message, task, and contradiction passes through here.
#[async_trait::async_trait]
pub trait Gate: Send + Sync {
    /// Register a new agent. Computes Resonance Signature.
    async fn register_agent(&self, request: RegistrationRequest) -> Result<ResonanceSignature, GateError>;

    /// Verify and route an inter-agent message.
    async fn process_message(&self, msg: Message) -> Result<RoutingDecision, GateError>;

    /// Assign a task to an agent, enforcing budget pre-checks.
    async fn assign_task(&self, task: Task, agent_id: AgentId) -> Result<(), GateError>;

    /// Accept a task result, triggering validation, quality gates, and ESP if needed.
    async fn accept_result(&self, result: TaskResult) -> Result<PostResultAction, GateError>;

    /// Resolve a contradiction via Evidence Supremacy Protocol.
    async fn resolve_contradiction(
        &self,
        ccp: CriticalConflictPoint,
        conflicting_results: Vec<TaskResult>,
    ) -> Result<Resolution, GateError>;

    /// Compute inter-agent resonance: how much two agents tend to agree.
    fn compute_inter_agent_resonance(&self, a: AgentId, b: AgentId) -> f64;

    /// Compute swarm coherence: overall agreement level across all agents.
    fn compute_swarm_coherence(&self) -> f64;

    /// Emit a signal to one or more agents.
    async fn emit_signal(&self, signal: SignalType, targets: Vec<AgentId>) -> Result<(), GateError>;

    /// Audit log interface: every significant action is logged.
    async fn audit_log(&self, entry: AuditEntry) -> Result<(), GateError>;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegistrationRequest {
    pub public_key: PublicKey,
    pub agent_definition: AgentDefinition,
    pub requested_tier: TrustTier,
    pub resource_claims: Budget,
    pub network_address: Option<String>, // For external agents (A2A)
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentDefinition {
    pub name: String,
    pub description: String,
    pub capabilities: Vec<Capability>,
    pub model_preference: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RoutingDecision {
    DeliverTo(AgentId),
    Broadcast,
    QueueForOrchestrator,
    Drop(GateError),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CriticalConflictPoint {
    pub ccp_id: Uuid,
    pub task_id: Uuid,
    pub claim_a: Claim,
    pub claim_b: Claim,
    pub severity: ConflictSeverity,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claim {
    pub agent_id: AgentId,
    pub statement: String,
    pub evidence_handles: Vec<ArenaHandle>,
    pub confidence: f64, // Agent's stated confidence
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConflictSeverity {
    Minor,
    Significant,
    Critical,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Resolution {
    pub winning_claim: Claim,
    pub losing_claims: Vec<Claim>,
    pub arbiter_agent_id: AgentId,
    pub evidence_scores: HashMap<AgentId, f64>,
    pub required_escalation: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PostResultAction {
    Proceed,
    TriggerQualityGates(Vec<AgentId>),
    TriggerESP(CriticalConflictPoint),
    Reassign { task_id: Uuid, reason: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEntry {
    pub timestamp: SystemTime,
    pub event_type: AuditEventType,
    pub actor: AgentId,
    pub target: Option<AgentId>,
    pub details: String,
    pub hash_chain: [u8; 32], // SHA-256 of previous entry + this entry's content
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AuditEventType {
    AgentRegistered,
    AgentDeregistered,
    TaskAssigned,
    TaskCompleted,
    TaskFailed,
    MessageRouted,
    ContradictionDetected,
    ContradictionResolved,
    BudgetExceeded,
    AgentKilled,
    AgentRestarted,
    PolicyChanged,
}

#[derive(Debug, Clone, thiserror::Error)]
pub enum GateError {
    #[error("Invalid signature on message from {0}")]
    InvalidSignature(AgentId),
    #[error("Agent {0} not authorized for this action")]
    Unauthorized(AgentId),
    #[error("Message expired (TTL exceeded)")]
    MessageExpired,
    #[error("Budget exhausted for agent {0}")]
    BudgetExhausted(AgentId),
    #[error("No arbiter available for contradiction resolution")]
    NoArbiterAvailable,
    #[error("Core agent {0} cannot be killed")]
    CannotKillCore(AgentId),
    #[error("Payload hash mismatch")]
    PayloadHashMismatch,
    #[error("Agent {0} already registered")]
    DuplicateAgent(AgentId),
    #[error("Trust tier {0} requires attestation")]
    AttestationRequired(String),
}
```

### 10.6 Arena Implementation (Zero-Copy)

```rust
// ---------------------------------------------------------------------------
// 10.6 Zero-Copy Arena
// ---------------------------------------------------------------------------

use std::sync::atomic::{AtomicUsize, Ordering};

/// A bump-arena with slab chaining for message passing.
/// Thread-safe via atomic allocation.
pub struct Arena {
    base: *mut u8,
    capacity: usize,
    slab_size: usize,
    next_free: AtomicUsize,
}

unsafe impl Send for Arena {}
unsafe impl Sync for Arena {}

impl Arena {
    pub fn new(capacity: usize, slab_size: usize) -> Self {
        let layout = std::alloc::Layout::from_size_align(capacity, 4096).unwrap();
        let base = unsafe { std::alloc::alloc(layout) };
        Self {
            base,
            capacity,
            slab_size,
            next_free: AtomicUsize::new(0),
        }
    }

    /// Allocate a slab chain for `length` bytes.
    /// Returns an ArenaHandle pointing to the first slab.
    pub fn allocate(&self, length: usize) -> Option<ArenaHandle> {
        let slabs_needed = (length + self.slab_size - 1) / self.slab_size;
        let total_size = slabs_needed * self.slab_size;
        let offset = self.next_free.fetch_add(total_size, Ordering::SeqCst);
        if offset + total_size > self.capacity {
            self.next_free.fetch_sub(total_size, Ordering::SeqCst);
            return None; // Arena exhausted
        }
        Some(ArenaHandle {
            offset,
            length,
            checksum: 0, // Computed after write
        })
    }

    /// Write data to the arena at the given handle.
    pub fn write(&self, handle: ArenaHandle, data: &[u8]) {
        assert_eq!(data.len(), handle.length);
        unsafe {
            let ptr = self.base.add(handle.offset);
            std::ptr::copy_nonoverlapping(data.as_ptr(), ptr, data.len());
        }
    }

    /// Read data from the arena at the given handle.
    /// Returns a slice valid for the lifetime of the Arena.
    pub fn read(&self, handle: ArenaHandle) -> &[u8] {
        unsafe {
            let ptr = self.base.add(handle.offset);
            std::slice::from_raw_parts(ptr, handle.length)
        }
    }
}

impl Drop for Arena {
    fn drop(&mut self) {
        let layout = std::alloc::Layout::from_size_align(self.capacity, 4096).unwrap();
        unsafe {
            std::alloc::dealloc(self.base, layout);
        }
    }
}
```

### 10.7 Workflow Template System

```rust
// ---------------------------------------------------------------------------
// 10.7 Workflow Templates
// ---------------------------------------------------------------------------

/// A predefined pipeline of agent roles and execution semantics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkflowTemplate {
    pub name: String,
    pub trigger_keywords: Vec<String>,
    pub trigger_path_patterns: Vec<String>,
    pub stages: Vec<WorkflowStage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkflowStage {
    pub stage_name: String,
    pub required_role: String, // e.g., "researcher", "builder"
    pub parallel: bool,
    pub gates: Vec<String>,    // Parallel gate roles (if any)
    pub next_stage: Option<String>,
}

/// The built-in workflow templates (GodMode-inspired).
pub fn default_workflows() -> Vec<WorkflowTemplate> {
    vec![
        WorkflowTemplate {
            name: "NewFeature".into(),
            trigger_keywords: vec!["add".into(), "implement".into(), "create".into()],
            trigger_path_patterns: vec![],
            stages: vec![
                WorkflowStage { stage_name: "research".into(), required_role: "researcher".into(), parallel: false, gates: vec![], next_stage: Some("design".into()) },
                WorkflowStage { stage_name: "design".into(), required_role: "architect".into(), parallel: false, gates: vec![], next_stage: Some("build".into()) },
                WorkflowStage { stage_name: "build".into(), required_role: "builder".into(), parallel: false, gates: vec!["validator".into(), "tester".into()], next_stage: Some("document".into()) },
                WorkflowStage { stage_name: "document".into(), required_role: "scribe".into(), parallel: false, gates: vec![], next_stage: None },
            ],
        },
        WorkflowTemplate {
            name: "BugFix".into(),
            trigger_keywords: vec!["fix".into(), "bug".into(), "error".into(), "crash".into()],
            trigger_path_patterns: vec![],
            stages: vec![
                WorkflowStage { stage_name: "fix".into(), required_role: "builder".into(), parallel: false, gates: vec!["validator".into(), "tester".into()], next_stage: None },
            ],
        },
        WorkflowTemplate {
            name: "ApiChange".into(),
            trigger_keywords: vec!["api".into(), "endpoint".into(), "route".into()],
            trigger_path_patterns: vec!["src/api/**".into(), "backend/routes/**".into(), "*.d.ts".into()],
            stages: vec![
                WorkflowStage { stage_name: "design".into(), required_role: "architect".into(), parallel: false, gates: vec![], next_stage: Some("guardian".into()) },
                WorkflowStage { stage_name: "guardian".into(), required_role: "api_guardian".into(), parallel: false, gates: vec![], next_stage: Some("build".into()) },
                WorkflowStage { stage_name: "build".into(), required_role: "builder".into(), parallel: false, gates: vec!["validator".into(), "tester".into()], next_stage: Some("document".into()) },
                WorkflowStage { stage_name: "document".into(), required_role: "scribe".into(), parallel: false, gates: vec![], next_stage: None },
            ],
        },
        WorkflowTemplate {
            name: "SecurityAudit".into(),
            trigger_keywords: vec!["audit".into(), "security".into(), "vulnerability".into()],
            trigger_path_patterns: vec!["auth/**".into(), "crypto/**".into()],
            stages: vec![
                WorkflowStage { stage_name: "audit".into(), required_role: "auditor".into(), parallel: true, gates: vec![], next_stage: Some("arbiter".into()) },
                WorkflowStage { stage_name: "arbiter".into(), required_role: "arbiter".into(), parallel: false, gates: vec![], next_stage: None },
            ],
        },
    ]
}
```

---

## 11. Key Invariants (Enforced)

These invariants are **hard architectural guarantees** enforced by the Gate at runtime:

### Invariant 1: Every agent has a mandatory Resonance Signature
**Enforcement:** The `register_agent` method on the `Gate` trait rejects any registration request without a valid Ed25519 public key and capability list. The `Agent` trait's `signature()` method returns `&ResonanceSignature` -- it is impossible to construct an agent without one.

### Invariant 2: Every inter-agent message passes through the Gate
**Enforcement:** The `process_message` method is the only mechanism for message delivery. Agents cannot hold direct references to each other. The `Arena` is owned by the Gate; agents receive only `ArenaHandle`s. The `Message` struct's `signature` field is verified by the Gate before routing.

### Invariant 3: The Orchestrator can kill and restart any agent (except Core)
**Enforcement:** The `Orchestrator::handle_agent_failure` method calls `Gate::emit_signal(Kill, ...)` for any non-Core agent. The `GateError::CannotKillCore` variant is returned if a Core agent is targeted. Core agents require a 2-of-3 human admin quorum for termination, enforced by a separate `AdminPolicy` layer.

### Invariant 4: Budget exhaustion triggers automatic agent termination
**Enforcement:** The `Gate::assign_task` method pre-checks budget availability. The `budget_monitor` background task (on `Orchestrator`) tracks consumption in real-time via MCP-layer interception. At 100% budget, `BudgetExhausted` signal is emitted. At 110%, `Kill` signal is emitted automatically. The agent's `accept_task` contract requires it to halt within 5 seconds of `BudgetExhausted`.

### Invariant 5: Contradictory outputs trigger Evidence Supremacy Protocol
**Enforcement:** The `Gate::accept_result` method checks for conflicting results on the same task. If the `ContradictionDetector` finds a consistency score below 0.7, `accept_result` returns `PostResultAction::TriggerESP(...)` instead of `Proceed`. The Orchestrator is then obligated to invoke `Gate::resolve_contradiction`. Results from contradicted tasks cannot proceed to downstream stages until ESP completes.

---

## 12. Implementation Roadmap

| Phase | Deliverable | Duration | Risk |
|---|---|---|---|
| **P0: Foundation** | Arena allocator, Agent Registry, basic Message routing | 2 weeks | Low |
| **P1: Orchestrator** | Task decomposition, routing algorithm, workflow templates | 2 weeks | Medium |
| **P2: Budget & Health** | Real-time budget tracking, heartbeat protocol, self-healing | 2 weeks | Medium |
| **P3: Quality Gates** | Parallel gate execution, git worktree isolation | 1 week | Low |
| **P4: ESP** | Contradiction detection, arbiter selection, evidence-weighted scoring | 2 weeks | High |
| **P5: A2A/MCP** | External agent support, Agent Cards, MCP tool governance | 2 weeks | Medium |
| **P6: Hardening** | Audit trail (SHA-256 hash chain), policy hot-reload, admin quorum | 1 week | Low |

---

## Appendix A: Glossary

| Term | Definition |
|---|---|
| **A2A** | Agent-to-Agent Protocol (Google). Standardizes direct agent communication via Agent Cards. |
| **Agent Card** | JSON descriptor at `/.well-known/agent.json` defining agent capabilities, auth, and endpoints. |
| **CCP** | Critical Conflict Point. A specific claim where two agents directly contradict each other. |
| **ESP** | Evidence Supremacy Protocol. The Gate's mechanism for resolving contradictions via evidence-weighted arbitration. |
| **MCP** | Model Context Protocol (Anthropic). Standardizes tool invocation with schema validation and access control. |
| **Resonance Score** | Aggregate trust metric [0.0, 1.0] combining task success, contradiction wins, peer attestation, and uptime. |
| **Resonance Signature** | Mandatory composite fingerprint containing public key, capabilities, model profile, and resonance score. |
| **Workflow Template** | Predefined agent pipeline (e.g., NewFeature, BugFix) with stage ordering and parallel gate definitions. |
| **Zero-Copy Arena** | Shared memory-mapped region where messages are written once and read by recipients without copy. |

---

## Appendix B: Source Links

| Source | URL | Authority |
|---|---|---|
| Multi-Agent Architectures in OpenClaw Compendium | https://gist.github.com/mmarcus006/8b3bb89cb213b6d4359bf1bb928079b3 | Community Research (Feb 2026) |
| OpenClaw Multi-Agent Orchestration FAQ | https://clawindex.app/cases/multi-agent-orchestration-specialists | Community (Mar 2026) |
| NemoClaw Review | https://www.taskade.com/blog/nemoclaw-review | Taskade (Apr 2026) |
| NVIDIA NemoClaw Docs: Sub-Agents | https://docs.nvidia.com/nemoclaw/latest/inference/set-up-sub-agent.html | Official (2026) |
| NemoClaw Security Layer | https://www.mindstudio.ai/blog/what-is-nemoclaw-nvidia-openclaw-wrapper/ | MindStudio (Mar 2026) |
| Cursor 2.0 Agent-First Guide | https://www.digitalapplied.com/blog/cursor-2-0-agent-first-architecture-guide | Digital Applied (Dec 2025) |
| Cursor 2.5 Async Subagents | https://www.reddit.com/r/cursor/comments/1r7fb0o/cursor_25_plugins_sandbox_access_controls_and/ | Reddit / Cursor (Mar 2026) |
| Parallel AI Development with Git Worktrees | https://blog.darkwood.com/article/parallel-ai-development-with-cursor-and-git-worktrees | Darkwood (Feb 2026) |
| Claude Code Cheat Sheet | https://blakecrosley.com/guides/claude-code-cheatsheet | Blake Crosley (Apr 2026) |
| Claude Code Subagents Docs | https://code.claude.com/docs/en/agent-sdk/subagents | Official Anthropic (2025) |
| Claude Code Agent Teams Guide | https://blog.laozhang.ai/en/posts/claude-4-6-agent-teams | Community (Feb 2026) |
| Claude Code Agent Teams Explained | https://newsletter.owainlewis.com/p/claude-code-agent-teams-explained | Owain Lewis (Feb 2026) |
| GodMode Skill (SKILL.md) | https://github.com/openclaw/skills/blob/main/skills/cubetribe/cc-godmode/SKILL.md | Official OpenClaw Skill |
| Multi-Agent AI Architecture Guide | https://cogitx.ai/blog/multi-agent-ai-systems-architecture-guide-for-engineering-leaders | Cogitx (Apr 2026) |
| Enterprise MAS Patterns | https://www.augmentcode.com/guides/multi-agent-ai-architecture-patterns-enterprise | AugmentCode (Mar 2026) |
| Collaborative Failure Modes in Medical MAS (arXiv) | https://arxiv.org/html/2510.10185v1 | Academic (Oct 2025) |
| OrchestRAG Framework | https://www.aijfr.com/research-paper.php?id=4100 | Academic (Mar 2026) |
| Fuzzy Voting Model for Ontology Mapping | https://www.sciencedirect.com/science/article/abs/pii/S0747563213003828 | Academic (2015) |

---

*Document synthesized from 20+ primary sources across community research, official documentation, and academic literature. All citations use inline notation `[^N^]` referencing the search result indices from the research phase.*
