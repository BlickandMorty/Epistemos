# Codex Prompt Chain — Paste One at a Time

> **Index status**: CANONICAL-OPERATIONAL — Paste-ready prompt sequence for Codex with verification cadence (quick checks + full audits per phase).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**How to use:** Paste one prompt. Wait for Codex to finish. Verify. Then paste the next.
**Rule:** Never paste two at once. Each prompt is self-contained.

## VERIFICATION CADENCE

**After every 3rd prompt** within a phase, paste this quick check:

```
Quick check before continuing:
1. Build: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
2. Run the most recent test file you created or modified
3. Launch the app and verify the last 3 changes work visually
4. If anything fails, fix it before moving on. Do not skip.
Report: "Build: PASS/FAIL. Tests: N passed. Visual: OK/issue"
```

**After the LAST prompt in each phase**, paste the full audit (A-9, B-9, C-5, D-4).
The full audit runs: build + all Rust tests + hardening grep + zero-corruption + anti-drift + performance + write to AUDIT_LOG.md.

**Cost:** Quick checks ~500 tokens each. Full audits ~2000 tokens each.
A typical phase of 9 prompts = 3 quick checks + 1 full audit = ~3500 tokens of verification.
That's <2% of the total work tokens. Worth it to prevent 100% rework from drift.

---

## ═══════════════════════════════════════
## PHASE A: PROVIDER OVERHAUL
## ═══════════════════════════════════════

### A-1: Triage Audit (read-only)

```
Read these 4 files. Tell me what each one does and how they route queries between models. Do not change any code.

1. Epistemos/Engine/TriageService.swift
2. Epistemos/State/InferenceState.swift
3. Epistemos/Agent/HermesSubprocessManager.swift
4. Epistemos/Omega/Orchestrator/FallbackChainResolver.swift

For each file answer:
- What models/providers does it know about?
- How does it decide which model to use?
- Does it have fallback logic?
- Are there hardcoded provider assumptions?

Report back. Do not edit anything.
```

### A-2: Single Active Provider

```
The model selector currently shows ALL cloud providers mixed together. Change it to ONE active provider at a time.

1. In Epistemos/State/InferenceState.swift add:
   - enum ActiveCloudProvider: String, CaseIterable, Codable { case openAI, anthropic, google, localOnly }
   - A persisted property: private(set) var activeCloudProvider: ActiveCloudProvider (default .openAI, backed by UserDefaults "epistemos.activeCloudProvider")
   - A method setActiveCloudProvider(_:) that updates it
   - A computed property activeCloudModels that filters CloudTextModelID.allCases to only models matching the active provider

2. Find where LocalModelToolbarMenu in Epistemos/App/RootView.swift renders cloud models. Filter to show only activeCloudModels instead of all cloud models.

3. Local models always visible regardless of active provider.

Rules: @Observable not ObservableObject. API keys in Keychain only.
Build: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
Run: xcodegen generate
```

### A-3: Provider Picker in Settings

```
Add a "Cloud Provider" section to the General settings in Epistemos/Views/Settings/SettingsView.swift. Place it above the existing "Power" section.

1. Picker with segmented or radio style showing: OpenAI (default), Anthropic, Google, Local Only
2. Bind to InferenceState.activeCloudProvider via the setter you created in A-2
3. Below the picker, show auth status per provider:
   - OpenAI selected: button "Sign In with OpenAI" (placeholder action for now — just print("TODO: OAuth"))
   - Anthropic selected: SecureField for API key (reuse the existing API key pattern from the cloud providers section)
   - Google selected: button "Sign In with Google" (placeholder action for now)
   - Local Only: text "No cloud provider. Using on-device models only."
4. Move the existing per-provider API key fields into this section so there's one place for all auth.

Build and verify.
```

### A-4: Dynamic Mode Selector

```
The mode selector (Fast/Thinking/Pro/Agent) currently shows all modes for all models. Change it so modes appear/disappear based on the selected model's capabilities.

1. Add to CloudTextModelID (in InferenceState.swift):
   var supportedOperatingModes: Set<EpistemosOperatingMode> {
       switch self {
       case .openAIGPT54: return [.fast, .thinking, .agent]
       case .openAIGPT54Mini, .openAIGPT54Nano: return [.fast, .agent]
       case .openAIGPT52, .openAIGPT41: return [.fast, .thinking, .agent]
       case .openAIGPT41Mini: return [.fast, .agent]
       // Anthropic
       case .anthropicOpus41, .anthropicSonnet4: return [.fast, .thinking, .agent]
       case .anthropicHaiku35: return [.fast]
       // Google
       case .googleGemini25Pro: return [.fast, .thinking, .agent]
       case .googleGemini25Flash: return [.fast, .agent]
       // Add cases for any other models
       default: return [.fast]
       }
   }

2. Update the availableOperatingModes computed property in InferenceState to intersect with the current model's supportedOperatingModes.

3. When user switches model and current mode is unsupported, auto-switch to .fast.

4. The mode buttons should animate: use .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity))) with .animation(.easeInOut(duration: 0.15)).

Build and verify: switch between models and confirm modes appear/disappear with animation.
```

### A-5: Provider-Native Controls

