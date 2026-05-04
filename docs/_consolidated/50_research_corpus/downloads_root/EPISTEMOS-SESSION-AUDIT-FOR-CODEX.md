# Epistemos Session Audit — Complete Synthesis for Codex
## Every change made, every issue found, every file to check

**Date:** April 9, 2026
**Session scope:** 26 tasks across 3 phases (original plan completion + competitor fusion + feature plan audit)
**Codebase:** `/Users/jojo/Downloads/Epistemos/`
**IMPORTANT:** Changes were made to the MAIN repo, NOT the `.claude/worktrees/serene-wright/` worktree. Codex must verify changes exist in the correct location.

---

## HOW TO USE THIS DOCUMENT

Codex should:
1. Read each file listed below and verify the change exists
2. For BROKEN items: fix them
3. For WARNING items: either wire them in or document why they're deferred
4. For ORPHANED items: wire into the app bootstrap or remove
5. Run full build + test suite after all fixes
6. Do a zero-change verification pass at the end

---

## SECTION 1: RUST CHANGES (agent_core crate)

### Files Modified

#### 1.1 `agent_core/src/storage/vault.rs`
**What was added:** Three new public methods after the existing `content_hash()` function (~line 229):
- `pub fn get_content_hash(&self, path: &str) -> Result<Option<String>, VaultError>` — SELECT from notes table
- `pub fn set_content_hash(&self, path: &str, hash: &str) -> Result<(), VaultError>` — UPDATE notes table
- `pub fn changed_paths_since(&self, paths: &[String]) -> Result<Vec<String>, VaultError>` — compares stored vs current file hashes

**AUDIT CHECK:** Verify these 3 methods exist. They query the `notes` table which has `content_hash TEXT NOT NULL` at line ~100. The methods use `self.db.lock()` consistently with existing patterns.

#### 1.2 `agent_core/src/prompts.rs`
**What was added:**
- New function `build_system_prompt_with_index()` that accepts an optional `knowledge_index: Option<&str>` parameter
- Original `build_system_prompt()` preserved as a wrapper that calls `build_system_prompt_with_index(..., None)`
- Knowledge index injected FIRST in the prompt (prefix-cache position)

**AUDIT CHECK:** Verify BOTH functions exist. The old one should delegate to the new one. Check that `if let Some(index) = knowledge_index` uses correct Rust syntax (not `if let index =`).

#### 1.3 `agent_core/src/agent_loop.rs`
**What was added:**
- `pub max_cost_usd: Option<f64>` field in `AgentConfig` struct
- `max_cost_usd: None` in `Default` impl
- `let session_id = uuid::Uuid::new_v4().to_string();` after variable initialization
- Knowledge index reading: `std::fs::read_to_string(&index_path).ok()` for `.epistemos/knowledge_index.md`
- Budget enforcement: after token usage accumulation, checks `estimated_cost >= budget`
- Working memory write: after tool results pushed, writes `.epistemos/sessions/{id}/working-memory.md`
- Import changed from `build_system_prompt` to `build_system_prompt_with_index`

**AUDIT CHECK:** Verify ALL of these exist. The budget enforcement should return an `AgentResult` with a budget exceeded message, NOT panic. The working memory write should use `let _ = std::fs::write(...)` (non-failing).

#### 1.4 `agent_core/src/bridge.rs`
**What was added:** `max_cost_usd: None` in the `AgentConfig` construction within `from_ffi()` (~line 178)

**AUDIT CHECK:** Verify this field is present. Without it, the code won't compile since `AgentConfig` now requires it.

#### 1.5 `agent_core/src/session.rs`
**What was added:**
- `SessionState` enum expanded from 3 to 7 variants: `Idle`, `Running`, `PausedForApproval { tool_name, args_json, deadline_secs }`, `Rescheduled { reason }`, `Completed { turns, input_tokens, output_tokens }`, `Failed { error }`, `Terminated`
- 4 new methods on `GlobalSessions`: `pause_for_approval()`, `resume_from_approval()`, `reschedule()`, `terminate()`
- `Drop` impl updated to handle all 7 variants in the match statement

