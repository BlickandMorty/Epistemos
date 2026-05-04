# Brainiac Native Skill — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the `brainiac-native` Claude Code skill — a multi-phase orchestrator that converts the brainiac-2.0 TypeScript app into a native Swift/SwiftUI macOS App Store app with 7 new features.

**Architecture:** The skill lives at `~/.claude/skills/brainiac-native/` and contains an orchestrator (skill.md), 7 phase files, and 3 mapping reference files. Each phase generates compilable Swift code with verification gates. The skill is designed to be run across multiple sessions — each phase is self-contained.

**Tech Stack:** Claude Code skill (Markdown), referencing Swift/SwiftUI, GRDB.swift, AVFoundation, SpriteKit, SPM, Xcode.

**Reference:** Design doc at `docs/plans/2026-02-14-brainiac-native-design.md`

---

## Task 1: Deep-Analyze TypeScript Codebase for Mapping Documents

Before writing any skill files, we need to produce the three mapping reference documents by thoroughly reading the brainiac-2.0 codebase.

**Files:**
- Read: `brainiac-2.0/lib/db/schema.ts`, `brainiac-2.0/lib/db/queries.ts`, `brainiac-2.0/lib/db/notes-queries.ts`
- Read: `brainiac-2.0/lib/store/slices/*.ts` (all 12 slices)
- Read: `brainiac-2.0/lib/engine/*.ts` (simulate, reflection, arbitration, query-analysis, signal-generation, fallback-generators)
- Read: `brainiac-2.0/lib/engine/soar/*.ts`, `brainiac-2.0/lib/engine/llm/*.ts`, `brainiac-2.0/lib/engine/steering/*.ts`
- Read: `brainiac-2.0/components/**/*.tsx` (all 73 components — first 40 lines each for signature/props)
- Read: `brainiac-2.0/app/api/**/route.ts` (all 9 API routes)
- Read: `brainiac-2.0/hooks/*.ts` (all 6 hooks)
- Read: `brainiac-2.0/daemon/*.ts`
- Create: `~/.claude/skills/brainiac-native/mappings/ts-to-swift.md`
- Create: `~/.claude/skills/brainiac-native/mappings/component-map.md`
- Create: `~/.claude/skills/brainiac-native/mappings/api-map.md`

**Step 1: Create skill directory structure**

```bash
mkdir -p ~/.claude/skills/brainiac-native/mappings
mkdir -p ~/.claude/skills/brainiac-native/phases
```

**Step 2: Dispatch analysis agent for ts-to-swift.md**

Dispatch a `general-purpose` agent to read ALL TypeScript source files in brainiac-2.0 and produce a comprehensive type/pattern mapping document. The agent must:

- Map every TypeScript type, interface, and enum to its Swift equivalent
- Map Zustand slice state shapes to @Observable class properties
- Map Drizzle schema tables to GRDB Record types
- Map branded types (UserId, ChatId, etc.) to Swift typealiases or newtypes
- Map the event bus (emit/on) to NotificationCenter or Combine
- Map async patterns (Promises, generators, SSE) to Swift async/await and AsyncSequence
- Map error handling patterns to Swift Result/throws

Write output to: `~/.claude/skills/brainiac-native/mappings/ts-to-swift.md`

**Step 3: Dispatch analysis agent for component-map.md**

Dispatch a `general-purpose` agent to read ALL React component files and produce a view mapping. The agent must:

- List every .tsx component with its file path, props interface, and line count
- Map each to a SwiftUI View name with expected @State/@Binding/@Environment usage
- Group by feature area (Shell, Chat, Writer, Notes, Agents, etc.)
- Note which components merge (e.g., 3 pixel mascot files → 1 PixelMascots.swift)
- Note which components split (e.g., chat.tsx → ChatView + GreetingTypewriter + ChatHistorySheet)
- Include the god-object decompositions already done in brainiac-2.0

Write output to: `~/.claude/skills/brainiac-native/mappings/component-map.md`

**Step 4: Dispatch analysis agent for api-map.md**