```
Add provider-specific controls below the mode selector in the chat composer (Epistemos/Views/Chat/ChatInputBar.swift).

These appear ONLY when the relevant provider is active:

1. When OpenAI is active:
   - Toggle: "Web Search" (store as @AppStorage("epistemos.openai.webSearch"))
   - Toggle: "Code Interpreter" (store as @AppStorage("epistemos.openai.codeInterpreter"))

2. When Anthropic is active:
   - Toggle: "Extended Thinking" (store as @AppStorage("epistemos.anthropic.extendedThinking"))
   - Picker: "Thinking Budget" with options: Low (1K), Medium (4K), High (16K), Max
     (store as @AppStorage("epistemos.anthropic.thinkingBudget"))

3. When Google is active:
   - Toggle: "Search Grounding" (store as @AppStorage("epistemos.google.grounding"))

4. When Local is active:
   - Slider: Temperature 0.0-2.0 (existing, just make sure it's visible)
   - Slider: Max Tokens (existing)

5. These controls should appear/disappear with animation when provider changes.

6. Wire toggled values into the actual API calls:
   - Read these values in LLMService.swift / CloudLLMClient.swift where API requests are constructed
   - For Anthropic extended thinking: add the thinking parameter to the messages API request
   - For OpenAI web search: add the web_search tool to the request
   - For Google grounding: add the grounding config to the request

Build and verify.
```

### A-6: Smart Triage

```
Rewrite the triage logic in Epistemos/Engine/TriageService.swift to implement a 4-tier fallback for chat and a separate 4-tier fallback for agents.

CHAT TRIAGE (regular conversations):
1. Active cloud provider (the one selected in Settings)
2. Secondary cloud provider (if user has a second provider configured with valid key/OAuth)
3. Apple Intelligence (if available — check AppleIntelligenceService.checkAvailability())
4. Local MLX routed by complexity:
   - Simple (token count < 50, no code) → smallest available model
   - Medium (< 200 tokens or summary/QA) → Qwen 4B
   - Complex (>= 200 tokens or code/reasoning) → Qwen 9B

AGENT TRIAGE (tool-calling tasks):
1. Active cloud provider (must support tool_use)
2. Secondary cloud provider
3. Local Qwen 9B ONLY (smaller models can't tool-call reliably)
4. Reject: show user "Agent requires cloud or Qwen 9B" with a button navigating to Settings

Apple Intelligence is NEVER used for agents — no tool calling support.

When fallback happens, show a toast: "Switched to [model] — [primary provider] unavailable"
When cloud recovers, show toast but do NOT auto-switch back.

Build and verify with unit tests for each triage tier.
```

### A-7: Firecrawl Settings + OAuth Placeholders

```
Two quick additions:

1. Firecrawl API key field:
   - In the Cloud Provider settings section, add a "Web Tools" subsection below auth
   - SecureField for Firecrawl API key
   - On save: Keychain.save(value, for: "epistemos.firecrawl.apiKey")
   - Help text: "Enables deep web scraping for research. Get a key at firecrawl.dev"
   - Already in HermesSubprocessManager.toolGateKeychainMappings — auto-passes to Hermes

2. Hermes OAuth passthrough:
   - In HermesSubprocessManager.swift, update toolGateKeychainMappings to try OAuth tokens first:
     For OPENAI_API_KEY: check "epistemos.oauth.openai" first, then "epistemos.openai.apiKey"
     For GOOGLE_API_KEY: check "epistemos.oauth.google" first, then "epistemos.google.apiKey"
   - This prepares for when we implement real OAuth — the Keychain keys are ready

Build and verify.
```

### A-8: Substrate Sprint 0 — Architecture Audit

```
Produce docs/ARCHITECTURE_AUDIT.md with these 5 sections. Pure analysis — do not change code.

Section 1 — Identity Types:
Search Epistemos/ for: UUID(), UUID.init, any String used as an entity ID, Int IDs, file paths used as identifiers. List each distinct identity pattern with file:line. Count total distinct patterns.

Section 2 — Observable State Holders:
Search for @StateObject, @ObservedObject, ObservableObject, @Observable. For each, note if it holds canonical state (note content, graph topology, model selection) vs view-local session state (scroll position, popover visibility).

Section 3 — UniFFI Call Sites:
Search for all function calls matching the pattern graph_engine_*, omega_mcp_*, omega_ax_*, epistemos_core_*. Categorize each as HIGH frequency (render loop, physics tick), MEDIUM (user action response), LOW (lifecycle/setup).

Section 4 — Python Invocations:
Search for Process(), references to python, hermes, run_agent. Flag any on @MainActor.

Section 5 — Binary Size:
Run: ls -lh build-rust/*.dylib build-rust/*.a 2>/dev/null
Run: du -sh hermes-agent/
Report sizes.
```

### A-9: Phase A Audit

```
Phase A is complete. Run the post-phase audit:

1. Build: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
2. Rust: cargo test --manifest-path agent_core/Cargo.toml
3. xcodegen generate

4. Hardening grep (run all from docs/HARDENING_VERIFICATION.md, report pass/fail count)

5. Zero-corruption:
   grep -rn 'try?' --include="*.swift" Epistemos/Sync/NoteFileStorage.swift | wc -l  (expect 0)
   grep -rn 'try!\|\.unwrap()' --include="*.swift" Epistemos/ | grep -v Test | wc -l  (expect 0)

6. Anti-drift:
   grep -rn 'ObservableObject' --include="*.swift" Epistemos/ | grep -v test | grep -v comment | wc -l  (expect 0)
   grep -rn 'UserDefaults.*[Aa]pi[Kk]ey' --include="*.swift" | wc -l  (expect 0)

7. Verify: new ActiveCloudProvider persists across launch, mode selector updates on model switch, triage falls back correctly.

Write results to docs/AUDIT_LOG.md. If all pass, Phase A is done.
```

