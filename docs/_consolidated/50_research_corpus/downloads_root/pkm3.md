# Epistemos Deep Synthesis
## Agent Architecture, 4 Cloud Providers, Code Editor, Living Intelligence Layer — Complete Audit & Hardening Guide

***

## Executive Summary

This report synthesizes a full-session audit of **Epistemos**, a Swift/Rust FFI-native macOS PKM application. The session completed 20+ commits spanning six migration phases (Goose-inspired agent loop, four cloud providers, 19 built-in tools, approval flow, context compaction, Living Intelligence Layer), a comprehensive UI overhaul (Xcode-style editor, AI Partner, NSPopover suggestions, line-breakdown panels), and three major architectural fixes. What follows is an independent deep-read designed to harden all pain points, close the remaining gaps identified across the Goose, Hermes, and OpenClaw source trees, and ensure the computer-use implementation for all four providers is both correct and maximally capable.

***

## Part 1 — Agent Core Architecture Audit

### 1.1 Current Architecture

The agent core follows the pattern `Main Chat → ChatCoordinator → Rust agent_core → 4 Cloud Providers → 19 Built-in Tools → Approval Flow → Context Compaction → Prompt Caching → Security Scanning`. This is a robust foundation. The Rust `agent_core` runs the agentic loop and surfaces results via UniFFI Swift bindings, giving the hot path memory-safety guarantees without GC pauses. UniFFI's automatic type conversion (Rust `enum` → Swift `enum`, snake_case → camelCase) keeps the Swift-side code idiomatic.[^1][^2]

### 1.2 Gaps vs Goose Reference Implementation

Goose leads Epistemos in three areas:[^3][^4]

| Gap | Goose Approach | Epistemos Status | Priority |
|-----|---------------|------------------|----------|
| **Subagents** | Spawns child goose processes for parallel sub-tasks | Not implemented | HIGH |
| **MCP ecosystem** | Full MCP server/client with MCPO proxy for OpenAPI compat | MCP absent | HIGH |
| **Provider quantity** | >10 provider targets | 4 providers | LOW |

The absence of a **Model Context Protocol** (MCP) layer is the most consequential gap. MCP has become the dominant standard for agent-tool interoperability in 2025, with Anthropic and Google both designing around it. Without it, Epistemos cannot consume the growing ecosystem of third-party MCP servers (file systems, browsers, databases, Slack, Calendar, etc.) that Goose and Claude Cowork leverage natively.[^5][^6]

**Recommendation:** Implement a minimal MCP client in Rust that speaks the standard JSON-RPC protocol over stdio/SSE. The Rust `mcp-client` crate provides a clean foundation. Expose discovered MCP tools through the same approval-flow gate as built-in tools. Do not add it to the Swift layer — keep it inside `agent_core`.

### 1.3 Hermes Memory System — What to Extract

Hermes v0.7.0 uses a four-layer memory architecture:[^7][^8]

1. **Prompt memory (hot)** — Always in context, ~1,300 tokens total (`MEMORY.md` + `USER.md`)
2. **Session archive (warm)** — Searchable via `session_search` tool call, not always in context
3. **Skills (procedural)** — Reusable task templates triggered after task completion
4. **External provider (pluggable)** — Structured extraction with entity resolution

The session audit shows Epistemos already has the Phase 3a/3b `memory` and `skills` tools from Hermes. The **critical Hermes pattern not yet ported** is the **periodic nudge**: at set intervals, Hermes sends an internal system-level prompt asking the agent to evaluate what from recent activity is worth persisting, without user input. This is distinct from saving chats — it is active self-assessment. The nudge fires every N turns (configurable) and is what keeps `MEMORY.md` up-to-date across long sessions.[^8]

**Recommendation:** Add a `nudgeInterval` counter to `ChatCoordinator`. Every 15 assistant turns, inject a brief system message: *"Pause and reflect: is there anything from this session worth adding to your persistent memory file? Write it now if so."* This mirrors Hermes's mechanism precisely.

