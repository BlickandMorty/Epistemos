# Epistemos — Remaining Work for Codex
## Everything that's NOT done yet. Complete these, then ship.

**Date:** April 9, 2026
**Codebase:** `/Users/jojo/Downloads/Epistemos/`
**Context:** The original EPISTEMOS-CODEX-PLAN.md v3 had ~18 tasks across 9 phases. Codex completed the majority. This doc covers ONLY what's left.

**Research docs** (all in `/Users/jojo/Downloads/`):
- `new.md` through `new4.txt` — CMA + Rowboat + MCP integration
- `man.txt` through `man7final.md` — Vault memory architecture
- `CMS-X (v3).md`, `CMS-X (final).md` — Applied research (TRACED, BeliefShift, GHRR)
- `last feature after new agents/LIVING_VAULT_ARCHITECTURE.md` — Diff engine, decay, git
- `last feature after new agents/sprint-omega-5-living-vault.md` — Sprint Omega-5 exact specs
- `tex.txt`, `tex2.txt` — TextKit compatibility (macOS 26 rendering bugs)
- `IDE 1.txt`, `IDE2.md`, `IDE3.md` — Code editor features (post-release)
- `opt.txt` through `opt6.md` — Editor performance optimization (post-release)
- `/Users/jojo/Downloads/rowboat/` — Cloned Rowboat source (Live Notes pattern)

---

# SECTION A: RELEASE BLOCKERS (Must complete before ship)

These are live-proof tasks, not code churn. The architecture is done.

---

## A.1 — Codesigning + Notarization Pipeline

**Status:** release.yml exists but uses `CODE_SIGNING_ALLOWED=NO`. No notarization.

**Files to modify:**
- `/Users/jojo/Downloads/Epistemos/.github/workflows/release.yml`
- Create `/Users/jojo/Downloads/Epistemos/scripts/notarize.sh`

**What to add to release.yml** after DMG creation step:

```yaml
- name: Codesign
  run: |
    codesign --deep --force --options runtime \
      --sign "${{ secrets.DEVELOPER_ID_APPLICATION }}" \
      --entitlements Epistemos/Epistemos.entitlements \
      build/Epistemos.app

- name: Create DMG
  run: |
    hdiutil create -volname "Epistemos" -srcfolder build/Epistemos.app \
      -ov -format UDZO build/Epistemos-${{ github.ref_name }}.dmg

- name: Notarize
  run: |
    xcrun notarytool submit build/Epistemos-${{ github.ref_name }}.dmg \
      --apple-id "${{ secrets.APPLE_ID }}" \
      --password "${{ secrets.NOTARIZATION_PASSWORD }}" \
      --team-id "${{ secrets.TEAM_ID }}" \
      --wait

- name: Staple
  run: |
    xcrun stapler staple build/Epistemos-${{ github.ref_name }}.dmg
```

**GitHub Secrets needed** (user must configure manually — Codex cannot):
- `DEVELOPER_ID_APPLICATION` — signing identity string
- `APPLE_ID` — Apple ID email
- `NOTARIZATION_PASSWORD` — app-specific password
- `TEAM_ID` — Apple Developer team ID

**Verification:** Download built DMG, open on clean macOS install, should not show "unidentified developer" warning.

---

## A.2 — OpenAI Dedicated Smoke Test

**Status:** OpenAI provider works (`openai.rs`) but has no dedicated validation test file.

**Create:** `EpistemosTests/OpenAILiveSweepTests.swift`

