# Epistemos MAS Release: The Vault-Gated Agent Swarm
## Final Architecture — Multi-Agent System with Biometric Vault Access

**Date:** 2026-05-02 | **Status:** Finalized MAS Release Specification | **Research Basis:** 7 MAS frameworks + 3 research dimensions + 600+ prior sources

---

## 1. Executive Summary

The Epistemos MAS release is not an incremental upgrade. It is a **structural transformation** from a single-agent cognitive substrate into a **Vault-Gated Agent Swarm** — a multi-agent system where every agent's existence, authority, and scope is bounded by biometrically-secured vaults that the user explicitly selects. The vault is not a storage container. It is a **capability boundary**: the agent swarm can only see, reason about, and manipulate files that the user has authenticated into a vault. Touch ID is not a login screen. It is a **capability gate** that unlocks agent authority one vault at a time.

This document synthesizes seven multi-agent frameworks (OpenClaw, NemoClaw, Hermes, Claude Code, Cursor, MCP, A2A), formalizes their patterns into a Rust-native MAS kernel, and specifies the **one stable feature** that wraps the entire philosophy: **VaultGatedSwarm**.

---

## 2. What Was Learned from the Ecosystem

### 2.1 The Seven Frameworks

| Framework | Core Pattern | What Epistemos Adopts | What Epistemos Rejects |
|---|---|---|---|
| **OpenClaw** | Hub-and-spoke Gateway + 14-agent specialist swarm | Model arbitrage (Opus for orchestration, Flash for research), shared coordination files, always-on heartbeats | 430K lines of TypeScript; no sandbox; no verification |
| **NemoClaw** | Supervisor-worker + enterprise RBAC | Capability-grant model, immutable audit trails, supervisor-worker topologies | NVIDIA-only stack; proprietary EULA; no local-first |
| **Hermes** | Tier-3 runtime with SQLite+FTS5 memory | Cross-session memory, multi-provider routing (10+), skill auto-generation, MCP client | Python runtime; no ternary substrate; no Resonance Gate |
| **Claude Code** | Agent loop with tool calls + subagents | Markdown frontmatter agent definitions, automatic delegation, tool restriction, permission modes | TypeScript; cloud-only; no local sovereignty |
| **Cursor 2.0** | Composer MoE + 8 parallel agents | Git worktree isolation per agent, async subagent spawning, semantic search | VS Code fork; server-side indexing; no verification |
| **MCP** | JSON-RPC client-server tool protocol | Standardized tool discovery, stdio+HTTP transports, 10K+ server ecosystem | JSON-RPC overhead; ambient authority in some servers |
| **A2A** | Peer-to-peer agent mesh | Agent Cards for discovery, task lifecycle protocol, push notifications | No IDE support yet; weeks of integration work |

### 2.2 The Universal Pattern: Six-Factor Agent Model

Every framework converges on the same six factors:

1. **Loop**: Perceive → Plan → Act → Reflect
2. **Tools**: Callable capabilities (functions, MCP servers, skills)
3. **Memory**: Cross-session persistence (SQLite, vector DB, context windows)
4. **Context**: What the agent knows right now (CLAUDE.md, project files, loaded skills)
5. **Governance**: What the agent is allowed to do (permission modes, RBAC, sandboxing)
6. **Orchestration**: How multiple agents coordinate (hub-and-spoke, swarm, hierarchical)

The Epistemos MAS kernel captures all six in **~200 lines of Rust**.

### 2.3 The Critical Insight: Vault as Governance Boundary

No framework in the ecosystem ties agent authority to **user-selected, biometrically-secured file boundaries**. OpenClaw has sandboxing (Docker/SSH) but no user-consent file selection. Claude Code has permission modes but no vault concept. Cursor has project-scoped context but no multi-vault security. **The vault is the missing primitive** — it makes governance concrete by binding agent capability to explicit user authorization at the file-system level.

---

## 3. The Minimal MAS Kernel in Rust