The Hermes **reflect** operation — periodically synthesizing across all stored memories to derive higher-order insights — is also absent. The existing `MeaningAnchorService` partially covers this but fires only on chat exit, not periodically. Consider a background task that calls Qwen to synthesize all anchors created in the last 7 days into a "weekly digest" anchor node.[^7]

### 1.4 OpenClaw Gaps

OpenClaw's core contribution (as a Claude-centric agent framework) is a clean separation of **reasoning traces** from **tool calls** in the conversation history. It keeps thinking blocks visible in the UI with an expandable "reasoning" disclosure, rather than hiding them. Epistemos should expose extended thinking tokens from Claude Sonnet 3.7 in the chat UI (collapsible, dimmed) when `thinking_budget` is set — this is not currently done.

***

## Part 2 — Computer Use Implementation Audit

### 2.1 Claude Computer Use (Anthropic)

Claude's computer use became available for macOS Pro/Max subscribers in March 2026. The API is accessed via the `computer-use-2025-11-24` beta header, with tool type `computer_20251124`. The current tool schema accepts `display_width_px`, `display_height_px`, and `display_number`. Crucially, Anthropic designed the feature to **reach for connectors first** (Slack, Gmail, Calendar), falling back to screen control only when no connector exists. This hierarchy must be respected in Epistemos's implementation.[^9][^10][^11]

The agent loop must follow the canonical sampling loop pattern:[^9]
1. Send user message + tools (computer, text_editor, bash) to Claude
2. Receive response with `stop_reason: "tool_use"`
3. Execute the tool action on the actual macOS environment
4. Send `tool_result` back in next user turn
5. Repeat until no tool use appears in response

**Epistemos-specific upgrade:** Rather than just capturing a screenshot for each Claude turn (as the reference implementation does), Epistemos can supply the macOS Accessibility API tree alongside the screenshot. The GUIrilla framework demonstrates that macOS apps expose structured accessibility trees via `AXUIElement` that can be serialized to clean hierarchical JSON. Injecting this tree as a text block before the screenshot gives Claude semantic understanding of what's on screen (button labels, text fields, checkboxes) rather than requiring pure visual inference. This is the "deeper than screen capture" capability the user requested.[^12]

**Implementation path:**
```swift
// In ComputerUseTool.swift
func captureEnvironmentState() async -> ComputerEnvironmentState {
    let screenshot = captureScreen()
    let axTree = AccessibilityTreeCapture.serialize(pid: frontmostPID)
    return ComputerEnvironmentState(screenshot: screenshot, accessibilityTree: axTree)
}
```

The `accessibility-tree-20251124` beta flag (if available when Anthropic expands the beta) would allow Claude to receive the tree natively. Until then, stringify and prepend to the user content block.

### 2.2 Gemini Computer Use (Google)

Google released the **Gemini 2.5 Computer Use model** via the API in October 2025. Its `computer_use` tool uses a cyclical interaction loop with inputs: user request + screenshot + recent action history. The model returns function calls specifying UI actions (click, type, scroll, etc.). The critical distinction from Claude: **Gemini's computer use works through a Playwright/browser agent loop primarily designed for web**, with mobile extension. For a macOS native app context, the screenshot+action loop must be adapted to use `CGEvent` (synthetic mouse/keyboard) rather than Playwright.[^13][^14]

**Gap in current Epistemos Gemini provider:** If computer use was wired in Phase 4 (`b85872a8`), verify that the Gemini provider correctly uses model ID `gemini-2.5-computer-use-preview-10-2025` and that the tool config `generate_content_config` excludes browser-only actions and includes custom macOS actions. The `computer_use` tool config supports excluding/adding custom function definitions — use this to restrict to `screenshot`, `click`, `type`, `scroll`, `keypress` and exclude `navigate_browser`.[^14]

### 2.3 OpenAI Computer Use

