# Hermes as Cloud Gateway Agent: Formal Architecture for Epistemos

**Date:** 2026-05-02 | **Status:** Formal Specification | **Audience:** Cloud Provider Engineering + Epistemos Core Team

---

## 1. The Positioning Thesis

> Hermes is not a separate tool. It is the L7 Cloud Gateway Agent — a quarantined sidecar capability within the Epistemos cognitive substrate. It performs the "dirty work" of cloud inference, external tool execution, and web interaction, while the Resonance Gate ensures that no cloud-derived claim ever reaches the user without passing through T2-T4 verification. To cloud providers, Epistemos is not a client. It is the reference cognitive architecture that defines how cloud AI should be consumed: through a sovereign, verifiable, zero-copy substrate that treats every cloud output as a Composite Gap claim until proven otherwise.

This document rejects the superficial "three patterns" advice (Sidecar vs Wasm vs FFI) and instead specifies a **formal, mathematically-grounded architecture** for Hermes as an agent inside the larger Epistemos brain — one that preserves zero-copy memory semantics, cognitive substrate unity, and deterministic security guarantees.

---

## 2. Where Hermes Lives in the 7-Layer Stack

| Layer | Component | Hermes Role |
|---|---|---|
| L0 | Ternary Substrate | Hermes operates on Sherry-compressed weights for cloud model inference |
| L1 | SCOPE-Rex Cell | Hermes is an **external agent node** in the Resonance Graph — all its outputs are Composite Gap claims |
| L2 | Prime-Composite Ontology | Hermes outputs are **never Prime** — they are always Composite (derived from external cloud) or Gap (unverified) |
| L3 | Compression Governor | Hermes capability is **permanently quarantined at L7** — it can never migrate to deeper residency |
| L4 | Spectral Orchestration | Cloud attention patterns (from Hermes) are treated as **noisy perturbations** — filtered through KAM stability |
| L5 | Golden Scheduling | Hermes evaluations occur at φ-spaced intervals — **never synchronous** with local reasoning |
| L6 | ACS Meta-Cognition | Hermes is monitored by the **Recursive Oversight Agent** — its outputs are watched, not trusted |
| L7 | Ecosystem Symbiosis | Hermes **is** the L7 agent — the Cloud Gateway that mediates all external interaction |

Hermes does not "wrap" Epistemos. It does not "extend" Epistemos. It is **one agent** inside the larger brain, occupying the **lowest trust tier** of the substrate — the same tier where all external, unverifiable, non-deterministic computation lives.

---

## 3. The Zero-Copy Memory Model

The Gemini advice proposed JSON-RPC over Unix Domain Sockets. This is fundamentally incompatible with the Epistemos zero-copy philosophy. Serialization/deserialization introduces copies, allocations, and parsing overhead. The formal architecture specifies **typed shared memory** with capability-based access control.