Dispatch a `general-purpose` agent to read ALL API routes and hooks, then produce a service mapping. The agent must:

- List every API route with its HTTP methods, request/response shapes, and purpose
- Map each to a Swift Service method (no API routes in Swift — direct function calls)
- Map streaming patterns (SSE in chat route) to AsyncSequence in Swift
- Map the daemon IPC to Swift Actor method calls
- Map rate-limit middleware to... nothing (no HTTP layer)
- Document which routes become which Service methods

Write output to: `~/.claude/skills/brainiac-native/mappings/api-map.md`

**Step 5: Verify all three mapping files are complete**

Read each file, verify it covers the full codebase. Check:
- ts-to-swift.md has entries for all 12 store slices, all DB tables, all branded types
- component-map.md has entries for all 73+ components
- api-map.md has entries for all 9 API routes + 6 hooks + daemon

**Step 6: Commit**

```bash
cd /Users/jojo/meta-analytical-pfc
git add ~/.claude/skills/brainiac-native/
git commit -m "feat: create brainiac-native skill with TS→Swift mapping documents"
```

---

## Task 2: Write Phase 00 — Analyze

This phase file instructs Claude to deep-read the TypeScript codebase and produce a Swift architecture specification document. It runs BEFORE any code is written.

**Files:**
- Create: `~/.claude/skills/brainiac-native/phases/00-analyze.md`

**Step 1: Write the phase file**

The file must instruct the executor to:

1. Read the 3 mapping documents (ts-to-swift.md, component-map.md, api-map.md)
2. Read the design doc at `docs/plans/2026-02-14-brainiac-native-design.md`
3. Read MEMORY.md for project history and patterns
4. Produce `docs/plans/swift-architecture.md` containing:
   - Complete GRDB schema (Swift code) mapped from Drizzle schema
   - Complete @Observable state model (Swift code) mapped from Zustand slices
   - Complete Service layer API (Swift protocols) mapped from API routes + engine
   - SwiftUI view hierarchy tree with responsibilities
   - Dependency graph (which Service depends on which)
   - File-by-file creation order (what to build first)
5. The architecture spec becomes the single source of truth for all subsequent phases

**Step 2: Verify the phase file is self-contained**

Read the file back. Ensure a fresh Claude session with zero context could execute it by reading only this file + the mapping docs + the design doc.

**Step 3: Commit**

```bash
git add ~/.claude/skills/brainiac-native/phases/00-analyze.md
git commit -m "feat: add Phase 00 (analyze) to brainiac-native skill"
```

---

## Task 3: Write Phase 01 — Foundation

This phase creates the Xcode project, SPM dependencies, data layer, and iCloud sync.

**Files:**
- Create: `~/.claude/skills/brainiac-native/phases/01-foundation.md`

**Step 1: Write the phase file**

The file must instruct the executor to:

1. Create Xcode project via `xcodebuild` or Swift Package Manager:
   - Bundle ID: configurable (default com.brainiac.app)
   - Deployment target: macOS 14.0+
   - Swift 5.10+
2. Add SPM dependencies:
   - GRDB.swift (SQLite)
   - No other external dependencies initially
3. Create `Models/` layer:
   - Schema.swift — GRDB table definitions matching Drizzle schema
   - Chat.swift, Note.swift, Concept.swift — Record types
   - Migrations.swift — version 1 baseline migration
4. Create `Services/SyncService.swift`:
   - iCloud container setup (Mode A)
   - Security-scoped bookmark management (Mode B)
   - Vault folder resolution logic
5. Create `Services/FileSystemService.swift`:
   - NSOpenPanel integration for folder selection
   - Bookmark persistence in UserDefaults
6. Set up entitlements:
   - App Sandbox, network client, file bookmarks, Keychain
7. Create `BrainiacApp.swift` — minimal @main with single WindowGroup
8. **Gate:** `xcodebuild build` must succeed with 0 errors

Include exact Swift code for the GRDB schema, referencing the ts-to-swift.md mapping. Every table, every column, every index.

**Step 2: Commit**