OpenAI's macOS app reads/edits content in coding apps using the **macOS Accessibility API** (`AXUIElement`). For the API-based integration in Epistemos, the `computer_use` feature maps to the OpenAI Responses API with tool `type: "computer_use_preview"`. Unlike Claude, OpenAI's implementation does not define named sub-tools (text_editor, bash) separately — it is a unified tool. The approval flow in Epistemos must handle the `requires_action` event type with action type `computer_use` and surface it to the user before executing.[^15]

**Integration check:** Confirm that OpenAI provider's tool dispatch handles `type == "computer_use_preview"` and that screen capture is passed as a `computer_call_output` with `output.type == "computer_screenshot"`.

### 2.4 Gemini (non-computer-use) + Future xAI

The Gemini 2.0 Flash provider (Phase 2 commit `d6ff9fea`) should be verified to use the `gemini-2.0-flash-exp` model for fast tool-calling. For xAI Grok as a potential 5th provider, the API is OpenAI-compatible (same endpoint shape), so the existing OpenAI provider can be duplicated with a base URL swap and model list update.

### 2.5 Provider Computer Use Feature Matrix

| Provider | Screenshot Input | AX Tree Input | Tool Schema | macOS Native Actions |
|----------|-----------------|---------------|-------------|----------------------|
| Claude | ✅ Required | ✅ Supported (text block) | `computer_20251124` | CGEvent synthesis |
| Gemini | ✅ Required | ⚠️ Manual stringify | `computer_use` tool | CGEvent synthesis |
| OpenAI | ✅ Required | ✅ Via macOS Accessibility | `computer_use_preview` | AXUIElement direct |
| (xAI) | N/A yet | N/A yet | OpenAI-compatible | — |

***

## Part 3 — Code Editor Audit

### 3.1 Critical Bug Recap

The session audit identified and fixed 9 critical-severity issues. The most structurally important:[^16][^17]

- **`ObservableObject` vs `@Observable`:** `AIPartnerService` and `CodeAskBarService` were using `ObservableObject + @Published`, which causes full-view re-renders across the entire view hierarchy. The `@Observable` macro enables fine-grained property tracking — only the views observing the specific changed property re-render. This fix is essential for performance with `AIPartnerService`, which receives updates on every keystroke.[^17][^16]

- **Edge field name typos in `WeightedContextEngine`:** `edge.sourceId` / `edge.targetId` should be `edge.sourceNodeId` / `edge.targetNodeId`. Additionally, iterating `[String: GraphEdgeRecord]` with `.count { edge in ... }` passes `(key, value)` tuples, not bare `GraphEdgeRecord` values. The fix `.values.filter { ... }.count` is correct.

### 3.2 Weighted Context Engine — Deep Analysis

The scoring formula \(\text{finalScore} = s_{sem} \cdot 0.35 + s_{node} \cdot 0.25 + s_{comp} \cdot 0.20 + s_{conn} \cdot 0.15 + s_{rec} \cdot 0.05\) is well-calibrated. The addition of the `activityScore` (Phase 3) bringing engagement weighting into the mix is architecturally sound. Research on weighted knowledge graph embeddings confirms that weighting triples by importance produces superior link prediction and retrieval compared to unweighted embeddings.[^18]

**Outstanding issue:** The `WeightedContextEngine` creates embeddings via an `EmbeddingService` instance. The Phase 3 architectural fix consolidates to a shared instance via `GraphState.embeddingService`. Verify that the `WeightedContextEngine` init now accepts the shared instance rather than creating its own, and that the 4096-entry LRU cache is the single source of truth.

**Improvement opportunity (not yet implemented):** Cache the complexity analysis result per `(fileHash, contentLength)` tuple with a 30-second TTL. The complexity analysis parses the entire file every analysis cycle. For files over 500 lines, this becomes expensive. A short-lived cache keyed on file identity + size avoids re-analysis during rapid edits while remaining accurate enough for the scoring formula.

### 3.3 Outline Parser — Robustness