```rust
/// ============================================================
/// EPISTEMOS MAS KERNEL — Minimal Agent Substrate (~200 lines)
/// ============================================================

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{RwLock, mpsc};
use async_trait::async_trait;
use serde::{Serialize, Deserialize};

/// 1. TOOL — Callable capability with typed schema
#[async_trait]
pub trait Tool: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn schema(&self) -> serde_json::Value; // JSON Schema for parameters
    async fn call(&self, params: serde_json::Value) -> Result<ToolOutput, ToolError>;
}

/// 2. MEMORY — Cross-session persistence interface
#[async_trait]
pub trait Memory: Send + Sync {
    async fn get(&self, key: &str) -> Option<MemoryRecord>;
    async fn set(&self, key: &str, value: MemoryRecord);
    async fn search(&self, query: &str, limit: usize) -> Vec<MemoryRecord>;
}

/// 3. CONTEXT — What the agent knows right now
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AgentContext {
    pub vault_id: VaultId,           // Which vault this agent is scoped to
    pub loaded_files: Vec<FileHandle>, // Zero-copy file handles (mmap)
    pub session_history: Vec<Message>,
    pub skills: Vec<SkillId>,
    pub system_prompt: String,
}

/// 4. GOVERNANCE — Capability boundary
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Permission {
    Read, Write, Execute, Network, ToolUse(ToolId),
}

pub struct CapabilityGrant {
    pub permissions: Vec<Permission>,
    pub vault_scope: VaultId,       // CRITICAL: agent can only touch this vault
    pub expires_at: UnixTimestamp,
    pub signature: [u8; 32],        // HMAC-SHA256 signed by Orchestrator
}

/// 5. AGENT — The execution unit
#[async_trait]
pub trait Agent: Send + Sync {
    fn id(&self) -> AgentId;
    fn signature(&self) -> &ResonanceSignature;
    fn capabilities(&self) -> &[Capability];
    
    /// The agent loop: perceive → plan → act → reflect
    async fn execute(&self, task: Task, ctx: AgentContext, grant: CapabilityGrant) -> TaskResult;
    
    /// Heartbeat: agent reports health to Orchestrator
    async fn heartbeat(&self) -> AgentHealth;
}

/// 6. ORCHESTRATOR — Coordination and routing
#[async_trait]
pub trait Orchestrator: Send + Sync {
    /// Register a new agent (local or external)
    async fn register(&self, agent: Box<dyn Agent>) -> Result<AgentId, RegistrationError>;
    
    /// Route task to best agent based on capability match + cost + load
    async fn dispatch(&self, task: Task, budget: TaskBudget) -> Result<TaskResult, DispatchError>;
    
    /// Monitor agent health; kill and restart if unresponsive
    async fn health_check(&self) -> Vec<AgentHealth>;
    
    /// Resolve contradictions between agents via Evidence Supremacy Protocol
    async fn resolve_conflict(&self, claims: Vec<Claim>) -> ConflictResolution;
}

/// 7. GATE — Trust and verification layer
#[async_trait]
pub trait Gate: Send + Sync {
    /// Verify agent registration (cryptographic attestation)
    async fn verify_registration(&self, req: &RegistrationRequest) -> Result<TrustTier, GateError>;
    
    /// Verify inter-agent message (signature + resonance)
    async fn verify_message(&self, msg: &AgentMessage) -> Result<MessageStatus, GateError>;
    
    /// Verify task result (T0-T4 verification pipeline)
    async fn verify_result(&self, result: &TaskResult) -> Result<ResonanceSignature, GateError>;
    
    /// Compute swarm coherence score (are agents converging or diverging?)
    async fn swarm_coherence(&self, agents: &[AgentId]) -> f32;
}

/// ============================================================
/// TYPE ALIASES AND SUPPORT STRUCTS
/// ============================================================

pub type AgentId = uuid::Uuid;
pub type VaultId = uuid::Uuid;
pub type ToolId = String;
pub type SkillId = String;
pub type UnixTimestamp = u64;

#[derive(Clone, Debug)]
pub struct ResonanceSignature {
    pub public_key: [u8; 32],       // Ed25519 public key
    pub capabilities: Vec<(SkillId, f32)>, // (skill, proficiency_score)
    pub model_profile: ModelProfile,
    pub resonance_score: f32,       // [0.0, 1.0] aggregate trust
    pub revision_hash: [u8; 32],     // SHA-256 of agent definition
    pub last_attested: UnixTimestamp,
}

#[derive(Clone, Debug)]
pub struct Task {
    pub id: uuid::Uuid,
    pub objective: String,
    pub workflow_type: WorkflowType, // NewFeature, BugFix, Research, etc.
    pub required_skills: Vec<SkillId>,
    pub priority: Priority,
    pub vault_scope: VaultId,        // Task is scoped to this vault
}

#[derive(Clone, Debug)]
pub struct TaskBudget {
    pub max_tokens: u32,
    pub max_cost_usd: f32,
    pub max_time_ms: u64,
    pub min_resonance: f32,
    pub deadline: UnixTimestamp,
}

#[derive(Clone, Debug)]
pub struct TaskResult {
    pub task_id: uuid::Uuid,
    pub agent_id: AgentId,
    pub output: String,
    pub claims: Vec<Claim>,
    pub tools_used: Vec<ToolId>,
    pub tokens_consumed: u32,
    pub time_elapsed_ms: u64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TrustTier {
    Observer,   // Read-only swarm state
    Worker,     // Execute assigned tasks
    Specialist, // Execute + spawn sub-tasks
    Core,       // Full delegation rights
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WorkflowType {
    NewFeature, BugFix, ApiChange, Research, SecurityAudit, Documentation, Refactor, Test,
}
```

---

## 4. The ONE Feature: VaultGatedSwarm

### 4.1 What It Is