---

## ═══════════════════════════════════════
## PHASE B: GRAPH-FIRST EXPERIENCE
## ═══════════════════════════════════════

### B-1: sRGB Fix + Metallib Precompile

```
Two quick fixes confirmed by 4 independent research reports:

1. sRGB pixel format fix (one line in graph-engine/src/renderer.rs):
   Find where the CAMetalLayer pixel format is set to BGRA8Unorm.
   Change it to BGRA8Unorm_sRGB.
   This fixes dark fringe artifacts on glow halos caused by blending in gamma space.

2. Precompile Metal shaders:
   Currently shaders compile from source strings every launch via new_library_with_source() (150-300ms).
   a. Add a build script that runs: xcrun metal -c shaders.metal -o shaders.air && xcrun metallib shaders.air -o shaders.metallib
   b. In renderer.rs, load via new_library_with_data() from the precompiled .metallib
   c. Remove the AppBootstrap file-lock workaround (it was only needed because of shader compilation races)
   d. If extracting the shader source strings to .metal files is complex, defer step 2 and just do step 1.

Build and verify: graph should look the same but colors are now correct.
cargo test --manifest-path graph-engine/Cargo.toml
```

### B-2: SDF Label Atlas Generation

```
Generate the MTSDF font atlas for graph labels. This is a build-time artifact, not runtime code.

1. Install msdf-atlas-gen (brew install msdf-atlas-gen or build from github.com/Chlumsky/msdf-atlas-gen)

2. Generate the atlas:
   msdf-atlas-gen -font /System/Library/Fonts/SFNS.ttf -type mtsdf -size 32 -pxrange 6 \
     -charset ascii -imageout Epistemos/Resources/sdf_labels.png \
     -json Epistemos/Resources/sdf_labels.json

   If SFNS.ttf isn't accessible, use SF-Pro-Text-Regular.otf from Apple's developer fonts.

3. Commit both files to Epistemos/Resources/
4. Add them to the resources section in project.yml
5. Run xcodegen generate

Do not write shader code yet — just get the atlas committed.
Verify the PNG looks correct (white glyphs on black background with smooth distance fields).
```

### B-3: Label Shader + Render Pipeline

```
Add SDF text label rendering to the graph. Read docs/GRAPH_SDF_LABEL_RESEARCH_PROMPT.md for full context.

1. In graph-engine/src/renderer.rs, add a new const LABEL_SHADER_SOURCE with a Metal fragment shader that:
   - Samples the MTSDF texture (4 channels: RGB = multi-channel SDF, A = true SDF)
   - Uses the alpha channel for blur: smoothstep(edge_min, edge_max, sdf_distance)
   - Takes camera_focus (float2) and zoom_level (float) from uniforms
   - Computes per-fragment: dist_to_focus = distance(node_world_pos, camera_focus)
   - blur_intensity = smoothstep(focus_radius, blur_radius, dist_to_focus)
   - Widens smoothstep boundaries with blur: crisp = (0.45, 0.55), blurred = (0.1, 0.9)
   - Returns float4(text_color, alpha * (1.0 - blur_intensity)) — fades out when fully blurred
   - Early exit when alpha < 0.01 (zero cost for invisible labels)

2. Add LabelUniforms struct: camera_focus (float2), zoom_level (float), text_color (float4)

3. Create the label render pipeline (same pattern as existing node/edge pipelines)

4. In the render loop, after drawing nodes and edges, draw label quads:
   - For each visible node, generate a quad positioned above the node
   - UV coordinates map to the correct glyph in the atlas using the JSON metadata
   - Only generate quads for nodes within the visible viewport

5. The label pass must be instanced (one draw call for all labels, not per-label)

Build, verify: labels should appear when zoomed in, blur when zoomed out.
cargo test --manifest-path graph-engine/Cargo.toml
```

### B-4: Graph Bug Fixes (3-6)

```
Fix the remaining 4 graph architectural bugs (bugs 1-2 were fixed in B-1):

Bug 3 — Link force pipeline bubble:
Read graph-engine/src/simulation.rs. If link/spring forces are computed on CPU while GPU handles N-body, they serialize. Options:
a. Move link forces to a Metal compute shader (best but complex)
b. Overlap CPU link calc with GPU N-body via double-buffered position arrays (easier)
Choose the simpler option. Profile before and after.

Bug 4 — Louvain clustering rebuild:
Find where semantic clustering is triggered. If it rebuilds from scratch on every change, make it incremental (only re-cluster affected communities). If already incremental, skip.

Bug 5 — TBDR glow optimization:
Evaluate whether the current glow/bloom pass exploits Apple Silicon tile memory. If it's a standard Gaussian blur, consider replacing with Dual Kawase blur (cheaper, designed for tile-based GPUs). Only change if profiling shows the glow pass is >1ms.

Bug 6 — Color space blending:
After the B-1 sRGB fix, verify all color uniforms passed to shaders are in linear space. Grep for any hardcoded color values (e.g., float4(1.0, 0.5, 0.0, 1.0)) and verify they're linear, not gamma-encoded.

Profile each fix. Report before/after frame times.
Build: cargo test --manifest-path graph-engine/Cargo.toml
```

### B-5: Three-Stance Model

