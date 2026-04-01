# Epistemos Vision Backlog — Comprehensive Future Work

**Last Updated:** 2026-04-01
**Source:** Brain dump + all research docs + codebase audit

This is the COMPLETE list of remaining work. Items are organized by theme and priority tier.

---

## TIER 0: SHIP-BLOCKING (Cannot release without these)

### 0A. Notarization + Sparkle Auto-Update
- DMG packaging exists (GitHub Actions) but NO xcrun notarytool step
- No Sparkle SUFeedURL or SUPublicEDSAKey configured
- Cannot distribute without notarization on macOS
- **Action:** Add notarize step to release.yml, configure Sparkle 2, add SUFeedURL to Info.plist

### 0B. ResearchPause Continuation Fix
- Has timeout (120s) but potential double-resume crash
- Needs atomic completion guard (same pattern as ConfirmationGate fix)
- **File:** `Epistemos/Omega/Orchestrator/ResearchPause.swift`

### 0C. EmbeddingService Main Thread Hang
- 3738ms hang during "pushed 1017 embeddings" — MainActor.run block after FFI call
- Profile with Instruments, move remaining MainActor work to background
- **File:** `Epistemos/Graph/EmbeddingService.swift`

---

## TIER 1: HERMES AGENT PARITY (Close the gap with upstream v0.6.0)

### 1A. Merge Hermes v0.6.0 Updates
Hermes shipped 95 PRs. Key features missing from Epistemos:
- **Profiles:** Multiple isolated Hermes instances (separate config, memory, sessions, skills)
- **MCP Server Mode:** Hermes exposes conversations to MCP clients
- **Fallback Provider Chains:** Automatic failover between inference providers
- **Docker Container:** Containerized Hermes for isolated execution
- **Telegram/Slack/WeCom Adapters:** Communication channel integrations
- **Exa Search Backend:** Alternative to Tavily
- **Action:** `git submodule update` hermes-agent, audit new features, wire into Swift bridge

### 1B. Multi-Instance Agent Profiles
- Spawn N isolated Hermes instances (research, content, BD, coding)
- Each has own config, memory, sessions, skills, rate limits
- UI: Agent tabs in sidebar (like Notes window tabs), start/stop per profile
- Wire to `HermesSubprocessManager` — needs multi-process support
- **Profile JSON schema:** name, model, skills, tools, memory_dir, personality

### 1C. Fallback Provider Chains
- Configure primary → secondary → tertiary inference providers
- Auto-failover with cooldown (e.g., Anthropic → OpenRouter → OpenAI)
- Wire into `HermesRuntimeRoute` resolution
- **File:** `Epistemos/Agent/HermesSubprocessManager.swift`

### 1D. Fix "Dumb Chatbot" UX Gap
The app doesn't FEEL like Hermes Agent or OpenClaw because:
- Tool results don't stream visually (user sees "thinking..." not the tool executing)
- No live agent panel showing tool calls, results, thinking in real-time
- No sub-agent delegation visible in UI
- Agent window should look like Xcode's debug console — live, informative, scrolling
- **Action:** Restyle AgentSessionPanel to show: tool call → result → thinking → next action in real-time

### 1E. Skills System Swift Integration
- Hermes has skills but Swift has no scanner for `~/.epistemos/skills/`
- Need: hot-reload watcher, skill discovery UI in sidebar, skill trigger matching
- Bundle default skills (summarize-paper, daily-review, code-review, web-research)
- **Per IMPLEMENTATION_PROMPTS §4**

### 1F. iMessage Integration
- Read: ~/Library/Messages/chat.db (SQLite, requires Full Disk Access)
- Send: AppleScript → Messages.app
- Alt: BlueBubbles REST API (localhost)
- Agent tools: imessage_read, imessage_send
- **Per IMPLEMENTATION_PROMPTS §5**

---

## TIER 2: CODING FEATURES (Xcode-inspired)

### 2A. Code Streaming to Notes
- When user chats or agent generates code, stream it to a note in real-time
- Toggle per chat/agent: "Stream responses to notes"
- Can target: new note, existing note, agent vault, code section
- Code section in notes sidebar with syntax highlighting

### 2B. Code Section in Notes Sidebar
- Notes sidebar becomes a "Knowledge Hub" with sections:
  - My Notes
  - Recent Chats
  - Agent Vaults (per-model knowledge profiles)
  - Code (syntax-highlighted, searchable, auto-organized by language)
- Code auto-extracted from chat/agent responses
- Tap code section → transforms current window to code view

### 2C. Ask Bar in Code Section
- Same capabilities as main chat Ask Bar
- Recent chats, context from code files, Xcode-style command palette
- Can ask questions about code, get inline explanations
- **Inspiration:** Xcode's Quick Help + Copilot Chat

### 2D. Study OpenClaw's Coding Patterns
- OpenClaw uses a VLM-driven coding loop with screen awareness
- Port patterns: file tree navigation, diff generation, test execution
- Adapt for local files, not just web-based repos

---

## TIER 3: GRAPH ENHANCEMENTS

### 3A. Black & White Graph Theme
- Folders: black (dark mode: white), shade lightens with nesting depth
- Notes: keep current color scheme
- Chats: yellow (or configurable)
- Nodes still glow — white/black glow effect

### 3B. Living Graph Animation
- Nodes drift slowly when idle — makes graph feel alive
- Subtle, continuous, non-distracting movement
- Configurable: Settings toggle for "Living Graph"

### 3C. Nested Perspective Layers
- Select a folder → zooms into that folder's subgraph
- Nested folders appear as layered depth planes (perspective)
- Moving "into" nested layers feels cinematic — real depth, not parallax
- Each depth level is a visual layer in the hologram overlay
- Setting: "Immersive Graph" toggle for enhanced depth effect