```swift
import Testing
@testable import Epistemos

/// Live OpenAI sweep — requires real API key and /tmp/epi-live-openai-sweep gate file.
/// Tests fast, thinking, pro, and agent paths with real output checks.
struct OpenAILiveSweepTests {

    /// Gate: only run when explicitly enabled
    static let isEnabled = FileManager.default.fileExists(atPath: "/tmp/epi-live-openai-sweep")

    @Test("gpt-4o-mini fast path produces coherent response")
    func fastPath() async throws {
        try XCTSkipUnless(Self.isEnabled, "Live OpenAI sweep not enabled")
        // Send simple prompt to gpt-4o-mini
        // Verify response is non-empty, coherent, finishes normally
    }

    @Test("gpt-4o thinking path with extended reasoning")
    func thinkingPath() async throws {
        try XCTSkipUnless(Self.isEnabled, "Live OpenAI sweep not enabled")
        // Send complex reasoning prompt to gpt-4o
        // Verify thinking tokens emitted, final response coherent
    }

    @Test("o3-mini agent path with tool calling")
    func agentPath() async throws {
        try XCTSkipUnless(Self.isEnabled, "Live OpenAI sweep not enabled")
        // Send task requiring tool use to o3-mini
        // Verify tool_use events, tool_result handling, final synthesis
    }

    @Test("gpt-4o vision with image attachment")
    func visionPath() async throws {
        try XCTSkipUnless(Self.isEnabled, "Live OpenAI sweep not enabled")
        // Send image + prompt to gpt-4o
        // Verify vision response references image content
    }

    @Test("permission-sensitive tool flow requires approval")
    func permissionFlow() async throws {
        try XCTSkipUnless(Self.isEnabled, "Live OpenAI sweep not enabled")
        // Send task requiring destructive tool (bash_execute)
        // Verify approval gate fires, session pauses
    }
}
```

**Verification:** `touch /tmp/epi-live-openai-sweep && xcodebuild test -scheme Epistemos -only-testing:EpistemosTests/OpenAILiveSweepTests`

---

## A.3 — TextKit 2 Compatibility Audit

**Status:** Not addressed. `tex.txt` and `tex2.txt` document macOS 26 rendering bugs with TextKit 1 vs TextKit 2 conflicts.

**Files to read first:**
- `/Users/jojo/Downloads/tex.txt`
- `/Users/jojo/Downloads/tex2.txt`
- `Epistemos/Views/Notes/ProseTextView2.swift` (NSTextView subclass)
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift` (TextKit bridge)

**What to check:**
1. Is ProseTextView2 using TextKit 1 or TextKit 2? If TK1: verify it doesn't crash on macOS 26 with layer-backed views.
2. Are there `layoutManager` calls that should be `textLayoutManager` on TK2?
3. Are there glyph visibility issues with the current NSTextStorage bridge?
4. Check for any `#available(macOS 26, *)` guards needed.

**This is an audit + fix task, not a new feature.** Read the tex docs, compare against the current editor code, fix any incompatibilities.

---

# SECTION B: HIGH-VALUE COMPLETIONS (Finish what's 80% done)

---

## B.1 — Incremental Graph Building (Task 0.1 — PARTIAL → DONE)

**What exists:** `vault.rs` has `content_hash()` function and DB schema stores hash.
**What's missing:** EntityExtractor doesn't use it.

**In `agent_core/src/storage/vault.rs`, add:**
```rust
/// Get stored content hash for a note path. Returns None if path not indexed.
pub fn get_content_hash(&self, path: &str) -> Result<Option<String>, VaultError> {
    let conn = self.db.lock().map_err(|_| VaultError::DatabaseError("lock".into()))?;
    let mut stmt = conn.prepare("SELECT content_hash FROM notes WHERE path = ?1")?;
    let hash: Option<String> = stmt.query_row(params![path], |row| row.get(0)).optional()?;
    Ok(hash)
}

/// Update stored content hash after successful processing.
pub fn set_content_hash(&self, path: &str, hash: &str) -> Result<(), VaultError> {
    let conn = self.db.lock().map_err(|_| VaultError::DatabaseError("lock".into()))?;
    conn.execute(
        "UPDATE notes SET content_hash = ?1 WHERE path = ?2",
        params![hash, path],
    )?;
    Ok(())
}

/// Given a list of paths, return only those whose current file hash differs from stored hash.
pub fn changed_paths_since(&self, paths: &[String]) -> Result<Vec<String>, VaultError> {
    let mut changed = Vec::new();
    for path in paths {
        let stored = self.get_content_hash(path)?;
        let current = self.content_hash(&std::path::PathBuf::from(&self.vault_root).join(path));
        match (stored, current) {
            (Some(s), Some(c)) if s == c => {} // unchanged, skip
            _ => changed.push(path.clone()),    // new, changed, or missing
        }
    }
    Ok(changed)
}
```