```
Implement the three-stance app model. Read docs/VISION_BACKLOG.md §3-PRIME.

Stance 1 — Quick (default on launch):
- This is the CURRENT landing page. Keep it as-is. Home greeting + click-to-search. No changes needed.

Stance 2 — Focused:
- This is the CURRENT note editing mode. Keep it as-is. Editor + sidebar. No changes needed.

Stance 3 — Immersive (Cmd+G toggle):
- This already exists as the hologram overlay (HologramOverlay.swift, HologramController.swift).
- Enhancement: when the user taps a note node in the overlay, open the note editor as a floating NSPanel (not inside the hologram view — a separate window).
- The NSPanel should be borderless, floating, draggable, with a close button.
- The graph continues rendering behind the panel.
- Multiple panels can be open (one per tapped node).
- Cmd+G dismisses the overlay and all floating panels.

Implementation:
1. Create Epistemos/Views/Graph/GraphFloatingPanel.swift — an NSPanel subclass
2. In HologramOverlay.swift, handle node tap → create GraphFloatingPanel with NoteDetailWorkspaceView
3. Track open panels in HologramController. Dismiss all on Cmd+G.
4. Panels should use the same glass/material background as existing windows.

Build and verify: Cmd+G opens overlay, tap node opens floating panel, Cmd+G dismisses all.
```

### B-6: Contextual Shadows

```
Implement semantic gravity — related notes drift toward the active editor panel in immersive mode.

Read docs/VISION_BACKLOG.md §3-SHADOW for full spec.

1. In graph-engine/src/simulation.rs, add a shadow_force system:
   - New field per node: shadow_attraction (float, 0.0 = no attraction, 1.0 = max)
   - New field per node: shadow_target_x, shadow_target_y (where to attract toward)
   - In the force tick, if shadow_attraction > 0, apply: force += (target - position) * shadow_attraction * 0.05

2. Add FFI function in graph-engine/src/lib.rs:
   graph_engine_set_shadow_targets(engine, node_ids: *const u32, strengths: *const f32, target_x: f32, target_y: f32, count: u32)

3. In Swift (MetalGraphView.swift or a new file), after each text edit:
   - Debounce 300ms
   - Run the current paragraph through InstantRecall (already exists, <3ms)
   - Get top 5 results with cosine similarity scores
   - Call graph_engine_set_shadow_targets with the matching node IDs and similarity-as-strength
   - When typing stops or topic changes, set all shadow_attractions to 0 (nodes drift back)

4. Shadow nodes should also get a glow boost: brighter opacity = higher similarity

Build and verify: type in a note, related nodes should visually drift closer in the graph overlay.
```

### B-7: Mass-Drag Physics

```
Implement mass-based drag resistance. Read docs/VISION_BACKLOG.md §3-PHYSICS.

1. In graph-engine/src/engine.rs, add mass field per node:
   - mass = 1.0 + (child_count as f32 * 0.5) + (link_count as f32 * 0.2)
   - Expose via FFI: graph_engine_set_node_mass(engine, node_id, mass)

2. During drag interaction:
   - node_displacement = cursor_delta / mass
   - Store the displacement as a "tether" offset

3. On release:
   - Inject impulse: velocity += tether_offset * snap_strength
   - The existing spring/link forces propagate this as a ripple
   - Add velocity clamping: max_velocity = 500.0 (prevent fly-off)

4. In the fragment shader, add per-node blur_radius:
   - blur_radius = |cursor_velocity - node_velocity| * mass * 0.001
   - If blur_radius > 0.5: apply radial blur (Gaussian sample, 3 taps)
   - If blur_radius < 0.5: early exit (zero cost)
   - blur_radius *= 0.85 per frame (decay after release)

5. In Swift, add haptic feedback (NSHapticFeedbackManager.defaultPerformer):
   - On grab: .alignment for light nodes, .levelChange for heavy nodes
   - On release/snap-back: intensity proportional to snap distance

Build and verify: drag a small note (light), drag a folder with many children (heavy, resistant).
cargo test --manifest-path graph-engine/Cargo.toml
```

### B-8: Visual Polish (B&W Theme + Living Animation)

```
Three visual enhancements:

1. Black & White graph theme:
   - Folders: black fill in light mode, white fill in dark mode
   - Shade lightens with nesting depth: depth 0 = solid, depth 1 = 80% opacity, depth 2 = 60%, etc.
   - Notes: keep current color scheme
   - Chats: yellow tint (existing)
   - Ideas: accent color tint
   - ALL nodes still glow (white glow in dark mode, subtle dark glow in light mode)

2. Living animation (slow drift):
   - When the graph is idle (no user interaction for 3 seconds), apply a gentle random force to each node:
     force += random_unit_vector() * 0.1
   - This creates slow, organic drift that makes the graph feel alive
   - The drift force should be very weak — nodes barely move, just enough to notice
   - When user interacts (click, drag, zoom), immediately stop the drift force

3. Nested perspective layers:
   - When user double-clicks a folder node, zoom the camera to center on that folder
   - Scale child nodes to be slightly larger, parent nodes scale down and fade to 30% opacity
   - This creates a depth effect — you're "inside" the folder
   - Double-click empty space or press Escape to zoom back out
   - Animate the transition (300ms ease-in-out)

Build and verify each change individually.
```

### B-9: Phase B Audit