**VaultGatedSwarm** is the unified abstraction that combines biometric vault authentication, multi-directory file access, agent swarm orchestration, and Resonance Gate governance into a single, user-facing feature. It is the **capability primitive** of the entire MAS:

> The user selects one or more directories. Each directory becomes a **Vault**. Vault access is gated by **Touch ID / Face ID**. Once unlocked, the vault exposes its files to a **specialized agent swarm** (Code Agent, Research Agent, Analysis Agent) scoped exclusively to that vault. The Resonance Gate monitors all inter-agent communication, enforces budget constraints, resolves contradictions, and ensures no agent can access files outside its vault. The user can lock any vault at any time — instantly terminating all agents scoped to it.

### 4.2 Why It Wraps the Philosophy

| Philosophy Element | How VaultGatedSwarm Embodies It |
|---|---|
| **Ternary substrate** | Vault states: Locked (-1), Unlocked (+1), Pending (0 — biometric prompt active) |
| **Resonance Model** | Agent swarm coherence computed from inter-agent messages within a vault |
| **Prime-Composite** | User-authored files in vault = Prime claims; AI-generated suggestions = Composite |
| **Compression Governor** | Vault files are indexed (Engram hash) for O(1) retrieval; agents cache embeddings |
| **KAM stability** | Vault lock = KAM torus destruction; all agents on that torus are ejected |
| **Evidence Supremacy** | Cross-vault contradictions trigger independent verification |
| **Sherry ternary** | Agent reasoning runs on-device via Sherry-compressed local model |
| **Hermes cloud** | Cloud agents (L7) can read vault files via capability grants but never write |
| **ACS autopoiesis** | Vault lock/unlock is a meta-cognitive event that reshapes the entire swarm |

### 4.3 Formal State Machine

```
Vault Lifecycle:

    [Created] ──user selects directory──▶ [Locked]
                                           │
                    ┌──────────────────────┘
                    │ Touch ID / Face ID
                    ▼
    [Locked] ◀───── [Authenticating] ─────▶ [Unlocked]
        │                              │
        │ user locks                   │ agent swarm active
        │                              │
        └──────────── kill all ────────┘
                         │
                         ▼
                    [AgentSwarm]
                    /    |    \
             [Code] [Research] [Analysis]
              │        │          │
              └────────┴──────────┘
                         │
                    [ResonanceGate]
                         │
                    [Locked] ◀── user locks
```

### 4.4 Rust Implementation