The pre-compiled static regex approach (performance fix #2) is correct. However, the Swift symbol detection using `line.contains(" class ")` is a false-positive risk — it matches comments, string literals, and `if let classValue = ...` patterns. A tighter approach:

```swift
// Prefer regex anchored to start-of-declaration patterns
static let swiftClassRegex = try! NSRegularExpression(
    pattern: #"^\s*(public|private|internal|open|fileprivate)?\s*(final\s+)?class\s+(\w+)"#
)
```

Similarly, the recursion detector that checks `code.contains("\(funcName)(")` will flag any call anywhere in the file with that name, including calls from unrelated functions. The corrected version (tracking `currentFunctionName` and only counting calls within the detected function body) should also handle Swift's trailing closure syntax where the function call appears without parentheses.

### 3.4 Performance Bottlenecks — Remaining

After the session's 10 performance fixes, three items remain from the audit:

1. **`@Query` reactivity root cause:** SwiftData `@Query` re-evaluates on any model context change — even when the specific fields the sidebar displays (title, favorite, folder) haven't changed. The `sidebarStructuralFingerprint` early-exit guard helps, but the query still fires. The permanent fix is migrating the sidebar fetch to a `ModelActor`-backed view model that only propagates changes when the fingerprint changes, completely decoupling from the main-thread `@Query`. This is safe to implement incrementally.[^19][^20]

2. **Multiple `EmbeddingService` instances (residual):** The `CodeCompanionService` at line 3426 still creates its own `EmbeddingService()` because it has no `graphState` reference. Wire it with a `weak var embeddingService: EmbeddingService?` init parameter, set by the call site that does have access to `graphState`.

3. **Metal `outputBuffer` Sendable violation:** The `@preconcurrency` import suppresses the warning but doesn't resolve the underlying threading contract. The `any MTLBuffer` type is `NSObject`-backed and not `Sendable`. Wrap the buffer access in a `nonisolated(unsafe) let` if the usage pattern guarantees single-threaded access, or migrate to an actor-isolated wrapper that serializes buffer reads/writes.

***

## Part 4 — Living Intelligence Layer Audit

### 4.1 Architecture Overview

Six phases shipped:

| Phase | Feature | Key Files |
|-------|---------|-----------|
| BG Fix | Background summary staleness | `WorkspaceSummaryService`, `ActivityTracker` |
| 1 | Chat unification (all surfaces → `SDChat`) | `DialogueChatState`, `CodeAskBarService`, `AIPartnerService` |
| 2 | Meaning anchors (structured snapshots → graph nodes) | `MeaningAnchorService` |
| 3 | Activity profile (engagement scoring → search weighting) | `ActivityTracker`, `WeightedContextEngine` |
| 4-6 | Anchor injection, proactive AI hints, retroactive backfill | `ChatCoordinator` |

### 4.2 Meaning Anchor Quality

`MeaningAnchorService` generates anchors using a local Qwen model via `TriageService`. The quality of anchors depends entirely on the prompt design. The current prompt structure (transcript → structured JSON with `topic`, `insights`, `connections`, `broaderTheme`) is the right shape. Two improvements:

- **Deduplication:** Before creating a new anchor node, embed the new anchor's topic and check cosine similarity against existing anchors. If similarity > 0.85, merge the insights rather than creating a duplicate node. This prevents the graph from becoming cluttered with semantically identical anchors from repeated conversations on the same topic.

- **Edge typing:** When the anchor service creates edges between the anchor node and referenced note nodes, the edge `type` should distinguish `inspired_by` (anchor references note content) from `about` (anchor summarizes a conversation about the note). This makes graph traversal more semantically meaningful.

### 4.3 Activity Profile Weighting

The activity score formula feeds into the weighted context engine. Research on intent-based memory grouping suggests that goal-oriented clustering outperforms recency-only decay. The current formula uses a 30-day half-life for recency. Consider a dual decay: **fast decay** (7-day half-life) for the "currently working on" signal, and **slow decay** (90-day half-life) for the "important to this user's long-term work" signal. Weight the fast signal at 0.7 and slow at 0.3 in the activityScore calculation.[^21]

### 4.4 Background Summary Fix — Remaining Gaps

The idle detection was broadened from `keyDown`-only to all input event types. The semantic diff was corrected to extract changed paragraphs rather than `prefix(totalParagraphs)`. However, one gap remains: the `WorkspaceSummaryService` still generates summaries on a timer tick. If the user is in a long focused session with no idle pauses, the summary will be stale until the next timer fires. Add a **change-count trigger**: after N semantic edits (N=20 is a reasonable default) since the last summary, trigger a regeneration even without an idle window.

### 4.5 Chat Unification — Surface Coverage

Five `chatType` values now exist: `chat`, `notes`, `dialogue`, `codeAsk`, `aiPartner`. One surface remains ephemeral: **graph node quick-look popovers** (when a node's inline chat is accessed from the graph). If these use a distinct chat surface, they should be persisted as `chatType: "graphQuickLook"` with the `sourceNodeId` attached as metadata.

***

## Part 5 — UI/UX Deep Audit

### 5.1 NSPopover Migration

The migration from `ZStack` overlays to `NSPopover` for AI suggestions is architecturally correct. Native `NSPopover` handles:
- Correct positioning relative to the anchor view
- Automatic dismissal on click-outside (respecting the `behavior` property)
- Correct layering above all app chrome
- Proper arrow rendering pointing to the source element

**Gap:** The popover anchor should be the specific line annotation glyph, not the editor frame. When a suggestion refers to line N, the popover should arrow-point to the line number gutter position for line N. This requires computing the line's `NSTextView` rect and converting to screen coordinates before calling `show(relativeTo:of:preferredEdge:)`.

### 5.2 Line Breakdown Panel

The `LineBreakdownPanel` design — per-line analysis at the top of the editor with navigation to each line — is the correct pattern for code review workflows. Key interaction requirements not yet explicitly verified:

- **Line jump:** Tapping a line entry should scroll the `NSTextView` to reveal that line and flash the line number gutter (brief highlight animation)
- **Replace button:** Must present a diff view (before/after side-by-side or inline highlights using `InlineResponseHighlighter`) before applying
- **Explain further:** Should open a new focused chat pre-seeded with the line content and the suggestion text
- **Dismiss individual line:** Each line entry should have an `×` button that removes it from the panel without dismissing the whole analysis

### 5.3 Sidebar Language Icons

The sidebar uses SF Symbols and custom asset fallbacks for language icons. The implementation should handle:
- `.swift` → Swift logo (the official bird glyph is part of Apple's `swift` SFSymbol in macOS 13+)
- `.rs` → Rust logo (no SF Symbol; render the "R-crab" as a local asset `rust_logo`)
- `.py` → `python.plain` devicon (local asset)
- `.js` / `.ts` → `js` and `ts` devicons
- Unknown extensions → `doc.text` SF Symbol

For the AI provider logos (Claude, GPT, Gemini), these are trademarked assets. Use locally bundled SVG assets for each:
- Claude → Anthropic's official logomark (triangle/circle form)
- GPT → OpenAI's pinwheel logomark
- Gemini → Google's Gemini star form (diamond)

None of these are available as SF Symbols. Bundle them as template images (monochrome) so they respect the app's accent color in dark mode.

### 5.4 Graph Inspector Performance

The fix for the pinned inspector render loop (stop `needsRender = true` every frame when physics has settled) is correct. However, the condition for "position changed" must use an epsilon comparison, not exact float equality:

```swift
let positionChanged = abs(lastPosition.x - node.position.x) > 0.5 ||
                      abs(lastPosition.y - node.position.y) > 0.5
```

Exact float equality will fail due to floating-point drift from physics micro-updates, causing the render loop to never settle.

***

## Part 6 — Rust FFI Layer Audit

### 6.1 Memory Safety at the FFI Boundary

UniFFI generates safe Swift bindings, but the `unsafe` boundary exists within the Rust crate itself where `extern "C"` functions are declared. Key invariants to verify:[^22]

- **String passing:** Ensure all strings crossing the FFI are passed as `RustBuffer` (UniFFI's managed type), never as raw `*const c_char`. Raw C strings require the caller to manage the lifetime of the pointed-to memory, which is error-prone.[^1]
- **Error propagation:** UniFFI supports `Result<T, E>` return types that become Swift `throws`. All agent-loop functions that can fail (provider calls, tool executions, approval timeouts) should return `Result<T, EpistemosError>` rather than panicking or returning sentinel values.
- **Async/await:** UniFFI 0.27+ supports `async` Rust functions via Swift `async`/`await`. If the agent loop uses Rust `async fn`, verify that the UniFFI scaffolding correctly bridges to Swift structured concurrency and that the cancellation token is propagated (Swift `Task.cancel()` → Rust `CancellationToken`).

### 6.2 Shared Memory Performance

The `agent_core` shared memory path (used for large context transfers between Rust and Swift without copying) is a key performance advantage over pure-FFI passing. For Metal compute outputs (embedding vectors), verify that the shared `MTLBuffer` is allocated in `MTLResourceStorageModeShared` mode so both CPU and GPU can access it without an explicit blit encoder copy. This pattern achieves near-zero-copy on Apple Silicon's unified memory architecture.[^23]

```swift
let buffer = device.makeBuffer(
    length: vectorDimension * MemoryLayout<Float>.size,
    options: .storageModeShared // NOT .storageModePrivate
)
```

Metal-accelerated vector search on Apple Silicon achieves ~0.84ms search time for 10,000 vectors in unified memory mode, compared to 105ms on CPU. This throughput is sufficient for real-time context retrieval during typing.[^23]

***

## Part 7 — Remaining High-Priority Implementation Gaps

### 7.1 Subagent Architecture

Goose spawns child agent processes for parallel sub-task execution. Epistemos has no equivalent. For the PKM use case, the most valuable subagent pattern is **parallel note synthesis**: given a query, spawn N subagents each focused on a subset of the knowledge graph, then a root agent synthesizes their outputs. This is implementable without a full multi-process architecture: use Swift `async let` to fire N concurrent `agent_core` calls with scoped context windows, then reduce.[^3]

### 7.2 MCP Client

The lack of MCP integration means Epistemos cannot use the growing ecosystem of MCP servers (browser automation, code execution, file system, calendar, Slack, etc.). A minimal Rust MCP client implementation requires:[^6][^5]
1. An MCP server process registry (per-project `.epistemos/mcp.json`)
2. A stdio transport for `server.start()` → `tools/list` → `tools/call` lifecycle
3. A dynamic tool registration path into the agent loop's tool dispatcher

### 7.3 Extended Thinking / Reasoning Traces

Claude Sonnet 3.7 supports a `thinking` parameter with configurable token budget. The current agent loop passes `thinking` only when `thinking_budget` is set. Two improvements:[^9]
- Expose a per-chat "reasoning depth" slider in the UI (maps to `budget_tokens`: 1k/4k/16k)
- Render thinking blocks in the chat as collapsible `<details>` sections with a distinct background color (light blue tint in dark mode)

### 7.4 Prompt Caching Verification

Phase 1 commit (`00f37ed2`) mentions prompt caching in the architecture. Claude's prompt caching requires the cached prefix to be marked with `cache_control: {"type": "ephemeral"}` on the content block. Verify that:[^9]
- The system prompt (workspace awareness + tools list) is the cached block, not the user message
- The cache is invalidated when the tool list changes (e.g., new MCP server registered)
- Gemini's equivalent (context caching API) is implemented for long system prompts

***

## Part 8 — Synthesis: Priority Action Matrix

| Priority | Category | Action | Effort |
|----------|----------|--------|--------|
| P0 | Stability | Resolve Metal Sendable violation properly (not just `@preconcurrency`) | 1h |
| P0 | Stability | Fix AX tree epsilon comparison in graph inspector settle check | 30m |
| P0 | Performance | Cache complexity analysis per `(fileHash, contentLength)` with 30s TTL | 2h |
| P1 | Feature | Add Hermes-style periodic memory nudge (every 15 turns) | 1h |
| P1 | Feature | AX tree injection into computer use screenshots for all 4 providers | 4h |
| P1 | Computer Use | Verify Gemini `computer_use` excludes browser actions, adds macOS CGEvent actions | 2h |
| P1 | Computer Use | Verify Claude popover anchor points to specific line glyph | 1h |
| P1 | Architecture | MCP client in Rust (`agent_core`) with stdio transport | 8h |
| P2 | Intelligence | Meaning anchor deduplication (cosine similarity > 0.85 → merge) | 2h |
| P2 | Intelligence | Dual-decay activity scoring (7-day fast + 90-day slow) | 1h |
| P2 | Intelligence | Weekly digest anchor from `MeaningAnchorService.reflect()` | 3h |
| P2 | Performance | Migrate sidebar fetch to `ModelActor`-backed view model | 4h |
| P2 | UI | Line breakdown panel: per-line dismiss, diff preview before replace | 3h |
| P3 | Feature | Subagent parallel synthesis via `async let` concurrent `agent_core` calls | 6h |
| P3 | Feature | Extended thinking UI (reasoning depth slider + collapsed trace display) | 3h |
| P3 | Intelligence | `graphQuickLook` chatType persistence for graph popover chats | 1h |

***

## Conclusion

Epistemos has achieved a structurally sound agent architecture — the Rust/Swift FFI core, 4 cloud providers, 19 tools, approval flow, and the Living Intelligence Layer represent a coherent system. The critical remaining gaps are: MCP client integration (the biggest capability unlock), proper computer-use AX tree injection for true semantic screen understanding (beyond screenshots), and the Hermes periodic nudge pattern for continuous memory self-improvement. The P0 stability items (Metal Sendable, graph inspector epsilon check, complexity analysis caching) should be addressed first since they affect runtime correctness, followed by the computer-use hardening and MCP work.

---

## References

1. [Multiplatform with Rust on iOS - by Tjeerd in 't Veen](https://mobilesystemdesign.substack.com/p/multiplatform-with-rust-on-ios-2c4) - UniFFI can also generate FFI code for Kotlin and even Python. The idea is to write your logic in Rus...

2. [Building an iOS App with Rust Using UniFFI - DEV Community](https://dev.to/almaju/building-an-ios-app-with-rust-using-uniffi-200a) - In this blog post, we'll guide you through the process of building a simple iOS app using Rust and U...

3. [Does Your AI Agent Need a Plan? | goose](https://block.github.io/goose/blog/2025/12/19/does-your-ai-agent-need-a-plan/) - Planning with an AI produces good results. Knowing when and how to plan with an AI agent produces ev...

4. [The Ultimate Guide to Open-Source AI Agent Frameworks in 2025](https://watercrawl.dev/blog/The-Ultimate-Guide-to-Open-Source) - AI agents in 2025 are smarter than ever, with open-source frameworks powering automation, research, ...

5. [A Survey of AI Agent Protocols](https://arxiv.org/abs/2504.16736) - The rapid development of large language models (LLMs) has led to the widespread deployment of LLM ag...

6. [A Survey of LLM-Driven AI Agent Communication: Protocols, Security Risks, and Defense Countermeasures](https://arxiv.org/abs/2506.19676) - In recent years, Large-Language-Model-driven AI agents have exhibited unprecedented intelligence and...

7. [How Hermes Agent Memory Actually Works (And How to Make It ...](https://vectorize.io/articles/hermes-agent-memory-explained) - Hermes Agent's memory is more layered than it looks. This guide explains the built-in system, the ne...

8. [Inside Hermes Agent: How a Self-Improving AI Agent Actually Works](https://mranand.substack.com/p/inside-hermes-agent-how-a-self-improving) - This article breaks down the learning loop, the four-layer memory system, the gateway, agent loop in...

9. [Computer use tool - Claude API Docs](https://platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool) - The computer use tool is implemented as a schema-less tool. When using this tool, you don't need to ...

10. [Anthropic's Claude Can Now Control a Mac and Complete Tasks](https://www.thurrott.com/a-i/334111/anthropics-claude-can-now-control-and-complete-tasks-on-a-mac) - Last month, Perplexity launched a similar Perplexity Computer tool that works as an agent with tools...

11. [Claude Can Now Control Your Mac & Here's How It Actually Works](https://www.timesofai.com/news/claude-can-now-control-your-mac-heres-how-it-actually-works/) - Anthropic is now doing natively what third-party tools built around its models were doing first. Whe...

12. [GUIrilla: A Scalable Framework for Automated Desktop UI Exploration](https://arxiv.org/html/2510.16051v2) - Upon installation, the crawler attempts to extract an application's accessibility tree according to ...

13. [Introducing the Gemini 2.5 Computer Use model - Google Blog](https://blog.google/innovation-and-ai/models-and-research/google-deepmind/gemini-computer-use-model/) - Today we are releasing the Gemini 2.5 Computer Use model via the API, which outperforms leading alte...

14. [2025 Complete Guide: Gemini 2.5 Computer Use Model](https://dev.to/czmilo/2025-complete-guide-gemini-25-computer-use-model-revolutionary-breakthrough-in-ai-agent-133) - 1. Send Request to Model. Add Computer Use tool to API request; Provide user goal and current GUI sc...

15. [Work with Apps on macOS | OpenAI Help Center](https://help.openai.com/en/articles/10119604-work-with-apps-on-macos) - Work with Apps on macOS. ChatGPT for macOS can now work with your apps, starting with coding tools l...

16. [@Observable Macro performance increase over ObservableObject](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/) - The @Observable Macro simplifies code at the implementation level and increases the performance of S...

17. [SwiftUI Performance Boost: Upgrade with @Observable - LinkedIn](https://www.linkedin.com/posts/tharinduketipe_swiftlang-swift6-swiftui-activity-7393723909713534976-ubw-) - @Observable improves performance when the parent view doesn't use the changing properties only the s...

18. [[PDF] Weight-aware Tasks for Evaluating Knowledge Graph Embeddings](https://www.semantic-web-journal.net/system/files/swj3522.pdf) - nDCG is commonly used to assess the performance of ranking models, taking the relevance of the ranke...

19. [Need help optimizing SwiftData performance with large datasets](https://www.reddit.com/r/SwiftUI/comments/1jy8zkq/need_help_optimizing_swiftdata_performance_with/) - Hi everyone,. I'm working on an app that uses SwiftData, and I'm running into performance issues as ...

20. [High Performance SwiftData Apps - by Jacob Bartlett](https://blog.jacobstechtavern.com/p/high-performance-swiftdata) - So I had my 2 objectives: Optimise my SwiftData usage to make my app performant… …without losing all...

21. [Intent vectors for AI search + knowledge graphs for AI analytics](https://www.reddit.com/r/KnowledgeGraph/comments/1pnaev8/intent_vectors_for_ai_search_knowledge_graphs_for/) - Embedding weights - When combining 4 memories into one group embedding, how should we weight them? E...

22. [How can I combine a static Rust library, low-level C FFI layer, and ...](https://stackoverflow.com/questions/75913273/how-can-i-combine-a-static-rust-library-low-level-c-ffi-layer-and-higher-level) - I'm using UniFFI to generate Swift bindings for a Rust library. Following the documentation, I have:...

23. [I built Metal-accelerated RAG for iOS – 0.84ms vector search, no ...](https://www.reddit.com/r/iOSProgramming/comments/1r7owg9/i_built_metalaccelerated_rag_for_ios_084ms_vector/) - Query "find that receipt from the restaurant" → searches text, visual similarity, and location simul...