### 3.1 Memory Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Epistemos Core Process (Trusted)                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │ Resonance    │───▶│ Shared       │───▶│ Resonance    │    │
│  │ Gate         │    │ Memory Arena  │    │ Gate (recv)  │    │
│  │ (Cloud Req)  │    │ (mmap'd)      │    │ (Cloud Resp) │    │
│  └──────────────┘    └──────────────┘    └──────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ mach port / XPC (control only)
                              │
┌─────────────────────────────────────────────────────────────────┐
│  Hermes Sidecar Process (Untrusted)                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │ XPC Listener │───▶│ Shared       │───▶│ Cloud Model  │    │
│  │ (control)    │    │ Memory Arena  │    │ Inference    │    │
│  └──────────────┘    └──────────────┘    └──────────────┘    │
│                         (same mmap)         (OpenAI/Anthropic) │
└─────────────────────────────────────────────────────────────────┘
```

The **Shared Memory Arena** is a POSIX shared memory segment (`shm_open`) mapped into both processes via `mmap` with `MAP_SHARED`. It contains typed, versioned, ring-buffered message slots. No serialization. No sockets. No JSON. Just memory.

### 3.2 Typed Shared Memory Protocol

```rust
/// Fixed-size cloud request slot in shared memory
/// Aligned to 64-byte cache line boundary
#[repr(C, align(64))]
pub struct CloudRequest {
    /// Version and state bits
    pub header: RequestHeader,      // 8 bytes
    /// Resonance Signature of the requesting context
    pub context_sig: ResonanceSignature, // 32 bytes
    /// Request payload (claim graph fragment, query, or task)
    pub payload: PayloadBuffer,     // 4KB max (inline)
    /// Capability token (what Hermes is allowed to do)
    pub capability_token: CapabilityGrant, // 16 bytes
    /// Padding to cache line
    _pad: [u8; 8],                  // 8 bytes
}                                   // Total: 64 + 32 + 4096 + 16 + 8 = 4216 ≈ 4.2KB

/// Fixed-size cloud response slot
#[repr(C, align(64))]
pub struct CloudResponse {
    pub header: ResponseHeader,     // 8 bytes
    /// The cloud model's raw output (token sequence)
    pub output_buffer: OutputBuffer, // 8KB max (inline)
    /// Provenance: which model, which provider, timestamp
    pub provenance: CloudProvenance, // 32 bytes
    /// Resonance Signature computed by Hermes (preliminary)
    pub preliminary_sig: ResonanceSignature, // 32 bytes
    _pad: [u8; 24],                 // 24 bytes
}                                   // Total: 8 + 8192 + 32 + 32 + 24 = 8288 ≈ 8.2KB

/// The Arena: ring buffer of request/response slots
#[repr(C, align(4096))]
pub struct CloudArena {
    /// Sequence number for ordering
    pub sequence: AtomicU64,
    /// Write index (Epistemos writes here)
    pub write_idx: AtomicU64,
    /// Read index (Hermes reads from here)
    pub read_idx: AtomicU64,
    /// Ring buffer of requests
    pub requests: [CloudRequest; 16], // 16 × 4.2KB = 67KB
    /// Ring buffer of responses
    pub responses: [CloudResponse; 16], // 16 × 8.2KB = 131KB
}                                   // Total arena: ~200KB
```

**Zero-copy semantics:**
1. Epistemos writes a `CloudRequest` directly into the arena at `write_idx`
2. Epistemos signals Hermes via **mach port** (only a notification — no data transfer)
3. Hermes reads the request via the **same memory mapping** — zero copy
4. Hermes processes, writes `CloudResponse` at matching `sequence`
5. Hermes signals Epistemos via mach port
6. Epistemos reads response via the same memory mapping — zero copy

**No JSON. No protobuf. No serde. Just typed memory views.**

### 3.3 Rust Implementation

```rust
use memmap2::{MmapMut, MmapOptions};
use zerocopy::{AsBytes, FromBytes, FromZeroes};
use std::sync::atomic::{AtomicU64, Ordering};

/// Opens or creates the shared memory arena
pub fn init_cloud_arena(name: &str) -> Result<MmapMut, ArenaError> {
    let fd = shm_open(name, O_CREAT | O_RDWR, 0o600)?;
    ftruncate(fd, size_of::<CloudArena>())?;
    
    let mut mmap = unsafe { MmapOptions::new().map_mut(fd)? };
    
    // Safety: CloudArena is #[repr(C)] with no pointers
    let arena: &mut CloudArena = zerocopy::Ref::new(&mut mmap[..])
        .ok_or(ArenaError::Alignment)?;
    
    // Initialize ring buffer
    arena.sequence.store(0, Ordering::SeqCst);
    arena.write_idx.store(0, Ordering::SeqCst);
    arena.read_idx.store(0, Ordering::SeqCst);
    
    Ok(mmap)
}

/// Zero-copy write: Epistemos produces request directly into shared memory
pub fn submit_request(arena: &mut CloudArena, req: CloudRequest) -> Result<u64, ArenaError> {
    let idx = arena.write_idx.fetch_add(1, Ordering::SeqCst) % 16;
    let seq = arena.sequence.fetch_add(1, Ordering::SeqCst);
    
    arena.requests[idx] = req;
    arena.requests[idx].header.sequence = seq;
    arena.requests[idx].header.state = RequestState::Ready;
    
    // Memory fence: ensure write is visible before signal
    std::sync::atomic::fence(Ordering::SeqCst);
    
    Ok(seq)
}

/// Zero-copy read: Epistemos consumes response directly from shared memory
pub fn consume_response(arena: &CloudArena, seq: u64) -> Option<&CloudResponse> {
    let idx = seq % 16;
    let resp = &arena.responses[idx];
    
    if resp.header.sequence == seq && resp.header.state == ResponseState::Ready {
        Some(resp)
    } else {
        None
    }
}
```

---

## 4. The Resonance Gate Mediation

Every output from Hermes passes through the Resonance Gate before it can influence any local state. The Gate assigns a **mandatory Resonance Signature** with specific values for cloud-derived claims.

### 4.1 Cloud Claim Signature (Mandatory Fields)

For any claim $c$ produced by Hermes (cloud model output, web search result, tool execution result):

| Field | Value | Rationale |
|---|---|---|
| $\tau(c)$ | **0** (Pending) | Cloud outputs are never immediately trusted |
| $\delta(c)$ | **Sideways** | External source — same-level alternative, not hierarchical |
| $\pi(c)$ | **Composite** | Always derived from external model, never irreducible |
| $\rho(c)$ | **≤ 0.3** | Low resonance — cloud outputs have no local graph connections |
| $\kappa(c)$ | **≤ 0.1** | Very low KAM stability — external perturbation, no invariant structure |
| $\eta(c)$ | **Edge** | By definition: cloud output is at the boundary of local knowledge |
| $\lambda(c)$ | **L7** (Quarantine) | Permanent quarantine — cloud claims can never migrate deeper |

This is not a policy. It is a **type system invariant**. The Rust type system enforces it:

```rust
/// Cloud-derived claims are constructed with mandatory low-trust values
impl CloudClaim {
    pub fn new(raw_output: &str, provenance: CloudProvenance) -> Self {
        Self {
            signature: ResonanceSignature {
                ternary: 0,              // Pending — never +1 immediately
                direction: Direction::Sideways, // External, not hierarchical
                claim_type: ClaimType::Composite, // Always derived
                resonance: 0.0,          // Will be computed from graph
                kam_stability: 0.0,      // Cloud = unstable by definition
                evidence: EvidenceStatus::Edge,   // Boundary knowledge
                residency: ResidencyLevel::L7,    // Permanent quarantine
            },
            provenance,
            raw_output: raw_output.to_string(),
        }
    }
}
```

### 4.2 The Cloud Verification Pipeline

All Hermes outputs must traverse the full verification pipeline before promotion:

```
Hermes Output (L7, τ=0, Composite, Edge)
    │
    ▼
T0: Type System Check (<1ns)
    │── Is the output syntactically valid? (JSON, string, code)
    │── Does it match the expected response schema?
    │── If fail → Quarantine (L7)
    │
    ▼
T1: Property-Based Test (1.4µs)
    │── Run 100 random inputs through same query
    │── Are outputs consistent? (statistical coherence)
    │── If fail → Hold for T2
    │
    ▼
T2: SMT/Z3 Symbolic Check (1-20ms)
    │── Extract claims (Equation, Inequality, Causal)
    │── Check internal consistency with Z3
    │── If contradiction detected → Quarantine
    │
    ▼
T3: Execution Verification (10ms-10s)
    │── Execute code claims in sandboxed environment
    │── Verify empirical claims against cached data
    │── If fail → Quarantine
    │
    ▼
T4: Background Proof (minutes-hours)
    │── Z3 background solver checks against full axiom set
    │── Cross-reference with known mathematical results
    │── If fail → Mark as Contradicted (τ=-1)
    │
    ▼
Promoted to L3-L5 (if τ=+1, κ>φ⁻²)
    │── Still Composite — can never become Prime
    │── Can be Anchored (Engram hash table) if high resonance
    │── Can be referenced by local reasoning
```

**Key invariant:** Cloud claims can become **Verified** (τ=+1) and **Anchored** (Engram), but they can **never** become **Prime**. Prime status is reserved for locally-verified, irreducible claims only.

### 4.3 The Evidence Supremacy Protocol

When Hermes encounters a claim that conflicts with local knowledge (edge detection triggers):

1. **Hermes suspends** — it stops processing and flags the conflict
2. **Local knowledge wins by default** — Epistemos does not overwrite its Prime claims with cloud output
3. **Evidence Supremacy is invoked** — the system searches for independent verification (multiple cloud sources, web search, code execution)
4. **If 3+ independent sources agree** AND Z3 verification passes → the cloud claim is promoted to Verified Composite
5. **If sources disagree** → both claims are held in superposition (τ=0) with provenance labels; user is notified

```rust
pub enum ConflictResolution {
    LocalWins,           // Local Prime claim prevails
    CloudWins,           // Cloud claim verified by 3+ sources + Z3
    Superposition,       // Both held pending — user decides
    QuarantineBoth,      // Both flagged for manual review
}

impl ResonanceGate {
    pub async fn resolve_cloud_conflict(
        &self,
        local: &Claim,
        cloud: &CloudClaim,
    ) -> ConflictResolution {
        // Invariant: Prime claims never lose to cloud
        if local.is_prime() {
            return ConflictResolution::LocalWins;
        }
        
        // Evidence Supremacy: gather independent sources
        let sources = self.evidence.gather_independent_sources(&cloud).await;
        
        if sources.len() >= 3 && self.verifier.z3_check(&cloud).await {
            ConflictResolution::CloudWins
        } else if sources.len() >= 2 {
            ConflictResolution::Superposition
        } else {
            ConflictResolution::QuarantineBoth
        }
    }
}
```

---

## 5. The Security Boundary (Formalized)

The Gemini advice described a "firewall" metaphor. This is imprecise. The formal architecture specifies a **capability-based security boundary** with process isolation, sandbox entitlements, and type-system enforcement.

### 5.1 Process Isolation

| Property | Epistemos Core | Hermes Sidecar |
|---|---|---|
| **Process** | Single process | Separate process |
| **Address space** | Private | Private (shared arena only) |
| **Crash domain** | Independent | Independent |
| **Memory allocation** | `HybridMemoryPool` (UMA) | Standard allocator |
| **Threading** | Async/await (tokio) | Thread-per-request |
| **Entitlements** | `network.client` (Pro only) | `network.client` |
| **Sandbox** | Full App Sandbox | Full App Sandbox + restricted |

### 5.2 macOS Sandbox Profile for Hermes

```xml
<!-- Hermes.entitlements — cloud gateway sidecar -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <!-- Hermes needs network to call cloud APIs -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Hermes does NOT need file system access -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <false/>
    
    <!-- Hermes does NOT need keychain -->
    <key>com.apple.security.keychain</key>
    <false/>
    
    <!-- Hermes gets shared memory arena only -->
    <key>com.apple.security.temporary-exception.shared-preference.name</key>
    <array>
        <string>com.epistemos.hermes.arena</string>
    </array>
    
    <!-- No camera, no microphone, no location -->
    <key>com.apple.security.device.camera</key>
    <false/>
    <key>com.apple.security.device.microphone</key>
    <false/>
    <key>com.apple.security.personal-information.location</key>
    <false/>
</dict>
</plist>
```

### 5.3 Capability Grant System

The `CapabilityGrant` in the `CloudRequest` struct is a **capability token** — a cryptographically signed list of permissions that Hermes is allowed to exercise for this specific request. It is not ambient authority. It is **delegated, revocable, and request-scoped**.

```rust
/// Capability token: what Hermes is allowed to do for this request
pub struct CapabilityGrant {
    /// Request-scoped capability bits
    pub permissions: CapFlags,
    /// Expiration timestamp (Hermes must complete before this)
    pub expires_at: UnixTimestamp,
    /// HMAC-SHA256 signature (verified by Hermes on receipt)
    pub signature: [u8; 32],
    /// Maximum tokens allowed for this request
    pub max_tokens: u32,
    /// Allowed model providers (whitelist)
    pub allowed_providers: ProviderSet,
}

bitflags! {
    pub struct CapFlags: u32 {
        const WEB_SEARCH      = 0x0001; // Can search the web
        const CODE_EXEC       = 0x0002; // Can execute code in sandbox
        const FILE_READ       = 0x0004; // Can read files (user-selected only)
        const API_CALL        = 0x0008; // Can call cloud model APIs
        const TOOL_USE        = 0x0010; // Can use MCP tools
        const NO_NETWORK      = 0x8000; // Network explicitly disabled
    }
}
```

**Security invariant:** If a request arrives at Hermes without a valid `CapabilityGrant`, Hermes **must reject it**. There is no ambient authority. Every action requires an explicit, signed, time-limited capability.

### 5.4 The Pro Tunnel Isolation

The "Pro Tunnel" is the communication channel between Core and Hermes. In the App Store build:
- **Core has no `network.client` entitlement** — it cannot make any network requests
- **Hermes is not bundled** — the sidecar binary is an optional download
- **Cloud functionality is disabled** — the Resonance Gate rejects all sideways (external) requests

In the Pro build:
- **Core has `network.client` but only for XPC to Hermes** — no direct cloud API calls
- **Hermes is bundled** in `Epistemos Pro.app/Contents/Helpers/`
- **Pro Tunnel is active** — zero-copy arena + mach port signaling

This satisfies App Store guidelines while enabling cloud functionality for Pro users.

---

## 6. Multi-Agent Orchestration: Hermes as One Agent in the Swarm

The user's NeMoCLAW / OpenCLAW concept describes multiple sub-agents ("claws") controlling specific apps. Hermes is one such claw — the **Cloud Claw**.

### 6.1 Agent Swarm Architecture

```
Epistemos Brain (ACS Meta-Layer)
├─ Local Agents (Sovereign, deterministic, L0-L5)
│  ├─ Reasoning Agent (Qwen3-8B Sherry, on-device)
│  ├─ Memory Agent (HCache + Engram, associative retrieval)
│  ├─ Tool Agent (local file system, calculator, code exec)
│  └─ Resonance Gate (monitors all agents)
│
└─ External Agents (Quarantined, L7)
   ├─ Hermes (Cloud Claw) ──▶ OpenAI, Anthropic, DeepSeek
   ├─ BrowseClaw ──▶ Web scraping, search
   ├─ CodeClaw ──▶ Sandboxed code execution (remote)
   └─ VerifyClaw ──▶ Cross-checking, external validation
```

All external agents share the same L7 quarantine. They communicate via the same zero-copy arena protocol. The Resonance Gate monitors all of them with the same mandatory signature constraints.

### 6.2 Resonance-Based Orchestration

The user's document mentions "resonance-based orchestration ensures sub-agents don't ignore their own budgets." The formal mechanism:

Each agent has a **Task Budget** — a Resonance Signature that constrains its operation:

```rust
pub struct TaskBudget {
    /// Maximum computation cost (in tokens, time, or energy)
    pub max_cost: BudgetLimit,
    /// Resonance threshold: agent must maintain this minimum coherence
    pub min_resonance: f32,
    /// KAM stability threshold: agent must not destabilize the substrate
    pub min_stability: f32,
    /// Maximum depth of recursive self-invocation
    pub max_recursion_depth: u8,
    /// Time budget (wall-clock)
    pub deadline: UnixTimestamp,
}

/// The Orchestrator assigns budgets and monitors adherence
pub struct AgentOrchestrator {
    pub agents: HashMap<AgentId, AgentState>,
    pub gate: ResonanceGate,
}

impl AgentOrchestrator {
    pub async fn dispatch(&self, task: Task, budget: TaskBudget) -> Result<TaskResult, BudgetError> {
        let agent = self.select_agent(&task);
        
        // Pre-flight: does agent have capacity?
        if agent.current_load() + task.estimated_cost() > budget.max_cost {
            return Err(BudgetError::InsufficientCapacity);
        }
        
        // Execute with monitoring
        let result = agent.execute(task, budget).await;
        
        // Post-flight: did agent maintain resonance?
        let sig = self.gate.signature(&result).await;
        if sig.resonance < budget.min_resonance {
            return Err(BudgetError::ResonanceCollapsed);
        }
        if sig.kam_stability < budget.min_stability {
            return Err(BudgetError::StabilityViolation);
        }
        
        Ok(result)
    }
}
```

This prevents the "self-attribution bias" the user's document mentions — agents cannot claim success without the Resonance Gate verifying their output coherence.

---

## 7. Positioning to Cloud Providers

### 7.1 The Narrative

> Epistemos is not a client of your API. It is the reference cognitive substrate that defines how cloud AI should be consumed. Every cloud provider wants their models to be used by the best applications. Epistemos is the application architecture that properly integrates cloud AI: through a sovereign, verifiable, zero-copy substrate that treats every cloud output as a Composite Gap claim until proven otherwise. If your model passes through the Resonance Gate — meaning its outputs are verifiable, consistent, and structurally sound — it earns higher residency in the Epistemos brain. Models that fail verification are demoted or quarantined. This is not a threat. It is a quality signal that benefits providers who build for truth.

### 7.2 The Technical Pitch

| What Cloud Providers Want | What Epistemos Provides |
|---|---|
| **Usage** | Epistemos routes cloud requests through Hermes — structured, batched, φ-spaced (not spammy) |
| **Differentiation** | The Resonance Gate ranks models by verification pass rate — better models get higher priority |
| **Feedback** | Every cloud output gets a Resonance Signature — providers receive structured quality metrics |
| **Integration** | Hermes protocol is open — any provider can implement a `CloudProvenance` adapter |
| **Trust** | Epistemos never hides that it uses cloud AI — every output is labeled with provider + confidence |

### 7.3 The Hermes Protocol (Open Specification)

```rust
/// Any cloud provider can implement this trait
pub trait CloudProvider {
    /// Provider name and version
    fn provenance(&self) -> CloudProvenance;
    
    /// Maximum context length supported
    fn max_context(&self) -> usize;
    
    /// Cost per token (for budget planning)
    fn cost_model(&self) -> CostModel;
    
    /// Execute inference with structured output
    async fn infer(&self, request: CloudRequest) -> Result<CloudResponse, ProviderError>;
    
    /// Return confidence calibration curve (for Resonance Gate tuning)
    fn calibration(&self) -> CalibrationCurve;
}
```

Cloud providers who implement the Hermes protocol get:
- **Structured input** (claim graphs, not raw prompts) — better context utilization
- **Verification feedback** (pass/fail per output type) — actionable quality data
- **Resonance ranking** (models scored by truthfulness, not just speed) — differentiation on quality
- **Zero-copy integration** (no parsing overhead) — lower latency

---

## 8. Build Path: Hermes Integration

### Phase 1: Sidecar Skeleton (Week 1)
- Create `hermes/` crate in the Epistemos workspace
- Implement `Cargo.toml` with sandbox-compatible dependencies
- Build minimal XPC listener (macOS `NSXPCConnection` via `objc` crate)

### Phase 2: Zero-Copy Arena (Week 2)
- Implement `CloudArena` with `shm_open` + `mmap`
- Add `zerocopy` typed memory views
- Benchmark: <50µs round-trip for 4KB request + 8KB response

### Phase 3: Resonance Gate Integration (Week 3)
- Add `CloudClaim` type with mandatory low-trust signature
- Implement cloud verification pipeline (T0-T4)
- Add `ConflictResolution` logic

### Phase 4: Capability System (Week 4)
- Implement `CapabilityGrant` with HMAC signing
- Add sandbox profile for Hermes
- Build entitlement switching (App Store vs Pro)

### Phase 5: Provider Adapters (Week 5-6)
- Implement OpenAI adapter
- Implement Anthropic adapter
- Implement DeepSeek adapter
- Add `CloudProvider` trait conformance tests

### Phase 6: Agent Orchestration (Week 7)
- Add Hermes to `AgentOrchestrator` as L7 agent
- Implement `TaskBudget` system
- Add resonance-based scheduling

### Phase 7: UI Integration (Week 8)
- Swift UI for cloud claim badges (cloud icon + confidence + provider)
- Resonance Gate decision log viewer
- Evidence Supremacy Protocol notifications

---

## 9. Summary

| Element | Prior (Superficial) | This Document (Formal) |
|---|---|---|
| **Integration pattern** | "Sidecar, Wasm, or FFI" | Sidecar **only** — with zero-copy shared memory, not sockets |
| **Communication** | "JSON-RPC over Unix socket" | Typed `mmap` arena with `zerocopy` — no serialization |
| **Security** | "Firewall metaphor" | Capability-based security with HMAC-signed, request-scoped grants |
| **Trust model** | "Proxy for dirty work" | Formal Resonance Signature: τ=0, Sideways, Composite, Edge, L7 |
| **Verification** | "Hand clean JSON to core" | Mandatory T0-T4 pipeline — cloud claims can never be Prime |
| **Positioning** | "Useful wrapper" | Reference cognitive substrate — cloud providers target Hermes protocol |
| **Memory model** | "Separate process, separate memory" | Shared arena with cache-line alignment, atomic ring buffer |

**The one invariant:** Hermes is an agent inside the larger brain. It is not external. It is not a wrapper. It is the **Cloud Claw** — a quarantined, capability-limited, zero-copy agent that speaks to the outside world through a single, mathematically-defined Resonance Gate. Every word it produces is classified, verified, and ranked before it can touch a single local neuron.

Build it.