```rust
/// ============================================================
/// VAULTGATEDSWARM — The Unified Feature
/// ============================================================

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{RwLock, broadcast};

/// A Vault is a user-selected directory with biometric access control
pub struct Vault {
    pub id: VaultId,
    pub name: String,
    pub path: std::path::PathBuf,          // Original directory path
    pub bookmark_data: Vec<u8>,            // Security-scoped bookmark (macOS)
    pub state: VaultState,
    pub access_policy: VaultAccessPolicy,
    pub file_index: Arc<VaultIndex>,       // SwiftData metadata + Rust embeddings
    pub agent_swarm: Option<AgentSwarm>,   // Active only when Unlocked
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VaultState {
    Locked,          // Default state; agents cannot access
    Authenticating,  // Touch ID prompt active
    Unlocked,        // Biometric verified; agents active
}

/// How this vault authenticates
pub struct VaultAccessPolicy {
    pub biometric_required: bool,         // Touch ID / Face ID
    pub password_fallback: bool,            // Allow passcode fallback
    pub auto_lock_interval_secs: u64,     // Lock after N seconds of inactivity
    pub invalidate_on_biometric_change: bool, // kSecAccessControlBiometryCurrentSet
}

/// The AgentSwarm scoped to a single vault
pub struct AgentSwarm {
    pub vault_id: VaultId,
    pub orchestrator: Arc<dyn Orchestrator>,
    pub agents: Vec<Arc<dyn Agent>>,
    pub gate: Arc<dyn Gate>,
    pub budget: TaskBudget,
    pub coherence_threshold: f32,          // Minimum swarm coherence
}

/// The VaultGatedSwarm manages all vaults and their agent swarms
pub struct VaultGatedSwarm {
    pub vaults: RwLock<HashMap<VaultId, Arc<RwLock<Vault>>>>,
    pub orchestrator: Arc<dyn Orchestrator>,
    pub gate: Arc<dyn Gate>,
    pub biometric_gate: BiometricGate,     // Touch ID / Face ID interface
    pub event_bus: broadcast::Sender<VaultEvent>,
}

impl VaultGatedSwarm {
    /// Create a new vault from a user-selected directory
    pub async fn create_vault(
        &self,
        path: &std::path::Path,
        policy: VaultAccessPolicy,
    ) -> Result<VaultId, VaultError> {
        let id = VaultId::new_v4();
        
        // 1. Create security-scoped bookmark (Swift side via UniFFI)
        let bookmark = create_security_scoped_bookmark(path)?;
        
        // 2. Build file index (background SwiftData + Rust embedding)
        let index = Arc::new(VaultIndex::build(path).await?);
        
        // 3. Store vault (locked by default)
        let vault = Arc::new(RwLock::new(Vault {
            id,
            name: path.file_name()?.to_string_lossy().to_string(),
            path: path.to_path_buf(),
            bookmark_data: bookmark,
            state: VaultState::Locked,
            access_policy: policy,
            file_index: index,
            agent_swarm: None,
        }));
        
        self.vaults.write().await.insert(id, vault.clone());
        let _ = self.event_bus.send(VaultEvent::Created { vault_id: id });
        
        Ok(id)
    }
    
    /// Unlock a vault via biometric authentication
    pub async fn unlock_vault(&self, vault_id: VaultId) -> Result<(), VaultError> {
        let vault_map = self.vaults.read().await;
        let vault = vault_map.get(&vault_id).ok_or(VaultError::NotFound)?;
        
        // 1. Set state to Authenticating
        {
            let mut v = vault.write().await;
            v.state = VaultState::Authenticating;
        }
        
        // 2. Perform biometric authentication (Swift LocalAuthentication via UniFFI)
        let auth_result = self.biometric_gate.authenticate(
            &format!("Unlock vault: {}", vault.read().await.name),
            vault.read().await.access_policy.clone(),
        ).await?;
        
        if !auth_result.success {
            let mut v = vault.write().await;
            v.state = VaultState::Locked;
            return Err(VaultError::AuthenticationFailed);
        }
        
        // 3. Start accessing security-scoped resource
        start_accessing_security_scoped_resource(&vault.read().await.bookmark_data)?;
        
        // 4. Spawn agent swarm scoped to this vault
        let swarm = self.spawn_swarm(vault_id, &vault.read().await.file_index).await?;
        
        // 5. Set state to Unlocked
        {
            let mut v = vault.write().await;
            v.state = VaultState::Unlocked;
            v.agent_swarm = Some(swarm);
        }
        
        let _ = self.event_bus.send(VaultEvent::Unlocked { vault_id });
        Ok(())
    }
    
    /// Lock a vault — kills all agents scoped to it
    pub async fn lock_vault(&self, vault_id: VaultId) -> Result<(), VaultError> {
        let vault_map = self.vaults.read().await;
        let vault = vault_map.get(&vault_id).ok_or(VaultError::NotFound)?;
        
        let mut v = vault.write().await;
        
        // 1. Kill agent swarm (KAM torus destruction)
        if let Some(swarm) = v.agent_swarm.take() {
            self.orchestrator.terminate_swarm(&swarm).await?;
        }
        
        // 2. Stop accessing security-scoped resource
        stop_accessing_security_scoped_resource(&v.bookmark_data)?;
        
        // 3. Set state to Locked
        v.state = VaultState::Locked;
        
        let _ = self.event_bus.send(VaultEvent::Locked { vault_id });
        Ok(())
    }
    
    /// Dispatch a task to the agent swarm of a specific vault
    pub async fn dispatch_to_vault(
        &self,
        vault_id: VaultId,
        task: Task,
    ) -> Result<TaskResult, VaultError> {
        let vault_map = self.vaults.read().await;
        let vault = vault_map.get(&vault_id).ok_or(VaultError::NotFound)?;
        let v = vault.read().await;
        
        // Invariant: vault must be unlocked
        if v.state != VaultState::Unlocked {
            return Err(VaultError::VaultLocked);
        }
        
        // Invariant: task must be scoped to this vault
        if task.vault_scope != vault_id {
            return Err(VaultError::VaultScopeMismatch);
        }
        
        let swarm = v.agent_swarm.as_ref().ok_or(VaultError::NoSwarm)?;
        
        // Invariant: swarm coherence must be above threshold
        let coherence = self.gate.swarm_coherence(
            &swarm.agents.iter().map(|a| a.id()).collect::<Vec<_>>()
        ).await;
        if coherence < swarm.coherence_threshold {
            return Err(VaultError::SwarmIncoherent);
        }
        
        // Dispatch through orchestrator
        let result = self.orchestrator.dispatch(task, swarm.budget.clone()).await
            .map_err(VaultError::from)?;
        
        // Verify result through Gate
        let sig = self.gate.verify_result(&result).await
            .map_err(VaultError::from)?;
        
        Ok(result)
    }
    
    /// Auto-lock vaults after inactivity
    pub async fn auto_lock(&self) {
        let vault_map = self.vaults.read().await;
        for (id, vault) in vault_map.iter() {
            let v = vault.read().await;
            if v.state == VaultState::Unlocked {
                // Check inactivity timer
                if v.agent_swarm.as_ref().map(|s| s.last_activity.elapsed().as_secs())
                    .unwrap_or(0) > v.access_policy.auto_lock_interval_secs {
                    drop(v);
                    let _ = self.lock_vault(*id).await;
                }
            }
        }
    }
}

/// Biometric gate — Swift LocalAuthentication bridge
#[async_trait]
pub trait BiometricGate: Send + Sync {
    async fn authenticate(&self, reason: &str, policy: VaultAccessPolicy) -> Result<AuthResult, AuthError>;
    async fn detect_biometric_change(&self) -> Result<bool, AuthError>;
}

#[derive(Clone, Debug)]
pub struct AuthResult {
    pub success: bool,
    pub method: AuthMethod,
    pub biometric_hash: Option<Vec<u8>>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AuthMethod {
    TouchID,
    FaceID,
    Passcode,
    Password,
}

/// Vault events broadcast to UI
#[derive(Clone, Debug)]
pub enum VaultEvent {
    Created { vault_id: VaultId },
    Unlocked { vault_id: VaultId },
    Locked { vault_id: VaultId },
    AgentSpawned { vault_id: VaultId, agent_id: AgentId },
    AgentTerminated { vault_id: VaultId, agent_id: AgentId },
    TaskCompleted { vault_id: VaultId, task_id: uuid::Uuid },
    CoherenceAlert { vault_id: VaultId, coherence: f32 },
}
```