**In `Epistemos/Graph/EntityExtractor.swift`, modify `scanVault()`:**
Before the batch processing loop, filter notes:
```swift
// Get all note paths
let allPaths = activePages.map { $0.vaultRelativePath }

// Ask VaultStore which ones changed since last extraction
let changedPaths = try await knowledgeCoreBridge.changedPaths(among: allPaths)

// Only process changed notes through LLM extraction
let notesToProcess = activePages.filter { changedPaths.contains($0.vaultRelativePath) }

// After successful extraction of each note, update its stored hash
for note in processedNotes {
    try await knowledgeCoreBridge.setContentHash(path: note.vaultRelativePath, hash: note.currentHash)
}
```

**Verification:** Scan 100-note vault. Edit 1 note. Rescan. Only 1 LLM call should fire.

---

## B.2 — Knowledge Index in Agent Prompts (Task 0.2 — NOT DONE → DONE)

**Create `Epistemos/Engine/KnowledgeIndexBuilder.swift`:**

```swift
/// Builds a compact entity table injected into every agent system prompt.
/// Enables entity resolution by lookup instead of search.
actor KnowledgeIndexBuilder {

    struct EntityEntry {
        let name: String
        let type: String      // note, project, person, topic
        let path: String      // vault-relative
        let modified: Date
    }

    private var cachedIndex: String?
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 30  // seconds

    /// Build compact markdown table from GraphStore.
    /// Cap at 150 entries, sorted by last_modified desc.
    func buildIndex(context: ModelContext) async -> String {
        if let cached = cachedIndex,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheTTL {
            return cached
        }

        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate { $0.type == 0 || $0.type == 4 }, // note or folder
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let nodes = (try? context.fetch(descriptor)) ?? []
        let capped = nodes.prefix(150)

        var table = "## Your Knowledge Graph\n"
        table += "| Note | Type | Path |\n|------|------|------|\n"
        for node in capped {
            let typeName = GraphNodeType(rawValue: node.type)?.displayName ?? "note"
            table += "| \(node.label) | \(typeName) | \(node.sourceId ?? "") |\n"
        }

        cachedIndex = table
        cacheTimestamp = Date()
        return table
    }
}
```

**Inject into `HermesPromptBuilder.systemPrompt()`:**
```swift
let knowledgeIndex = await knowledgeIndexBuilder.buildIndex(context: modelContext)
let systemPrompt = """
\(knowledgeIndex)

You are a function calling AI model...
"""
```

**Also inject into Rust `agent_core/src/agent_loop.rs`** `build_system_prompt()`:
Read `.epistemos/knowledge_index.md` (written by Swift on app launch / graph rebuild) and prepend to system prompt.

**Verification:** Start agent session, ask "find my notes about [topic that exists]". Agent should reference the exact path from the index on first turn without searching.

---

## B.3 — CMS-X Logarithmic Inertia in Decay Engine (Task 1.3 enhancement)

**In `agent_core/src/storage/memory_decay.rs`, find the decay calculation and add:**

```rust
impl NodeStrength {
    /// CMS-X conceptual inertia: frequently-accessed facts resist displacement.
    /// Reference: CMS-X (v3).md §3.1 Concept Packet — m_i parameter.
    fn effective_decay_rate(&self) -> f64 {
        let base = self.decay_rate;
        // Logarithmic inertia: access_count=1 → 1.0x, 50 → ~0.26x, 1000 → ~0.14x
        base / (1.0 + (self.access_count.max(1) as f64).ln())
    }
}
```

Replace all uses of `self.decay_rate` in the `decay()` method with `self.effective_decay_rate()`.

**Verification:** Create two nodes with same importance. Access one 50 times. Run batch_decay. The frequently-accessed node should have decayed ~4x less.

---

## B.4 — Session State Machine (Task 0.4 — PARTIAL → DONE)

**In `agent_core/src/session.rs`, extend SessionState:**

```rust
#[derive(Debug, Clone, PartialEq)]
pub enum SessionState {
    Idle,
    Running { turn: u32 },
    PausedForApproval {
        tool_name: String,
        args_json: String,
        deadline: std::time::SystemTime,
    },
    Rescheduled {
        next_run: std::time::SystemTime,
        reason: RescheduleReason,
    },
    Completed {
        turns: u32,
        input_tokens: u64,
        output_tokens: u64,
    },
    Failed { error: String },
    Terminated,  // user-cancelled (distinct from Failed)
}

#[derive(Debug, Clone, PartialEq)]
pub enum RescheduleReason {
    BudgetExceeded { spent_usd: f64, limit_usd: f64 },
    RateLimited { retry_after: std::time::SystemTime },
    NightBrainDeferred,
}
```