```bash
git add ~/.claude/skills/brainiac-native/phases/01-foundation.md
git commit -m "feat: add Phase 01 (foundation) to brainiac-native skill"
```

---

## Task 4: Write Phase 02 — Engine

This phase ports the reasoning engine, SOAR, LLM client, and agent system to Swift.

**Files:**
- Create: `~/.claude/skills/brainiac-native/phases/02-engine.md`

**Step 1: Write the phase file**

The file must instruct the executor to create:

1. `Services/LLMService.swift` — Swift Actor:
   - Protocol: `LLMProvider` with `func generate(prompt:, system:, options:) async throws -> AsyncStream<String>`
   - `AnthropicProvider` — URLSession POST to api.anthropic.com, SSE parsing
   - `OpenAIProvider` — URLSession POST to api.openai.com, SSE parsing
   - `GoogleProvider` — URLSession POST to generativelanguage.googleapis.com
   - `OllamaProvider` — URLSession POST to localhost:11434
   - Streaming via AsyncStream (replaces SSE EventSource)
   - API key storage via Keychain (not UserDefaults)
2. `Services/PipelineService.swift`:
   - Port the 10-stage pipeline from simulate.ts + query-analysis.ts + signal-generation.ts
   - Each stage is a method, not a class (simpler in Swift)
   - Reference api-map.md for exact stage→method mapping
3. `Services/SOARService.swift`:
   - Port from lib/engine/soar/ — the Self-Optimizing Adaptive Reasoning engine
   - Swift Actors for thread safety (replaces generation counter pattern)
4. `Services/AgentService.swift` — Swift Actor:
   - Agent struct: type, instruction, llmProvider, tools, status, output
   - AgentQueue: serial task management
   - WebBrowseCapability: URLSession + basic HTML→text (strip tags)
   - FileCapability: read/write via security-scoped bookmarks
   - NoteCapability: create/update notes in vault via GRDB
   - Background execution: Swift structured concurrency (Task.detached)
5. `Services/ResearchService.swift`:
   - Port research library types and web search
6. `State/InferenceState.swift`:
   - @Observable class for inference mode, provider selection
   - Keychain wrapper for API key CRUD

**Gate:** `xcodebuild build` must succeed. Write unit tests for LLMService (mock URLSession) and PipelineService (mock LLM).

**Step 2: Commit**

```bash
git add ~/.claude/skills/brainiac-native/phases/02-engine.md
git commit -m "feat: add Phase 02 (engine) to brainiac-native skill"
```

---

## Task 5: Write Phase 03 — Core UI

This phase creates the SwiftUI shell, navigation, theming, and modular windowing.

**Files:**
- Create: `~/.claude/skills/brainiac-native/phases/03-core-ui.md`

**Step 1: Write the phase file**

The file must instruct the executor to create:

1. `Theme/BrainiacTheme.swift`:
   - Color palette: muted pastels, translucent backgrounds
   - Typography: system fonts with custom sizes (title, body, caption, mono)
   - Spacing: 4pt grid (4, 8, 12, 16, 20, 24, 32)
   - Multiple themes (light, dark, warm, cool, etc.) each with ambience track
2. `Theme/MotionConfig.swift`:
   - Default spring: `.spring(duration: 0.35, bounce: 0.15)`
   - Soft spring: `.spring(duration: 0.5, bounce: 0.1)`
   - Quick spring: `.spring(duration: 0.2, bounce: 0.2)`
   - Standard entrance transition
   - Standard matched geometry namespace
3. `Views/Shell/AppShell.swift`:
   - NavigationSplitView with collapsible sidebar
   - Sidebar: minimal icons (SF Symbols, .light weight), active state highlight
   - Content area: the selected view
   - No borders between panes — just subtle background color difference
4. `Views/Shell/Sidebar.swift`:
   - Navigation items: Chat, Writer, Notes, Agents, Concept Atlas, Settings
   - Each item: SF Symbol icon + label, .caption size
   - Active item: subtle background pill, not bold