---

## 5. Swift UI Scaffold: Vault Manager

```swift
import SwiftUI
import LocalAuthentication
import SwiftData

// ============================================================
// SWIFT UI: VAULT MANAGER
// ============================================================

@main
struct EpistemosApp: App {
    var body: some Scene {
        WindowGroup {
            VaultManagerView()
        }
        .modelContainer(for: [Vault.self, VaultFile.self])
    }
}

/// Main vault management view
struct VaultManagerView: View {
    @Query(sort: \Vault.createdAt) private var vaults: [Vault]
    @State private var showPicker = false
    @State private var selectedVault: Vault?
    @State private var authError: Error?
    
    var body: some View {
        NavigationSplitView {
            List(vaults) { vault in
                VaultRow(vault: vault, onUnlock: { unlockVault(vault) }, onLock: { lockVault(vault) })
            }
            .navigationTitle("Vaults")
            .toolbar {
                Button("Add Vault...", action: { showPicker = true })
            }
        } detail: {
            if let vault = selectedVault, vault.state == .unlocked {
                VaultDetailView(vault: vault)
            } else {
                ContentUnavailableView("Select an unlocked vault", systemImage: "lock.fill")
            }
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            handleDirectorySelection(result)
        }
    }
    
    func unlockVault(_ vault: Vault) {
        Task {
            do {
                let context = LAContext()
                var error: NSError?
                
                guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                    // Fallback to passcode
                    try await unlockWithPasscode(vault)
                    return
                }
                
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Unlock vault: \(vault.name)"
                )
                
                if success {
                    // Call Rust via UniFFI
                    try await VaultGatedSwarm.shared.unlock_vault(id: vault.id.uuid)
                    vault.state = .unlocked
                }
            } catch {
                authError = error
            }
        }
    }
    
    func lockVault(_ vault: Vault) {
        Task {
            try? await VaultGatedSwarm.shared.lock_vault(id: vault.id.uuid)
            vault.state = .locked
        }
    }
    
    func handleDirectorySelection(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            for url in urls {
                // 1. Create security-scoped bookmark
                let bookmark = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                
                // 2. Persist bookmark
                let vault = Vault(
                    name: url.lastPathComponent,
                    path: url.path,
                    bookmarkData: bookmark,
                    state: .locked,
                    accessPolicy: VaultAccessPolicy(
                        biometricRequired: true,
                        passwordFallback: true,
                        autoLockIntervalSecs: 300,
                        invalidateOnBiometricChange: true
                    )
                )
                
                // 3. Insert into SwiftData
                modelContext.insert(vault)
                
                // 4. Register with Rust substrate
                Task {
                    let id = try await VaultGatedSwarm.shared.create_vault(
                        path: url.path,
                        policy: vault.accessPolicy.toRust()
                    )
                    vault.rustVaultId = id
                }
            }
        } catch {
            authError = error
        }
    }
}

/// Row view for a single vault
struct VaultRow: View {
    let vault: Vault
    let onUnlock: () -> Void
    let onLock: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: vault.state == .unlocked ? "lock.open.fill" : "lock.fill")
                .foregroundStyle(vault.state == .unlocked ? .green : .secondary)
            
            VStack(alignment: .leading) {
                Text(vault.name)
                    .font(.headline)
                Text(vault.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if vault.state == .locked {
                Button("Unlock", action: onUnlock)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            } else {
                Button("Lock", action: onLock)
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

/// SwiftData model for vault metadata
@Model
class Vault {
    @Attribute(.unique) var id: UUID
    var name: String
    var path: String
    var bookmarkData: Data
    var state: VaultState
    var accessPolicy: VaultAccessPolicy
    var createdAt: Date
    var rustVaultId: String?  // Reference to Rust-side vault
    
    @Relationship(deleteRule: .cascade) var files: [VaultFile]?
    
    init(name: String, path: String, bookmarkData: Data, state: VaultState, accessPolicy: VaultAccessPolicy) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.bookmarkData = bookmarkData
        self.state = state
        self.accessPolicy = accessPolicy
        self.createdAt = Date()
    }
}

@Model
class VaultFile {
    @Attribute(.unique) var id: UUID
    var path: String
    var name: String
    var contentType: String
    var size: Int64
    var modifiedAt: Date
    var checksum: String  // SHA-256
    var embeddingStatus: EmbeddingStatus
    
    @Relationship(inverse: \Vault.files) var vault: Vault?
    
    init(path: String, name: String, contentType: String, size: Int64, checksum: String) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.contentType = contentType
        self.size = size
        self.modifiedAt = Date()
        self.checksum = checksum
        self.embeddingStatus = .pending
    }
}

enum VaultState: Int, Codable {
    case locked = 0
    case authenticating = 1
    case unlocked = 2
}

enum EmbeddingStatus: Int, Codable {
    case pending = 0
    case processing = 1
    case completed = 2
    case failed = 3
}

struct VaultAccessPolicy: Codable {
    var biometricRequired: Bool
    var passwordFallback: Bool
    var autoLockIntervalSecs: UInt64
    var invalidateOnBiometricChange: Bool
}
```