```
Phase B is complete. Run the 8-step audit:

1. Build: xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
2. Rust: cargo test --manifest-path agent_core/Cargo.toml && cargo test --manifest-path graph-engine/Cargo.toml
3. xcodegen generate
4. Hardening grep: run all from docs/HARDENING_VERIFICATION.md
5. Zero-corruption checks
6. Anti-drift checks
7. Performance: verify graph still runs at 120fps with labels enabled, 60fps in eco mode
8. Profile: the label pass should be <0.5ms for 2K visible labels

Write results to docs/AUDIT_LOG.md. Phase B done only if all pass.
```

---

## ═══════════════════════════════════════
## PHASE C: AGENT PARITY
## ═══════════════════════════════════════

### C-1: CodeNano 17-Tool Audit

```
Audit the current Hermes tool set against CodeNano's minimal 17-tool coding agent.

The 17 essential tools: file_read, file_write, file_edit, file_create, directory_list, bash_execute, grep_search, glob_pattern, git_status, git_diff, git_commit, web_fetch, web_search, task_create, task_complete, memory_read, memory_write.

For each:
1. Does Hermes have an equivalent? Check hermes-agent/tools/ directory.
2. If yes, is it working? (Check tool gate — does check_fn pass?)
3. If no, what would be needed to add it?

Report as a table. Do not implement anything yet.
```

### C-2: Hermes v0.6.0 Feature Audit

```
Check if our hermes-agent submodule has the v0.6.0 features. Read the submodule's version or changelog.

Features to check:
1. Profiles (multi-instance isolation) — does profiles/ directory exist?
2. MCP server mode (hermes mcp serve) — does the CLI support this?
3. Fallback provider chains — is fallback_providers in config?
4. Exa search backend — is exa in tools/?
5. Firecrawl integration — is firecrawl in tools/?

If our fork is behind, report what version we're on and what's missing.
Do not merge anything yet — just report.
```

### C-3: Session Lifecycle

```
Implement session lifecycle management in the agent panel.

1. Add to AgentViewModel:
   - var sessions: [AgentSession] (list of past sessions with ID, title, timestamp, status)
   - func createSession() → new session, clears context
   - func resetSession() → clears current session, keeps history
   - func compactSession() → summarize old turns, reduce token count

2. Add AgentSession model:
   struct AgentSession: Identifiable, Codable {
       let id: UUID
       var title: String
       let createdAt: Date
       var lastActiveAt: Date
       var turnCount: Int
       var status: SessionStatus // .active, .completed, .compacted
   }

3. Persist sessions to SQLite (via GRDB or the existing EventStore pattern).

4. In the agent panel UI (Epistemos/Views/AgentSessionPanel.swift), add:
   - Session list (sidebar or dropdown)
   - "New Session" button
   - "Reset" button
   - Session auto-compacts after 50 turns

Build and verify.
```

### C-4: Control Plane UI

```
The agent panel should expose Hermes primitives as first-class UI objects. Read docs/CONTROL_PLANE_RESEARCH.md §10A.

Add these sections to AgentSessionPanel.swift:

1. Active Tools section:
   - List all tools Hermes reports via tools/list MCP call
   - Show name, description, and enabled/disabled toggle
   - Group by category (file, terminal, web, memory, system)

2. Provider Status:
   - Show current inference provider (from InferenceState.activeCloudProvider)
   - Green dot = connected, yellow = fallback active, red = disconnected
   - Show model name and mode (Fast/Thinking/Agent)

3. Cost Tracker:
   - Show session cost in micro-dollars (already tracked by CostTracker)
   - Show per-turn cost breakdown

4. Active Skills:
   - List skills from Hermes admin commands
   - Show skill name, description, enabled status

Keep it clean — collapsible sections, not overwhelming. Match the existing app's visual style.

Build and verify.
```

### C-5: Phase C Audit

```
Phase C is complete. Run the 8-step audit:

1. Build + Rust tests
2. xcodegen generate
3. Hardening grep
4. Zero-corruption
5. Anti-drift
6. Performance
7. Verify: sessions persist across launch, control plane shows live tool list, provider status updates
8. Write to docs/AUDIT_LOG.md
```

---

## ═══════════════════════════════════════
## PHASE D: KNOWLEDGE BRICK
## ═══════════════════════════════════════

### D-1: Tab Infrastructure

```
Replace the current notes sidebar with the Knowledge Brick — a tabbed sidebar with Notes/Chat/Code.

CRITICAL: Use NSHostingView swap for tab isolation. Do NOT use SwiftUI TabView (it keeps all tabs in memory). Read docs/VISION_BACKLOG.md §4-ENGINEERING.

1. Create Epistemos/Views/KnowledgeBrick/KnowledgeBrickContainer.swift:
   - An NSView that contains an NSSegmentedControl at the top (Notes/Chat/Code tabs)
   - A content area below that swaps NSHostingView instances
   - Only the active tab's NSHostingView is in the view hierarchy
   - Each tab's state persists in an @Observable model (not in the view)

2. Create tab content views:
   - KnowledgeBrickNotesTab.swift — current NotesSidebar content moved here
   - KnowledgeBrickChatTab.swift — recent chats list + inline mini chat
   - KnowledgeBrickCodeTab.swift — placeholder for now (just "Code coming soon")

3. Wire keyboard shortcuts: Cmd+1 = Notes, Cmd+2 = Chat, Cmd+3 = Code

4. Default width: 320px. Draggable edge to resize. Collapse to icon strip (48px) with Cmd+\

5. Replace NotesSidebar usage in RootView/ChatView with KnowledgeBrickContainer.

Build and verify: tab switching is instant (<16ms), only active tab is in the view tree.
```

