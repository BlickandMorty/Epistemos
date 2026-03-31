# Agent System Implementation Progress

Last updated: 2026-03-30 (late session) | Agent Integration Items 1-15 COMPLETE | Sprint Omega-6 in progress | Current research source of truth: docs/HERMES_INTEGRATION_RESEARCH.md

## Sprint Agent-1: The Living Loop ✅
- [x] agent_core crate with all 13 source files
- [x] Full SSE state machine with thinking/signature preservation
- [x] Parallel tool execution (futures::try_join_all)
- [x] Agent-decides termination (stop_reason == end_turn)
- [x] UniFFI bridge with AgentEventDelegate callback interface
- [x] All verification greps pass

## Sprint Agent-2: Local Agent System ✅
- [x] HermesPromptBuilder, LocalToolGrammar, LocalAgentLoop, ConfidenceRouter
- [x] canActAsAgent=false enforced for weak models
- [x] 20/20 focused tests pass

## Sprint Agent-3: MCP + Computer Use ✅
- [x] Rust-authoritative tool catalog (26 tools, 5 agents)
- [x] Vault-focused MCP surface (read/write/list/search)
- [x] AX-first computer-use path hardened
- [x] Device backend execution seam closed
- [x] Focused tests pass

## Sprint Agent-4: Multi-Provider + Polish (partial)
- [x] Routed provider preview + honest auto bridge resolution
- [x] Perplexity Sonar streaming provider with citations
- [ ] OpenAI provider via rig-core
- [ ] Full context compaction loop ← REPLACED by Sprint Omega-1 Task 3
- [ ] Metal thinking glow shader for OmegaPanel
- [ ] Full validation checklist passes

---

## Sprint Omega-1: Foundation Integration ✅ (2026-03-29)
- [x] Task 1: prompt_caching.rs — cache_control breakpoints (~85% cost reduction)
- [x] Task 2: think.rs — zero-cost reasoning tool
- [x] Task 3: compaction.rs — 4-phase context compaction (boundary protect → tool replace → summarize → fold)
- [x] Task 4: security.rs — credential redaction + command risk + output scanning
- [x] Task 5: MCP stdio transport in omega-mcp
- [x] Task 6: Full compilation + test sweep passes (164 Rust tests, 0 failures)

## Sprint Omega-2: Hermes Subprocess Bridge ✅ (2026-03-29)
- [x] HermesSubprocessManager.swift — spawn/manage/kill via Foundation Process
- [x] HermesMCPClient.swift — MCP stdio client to Hermes
- [x] EpistemosMCPServer.swift — MCP stdio server exposing macOS tools
- [x] Pipe-based watchdog heartbeat for zombie prevention
- [x] Process group management for clean shutdown
- [x] Integration with AppBootstrap lifecycle
- [x] Hermes health check on launch

## Sprint Omega-3: AXorcist Computer Use ✅ (2026-03-29)
- [x] Replace raw AXUIElement code with AXorcist SPM dependency
- [x] Ghost OS-style MCP tools (see, click, type, scroll, keys, screenshot)
- [x] ScreenCaptureKit pipeline with buffer dropping (<200ms target)
- [x] TCC permission management UI
- [x] AX-first with vision fallback pattern

## Sprint Omega-4: Skills + Memory + Polish (2026-03-29)
- [x] SKILL.md progressive disclosure (metadata → instructions → resources)
- [x] Post-task auto-skill creation
- [x] 3-layer progressive memory retrieval
- [x] Overnight Note Research — NightBrain-scheduled deep research on flagged notes with morning summary
- [x] Usage cost dashboard
- [x] Slash-command palette (/plan, /research, /review)
- [x] Metal thinking glow shader for OmegaPanel
- [x] Full validation checklist passes (3/3 recursive clean)
- [x] All Rust tests pass (371 tests, 0 failures)

