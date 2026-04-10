# Implementation Advice Synthesis: Epistemos Agent Architecture
## Based on Analysis of 5 Research Papers on PKM, Agent Systems, and Performance Optimization

**Date:** April 7, 2026  
**Source Material:** 5 comprehensive research papers on Epistemos, Goose, OpenClaw, Hermes Agent, and native macOS agent architecture

---

## Executive Summary: The Unified Recommendation

After synthesizing all 5 research papers, a clear architectural vision emerges: **Epistemos has superior technical foundations but needs agent orchestration capabilities to compete.** The papers universally agree on three critical gaps:

1. **Subagent Orchestration** — Parallel task execution via spawned agents
2. **MCP Client Integration** — Consuming the ecosystem of third-party tools
3. **Real Computer Use** — AXUIElement accessibility tree, not just screenshots

The synthesis below provides implementation advice organized by priority, with specific technical recommendations drawn from the consensus of all research sources.

---

## Part 1: Critical Implementation Priorities (Do First)

### 1.1 Computer Use: The Accessibility Tree Paradigm

**The Consensus:** All 5 papers agree that pure screenshot-based computer use is insufficient. The layered targeting strategy (AXUIElement tree → OCR → VLM vision) is the hardened approach.

**Implementation Advice:**

```swift
// Recommended architecture from pkm4.txt and pkm3.md
actor ComputerUseBridge {
    // Layer 1: Accessibility Tree (primary)
    func captureAXTree(pid: pid_t?) async throws -> AXTreeNode {
        let systemWide = AXUIElementCreateSystemWide()
        let app = pid.map { AXUIElementCreateApplication($0) } ?? frontmostApp()
        return try await traverseAXTree(root: app)
    }
    
    // Heuristic pruning (pkm4.txt: 70-80% token reduction)
    private func pruneInteractiveOnly(_ node: AXTreeNode) -> AXTreeNode? {
        guard node.isInteractive || node.children.contains(where: \.isInteractive) else {
            return nil // Discard non-interactive structural containers
        }
        return AXTreeNode(
            role: node.role,
            label: node.label,
            value: node.value,
            frame: node.frame,
            elementID: node.elementID, // @e21 style reference for LLM
            children: node.children.compactMap(pruneInteractiveOnly)
        )
    }
    
    // Layer 2: Screen capture fallback
    func captureScreenshot(scale: CGFloat = 0.5) async -> Data {
        // Use ScreenCaptureKit for 60+ FPS, not CGWindowListCreateImage
        let filter = SCContentFilter(display: mainDisplay, excludingApplications: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(mainDisplay.width * scale)
        configuration.height = Int(mainDisplay.height * scale)
        // ... stream implementation
    }
}
```

**Key Implementation Details:**
- **Token efficiency:** Raw AX tree = 15k-60k tokens; pruned tree = 200-500 tokens (pkm4.txt)
- **Element referencing:** Use `@e21` style IDs instead of (x,y) coordinates for deterministic targeting
- **ScreenCaptureKit:** Required for real-time capture; CGDisplayCreateImage produces stale frames (pkm agent.txt)

**Provider-Specific Wiring:**
| Provider | Native API | Epistemos Bridge |
|----------|-----------|------------------|
| Claude | `computer_use_20251022` | Inject pruned AX tree as text block before screenshot |
| OpenAI | `computer_use_preview` | Map to AX element IDs; execute via CGEvent |
| Gemini | No native API | Full Swift-side implementation using AX tree |

---

### 1.2 Subagent Orchestration (The Goose Gap)

**The Consensus:** All papers identify subagent spawning as the highest-value missing feature. Goose's "Recipes" (YAML-defined subagents) and OpenClaw's Gateway pattern both support this.

**Implementation Advice:**

Use **Swift `async let` for concurrent agent execution** rather than true process spawning. This is lighter weight and sufficient for PKM use cases:

```rust
// In agent_core/src/subagent.rs
pub struct SubAgentCoordinator {
    max_concurrent: usize,
    active: HashMap<String, JoinHandle<AgentResult>>,
}

impl SubAgentCoordinator {
    pub async fn spawn_parallel(
        &self,
        objectives: Vec<String>,
        parent_context: &AgentContext,
    ) -> Vec<AgentResult> {
        // Fire N concurrent agent sessions
        let handles: Vec<_> = objectives
            .into_iter()
            .map(|obj| {
                let ctx = parent_context.scoped_clone();
                tokio::spawn(async move {
                    run_agent_loop(obj, ctx.provider, ctx.tools, ctx.delegate, ctx.config).await
                })
            })
            .collect();
        
        // Gather results
        futures::future::join_all(handles).await
            .into_iter()
            .filter_map(|r| r.ok())
            .collect()
    }
}
```