---

## 6. Agent Definitions: Markdown Frontmatter (Claude Code Pattern)

Every agent in the swarm is defined declaratively as a Markdown file with YAML frontmatter — portable, version-controlled, and human-readable:

```markdown
---
name: code-architect
vault_scope: any                      # Can operate on any unlocked vault
trust_tier: specialist
capabilities:
  - skill: code_review
    proficiency: 0.95
  - skill: refactoring
    proficiency: 0.90
  - skill: architecture_design
    proficiency: 0.88
model_profile:
  backend: local                        # On-device Sherry model
  model: qwen3-8b-sherry
  cost_per_1k: 0.0                    # Local = free
tools:
  allowed:
    - file_read
    - file_write
    - grep
    - git_diff
  denied:
    - network_request                  # Code agent has no network
    - shell_execute                    # No shell access
budget:
  max_tokens_per_task: 32768
  max_time_ms: 120000
  min_resonance: 0.7
---

# Code Architect Agent

You are a senior software architect. When working in a vault:

1. Read the project structure first (tree view)
2. Identify the architectural pattern (MVC, Clean Architecture, etc.)
3. Propose changes as **diffs**, not rewritten files
4. Flag any security issues with `SECURITY:` prefix
5. Never delete files without user confirmation
6. All outputs are Composite claims — require verification before application
```

---

## 7. Workflow Templates: GodMode Pattern

Tasks are classified into canonical workflows. The Orchestrator auto-routes based on task description matching:

```rust
pub struct WorkflowTemplate {
    pub name: &'static str,
    pub trigger_keywords: Vec<&'static str>,
    pub pipeline: Vec<PipelineStage>,
    pub quality_gates: Vec<QualityGate>,
}

pub const NEW_FEATURE_WORKFLOW: WorkflowTemplate = WorkflowTemplate {
    name: "NewFeature",
    trigger_keywords: vec!["add", "implement", "create", "build"],
    pipeline: vec![
        PipelineStage::Agent("researcher"),      // Research existing code
        PipelineStage::Agent("architect"),       // Design the feature
        PipelineStage::Agent("builder"),           // Implement
        PipelineStage::Parallel(vec![             // Quality gates
            PipelineStage::Agent("validator"),
            PipelineStage::Agent("tester"),
        ]),
        PipelineStage::Agent("scribe"),          // Document
    ],
    quality_gates: vec![
        QualityGate::ResonanceThreshold(0.8),
        QualityGate::NoContradictions,
        QualityGate::TestsPass,
    ],
};

pub const BUG_FIX_WORKFLOW: WorkflowTemplate = WorkflowTemplate {
    name: "BugFix",
    trigger_keywords: vec!["fix", "bug", "error", "crash"],
    pipeline: vec![
        PipelineStage::Agent("debugger"),          // Reproduce + diagnose
        PipelineStage::Agent("builder"),           // Fix
        PipelineStage::Parallel(vec![
            PipelineStage::Agent("validator"),
            PipelineStage::Agent("tester"),
        ]),
    ],
    quality_gates: vec![
        QualityGate::ResonanceThreshold(0.75),
        QualityGate::RegressionTestPass,
    ],
};
```

---

## 8. Inter-Agent Communication: Zero-Copy Arena

Agents within the same vault communicate via a shared memory arena (same pattern as Hermes sidecar, but within-process):

