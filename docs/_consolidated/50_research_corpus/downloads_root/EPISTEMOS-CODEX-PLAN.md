# Epistemos — Codex Implementation Plan v2
## Living Vault + Claude Managed Sessions + Metal Mamba-2 + Rowboat Patterns

**Version:** 2.0 — April 8, 2026
**Author:** Jordan Tyrell Conley
**Target:** AI coding agents (Codex, Claude Code)
**Repository:** BlickandMorty/Epistemos

---

## How to Use This Document

Read the "Files to Read First" for every task before writing code. Do not skip them. Commit after each task.

**Research Reference Docs** (all in `/Users/jojo/Downloads/`):
- `new.md` — Claude Managed Agents + Rowboat Integration Blueprint (April 8, 2026 launch)
- `new2.md` — Hybrid Rust/Swift architecture, rmcp crate, Metal Mamba-2 GPU analysis
- `new3.md` — CMA session/event semantics, snapshot-and-merge pattern, Rowboat portables
- `new4.txt` — Neural-symbolic Mamba-2 as cognitive exoskeleton, temporal knowledge graph
- `Custom Metal Mamba 2 Implementation for Epistemos  Technical Specification.md` — 6 core kernels, tile sizing, chunk Q=128
- `Metal Mamba 2  Deep Dive into Blelloch Scan, FFT Strategy, and Tile Sizing.md` — CRITICAL: Decoupled Fallback required
- `Custom Metal Mamba-2 Implementation  Technical Specification for Epistemos.md` — bandwidth-bound analysis
- `Metal Mamba 2 Implementation Research.txt` — SSM math, Apple Silicon memory hierarchy
- `CMS-X (v3).md` — Constitutive Semantic Field Model: force laws, concept packets, GHRR binding, Neural Barrier Functions
- `CMS-X (final).md` — CMS-X literature validation: 19/20 citations validated, competitive landscape
- `CMS-X_Claim_Ledger.md` — Claim calibration, scaling objections, consolidated validation assessment
- `CMS_v2_Final_Definitive.md` — CMS v2 six-layer safety architecture (HIS, NSPO, Mamba temporal audit)
- `man.txt` through `man7final.md` — Hub-and-Topic vault architecture, 5-tier memory model, verbatim storage
- `last feature after new agents/LIVING_VAULT_ARCHITECTURE.md` — Diff engine, Ebbinghaus decay, git-backed mutations
- `last feature after new agents/sprint-omega-5-living-vault.md` — Sprint Omega-5 tasks 1–8 exact specs
- `/Users/jojo/Downloads/rowboat/` — Cloned Rowboat source. Key files:
  - `apps/x/packages/core/src/knowledge/build_graph.ts` — change detection, batching
  - `apps/x/packages/core/src/knowledge/inline_tasks.ts` — Live Notes exact implementation
  - `apps/x/packages/core/src/knowledge/graph_state.ts` — mtime+hash state tracking
  - `apps/x/packages/shared/src/agent-schedule.ts` — cron/window/once scheduling schema
  - `apps/rowboat/src/application/workers/job-rules.worker.ts` — two-tier scheduler

**Codebase:** `/Users/jojo/Downloads/Epistemos/`

---

## ⚠️ CRITICAL SAFETY NOTE — Metal Mamba-2 Blelloch Scan

Standard Blelloch / Decoupled Lookback scan requires Forward Progress Guarantees (FPG).
**Apple M1/M2/M3/M4 GPUs DO NOT have FPG.**
Using standard Decoupled Lookback on Apple GPU → GPU HANG at 2000ms TDR timeout.