5. `Views/Shell/TopBar.swift`:
   - Toolbar items: search (triggers liquid bubbles), pop-out button, breathe trigger
6. `BrainiacApp.swift` — expand with:
   - Multiple WindowGroup declarations (Chat, Notes, Writer, Agents, Mini Chat)
   - MenuBarExtra for quick access
   - Scene delegation for window lifecycle
   - AppState injection via .environment()
7. `State/AppState.swift`:
   - Root @Observable that holds references to all sub-states
   - ChatState, NotesState, InferenceState, AgentState, UIState
8. `State/UIState.swift`:
   - Current theme, sidebar visibility, active panel
   - @AppStorage for persistence
9. `Views/Shared/MinimalButton.swift`:
   - Tiny, borderless, subtle hover state
   - .ultraThinMaterial background on hover only
10. `Views/Shared/GlassPanel.swift`:
    - .ultraThinMaterial + .clipShape(RoundedRectangle)
    - Subtle shadow, generous corner radius (12pt)
11. `Views/Shared/TypewriterText.swift`:
    - Animates text reveal character-by-character
    - Configurable speed, cursor blink

**UI Rules (encode in phase file):**
- 16pt minimum padding everywhere
- SF Symbols only, weight .light or .regular
- No Divider() — use spacing
- .ultraThinMaterial for overlays
- Springs only, no linear/easeInOut
- Every interactive element: subtle scale on press (.scaleEffect(configuration.isPressed ? 0.97 : 1.0))

**Gate:** `xcodebuild build` succeeds. App launches, shows sidebar + empty content area.

**Step 2: Commit**

```bash
git add ~/.claude/skills/brainiac-native/phases/03-core-ui.md
git commit -m "feat: add Phase 03 (core UI) to brainiac-native skill"
```

---

## Task 6: Write Phase 04 — Port Features

This phase ports the existing features from TypeScript: Chat, Notes, Concept Atlas, Analytics, Settings, Onboarding.

**Files:**
- Create: `~/.claude/skills/brainiac-native/phases/04-port-features.md`

**Step 1: Write the phase file**

The file must instruct the executor to create (in order):

**4a. Chat:**
- `Views/Chat/ChatView.swift` — message list + input bar
- `Views/Chat/MessageBubble.swift` — single message with markdown rendering
- `Views/Chat/ChatInput.swift` — composer with send button, minimal
- `Views/Chat/StreamingText.swift` — live text animation during LLM response
- `State/ChatState.swift` — messages array, streaming state, active chat
- Wire to PipelineService for query processing
- Reference component-map.md for exact component→view mapping

**4b. Notes:**
- `Views/Notes/NotesView.swift` — split view: sidebar + editor
- `Views/Notes/NotesSidebar.swift` — page tree with groups
- `Views/Notes/BlockEditor.swift` — block-based editor (simplified from 2251→425 line decomposition)
- `State/NotesState.swift` — vault, pages, blocks, active page
- Wire to GRDB for persistence
- Support markdown rendering in blocks

**4c. Concept Atlas:**
- `Views/ConceptAtlas/ConceptAtlasView.swift` — force-directed graph
- Use SpriteKit or Canvas for GPU-accelerated rendering
- Port D3-force simulation to Swift (simple spring physics)
- Nodes = concepts, edges = relationships

**4d. Settings:**
- `Views/Settings/SettingsView.swift` — native Settings window (use Settings scene)
- Sections: Inference, Appearance, Breathe interval, Export
- Keychain integration for API keys
- Theme picker with live preview

**4e. Onboarding:**
- `Views/Onboarding/OnboardingView.swift` — multi-step welcome flow
- Steps: Welcome → Choose LLM mode → Set breathe interval → Choose vault location → Done
- Breathe interval selection is MANDATORY (cannot skip)

**Gate:** All views compile, navigate, and display placeholder/mock data. Chat sends a message through the pipeline and gets a response.

**Step 2: Commit**

```bash
git add ~/.claude/skills/brainiac-native/phases/04-port-features.md
git commit -m "feat: add Phase 04 (port features) to brainiac-native skill"
```