### D-2: Command Bar

```
Build the Cmd+K command bar. It's a floating NSPanel that can teleport anywhere.

1. Create Epistemos/Views/KnowledgeBrick/CommandBarPanel.swift:
   - NSPanel, borderless, floating, centered horizontally
   - TextField at top with "Type anything..." placeholder
   - Results list below, updating as you type

2. Result types:
   - Notes: search by title (use existing SearchIndexService)
   - Chats: search recent chat titles
   - Settings: match against known setting names ("eco mode", "theme", "provider")
   - Commands: "new note", "new chat", "train", "agent: [task]"

3. Behavior:
   - Cmd+K opens the panel (register global shortcut in AppDelegate or SwiftUI .onKeyPress)
   - Arrow keys navigate results
   - Enter selects (navigates to note, opens chat, toggles setting, runs command)
   - Escape dismisses
   - Results appear within 50ms of typing (debounce 100ms, then search)

4. The command bar is the SINGLE input that replaces search, navigation, and quick actions.

Build and verify: Cmd+K opens, type a note name, Enter opens it.
```

### D-3: Inline Settings

```
Kill the separate settings window. Move settings into the Knowledge Brick.

1. Add a gear icon at the bottom of KnowledgeBrickContainer
2. Tapping it expands an inline settings panel (same sidebar, scrollable)
3. Move the most-used settings to quick toggles at the top:
   - Eco mode (PowerGuard toggle)
   - Active provider (segmented picker)
   - Graph quality (performance/cinematic)
   - Theme selector
4. Full settings expand below in collapsible sections
5. Cmd+K → type "eco" → toggle eco mode (wire into command bar from D-2)
6. Remove UtilityWindowManager.show(.settings) calls — settings is now inline

Build and verify: settings accessible from sidebar, Cmd+K can toggle settings by name.
```

### D-4: Phase D Audit

```
Phase D complete. Run the 8-step audit.
Build + Rust tests + xcodegen + hardening grep + zero-corruption + anti-drift + performance + write to AUDIT_LOG.md.
Verify: tab switching <16ms, command bar <50ms, inline settings work, no layout recursion.
```

---

## ═══════════════════════════════════════
## PHASES E-H: LATER PHASES (Summary Prompts)
## ═══════════════════════════════════════

### E-1: Code Editor Foundation

```
Read docs/VISION_BACKLOG.md §TIER 9. Build the code editor foundation:
1. Create a custom NSView backed by CoreText (NOT TextKit 2) for code rendering
2. Support syntax highlighting via Tree-sitter queries passed from Rust
3. Line numbers in the same draw pass
4. Wire into the Knowledge Brick Code tab
Start with read-only code viewing. Editing comes later.
Build and verify.
```

### F-1: Multi-Agent Foundation

```
Read docs/VISION_BACKLOG.md §TIER 5. Build multi-agent support:
1. Multiple Hermes profiles (each with own config, memory, skills)
2. Profile selector in agent panel
3. Agent-to-agent communication via MCP
4. Worker/Reviewer verification pass on agent output
Build and verify.
```

### G-1: Performance Hardening

```
Read docs/VISION_BACKLOG.md §TIER 7 and §TIER 11. Profile the app with Instruments:
1. Identify the top 3 allocation hotspots
2. Identify the top 3 main-thread bottlenecks
3. For each, implement the fix (zero-copy, background actor, or caching)
4. Replace the top 3 measured UniFFI hotspots with #[repr(C)] if profiling justifies
Report before/after measurements for each fix.
```

### I-1: Goose Provider Bridge

```
Read docs/PHASE_I_IMPLEMENTATION_GUIDE.md (800 lines). Start Phase I Week 1:
1. Add goose crate as a Cargo dependency to agent_core (feature-gate: no LanceDB, no V8)
2. Implement TokenStreamCallback (Rust → Swift via UniFFI)
3. Create MetalProvider with bidirectional callback (Rust asks Swift/MLX to generate)
4. Channel registry (DashMap<u64, mpsc::Sender>) for Metal thread → Rust async
5. Mock provider bridge test: tokens show up in SwiftUI
Build: cargo test --manifest-path agent_core/Cargo.toml
```

### I-2: Goose Agent Loop + Builtin Extensions

```
Phase I Week 2-3:
1. Extract Goose Provider trait into agent_core (stream, complete, get_model_config)
2. Implement AnthropicProvider, OpenAIProvider, GoogleProvider using Goose patterns
3. Implement parallel tool dispatch: futures::try_join_all (not sequential)
4. Proactive context compaction (before hitting limit, not after error)
5. Rewrite 17 core tools as Rust builtin extensions (zero IPC)
6. Use rmcp v0.9.1 for external MCP tools
Build and verify all providers stream correctly.
```

### I-3: GEPA + Validation + Python Elimination

```
Phase I Week 4-5:
1. Port GEPA reflective evolution to Rust:
   - trace → LLM diagnosis → targeted mutation → Pareto selection → 5 constraint gates
   - Wire into Living Vault optimization loop
2. Model manager: Qwen3.5 4B router (pinned) + 9B reasoner (cold-loaded)
3. Validate: all 50+ tools working, all providers working, <10ms cold start
4. Delete hermes-agent/ submodule
5. Verify zero Python on a clean machine
Run full audit. Write to AUDIT_LOG.md.
```

