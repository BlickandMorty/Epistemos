# Sprint Omega-5: Living Vault Memory Engine
## Duration: 3-4 sessions | Priority: HIGH — the feature that makes Epistemos compound in value

Prerequisite: Sprints Omega-1 through Omega-4 must be complete and verified.

---

## Pre-Read

```bash
cat CLAUDE.md
cat docs/AGENT_PROGRESS.md
cat docs/agent-system/LIVING_VAULT_ARCHITECTURE.md
```

Confirm: "Architecture read. Sprint Omega-5: Living Vault. First task: diff engine."

---

## What This Sprint Does

Builds the self-editing memory engine that makes the vault a living mind. After this sprint, every conversation automatically persists as searchable markdown, every vault file carries strength/decay metadata, every mutation is a git-committed diff (not a rewrite), and cross-file contradictions are detected and resolved automatically.

## Tasks

### Task 1: Diff Engine (Rust)

**Create:** `agent_core/src/storage/diff_engine.rs`

The diff engine generates patches from two text states. It never rewrites entire files.

**Requirements:**
- `generate_text_diff(old: &str, new: &str) -> UnifiedDiff` — unified diff using the `similar` crate
- `generate_json_diff(old: &Value, new: &Value) -> Vec<JsonPatch>` — tree-walking diff for structured data, emitting path-based operations (add/remove/replace at JSON pointer paths)
- `apply_text_patch(original: &str, diff: &UnifiedDiff) -> Result<String, DiffError>` — applies a unified diff to text content
- `DiffHunk` struct: `{ old_start, old_count, new_start, new_count, lines: Vec<DiffLine> }`
- `DiffLine` enum: `Context(String)`, `Add(String)`, `Remove(String)`
- Fuzzy matching: if the target text has shifted by up to 3 lines from the expected position, the patcher should still find and apply the hunk
- Add `similar = "2"` to agent_core/Cargo.toml

**Tests:** generate diff from two strings, apply it back, result matches the new string. JSON diff on nested objects. Fuzzy apply when context has shifted. Empty diff when inputs are identical.

**Verify:**
```bash
grep -c "generate_text_diff\|generate_json_diff\|apply_text_patch" agent_core/src/storage/diff_engine.rs
cargo test --manifest-path agent_core/Cargo.toml -- diff_engine 2>&1 | tail -5
```

### Task 2: Memory Classifier (Rust)

**Create:** `agent_core/src/storage/memory_classifier.rs`

The four-operation classifier that decides ADD/UPDATE/DELETE/NOOP before every vault write.

**Requirements:**
- `MemoryOperation` enum: `Add`, `Update { target_file, target_section }`, `Delete { target_file, target_section, reason }`, `Noop { reason }`
- `classify_memory_operation(incoming: &str, existing_facts: &[VaultFact]) -> MemoryOperation`
- `VaultFact` struct: `{ file_path, section, content, embedding: Vec<f32>, strength: f64, last_accessed: DateTime }`
- Embedding similarity threshold: cosine > 0.85 means potential match → needs classification
- When no existing facts match (cosine < 0.85 for all), always returns `Add`
- When a match is found, uses a prompt template to classify: does the incoming fact confirm, update, or contradict the existing fact?
- The prompt template must be under 200 tokens to keep classification fast
- For local classification, call the existing constrained decoding pipeline (Qwen/Hermes via LocalAgentLoop)
- Fallback to Haiku for classification if local model is unavailable

**Tests:** identical facts return NOOP, contradictory facts return DELETE+ADD sequence, updated facts return UPDATE, novel facts return ADD.

**Verify:**
```bash
grep -c "MemoryOperation\|classify_memory_operation\|VaultFact" agent_core/src/storage/memory_classifier.rs
cargo test --manifest-path agent_core/Cargo.toml -- memory_classifier 2>&1 | tail -5
```

### Task 3: Ebbinghaus Decay Engine (Rust)

**Create:** `agent_core/src/storage/memory_decay.rs`

Strength decay for vault nodes. Facts you use stay. Facts you don't fade.

**Requirements:**
- `NodeStrength` struct: `{ strength: f64, importance: Importance, decay_rate: f64, last_accessed: DateTime, access_count: u32, pinned: bool }`
- `Importance` enum: `Critical` (λ=0.005/day), `High` (λ=0.01), `Normal` (λ=0.05), `Low` (λ=0.1)
- `decay(node: &mut NodeStrength, now: DateTime)` — applies `strength *= e^(-λ × days_elapsed)`, resets elapsed clock
- `access(node: &mut NodeStrength)` — resets strength to 1.0, increments access_count, updates last_accessed
- `pin(node: &mut NodeStrength)` — sets pinned=true, strength stays at 1.0 regardless of decay
- `collect_garbage(nodes: &mut Vec<NodeStrength>, threshold: f64) -> Vec<NodeStrength>` — returns and removes nodes below threshold (default 0.15)
- `batch_decay(nodes: &mut [NodeStrength], now: DateTime)` — applies decay to all nodes efficiently
- Pinned nodes never decay. Accessed nodes reset to 1.0.