**Use Cases from Research:**
1. **Parallel note synthesis:** Spawn N subagents, each analyzing a subgraph, then synthesize (pkm3.md)
2. **Background indexing:** Research task runs in subagent while main chat continues (pkm4.txt)
3. **Code review:** "Frontend Developer" and "Backend Developer" agents in parallel (pkm agent.txt)

**Git Worktree Isolation (from pkm agent.txt):**
For destructive operations, use Git worktrees to prevent cross-contamination:
```bash
# Rust-level file tool creates temporary worktree
git worktree add -b agent-task-{id} /tmp/epistemos-task-{id}
# Subagent operates in /tmp/epistemos-task-{id}
# On completion: review diff, merge or discard
```

---

### 1.3 MCP Client Integration

**The Consensus:** Papers 1, 3, and 4 all identify MCP as the dominant 2025 standard. Without a client, Epistemos cannot use community tools (Playwright, Slack, Calendar, etc.).

**Implementation Advice:**

Implement the MCP client **in Rust** (not Swift) to keep it close to the tool registry:

```rust
// agent_core/src/mcp/client.rs
pub struct McpClient {
    servers: HashMap<String, McpServerConnection>,
}

pub struct McpServerConnection {
    process: Child,
    transport: McpTransport, // stdio or SSE
    tools: Vec<ToolSchema>,
}

impl McpClient {
    pub async fn discover_servers() -> Vec<McpServerConfig> {
        // Read ~/.config/mcp/servers.json
        // Parse per-project .epistemos/mcp.json
    }
    
    pub async fn connect(&mut self, config: McpServerConfig) -> Result<()> {
        // Spawn server process
        // Initialize via JSON-RPC initialize handshake
        // Fetch tools/list and register in ToolRegistry
    }
    
    pub async fn call_tool(&self, server: &str, tool: &str, args: Value) -> Result<String> {
        // JSON-RPC tools/call
        // Route through approval flow
    }
}
```

**Registry Integration (from pkm1.md):**
- Dynamic tool registration: MCP tools appear in `ToolRegistry.get_definitions()`
- Approval flow: MCP tools go through same permission gate as built-in tools
- No UI changes needed: Tool calls render the same way

---

## Part 2: Performance Hardening (Do Second)

### 2.1 FFI Optimization: Beyond UniFFI

**The Consensus:** Papers 1, 4, and pkm agent.txt all identify UniFFI overhead as a bottleneck for high-frequency operations. BoltFFI offers 1000× speedup for certain patterns.

**Implementation Advice:**

**Immediate fix (low risk):** Use `[UInt8]` buffers instead of String passing:

```rust
// Instead of: fn process_large_data(input: String) -> String
// Use: fn process_large_data(input: Vec<u8>) -> Vec<u8>

// Swift side receives UnsafeBufferPointer<UInt8>
// Bypasses UTF-8 validation and string allocation
```

**Advanced fix (medium risk):** Zero-copy shared memory for embedding vectors:

```rust
// agent_core/src/shared_memory.rs (exists but verify usage)
pub struct ShmEmbeddingBuffer {
    fd: c_int,
    ptr: *mut f32,
    len: usize,
}

// Map Metal MTLBuffer as shared memory for GPU→CPU zero copy
let buffer = device.makeBuffer(
    length: dimension * 4,
    options: .storageModeShared // NOT .storageModePrivate
)
```

**Benchmarks from pkm4.txt:**
- Metal-accelerated vector search: **0.84ms** for 10,000 vectors (vs 105ms CPU)
- BoltFFI vs UniFFI: **1000× faster** for struct materialization

---

### 2.2 SwiftData Reactivity: The Sidebar Fix

**The Consensus:** Papers 1, 3, and 4 all identify `@Query` as the root cause of sidebar stutter. The "structural fingerprinting" pattern is the accepted solution.

**Implementation Advice:**

**Current state:** You have a fingerprint guard in `rebuildCache()`, but `@Query` still fires.

**Correct fix (from pkm3.md and pkm agent.txt):**