**AUDIT CHECK:** Verify the match in `Drop` is exhaustive for all 7 variants. Check that `active_count()` still correctly filters only `SessionState::Running` (the match pattern may need updating since `Running` now has a field `{ turn }`). **THIS IS A POTENTIAL BUG** — if `Running` changed from unit variant to struct variant, the filter needs `matches!(handle.state, SessionState::Running { .. })`.

#### 1.6 `agent_core/src/storage/memory_decay.rs`
**What was added:**
- `pub fn effective_decay_rate(&self) -> f64` method on `NodeStrength` — logarithmic inertia formula
- Both `decay()` and `batch_decay()` now use `node.effective_decay_rate()` instead of `node.decay_rate`
- 2 new tests: `memory_decay_logarithmic_inertia_slows_decay_for_frequently_accessed` and `memory_decay_effective_rate_is_lower_with_higher_access_count`

**AUDIT CHECK:** Verify the formula: `self.decay_rate / (1.0 + (self.access_count.max(1) as f64).ln())`. Run `cargo test -- memory_decay` — should show 7 tests passing (5 original + 2 new).

#### 1.7 `agent_core/src/context_loader.rs`
**What was added:**
- L2 skills injection enhanced: top match (score > 0.3) gets full skill body in `<skill>` XML tags, rest get description-only
- L3.25 working memory injection: scans `.epistemos/sessions/` for `working-memory.md` files with `status: running`, injects as context layer

**AUDIT CHECK:** Verify the L2 enhancement is inside `load_skill_descriptions()`. The `<skill>` tag should wrap the full body. The L3.25 injection should be BETWEEN neocortex gist (L3.5) and facts (L3), using `std::fs::read_dir` and `std::fs::read_to_string`.

#### 1.8 `agent_core/src/tools/registry.rs`
**What was added:**
- `register_pkm_graph_neighbors()` method called from `register_default_tools()`
- `GraphNeighborsHandler` struct implementing `ToolHandler` trait
- Tool uses `self.vault.hybrid_search(title, limit, &[])` to find related notes by title

**AUDIT CHECK:** Verify the handler is registered in `register_default_tools()` and the `GraphNeighborsHandler` struct has a `vault: Arc<dyn VaultBackend>` field.

#### 1.9 `agent_core/src/routing.rs`
**What was added:**
- Message length signal in `HeuristicClassifier::classify()`: <160 chars reduces complexity, >400 chars increases it
- Code detection: checks for triple backticks, `fn `, `func `, `class `, `impl `
- URL detection: `contains_url()` helper function checking for `http://`, `https://`, `www.`
- URL presence sets `requires_current_info = true`
- Code blocks set `shell_required = true`

**AUDIT CHECK:** Verify `contains_url()` is defined after `contains_any()`. Verify the complexity adjustments are clamped to `(0.05, 1.0)`.

#### 1.10 `agent_core/src/storage/hyperbolic_topology.rs`
**What was added:**
- `pub fn should_pierce_blanket(query: &str, node: &VaultNodeMetrics) -> (bool, f64)` — FEP-inspired decision function
- Uses Jaccard similarity between query terms and blanket summary
- Adjusts by gravity bonus (max +0.2) and volatility bonus (max +0.1)
- Threshold: pierce if confidence > 0.15

**AUDIT CHECK:** Verify the function exists between the `generate_blanket_summaries()` function and the "Agent-Facing Output" section. Check that `query_lower` is a `let` binding (not a temporary that gets dropped).

### New Rust Files