## ═══════════════════════════════════════
## HIGH-PRIORITY ADDITIONS (inject into phases as noted)
## ═══════════════════════════════════════

These prompts MUST be delivered. They are numbered outside the main chain to avoid renumbering existing prompts. Each one notes which phase it belongs in. **Treat X-1 (iMessage) and X-2 (OpenClaw) as release-blocking features — they are the moat.**

### ★★★ X-1: iMessage Ingestion (CRITICAL — Phase D, after D-3)

```
Build the iMessage ingestion pipeline. This is a FLAGSHIP feature — Epistemos becomes the only PKM that fuses your conversations with your notes.

SCOPE:
1. Read-only access to ~/Library/Messages/chat.db (SQLite). Requires user to grant Full Disk Access in System Settings → Privacy & Security.
2. On first run: show a gate UI explaining what will be imported and asking for explicit consent. Nothing syncs without user action.
3. Per-conversation opt-in: show a list of all chats (title, last date, message count) with checkboxes. User picks which conversations to ingest.
4. Each selected conversation becomes a Chat-type node in the graph. Each message becomes a Block node linked to the Chat.
5. Incremental sync: track last-ingested-ROWID per chat. Only ingest new messages on subsequent runs.
6. Background sync every 30 minutes when app is active. NEVER sync when app is idle or on battery < 20%.
7. Respect user privacy — all processing local, never sent to any cloud API without explicit per-message opt-in.

FILES:
- Epistemos/Ingestion/iMessageImporter.swift — the SQLite reader + node builder
- Epistemos/Views/Settings/iMessageSettingsSection.swift — gate UI + chat picker
- Epistemos/State/iMessageSyncState.swift — @Observable state holder

SCHEMA NOTES:
- chat.db tables: chat, message, handle, chat_message_join
- Message body is in `text` column; attributedBody (binary plist) holds rich content for newer messages
- `is_from_me` flags direction; `date` is nanoseconds since 2001-01-01
- Group chats: link via chat_message_join

CONSTRAINTS:
- Use GRDB with read-only flag (SQLite.Configuration.readOnly)
- No writes to chat.db EVER
- Attachments stay on disk; only store paths
- If Full Disk Access is not granted, show clear error with "Open System Settings" button

Build and verify: ingest a test conversation, confirm nodes appear in graph, confirm incremental sync skips already-ingested messages.
```

### ★★★ X-2: OpenClaw Screen-Aware Coding Agent (CRITICAL — Phase E, after E-1)

```
Build the screen-aware coding agent — the OpenClaw/Pi pattern. This is THE moat feature. Nobody else has this on-device.

The agent can SEE your screen, read the Xcode AX tree, and take targeted actions. Unlike Cursor (sidebar only) or Copilot (suggestions only), this agent operates across ANY macOS app.

SCOPE:
1. Screen capture via ScreenCaptureKit (already exists in Epistemos/Omega/Vision/ScreenCaptureService.swift) — reuse, don't rebuild.
2. AX tree extraction via AXorcist (already in codebase) — get structured view of focused window.
3. Fusion pass: combine screen image + AX tree into a unified representation. Already exists at Epistemos/Omega/Vision/Screen2AXFusion.swift — extend it.
4. Tool set (new):
   - xcode_build_error_reader: parse Xcode error pane via AX, return structured errors
   - editor_goto_line: click a specific file:line in the focused editor
   - editor_replace_selection: type replacement text
   - xcode_run: click Run button
   - terminal_read_output: read stdout from frontmost Terminal window
   - screen_describe: vision model describes what's on screen
5. Agent loop: uses existing Hermes/Rust agent infrastructure. Adds these tools to the registry (agent_core/src/tools/registry.rs).
6. Trigger: global hotkey Cmd+Shift+K opens an inline prompt "what should I do?" near the cursor. User types, agent acts on the focused window.

SECURITY GATES:
- Screen capture requires Screen Recording permission (already handled by existing ScreenCaptureService)
- AX queries require Accessibility permission
- NEVER act on a screen containing the word "password", "secret", or a visible credit card pattern — hard stop
- User sees a preview of planned actions before any click/type is sent
- Cmd+. cancels mid-action

FILES TO CREATE/EXTEND:
- agent_core/src/tools/screen_aware.rs — new tool module
- Epistemos/Omega/CodingAgent/CodingAgentService.swift — orchestration
- Epistemos/Omega/CodingAgent/ActionPreviewPanel.swift — user confirmation UI
- Epistemos/Omega/CodingAgent/XcodeAXAdapter.swift — Xcode-specific AX queries

CONSTRAINT: This is a CODING agent. Scope it to Xcode, Terminal, and the focused editor. Do NOT build general computer use here.

Build and verify: open Xcode with a syntax error, press Cmd+Shift+K, ask "fix this", confirm the preview, watch the agent navigate to the error and fix it.
```

### ★★ X-3: Model Council (Phase F, after F-1)