```swift
// NotesBrowserView.swift - migrate to manual fetch
@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var items: [SidebarPageItem] = []
    
    private let context: ModelContext
    private var lastFingerprint: Int = 0
    
    func load() async {
        // Fetch on background actor
        let (newItems, newFingerprint) = await Task.detached {
            let context = ModelContext(container)
            let pages = try? context.fetch(FetchDescriptor<SDPage>())
            let items = pages?.map(SidebarPageItem.init) ?? []
            let fingerprint = items.structuralFingerprint
            return (items, fingerprint)
        }.value
        
        // Only update if fingerprint changed
        if newFingerprint != lastFingerprint {
            self.items = newItems
            self.lastFingerprint = newFingerprint
        }
    }
}

// Structural fingerprint only hashes sidebar-relevant fields
struct SidebarPageItem: Hashable {
    let id: String
    let title: String
    let isFavorite: Bool
    let folderID: String?
    // NOT including: body, updatedAt, wordCount
}
```

**Why this works:**
- `@Query` observes ALL properties; manual fetch observes ONLY what you check
- Body text mutations (5s auto-save) don't trigger sidebar rebuild
- Haptic throttling prevents scroll spam (pkm agent.txt)

---

### 2.3 Code Editor: Cached Parsing

**The Consensus:** Papers 1 and 4 identify redundant parsing as a major performance drain. Static regex and cached line splits are the solutions.

**Implementation Advice:**

You already have these fixes, but verify completeness:

```swift
// OutlineParser.swift - verify all patterns are static
extension OutlineParser {
    // Pre-compiled at app launch, not per-keystroke
    static let markdownHeaderRegex = try! NSRegularExpression(
        pattern: "^(#{1,6})\\s+(.+)$"
    )
    static let markCommentRegex = try! NSRegularExpression(
        pattern: "^\\s*//\\s*MARK:\\s*(.+)$"
    )
    static let swiftClassRegex = try! NSRegularExpression(
        pattern: #"^\s*(public|private|internal|open|fileprivate)?\s*(final\s+)?class\s+(\w+)"#
    )
}

// AIPartnerService.swift - verify line cache invalidation
final class AIPartnerService {
    private var currentLines: [String] = []
    private var lastContentHash: Int = 0
    
    func updateCode(_ content: String) {
        let hash = content.hashValue
        guard hash != lastContentHash else { return }
        
        currentLines = content.components(separatedBy: .newlines)
        lastContentHash = hash
        // ... rest of analysis
    }
}
```

**Impact from research:**
- Pre-compiled regex: **~5000× fewer compilations** per keystroke
- Cached line splits: **~10× fewer allocations** per keystroke

---

## Part 3: Intelligence Layer Expansion (Do Third)

### 3.1 Hermes-Style Periodic Nudge

**The Consensus:** Papers 1, 3, and 4 highlight the "periodic nudge" as a key Hermes innovation for continuous learning. Epistemos has meaning anchors on exit, but not mid-session reflection.

**Implementation Advice:**

```swift
// ChatCoordinator.swift
final class ChatCoordinator {
    private var turnCount = 0
    private let nudgeInterval = 15 // Every 15 assistant turns
    
    func handleAgentResponse(_ response: String) {
        turnCount += 1
        
        if turnCount % nudgeInterval == 0 {
            injectMemoryNudge()
        }
    }
    
    private func injectMemoryNudge() {
        let nudge = """
        [System reflection checkpoint]
        Pause and consider: Is there anything from this session worth 
        persisting to your memory? If so, use the memory tool to record it.
        """
        // Inject as system message (not shown to user)
        // Let the agent decide whether to call memory.add
    }
}
```

**Why this matters:**
- Frozen snapshot pattern keeps prompt cache valid (pkm1.md)
- Self-assessment without user prompting (pkm4.txt)
- MEMORY.md stays current across long sessions

---

### 3.2 Activity Profile: Dual Decay

**The Consensus:** Papers 3 and 4 suggest improving the activity score with dual decay (fast + slow signals).

**Implementation Advice:**

```swift
// ActivityTracker.swift - upgrade from single to dual decay
struct ActivityScore {
    let fastDecay: Double  // 7-day half-life (recent focus)
    let slowDecay: Double  // 90-day half-life (long-term importance)
    
    var combined: Double {
        0.7 * fastDecay + 0.3 * slowDecay
    }
}

func activityScore(for nodeID: String) -> ActivityScore {
    let edits = editHistory[nodeID] ?? []
    let visits = visitHistory[nodeID] ?? []
    
    let fast = computeDecay(edits + visits, halfLife: 7)
    let slow = computeDecay(edits + visits, halfLife: 90)
    
    return ActivityScore(fastDecay: fast, slowDecay: slow)
}
```

**Why this matters:**
- Fast signal captures "currently working on"
- Slow signal captures "important to user's long-term work"
- Prevents over-weighting of recent but trivial activity