#### 1.11 `agent_core/src/reasoning_metrics.rs` (NEW)
**What it is:** TRACED-inspired reasoning trajectory metrics. Computes displacement, path length, curvature ratio, loop count from tool call sequences.
- `ReasoningTrajectoryMetrics` struct with 8 fields
- `TrajectoryClassification` enum: Efficient, Exploratory, Hesitating, Stuck, Failed
- `compute_trajectory_metrics()` function using Jaccard distance
- 5 tests

**AUDIT CHECK:** Verify registered in `lib.rs` as `pub mod reasoning_metrics;`. Run `cargo test -- reasoning_metrics` — should show 5 passing tests.

#### 1.12 `agent_core/src/error_classifier.rs` (NEW)
**What it is:** 7-category semantic error classification with recovery hints.
- `ErrorCategory` enum: Retryable, ContextOverflow, CredentialFailure, ModelOverloaded, ToolFailure, PermissionDenied, Unrecoverable
- `ClassifiedError` struct with recovery flags
- `classify()` function matching on `AgentError` variants
- 6 tests

**AUDIT CHECK:** Verify registered in `lib.rs` as `pub mod error_classifier;`. Run `cargo test -- error_classifier` — should show 6 passing tests.

### Rust Compilation Verification
```bash
export PATH="$HOME/.cargo/bin:$PATH"
cd /Users/jojo/Downloads/Epistemos
cargo test --manifest-path agent_core/Cargo.toml
# Expected: 245 passed, 0 failed
cargo clippy --manifest-path agent_core/Cargo.toml -- -D warnings
# Expected: warnings only (pre-existing), no errors
```

---

## SECTION 2: SWIFT CHANGES

### Files Modified

#### 2.1 `Epistemos/Graph/EntityExtractor.swift`
**What was added:**
- `import CryptoKit` at top
- `processedHashes` property backed by UserDefaults (`EntityExtractor.processedHashes`)
- `contentHash(of:)` method using SHA256
- In `scanVault()`: filters pages by hash comparison before LLM batch, updates hash after success, batch size 5→10
- Status message shows "X changed notes" instead of "all notes"

**STATUS: CLEAN** — All existing methods preserved.

#### 2.2 `Epistemos/LocalAgent/HermesPromptBuilder.swift`
**What was added:** `knowledgeIndex: String? = nil` parameter to `systemPrompt()`, prepended before tools block.

**STATUS: CLEAN** — Default value preserves all existing callers.

#### 2.3 `Epistemos/Views/Notes/NoteBacklinksPanel.swift`
**What was added:**
- `BacklinkItem` gains `edgeType: String?` and `source: BacklinkSource` fields
- New params: `pageId: String?`, `graphState: GraphState?`
- Graph edge query merged with text-scan results
- Edge type badges (green=supports, red=contradicts, blue=expands, orange=questions)

**STATUS: ⚠️ BROKEN** — Line 117 calls `await graphState.incomingEdges(forPageId:)` which DOES NOT EXIST on GraphState. **Codex must either implement this method or remove the graph edge query.**

**FIX OPTION A:** Add to GraphState:
```swift
func incomingEdges(forPageId pageId: String) async -> [(sourcePageId: String, sourceTitle: String, edgeType: String)] {
    // Query edges where targetNodeId matches a graph node with sourceId == pageId
    // Return source node's sourceId, label, and edge type
}
```

**FIX OPTION B:** Remove the graph edge query and keep only text-scan backlinks (simpler, still works).

#### 2.4 `Epistemos/Graph/GraphStore.swift`
**What was added:** `strength: Double = 1.0`, `lastAccessed: Date = .now`, `accessCount: Int = 0` to `GraphEdgeRecord`.

**STATUS: CLEAN** — Default values preserve all existing constructors.

#### 2.5 `Epistemos/Models/GraphTypes.swift`
**What was added:** 6 new cases: `person`, `project`, `topic`, `decision`, `event`, `resource` with rustIndex 8-13, displayNames, icons, and `inferFromPath()` static method.