```
Build the Model Council — parallel multi-model synthesis. Sends the same prompt to N providers, then synthesizes the answers with a meta-prompt.

UX: In the chat composer, add a "Council" button next to Send. When active, the message is sent to 2-4 configured models simultaneously. Responses stream side-by-side in columns. A synthesis response appears below, generated by the primary model using the others as context.

SCOPE:
1. Add CouncilConfig to InferenceState:
   struct CouncilConfig: Codable {
       var enabled: Bool
       var members: [CloudTextModelID]  // 2-4 models
       var synthesizerModel: CloudTextModelID  // who writes the final answer
       var synthesisPrompt: String  // templated meta-prompt
   }

2. On send, fan out to all members in parallel via TaskGroup. Stream each to its own column.
3. After all members finish, run synthesizer with prompt: "Here are N expert answers. Identify agreements, disagreements, and synthesize the strongest response: [answer 1]... [answer 2]..."
4. Store all responses as linked nodes in the graph (one Chat node, N Block children for each member, 1 synthesis Block).
5. Cost tracker sums all N calls + synthesis.

FILES:
- Epistemos/Council/CouncilOrchestrator.swift
- Epistemos/Views/Chat/CouncilView.swift (side-by-side columns)
- Epistemos/State/CouncilConfig.swift

CONSTRAINT: Local-only mode (only MLX models) must also work — council of 2-3 local model profiles.

Build and verify: send "explain async/await" to council of GPT-5.4 + Claude Opus 4.6 + Gemini 2.5, confirm 3 streams + synthesis.
```

### ★★ X-4: GTD Quick Capture (Phase D, after D-2)

```
Build zero-friction quick capture. Menu bar item + global hotkey = instant node creation without opening the full app.

SCOPE:
1. NSStatusItem in menu bar (always visible when app is running). Icon: small Epistemos glyph.
2. Clicking icon opens a small popover (NSPanel) with a single TextField and tag chips.
3. Global hotkey: Cmd+Shift+N opens the same popover. Register via RegisterEventHotKey or SwiftUI .keyboardShortcut on a hidden window.
4. User types, optionally adds tags (autocomplete from existing tags), presses Enter → new Note node created → popover closes.
5. Popover shows recent captures (last 5) for "just-wrote-that" confirmation.
6. Captured notes land in an "Inbox" folder by default. User can batch-process later.

FILES:
- Epistemos/Capture/QuickCaptureController.swift
- Epistemos/Views/Capture/QuickCapturePopover.swift
- Epistemos/State/CaptureInboxState.swift

CONSTRAINTS:
- Capture must complete in <500ms from hotkey to confirmation
- Works even if main window is closed
- No inference runs on capture — it's purely store-and-forget

Build and verify: hide main window, press Cmd+Shift+N, type "buy groceries", press Enter, reopen app, verify node exists in Inbox.
```

### ★★ X-5: Agent Personas UI (Phase F, after X-3)

```
Surface Hermes profiles as personas with character. Each profile = name + avatar + system-prompt tone + default toolset + color.

SCOPE:
1. Add PersonaConfig model:
   struct PersonaConfig: Identifiable, Codable {
       let id: UUID
       var name: String  // "Researcher", "Critic", "Builder"
       var avatarSymbol: String  // SF Symbol name
       var tint: Color
       var systemPromptAddition: String  // prepended to base system prompt
       var enabledTools: Set<String>  // subset of available tool names
       var hermesProfileName: String  // backing Hermes profile
   }

2. Ship 4 built-in personas: Researcher (web + memory tools, curious tone), Critic (no tools, skeptical tone), Builder (file + bash tools, pragmatic), Coach (no tools, supportive).
3. User can create custom personas.
4. Persona selector in agent panel — pill-style chips at top. Clicking one switches the active persona (= switches Hermes profile).
5. Chat bubbles colored with persona tint so conversation history shows who said what.

FILES:
- Epistemos/Personas/PersonaConfig.swift
- Epistemos/Personas/PersonaRegistry.swift (@Observable)
- Epistemos/Views/Agent/PersonaPicker.swift

Build and verify: switch between Researcher and Critic on the same question, confirm different tone + different tools available.
```

### ★ X-6: Mindfulness Pause Screen (Phase B, after B-8)

```
Add a 60-second mindfulness pause screen. Full-screen breathing overlay with ambient graph animation.

SCOPE:
1. Trigger: Cmd+Shift+P or menu bar "Pause" button.
2. Full-screen NSWindow overlay on the active display. Dark translucent background.
3. Large breathing circle centered on screen — 4s in, 7s hold, 8s out (box breathing).
4. Behind the circle: the graph continues rendering but at 0.1x physics speed, heavily blurred, low opacity.
5. Text below the circle: "Breathe in" / "Hold" / "Breathe out" synced to the circle animation.
6. After 60 seconds, a subtle "Continue" button fades in. Or user presses Escape to exit immediately.
7. Log pauses to a small SQLite table (timestamp, duration) for tracking.

FILES:
- Epistemos/Views/Mindfulness/MindfulnessPauseWindow.swift
- Epistemos/Views/Mindfulness/BreathingCircleView.swift
- Epistemos/State/MindfulnessLogStore.swift

CONSTRAINTS:
- Uses existing graph rendering — does NOT create a second Metal context
- Animation runs at 60fps even if main app is in eco mode
- Dismissible at any time

Build and verify: trigger pause, confirm full-screen overlay, confirm graph animates behind, confirm 60s auto-continue.
```

---

## ═══════════════════════════════════════
## ORIGINAL PHASE H
## ═══════════════════════════════════════

### H-1: Release

```
Phase H — ship it:
1. Add xcrun notarytool to .github/workflows/release.yml
2. Configure Sparkle 2 (SUFeedURL in Info.plist, EdDSA key generation)
3. Run scripts/release/release_preflight.sh
4. Build DMG on a clean machine
5. Verify: app launches, no Python, all features work, code signing valid
6. Submit to notarization service
Ship.
```