---

### 3.3 Meaning Anchor Deduplication

**The Consensus:** Papers 3 and 4 identify anchor proliferation as a risk. Cosine similarity merging is the solution.

**Implementation Advice:**

```swift
// MeaningAnchorService.swift
func generateAnchor(from chat: SDChat) async throws {
    let newAnchor = try await createAnchor(chat)
    let newEmbedding = try await embeddingService.embed(newAnchor.topic)
    
    // Check for semantic duplicates
    let existingAnchors = try await fetchRecentAnchors(limit: 100)
    let similarAnchors = existingAnchors.filter { existing in
        let similarity = cosineSimilarity(newEmbedding, existing.embedding)
        return similarity > 0.85
    }
    
    if let duplicate = similarAnchors.first {
        // Merge insights instead of creating new node
        try await mergeAnchors(duplicate, newAnchor)
    } else {
        // Create new graph node
        try await createGraphNode(newAnchor, embedding: newEmbedding)
    }
}
```

---

## Part 4: UI/UX Polish (Do Fourth)

### 4.1 NSPopover Line Anchoring

**The Consensus:** Papers 1 and 3 note that popover anchor should point to specific lines, not the editor frame.

**Implementation Advice:**

```swift
// InlineSuggestionOverlay.swift
func showPopover(for suggestion: InlineSuggestion, in textView: NSTextView) {
    let lineNumber = suggestion.lineRange.lowerBound
    
    // Convert line number to rect in text view
    guard let lineRect = textView.rectForLine(lineNumber) else { return }
    
    // Convert to window coordinates
    let windowRect = textView.convert(lineRect, to: nil)
    
    // Show popover anchored to line
    popover.show(
        relativeTo: windowRect,
        of: textView.window!.contentView!,
        preferredEdge: .maxX
    )
}
```

---

### 4.2 Line Breakdown Panel Interactions

**The Consensus:** Paper 3 specifies four required interactions for the line breakdown panel.

**Implementation Checklist:**
- [ ] **Line jump:** Tap entry → scroll to line + flash gutter
- [ ] **Replace button:** Show diff view (before/after) before applying
- [ ] **Explain further:** Open focused chat pre-seeded with line content
- [ ] **Dismiss individual:** Each entry has × button to remove

---

## Part 5: Security Hardening (Do Throughout)

### 5.1 Smart Approvals

**The Consensus:** Papers 1, 3, and 4 all emphasize tiered approval based on risk levels.

**Current State (from pkm1.md):**
You have ReadOnly/Modification/Destructive risk levels with auto-approval for reads.

**Recommended Additions:**

```rust
// agent_core/src/security.rs
pub struct ApprovalPolicy {
    pub auto_approve_read_only: bool,      // true (current)
    pub auto_approve_modification: bool,   // false (current)
    pub auto_approve_destructive: bool,    // false (current)
    
    // New: Pattern-based escalation
    pub block_patterns: Vec<Regex>,        // rm -rf, mkfs, etc.
    pub require_confirmation_for: Vec<String>, // Specific tool+pattern combos
}

// New: Secret exfiltration scanning
pub fn scan_for_secrets(text: &str) -> Vec<SecretMatch> {
    // Detect API keys, credentials in tool outputs
    // Block if found
}
```

---

## Part 6: Implementation Roadmap

### Phase 1: Stability (Week 1)
| Task | Source | Effort |
|------|--------|--------|
| Fix Metal Sendable violation properly | pkm3.md | 1h |
| AX tree epsilon comparison in graph inspector | pkm3.md | 30m |
| Cache complexity analysis with 30s TTL | pkm3.md | 2h |
| EmbeddingService consolidation (last instance) | pkm1.md | 1h |

### Phase 2: Computer Use (Week 2)
| Task | Source | Effort |
|------|--------|--------|
| Implement `ComputerUseBridge.swift` with AX tree | pkm3.md, pkm4.txt | 4h |
| Per-provider routing (Claude/Gemini/OpenAI) | pkm3.md | 2h |
| Heuristic pruning (70-80% token reduction) | pkm4.txt | 2h |

### Phase 3: Subagents (Week 3)
| Task | Source | Effort |
|------|--------|--------|
| `SubAgentCoordinator` in Rust | pkm3.md, pkm agent.txt | 4h |
| Swift `async let` concurrent execution | pkm agent.txt | 2h |
| Git worktree isolation for destructive ops | pkm agent.txt | 2h |