**Tests:** node decays to ~0.37 after 1/λ days, pinned node stays at 1.0, accessed node resets, garbage collection removes weak nodes, batch decay handles 10K nodes in <10ms.

**Verify:**
```bash
grep -c "NodeStrength\|decay\|collect_garbage\|batch_decay" agent_core/src/storage/memory_decay.rs
cargo test --manifest-path agent_core/Cargo.toml -- memory_decay 2>&1 | tail -5
```

### Task 4: Cross-File Propagation Scanner (Rust)

**Create:** `agent_core/src/storage/cross_propagation.rs`

When a vault file is patched, scan all other files for references to the changed entity and generate secondary patches.

**Requirements:**
- `PropagationResult` struct: `{ primary_diff, secondary_diffs: Vec<(PathBuf, UnifiedDiff)>, all_atomic: bool }`
- `scan_for_references(changed_entity: &str, vault_root: &Path, exclude: &Path) -> Vec<(PathBuf, String, usize)>` — returns (file, matched_line, line_number) for every file that references the entity
- Uses tantivy search (already in agent_core) for fast full-text lookup
- `generate_propagation_diffs(primary_diff: &UnifiedDiff, references: &[(PathBuf, String, usize)]) -> Vec<(PathBuf, UnifiedDiff)>` — for each reference, determine if it needs updating based on the primary diff
- All diffs (primary + secondary) must be committed atomically — if any secondary diff fails to apply, the entire batch is rolled back

**Tests:** changing "Claude costs $15" in one file generates an update diff in another file that references "Claude costs $15". Files with no reference to the changed entity get no diffs. Atomic commit rolls back on failure.

**Verify:**
```bash
grep -c "PropagationResult\|scan_for_references\|generate_propagation_diffs" agent_core/src/storage/cross_propagation.rs
cargo test --manifest-path agent_core/Cargo.toml -- cross_propagation 2>&1 | tail -5
```

### Task 5: Git Commit Integration (Rust)

**Create:** `agent_core/src/storage/vault_git.rs`

Programmatic git commits for every vault mutation. Uses libgit2 via the `git2` crate.

**Requirements:**
- `VaultGit` struct wrapping a `git2::Repository`
- `VaultGit::open(vault_root: &Path) -> Result<Self>` — opens existing repo or initializes new one
- `commit_diffs(diffs: &[(PathBuf, UnifiedDiff)], message: &str, operation: MemoryOperation) -> Result<git2::Oid>`
- Structured commit message format: `[MEMORY:{operation}] {file_path}\n  - {change_summary}\n  - source: {source}\n  - strength: {strength}`
- `history(file_path: &Path, limit: usize) -> Vec<CommitInfo>` — returns recent commits touching this file
- `diff_between(old_commit: Oid, new_commit: Oid) -> String` — shows what changed between two commits
- Add `git2 = "0.19"` to agent_core/Cargo.toml (uses bundled libgit2, no system dependency)

**Tests:** initialize repo, commit a diff, verify history returns it, diff_between shows the change.

**Verify:**
```bash
grep -c "VaultGit\|commit_diffs\|history" agent_core/src/storage/vault_git.rs
grep "git2" agent_core/Cargo.toml
cargo test --manifest-path agent_core/Cargo.toml -- vault_git 2>&1 | tail -5
```

### Task 6: Auto-Documenting Conversation Persistence (Swift)

**Create:** `Epistemos/Vault/ConversationPersistence.swift`

Every conversation auto-saves as dual-format JSONL + companion markdown.

**Requirements:**
- `ConversationPersistence` actor that manages file I/O off the main thread
- `appendTurn(turn: ConversationTurn, sessionID: UUID)` — appends one JSONL line to `sessions/<uuid>.jsonl`
- `generateCompanionMarkdown(sessionID: UUID) -> URL` — creates/updates the human-readable markdown file in `chats/{type}/{date}-{title}.md`
- `ConversationTurn` struct: `id, parentID, timestamp, role, content, model, tokens, toolCalls, vaultMutations, latencyMs`
- File hierarchy: `chats/main/`, `chats/mini/`, `chats/agentic/`
- On session end, trigger the memory flush (extract durable facts → classify → diff → commit)
- Uses existing `VaultSyncService` for file watching and index updates

**Tests:** append 3 turns, verify JSONL has 3 lines, verify markdown file exists and contains all 3 turns, verify session end triggers memory flush call.

**Verify:**
```bash
grep -c "ConversationPersistence\|appendTurn\|generateCompanionMarkdown" Epistemos/Vault/ConversationPersistence.swift
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3
```

### Task 7: Vault Chat Mutation Interface (Swift)

**Create:** `Epistemos/Vault/VaultChatMutator.swift`