**STATUS: ⚠️ WARNING** — The Rust `graph-engine` crate's `NodeType` enum only has 8 types (0-7). Any node with type 8-13 will be silently converted to `Note` on the Rust side. **Codex must update `graph-engine/src/types.rs` to add the 6 new types, OR accept that entity types are Swift-only metadata.**

#### 2.6 `Epistemos/State/NotesUIState.swift`
**What was added:** `OutlineFoldMode` expanded from 1 case to 4 (expanded, foldToH1, foldToH2, foldToH3) with `maxVisibleLevel`, `next` cycle property. `cycleOutlineFoldMode()` wired.

**STATUS: CLEAN**

#### 2.7 `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
**What was added:** `applyOutlineFoldMode()` now uses `delegate.headingLevel(at: i) ?? 1` to fold based on level.

**STATUS: CLEAN**

#### 2.8 `Epistemos/Views/Notes/EditableTransclusionView.swift`
**What was added:** TextKit 2 primary path for `intrinsicContentSize` using `textLayoutManager.usageBoundsForTextContainer`.

**STATUS: CLEAN** — TextKit 1 fallback preserved.

#### 2.9 `Epistemos/Views/Notes/AIPartnerInlineView.swift`
**What was added:** TextKit 2 primary path using `enumerateTextSegments` for highlight rect calculation.

**STATUS: CLEAN** — TextKit 1 fallback preserved.

#### 2.10 `Epistemos/State/EpistemosConfig.swift`
**What was added:** `claudeManagedSessionsEnabled` (Bool, default false) and `defaultAgentBudgetUSD` (Double, default 0).

**STATUS: CLEAN**

#### 2.11 `.github/workflows/release.yml`
**What was added:** Codesign step (gated by DEVELOPER_ID_APPLICATION secret), Notarize step (gated by APPLE_ID + NOTARIZATION_PASSWORD), Staple step.

**STATUS: CLEAN** — All steps are conditional (`if: env.X != ''`), so existing builds without secrets still work.

### New Swift Files

**⚠️ CRITICAL: 8 of 11 new Swift files are ORPHANED — not referenced from anywhere in the app.**

| File | Purpose | Referenced? | Status |
|------|---------|------------|--------|
| `Engine/KnowledgeIndexBuilder.swift` | Builds entity table for agent prompts | **NO** | ⚠️ ORPHANED |
| `Engine/AgentRuntime.swift` | Protocol + event enum + registry | YES (54 refs) | ✅ CLEAN |
| `Engine/LocalRustRuntime.swift` | Wraps Rust FFI as AgentRuntime | Minimal (1 ref) | ⚠️ STUB |
| `Engine/ClaudeManagedRuntime.swift` | CMA API wrapper (experimental) | Minimal (1 ref) | ⚠️ STUB |
| `Engine/DataviewService.swift` | Dataview query parser | **NO** | ⚠️ ORPHANED |
| `Engine/HookRegistry.swift` | Plugin lifecycle hooks | **NO** | ⚠️ ORPHANED |
| `Engine/CredentialPool.swift` | Multi-key rotation | **NO** | ⚠️ ORPHANED |
| `Models/EpistemicStatus.swift` | Certainty + evidence metadata | **NO** | ⚠️ ORPHANED |
| `Vault/LiveNoteScanner.swift` | Scans for live_note: true | **NO** | ⚠️ ORPHANED |
| `Vault/LiveNoteExecutor.swift` | Executes scheduled live notes | **NO** | ⚠️ ORPHANED |
| `EpistemosTests/OpenAILiveSweepTests.swift` | Gated OpenAI tests | YES (test target) | ✅ CLEAN |
| `scripts/release/notarize.sh` | Local notarization script | YES (release.yml) | ✅ CLEAN |

---

## SECTION 3: ISSUES REQUIRING ACTION

### 🔴 BROKEN (Must Fix)