---

## Task 7: Write Phase 05 — New Features

This phase builds all 7 new features: Ambience, Deep Writer, Agents UI, Modular Windowing, Breathe, iCloud Sync, Liquid Search Bubbles.

**Files:**
- Create: `~/.claude/skills/brainiac-native/phases/05-new-features.md`

**Step 1: Write the phase file**

The file must instruct the executor to create:

**5a. Ambience Engine (F1):**
- `Services/AmbienceService.swift` — Swift Actor
  - AVAudioPlayer management
  - Theme→track mapping dictionary
  - Crossfade: dual-player, fade one out while fading other in (2s)
  - Gapless loop: set `numberOfLoops = -1`
  - Volume: bind to slider in settings
  - Pause during Breathe mode, resume after
- `Theme/Ambience.swift` — mapping enum
- Bundle placeholder audio files in Resources/Audio/ (can be replaced later)

**5b. Deep Writer (F2):**
- `Views/Writer/WriterView.swift` — main writer with mode toggle
- `Views/Writer/WriterLibrary.swift` — three-pane Ulysses layout
  - Groups list → Sheets list → Editor
  - Reads/writes .md files in vault
- `Views/Writer/ParagraphFocus.swift` — iA Writer focus mode
  - TextEditor with custom attributed string rendering
  - Active paragraph: full opacity. Others: 0.3 opacity
  - Typewriter scrolling: active line pinned to vertical center
  - Zero chrome: hide toolbar, sidebar, title bar
  - Esc to exit
- Word count, reading time in status bar (computed from text)

**5c. Agent System UI (F3):**
- `Views/Agents/AgentListView.swift` — list of running/completed agents
  - Status pills: queued (gray), running (blue pulse), completed (green), failed (red)
  - Tap to expand → detail view
- `Views/Agents/AgentDetailView.swift` — single agent progress
  - Live log of actions taken
  - Output artifacts (notes created, files written)
  - Cancel button
- `Views/Agents/NewAgentSheet.swift` — create new agent
  - Pick type: research / write / synthesize / analyze
  - Natural language instruction field
  - Pick LLM provider
  - Pick tools to enable
  - Start button
- `State/AgentState.swift` — running agents, completed agents

**5d. Modular Windowing (F4):**
- Update `BrainiacApp.swift` with WindowGroup declarations for each detachable panel
- Add pop-out button to each view's toolbar (tiny SF Symbol)
- `openWindow(id:)` to detach
- All windows share same AppState via @Environment
- Window titles: "Brainiac — Chat", "Brainiac — Notes", etc.

**5e. Breathe Mode (F5):**
- `Services/BreatheService.swift`:
  - Timer that fires at user-selected interval
  - Posts notification when triggered
  - Tracks last breathe time in UserDefaults
- `Views/Breathe/BreatheOverlay.swift`:
  - Full-screen overlay, ZStack over entire app
  - Black background, fades in over 3s
  - TypewriterText sequence (see design doc for exact text + timings)
  - Frequency tone: AVTonePlayerNode or custom oscillator (432Hz)
  - No dismiss button — overlay auto-dismisses after sequence
  - Pauses AmbienceService, resumes after
- Onboarding enforces interval selection (30m / 1h / 2h)
- Cmd+Shift+B keyboard shortcut for manual trigger

**5f. Liquid Search Bubbles (F7):**
- `Views/Chat/LiquidSearchBar.swift`:
  - Custom search bar with fluid animation
  - On text input (debounced 500ms): call LLMService to generate 3-5 enhanced prompts
  - Each suggestion appears as a floating bubble pill
  - Bubble physics: gentle upward float + wobble (SpriteKit particle or custom animation)
  - Tap bubble → replaces input text and submits
  - Bubbles fade out when input changes
- The fluid/liquid animation: use `Canvas` with custom path animation
  - Or `TimelineView` + sine wave displacement
  - Reference: Apple's SF Symbols animations for inspiration

