# Epistemos Vision Backlog — Comprehensive Future Work

**Last Updated:** 2026-04-01
**Source:** Brain dump + all research docs + codebase audit

This is the COMPLETE list of remaining work. Items are organized by theme and priority tier.

---

## TIER -1: CLOUD PROVIDER OVERHAUL (Changes how the entire app connects to AI)

### -1A. Single Active Provider Model (Replace multi-provider model selector)

**Current problem:** The model selector shows a flat list of all cloud providers' models mixed together (Claude Opus, GPT-5.4, Gemini, etc.). This is confusing and requires API keys for every provider.

**New model:**
- Settings → "AI Provider" section with ONE active provider at a time
- Default: OpenAI (OAuth sign-in, zero API keys needed)
- User can switch to: Anthropic, Google, or Local-only
- The model selector in chat ONLY shows models from the active provider + local models

**Provider selector in Settings:**
```
┌─ AI Provider ─────────────────────────────┐
│ ● OpenAI        [Sign In with OpenAI]     │  ← DEFAULT, OAuth
│ ○ Anthropic     [Enter API Key]           │  ← API key required
│ ○ Google        [Sign In with Google]     │  ← OAuth possible
│ ○ Local Only    [No cloud needed]         │  ← MLX only
└───────────────────────────────────────────┘
```

**Model selector in chat (adapts to active provider):**

When OpenAI is active:
```
── OpenAI ──
  GPT-5.4          (Pro)
  GPT-5.4 Mini     (Fast)
  o3               (Thinking)
── Local ──
  Qwen 3.5 4B     (Fast)
  Qwen 3.5 9B     (Thinking)
```

When Anthropic is active:
```
── Anthropic ──
  Claude Opus 4.6    (Pro)
  Claude Sonnet 4.6  (Fast)
  Claude Haiku 4.5   (Fast)
── Local ──
  Qwen 3.5 4B     (Fast)
  Qwen 3.5 9B     (Thinking)
```

When Google is active:
```
── Google ──
  Gemini 2.5 Pro   (Thinking)
  Gemini 2.5 Flash (Fast)
── Local ──
  ...
```

### -1B. OpenAI OAuth Sign-In (Zero API Keys — THE Default Path)

**Implementation:** Use OpenAI's Apps SDK OAuth 2.1 flow.
- User taps "Sign In with OpenAI" in Settings
- OAuth browser flow → user logs into their ChatGPT account
- Token stored in macOS Keychain (same pattern as current API keys)
- ChatGPT Plus/Pro subscription billing handles everything — no separate API charges
- Free tier users get limited access, subscribers get full access
- This is exactly how Xcode 26 does it

**Codex research tasks before implementing:**
1. Read OpenAI Apps SDK auth docs: https://developers.openai.com/apps-sdk/build/auth
2. Determine if Apps SDK OAuth works for direct API calls or only for Apps SDK features
3. If OAuth doesn't grant API access, fall back to API key but with a streamlined "paste your key" flow
4. Check if ChatGPT subscription tokens can call the /v1/chat/completions endpoint
5. Check rate limits: does Plus get the same limits as API tier?

### -1C. Provider-Native Controls (Match the native app experience)

Each provider exposes different capabilities. The controls in the chat UI should match what the native app offers:

**OpenAI controls:**
- Model tier: Pro / Fast / Thinking (maps to GPT-5.4 / GPT-5.4 Mini / o3)
- Thinking mode: toggle on/off for o3 (shows reasoning steps)
- Web search: toggle (ChatGPT can search the web)
- Code interpreter: toggle
- Temperature / top-p (advanced, collapsed by default)

