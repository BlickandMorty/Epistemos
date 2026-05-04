# Agent System Implementation Progress

Last updated: 2026-03-29 | Current research source of truth: docs/HERMES_INTEGRATION_RESEARCH.md

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

## Sprint Omega-1: Foundation Integration
- [ ] Task 1: prompt_caching.rs — cache_control breakpoints (~85% cost reduction)
- [ ] Task 2: think.rs — zero-cost reasoning tool
- [ ] Task 3: compaction.rs — 4-phase context compaction (boundary protect → tool replace → summarize → fold)
- [ ] Task 4: security.rs — credential redaction + command risk + output scanning
- [ ] Task 5: MCP stdio transport in omega-mcp
- [ ] Task 6: Full compilation + test sweep passes

## Sprint Omega-2: Hermes Subprocess Bridge
- [ ] HermesSubprocessManager.swift — spawn/manage/kill via swift-subprocess
- [ ] HermesMCPClient.swift — MCP stdio client to Hermes
- [ ] EpistemosMCPServer.swift — MCP stdio server exposing macOS tools
- [ ] Pipe-based watchdog heartbeat for zombie prevention
- [ ] Process group management for clean shutdown
- [ ] Integration with AppBootstrap lifecycle
- [ ] Hermes health check on launch

## Sprint Omega-3: AXorcist Computer Use
- [ ] Replace raw AXUIElement code with AXorcist SPM dependency
- [ ] Ghost OS-style MCP tools (see, click, type, scroll, keys, screenshot)
- [ ] ScreenCaptureKit pipeline with buffer dropping (<200ms target)
- [ ] TCC permission management UI
- [ ] AX-first with vision fallback pattern

## Sprint Omega-4: Skills + Memory + Polish
- [ ] SKILL.md progressive disclosure (metadata → instructions → resources)
- [ ] Post-task auto-skill creation
- [ ] 3-layer progressive memory retrieval
- [ ] Usage cost dashboard
- [ ] Slash-command palette (/plan, /research, /review)
- [ ] Metal thinking glow shader for OmegaPanel
- [ ] Full validation checklist passes
- [ ] All 2,679+ tests pass