**Gate:** All features compile. Ambience plays audio. Writer shows focus mode. Agent can be created (even if LLM isn't configured, it should show the UI). Breathe overlay triggers. Search bubbles animate.

**Step 2: Commit**

```bash
git add ~/.claude/skills/brainiac-native/phases/05-new-features.md
git commit -m "feat: add Phase 05 (new features) to brainiac-native skill"
```

---

## Task 8: Write Phase 06 — Polish

This phase handles animations, accessibility, performance, and App Store submission prep.

**Files:**
- Create: `~/.claude/skills/brainiac-native/phases/06-polish.md`

**Step 1: Write the phase file**

The file must instruct the executor to:

**6a. Animation Polish:**
- Audit every view transition — ensure springs, no linear
- Add .matchedGeometryEffect for sidebar↔content transitions
- Add .contentTransition(.numericText()) for word counts, timers
- Subtle press effects on all interactive elements
- Entrance animations for lists (staggered, 0.05s delay each)

**6b. Accessibility:**
- VoiceOver labels on all interactive elements
- Dynamic Type support (all text uses system sizes)
- Keyboard navigation for all features
- Reduce Motion: skip animations, use opacity-only transitions
- High Contrast: ensure all text passes WCAG AA

**6c. Performance:**
- Profile with Instruments: Time Profiler, Allocations
- Lazy loading for large lists (LazyVStack)
- Image caching (if any images)
- SQLite query optimization (indexes, batch reads)
- Startup time: target < 1 second to first paint

**6d. App Store Prep:**
- App icon (1024x1024 + all sizes)
- Privacy manifest (PrivacyInfo.xcprivacy)
  - NSPrivacyTracking: false
  - NSPrivacyTrackingDomains: []
  - Declare API reasons for UserDefaults, file timestamp
- Entitlements review — minimal permissions
- Code signing configuration
- Notarization script (scripts/notarize.sh)
- Build number and version management
- App Store Connect metadata preparation guide

**6e. Error Handling:**
- Graceful LLM failures (show inline error, don't crash)
- Network offline handling (queue agent tasks, retry)
- Corrupt DB recovery (backup before migration)
- Keychain access failure fallback

**Gate:** App passes `xcodebuild test`, compiles for release, and can be archived.

**Step 2: Commit**

```bash
git add ~/.claude/skills/brainiac-native/phases/06-polish.md
git commit -m "feat: add Phase 06 (polish) to brainiac-native skill"
```

---

## Task 9: Write the Orchestrator (skill.md)

This is the main entry point — the file Claude reads when you invoke `/brainiac-native`.

**Files:**
- Create: `~/.claude/skills/brainiac-native/skill.md`

**Step 1: Write the skill.md**

The file must contain:

1. **YAML frontmatter:**
   ```yaml
   ---
   name: brainiac-native
   description: >
     Use when building the Brainiac macOS app from the TypeScript reference codebase.
     Triggers: "build native app", "swift conversion", "brainiac native", "macOS app",
     "run phase", "continue build". Orchestrates a 7-phase Swift/SwiftUI rebuild.
   ---
   ```

2. **Overview:** One-paragraph description of what this skill does

3. **Pre-Flight Checklist:**
   - Verify mapping docs exist (ts-to-swift.md, component-map.md, api-map.md)
   - Verify design doc exists
   - Check which phase was last completed (read `docs/plans/swift-build-progress.md`)
   - Resume from next incomplete phase

4. **Phase Execution Protocol:**
   - Read the phase file for the current phase
   - Dispatch agents per the phase instructions
   - After each agent completes: meta-read its output, verify correctness
   - Run compile gate: `xcodebuild build`
   - Run test gate: `xcodebuild test` (if tests exist for this phase)
   - If gates pass: update progress file, commit, move to next phase
   - If gates fail: revert agent's work, report error, stop

5. **Agent Safety Rules:**
   - One agent per isolated task — no overlapping file scopes
   - Every agent task specifies exact target directory: `Brainiac/Brainiac/`
   - Agent output is READ AND VERIFIED before committing
   - Compile check after every agent completes
   - If compile fails, the agent's work is reverted (`git checkout -- <files>`)
   - NEVER allow two agents to modify the same file

6. **Progress Tracking:**
   - Maintain `docs/plans/swift-build-progress.md` with phase completion status
   - Each phase entry: date, status (pending/in-progress/complete/blocked), notes

7. **Phase List (linking to phase files):**
   - Phase 0: Analyze → `phases/00-analyze.md`
   - Phase 1: Foundation → `phases/01-foundation.md`
   - Phase 2: Engine → `phases/02-engine.md`
   - Phase 3: Core UI → `phases/03-core-ui.md`
   - Phase 4: Port Features → `phases/04-port-features.md`
   - Phase 5: New Features → `phases/05-new-features.md`
   - Phase 6: Polish → `phases/06-polish.md`

**Step 2: Read the file back and verify**

Ensure a fresh Claude session could:
- Invoke `/brainiac-native`
- Read skill.md
- Determine current phase from progress file
- Execute the correct phase file
- Verify and commit results

**Step 3: Commit**

```bash
git add ~/.claude/skills/brainiac-native/skill.md
git commit -m "feat: add brainiac-native skill orchestrator"
```

---

## Task 10: Test the Skill (Baseline Verification)

Per the writing-skills TDD protocol, we need to verify the skill works before considering it done.

**Step 1: Dry-run Phase 0**

Invoke the skill and run only Phase 0 (Analyze). This is the safest phase — it only reads code and writes a spec document, no Swift code yet.

Verify:
- The skill correctly reads mapping docs
- The skill produces a complete `docs/plans/swift-architecture.md`
- The architecture spec covers: schema, state, services, views, dependency graph
- The progress file is updated

**Step 2: Review the architecture spec**

Read the output. Check:
- Every GRDB table matches the Drizzle schema
- Every @Observable class matches a Zustand slice
- Every Service method matches an API route or engine function
- The view hierarchy makes sense
- The dependency graph has no cycles

**Step 3: Fix any issues**

If the phase file produced incomplete or incorrect output, update the phase file and re-run.

**Step 4: Commit the verified Phase 0 output**

```bash
git add docs/plans/swift-architecture.md docs/plans/swift-build-progress.md
git commit -m "feat: Phase 0 complete — Swift architecture spec generated"
```

---

## Task 11: Final Review and Design Doc Update

**Step 1: Update the design doc**

Add F7 (Liquid Search Bubbles) to the feature table if not already there. Update any decisions that changed during planning.

**Step 2: Update MEMORY.md**

Add a section documenting:
- The brainiac-native skill exists at `~/.claude/skills/brainiac-native/`
- It has 7 phases (0-6)
- The design doc is at `docs/plans/2026-02-14-brainiac-native-design.md`
- The architecture spec will be at `docs/plans/swift-architecture.md`
- Progress tracking at `docs/plans/swift-build-progress.md`

**Step 3: Commit everything**

```bash
git add -A
git commit -m "docs: finalize brainiac-native skill and update project memory"
```

---

## Execution Order Summary

| Task | What | Depends On |
|------|------|------------|
| 1 | Deep-analyze TS codebase, create 3 mapping docs | Nothing |
| 2 | Write Phase 00 (Analyze) | Task 1 |
| 3 | Write Phase 01 (Foundation) | Task 1 |
| 4 | Write Phase 02 (Engine) | Task 1 |
| 5 | Write Phase 03 (Core UI) | Task 1 |
| 6 | Write Phase 04 (Port Features) | Task 1 |
| 7 | Write Phase 05 (New Features) | Task 1 |
| 8 | Write Phase 06 (Polish) | Task 1 |
| 9 | Write Orchestrator (skill.md) | Tasks 2-8 |
| 10 | Test Phase 0 dry-run | Task 9 |
| 11 | Final review + MEMORY.md update | Task 10 |

**Parallelizable:** Tasks 2-8 can all be written in parallel after Task 1 completes (they only depend on the mapping docs, not each other). Task 9 depends on all phase files existing. Tasks 10-11 are sequential.