### Phase 4: MCP (Week 4)
| Task | Source | Effort |
|------|--------|--------|
| MCP client in Rust | pkm1.md, pkm3.md | 8h |
| Server discovery via `~/.config/mcp/servers.json` | pkm3.md | 2h |
| Dynamic tool registration | pkm3.md | 2h |

### Phase 5: Intelligence (Week 5)
| Task | Source | Effort |
|------|--------|--------|
| Hermes-style periodic nudge | pkm1.md, pkm3.md | 1h |
| Dual decay activity scoring | pkm3.md | 1h |
| Meaning anchor deduplication | pkm3.md | 2h |
| Weekly digest anchor synthesis | pkm3.md | 3h |

---

## Part 7: Architecture Decision Records (ADRs)

### ADR 1: Swift `async let` over Process Spawning for Subagents
**Decision:** Use lightweight Swift concurrency instead of spawning separate processes for subagents.
**Rationale:** For PKM use cases (not distributed systems), process overhead is unnecessary. `async let` provides parallel execution with shared memory access.
**Trade-off:** Less isolation than true processes; use Git worktrees for file isolation.

### ADR 2: MCP Client in Rust (Not Swift)
**Decision:** Implement MCP client inside `agent_core`, not as Swift layer.
**Rationale:** Keeps tool registry unified; MCP tools go through same approval/security gates as built-in tools.
**Trade-off:** Swift UI can't easily customize MCP tool rendering without Rust changes.

### ADR 3: Accessibility Tree Primary, Vision Fallback
**Decision:** AXUIElement tree is Layer 1; screenshot/VLM is Layer 3 fallback.
**Rationale:** Token efficiency (200 vs 5000 tokens) and deterministic targeting.
**Trade-off:** Only ~33-36% of macOS apps have good accessibility metadata (pkm4.txt); fallback required.

### ADR 4: BoltFFI for High-Frequency Paths Only
**Decision:** Keep UniFFI for general use; migrate hot paths (embeddings, AX tree) to BoltFFI or zero-copy shared memory.
**Rationale:** UniFFI is ergonomic and safe; premature optimization of all FFI is unnecessary.
**Trade-off:** Two FFI patterns to maintain.

---

## Conclusion: The Synthesized Architecture

The 5 research papers converge on a unified vision for Epistemos:

```
┌─────────────────────────────────────────────────────────────────┐
│  SwiftUI Layer                                                  │
│  - @Observable state (fine-grained)                             │
│  - NSPopover suggestions (native, anchored)                     │
│  - Structural fingerprinting (no @Query thrashing)              │
│  - Metal rendering (120fps graph, syntax)                       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ UniFFI (general) / BoltFFI (hot paths)
┌──────────────────────────▼──────────────────────────────────────┐
│  Rust agent_core                                                │
│  - SubAgentCoordinator (async let parallel)                     │
│  - MCP Client (community tools)                                 │
│  - ComputerUseTool (AX tree + vision fallback)                  │
│  - ToolRegistry (19 built-in + dynamic MCP)                     │
│  - 4 cloud providers (Claude, OpenAI, Gemini, Perplexity)       │
│  - Context compaction (4-phase)                                 │
│  - Security scanning (secrets, injection)                       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ POSIX shared memory / Git worktrees
┌──────────────────────────▼──────────────────────────────────────┐
│  Persistence                                                    │
│  - SwiftData (ModelActor for background)                        │
│  - Graph (WeightedContextEngine: 6-factor scoring)              │
│  - Memory: MEMORY.md + USER.md (Hermes pattern)                 │
│  - Anchors: MeaningAnchorService (deduplicated)                 │
└─────────────────────────────────────────────────────────────────┘
```

**Final Score Prediction:**
After implementing the above, Epistemos vs Goose becomes:
- **Epistemos 11 — Goose 2 — Tie 2**
- Subagent parity (your async let vs their process spawn)
- MCP parity (both client and server)
- Superior computer use (AX tree depth they lack)
- Superior context management (already leading)
- Superior native integration (Metal, SwiftUI)

---

**References:**
- pkm1.md: Epistemos PKM App — Deep Synthesis & Architecture Audit
- pkm2.txt.md: Model comparison synthesis (GPT-5.4, Claude Opus 4.6, Gemini 3.1)
- pkm3.md: Epistemos Deep Synthesis — Agent Architecture, 4 Cloud Providers, Code Editor
- pkm4.txt: Comprehensive Audit of Native Agentic PKM Systems (Goose, OpenClaw, Hermes)
- pkm agent.txt: Architectural Synthesis of Native macOS Autonomous Agent Environments