Add transition methods to `SessionRegistry`:
```rust
pub fn pause_for_approval(&self, id: &str, tool_name: &str, args_json: &str)
pub fn resume_from_approval(&self, id: &str)
pub fn reschedule(&self, id: &str, next_run: SystemTime, reason: RescheduleReason)
pub fn terminate(&self, id: &str)  // distinct from cancel — user-initiated
```

**Verification:** Trigger a Destructive-risk tool → session transitions to PausedForApproval. Cancel a session → Terminated (not Failed).

---

## B.5 — Transparent Working Memory File (Task 2.1 — PARTIAL → DONE)

**What exists:** context_loader.rs loads memory files at session start.
**What's missing:** No per-session `working-memory.md` file written during execution.

**In `agent_core/src/agent_loop.rs`, after each tool execution completes:**

```rust
// Write working memory snapshot
let wm_path = format!(".epistemos/sessions/{}/working-memory.md", session_id);
let wm_content = format!(
    "---\nsession_id: {}\nobjective: \"{}\"\nstatus: running\nturn: {}\n---\n\n\
     ## Goal\n{}\n\n\
     ## Completed Actions\n{}\n\n\
     ## Open Questions\n{}\n",
    session_id,
    objective,
    current_turn,
    objective,
    completed_actions_summary,
    open_questions_summary,
);
let _ = vault.write(&wm_path, &wm_content, &[], false).await;
```

**On session resume (in context_loader.rs or agent_loop bootstrap):**
```rust
// Check for existing working memory
let wm_path = format!(".epistemos/sessions/{}/working-memory.md", session_id);
if vault.exists(&wm_path).await {
    let wm = vault.read(&wm_path).await?;
    // Inject as first context block after L4 identity
    messages.insert(1, Message::system(&format!("<working_memory>\n{}\n</working_memory>", wm)));
}
```

**Verification:** Start agent session. Mid-session, check `.epistemos/sessions/{id}/working-memory.md` exists and has structured content. Kill session. Resume. Agent should reference prior progress.

---

# SECTION C: NEW FEATURES (High value, not started)

---

## C.1 — Cost Budget Enforcement (Task 0.5)

**In `agent_core/src/agent_loop.rs`:**

Add to `AgentConfig`:
```rust
pub max_cost_usd: Option<f64>,  // None = unlimited
```

In the loop, after each provider call:
```rust
if let Some(budget) = config.max_cost_usd {
    let spent = token_usage.estimate_cost_usd(); // use provider pricing matrix
    if spent >= budget {
        delegate.on_budget_exceeded(spent, budget);
        return Ok(AgentResult {
            final_content: vec![ContentBlock::Text {
                text: format!("Budget limit ${:.2} reached (spent ${:.2}). Task paused.", budget, spent)
            }],
            ..
        });
    }
}
```

**Verification:** Set budget to $0.001. Start agent. Should stop after first API call.

---

## C.2 — pkm_graph_neighbors MCP Tool (Task 0.3)

**In `agent_core/src/tools/registry.rs`, register:**

```rust
RegisteredTool {
    name: "pkm_graph_neighbors".to_string(),
    description: "Returns notes connected to a given note path via the knowledge graph. Includes edge types and weights.".to_string(),
    parameters: json!({
        "type": "object",
        "properties": {
            "path": { "type": "string", "description": "Vault-relative path" },
            "edge_types": { "type": "array", "items": { "type": "string" }, "description": "Filter: reference, related, supports, contradicts, expands, questions" },
            "depth": { "type": "integer", "description": "Hop depth (1 or 2)", "default": 1 }
        },
        "required": ["path"]
    }),
    risk_level: RiskLevel::ReadOnly,
    handler: Arc::new(/* handler that queries GraphStore via FFI */)
}
```

Handler queries Swift's GraphStore for edges matching the path, filters by edge_types if provided, and returns JSON.

---

## C.3 — TRACED Reasoning Trajectory Metrics (Task 9.1)