### 3D. Dead Code Cleanup in Graph
- Remove unused graph code from the "living system" era
- Audit graph-engine for dead code paths
- Focus Metal rendering on production quality

---

## TIER 4: SIDEBAR OVERHAUL

### 4A. Unified Notes Sidebar + Mini Chat
- Notes sidebar becomes the primary knowledge surface
- Contains: Notes, Recent Chats, Agent Vaults, Code, Coworker Agent
- Toggle between sidebar and mini chat (or show both)
- Mini chat appears as a section/tab within sidebar

### 4B. Coworker Agent (Sidebar Intern)
- Sidebar turns into an agent that works on local files
- Routes through agent runtime OR operates independently
- Can: organize notes, suggest edits, find related content, draft responses
- Background mode: works while you do other things

### 4C. Agent Vault Directories
- Per-model knowledge profiles visible in sidebar
- User can browse, edit, rebuild (per CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md)
- Shows: concept index, active context, instructions, knowledge profile

---

## TIER 5: MULTI-AGENT SYSTEM (OpenClaw-level)

### 5A. Sub-Agent Architecture
- Main agent spawns sub-agents for parallel tasks
- Sub-agents communicate with each other
- Concurrent process execution (not sequential)
- Context scoping: each sub-agent sees only relevant context
- **Pattern:** OpenClaw's agent delegation + NemoClaw's parallel execution

### 5B. Agent Personas
- Each agent has a personality JSON + system prompt + limits
- Can have email, social media accounts (for automation)
- Profile: name, model, tools, personality, communication style, boundaries
- Max 4 agent profiles active + 1 user profile

### 5C. Agent Self-Development
- An agent can be given an entire vault + app instance
- It asks AI questions, takes notes, does auto-research
- Creates its own models, agents, trains them
- Separate instance of the app that self-develops based on profile
- **This is the autonomous research pipeline vision**

### 5D. Wake-Up Summary
- Agent works overnight (NightBrain + background tasks)
- On wake: desktop shows summary of completed work
- "While you slept, I researched X, organized Y, drafted Z"
- OpenClaw-level: continuous operation across sleep/wake cycles

---

## TIER 6: COMMUNICATION CHANNELS

### 6A. iMessage Agent (Tier 1F)
- Text Epistemos to do work, fetch stuff, get summaries
- Bidirectional: read messages + send responses

### 6B. Telegram Webhook (from Hermes v0.6.0)
- Wire Hermes's new Telegram adapter
- Agent responds to Telegram messages

### 6C. Agent Email
- Give agent its own email account
- Auto-responds, fetches info, files emails as notes

---

## TIER 7: OPTIMIZATION & HARDENING

### 7A. Stream Composition Pipeline
- Compose existing safety components into a clean chain:
  - Raw SSE → Thinking Extraction → Cost Accumulation → Credential Redaction → UI Rendering
- Currently called separately at ad-hoc points

### 7B. Auth Profile Rotation
- Multi-key failover with cooldown
- Primary → secondary → tertiary API keys
- Automatic rotation on rate limit or error

### 7C. ContextBudgetManager in Omega
- Wired in Hermes flow but NOT in Omega orchestrator
- Add budget tracking to OrchestratorState

### 7D. Phase 8: macOS Isolation
- Sandbox-exec profiles for candidate evaluation
- Volatile project roots, env scrubbing, network restriction

### 7E. Zero-Copy & Performance
- Audit all FFI boundaries for unnecessary copies
- Metal StorageModeShared everywhere possible
- Profile with Instruments before optimizing
- Crossbeam-epoch for lock-free reads on hot paths

---

## TIER 8: BUSINESS FEATURES

### 8A. Company Training Pipeline
- Fine-tune local 3-tier models for companies
- Specific purposes: customer support, internal tools, domain expertise
- Niche: training local models on-device for enterprise clients

### 8B. Tyler/Local Business Outreach
- Research companies in Tyler area
- Pitch AI automation, app development, model training
- Create portfolio from Epistemos capabilities

---

## RESEARCH ITEMS (Need Investigation Before Building)

| ID | Topic | Blocker For |
|----|-------|-------------|
| R2 | CoreML ANE dual-brain path | Tier 5 sub-agents |
| R3 | Dual-model memory budget | Tier 5 concurrent agents |
| R10 | Cartesia Metal kernels for Mamba-2 | Custom model training |
| R14 | LoRA on Mamba-2 via MLX | Knowledge Fusion |
| R17 | SMAppService App Store distribution | Mac App Store version |
| NEW | OpenClaw VLM agent loop analysis | Tier 2 coding features |
| NEW | Hermes v0.6.0 profiles architecture | Tier 1 multi-instance |
| NEW | Docker-in-app feasibility | Tier 5 isolation |

---

## EXECUTION ORDER (Recommended)

```
IMMEDIATE (This week):
  0A Notarization + Sparkle
  0B ResearchPause fix
  0C EmbeddingService hang

NEXT (Agent parity):
  1A Merge Hermes v0.6.0
  1D Restyle agent window (Xcode-inspired)
  1E Skills system Swift integration
  1B Multi-instance profiles

THEN (Features):
  2A-2C Code features
  3A-3C Graph enhancements
  4A-4C Sidebar overhaul

LATER (Advanced):
  5A-5D Multi-agent system
  6A-6C Communication channels
  7A-7E Optimization
  1F iMessage

DEFERRED (Research-blocked):
  8A-8B Business features
  Phases 10-13 from MASTER_HARDENING_AND_HARNESS_PLAN
```