## Sprint Omega-5: Living Vault Memory Engine (in progress)
- [x] Task 1: diff_engine.rs — unified text diff, JSON pointer diff, and 3-line fuzzy patch apply (2026-03-30)
- [x] Task 2: memory_classifier.rs — ADD/UPDATE/DELETE/NOOP vault write classifier with compact prompt + local/Haiku dispatch hint + contradiction planner (2026-03-30)
- [x] Task 3: memory_decay.rs — Ebbinghaus decay + garbage collection with pinned/access-aware batch decay (2026-03-30)
- [x] Task 4: cross_propagation.rs — Tantivy/file-scan reference detection with atomic secondary patch rollback (2026-03-30)
- [x] Task 5: vault_git.rs — git-backed atomic vault commits with history + diff_between support (2026-03-30)
- [x] Task 6: ConversationPersistence.swift — JSONL + markdown conversation persistence (2026-03-30)
- [x] Task 7: VaultChatMutator.swift — diff staging + approval flow (2026-03-30)
- [x] Task 8: VaultRegistry.swift / vault_registry.rs — multi-vault identity mapping (2026-03-30)
- [x] Task 9: Full compilation + integration verification (2026-03-30)

## Agent Integration Session (2026-03-30) ✅
Items 1-15 from `docs/AGENT_INTEGRATION_SESSION_PLAN.md` — all building clean.

### Do First Tier ✅
- [x] Item 6: ToolLoopDetector wired into Hermes bridge tool_completed events (2026-03-30)
- [x] Item 5: AgentDepthLimiter wired into Hermes bridge tool_started/completed for delegate tools (2026-03-30)
- [x] Item 15: CredentialRedactor — 9 patterns, wired into vault_search + vault_read (2026-03-30)
- [x] Item 14: CostTracker — micro-dollar precision, March 2026 pricing, wired into complete events (2026-03-30)
- [x] Item 8: ContextCompiler — U-curve reordering on vault_search results (2026-03-30)

### Do Second Tier ✅
- [x] Item 13: MemoryThreatScanner — role hijack + exfiltration + invisible unicode, wired into vault tools (2026-03-30)
- [x] Item 12: ShadowGitCheckpoint — GIT_DIR/WORK_TREE separation, 10s timeout, auto-checkpoint (2026-03-30)
- [x] Item 3: NightBrain menu bar agent mode — config + delegate + Settings toggle (2026-03-30)
- [x] Item 7: Living Vault Rust FFI exports — classify_vault_memory, decay_memory_nodes, gc_memory_nodes (2026-03-30)

### Do Third Tier ✅
- [x] Item 4: SkillStoreView — 7 categories, search, detail sheet, native + Hermes skills (2026-03-30)
- [x] Item 9: QLoRATrainer prefers composed train_final.jsonl over raw shards (2026-03-30)
- [x] Item 1: HTTP/SSE transport via NWListener for MCP payloads >50KB (2026-03-30)
- [x] Item 2: recovery.rs (7 tests) + HexViewerView with Rust FFI (2026-03-30)

### Gemini Deep Analysis Integration ✅
- [x] Evaluated 6 proposals from OpenClaw/Hermes comparative analysis (2026-03-30)
- [x] Accepted: Heartbeat Memory Distillation (Item 20), Sub-Agent Context Scoping (Item 21)
- [x] Rejected: A2UI (already SwiftUI), PyO3 (wrong direction), Zero-Trust WS (local app), Docker Proxy (deferred)
- [x] Updated AGENT_INTEGRATION_SESSION_PLAN.md, MASTER_SESSION_PROMPT.md, AGENT_PROGRESS.md

### Do Next Tier (Gemini analysis upgrades) ✅
- [x] Item 20: NightBrain Heartbeat Memory Distillation — memoryDistillation job in NightBrainService, calls AgentGraphMemory.distillMemory() with Ebbinghaus decay + GC (2026-03-30)
- [x] Item 21: Sub-Agent Hierarchical Context Scoping — context_scope parameter in delegate_tool.py, 3 role-specific context files (terminal, research, file) in hermes-agent/contexts/ (2026-03-30)

## Sprint Omega-6: Context Compiler + Graph Visualizer
- [x] Task 1: context_compiler.rs — prompt DAG with cache-optimal assembly (2026-03-30)
- [ ] Task 2: skill_router.rs — embedding-based skill selection
- [ ] Task 3: example_bank.rs — few-shot retrieval + quality ranking
- [ ] Task 4: GraphDataModel.swift — vault→graph conversion
- [ ] Task 5: AgentGraphView.swift — Grape force-directed graph
- [ ] Task 6: SemanticZoomController.swift — 5-level semantic zoom
- [ ] Task 7: NodeDetailPanel.swift + full verification