**Create `agent_core/src/reasoning_metrics.rs`:**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReasoningTrajectoryMetrics {
    pub displacement: f32,        // semantic distance: start → end
    pub path_length: f32,         // total semantic distance traveled
    pub curvature_ratio: f32,     // path_length / displacement (>4.0 = hesitation loop)
    pub loop_count: u32,          // repeated tool+args hash count
    pub error_count: u32,
    pub total_turns: u32,
    pub efficiency: f32,          // displacement / total_turns
    pub classification: TrajectoryClassification,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TrajectoryClassification {
    Efficient,      // curvature < 2.0, loops == 0
    Exploratory,    // curvature 2.0–4.0, displacement > 0.3
    Hesitating,     // curvature > 4.0 OR loops >= 3
    Stuck,          // displacement < 0.1, turns > 3
    Failed,         // errors > turns / 2
}

/// Compute from tool call log after session completes.
pub fn compute_trajectory_metrics(
    tool_calls: &[(String, String, String, bool)], // (name, args, result, is_error)
) -> ReasoningTrajectoryMetrics {
    // 1. Hash each (name, args) pair → detect loops
    // 2. Compute pairwise text similarity between consecutive tool results
    //    (bag-of-words cosine as lightweight proxy for embeddings)
    // 3. path_length = sum of consecutive distances
    // 4. displacement = distance(first, last)
    // 5. curvature = path_length / displacement.max(0.001)
    // 6. Classify based on thresholds
    todo!()
}
```

**Integration:** Call after session in `agent_loop.rs`. Store in `AgentResult.trajectory_metrics`.
**UI:** Show colored badge after session (green=Efficient, yellow=Hesitating, red=Stuck).

---

## C.4 — Live Notes (Task 3.1)

**This is the flagship proactive feature.** Read the Rowboat source at `/Users/jojo/Downloads/rowboat/` for the exact implementation pattern.

**Frontmatter schema:**
```yaml
---
live_note: true
---
```

**Task block in note body:**
````markdown
```task
{
  "instruction": "Find recent Apple Intelligence announcements",
  "schedule": { "type": "cron", "expression": "0 9 * * *" },
  "targetId": "apple-ai-updates",
  "lastRunAt": null
}
```
````

**Target region:**
```markdown
<!--task-target:apple-ai-updates-->
[agent writes here]
<!--/task-target:apple-ai-updates-->
```

**Implementation:**
1. New NightBrain job: `liveNoteUpdate`
2. Polls every 15 seconds via DispatchSourceTimer
3. Scans vault for notes with `live_note: true` frontmatter
4. Parses task blocks, checks schedule against `lastRunAt`
5. On trigger: spawn constrained agent session (web_search + vault_search only, vault_write only to THIS note)
6. Replace target region content, update `lastRunAt`
7. Commit via VaultGit

---

# SECTION D: RELEASE CLOSEOUT PROTOCOL

After Sections A–C are complete, execute these 5 gates in order:

1. **Local-model release sweep** — `touch /tmp/epi-live-local-model-release-sweep` → run tests → quarantine failures
2. **SSM live proof** — Wait for HF quota → rerun `verifyLiveSSMStateRoundTrip()` for LFM2.5-350M and mamba2-2.7b
3. **OpenAI live sweep** — `touch /tmp/epi-live-openai-sweep` → run OpenAILiveSweepTests → verify all paths
4. **Graph feel pass** — Manual test: zoom/pan/drag/hover on real data, verify no stutter on target machine
5. **Signed release** — Build Release, codesign, DMG, notarize, staple, clean-install smoke

**Final verification:** Zero-change pass. No code edits. Build → test → sign → install → smoke. If zero-fail → **SHIP**.

---

# Build & Commit Protocol

```bash
# Rust
cargo test --manifest-path /Users/jojo/Downloads/Epistemos/agent_core/Cargo.toml
cargo clippy --manifest-path /Users/jojo/Downloads/Epistemos/agent_core/Cargo.toml -- -D warnings

# Swift
cd /Users/jojo/Downloads/Epistemos
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
swiftlint
xcodebuild test -scheme Epistemos -destination 'platform=macOS' 2>&1 | xcbeautify
```

**Commit after EVERY task.** Reference task ID in message.

**Code standards:** No try!, no force-unwraps, all inference on background actors, DispatchQueue.main.async in UniFFI callbacks (never .sync), API keys in Keychain never UserDefaults, stream every token, preserve thinking blocks.

---

*End of EPISTEMOS-CODEX-REMAINING.md*