**Anthropic controls:**
- Extended thinking: toggle on/off (shows Claude's thinking process)
- Thinking budget: slider (low / medium / high token budget for thinking)
- System prompt: editable (power users can customize)
- Prompt caching: auto-enabled for conversations >1024 tokens

**Google controls:**
- Thinking: toggle for Gemini 2.5 Pro thinking mode
- Grounding: toggle for Google Search grounding
- Safety settings: configurable thresholds

**Local model controls (unchanged):**
- Fast / Thinking mode
- Temperature
- Max tokens

### -1D. Google OAuth Sign-In
Google supports full OAuth 2.0 for Gemini API — users can sign in with their Google account.
- Create OAuth 2.0 Client ID in Google Cloud Console (Desktop app type)
- Standard OAuth browser flow → user signs into Google → grants Gemini API scope
- Token cached in Keychain, refreshed automatically
- **Codex:** Read https://ai.google.dev/gemini-api/docs/oauth for implementation details
- Google AI Studio free tier gives 1500 req/day on Flash, 50 req/day on Pro

**Authentication summary:**
| Provider | Auth Method | Zero-Key? | Subscription Billing? |
|----------|-----------|-----------|----------------------|
| OpenAI | OAuth (Apps SDK) | YES | ChatGPT Plus/Pro |
| Google | OAuth (Google Sign-In) | YES | Google AI Studio / Workspace |
| Anthropic | API Key (manual) | NO | Pay-per-use only |

### -1E. Anthropic API Key Flow (Streamlined)
- Anthropic killed third-party OAuth — API key is the only option
- But make it frictionless: Settings → tap Anthropic → "Get API Key" button opens console.anthropic.com/settings/keys in browser
- User pastes key → saved to Keychain → validated immediately → done
- The auth failure banner on landing page already handles the "missing key" case

### -1F. Dynamic Mode Selector (Adapts to Provider + Model)

The mode selector (Fast / Thinking / Pro / Agent) is NOT a fixed list. It dynamically shows only the modes the current model actually supports. Modes that don't apply DISAPPEAR — they don't grey out.

**Per-provider mode capabilities:**

| Provider | Model | Fast | Thinking | Pro | Agent |
|----------|-------|------|----------|-----|-------|
| OpenAI | GPT-5.4 | ✅ | ✅ (via o3) | ✅ | ✅ (tool_use) |
| OpenAI | GPT-5.4 Mini | ✅ | ❌ | ❌ | ✅ (tool_use) |
| OpenAI | o3 | ❌ | ✅ (native) | ✅ | ✅ (tool_use) |
| Anthropic | Claude Opus 4.6 | ✅ | ✅ (extended thinking) | ✅ | ✅ (tool_use) |
| Anthropic | Claude Sonnet 4.6 | ✅ | ✅ (extended thinking) | ❌ | ✅ (tool_use) |
| Anthropic | Claude Haiku 4.5 | ✅ | ❌ | ❌ | ❌ |
| Google | Gemini 2.5 Pro | ✅ | ✅ (native) | ✅ | ✅ (tool_use) |
| Google | Gemini 2.5 Flash | ✅ | ❌ | ❌ | ✅ (tool_use) |
| Local | Qwen 3.5 4B | ✅ | ✅ | ❌ | ❌ |
| Local | Qwen 3.5 9B | ✅ | ✅ | ❌ | ❌ |

**Behavior:**
- User selects a model → mode selector instantly updates to show only supported modes
- If current mode is not supported by new model → auto-switch to Fast
- Modes that disappear animate out (not instant pop — smooth 150ms transition)
- Modes that appear animate in
- The mode selector should feel alive and responsive to model changes

**Provider-specific controls (appear below mode selector when relevant):**

OpenAI active:
- Web search toggle (when model supports it)
- Code interpreter toggle

Anthropic active:
- Extended thinking toggle (Opus/Sonnet only)
- Thinking budget: Low (1K tokens) / Medium (4K) / High (16K) / Max (model decides)
- Prompt caching indicator (auto-enabled, shows "cached" badge when active)

Google active:
- Search grounding toggle (Gemini Pro only)
- Safety threshold selector (default / relaxed / strict)

Local active:
- Temperature slider
- Max tokens slider

**Implementation:**
- `CloudTextModelID` already has a `provider` field — extend with `supportedModes: Set<OperatingMode>`
- Mode selector reads `selectedModel.supportedModes` and renders only those
- Provider controls read `activeProvider` and show relevant toggles
- All controls persist per-provider in UserDefaults (switching providers restores last-used settings)

### -1H. Hermes Agent Subprocess — OAuth Token Passthrough

**The key insight:** Hermes doesn't care WHERE the API key came from. It reads `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or `GOOGLE_API_KEY` from its environment. OAuth tokens are bearer tokens — they work in the same `Authorization: Bearer <token>` header as API keys.

**How OAuth flows into Hermes:**
1. User signs into OpenAI via OAuth in Settings → access token stored in Keychain
2. `HermesRuntimeRoute.resolve()` reads token from Keychain (same path as API keys)
3. Token passed to Hermes subprocess as `OPENAI_API_KEY` environment variable
4. Hermes uses it transparently — no Hermes code changes needed

**Same for Google:**
1. User signs into Google via OAuth → access token + refresh token in Keychain
2. Token refresh handled by Swift (Google OAuth tokens expire every hour)
3. `HermesRuntimeRoute` passes current token as `GOOGLE_API_KEY`
4. If token expires mid-session, Swift refreshes and updates Hermes env (requires Hermes restart or env hot-reload)

**Anthropic:** No change — API key from Keychain as today.

**What changes in HermesRuntimeRoute:**
- `resolve()` must check for OAuth tokens FIRST, then fall back to API keys
- OAuth tokens stored with a different Keychain key prefix: `epistemos.oauth.openai`, `epistemos.oauth.google`
- Token refresh logic runs in a background task, updates Keychain, signals Hermes if needed
- `toolGateKeychainMappings` updated to try OAuth token first, then API key

**Agent mode selector should also respect provider modes:**
When Hermes agent is running (not just chat), the mode selector still applies:
- OpenAI agent: can use GPT-5.4 (Pro), o3 (Thinking), GPT-5.4 Mini (Fast)
- Anthropic agent: can use Opus (Pro), Sonnet (Fast), with extended thinking toggle
- Google agent: can use Gemini 2.5 Pro (Thinking), Flash (Fast)
- Local agent: Qwen only (Fast/Thinking, no Pro)

The `HermesRuntimeRoute` already selects the model — extend it to also pass mode-specific parameters:
- OpenAI Thinking: route to o3 model slug
- Anthropic Thinking: set `HERMES_EXTENDED_THINKING=true` + budget env var
- Google Thinking: route to gemini-2.5-pro with thinking config
- The mode selector in agent panel works identically to chat mode selector

### -1I. Smart Triage & Fallback System

**CODEX: Before implementing this, audit the current triage logic in these files:**
- `Epistemos/Engine/TriageService.swift` — current routing logic
- `Epistemos/Engine/PipelineService.swift` — current pipeline orchestration
- `Epistemos/State/InferenceState.swift` — model selection, capability gating, policy engine
- `Epistemos/Engine/AppleIntelligenceService.swift` — Apple Intelligence availability + token budget
- `Epistemos/Engine/MLXInferenceService.swift` — local model loading, idle unload, memory policy
- `Epistemos/Agent/HermesSubprocessManager.swift` — HermesRuntimeRoute resolution
- `Epistemos/Omega/Orchestrator/FallbackChainResolver.swift` — existing fallback logic

**Read and understand the current triage before changing anything. Report what exists, what's broken, what's missing.**

---

#### Chat Triage (regular conversations, not agent)

**Priority order — cloud first, Apple Intelligence second, local MLX last:**

```
User sends message
  ↓
TIER 1: Active cloud provider
  - OpenAI (OAuth) / Anthropic (API key) / Google (OAuth)
  - Use the model matching the user's selected mode (Pro/Thinking/Fast)
  - If cloud succeeds → done
  - If cloud fails (rate limit, network down, token expired, 401) → TIER 2
  ↓
TIER 2: Secondary cloud provider (if configured)
  - User may have both OpenAI AND Anthropic configured
  - Try the non-active provider as backup
  - If succeeds → toast: "Switched to [provider] — [primary] unavailable"
  - If fails or not configured → TIER 3
  ↓
TIER 3: Apple Intelligence (on-device, fast, free)
  - Available on Apple Silicon with macOS 26+
  - Best for: summaries, quick Q&A, simple tasks
  - NOT for: tool calling, long reasoning, code generation
  - If available → use it, toast: "Using Apple Intelligence — cloud unavailable"
  - If not available (model not downloaded, query too complex) → TIER 4
  ↓
TIER 4: Local MLX (complexity-routed, always works)
  - Route by query complexity:
    - Simple (short query, factual) → Qwen 3.5 2B (if installed, fastest)
    - Medium (multi-paragraph, analysis) → Qwen 3.5 4B
    - Complex (reasoning, code, long context) → Qwen 3.5 9B (if memory allows)
  - If selected model not installed → try next smaller
  - Toast: "Using local [model] — cloud unavailable"
  - This tier ALWAYS works — guaranteed fallback
```

**Complexity routing for local models (TIER 4):**
```
Query analysis (lightweight, <1ms):
  - Token count < 50 AND no code blocks → Simple → route to smallest available
  - Token count < 200 OR summary/QA intent → Medium → route to 4B
  - Token count >= 200 OR code/reasoning/multi-step → Complex → route to 9B
  - If target model not installed or won't fit in memory → downgrade one tier
  - Apple Intelligence and Qwen 2B are roughly comparable for simple tasks
    — Apple AI slightly better at summaries, Qwen 2B slightly better at following instructions
    — when both available for a simple query, prefer Apple AI (no memory pressure)
```

**Apple Intelligence vs Qwen 2B decision (for TIER 3/4 boundary):**
- Simple summary or Q&A → Apple Intelligence (faster, no MLX load overhead)
- Needs specific instruction following → Qwen 2B (better at structured output)
- Needs code → skip both, go to Qwen 4B minimum
- Needs reasoning → skip both, go to Qwen 9B
- Apple Intelligence has a hard 4096 token context limit — anything longer → local MLX

---

#### Agent Triage (tool-calling tasks)

Agents REQUIRE tool calling. Apple Intelligence cannot call tools. Small local models can't reliably call tools. Different triage:

```
Agent task submitted
  ↓
TIER 1: Active cloud provider (must support tool_use)
  - OpenAI: GPT-5.4 or o3 (both support tool_use)
  - Anthropic: Opus or Sonnet (both support tool_use)
  - Google: Gemini Pro (supports function_calling)
  - If succeeds → done
  - If fails → TIER 2
  ↓
TIER 2: Secondary cloud provider (if configured, must support tool_use)
  - Same logic as chat TIER 2
  - Toast: "Agent switched to [provider]"
  - If fails → TIER 3
  ↓
TIER 3: Local agent-capable model
  - ONLY Qwen 3.5 9B qualifies (canActAsAgent = true in LocalTextModelID)
  - Qwen 4B and 2B do NOT reliably tool-call → skip them
  - If 9B loaded and memory available → use it
  - If 9B can't load → TIER 4
  ↓
TIER 4: Reject with actionable message
  - "This task requires a cloud model or Qwen 9B."
  - "Sign in to OpenAI (free) or install Qwen 9B to use agents."
  - Show a button that navigates to Settings → AI Provider
  - Do NOT fall back to Apple Intelligence or small models — a non-tool-calling
    response is worse than no response. The user must understand the constraint.
```

**Apple Intelligence is NEVER used for agents.** No tool calling support = no agent capability. Don't fake it.

---

#### UI Behavior During Fallback

**Toast notifications (non-blocking, bottom-right):**
- Cloud → secondary cloud: "Switched to [Anthropic] — [OpenAI] rate limited"
- Cloud → Apple Intelligence: "Using Apple Intelligence — cloud unavailable"
- Cloud → Local: "Using Qwen 3.5 [4B] locally — cloud unavailable"
- Cloud recovered: "OpenAI reconnected" (but do NOT auto-switch back — let user decide)

**Mode selector updates on fallback:**
- If user was in "Pro" mode and falls back to Apple Intelligence (only Fast) → auto-switch to Fast
- Mode selector animates to show only fallback model's supported modes
- When user manually switches back to cloud → modes restore to cloud model's capabilities

**Agent panel during fallback:**
- If cloud fails mid-agent-task → pause task, show: "Cloud connection lost. Resume when reconnected?"
- Do NOT silently switch agent to local model mid-task — tool schemas may differ
- User chooses: wait for reconnect, switch to local 9B and restart, or cancel

**Settings indicator:**
- Active provider shows green dot when connected
- Yellow dot when using fallback
- Red dot when disconnected and no fallback available
- Provider health checked every 60s (or on demand via pull-to-refresh in settings)

---

## TIER 0: SHIP-BLOCKING (Cannot release without these)

### 0A. Notarization + Sparkle Auto-Update
- DMG packaging exists (GitHub Actions) but NO xcrun notarytool step
- No Sparkle SUFeedURL or SUPublicEDSAKey configured
- Cannot distribute without notarization on macOS
- **Action:** Add notarize step to release.yml, configure Sparkle 2, add SUFeedURL to Info.plist

### 0B. ResearchPause Continuation Fix — ✅ DONE (Codex: bc3266ee)

### 0C. EmbeddingService Main Thread Hang
- 3738ms hang during "pushed 1017 embeddings" — MainActor.run block after FFI call
- Profile with Instruments, move remaining MainActor work to background
- **File:** `Epistemos/Graph/EmbeddingService.swift`
- **Status:** Needs verification — Codex may have addressed indirectly via graph startup fix (c5e30065)

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

### 1-STRATEGY. Surpassing OpenClaw (Port Patterns, Don't Rewrite)
**DO NOT rewrite OpenClaw in Rust/Swift.** The bottleneck is LLM latency (seconds), not runtime speed (microseconds). Port the 5 orchestration patterns that make OpenClaw powerful:
1. **Sub-agent spawning** → Hermes v0.6.0 profiles (already supports multi-instance)
2. **Concurrent task execution** → Rust tokio tasks with bounded parallelism
3. **Session lifecycle** → existing session/progress store + daily reset semantics
4. **Channel abstraction** → Hermes adapters (Telegram, Slack, iMessage)
5. **Gateway control plane** → Knowledge Brick + ⌘K IS the control plane

**Why Epistemos beats OpenClaw even without a rewrite:**
- OpenClaw has zero knowledge management — no vault, no graph, no search, no memory
- OpenClaw forgets everything between sessions unless you manually maintain context
- Epistemos has: 3ms semantic search, nightly training, Ebbinghaus decay, Living Vault
- OpenClaw is a powerful employee with amnesia. Epistemos is a research partner with perfect memory.

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

## TIER 3: GRAPH-FIRST APP (The graph IS the app)

### 3-PRIME. Three-Stance App Model (Quick / Focused / Immersive)

The app has three natural "stances" the user drifts between. No mode is mandatory. The graph is always one keystroke away but never blocking fast work.

**Stance 1: Quick Mode (default on launch)**
- Home greeting (LiquidGreeting) + shortcut hints — the brand moment
- Click anywhere → search popover → start typing → done
- No graph, no overhead. 90% of sessions start and end here.
- This is the fast path for "open app, capture thought, close"

**Stance 2: Focused Mode**
- Note open in editor, Knowledge Brick sidebar on the left
- Traditional macOS layout — editor + sidebar + toolbar
- No graph visible. For deep writing without distraction.
- Contextual Shadows appear as ghost cards in the Knowledge Brick margin

**Stance 3: Immersive Mode (⌘G toggle)**
- Hologram overlay activates on top of current view
- Entire vault as floating constellation — notes, chats, folders, agents
- Tap a note node → floating editor panel opens INSIDE the graph
- Tap a chat node → chat panel floats inside the graph
- Tap a folder → cinematic zoom into nested perspective layers
- Agent work visible as pulsing nodes with particle trails between tool calls
- Contextual Shadows physically orbit the active panel (semantic gravity)
- Knowledge Brick sidebar still visible as the left anchor
- ⌘G again → dismisses overlay, returns to Quick or Focused stance
- You're NEVER stuck — one keystroke in, one keystroke out

**Graph lenses (within Immersive Mode):**
- Default lens: all notes, chats, folders
- "Agents" lens: agent vaults, model nodes, tool nodes, active sessions
- "Temporal" lens: time-axis showing knowledge evolution
- Each lens is a filter on the same underlying Metal-rendered graph

**Floating panels inside the graph (never leave immersive mode):**
Every interaction opens a panel that floats inside the constellation. The graph is the workspace.

| Trigger | Panel | Content |
|---------|-------|---------|
| Tap note node | Editor panel | Full note editor, same as focused mode |
| Tap agent diamond | Agent runtime panel | Live tool calls, streaming output, thinking glow, cost |
| Tap model vault rect | Vault inspector | Knowledge profile, concept index, edit in place |
| Tap skill hexagon | Skill detail | Description, usage history, enable/disable toggle |
| Tap code rectangle | Code preview | Syntax-highlighted, read-only or editable |
| Tap person dot | Entity panel | All notes mentioning this person, relationship map |
| Tap chat circle | Chat panel | Conversation history, continue chatting inline |
| ⌘K | Command bar | Floating over graph, same as Knowledge Brick |
| ⌘, or gear node | Settings panel | Inline settings, same as Knowledge Brick bottom |

- Panels are draggable, resizable, dismissable (click X or Esc)
- Multiple panels open simultaneously — tile or overlap
- Knowledge Brick sidebar stays as left anchor (persistent navigation)
- Graph fills remaining space, panels float within it
- Contextual Shadows orbit the FOCUSED panel (whichever was last clicked)

**IMMERSIVE MODE PERFORMANCE MANDATE:**
Immersive mode MUST run at the same performance as the current graph overlay. Adding floating panels, Contextual Shadows, motion blur, and haptics must not degrade frame rate. Canonical enforcement:
- Floating panels are NSPanels (separate windows) — zero impact on Metal render pipeline
- Contextual Shadows are a force injection into existing compute shader — no new draw calls
- Motion blur is a per-node float in the existing fragment shader with early-exit when 0
- Haptics are NSHapticFeedbackManager calls (system API, no render cost)
- Command bar and settings are NSPanels (separate windows)
- Knowledge Brick sidebar is NSHostingView swap (only active tab in view tree)
- Graph render loop unchanged: same display link, same atomic guards, same frame budget
- PowerGuard eco/lowPower: 60fps cap + calmer physics still apply in immersive mode
- **Target: immersive mode with 5 floating panels open = same fps as current graph overlay with 0 panels**
- **Codex: profile before and after implementing each immersive feature. Reject any feature that drops fps by more than 5%.**

**Global hotkey: ⌥Space (Option+Space)**
- Works from ANY app — summons the ⌘K command bar as a floating overlay
- Same command bar as in the Knowledge Brick, but system-wide
- Type a note title → teleports to Epistemos with that note open
- Type "agent: research X" → launches agent task without switching apps
- Type "capture: [thought]" → saves to vault without opening the app
- When Epistemos is focused, ⌘K opens the same bar inline

### 3-SHADOW. Contextual Shadows (Real-time semantic gravity)
As you type in ANY note, the most semantically related notes respond physically. Not a list. Not a sidebar. The graph itself reacts to your thoughts.

**The physics are real:**
- Debounce editor text (300ms) → embed current paragraph via InstantRecall (<3ms)
- Top 5 results get a **semantic gravity force** injected into the Metal compute shader
- Cosine similarity maps to gravitational strength: 0.95 similarity = strong pull, 0.80 = gentle drift
- Related nodes physically accelerate toward the active editor panel over 500ms (not teleport — smooth force-directed motion)
- When you stop typing or change topic, the gravity force decays and nodes drift back to equilibrium
- The existing Barnes-Hut N-body repulsion keeps them from colliding — shadows orbit, they don't pile up

**In each stance:**
- **Immersive (⌘G):** shadows orbit your floating editor panel in the hologram. Grab one → dock it beside your note for side-by-side. The graph is alive and responding to your writing.
- **Focused:** ghost cards appear in the Knowledge Brick margin panel. Subtle, non-distracting, clickable.
- **Quick:** shadows don't appear (search popover handles discovery instead)

**Implementation path:**
1. Add `shadow_force` array to the Rust force simulation (per-node attraction toward a target point)
2. Swift sends `(target_x, target_y, node_ids[], strengths[])` to Rust via FFI after each InstantRecall query
3. Rust compute shader applies the force alongside existing N-body + link forces
4. Nodes with shadow force get a glow intensity boost proportional to similarity
5. When shadow force is removed, nodes return to natural equilibrium via existing velocity decay

**Why this is unprecedented:** No app has spatial semantic search where the results physically move in a force-directed simulation. Obsidian shows a list. Notion shows a table. Epistemos shows your related knowledge gravitating toward your current thought in real-time 3D space.

**This is the feature that sells the app in 5 seconds.**

### 3-GRAPH. Universal Graph — Everything Is a Node
The graph stops being "notes only" and becomes the map of your entire knowledge system.

**CODEX INSTRUCTION — DISABLED NODE TYPES:**
The Rust graph engine defines `source` (type 3), `quote` (type 5), and `person` node types.
**These are DISABLED. Do NOT create, render, or wire these node types into any UI, graph builder,
or agent flow.** They remain in the engine code for future use but must be disconnected from all
production paths. Only re-enable if the user explicitly says so. This applies to:
- GraphBuilder.swift — do not generate source/quote/person nodes
- EntityExtractor.swift — do not create source/quote nodes from agent executions
- Graph lenses — no "People" or "Sources" lens
- Node type filters — source/quote/person excluded from all filter UIs
**Active node types: note, chat, folder, idea, agent session, model vault, skill, tool, code file.**

**Node types and visual encoding (ACTIVE ONLY):**
| Type | Shape | Visual | Edges To |
|------|-------|--------|----------|
| Note | Circle | Opacity = Ebbinghaus strength | Other notes (wikilinks), agents (created by) |
| Chat | Small circle | Yellow tint | Notes (spawned from), agents (session of) |
| Folder | Circle | Black/white, shade lightens with nesting depth | Child notes, child folders |
| Idea | Circle | Accent color tint | Notes (spawned from), agents (generated by) |
| Agent session | Diamond | Pulses when active | Tools used, notes created, skills invoked |
| Model vault | Large rounded rect | Color by provider (purple=Anthropic, green=OpenAI) | Skills, tools, memory nodes |
| Skill | Hexagon | Color by category (blue=code, teal=research, coral=writing) | Models that have it, notes it produced |
| Tool | Small square | Connected to models that can use it | Agent sessions that invoked it |
| Code file | Rectangle | Monospace icon, syntax-colored border | Notes that reference it, agents that generated it |

**Disabled (DO NOT WIRE):**
| Type | Engine Code | Status |
|------|------------|--------|
| Source | `NodeType::source = 3` | DISABLED — do not create or render |
| Quote | `NodeType::quote = 5` | DISABLED — do not create or render |
| Person | Not in engine | DISABLED — do not implement |

**Graph lenses (filter views in immersive mode):**
- **All** — full constellation, everything visible
- **Notes** — just vault notes and their connections
- **Agents** — agent vaults, models, tools, active sessions, skills
- **Code** — code files and their connections to notes/agents
- **Temporal** — time-axis showing knowledge evolution

**5 zoom levels (from Living Vault Architecture):**
- Level 1 (cosmic): provider clouds — Anthropic, OpenAI, Local, Personal
- Level 2 (constellation): models/agents within each cloud, edges show shared skills
- Level 3 (solar system): one model selected, its skills/memory/tools/agents orbit it
- Level 4 (planet): one agent or skill, individual memory nodes with strengths
- Level 5 (surface): one node selected, full content shown, edit in place, diff history

**Live state rendering:**
- Active agents pulse, tool call edges flash
- Context window fills as radial progress around model node
- Token flow animates as particles along edges
- Memory mutations flash affected nodes
- Contextual Shadows orbit active editor panel (semantic gravity)

### 3-PHYSICS. Mass-Based Drag, Snap-Back Ripple, Motion Blur, Haptics
**Nodes have weight. You feel it.**

**Mass-based drag resistance:**
- Every node has a `mass` derived from: child count + link count + nesting depth
- Drag force divided by mass: `displacement = cursor_delta / mass`
- Single orphan note (mass ~1) → follows cursor 1:1, light
- Folder with 50 notes (mass ~50) → cursor leads, node lags behind
- Root folder with 200 children → heavy, sluggish, you're pulling against gravity
- Visible elastic tether between cursor and heavy node (faint line, stretches, thins)

**Snap-back on release:**
- Node rubber-bands toward force-layout equilibrium position
- Snap velocity proportional to displacement distance
- Small drag → gentle drift back. Large drag on heavy node → hard snap.
- On snap-back: inject impulse vector at node position
- Existing spring/link forces propagate the impulse as a ripple through connected nodes
- Ripple attenuates with graph distance: 1-hop neighbors move noticeably, 3+ barely

**Motion blur:**
- Radial blur proportional to displacement speed between cursor and node
- Heavy nodes blur more (they lag further behind cursor)
- Per-node `blur_radius` float in fragment shader: `|cursor_vel - node_vel| * mass_factor`
- Blur peaks briefly on snap-back then decays: `blur *= 0.85` per frame until < 0.5px
- Zero cost when blur is 0 (early exit in shader)

**Haptic feedback (NSHapticFeedbackManager):**
- Grab light node → `.alignment` (subtle click)
- Grab medium folder (10-50 children) → `.levelChange` (firm click)
- Grab heavy folder (50+) → strong `.generic` pattern (trackpad THUDS)
- Snap-back → haptic pulse proportional to snap distance
- Heavy snap = strong thud. Light snap = soft tick.

**Implementation (all in existing Rust engine + Metal shaders):**
1. Add `mass: f32` field per node (derived from metadata)
2. Drag interaction: `node_displacement = cursor_delta / mass` with spring tether
3. Release: inject impulse at node position, simulation naturally propagates ripple
4. Fragment shader: `blur_radius` uniform per node, Gaussian sample when > 0
5. Swift: `NSHapticFeedbackManager.defaultPerformer.perform()` on grab/release events

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

## TIER 4: THE KNOWLEDGE BRICK (Replaces notes sidebar entirely)

### 4-PRIME. Knowledge Brick — One Sidebar, Everything Lives Here

The current notes sidebar becomes the **Knowledge Brick** — the single surface where all knowledge, conversations, agents, and code live. It starts wider than the current sidebar (~320px default) and has section toggles at the top.

**Three toggle tabs at the top of the brick:**
- **Notes** — your vault notes, folders, recent edits
- **Chat** — recent conversations, mini chat inline, agent sessions
- **Code** — code files, projects, IDE-style file tree

Each tab shows its own content but shares the same search/command bar at the top.

**Sections within each tab:**

**Notes tab:**
- Recent notes (sorted by last edited)
- Folders (collapsible tree)
- Agent Vaults (per-model knowledge directories — editable)
- Pinned notes
- Decaying notes (Ebbinghaus strength < 0.3 — "needs review")

**Chat tab:**
- Recent chats (clickable → opens chat in main area)
- Active agent sessions (live status, tool calls streaming)
- Mini chat inline (type here, response appears here — no window switch)
- Session history searchable

**Code tab:**
- Project file tree (from workspace/vault)
- Recent code files
- Code streamed from agent/chat responses (auto-captured)
- Syntax-highlighted previews

**The ⌘K Command Bar sits at the TOP of the brick (always visible):**
- Type anything → results appear as you type:
  - Note titles → teleport to note
  - Chat names → open that conversation
  - "settings:eco" → jump to eco mode toggle
  - "agent: research transformers" → launches agent task
  - "@claude summarize week" → agent with vault context
  - "code: main.swift" → opens code file
  - Session IDs → resume a specific agent session
- Command bar is the ONE input that replaces: search, navigation, agent invocation, settings access
- Keyboard-first: ⌘K opens it, arrow keys navigate results, Enter selects, Esc dismisses

**Mini chat lives INSIDE the brick (Chat tab):**
- No separate mini chat window needed
- Type in the chat section → response streams inline
- Toggle "stream to notes" → response also creates/appends to a note
- Toggle "stream to code" → code blocks extracted to code section
- Same capabilities as main chat: model selector, context attachments, recent history

**Isolation between tabs:**
- Each tab maintains its own scroll position and selection state
- Switching tabs is instant (no reload, just visibility toggle)
- Keyboard shortcuts: ⌘1 = Notes, ⌘2 = Chat, ⌘3 = Code

**Width behavior:**
- Default: ~320px (wider than current sidebar)
- Draggable edge to resize
- Collapse to icon-only strip (~48px) with ⌘\
- Expand to full split (50/50) for focused browsing

### 4-ENGINEERING. Knowledge Brick & Floating Panel Isolation (Canonical Engineering Spec)

**Problem:** Cramming notes + chat + code + settings + agent panels into one SwiftUI view hierarchy will lag. The current notes sidebar already shows layout cost. Adding more content without isolation guarantees frame drops.

**Principle: render only the active tab. Inactive tabs do not exist in the view tree.**

**Recommended architecture (Codex: research and validate the best approach before implementing):**

| Component | Recommended Technology | Rationale |
|-----------|----------------------|-----------|
| Knowledge Brick container | NSView (AppKit) | Single hosting view swap, no SwiftUI TabView overhead |
| Each tab content (Notes/Chat/Code) | Separate NSHostingView, swapped in/out | Only active tab in view tree — zero layout cost for hidden tabs |
| Tab switcher | NSSegmentedControl (native) | Consistent with macOS HIG, no custom SwiftUI segment rebuild |
| Tab state persistence | @Observable models per tab | Scroll position, selection state survive tab switch without keeping view alive |
| ⌘K command bar | NSPanel (borderless floating window) | Own window, own view tree, no layout interference with sidebar or graph |
| ⌥Space global overlay | NSPanel + NSEvent.addGlobalMonitorForEvents | System-wide hotkey, floating panel over all apps |
| Floating graph panels (immersive) | NSPanel per panel instance | True OS-level window isolation, native drag/resize, composited by window server |
| Metal graph | NSView with CAMetalLayer (existing) | Own render pipeline, unaffected by panel count or sidebar state |
| Settings panel | NSHostingView in sidebar (inline) | Same swap mechanism as tab content — no separate window |

**Why NSPanel for floating panels:**
- Each panel has its own view tree, own layout pass — no cross-panel interference
- Native dragging, resizing, minimize for free
- Window server composites panels over the Metal graph — zero GPU overhead from panels
- This is exactly how Xcode inspectors, Instruments detail views, and Final Cut floating panels work
- NOT SwiftUI overlays (which share the parent view's layout pass and cause frame drops)

**Why NSHostingView swap instead of SwiftUI TabView:**
- SwiftUI TabView keeps all tabs in memory and computes layout for hidden tabs
- NSHostingView swap removes inactive tabs from the view hierarchy entirely
- Reconstruct from @Observable model on tab switch — scroll position, selection all restored
- Same pattern as GraphRenderWakeSignature (store state separately, render from it on demand)

**Performance guarantees:**
- 10 floating panels open in immersive mode → graph still renders at 120fps
- Knowledge Brick tab switch → <16ms (single NSHostingView swap)
- ⌘K command bar appears → <8ms (NSPanel makeKeyAndOrderFront)
- Each component is independently profiled — no shared layout bottleneck

**IMPORTANT FOR CODEX:** This is a recommended starting architecture based on AppKit best practices. Before implementing, research:
1. Whether NSHostingView swap causes any SwiftUI state loss that @Observable doesn't cover
2. Whether NSPanel compositing has any interaction with Metal's CAMetalLayer presentDrawable
3. Whether there's a better pattern for floating panels in macOS 26 (SwiftUI Scene? WindowGroup?)
4. Profile the current notes sidebar to identify the exact source of lag before assuming it's view hierarchy size
5. Consider whether LazyVStack inside each tab eliminates enough overhead to stay pure SwiftUI
6. Research how CodeEdit and Nova handle their sidebar panel architecture

**The goal is zero-compromise: 120fps graph + responsive sidebar + instant command bar + N floating panels, all isolated.**

### 4-SETTINGS. Inline Settings Panel (Kill Separate Window)
- Gear icon at bottom of Knowledge Brick expands inline settings
- Quick toggles at top: eco mode, model selector, theme, graph quality
- Full settings expand below: Hermes config, API keys, NightBrain, training
- ⌘K → type "eco" → toggle instantly (no window, no navigation)
- ⌘K → type "theme" → switch theme instantly
- ⌘K → type "api key" → jumps to credentials section
- DELETE the separate SettingsView window — everything lives in the brick
- Like Xcode's sidebar inspector: settings where you already are

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

## TIER 8B: LIVING VAULT (from LIVING_VAULT_ARCHITECTURE.md — Sprint Omega-5)

The vault becomes a living cognitive substrate. Every memory change is a diff, not an overwrite.

### 8B-1. Diff Engine (Rust)
- `agent_core/src/storage/diff_engine.rs` — unified diff via `similar` crate
- Text diff + JSON tree diff + fuzzy patch application
- **Sprint task:** Omega-5 Task 1

### 8B-2. Memory Classifier (Rust)
- `agent_core/src/storage/memory_classifier.rs` — ADD/UPDATE/DELETE/NOOP
- Embedding similarity (cosine > 0.85) + lightweight LLM classification
- **Sprint task:** Omega-5 Task 2

### 8B-3. Ebbinghaus Decay (Rust)
- `agent_core/src/storage/memory_decay.rs` — strength decay + GC sweep
- `strength(t) = strength(t₀) × e^(-λ × (t - t₀))`
- Pin/boost/manual delete. Graph shows strength as node opacity.

### 8B-4. Cross-File Propagation
- When one vault file is patched, scanner checks all references
- All patches land as one atomic git commit — no belief drift between files
- Uses tantivy full-text search to find references

### 8B-5. Git as Cognitive Journal
- Every vault mutation is a git commit with structured message
- `git log` IS the agent's intellectual history
- `git revert` undoes a bad memory

### 8B-6. Context Compiler (Rust)
- `agent_core/src/context_compiler.rs` — prompt DAG assembly
- Cache-optimal ordering (U-curve aware): tools → system → skills → memory → few-shot → RAG → history → user message
- Multi-level compression (lossless → near-lossless → LLMLingua → aggressive)
- Self-improving optimization loop (DSPy/OPRO/EvoPrompt style)

### 8B-7. Multi-Vault Registry
- Per-model vaults, per-agent vaults, per-user vault
- Vault switching in UI changes what context compiler draws from
- Merges with priority: agent > model > personal

### 8B-8. Agent Graph Visualizer
- 5 zoom levels (cosmic → constellation → solar system → planet → surface)
- Live state: pulsing active agents, flashing tool edges, token flow particles
- Phase 1: Grape, Phase 2: Metal instanced, Phase 3: full Metal compute

---

## TIER 8C: TRANSFORMATIVE UX FEATURES (from session analysis)

### 8C-1. Vault Pulse (Graph as living ambient layer)
- Notes touched today glow brighter (higher opacity)
- Notes decaying (Ebbinghaus) fade in real-time
- NightBrain-updated nodes have subtle ring indicator
- Agent active work pulses with particle trails
- The graph IS your vault's vital signs

### 8C-2. Wake-Up Briefing
- On first open each day: "While you slept..." summary
- NightBrain + heartbeat traces → compiled into brief
- Shows: notes updated, concepts grown, contradictions found, diffs
- Tap any item → deep-link to the relevant note/diff

### 8C-3. One-Click Research Mode (⌘R)
- Highlight concept → press ⌘R
- Step 1: InstantRecall finds what you already know (vault)
- Step 2: Web search for what's new (Tavily/Exa via Hermes)
- Step 3: Local model synthesizes: your notes + new findings + contradictions
- Step 4: Streams result into new linked note
- All pieces exist — this is pure orchestration wiring

### 8C-4. Ghost Writer (AI prose completion in your style)
- Pause typing for 3 seconds → ghost completion appears (30% opacity)
- Tab to accept, keep typing to dismiss
- Generated by YOUR QLoRA-trained model — writes like you
- Uses MoLoRA adapter matched to current context
- Like GitHub Copilot but for prose, trained on YOUR vault

### 8C-5. Time Machine for Ideas
- Timeline slider at bottom of any note
- Slide to January → see what model would have said then vs now
- Monthly LoRA snapshots + embedding drift visualization
- Graph view: concept vectors shift over time as understanding evolves
- "How has my thinking about X changed?"

### 8C-6. Instant Command Bar (⌘K)
- Single keystroke → unified command palette over everything
- Type note title → teleport. Type question → AI answers from vault.
- "research [topic]" → launches research mode
- "train" → kicks off vault training
- "agent: [task]" → delegates to Hermes
- "@claude summarize my week" → agent with vault context
- The surface that unifies search + AI + agent + notes into one gesture

### 8C-7. Temporal Knowledge Decay Visualization
- In the graph, notes you haven't touched fade over time (Ebbinghaus decay already computed)
- A "Memory Health" dashboard shows: notes at risk of being forgotten, concepts strengthening, knowledge gaps
- Weekly digest: "You're losing grip on X — here are the 3 notes to revisit"
- The graph literally shows your memory fading — motivates review without nagging

### 8C-8. Epistemic Drift Detection
- Monthly LoRA snapshots already exist — wire them to a comparison view
- "Your understanding of [attention mechanisms] shifted 23% since January"
- Shows which notes caused the shift, what changed, whether it was intentional
- Unique to Epistemos — no other tool tracks how your thinking evolves

### 8C-9. Ambient Capture (from North Star doc)
- Background listener captures ideas from any app via global hotkey
- ⌘⇧E from anywhere → quick capture overlay → idea lands in vault as a node
- Auto-tagged with: source app, timestamp, current context
- Appears in graph immediately as a fresh bright node

### 8C-10. Contextual Shadows — Graph Physics Mode
- In hologram overlay: related notes gravitationally orbit your active panel
- Semantic similarity = gravitational force (closer match = tighter orbit)
- Grab an orbiting node → dock it beside your current note for side-by-side
- In modular mode: same data renders as ghost cards in a margin panel
- The shadows aren't a list — they're spatial, physical, part of the graph simulation

### 8C-11. Knowledge Gaps Detection
- After vault analysis: "You have 47 notes on transformers but nothing on state space models"
- Suggests research directions based on what's missing from your knowledge graph
- Agent can auto-research gaps overnight via NightBrain + Hermes

### 8C-12. "It Just Knows" Notification
- Background agent detects: relevant new paper, vault contradiction, trending concept
- Native macOS notification with insight preview
- Tap → deep-link to relevant note with insight highlighted
- NightBrain + heartbeat + Hermes tools power the detection

---

## TIER 9: CODE EDITOR & IDE FEATURES (from Architecture Discovery Report)

### 9A. Custom CoreText Code Editor Surface
- Reject TextKit 2 for code — viewport estimation breaks scroll positioning
- Custom NSView + CTTypesetter + CTFrame for code rendering
- Hardware-accelerated glyph rendering, sub-16ms typing latency
- Line numbers, gutters, minimap in same draw pass
- **Reference:** Nova, CodeEdit both abandoned NSTextView for this approach

### 9B. Rust Rope Text Storage
- Replace String-based text storage with Sum-Tree/Rope in Rust
- O(log N) for all operations (insert, delete, search)
- Immutable snapshots for concurrent background parsing
- Zero-copy cursor for Tree-sitter integration
- **Reference:** Zed, Helix use this pattern

### 9C. Tree-sitter Incremental Parsing
- Embed Tree-sitter in Rust core for Swift, Rust, Python, Markdown, Web
- Incremental AST updates in <2ms per keystroke
- Syntax tokens returned as flat C-array via FFI: `[start_byte, end_byte, token_id]`
- **Already partially exists** in epistemos-core — needs wiring to code editor surface

### 9D. LSP Supervisor in Rust
- sourcekit-lsp (Swift), rust-analyzer (Rust), pyright (Python), typescript-language-server (Web)
- Rust tokio::process supervision — crash detection, auto-restart, graceful degradation
- Features: diagnostics, hover, go-to-definition, find references, formatting
- Merge LSP semantic tokens with Tree-sitter syntax tokens (semantic takes priority)

### 9E. BoltFFI for Hot Paths
- UniFFI for coarse-grained events (file open, config change)
- BoltFFI or manual C FFI for 120fps hot paths (keystrokes, cursor, syntax tokens)
- Zero-copy via Apple Silicon UMA — Swift reads Rust memory addresses directly
- **Benchmark target:** <16ms keystroke-to-frame, <2ms AST update

### 9F. AI-Native Code Context
- Tree-sitter semantic excerpt generation — don't send entire files to LLM
- Ascend syntax tree to extract function + enclosing class + dependencies
- Workspace-aware RAG: sqlite-vec retrieves code chunks + notes, cross-referenced with LSP symbols
- Merkle-tree hashing for incremental re-indexing (only embed diffs)

---

## TIER 10: CONTROL PLANE ARCHITECTURE (from Deep Research Report)

### 10A. Harness as GUI Control Plane
The app must become the **GUI control plane** for the agent runtime, not "another chat client."
- Expose all Hermes/OpenClaw primitives as first-class UI objects:
  - Profiles/Agents: picker, creation, import/export, isolated workspaces
  - Sessions: list, search, compaction status, new/reset
  - Skills: install/manage, "skill used" traces, availability per session
  - Tools & Approvals: execution stream, approval UI, hardening signals
  - Schedulers: cron timeline, next-run times, run logs, outputs
  - Provider Routing: active provider, fallback chain, failover events
  - Gateways/Channels: connect/disconnect, pairing, webhook toggles

### 10B. MCP as the Spine
- Hermes (server) ⇄ Harness (client) via MCP
- Harness runs its own MCP servers: vault filesystem, graph, notes, code artifacts
- Agent runtime accesses UI-managed resources through MCP protocol
- Avoids bespoke API that duplicates ecosystem convergence

### 10C. Automated Install + Doctor + Update
- First-run bootstrap: embedded runtime + dependency install
- "Doctor" command: runtime health, dependency presence, credential sanity, tool-sandbox check
- "Update" flow: pull latest + reinstall (like Hermes's `hermes update`)
- Sandbox choices (local vs Docker) visible and selectable in UI

### 10D. Paperclip "Company OS" Mode
- Optional mode inside Harness for managing:
  - Org charts, budgets, governance, heartbeats, role/persona configs, audit logs
- "If OpenClaw is an employee, Paperclip is the company"
- Treat as a plugin/mode, not core — MIT licensed, attribution required

---

## TIER 11: ZERO-COPY & PERFORMANCE ENGINEERING (from Typestate Report)

### 11A. Noncopyable FFI Handles
- Wrap all UniFFI handles in Swift 6 `~Copyable` structs
- `deinit` calls Rust release function — RAII pattern, zero leaks
- `consuming func` for state transitions — compile-time enforcement
- **Already deferred to Phase 13** — but should be reconsidered for critical paths

### 11B. Typestate for Critical Protocols
- MLX pipeline: `Uninitialized` → `Ready` → `InferenceInProgress` (noncopyable)
- PTY handle: `Opened` → `Closed` (Rust PhantomData)
- FoundationModels session: `Active` → `Recycling` → `Closed`
- **Already deferred to Phase 11** — assess after Phases 1-9 stable

### 11C. Capability-State Tokens
- `ComputeCapability` token required for inference
- Low-power state → only issues `QuantizedInferenceCapability`
- Prevents operations that would fail or drain battery
- Wire into PowerGuard mode transitions

### 11D. Zero-Copy IPC Patterns
- Apache Arrow for shared-memory interchange (columnar, relocatable)
- FlatBuffers for zero-parse structured messages
- Append-only mmap logs for transcripts, tool traces, graph events
- UI reads via offsets/slices — only materialize for display

### 11E. Lock-Free Circuit Breaker on Apple Silicon
- AtomicU64 bit-packed ring with popcount health check
- `#[repr(align(128))]` for 128-byte L1 cache lines
- ManagedBuffer for co-located header + element storage
- **Already deferred to Phase 12** — implement when profiling justifies

### 11F. Performance Benchmark Targets
| Metric | Target |
|--------|--------|
| Typing latency (keyDown → frame swap) | <16ms |
| File open (100K lines) | <150ms |
| Idle memory (workspace open) | <150MB |
| AST update (single char) | <2ms |
| Tantivy search (10K files) | <10ms |
| LSP crash recovery | <3s |

---

## TIER 12: FROM ORIGINAL RESEARCH VISION (North Star + Time-Aware + Cognitive macOS)

### 12A. Spaced Repetition Integration
- Notes flagged for review surface on FSRS schedule (Free Spaced Repetition Scheduler)
- Graph nodes pulse when it's time to revisit
- Decay strength resets on access — the more you use a note, the longer it lives
- Already have Ebbinghaus decay in memory_decay.rs — needs UI surface

### 12B. Concept Evolution Timeline
- Horizontal timeline view: how a concept grew across notes over months
- Each point = a note that mentioned or evolved the concept
- Color = sentiment/confidence shift
- Click any point → see the note at that moment in time

### 12C. Friction-Aware Writing
- FrictionMonitorService already exists in code
- Detect when user is struggling: long pauses, deletions, cursor jumping
- Offer contextual help: "Having trouble? Here are related notes that might help"
- Or silently trigger Contextual Shadows with broader semantic radius

### 12D. Cross-App Knowledge Capture (from Cognitive macOS research)
- ScreenCaptureKit + AXorcist already built
- When user reads a paper in Preview or a webpage in Safari, detect key highlights
- Offer to capture highlighted text as a vault node
- Auto-link to existing related notes via InstantRecall
- CaptureEnabled flag already in EpistemosConfig

### 12E. Collaborative Graph Exploration (future — requires sync)
- Share a read-only view of your knowledge graph with collaborators
- They see your constellation but can't edit
- Can suggest connections ("your note on X is related to Y")
- Deferred until sync infrastructure exists

### 12F. Daily Journal with Graph Context
- Logseq's killer feature adapted for Epistemos
- Daily note auto-created with: today's Contextual Shadows, vault health summary, pending reviews
- Graph view filters to show only today's activity
- Links back to yesterday's journal for continuity

---

## RESEARCH ITEMS (Need Investigation Before Building)

| ID | Topic | Blocker For |
|----|-------|-------------|
| R2 | CoreML ANE dual-brain path | Tier 5 sub-agents |
| R3 | Dual-model memory budget | Tier 5 concurrent agents |
| R10 | Cartesia Metal kernels for Mamba-2 | Custom model training |
| R14 | LoRA on Mamba-2 via MLX | Knowledge Fusion |
| R17 | SMAppService App Store distribution | Mac App Store version |
| NEW | OpenClaw VLM agent loop analysis | Tier 2 coding, Tier 5 sub-agents |
| NEW | Hermes v0.6.0 profiles architecture | Tier 1 multi-instance |
| NEW | Docker-in-app feasibility | Tier 5 isolation |
| NEW | BoltFFI vs UniFFI hot-path benchmarks | Tier 9 code editor |
| NEW | CoreText custom NSView patterns (Nova, CodeEdit) | Tier 9 code editor |
| NEW | Rope data structure evaluation (ropey vs custom) | Tier 9 text storage |
| NEW | Apache Arrow / FlatBuffers for zero-copy IPC | Tier 11 performance |
| NEW | Paperclip integration architecture | Tier 10 company OS mode |
| NEW | OpenCode coding patterns analysis | Tier 2 coding features |

---

## EXECUTION ORDER (Recommended)

```
PHASE A — STABILITY + PROVIDER OVERHAUL:
  0B ResearchPause fix — ✅ DONE (Codex: bc3266ee)
  0C EmbeddingService hang — verify if resolved
  -1A Single active provider model (replace multi-provider selector)
  -1B OpenAI OAuth sign-in (zero API keys, default path)
  -1D Google OAuth sign-in
  -1E Anthropic streamlined API key flow
  -1F Dynamic mode selector (modes appear/disappear per model capability)
  -1C Provider-native controls (thinking toggles, extended thinking, web search, grounding)
  -1H Hermes agent OAuth passthrough (tokens flow to subprocess as env vars)
  -1I Default fallback chain (cloud → local → toast)
  (0A Notarization + Sparkle DEFERRED — Phase H)

PHASE B — GRAPH-FIRST APP (The defining experience):
  3-PRIME Immersive graph as default landing (hologram overlay = home)
  3-SHADOW Contextual Shadows (semantic nodes glow as you type)
  3A Black & white theme with glow
  3B Living graph animation (slow drift)
  3C Nested perspective layers (cinematic depth into folders)

PHASE C — AGENT PARITY (Make it feel like Hermes/OpenClaw):
  1A Merge Hermes v0.6.0
  10A Build control plane UI (profiles, sessions, tools, cron, providers)
  1D Restyle agent window (Xcode-inspired live execution view)
  10C Automated install + doctor + update flow
  1B Multi-instance agent profiles
  1C Fallback provider chains
  1E Skills system Swift integration

PHASE D — KNOWLEDGE BRICK (The one sidebar that IS the app):
  4-PRIME Knowledge Brick sidebar (replaces notes sidebar entirely)
  4-SETTINGS Inline settings panel (kill separate settings window)
  8C-6  Command bar (Cmd+K) — teleport to anything, including settings
  8C-9  Global hotkey (Opt+Space) — system-wide command bar overlay
  2A    Code streaming to notes
  4B    Coworker agent section

PHASE E — CODE EDITOR (V2 — after core is stable):
  9A Custom CoreText code surface
  9B Rust Rope text storage
  9C Tree-sitter incremental parsing
  9D LSP supervisor in Rust
  9E BoltFFI for hot paths
  9F AI-native code context

PHASE F — MULTI-AGENT & COMMUNICATION:
  5A Sub-agent architecture
  5B Agent personas (JSON profiles)
  5C Agent self-development (autonomous research pipeline)
  5D Wake-up summary
  6A iMessage integration
  6B Telegram webhook
  6C Agent email
  10D Paperclip "company OS" mode

PHASE G — PERFORMANCE HARDENING:
  7A Stream composition pipeline
  7B Auth profile rotation
  10B MCP as spine (standardize on MCP for all IPC)
  11A-F Zero-copy, typestate, capability tokens
  Phases 10-13 from MASTER_HARDENING_AND_HARNESS_PLAN

PHASE H — RELEASE PREP (After features are complete):
  0A Notarization + Sparkle auto-update
  Release preflight, DMG packaging, legal docs
  Fresh-machine verification

DEFERRED (Research-blocked):
  8A-8B Business features
  MOHAWK custom model training (RunPod funding + R10/R14 research)
  Mamba Metal kernels (Cartesia Edge or MLX Mamba support)
  CoreML ANE dual-brain (R2/R3 research)
```