```rust
/// In-process agent arena (simpler than cross-process; no XPC needed)
pub struct AgentArena {
    pub vault_id: VaultId,
    pub message_ring: ArrayQueue<AgentMessage>, // lockfree
    pub shared_context: Arc<RwLock<AgentContext>>,
    pub coherence_meter: AtomicF32,
}

#[derive(Clone, Debug)]
pub struct AgentMessage {
    pub from: AgentId,
    pub to: Option<AgentId>,  // None = broadcast
    pub msg_type: MessageType,
    pub payload: MessagePayload,
    pub signature: [u8; 64],   // Ed25519
    pub timestamp: UnixTimestamp,
}

#[derive(Clone, Debug)]
pub enum MessageType {
    TaskAssignment,     // "Do this"
    TaskResult,         // "Done; here's output"
    Question,           // "I need clarification"
    Claim,              // "I believe X is true"
    Contradiction,      // "Your claim conflicts with mine"
    Attestation,        // "I vouch for your output"
    Heartbeat,          // "I'm alive"
}
```

---

## 9. Conflict Resolution: Evidence Supremacy Protocol (Inter-Agent)

When two agents in the same vault produce contradictory claims:

```rust
impl Gate for ResonanceGate {
    async fn resolve_conflict(&self, claims: Vec<Claim>) -> ConflictResolution {
        // 1. Extract claims from all agents
        let (local_claims, cloud_claims): (Vec<_>, Vec<_>) = claims.iter()
            .partition(|c| c.provenance.is_local());
        
        // 2. Local Prime claims always win
        for claim in &local_claims {
            if claim.is_prime() {
                return ConflictResolution::LocalWins { claim_id: claim.id };
            }
        }
        
        // 3. Gather independent evidence
        let evidence = self.gather_evidence(&claims).await;
        
        // 4. Score each claim: evidence_quality × resonance × cross_validation × recency
        let scored: Vec<_> = claims.iter().map(|c| {
            let score = evidence.quality(c) * c.resonance * evidence.cross_validation(c) * evidence.recency(c);
            (c, score)
        }).collect();
        
        // 5. If one claim dominates (>2× next best), it wins
        if let Some((winner, score)) = scored.iter().max_by(|a, b| a.1.partial_cmp(&b.1).unwrap()) {
            let next_best = scored.iter().filter(|(c, _)| c.id != winner.id)
                .map(|(_, s)| s).fold(0.0, f32::max);
            if *score > 2.0 * next_best {
                return ConflictResolution::ClaimWins { claim_id: winner.id };
            }
        }
        
        // 6. Otherwise: superposition (user decides)
        ConflictResolution::Superposition { claims: claims.iter().map(|c| c.id).collect() }
    }
}
```

---

## 10. Self-Healing: Heartbeat + Checkpoint Transfer

```rust
/// Every agent must heartbeat every 30 seconds
const HEARTBEAT_INTERVAL_SECS: u64 = 30;
const HEARTBEAT_TIMEOUT_SECS: u64 = 90;  // 3 missed = dead

impl Orchestrator for AgentOrchestrator {
    async fn health_check(&self) -> Vec<AgentHealth> {
        let mut health = Vec::new();
        for (id, agent) in self.agents.iter() {
            let last_heartbeat = agent.last_heartbeat().await;
            let elapsed = now() - last_heartbeat;
            
            let status = if elapsed < HEARTBEAT_INTERVAL_SECS * 3 {
                AgentStatus::Healthy
            } else if elapsed < HEARTBEAT_TIMEOUT_SECS {
                AgentStatus::Warning
            } else {
                AgentStatus::Dead
            };
            
            health.push(AgentHealth { id: *id, status, last_heartbeat });
            
            // Self-healing: restart dead agents
            if status == AgentStatus::Dead {
                let checkpoint = agent.last_checkpoint().await;
                self.restart_agent(*id, checkpoint).await;
            }
        }
        health
    }
}
```

---

## 11. Resource Allocation: Weighted Fair Queuing + Model Arbitrage

```rust
/// Model arbitrage: route to cheapest capable model
pub fn select_model(task: &Task, available: &[ModelProfile]) -> ModelProfile {
    let capable = available.iter()
        .filter(|m| m.supports_all(&task.required_skills));
    
    // Weighted score: capability_match × (1/cost) × speed
    capable.max_by(|a, b| {
        let score_a = a.capability_match(&task.required_skills) * (1.0 / a.cost_per_1k) * a.speed;
        let score_b = b.capability_match(&task.required_skills) * (1.0 / b.cost_per_1k) * b.speed;
        score_a.partial_cmp(&score_b).unwrap()
    }).cloned().unwrap_or_else(|| available[0].clone())
}

/// Token budget ceiling: hard kill at 110%
pub struct TokenBudget {
    pub allocated: u32,
    pub warning_80: bool,   // Warn at 80%
    pub warning_100: bool,  // Hard warning at 100%
    pub kill_110: bool,     // Terminate at 110%
}
```

---

## 12. Security: What MAS CAN and CANNOT Do

### What MAS CAN Do (Explicit Capabilities)