**REQUIRED:** Use **Decoupled Fallback** (Smith, Levien, Owens, SPAA '25) for inter-chunk scan.
- Measured: 36.85×10⁹ el/s on M1 Max, 98.4% of memcpy ceiling, zero hangs.
- Reference implementation: `cartesia-ai/edge` Metal kernels.
- Applies ONLY to Step 3 (inter-chunk scan). Intra-chunk scan (≤128 tokens) uses standard threadgroup Blelloch — safe.

---

## Architecture Overview (Current State)

```
Swift UI (macOS native)
  ↓ UniFFI FFI
Rust agent_core (agentic loop, tools, compaction, routing, session registry)
  ↓ JSON-RPC
omega-mcp (→ replace with rmcp crate, Phase 7)
  ↓
Tantivy FTS + Vec0 vectors + SwiftData + GRDB
```

**Key existing files:**
- `agent_core/src/agent_loop.rs` — main agentic loop
- `agent_core/src/session.rs` — SessionState (Running/Completed/Failed)
- `agent_core/src/storage/vault.rs` — VaultStore with Tantivy + SHA-256 hash
- `agent_core/src/tools/registry.rs` — tool registry + risk levels
- `Epistemos/LocalAgent/LocalAgentLoop.swift` — local MLX agent loop
- `Epistemos/LocalAgent/HermesPromptBuilder.swift` — system prompt construction
- `Epistemos/Omega/MCPBridge.swift` — UniFFI MCP bridge
- `Epistemos/State/EventStore.swift` — SQLite WAL telemetry (6 tables)
- `Epistemos/State/NightBrainService.swift` — idle-time maintenance jobs
- `Epistemos/Graph/EntityExtractor.swift` — AI entity extraction
- `Epistemos/Graph/GraphBuilder.swift` — structural graph construction
- `Epistemos/Vault/ConversationPersistence.swift` — exists, needs implementation
- `Epistemos/Vault/VaultChatMutator.swift` — exists, needs implementation
- `agent_core/src/storage/vault_git.rs` — exists, needs implementation
- `agent_core/src/storage/diff_engine.rs` — exists, needs implementation
- `agent_core/src/storage/memory_classifier.rs` — exists, needs implementation
- `agent_core/src/storage/memory_decay.rs` — exists, needs implementation
- `agent_core/src/storage/cross_propagation.rs` — exists, needs implementation

---

# PHASE 0: Foundation (Unblocks Everything Else)

---

## Task 0.1 — Incremental Graph Building with SHA-256 Change Detection

**Read first:**
- `Epistemos/Graph/EntityExtractor.swift`
- `agent_core/src/storage/vault.rs`
- `/Users/jojo/Downloads/rowboat/apps/x/packages/core/src/knowledge/graph_state.ts`

**Pattern from Rowboat `build_graph.ts`:** hybrid mtime+SHA256. Fast check: if mtime unchanged, skip. If mtime changed, verify hash. Batch changed files in groups of 10.

**Rust changes in `agent_core/src/storage/vault.rs`:**
```rust
pub fn get_content_hash(&self, path: &str) -> Option<String>
pub fn set_content_hash(&self, path: &str, hash: &str) -> Result<(), VaultError>
pub fn changed_paths_since(&self, paths: &[String]) -> Vec<String>
// Also add: pub fn get_mtime(&self, path: &str) -> Option<SystemTime>
```

**Swift changes in `Epistemos/Graph/EntityExtractor.swift`:**
- Before processing each batch: call `changedPaths(among:)` via KnowledgeCoreBridge
- Only pass changed paths to LLM extraction pass
- After successful extraction: call `setContentHash` for each processed path
- Bump batch size from 5 → 10 (matches Rowboat's empirically tested batch size)

**Bridge in `Epistemos/Engine/KnowledgeCoreBridge.swift`:**
```swift
func changedPaths(among paths: [String]) async -> [String]
func setContentHash(path: String, hash: String) async
```

**Verification:** 100-note vault. Time full scan (should be ~30s). Edit 1 note. Re-scan (should be <2s). Confirm only changed note triggered LLM call.

---

## Task 0.2 — Knowledge Index Injected Into Every Agent Prompt

**Read first:**
- `Epistemos/LocalAgent/HermesPromptBuilder.swift`
- `agent_core/src/agent_loop.rs` (system prompt construction)
- `/Users/jojo/Downloads/rowboat/apps/x/packages/core/src/knowledge/knowledge_index.ts`

**Rowboat's insight:** Pass entity index as formatted table in system prompt. Agent resolves "MOHAWK project" → `/KnowledgeFusion/MOHAWK/` by lookup, not search.

**Create `Epistemos/Engine/KnowledgeIndexBuilder.swift`:**
```swift
actor KnowledgeIndexBuilder {
    // Queries GraphStore for all note/folder nodes by entity type
    // Renders as compact markdown table (≤150 entries, sorted by last_modified desc)
    // Cache: 30s TTL (graph rarely changes during session)
    // Size target: <2000 tokens total

    func buildIndex(context: ModelContext, vaultRoot: URL) async -> String
    func systemPromptBlock(context: ModelContext, vaultRoot: URL) async -> String
}
```

**Output format (entity-typed sections from Phase 8.1):**
```markdown
## Your Knowledge Graph
### People (3)
| Name | Path |
|------|------|
| Alex Chen | People/Alex-Chen.md |
### Projects (4)
| Name | Path |
|------|------|
| MOHAWK Training Pipeline | KnowledgeFusion/MOHAWK/ |
### Decisions (2)
| Decision | Path |
|----------|------|
| Use Tantivy over GRDB for FTS | Decisions/2026-03-FTS-choice.md |
### Notes (other, most recent 50)
...
```

**Inject in:**
1. `HermesPromptBuilder.systemPrompt()` — after tool definitions
2. `agent_core/src/agent_loop.rs` — system prompt construction (Rust side)

**Prefix-cache note (from `last.txt`, `man7final.md`):** Knowledge Index must come AFTER the frozen memory blocks (SOUL.md, USER.md) but BEFORE tools. Memory blocks occupy prefix-cache chunk 1; index occupies chunk 2.

---

## Task 0.3 — pkm_graph_neighbors + pkm_list_entity + pkm_get_backlinks MCP Tools

**Read first:**
- `Epistemos/Omega/MCPBridge.swift`
- `agent_core/src/tools/registry.rs`
- `Epistemos/Graph/GraphStore.swift` (SDGraphEdge schema)

**Add to `agent_core/src/tools/registry.rs`:**

```rust
// Tool 1: pkm_graph_neighbors
// Parameters: path (required), edge_types (optional array), depth (optional 1-2, default 1)
// Returns: { source, neighbors: [{path, edge_type, weight}] }
// Risk: ReadOnly

// Tool 2: pkm_list_entity
// Parameters: entity_type ("person"|"project"|"topic"|"decision"|"event"|"resource")
// Returns: array of {name, path, last_modified}
// Risk: ReadOnly

// Tool 3: pkm_get_backlinks
// Parameters: path
// Returns: array of {source_path, context_excerpt}
// Risk: ReadOnly
```

All three query GraphStore via Swift UniFFI callback (same pattern as existing vault_search tool).

---

## Task 0.4 — Session State Machine

**Read first:** `agent_core/src/session.rs`

**Extend `SessionState` enum:**
```rust
pub enum SessionState {
    Idle,
    Running { turn: u32 },
    PausedForApproval { tool_name: String, args_json: String, deadline: SystemTime },
    Rescheduled { next_run: SystemTime, reason: RescheduleReason },
    Completed { turns: u32, input_tokens: u64, output_tokens: u64, cost_usd: f64 },
    Failed { error: String },
    Terminated,
}
pub enum RescheduleReason { BudgetExceeded { spent: f64, limit: f64 }, RateLimited, NightBrainDeferred }
```

Add transition methods: `pause_for_approval()`, `resume_from_approval()`, `reschedule()`, `terminate()`.
Expose to Swift via UniFFI. Surface in `UIState.swift` as `@Published var agentStatus`.

---

## Task 0.5 — Cost Budget Enforcement

**Read first:** `Epistemos/Omega/Safety/CostTracker.swift`, `agent_core/src/agent_loop.rs`

Add `max_cost_usd: Option<f64>` to `AgentConfig`. After each turn, check cumulative cost vs budget. On exceed: emit event, return `AgentResult` with explanation, transition session to `Rescheduled(BudgetExceeded)`. Expose as optional UI field.

---

# PHASE 1: Living Vault Memory System

**Read ALL of these before starting Phase 1:**
- `last feature after new agents/LIVING_VAULT_ARCHITECTURE.md`
- `last feature after new agents/sprint-omega-5-living-vault.md`
- `man7final.md`

---

## Task 1.1 — Diff Engine (Rust)

**Create `agent_core/src/storage/diff_engine.rs`:**

```rust
// Uses `similar` crate for text diffs (add to Cargo.toml: similar = { version = "2.6", features = ["unicode"] })

pub struct DiffLine { pub tag: ChangeTag, pub content: String, pub old_index: Option<usize>, pub new_index: Option<usize> }
pub struct DiffHunk { pub header: String, pub lines: Vec<DiffLine> }
pub struct TextDiffResult { pub hunks: Vec<DiffHunk>, pub additions: usize, pub deletions: usize }
pub struct JsonDiff { pub op: JsonDiffOp, pub path: String, pub old_value: Option<Value>, pub new_value: Option<Value> }
pub enum JsonDiffOp { Add, Remove, Change }

pub fn generate_text_diff(old: &str, new: &str) -> TextDiffResult
pub fn generate_json_diff(old: &Value, new: &Value) -> Vec<JsonDiff>

// Fuzzy patch application: try exact → whitespace-insensitive → ±3 line offset
pub fn apply_text_patch(target: &str, hunks: &[DiffHunk]) -> Result<String, DiffError>

pub enum DiffError { HunkNotFound { hunk_header: String }, AmbiguousMatch { candidates: usize }, ContextMismatch }
```

---

## Task 1.2 — Memory Classifier (Rust)

**Create `agent_core/src/storage/memory_classifier.rs`:**

```rust
pub enum MemoryOperation { Add, Update, Delete, Noop }
pub struct VaultFact { pub path: String, pub content: String, pub confidence: f32, pub source: FactSource, pub created_at: SystemTime, pub last_reinforced: SystemTime }
pub enum FactSource { UserStatement, AgentInference, DocumentIngestion, VaultSearch }

// Algorithm:
// 1. Embed new_content via VaultStore embedding pipeline
// 2. Cosine search existing vault (threshold 0.85)
// 3. No match → Add; identical content → Noop; different content → Update; retraction → Delete
// 4. Optional LLM confirmation (<200 token prompt): "update / noop / delete?"
// 5. Fallback: pure cosine if no model available
pub async fn classify_memory_operation(new_content: &str, vault: &VaultStore, provider: Option<&dyn Provider>) -> Result<(MemoryOperation, Option<String>), ClassifierError>
```

LLM prompt template (under 200 tokens):
```
Classify this memory operation.
NEW FACT: {new_content}
EXISTING FACT: {existing_content}
OPTIONS: update (new replaces old), noop (same meaning), delete (new retracts old)
Respond with exactly one word: update, noop, or delete.
```

---

## Task 1.3 — Decay Engine (Rust)

**Create `agent_core/src/storage/memory_decay.rs`:**

```rust
// Ebbinghaus forgetting curve: strength(t) = s₀ × e^(-λ × days_elapsed)
pub struct NodeStrength { pub value: f32, pub importance: Importance, pub last_accessed: SystemTime, pub pinned: bool, pub access_count: u32 }
pub enum Importance { Critical, High, Normal, Low }
// λ values: Critical=0.005, High=0.01, Normal=0.05, Low=0.1 (per day)

impl NodeStrength {
    pub fn decay(&mut self, now: SystemTime)   // apply Ebbinghaus formula
    pub fn access(&mut self)                   // reset strength to 1.0
    pub fn pin(&mut self)                      // lock at 1.0, immune to decay
    pub fn unpin(&mut self)                    // resume decay from current value
    pub fn should_gc(&self) -> bool            // true if strength < 0.15 AND not pinned
}

pub async fn batch_decay(vault: &VaultStore) -> DecayReport    // called by NightBrain
pub async fn collect_garbage(vault: &VaultStore) -> Vec<String> // remove strength < 0.15 nodes
```

**CMS-X Enhancement — Logarithmic Conceptual Inertia:**
CMS-X v3 defines `m_i` (conceptual inertia) as resistance to rapid displacement that *grows with use*.
Map this directly to the decay engine: make effective λ inversely proportional to `access_count`,
not just `importance`. A fact accessed 50 times should decay 10× slower than one accessed twice.

```rust
/// CMS-X conceptual inertia: frequently-accessed facts resist displacement.
/// Reference: CMS-X (v3).md §3.1 Concept Packet — m_i parameter.
fn effective_lambda(&self) -> f64 {
    let base = self.importance.lambda();
    // Logarithmic inertia: access_count=1 → 1.0x, access_count=50 → ~0.26x, access_count=1000 → ~0.14x
    base / (1.0 + (self.access_count.max(1) as f64).ln())
}
```

Use `effective_lambda()` instead of raw `importance.lambda()` in the `decay()` method.

**YAML frontmatter to add to vault notes:**
```yaml
strength: 0.95
importance: high         # critical | high | normal | low
pinned: false
access_count: 12
last_accessed: 2026-04-08T14:23:00Z
decay_rate: 0.01
```

---

## Task 1.4 — Cross-File Propagation (Rust)

**Create `agent_core/src/storage/cross_propagation.rs`:**

```rust
pub struct ReferenceMatch { pub path: String, pub excerpt: String, pub confidence: f32 }
pub struct PropagationDiff { pub target_path: String, pub diff: TextDiffResult, pub reason: String }

// Find all notes referencing a given entity (uses Tantivy FTS on entity name + key terms)
pub async fn scan_for_references(entity: &str, vault: &VaultStore) -> Vec<ReferenceMatch>

// For each reference, ask LLM if secondary update needed. Returns proposed diffs (not yet applied).
pub async fn generate_propagation_diffs(primary_diff: &TextDiffResult, primary_path: &str, references: &[ReferenceMatch], provider: &dyn Provider) -> Vec<PropagationDiff>

// Atomic: apply primary + all propagation diffs. If any propagation fails, roll back ALL.
// Shadow git checkpoint BEFORE applying.
pub async fn atomic_commit(primary_path: &str, primary_diff: &TextDiffResult, propagation_diffs: &[PropagationDiff], vault: &VaultStore, git: &VaultGit) -> Result<CommitResult, PropagationError>
```

---

## Task 1.5 — Git Integration (Rust)

**Implement `agent_core/src/storage/vault_git.rs` (file exists, fill it in):**

```rust
// Add dep: git2 = { version = "0.19", default-features = false }

pub struct VaultGit { repo: Repository, vault_root: PathBuf }

impl VaultGit {
    pub fn open_or_init(vault_root: &Path) -> Result<Self, GitError>

    // Structured commit messages:
    // [MEMORY:UPDATE] path/to/file.md
    //   - field: old_value → new_value
    //   - source: agent inference
    //   - strength: 0.95 (reinforced)
    pub fn commit_diffs(&self, diffs: &[(String, TextDiffResult)], template: &CommitMessageTemplate, author: &str) -> Result<git2::Oid, GitError>

    pub fn history(&self, path: Option<&str>, limit: usize) -> Vec<CommitRecord>
    pub fn diff_between(&self, old: git2::Oid, new: git2::Oid) -> String
    pub fn revert_commit(&self, oid: git2::Oid) -> Result<git2::Oid, GitError>  // creates revert commit, does NOT force-push
    pub fn checkpoint(&self, label: &str) -> Result<git2::Oid, GitError>
}
```

---

## Task 1.6 — Conversation Persistence (Swift)

**Implement `Epistemos/Vault/ConversationPersistence.swift` (exists, fill in):**

```swift
// CRITICAL rule from man7final.md: NEVER summarize on write. Store verbatim.
// MemPalace achieves 96.6% LongMemEval R@5 via raw verbatim storage.

actor ConversationPersistence {
    struct ConversationTurn: Codable {
        let id: UUID
        let sessionId: String
        let timestamp: Date
        let role: String         // user | assistant | tool
        let content: String      // VERBATIM — never summarized
        let toolCalls: [ToolCallRecord]?
        let tokenCount: Int
    }

    // File hierarchy:
    // [vault]/.epistemos/chats/{type}/{session_id}/turns.jsonl   (immutable, append-only)
    // [vault]/.epistemos/chats/{type}/{date}-{title}.md          (human-readable companion)
    // [vault]/.epistemos/sessions/{session_id}/working-memory.md (Phase 2.1)
    // [vault]/.epistemos/sessions/{session_id}/trace.json        (tool call log)
    // [vault]/.epistemos/sessions/{session_id}/context.json      (system prompt snapshot)

    func appendTurn(_ turn: ConversationTurn, vaultRoot: URL) async throws
    func generateCompanionMarkdown(sessionId: String, vaultRoot: URL) async throws -> URL
    func flushToMemory(sessionId: String, vaultRoot: URL) async throws  // called on session end or 50% context fill
    func loadConversation(sessionId: String, vaultRoot: URL) async throws -> [ConversationTurn]
}
```

---

## Task 1.7 — Vault Chat Mutator + Diff Approval UI (Swift)

**Implement `Epistemos/Vault/VaultChatMutator.swift` (exists, fill in):**

```swift
@Observable
class VaultChatMutator {
    enum MutationMode { case auto, supervised, locked }
    var pendingDiff: StagedDiff?
    var mode: MutationMode = .supervised

    // Pipeline: content → classify (Rust MemoryClassifier) → diff (Rust DiffEngine)
    //           → show DiffApprovalSheet if supervised → apply → git commit (Rust VaultGit)
    func mutate(path: String, newContent: String, source: FactSource, vaultRoot: URL) async throws -> MutationResult
}
```

**Create `Epistemos/Views/Notes/DiffApprovalSheet.swift`:**
- Unified diff display (red = removed, green = added) in `List` with `NSFont.monospacedSystemFont`
- "Propagation Diffs" expandable section ("3 other notes will also update")
- "Apply" and "Reject" buttons
- Auto-approve countdown (30s) in `.auto` mode
- Staging area shows `[staged]` / `[unstaged]` labels like `git add -p`

**CMS-X Enhancement — Contradiction Cards (BeliefShift pattern):**

Reference: `CMS-X (final).md` — BeliefShift (arXiv:2603.23848) confirms no current model achieves both
high drift resistance AND high evidence sensitivity. GPT-4o drifts with user; Claude holds ground but
won't update on legitimate evidence.

When `VaultChatMutator` classifies a mutation as `MemoryOperation::Update` AND the existing fact has
`strength > 0.8`, do NOT silently diff-and-apply. Instead, surface a **Contradiction Card** in DiffApprovalSheet:

```swift
struct ContradictionCard {
    let existingFact: String       // the current high-confidence fact
    let existingStrength: Float    // e.g., 0.92
    let existingSource: FactSource // e.g., .userStatement
    let proposedFact: String       // the new conflicting content
    let proposedSource: FactSource // e.g., .agentInference
    let conflictType: ConflictType // .directContradiction | .partialUpdate | .scopeChange
}

enum ConflictType {
    case directContradiction  // "Claude input is $3/M" vs "Claude input is $5/M"
    case partialUpdate        // fact is mostly same but one field changed
    case scopeChange          // same topic but different scope/context
}
```

**UI in DiffApprovalSheet** — show side-by-side:
```
┌─────────────────────────────┬─────────────────────────────┐
│ EXISTING (strength: 0.92)   │ PROPOSED (new)              │
│ Source: user statement       │ Source: agent inference      │
├─────────────────────────────┼─────────────────────────────┤
│ Claude Sonnet 4.6 input     │ Claude Sonnet 4.6 input     │
│ pricing: $3.00/MTok         │ pricing: $5.00/MTok         │
└─────────────────────────────┴─────────────────────────────┘
        [Keep Existing]  [Accept New]  [Keep Both as Conflict]
```

"Keep Both as Conflict" appends the proposed fact with `certainty: 0.5` and a `conflicts_with: <existing_path>` reference in the frontmatter. The user resolves it later. This is the correct behavior per BeliefShift: surface the conflict rather than silently overwriting OR silently ignoring.

**Detection logic in `VaultChatMutator.mutate()`:**
```swift
let (operation, existingPath) = try await classifyMemoryOperation(newContent, vault, provider)
if operation == .update, let path = existingPath {
    let existing = try await vault.read(path)
    let existingStrength = parseStrengthFromFrontmatter(existing)
    if existingStrength > 0.8 {
        // High-confidence fact being challenged — show Contradiction Card
        pendingDiff = .contradiction(ContradictionCard(
            existingFact: existing, existingStrength: existingStrength,
            proposedFact: newContent, ...
        ))
        return  // wait for user decision in DiffApprovalSheet
    }
}
// Normal diff flow for low-strength facts
```

---

# PHASE 2: Transparent Working Memory + SOUL.md

---

## Task 2.1 — Transparent Working Memory

**Read first:**
- `agent_core/src/agent_loop.rs`
- `man7final.md` (L0 Working Memory section)
- `last.txt` (MEMORY.md frozen prefix-cache pattern)

**What to build:** After every agent tool execution, write progress summary to:
```
[vault_root]/.epistemos/sessions/[session_id]/working-memory.md
```

**Format:**
```markdown
---
session_id: abc-123
objective: "Research the MOHAWK pipeline and write a summary"
status: running
turn: 3
---

## Goal
Research the MOHAWK training pipeline and write a summary.

## Current State
- Found MOHAWK directory with 15 training data files
- Identified 3 key training phases: SFT, KTO, evaluation
- Still need: evaluate quality metrics from mix_report.json

## Completed Actions
1. vault_search("MOHAWK training") → found 8 relevant files
2. vault_read("KnowledgeFusion/MOHAWK/") → extracted pipeline overview
3. pkm_graph_neighbors → found 4 connected modules

## Open Questions
- What are the eval.jsonl pass rates?
- Is KTO alignment phase complete?

## Key Decisions
- Focusing on composed_training_data/ over raw (more processed)
```

**Rust (`agent_loop.rs`):** After each tool execution, `vault.write(".epistemos/sessions/{id}/working-memory.md", &render_working_memory(&state), &[], false)`.
**On session start:** If working-memory.md exists and status != completed, inject as first context block (enables resume after crash/interruption).
**On completion:** Commit to VaultGit as `[SESSION:COMPLETE] session_id`.
**User editing:** User can open this file in the note editor and redirect the agent — edits are picked up next turn.

---

## Task 2.2 — SOUL.md Identity System

**Read first:** `man.txt`, `last.txt` (SOUL.md and MEMORY.md patterns)

**Files to create in vault on first attach:**
- `.epistemos/memory/soul.md` — role, communication style, decision framework (user edits once)
- `.epistemos/memory/user.md` — user preferences (NightBrain writes this from session distillation)

**Injected as the FIRST block in every agent system prompt** (prefix-cache position 1). These blocks are frozen — mutations written to disk but not re-injected into active prompt until next session (preserves cache).

**Create `Epistemos/Views/Settings/IdentityEditorView.swift`:**
- Settings → Agent → Identity
- Template on first launch (role, communication style, decision framework, current focus)
- "Initialize Identity" button → creates soul.md from template
- Live editor after initialization

**In `agent_loop.rs` session bootstrap (inject before everything else):**
```rust
let soul = vault.read(".epistemos/memory/soul.md").unwrap_or_default();
let user_prefs = vault.read(".epistemos/memory/user.md").unwrap_or_default();
let knowledge = vault.read(".epistemos/memory/knowledge.md").unwrap_or_default();
let decisions = vault.read(".epistemos/memory/decisions.md").unwrap_or_default();
// L2 patterns injected only if semantically relevant:
let patterns = if is_relevant(&objective, ".epistemos/memory/patterns.md") {
    vault.read(".epistemos/memory/patterns.md").unwrap_or_default()
} else { String::new() };

let memory_context = format!("<identity>\n{soul}\n{user_prefs}\n</identity>\n<knowledge>\n{knowledge}\n</knowledge>\n<decisions>\n{decisions}\n</decisions>\n<patterns>\n{patterns}\n</patterns>\n");
// Prepend memory_context as FIRST block in system prompt
```

---

# PHASE 3: Live Notes (Rowboat Pattern — Exact Implementation)

**Read first:**
- `/Users/jojo/Downloads/rowboat/apps/x/packages/core/src/knowledge/inline_tasks.ts` (source of truth)
- `/Users/jojo/Downloads/rowboat/apps/x/packages/shared/src/agent-schedule.ts`

---

## Task 3.1 — Live Notes Implementation

**Rowboat uses:** JSON-in-fence blocks with `targetId` region markers, poll every 15 seconds.

**Step 1: Live note schema**

A note becomes live by adding `live_note: true` to frontmatter plus task blocks in the body:

````markdown
---
live_note: true
---

# Apple Intelligence Tracker

## Background
Tracking Apple's on-device AI for Epistemos integration.

## Recent Updates
<!--task-target:apple-ai-updates-->
[agent output inserted here]
<!--/task-target:apple-ai-updates-->

```task
{
  "instruction": "Find recent Apple Intelligence and MLX-Swift announcements. Summarize top 3 developments.",
  "schedule": {
    "type": "cron",
    "expression": "0 9 * * *",
    "startDate": "2026-04-08T00:00:00Z",
    "endDate": "2026-07-08T00:00:00Z",
    "label": "runs daily at 9 AM"
  },
  "targetId": "apple-ai-updates",
  "lastRunAt": null
}
```
````

**Three schedule types (from Rowboat `agent-schedule.ts`):**
1. `cron` — standard cron expression + startDate + endDate
2. `window` — cron date check AND current time in [startTime, endTime]
3. `once` — single execution at `runAt` if `lastRunAt == null`

**Step 2: Create `Epistemos/State/LiveNoteService.swift`**

```swift
// NOT NSBackgroundActivityScheduler (only fires on system idle)
// USE DispatchSourceTimer on background serial queue (fires during active use)

actor LiveNoteService {
    private var timer: DispatchSourceTimer?
    private let pollInterval: TimeInterval = 15  // matches Rowboat

    func start(vaultRoot: URL)
    func stop()

    private func pollForDueTasks(vaultRoot: URL) async
    // 1. Scan vault for notes with live_note: true frontmatter
    // 2. Parse task blocks from each note
    // 3. For each task: check if due (cron/window/once logic)
    // 4. If due: spawn agent session (via AgentRuntime)
    // 5. On completion: update target region + lastRunAt in JSON block
    // 6. If no future tasks remain: set live_note: false in frontmatter
    // 7. Commit: [LIVE_NOTE] path: daily update run

    private func isDue(task: LiveTask, now: Date) -> Bool
    private func updateNoteWithResult(note: URL, targetId: String, result: String, runAt: Date) async throws
}
```

**Step 3: Agent constraints for live note runs**

Constrained system prompt: "You are monitoring [topics]. Find at most [max_additions] new developments not already in the note. Append them under the target region. Be brief — 2–3 sentences per item. Cite sources."

Allowed tools: `web_search`, `web_fetch`, `vault_search`, `pkm_graph_neighbors`
Forbidden: `vault_write` to any path OTHER than the live note itself
Max turns: 5 (not 50 — these are short monitoring runs)
Max cost: `$0.05` per run (configurable in note frontmatter)

**Step 4: UI**

In `NoteDetailWorkspaceView.swift` toolbar:
- "Make Live" toggle (adds frontmatter + example task block)
- When live: shows "Last monitored: 2h ago" badge
- "Run Now" button → immediate manual trigger
- Task editor sheet (cron expression or human-readable frequency selector)

---

# PHASE 4: Cross-Session Memory Distillation

---

## Task 4.1 — Memory Distillation NightBrain Job

**Read first:** `Epistemos/State/NightBrainService.swift`, `man7final.md` (5-tier model)

**Implement the existing stub `Job.memoryDistillation`:**

```swift
private func runMemoryDistillation() async -> PipelineResult {
    // 1. Find completed sessions from last 7 days
    //    Look in [vault]/.epistemos/sessions/ for dirs with status: completed in working-memory.md
    // 2. Load turns.jsonl from each session
    // 3. Run MemoryClassifier (Rust FFI) on conversation content
    //    Extract: user preferences, domain facts, successful patterns, failed approaches
    // 4. Classify each fact against existing memory files (Add/Update/Noop/Delete)
    // 5. Apply diffs via VaultChatMutator(.auto mode)
    //    Target: .epistemos/memory/knowledge.md, patterns.md, user.md, decisions.md
    // 6. Run batch_decay on all memory files (Ebbinghaus pass via Rust FFI)
    // 7. collect_garbage (strength < 0.15)
    // 8. Commit: [MEMORY:DISTILLATION] NightBrain 2026-04-08
    // 9. Record in EventStore night_brain_runs
}
```

---

## Task 4.2 — User-Configurable Agent Scheduling

**Pattern from Rowboat `job-rules.worker.ts` (two-tier: rules → jobs):**
- Store schedules in `.epistemos/agents/{agent-id}.json`
- Schema matches Rowboat `agent-schedule.ts`: `{ schedule: Cron|Window|Once, enabled, startingMessage, description }`
- `AgentSchedulerService.swift` polls at minute boundary + 2 seconds for due schedules
- On trigger: spawns agent session via AgentRuntime protocol (Phase 5)

---

# PHASE 5: Claude Managed Sessions (Optional Feature)

---

## Task 5.1 — AgentRuntime Protocol

**Create `Epistemos/Engine/AgentRuntime.swift`:**

```swift
@MainActor
protocol AgentRuntime: AnyObject {
    var runtimeId: String { get }
    var displayName: String { get }
    var isAvailable: Bool { get }
    func startSession(objective: String, config: AgentSessionConfig) async throws -> String
    func cancelSession(_ sessionId: String) async
    func sessionEvents(_ sessionId: String) -> AsyncStream<AgentEvent>
    func sessionState(_ sessionId: String) -> SessionState
}

struct AgentSessionConfig {
    var maxTurns: Int = 50
    var maxCostUSD: Double? = nil
    var enableBash: Bool = false
    var enableWebSearch: Bool = true
    var enableVaultWrite: Bool = false
}

// Unified event stream — identical schema for local and cloud backends
enum AgentEvent {
    case sessionStarted(sessionId: String)
    case turnStarted(turn: Int)
    case tokenEmitted(token: String)
    case thinkingEmitted(token: String)            // preserve thinking blocks per CLAUDE.md
    case toolCallStarted(toolName: String, args: String)
    case toolCallCompleted(toolName: String, result: String, durationMs: Int)
    case approvalRequired(toolName: String, args: String, riskLevel: String)
    case budgetWarning(spentUSD: Double, limitUSD: Double)
    case turnCompleted(turn: Int, content: String)
    case sessionCompleted(totalTurns: Int, totalCostUSD: Double)
    case sessionFailed(error: String)
    case sessionCancelled
}
```

**Two concrete implementations:**
- `LocalRustRuntime.swift` — wraps existing Rust agent_core FFI
- `ClaudeManagedRuntime.swift` — wraps CMA API (Task 5.2)

**Update `ChatCoordinator.swift`** to use `AgentRuntime` protocol instead of calling local loop directly.

---

## Task 5.2 — Claude Managed Sessions Backend

**Create `Epistemos/Engine/ClaudeManagedRuntime.swift`:**

Raw `URLSession` only — NO Swift SDK (per CLAUDE.md).

```swift
final class ClaudeManagedRuntime: AgentRuntime {
    // Anthropic Managed Sessions API — verify exact endpoints against current docs
    private let baseURL = "https://api.anthropic.com/v1/sessions"

    func startSession(objective: String, config: AgentSessionConfig) async throws -> String {
        // POST /v1/sessions
        // Body: { model, system, tools, max_tokens, ... }
        // Returns session_id
    }

    func sessionEvents(_ sessionId: String) -> AsyncStream<AgentEvent> {
        // GET /v1/sessions/{id}/events → SSE stream
        // Parse SSE events → map to AgentEvent enum
    }
}
```

**Two vault integration patterns (from new3.md):**
- **Live tool calls (preferred):** PKM ops as custom tools. Agent pauses at `stop_reason: requires_action`. Swift executes locally. Responds with `user.custom_tool_result`.
- **Snapshot and merge (privacy):** Export read-only vault subset → upload → agent processes → download → merge. Pseudonymize PII before upload.

---

## Task 5.3 — CMS UI (Settings + Mode Toggle)

**In `SettingsView.swift` → new "Agent" section:**
```
Settings → Agent
├── Runtime
│   ├── [●] Local (Rust) — default
│   └── [ ] Claude Managed Sessions — experimental
│             ⚠️ Sessions run in Anthropic's cloud (~$0.08/session-hour active)
│             Vault content is NOT sent — only prompts and results
├── Budget
│   └── Default session budget: [Unlimited ▾] → $0.10/$0.25/$0.50/$1.00/Custom
└── Identity
    └── [Edit Identity] → opens IdentityEditorView (Task 2.2)
```

**In agent input bar** (only when CMA enabled AND Claude selected AND agent mode):
```
[input                          ]
                      [Local] [Cloud] [▶ Run]
```
Default: Local. Explicit tap required for Cloud.

**`EpistemosConfig.swift` additions:**
```swift
var claudeManagedSessionsEnabled: Bool = false
var defaultAgentBudgetUSD: Double? = nil
var runtimePreference: RuntimePreference = .localFirst
```

---

# PHASE 6: Custom Metal Mamba-2 Kernels

**Read ALL Mamba-2 docs before starting this phase:**
- `Custom Metal Mamba 2 Implementation for Epistemos  Technical Specification.md` — 6 kernels, tile sizing
- `Metal Mamba 2  Deep Dive into Blelloch Scan, FFT Strategy, and Tile Sizing.md` — Decoupled Fallback
- `Custom Metal Mamba-2 Implementation  Technical Specification for Epistemos.md` — bandwidth analysis
- `Metal Mamba 2 Implementation Research.txt` — hardware specs
- `new4.txt` — temporal knowledge graph vision

---

## Task 6.1 — Mamba-2 SSD Architecture (4 Steps)

**File directory:** `Epistemos/Shaders/Mamba2/`

**The 4-step SSD algorithm:**
- **Step 1 (parallel):** `Y_diag` — semiseparable intra-chunk outputs → MPS matmul
- **Step 2 (parallel):** `state_c` — chunk-end states → MPS matmul
- **Step 3 (SEQUENTIAL, T/Q elements only):** `h_c = A_{c:} h_{c-1} + state_c` — inter-chunk recurrence → **Decoupled Fallback scan** (see critical note at top)
- **Step 4 (parallel):** `Y_off` — output from prior chunk states → MPS matmul

**Critical rule:** Use MPS (`MPSMatrixMultiplication`) for ALL matmul steps (2.9 TFLOPS M4 vs 0.34 custom Metal = 8.5× gap). Custom Metal kernels ONLY for: segsum, inter-chunk scan, decay multiplication.

**Optimal configuration:**
- Chunk size: Q=128 (empirically optimal post-fusion; was Q=256 pre-fusion)
- SIMD group: 32 threads (fixed Apple Silicon)
- Threadgroup: 128–256 threads (4–8 SIMD groups)
- Memory mode: `MTLStorageModeShared` throughout (zero-copy UMA on Apple Silicon)
- Weight matrices: row-major, 64-byte aligned
- Hidden states: `[n_layers, H, N, D]` — layers outermost for layer-streaming
- Chunk states: `[B, n_chunks, H, N]`

---

## Task 6.2 — Six Metal Kernels

**Kernel 1: `segsum_stable.metal`**
- Log-space segment sums WITHOUT subtraction (avoids NaN catastrophic cancellation even in FP32)
- 32KB threadgroup tiling for coalesced access
- Input: log-decay vector. Output: cumulative log-sum per position.
- Do NOT use simple subtraction: `log(A[i]) - log(A[j])` → NaN at extremes

**Kernel 2: `chunk_state_decay.metal`**
- Per-chunk decay factors (λ values, input-dependent in Mamba-2)
- Elementwise multiply B_l ⊙ decay_l · X_l across batch × heads × features
- All parallel — no sequential dependencies

**Kernel 3: `inter_chunk_scan.metal`** ← MOST CRITICAL
- **MUST implement Decoupled Fallback — DO NOT use standard Blelloch on Apple GPU**
- Implementation pattern:
  ```metal
  // Each workgroup spins on predecessors up to MAX_SPIN_COUNT
  // On trigger: cooperative fallback recomputes blocking tile from source data
  // Atomically posts result via device-scope atomic
  // No starvation — no FPG required
  ```
- At Q=128, L=1M: T/Q = 7,812 chunk states (small scan, fast)
- State size per chunk: H=32, N=64, FP16 → 16 KB (fits in 32 KB threadgroup limit)
- Intra-SIMD sync: `simd_shuffle_down(value, offset)` — ~1–2 cycles
- Inter-SIMD sync: threadgroup barrier `mem_flags::mem_threadgroup` — ~2–4 cycles

**Kernel 4: `ssd_intra_chunk.metal`**
- MPS matmul + segsum mask within each chunk (Q=128)
- Where MPS can't be used: `simdgroup_matrix` 8×8 tiles
- FP16 arithmetic, FP32 accumulator → FP32 output for numerical stability

**Kernel 5: `ssd_output_merge.metal`**
- `Y = Y_diag + Y_off` — simple elementwise addition
- FUSE with Kernel 4 in same command buffer to eliminate HBM round-trip

**Kernel 6: `input_output_proj.metal`**
- Dispatch to MPS directly — no custom kernel needed

**Command buffer strategy:**
- ALL 48 layers in ONE `MTLCommandBuffer` (prefill or decode) — eliminates CPU round-trips
- Triple buffering with `DispatchSemaphore` to avoid 2000ms GPU watchdog timeout
- Chunk submission for prefill: segment 1M-token prefill into 512-token blocks (<100ms each on M4 Pro)
- Metal's internal data hazard tracking handles cross-layer sync; explicit `MTLFence` only if profiling shows it needed

---

## Task 6.3 — FFT Strategy (d_conv=4 case)

**Verdict: SKIP FFT. Use direct convolution.**

At d_conv=4: 4 MACs per token — negligible vs. SSM FLOPs. Cache kernel weights as `constant` Metal buffer.

**Only add FFT if d_conv grows beyond ~16.** If needed:
- Radix-8 Stockham FFT: 138 GFLOPS M1 vs vDSP 107 GFLOPS (29% better)
- Batch requirement: ≥64 channels to overcome dispatch overhead (Mamba-2: d_model=2048 >> 64 ✓)
- Precompute FFT(K) once; per-token: element-wise complex multiply only
- Max single-dispatch threadgroup: N=8192 in FP16 (= 32KB)
- For N > 4096: four-step FFT (decompose N=N₁×N₂, device-memory transpose between stages)

---

## Task 6.4 — ANE Hybrid Strategy

**Profile first before adding ANE complexity.**
- Selective SSM scan: CANNOT run on ANE (RNN layers unsupported)
- Linear projections: CAN route to ANE via Core ML
- But: MPS already at 2.9 TFLOPS, ANE routing adds 0.5–2ms dispatch overhead per layer
- Only worth pursuing if MPS matmuls are proven bottleneck (unlikely at batch=1)

---

## Task 6.5 — Vault State Serialization for Mamba-2 Hidden State

**Use FlatBuffers (not JSON, not NSCoding, not CBOR):**
- Random-access: 1.24 ns
- Load time: 10.47 µs (memory-mapped)
- No parse step — map directly into native types
- Schema:
  ```fbs
  table LayerState { h: [float]; }
  table MambaHiddenState { layers: [LayerState]; timestamp: ulong; context_length: ulong; }
  root_type MambaHiddenState;
  ```
- Memory-map on app launch; checkpoint to disk every N turns via `fsync()`
- **Cargo dep:** `flatbuffers = "24.3.7"`
- **Swift dep:** FlatSwift or generate from schema via `flatc`

**State file path:** `.epistemos/mamba/hidden_state.fbs` (one per vault, not per session)

---

## Task 6.6 — Performance Targets & Benchmarks

| Config | Throughput (M4 Max) | Context |
|--------|---------------------|---------|
| FP16 baseline | ~101 tok/s | Unlimited (fixed O(1) state) |
| INT8 | ~202 tok/s (theoretical) | Same |
| Q4 | ~404 tok/s (theoretical) | Same |
| M4 Pro with INT4 | **120+ tok/s target** | Same |

**Create benchmark harness** in `EpistemosTests/MetalMamba2BenchmarkTests.swift`:
- Prefill 1K tokens: target <100ms
- Prefill 100K tokens: target <5s
- Decode single token: target <10ms
- State serialization round-trip: target <50ms

**Context advantage over Transformer:** Fixed state 16–32 MB regardless of context length. Transformer KV cache for 70B at 1M tokens: 412 GB. Mamba-2 enables true 1M+ context on M2 Pro 18 GB.

---

## Task 6.7 — Temporal Knowledge Graph (new4.txt)

Mamba-2's O(1) state enables features Transformers can't support in-memory:

**Add to vault YAML frontmatter:**
```yaml
certainty: 0.85                    # 0.0–1.0
evidence_robustness: medium        # high | medium | low | speculative
event_time: 2026-03-15T00:00:00Z  # when it happened
recording_time: 2026-04-08T...    # when agent learned it
```

**Three subgraphs** (add edge types to GraphStore):
- Episode subgraph: raw event nodes (conversation turns, tool calls)
- Semantic subgraph: entity nodes + typed relationships (existing GraphStore)
- Community subgraph: Louvain cluster nodes (NightBrain job)

**Ghost Links:** Edges with `decay_rate` → apply same Ebbinghaus decay as node strength. Edges with strength < 0.1 become dotted in graph renderer. Edges with strength < 0.05 are garbage-collected.

**Display in note sidebar:** `Epistemic Status: Certain (0.92) | Well-evidenced`

---

# PHASE 7: MCP Server Upgrade (rmcp Crate)

**Read first:** `new2.md` (rmcp section), existing `Epistemos/Omega/MCPBridge.swift`

## Task 7.1 — Replace omega-mcp with rmcp

**Dep:** `rmcp = "0.16"` in `agent_core/Cargo.toml`

**Expose 7 tools via rmcp:**
1. `pkm_search(query, limit)` — FTS + semantic hybrid (ReadOnly)
2. `pkm_get(path)` — read note content (ReadOnly)
3. `pkm_write(path, content, tags)` — write note (Modification)
4. `pkm_list_entity(type)` — list by entity type (ReadOnly)
5. `pkm_graph_neighbors(path, edge_types, depth)` — graph traversal (ReadOnly)
6. `pkm_get_backlinks(path)` — reverse link lookup (ReadOnly)
7. `pkm_query_graph(from_type, relationship, to_type)` — semantic query (ReadOnly)

**Transport modes:**
- `stdio` — for local agent access (existing behavior)
- Streamable HTTP — for future CMA tunnel access
- Bearer token auth on HTTP: generated per-session, stored in Keychain, never in vault files

---

# PHASE 8: Entity Ontology + Dataview Query Layer

## Task 8.1 — Entity-Typed Folder Ontology

**Extend `GraphNodeType` in `GraphStore.swift`:**
```swift
// New semantic entity types
case person = 7         // notes in People/ folder
case project = 8        // notes in Projects/ folder
case topic = 9          // notes in Topics/ folder
case decision = 10      // notes in Decisions/ folder
case event = 11         // notes in Events/ folder
case resource = 12      // notes in Resources/ folder
```

Detection: rule-based (folder path) + LLM-based for non-typed folders (add to EntityExtractor prompt).
Apply to Knowledge Index: render as separate sections per type.

## Task 8.2 — Dataview-Compatible Query Layer

**Extend `Epistemos/Engine/QueryAST.swift`:**
- Dataview syntax parser: `TABLE col1, col2 FROM "folder" WHERE condition SORT BY field LIMIT n`
- Render in code blocks: ` ```dataview ... ``` `
- `DataviewService.swift`: parses DQL → QueryAST nodes → executes via existing QueryRuntime

---

# PHASE 9: CMS-X Applied Research — Validated Concepts Only

**Read first:**
- `/Users/jojo/CMS-X (v3).md` — Full architecture (Part III: Force Laws, Concept Packets, GHRR)
- `/Users/jojo/CMS-X (final).md` — Literature validation (19/20 confirmed, competitive landscape)
- `/Users/jojo/CMS-X_Claim_Ledger.md` — Claim calibration table, scaling objections

**Important:** CMS-X is a theoretical research paper about how LLMs should work internally.
Most of it (SGFM, Neural Barrier Functions, Holographic FE) cannot be implemented in an app.
This phase extracts ONLY the four concepts that are validated AND implementable in Epistemos.
See Claim Ledger §6 "Consolidated validation assessment" for what is validated vs speculative.

---

## Task 9.1 — TRACED Reasoning Trajectory Metrics (Agent Self-Evaluation)

**Priority:** MEDIUM. Gives the agent system a quality signal for every session — enables learning what works.

**Read first:**
- `/Users/jojo/CMS-X (v3).md` — §3.2 Force Primitive 4 (Damping), §3.6 TRACED integration
- `CMS-X_Claim_Ledger.md` — TRACED (arXiv:2603.10384) row: VALIDATED, displacement/curvature metrics confirmed

**Scientific basis:** TRACED (arXiv:2603.10384, March 2026) demonstrates that LLM reasoning trajectories
have measurable geometric properties. Correct reasoning produces high-displacement, low-curvature trajectories
(direct progress toward goal). Hallucination produces low-displacement, high-curvature "Hesitation Loops"
(circling without progress). This maps directly to agent tool call sequences.

**What to build:**

Create `agent_core/src/reasoning_metrics.rs`:

```rust
use serde::{Serialize, Deserialize};

/// TRACED-inspired reasoning trajectory metrics.
/// Applied to agent tool call sequences, not to model internals.
///
/// Reference: TRACED (arXiv:2603.10384) — validated displacement/curvature metrics
/// for distinguishing correct reasoning from hallucination.
///
/// Interpretation:
/// - High displacement + low curvature = efficient reasoning (direct path to goal)
/// - Low displacement + high curvature = hesitation loop (circling, no progress)
/// - High displacement + high curvature = exploration (broad search, may be appropriate)
/// - Low displacement + low curvature = stuck (no movement at all)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReasoningTrajectoryMetrics {
    /// Semantic distance from first tool call to final result.
    /// Computed as: cosine_distance(embedding(first_tool_call_args), embedding(final_output))
    /// Range: 0.0 (no progress) to 1.0+ (significant semantic displacement)
    pub displacement: f32,

    /// Total semantic distance traveled across all tool calls.
    /// Computed as: sum of cosine_distance(embedding(tool_call_n), embedding(tool_call_n+1))
    /// for all consecutive tool call pairs.
    pub path_length: f32,

    /// Curvature ratio: path_length / displacement.
    /// 1.0 = perfectly direct path (impossible in practice)
    /// <2.0 = efficient reasoning
    /// 2.0–4.0 = moderate exploration (acceptable for research tasks)
    /// >4.0 = hesitation loop detected (flag for review)
    pub curvature_ratio: f32,

    /// Number of times the agent called the same tool with identical or near-identical args.
    /// 0 = no loops. ≥3 = definite hesitation loop.
    /// Detection: hash(tool_name + args_json), track duplicates.
    pub loop_count: u32,

    /// Number of tool calls that returned errors.
    /// High error_count + high curvature = agent is thrashing.
    pub error_count: u32,

    /// Total turns in session.
    pub total_turns: u32,

    /// Efficiency score: displacement / total_turns.
    /// Higher = more progress per turn.
    pub efficiency: f32,

    /// Overall quality classification based on the above metrics.
    pub classification: TrajectoryClassification,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TrajectoryClassification {
    Efficient,      // curvature < 2.0 AND loop_count == 0
    Exploratory,    // curvature 2.0–4.0 AND displacement > 0.3
    Hesitating,     // curvature > 4.0 OR loop_count >= 3
    Stuck,          // displacement < 0.1 AND total_turns > 3
    Failed,         // error_count > total_turns / 2
}

/// Compute trajectory metrics from a completed agent session's tool call log.
///
/// Input: Vec of (tool_name, args_json, result_json, is_error) tuples
/// from the session's trace.json file.
///
/// Embedding: uses VaultStore's embedding pipeline to embed each tool call's
/// args+result as a single vector. If embeddings unavailable, falls back to
/// TF-IDF bag-of-words cosine similarity.
pub fn compute_trajectory_metrics(
    tool_calls: &[(String, String, String, bool)],  // (name, args, result, is_error)
    vault: &VaultStore,
) -> ReasoningTrajectoryMetrics {
    // 1. Embed each tool call: embed(tool_name + " " + args_json + " " + result_json_first_200_chars)
    // 2. Compute pairwise cosine distances between consecutive embeddings
    // 3. path_length = sum of all consecutive distances
    // 4. displacement = cosine_distance(first_embedding, last_embedding)
    // 5. curvature_ratio = path_length / displacement.max(0.001)
    // 6. loop_count = count of hash(tool_name + args_json) duplicates
    // 7. error_count = count where is_error == true
    // 8. efficiency = displacement / total_turns as f32
    // 9. Classify based on thresholds above

    todo!()  // Implement
}
```

**Integration points:**

1. **In `agent_loop.rs`** — after session completes, call `compute_trajectory_metrics()` on the tool call history.
   Store the result in the session's `AgentResult`:
   ```rust
   pub struct AgentResult {
       // ... existing fields ...
       pub trajectory_metrics: Option<ReasoningTrajectoryMetrics>,
   }
   ```

2. **In `Epistemos/Vault/ConversationPersistence.swift`** — when writing `trace.json`, also write
   `metrics.json` alongside it with the serialized `ReasoningTrajectoryMetrics`.

3. **In `Epistemos/State/EventStore.swift`** — add a `session_metrics` table:
   ```sql
   CREATE TABLE IF NOT EXISTS session_metrics (
       session_id TEXT PRIMARY KEY,
       displacement REAL,
       path_length REAL,
       curvature_ratio REAL,
       loop_count INTEGER,
       error_count INTEGER,
       total_turns INTEGER,
       efficiency REAL,
       classification TEXT,
       timestamp REAL
   );
   ```
   Index on `classification` and `timestamp` for querying "show me all hesitating sessions this week."

4. **In NightBrain `memoryDistillation` (Task 4.1)** — when distilling patterns from past sessions,
   weight facts from `Efficient` sessions higher than facts from `Hesitating` sessions.
   A pattern discovered during a hesitation loop is less reliable than one from efficient reasoning.

5. **In the agent input bar UI** — after session completes, show a small badge:
   - Green checkmark for `Efficient`
   - Blue compass for `Exploratory`
   - Yellow warning for `Hesitating`
   - Red X for `Stuck` or `Failed`
   Tapping the badge shows the full metrics breakdown.

**Verification:**
- Run an agent session that completes a simple vault search (should classify as `Efficient`)
- Run an agent session where you ask something impossible (should classify as `Stuck` or `Hesitating`)
- Check that `session_metrics` table has entries after both
- Check that `metrics.json` was written next to `trace.json`

---

## Task 9.2 — GHRR Path-Sensitive Graph Embeddings (Future Enhancement)

**Priority:** LOW — Phase 8+ enhancement. Implement only after Phases 0–4 are stable.

**Read first:**
- `/Users/jojo/CMS-X (v3).md` — §3.1 Concept Packet, `v_bind` parameter (GHRR)
- `CMS-X_Claim_Ledger.md` — PathHD/GHRR (arXiv:2512.09369) row: VALIDATED, 40–60% latency reduction

**Scientific basis:** PathHD demonstrates that GHRR (Generalized Holographic Reduced Representations) —
block-diagonal unitary binding via circular convolution in frequency domain — achieves 40–60% latency
reduction and 3–5× GPU memory reduction for knowledge graph reasoning compared to neural encoder approaches.
The key insight: embed a note's *structural position in the graph* (its typed path), not just its content.

**What this enables:** `pkm_graph_neighbors` becomes dramatically faster and more semantically accurate.
"Person → authored → Project → contains → Note" produces a different embedding than
"Topic → mentions → Person → attended → Event" even if the content overlaps.

**Algorithm:**
```
GHRR binding: v_path = FFT⁻¹( FFT(v_edge1) ⊙ FFT(v_entity1) ⊙ FFT(v_edge2) ⊙ FFT(v_entity2) ⊙ ... )
```
Where ⊙ is element-wise complex multiplication in frequency domain.
This is non-commutative (order matters) and produces a fixed-dimension vector regardless of path length.

**Implementation sketch (Rust):**
```rust
// In agent_core/src/storage/ghrr.rs (future)

/// GHRR: Generalized Holographic Reduced Representation
/// Reference: PathHD (arXiv:2512.09369), CMS-X v3 §3.1

/// Encode a graph path as a single fixed-dimension vector.
/// Path: [(edge_type, entity_type, entity_id), ...]
/// Each component has a learned embedding vector.
/// Binding: circular convolution in frequency domain (FFT → elementwise multiply → IFFT).
pub fn encode_path(path: &[(EdgeType, EntityType, &str)], embeddings: &PathEmbeddings) -> Vec<f32> {
    let d = embeddings.dimension;
    let mut result_freq = vec![Complex::new(1.0, 0.0); d]; // identity in freq domain

    for (edge, entity_type, entity_id) in path {
        let edge_vec = embeddings.edge_embedding(edge);
        let entity_vec = embeddings.entity_embedding(entity_type, entity_id);

        // FFT both, elementwise multiply into accumulator
        let edge_freq = fft(&edge_vec);
        let entity_freq = fft(&entity_vec);

        for i in 0..d {
            result_freq[i] = result_freq[i] * edge_freq[i] * entity_freq[i];
        }
    }

    ifft(&result_freq) // back to real domain
}
```

**Capacity note (from CMS-X Claim Ledger §4):** VSA capacity scales O(√D). For D=4096 dimensions,
reliable binding capacity is ~64 items per superposition. Graph paths rarely exceed 4–5 hops,
so this is well within bounds. Do NOT try to bind entire subgraphs — bind individual paths only.

**Do NOT implement yet.** Add as Phase 8+ after validating that the current Vec0 embeddings
are actually a bottleneck for graph traversal speed. Profile first.

---

## Task 9.3 — Ghost Links with Decay in Graph Renderer

**Priority:** MEDIUM — adds visual intelligence to the graph view.

**Read first:**
- `/Users/jojo/CMS-X (v3).md` — §3.2 Force Primitive 3 (Binding) — stiffness `k_ij` is learned and decayable
- `Epistemos/Graph/GraphEngine.swift` — current edge rendering

**What to build:** Apply the same Ebbinghaus decay from Task 1.3 to graph EDGES, not just nodes.
Edges that haven't been traversed (accessed by agent or user) fade over time.

**In `GraphStore.swift`** — add to `SDGraphEdge`:
```swift
// Existing fields: sourceNodeId, targetNodeId, type, weight, isManual
// ADD:
var strength: Float = 1.0        // Ebbinghaus decay, same formula as NodeStrength
var lastAccessed: Date = .now
var accessCount: Int = 0
```

**In `GraphEngine.swift`** — when rendering edges:
```swift
// Edge alpha = strength value (0.0 = invisible, 1.0 = fully opaque)
// strength 0.3–1.0: solid line, alpha = strength
// strength 0.1–0.3: dotted line, alpha = strength (visual "ghost" appearance)
// strength < 0.1: do not render (garbage-collected by NightBrain)
```

This creates the "Ghost Link" effect from CMS-X: relationships that haven't been reinforced
gradually fade from the graph visualization. Relationships the user and agent actively use
stay bright and visible. Old, unused connections become transparent dotted lines before
eventually being removed.

**In NightBrain `batch_decay`** — decay edge strength alongside node strength.
**In pkm_graph_neighbors** — when an edge is traversed by the agent, call `edge.access()` to reset strength to 1.0.

---

## Task 9.4 — Epistemic Status Labels on Vault Notes

**Priority:** LOW — adds metadata richness to the knowledge graph.

**Read first:**
- `/Users/jojo/CMS-X (v3).md` — concept of confidence attached to semantic state
- `CMS-X_Claim_Ledger.md` — §6 consolidated validation shows how claims are tiered (validated/supported/theoretical/speculative)

**What to build:** Every vault note gets optional epistemic status in frontmatter:

```yaml
certainty: 0.85                    # 0.0–1.0 (how confident is this fact?)
evidence_robustness: medium        # high | medium | low | speculative
event_time: 2026-03-15T00:00:00Z  # when the fact became true (bi-temporal)
recording_time: 2026-04-08T14:00:00Z  # when the agent learned it (bi-temporal)
```

**Certainty assignment rules:**
- `1.0` — user explicitly stated it ("my API key is X")
- `0.9` — user confirmed agent's inference ("yes that's correct")
- `0.7` — agent inferred from multiple vault sources (cross-referenced)
- `0.5` — agent inferred from single source or web search
- `0.3` — agent speculation or tentative conclusion
- Auto-assigned by `MemoryClassifier` based on `FactSource` enum.

**Evidence robustness assignment:**
- `high` — multiple independent sources, user confirmation, or peer-reviewed citation
- `medium` — single authoritative source or strong inference
- `low` — single web result or agent reasoning without verification
- `speculative` — agent hypothesis, not yet checked

**Display in note metadata sidebar** (`NoteDetailWorkspaceView`):
```
Epistemic Status: Certain (0.85) | Medium evidence
Last confirmed: 2 days ago
```

**Impact on Memory Distillation (Task 4.1):**
When NightBrain distills session memories, set `certainty` and `evidence_robustness` based on how the fact was learned. Facts from user statements get `certainty: 1.0, evidence: high`. Facts from agent web searches get `certainty: 0.5, evidence: low`.

When Contradiction Cards (Task 1.7 enhancement) surface a conflict, show both facts' epistemic status so the user can see "user statement (0.95) vs agent inference (0.5)" and make an informed choice.

---

# Build, Verification & Commit Protocol

## After each Rust task:
```bash
cargo test --manifest-path /Users/jojo/Downloads/Epistemos/agent_core/Cargo.toml
cargo clippy --manifest-path /Users/jojo/Downloads/Epistemos/agent_core/Cargo.toml -- -D warnings
cargo fmt --manifest-path /Users/jojo/Downloads/Epistemos/agent_core/Cargo.toml --check
```

## After each Swift task:
```bash
cd /Users/jojo/Downloads/Epistemos
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swiftlint
xcodebuild test -scheme Epistemos -destination 'platform=macOS' 2>&1 | xcbeautify
```

## Commit after EVERY task (user explicitly requires this — see feedback_commit_after_change.md):
```bash
git commit -m "Task X.Y: <description>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

## Code Standards (NON-NEGOTIABLE — CLAUDE.md):
1. No `try!`, no force-unwraps anywhere
2. All inference on background actors — never block `@MainActor`
3. Every `unsafe` block gets `// SAFETY:` comment
4. `DispatchQueue.main.async` in UniFFI callbacks — NEVER `.sync` (deadlock)
5. API keys in Keychain — never UserDefaults
6. Stream every token — no buffering
7. Preserve thinking blocks — never strip content array from tool_use turns
8. No subprocess for inference — Hermes subprocess is orchestration only

---

# Priority Order for Codex

| # | Task | Why This Order | Source |
|---|------|---------------|--------|
| 1 | 0.1 — Incremental graph | Graph freshness affects all other features | Rowboat build_graph.ts |
| 2 | 0.2 — Knowledge Index | Highest prompt engineering leverage | Rowboat knowledge_index.ts |
| 3 | 1.1–1.5 — Living Vault Rust core | Already specced in sprint-omega-5 — low ambiguity | sprint-omega-5.md |
| 4 | 1.6–1.7 — Conversation persistence + DiffApproval + Contradiction Cards | Completes Living Vault loop | man7final.md + CMS-X BeliefShift |
| 5 | 2.1 — Working memory | Trust feature — users need to see what agent knows | man7final.md L0 |
| 6 | 3.1 — Live Notes | Flagship proactive feature | Rowboat inline_tasks.ts |
| 7 | 4.1 — Memory distillation | Completes session→vault memory loop | man7final.md L1–L3 |
| 8 | 9.1 — TRACED reasoning metrics | Quality signal for every session; informs distillation | CMS-X + TRACED arXiv:2603.10384 |
| 9 | 9.3 — Ghost Links with decay | Visual intelligence in graph — fading unused edges | CMS-X v3 §3.2 |
| 10 | 2.2 — SOUL.md | Identity persistence | man.txt SOUL.md pattern |
| 11 | 0.3 — pkm_graph_neighbors | Graph-aware agent traversal | new.md MCP spec |
| 12 | 0.4–0.5 — Session state + budget | Safety and UX | new3.md session semantics |
| 13 | 9.4 — Epistemic status labels | Metadata richness, informs Contradiction Cards | CMS-X Claim Ledger pattern |
| 14 | 5.1–5.3 — Claude Managed Sessions | Optional premium backend | new.md + new3.md |
| 15 | 6.1–6.7 — Metal Mamba-2 | Transformative but dedicated sprint | Mamba-2 specs (5 docs) |
| 16 | 7.1 — rmcp upgrade | MCP server hardening | new2.md rmcp section |
| 17 | 8.1–8.2 — Entity ontology + Dataview | Enhancement | Rowboat entity schema |
| 18 | 9.2 — GHRR path embeddings | Future: only if Vec0 proven bottleneck | CMS-X v3 §3.1 + PathHD |

---

*End of EPISTEMOS-CODEX-PLAN.md v3.0 — CMS-X Applied Research integrated*