The UI component where users send messages that directly mutate vault files via diffs.

**Requirements:**
- `VaultChatMutator` @Observable class that takes a message, generates a diff, and presents it for approval
- `mutate(message: String, targetVault: VaultIdentity) async -> DiffResult`
- Calls the Rust memory classifier via UniFFI to determine the operation
- Calls the Rust diff engine to generate the patch
- Presents the diff in a staging area view (DiffApprovalSheet)
- On approval, calls VaultGit.commit_diffs()
- On rejection, discards the diff
- In auto mode (for agent-driven mutations), skips approval and commits directly with agent reasoning as commit message

**Verify:**
```bash
grep -c "VaultChatMutator\|mutate\|DiffResult" Epistemos/Vault/VaultChatMutator.swift
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -3
```

### Task 8: Multi-Vault Registry (Swift + Rust)

**Create:** `agent_core/src/vault_registry.rs` and `Epistemos/Vault/VaultRegistry.swift`

The identity→vault mapping that enables switching between personal, model, agent, and team vaults.

**Rust requirements:**
- `VaultIdentity` enum: `Model(String)`, `Agent(String)`, `Team(Vec<String>)`, `UseCase(String)`, `Personal`
- `VaultRegistry` struct with `register(identity, path)`, `resolve(identity) -> Option<PathBuf>`, `list() -> Vec<(VaultIdentity, PathBuf)>`
- `merge_vaults(identities: &[VaultIdentity]) -> MergedVaultView` — creates a read-only view combining multiple vaults with priority ordering (agent > model > personal)
- UniFFI export for Swift access

**Swift requirements:**
- `VaultSwitcher` SwiftUI view showing available vaults with icons
- Selecting a vault updates the context compiler source and the graph view filter
- Visual indicators: vault icon + name + node count + last modified

**Verify:**
```bash
grep -c "VaultIdentity\|VaultRegistry\|merge_vaults" agent_core/src/vault_registry.rs
grep -c "VaultSwitcher\|VaultRegistry" Epistemos/Vault/VaultRegistry.swift
cargo test --manifest-path agent_core/Cargo.toml -- vault_registry 2>&1 | tail -5
```

### Task 9: Full Compilation + Integration Test

Run everything:

```bash
echo "=== Sprint Omega-5 Full Verification ==="

echo "--- Rust compilation ---"
cargo check --manifest-path agent_core/Cargo.toml 2>&1 | tail -3
cargo test --manifest-path agent_core/Cargo.toml 2>&1 | tail -5

echo "--- New modules exist ---"
for f in \
  agent_core/src/storage/diff_engine.rs \
  agent_core/src/storage/memory_classifier.rs \
  agent_core/src/storage/memory_decay.rs \
  agent_core/src/storage/cross_propagation.rs \
  agent_core/src/storage/vault_git.rs \
  agent_core/src/vault_registry.rs \
  Epistemos/Vault/ConversationPersistence.swift \
  Epistemos/Vault/VaultChatMutator.swift \
  Epistemos/Vault/VaultRegistry.swift; do
  [ -f "$f" ] && echo "✅ $f" || echo "❌ MISSING: $f"
done

echo "--- Module wiring ---"
grep -c "diff_engine\|memory_classifier\|memory_decay\|cross_propagation\|vault_git\|vault_registry" agent_core/src/lib.rs

echo "--- Swift build ---"
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build 2>&1 | tail -5

echo "--- New Rust tests ---"
for mod in diff_engine memory_classifier memory_decay cross_propagation vault_git vault_registry; do
  echo "$mod:"
  cargo test --manifest-path agent_core/Cargo.toml -- $mod 2>&1 | grep "test result" || echo "  no tests found"
done

echo "--- No regressions ---"
cargo test --manifest-path agent_core/Cargo.toml 2>&1 | grep "test result"
cargo test --manifest-path omega-mcp/Cargo.toml 2>&1 | grep "test result"

./scripts/verify/omega_verify.sh --quick
```

---

## Sprint Omega-6 Preview (Context Compiler + Graph Visualizer)

After Sprint Omega-5, the vault has a living memory engine. Sprint Omega-6 adds the brain that reads from it and the eyes that see into it:

- `agent_core/src/context_compiler.rs` — prompt DAG assembly with cache-optimal ordering
- `agent_core/src/context_compiler/skill_router.rs` — embedding-based skill selection
- `agent_core/src/context_compiler/example_bank.rs` — few-shot retrieval + ranking
- `Epistemos/Views/Graph/AgentGraphView.swift` — Metal-rendered knowledge graph (start with Grape)
- `Epistemos/Views/Graph/SemanticZoomController.swift` — 5-level zoom hierarchy
- `Epistemos/Views/Graph/NodeDetailPanel.swift` — inline node editing with live diff preview
- Optimization loop: DSPy-style prompt refinement against test-suite.yaml