**B1: NoteBacklinksPanel.swift — Missing Method**
- File: `Epistemos/Views/Notes/NoteBacklinksPanel.swift`
- Issue: Calls `graphState.incomingEdges(forPageId:)` which doesn't exist
- Fix: Either implement the method on GraphState or remove the graph edge query

### 🟡 WARNINGS (Should Fix)

**W1: GraphTypes.swift — Rust Enum Mismatch**
- Swift has 14 node types (0-13), Rust graph-engine has 8 (0-7)
- Impact: Entity types (person/project/topic/decision/event/resource) silently become Note on Rust side
- Fix: Update `graph-engine/src/types.rs` NodeType enum to match

**W2: SessionState::Running Field Change**
- `Running` may have changed from unit variant to `Running { turn: u32 }`
- Impact: `matches!(handle.state, SessionState::Running)` won't match the struct variant
- Fix: Update to `matches!(handle.state, SessionState::Running { .. })`

**W3: 8 Orphaned New Files**
- KnowledgeIndexBuilder, DataviewService, HookRegistry, CredentialPool, EpistemicStatus, LiveNoteScanner, LiveNoteExecutor, LocalRustRuntime
- Impact: Dead code that compiles but never executes
- Fix: Wire each into AppBootstrap/AppCoordinator OR remove if deferred

### 🟢 CLEAN (No Action Needed)

Everything else passed audit.

---

## SECTION 4: WHAT CODEX SHOULD DO

### Pass 1: Verify All Changes Exist
For every file in Sections 1-2, open it and confirm the described additions are present. If any are missing (possibly written to wrong path), re-apply from this document.

### Pass 2: Fix Broken Items
1. Fix B1 (NoteBacklinksPanel missing method)
2. Fix W2 (SessionState Running field matching)

### Pass 3: Wire Orphaned Files
For each orphaned file, decide: wire it in or remove it.
- **Wire KnowledgeIndexBuilder** → call from EntityExtractor.scanVault() after graph rebuild, or from AppBootstrap
- **Wire LiveNoteScanner/Executor** → start LiveNoteSchedulerService from AppBootstrap
- **Wire HookRegistry** → register in AppBootstrap, fire hooks from agent loop bridge
- **Wire CredentialPool** → load from Keychain in AppBootstrap, use from LLMService
- **Wire DataviewService** → register as code block renderer in ProseTextView2
- **Wire EpistemicStatus** → integrate into VaultChatMutator when writing facts

### Pass 4: Build + Test
```bash
# Rust
export PATH="$HOME/.cargo/bin:$PATH"
cargo test --manifest-path agent_core/Cargo.toml
# Expected: 245+ passed, 0 failed

cargo clippy --manifest-path agent_core/Cargo.toml -- -D warnings

# Swift
cd /Users/jojo/Downloads/Epistemos
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swiftlint
```

### Pass 5: Release Closeout
After all fixes, run the 5-gate release protocol:
1. Local-model release sweep
2. SSM live proof (Liquid 350M + Mamba2)
3. OpenAI live sweep
4. Graph feel pass (manual)
5. Signed release path (build → DMG → notarize → staple)

---

## SECTION 5: FILES NOT TOUCHED (Verified Intact)

These critical files were **audited but NOT modified**. Codex should verify they're still clean:
- `Epistemos/Vault/SkillEvolutionService.swift` (874 lines — verified complete, NOT overwritten)
- `Epistemos/Vault/VaultLifecycleService.swift` (794 lines — verified complete, NOT overwritten)
- `agent_core/src/storage/neural_cache.rs` (373 lines — verified complete, NOT overwritten)
- `agent_core/src/evolution/mutation_proposer.rs` (317 lines — verified complete, NOT overwritten)
- `agent_core/src/evolution/trace_analyzer.rs` (335 lines — verified complete, NOT overwritten)
- `epistemos-core/src/instant_recall/turbo_quant.rs` (verified complete, NOT overwritten)
- All 14 Metal Mamba-2 shader files (verified complete, NOT overwritten)

---

*End of Session Audit*