| Capability | Mechanism | User Control |
|---|---|---|
| Read files in unlocked vaults | Security-scoped bookmark + mmap | User selects vault; Touch ID unlocks |
| Write files in unlocked vaults | CapabilityGrant with Write permission | Must be explicitly granted per task |
| Execute code | Sandboxed `nsjail` or `seccomp` | User approves each execution |
| Call cloud APIs | Hermes sidecar (L7) | Pro build only; MAS has no network |
| Use MCP tools | MCP client with allowlist | Tool-by-tool user approval |
| Spawn sub-agents | Orchestrator dispatch | Budget-limited; auto-terminated on budget exhaustion |
| Access web | BrowseClaw (L7) | Pro build only; each search requires approval |
| Read user keychain | Never | **Explicitly denied** |
| Access camera/mic | Never | **Explicitly denied** |
| Access other apps' data | Never | Sandbox prevents this |
| Escape sandbox | Never | **Impossible by design** |

### What MAS CANNOT Do (Explicit Boundaries)

1. **Cannot access files outside unlocked vaults** — Security-scoped bookmarks enforce this at the kernel level
2. **Cannot run without biometric unlock** — Touch ID is mandatory for vault unlock; no "remember me"
3. **Cannot access network in MAS build** — App Store build has no `network.client` entitlement
4. **Cannot modify Prime claims** — User-authored files are Prime; AI suggestions are Composite and require user approval
5. **Cannot exceed token budget** — Orchestrator kills agents at 110% budget consumption
6. **Cannot communicate agent-to-agent without Gate mediation** — All messages pass through Resonance Gate
7. **Cannot become Core-tier without human attestation** — 2-of-3 admin quorum required
8. **Cannot persist cloud claims as Prime** — Cloud-derived claims are permanently Composite
9. **Cannot access security-scoped bookmarks from other apps** — Each bookmark is scoped to Epistemos only
10. **Cannot bypass Touch ID via accessibility** — `kSecAccessControlBiometryCurrentSet` invalidates on biometric change

---

## 13. macOS Entitlements: MAS vs Pro

### MAS Build (Epistemos — Free)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <!-- No network access in MAS build -->
    <!-- Local agent only -->
    
    <!-- File access: user-selected only -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Bookmarks for persistent access -->
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    
    <!-- No cloud, no Hermes, no MCP remote -->
</dict>
</plist>
```

### Pro Build (Epistemos Pro — Direct Distribution)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <!-- Network for Hermes sidecar -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- File access -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Bookmarks -->
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    
    <!-- XPC for Hermes -->
    <key>com.apple.security.temporary-exception.shared-preference.name</key>
    <array>
        <string>com.epistemos.hermes.arena</string>
    </array>
    
    <!-- SMAppService for background agents -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

---

## 14. Build Path: 12 Weeks to MAS Release

| Week | Phase | Deliverable |
|---|---|---|
| 1 | **Vault Foundation** | Swift Vault model, NSOpenPanel directory picker, security-scoped bookmark creation |
| 2 | **Biometric Gate** | LocalAuthentication integration, Touch ID unlock/lock, biometric change detection |
| 3 | **Rust MAS Kernel** | Agent trait, Orchestrator trait, Gate trait, Tool trait, Memory trait |
| 4 | **UniFFI Bridge** | Vault operations Rust ↔ Swift, bookmark passing, error bridging |
| 5 | **File Indexing** | SwiftData metadata model, Rust embedding pipeline, SHA-256 checksums |
| 6 | **Agent Definitions** | Markdown frontmatter parser, agent registry, skill loader |
| 7 | **Orchestrator** | Task routing, workflow templates, model arbitrage, budget enforcement |
| 8 | **Resonance Gate MAS** | Multi-agent verification, inter-agent message validation, swarm coherence |
| 9 | **Self-Healing** | Heartbeat protocol, checkpoint transfer, agent restart, health dashboard |
| 10 | **Conflict Resolution** | Evidence Supremacy Protocol, cross-vault contradiction handling |
| 11 | **Hermes Integration** | Vault-scoped cloud agent, MCP client with allowlist, Pro tunnel activation |
| 12 | **UI Polish** | Vault manager view, agent activity dashboard, coherence visualizer, lockdown button |

---

## 15. Summary: The Vault-Gated Agent Swarm

> The Epistemos MAS release transforms the cognitive substrate from a single-agent system into a **Vault-Gated Agent Swarm** — a multi-agent architecture where every agent's authority is bounded by biometrically-secured vaults that the user explicitly selects. The vault is the capability primitive: no vault unlocked, no agent active. Touch ID is not a login screen — it is a **capability gate** that grants and revokes agent authority one vault at a time.

The architecture synthesizes seven frameworks into a unified Rust kernel, formalizes six universal agent factors, and wraps the entire philosophy into **one stable feature**: `VaultGatedSwarm`. It is buildable in 12 weeks on Apple Silicon, ships to both MAS and Pro, and enforces explicit security boundaries that no other MAS in the ecosystem provides.

Build it.
