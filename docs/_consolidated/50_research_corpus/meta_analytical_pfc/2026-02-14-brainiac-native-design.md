# Lucid — macOS App Design Document

> **Lucid** by Brainiac · A native macOS research reasoning engine.
> Full SwiftUI + Swift backend rebuild of the brainiac-2.0 TypeScript app.
> Target: macOS App Store (macOS 26+). Built via a Claude Code conversion skill.
> Design language: **Material You meets Liquid Glass** — vibrant, not just translucent.

---

## 0. Name — DECIDED

**App Name:** Lucid
**Brand Name:** Brainiac
**Bundle ID:** `com.brainiac.lucid`
**Tagline:** "Get lucid." / "Research, clarified."

**Marketing format:** *Lucid* by Brainiac

### Trademark Notes

**"Lucid" — Moderate risk:**
Lucid Software Inc. (makers of Lucidchart/Lucidspark) holds a USPTO trademark for "LUCID" in software/SaaS (TM #88808001). However, their products are diagramming/collaboration tools — not research reasoning engines. The overlap is in the broad "software" category, not in function. A trademark attorney should evaluate whether "Lucid" for a macOS research app conflicts with their registration. Mitigations: the full brand is "Lucid by Brainiac" and the bundle ID uses `com.brainiac.lucid`.

**"Brainiac" (brand) — Low-moderate risk:**
Multiple companies use "Brainiac" (Brainiac Global Solutions, Brainiac Technologies Inc., Brainiac IP Solutions) but none holds an exclusive software trademark in the research/AI space. Less crowded than "Lucid" for the specific product category.

**Previous name:** blickandmorty (user's existing brand — could be used as publisher name if trademark issues arise with Brainiac)

---

## 1. Vision

This app is a **meta-analytical reasoning engine** — a research writing hub where you never need another app. It combines deep chat-based reasoning, a block-based notes system, autonomous research agents, and an immersive writing environment into a single, minimal, native macOS experience.

**Three words for the UI: Light. Spacious. Quiet.**

**Three words for the UX: It. Just. Works.**

---

## 2. Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform | macOS 26+ (App Store) | Native distribution, Keychain, iCloud, windowing, Liquid Glass |
| Language | Swift + SwiftUI | Truly native. Not Electron, not Tauri, not WKWebView |
| Backend | Swift (new) | TypeScript codebase as reference spec, not ported |
| Build method | Claude Code skill (`brainiac-native`) | Reproducible, phased, context-safe across sessions |
| Database | GRDB.swift (SQLite) | Best Swift SQLite wrapper, WAL mode, migrations |
| State | @Observable + @Environment | Native SwiftUI reactivity, replaces Zustand |
| AI SDK | Direct HTTP (URLSession) + Foundation Models | URLSession for external LLMs; Apple's Foundation Models framework for on-device tasks (summarization, entity extraction) — avoids 5.1.2(i) disclosure for simple operations |
| LLM access | API + Local (Ollama) + On-Device (Foundation Models) | User chooses per task. On-device for light tasks, external for deep reasoning |
| Audio | AVFoundation | Native macOS audio for ambience + frequency tones |
| Windowing | SwiftUI WindowGroup | Native multi-window, any panel detaches |
| Sync | iCloud Drive folder or local folder | No custom backend, vault is a folder of .md + .db |
| Agent FS access | Security-Scoped Bookmarks | Full file system via user-granted folder access |

---

## 3. Feature Set

### F1: Ambience Engine
- Each of the 4 themes pairs with an ambient audio track:
  - **Pitch White** → Silence or minimal white noise (matches the zero-personality aesthetic)
  - **Sunny** → Warm jazz, upbeat instrumental (cheerful energy)
  - **Sunset** → Lo-fi ambient, nostalgic plugg, warm pads (cozy writing mood)
  - **OLED** → Deep space synth, dark ambient (cosmic late-night)
- User can override: pick any track regardless of theme, or silence
- Crossfade on theme switch (2s transition)
- Gapless looping via AVAudioPlayer
- Volume: system + app slider
- Respects macOS Focus modes / Do Not Disturb

### F2: Deep Writer Mode
Two sub-modes within the Writer feature:

**Library Mode (Ulysses-style):**
- Three-pane: Groups → Sheets → Editor
- Markdown-first, plain text .md files in the vault
- Word count, reading time in status bar
- Drag-and-drop sheet organization

**Focus Mode (iA Writer-style):**
- Active paragraph highlighted, rest at 30% opacity
- Typewriter scrolling (active line at vertical center)
- Zero UI chrome — just text + cursor + ambience
- Esc to exit focus mode

Both modes read/write vault files — research notes and writing coexist.

### F3: Agent System
Background autonomous agents that research, write, synthesize, or analyze.

**Architecture:**
```
AgentService (Swift Actor)
├── AgentQueue — serial lifecycle management
├── Agent — individual task runner
│   ├── type: research | write | synthesize | analyze
│   ├── llmProvider: .api(provider) | .local(ollama)
│   ├── tools: [.webBrowse, .fileRead, .fileWrite, .noteCreate]
│   ├── status: .queued | .running | .paused | .completed | .failed
│   └── output: [AgentArtifact]
├── WebBrowseCapability — URLSession + HTML→text
├── FileCapability — Security-scoped FS access
└── NoteCapability — Direct vault write via GRDB
```

**Flow:** New Agent → pick type → natural language instruction → pick LLM → runs in background → results appear as notes/files.

LLM backends:
- API: Anthropic (Claude), OpenAI (GPT), Google (Gemini)
- Local: Ollama at localhost:11434

### F4: Modular Windowing + Native Tab System
Any panel can detach into its own macOS window. Tabs use Apple's native tab system — not custom.

**Tab Model — Native macOS (don't reinvent):**
Lucid uses Apple's built-in window tabbing, the same system Safari and Finder use. This means:

- `NSWindow.allowsAutomaticWindowTabbing = true` — macOS handles tab bar, drag-to-detach, drag-to-merge automatically
- SwiftUI `TabView` with Liquid Glass auto-glassification (macOS 26) — tabs get glass treatment for free
- `tabBarMinimizeBehavior(.onScrollDown)` — tab bar minimizes when scrolling content, maximizes on scroll up
- `tabViewBottomAccessory` — word count, writing session timer, or note metadata below tabs
- Native keyboard shortcuts: Cmd+T (new tab), Cmd+Shift+T (reopen), Cmd+W (close tab)
- Drag a tab out → new window. Drag a tab into another window → merge. Zero custom code — macOS does this

**Why native over custom:**
- Free for us to maintain, tested by Apple, accessible out of the box
- Consistent with every other macOS app the user has — zero learning curve
- Liquid Glass auto-applied by the system in macOS 26
- Window tab merging, show/hide tab bar (Cmd+Shift+T), "Move Tab to New Window" — all free

**Window Types:**
```swift
WindowGroup("Chat", id: "chat") { ChatView() }
WindowGroup("Notes", id: "notes") {                  // Has native tab bar
    NotesTabView()
        .tabViewBottomAccessory { WordCountBar() }
}
WindowGroup("Writer", id: "writer") {                 // Has native tab bar
    WriterTabView()
        .tabViewBottomAccessory { WritingSessionBar() }
}
WindowGroup("Agent", id: "agent") { AgentListView() }
WindowGroup("Mini Chat", id: "mini-chat") { MiniChatView() }
WindowGroup("Research", id: "research") { ResearchLibraryView() }
```

Pop-out button (minimal glass icon, top-right). All windows share AppState via @Observable for live sync. Edit a note in one window → instantly updates in another.

**"It Just Works" Principles:**
- No "Window" menu with 15 options. Just drag tabs — the OS handles it
- No modal dialogs. Ever. Everything is inline or a sheet
- No confirmation dialogs for non-destructive actions
- Undo replaces "Are you sure?" — Cmd+Z always works
- Every action has a keyboard shortcut. Power users never touch the trackpad
- If Apple built it, use it. Don't rebuild what macOS gives you for free

### F5: Breathe Mode (Anti-Burnout)
Mandatory pause intervals. User must select during onboarding: 30m, 1h, or 2h.

**Sequence:**
1. Screen fades to black (3s)
2. Frequency tone begins (432Hz default, adjustable)
3. Typewriter text:
   - "Hey." (2s pause)
   - "Slow down." (2s pause)
   - "Count to 10 with me." (count 1-10)
   - "How do you feel right now?" (5s pause)
   - "Be kind to yourself." (3s pause)
4. Screen fades back in (3s)

- No skip, no escape — the app enforces rest
- Total duration: ~45 seconds
- Ambient music pauses during breathe, resumes after
- Cmd+Shift+B to trigger manually

### F6: iCloud Vault Sync
The vault is a folder of .md files + brainiac.db:

**Mode A — iCloud container:**
```
~/Library/Mobile Documents/iCloud~com.brainiac.app/Documents/
```
macOS handles sync automatically.

**Mode B — User-selected folder:**
Any folder via Security-Scoped Bookmark. If user picks their iCloud Drive folder, sync "just works" via macOS.

SQLite DB lives inside the vault folder. Vault is portable — move it anywhere.

---

## 4. Swift App Architecture

### Project Structure
```
Brainiac/
├── Brainiac.xcodeproj
├── Brainiac/
│   ├── BrainiacApp.swift              # @main, WindowGroup, MenuBarExtra
│   │
│   ├── Models/                         # Data layer
│   │   ├── Schema.swift                # GRDB table definitions
│   │   ├── Chat.swift                  # Chat, Message
│   │   ├── Note.swift                  # Page, Block, Vault
│   │   ├── Concept.swift               # Concept graph
│   │   └── Migrations.swift            # DB version migrations
│   │
│   ├── Services/                       # Business logic
│   │   ├── LLMService.swift            # API + Ollama LLM client
│   │   ├── AgentService.swift          # Agent orchestration
│   │   ├── PipelineService.swift       # Reasoning pipeline
│   │   ├── SOARService.swift           # Self-optimizing reasoning
│   │   ├── ResearchService.swift       # Research library + web
│   │   ├── AmbienceService.swift       # Audio engine
│   │   ├── BreatheService.swift        # Pause timer + meditation
│   │   ├── SyncService.swift           # iCloud / local sync
│   │   └── FileSystemService.swift     # Security-scoped access
│   │
│   ├── State/                          # @Observable state
│   │   ├── AppState.swift              # Root observable
│   │   ├── ChatState.swift             # Messages, streaming
│   │   ├── NotesState.swift            # Vault, pages, blocks
│   │   ├── InferenceState.swift        # Mode, keys (Keychain)
│   │   ├── AgentState.swift            # Running agents
│   │   └── UIState.swift               # Theme, sidebar, panels
│   │
│   ├── Views/                          # SwiftUI views
│   │   ├── Shell/                      # AppShell, Sidebar, TopBar
│   │   ├── Chat/                       # ChatView, MessageBubble, ChatInput
│   │   ├── Writer/                     # WriterView, ParagraphFocus, Library
│   │   ├── Notes/                      # NotesView, BlockEditor, Sidebar
│   │   ├── Agents/                     # AgentList, AgentDetail, NewAgent
│   │   ├── Breathe/                    # BreatheOverlay
│   │   ├── Settings/                   # SettingsView (native)
│   │   └── Shared/                     # GlassButton, GlassPanel, GlassToolbar, TypewriterText
│   │
│   ├── Theme/
│   │   ├── BrainiacTheme.swift         # Colors, typography, spacing
│   │   ├── Ambience.swift              # Theme → track mapping
│   │   └── MotionConfig.swift          # Spring presets
│   │
│   └── Resources/
│       ├── Audio/                      # Ambient loops (m4a)
│       ├── Fonts/                      # Custom typefaces
│       └── Assets.xcassets             # App icon, colors
│
├── BrainiacTests/
└── scripts/                            # Build, sign, notarize
```

### TypeScript → Swift Mapping

| TypeScript | Swift Equivalent |
|-----------|-----------------|
| Zustand store (13 slices) | @Observable model objects in @Environment |
| Event bus (emit/on) | NotificationCenter or Combine publishers |
| React components (.tsx) | SwiftUI Views (.swift) |
| API routes (app/api/) | Direct function calls on Services |
| Framer Motion | SwiftUI .animation(), .matchedGeometryEffect, .glassEffectID() |
| better-sqlite3 | GRDB.swift |
| Drizzle ORM | GRDB record types + migrations |
| localStorage | UserDefaults (non-sensitive), Keychain (API keys) |
| CSS Tailwind | SwiftUI modifiers + .glassEffect() + BrainiacTheme |
| next-themes (6 themes) | @AppStorage("theme") + system appearance (4 themes: Pitch White, Sunny, Sunset, OLED) |
| proxy.ts (edge auth) | Not needed — no server, direct function calls |
| daemon/ | Background Swift Actors with Task scheduling |

### Line Count Target
- Current TypeScript: ~15,000 LOC
- Target Swift: ~8,000-10,000 LOC (~35-40% reduction)
- Reduction from: declarative SwiftUI, no API layer, native state, no bundler config

---

## 5. UI Design Principles — Material You meets Liquid Glass

### Design Language: Material You meets Liquid Glass
The app's aesthetic is **vibrant, not just translucent**. Think Google Material You's bold colors and personalization philosophy expressed through Apple's Liquid Glass translucency system. Where stock Liquid Glass is subtle and neutral, Lucid is colorful and alive — every glass surface carries the personality of your chosen theme. It's not a gray overlay with a blur; it's sky blue, deep purple, warm amber, or true black pulsing through translucent layers. The desktop bleeds through, but with *character*.

Liquid Glass is Apple's translucent, dynamic material system introduced at WWDC 2025.
It provides surfaces that reflect and refract surrounding content, creating depth and focus.
The app uses Liquid Glass as its primary visual language — every panel, toolbar,
button, back arrow, toggle, and interactive surface is glass. Not selectively — universally.

### Visual Language
- **No borders** — spacing and glass surfaces, never lines
- **Glass everywhere** — every button, every back arrow, every toggle, every tab is Liquid Glass. Not just "key surfaces" — literally everything interactive is glass. The app should feel like you're touching light
- **Themed glass tinting** — each of the 4 palettes tints the glass differently. Sunny = warm blue-tinted glass nav bar. Sunset = dark plum glass. Pitch White = near-invisible glass. OLED = sharp-edged glass over starfield. The palette colors show THROUGH the glass, not as solid fills
- **Glass containers** — `GlassEffectContainer(spacing:)` to group related glass elements
- **Small metadata** — .caption size for secondary info, .body for content
- **Generous padding** — 16pt minimum everywhere
- **Monochromatic icons** — SF Symbols, weight: .light or .regular
- **"It just works"** — every interaction is obvious, every gesture is discoverable. No hidden menus, no learning curve. Robust enough that you never think about it

### Liquid Glass API Reference
```swift
// Basic glass panel
.glassEffect()                                    // Default capsule shape
.glassEffect(.regular, in: .rect(cornerRadius: 12)) // Custom shape
.glassEffect(.prominent, in: .capsule)            // Prominent variant

// Interactive elements (buttons, toggles, tabs)
.glassEffect(.regular.interactive(), in: .circle) // Scales, bounces, shimmers on tap
.glassEffect(.prominent.interactive())            // Prominent + interactive

// Grouping glass elements (REQUIRED — glass can't sample other glass)
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 16) {
        ForEach(tools) { tool in
            ToolButton(tool: tool)
                .glassEffect(.regular.interactive(), in: .circle)
        }
    }
    .padding()
}

// Morphing between glass elements
.glassEffectID(selectedTab, in: namespace)         // Fluid morph transitions
```

### Glass Rules
1. Apply `.glassEffect()` **after** layout modifiers (padding, frame)
2. Group related glass elements inside `GlassEffectContainer` — glass can't sample glass
3. Use `.interactive()` on ALL tappable elements — buttons, back arrows, tabs, toggles, everything
4. Keep glass shapes consistent within a screen (all circles, or all rounded rects)
5. Use `.prominent` for the primary action in a group (send button, active tab, selected mode)
6. Container spacing must match internal layout spacing
7. **Tint glass, don't paint it** — color palettes express through glass translucency, not solid backgrounds. A "blue nav bar" in Sunny mode is `.tint(.blue)` on glass, so the desktop shows through with a blue cast. **Pitch White exception:** the nav bar is a solid black pill (the ONLY non-glass element in the whole app) — this extreme contrast defines the theme

### Animation Standards
- **Default spring:** `.spring(duration: 0.35, bounce: 0.15)`
- **Entrance:** `.transition(.opacity.combined(with: .scale(0.97)))`
- **Text changes:** `.contentTransition(.numericText())`
- **View morphing:** `.matchedGeometryEffect(id:in:)` + `.glassEffectID()`
- **Glass transitions:** Use `glassEffectID` for fluid morphing between glass elements
- **No linear easing** — everything uses springs
- **No bounce > 0.3** — subtle, not playful

### Glass Hierarchy — Everything is Glass

**Principle:** If you can see it, it's glass. If you can tap it, it's interactive glass.

| Surface | Glass Variant | Shape | Tint |
|---------|--------------|-------|------|
| **Navigation bar** | `.regular` | `.rect(cornerRadius: 0)` | Theme tint (white in Pitch White, sky blue in Sunny, plum in Sunset, black in OLED). **Pitch White exception:** nav is a solid black pill — the only opaque element |
| **Sidebar** | `.regular` | `.rect(cornerRadius: 0)` | Theme palette surface |
| **Back button** | `.regular.interactive()` | `.circle` | None (inherits from container) |
| **All toolbar buttons** | `.regular.interactive()` | `.circle` | None |
| **Chat input bar** | `.regular` | `.capsule` | None |
| **Send button** | `.prominent.interactive()` | `.circle` | Theme accent |
| **Tab pills** | `.regular.interactive()` | `.capsule` | None |
| **Active tab** | `.prominent.interactive()` | `.capsule` | Theme accent |
| **Tab bar (notes window)** | `.regular` | `.rect(cornerRadius: 0)` | Theme palette surface |
| **Toggle switches** | `.regular.interactive()` | `.capsule` | Theme accent when on |
| **Dropdown menus** | `.regular.interactive()` | `.rect(cornerRadius: 8)` | None |
| **Floating panels** | `.regular` | `.rect(cornerRadius: 16)` | None |
| **Mini-chat window** | `.regular` | `.rect(cornerRadius: 12)` | None |
| **Settings rows** | `.regular.interactive()` | `.rect(cornerRadius: 12)` | None |
| **Consensus level badges** | `.regular.interactive()` | `.capsule` | Level color (green/amber/red/gray) |
| **Research library cards** | `.regular.interactive()` | `.rect(cornerRadius: 12)` | None |
| **Writer format pills** (APA/MLA/Chicago) | `.regular.interactive()` | `.capsule` | None |
| **Active format pill** | `.prominent.interactive()` | `.capsule` | Theme accent |
| **Breathe overlay** | `.prominent` | `.rect(cornerRadius: 0)` | Black (full opacity fade) |
| **Search bubbles** | `.regular.interactive()` | `.capsule` | None |

### Theme Palettes Through Glass — 4 Themes

Two light modes, two dark modes. The extremes (Pitch White, OLED) are for users who want to push contrast. The middles (Sunny, Sunset) are comfortable daily drivers where the desktop bleeds through most.

| Theme | Mode | Nav Glass Tint | Accent | Glass Character | Vibe |
|-------|------|---------------|--------|----------------|------|
| **Pitch White** | Light (extreme) | Pure white, near-transparent glass | Black | Glass is almost invisible — surfaces are barely there. The nav bar is a solid black pill, the only high-contrast element. Everything else is white-on-white with subtle glass edges. Ultra-minimal, "it just works" aesthetic | Clean, surgical, zero personality by design |
| **Sunny** | Light (regular) | Sky blue, warm tinted glass | Amber / warm gold | Glass carries a warm blue cast — like sunlight filtering through a window. Nav bar is sky-blue tinted glass. Chat input is white with soft glass edges. Clouds-through-glass energy. The desktop wallpaper tints warm through every surface | Warm, inviting, cheerful — like sunlight through glass |
| **Sunset** | Dark (regular) | Dark plum / mauve, warm-tinted glass | Rose / warm copper | Glass surfaces carry a deep plum warmth — not cold charcoal. Nav blends into the dark background with warm undertones. Chat input has a dark glass look with visible edges. Purple/mauve personality throughout. The dark desktop shows through with a warm cast | Golden hour, cozy, focused writing mood |
| **OLED** | Dark (extreme) | True black, sharp-edged glass | White / cool silver | Glass sits over an **animated starfield** — white particles drifting slowly on pure black. Glass borders are visible and crisp (subtle white/silver edges). Chat input has a dark glass look with a visible border glow. **This is the only theme where Lucid paints its own backdrop** instead of showing the desktop through glass | Cosmic, late-night, signature Brainiac aesthetic |

**Desktop wallpaper behavior:**
- **Pitch White, Sunny, Sunset:** The desktop wallpaper bleeds through every glass surface — the user's Mac becomes part of the app. Glass tinting gives it the theme's personality.
- **OLED:** Exception. Renders its own animated starfield behind the glass — the same cosmic particle effect from brainiac-2.0. Stars drift slowly behind translucent panels. The desktop does NOT show through. This is Lucid's signature look.

### Reference Apps (feel targets)
- Apple's own macOS 26 apps — Liquid Glass everywhere, the gold standard
- Claude iOS — minimal buttons, spacious, "feels like air"
- Apple Notes (macOS 26) — clean editor, glass sidebar
- ChatGPT — smooth streaming text, light input bar
- Safari tabs — tear-off tabs into new windows, merge windows
- iA Writer — focus mode typography

---

## 6. Conversion Skill Design

### Skill: `brainiac-native`

```
brainiac-native/
├── skill.md                    # Orchestrator entry point
├── phases/
│   ├── 00-analyze.md           # Deep TS→Swift architecture mapping
│   ├── 01-foundation.md        # Xcode project, SPM, GRDB, iCloud
│   ├── 02-engine.md            # Pipeline, SOAR, agents, LLM client
│   ├── 03-core-ui.md           # Shell, nav, theming, modular windows
│   ├── 04-port-features.md     # Chat, Notes, Analytics (existing)
│   ├── 05-new-features.md      # Ambience, Writer, Agents, Breathe
│   └── 06-polish.md            # Animations, a11y, perf, App Store
└── mappings/
    ├── ts-to-swift.md          # Type/pattern reference
    ├── component-map.md        # React→SwiftUI view mapping
    └── api-map.md              # Route→service mapping
```

### Phase Gates
Each phase must pass before the next begins:
- **Compile gate:** `xcodebuild build` succeeds with 0 errors
- **Test gate:** all tests pass
- **Review gate:** agent output is meta-read and verified
- **No cross-phase conflicts:** each phase has explicit file ownership

### Agent Safety Rules (encoded in skill)
1. One agent per isolated task — no overlapping file scopes
2. Every agent task specifies exact target directory
3. Agent output is read and verified before committing
4. Compile check after every agent completes
5. If compile fails, the agent's work is reverted before continuing

---

## 7. Security & App Store Compliance

### Sandboxing
- App Sandbox: ON (required for App Store)
- Network: outgoing (API calls to LLM providers + web browse)
- File system: Security-Scoped Bookmarks for user folders
- Keychain: API keys stored in app-scoped Keychain

### Privacy
- No telemetry, no analytics, no tracking
- All data local or in user's iCloud
- Privacy manifest declares: no data collection
- Camera/microphone: not used

### Entitlements
```xml
com.apple.security.app-sandbox: true
com.apple.security.network.client: true
com.apple.security.files.user-selected.read-write: true
com.apple.security.files.bookmarks.app-scope: true
com.apple.security.keychain-access-groups: [com.brainiac.app]
```

### App Store AI Compliance — Guideline 5.1.2(i) (Nov 2025 update)

Apple's 2026 review process specifically targets third-party AI apps. These are mandatory for approval:

**1. Explicit AI Disclosure Modal**
- On first AI feature use, show a modal naming every provider: "Anthropic (Claude), OpenAI (GPT), Google (Gemini)"
- User taps "I Agree" before any data leaves the device. Cannot be buried in general ToS

**2. Real-Time Model Indicator**
- UI must show which AI model is currently generating a response (tag/icon in chat)
- Already planned: Lucid's chat shows the active model — just make it visible and persistent

**3. Persistent Privacy Controls**
- "AI Settings" menu where user can revoke access to any individual provider at any time
- If revoked, app must immediately stop all calls to that provider and clear active state

**4. Backend Proxy Architecture**
- Apple's static analysis flags hardcoded API keys in the binary — instant rejection
- Lucid stores keys in Keychain (not hardcoded), but the design doc says "Direct HTTP (URLSession)" for LLM calls
- **Decision needed:** either (a) validate that Keychain-stored keys sent via URLSession pass review (keys never in binary), or (b) add an optional proxy mode. Since Lucid is a local-first tool where the user provides their own keys, option (a) is likely compliant — the keys are user-supplied at runtime, not bundled. Monitor reviewer feedback

**5. Foundation Models Framework (iOS/macOS 26)**
- Apple's on-device AI for summarization, entity extraction, translation
- On-device processing does NOT trigger Guideline 5.1.2(i) — no disclosure needed
- **Strategy:** Use Foundation Models for simple tasks (note summarization, concept extraction, entity recognition). Reserve external LLMs for deep reasoning, consensus engine, and research. This reduces disclosure friction and improves offline capability

**6. Guideline 4.2 — "Significant Value" (Anti-Wrapper Rule)**
- Apps that are just a chat UI over GPT/Claude get rejected as "wrapper" apps
- Lucid passes easily: 10-stage reasoning pipeline, consensus engine, writer mode, agent system, research library, concept atlas — this is not a chat wrapper
- The app must feel like a native research tool that happens to use AI, not an AI client with a native skin

**7. UGC Moderation (Guideline 1.2)**
- Chat interfaces are classified alongside social platforms — need content filtering
- Required: "Report" and "Block" mechanisms for AI-generated content
- Add a moderation check (e.g. OpenAI's /v1/moderations endpoint via proxy) for user prompts before sending to LLMs
- Since Lucid is single-user (no social features), this is lightweight — but the review process still checks for it

**8. Trademark Attribution**
- Cannot use "GPT", "Claude", "Gemini" in app name, icon, or marketing headline
- Lucid's name is clean — "Lucid by Brainiac" has no provider trademarks
- In Settings/About, add: *"GPT is a trademark of OpenAI, Inc. Gemini is a trademark of Google LLC. Claude is a trademark of Anthropic PBC. This app is an independent publication and has not been authorized, sponsored, or otherwise approved by these entities."*
- Model names appear only as text labels in settings, never in branding

**9. iOS 26 SDK Deadline: April 28, 2026**
- All new apps must be built with iOS/macOS 26 SDK
- Lucid targets macOS 26+ already — compliant by design

---

## 8. Source Mapping — Where to Pull What

> **Rule:** brainiac-2.0 is the UI/UX reference. pfc-app is the logic reference for features that only exist there. When both have a feature, pull UI from brainiac-2.0 and cross-check logic from pfc-app.

### UI/UX, Polish, Patterns → brainiac-2.0

Everything visual, interactive, and structural comes from brainiac-2.0. This is the mature, polished codebase.

| What | Where in brainiac-2.0 | Why brainiac-2.0 |
|------|----------------------|------------------|
| Tailwind + Shadcn component patterns | `components/` | Clean, consistent design system. pfc-app uses inline styles — don't reference those |
| Notes block editor (SiYuan-style) | `lib/store/slices/notes.ts` (1890 lines), `components/notes/` | Full undo/redo, vaults, concepts, AI typewriter. pfc-app notes are basic |
| Store architecture (13 slices + events) | `lib/store/` | Mature Zustand pattern with event bus. Maps cleanly to @Observable |
| Research library UI | `components/research/`, `app/(shell)/library/` | Existing ResearchPaper, Citation, ResearchBook types |
| Chat streaming + message layers | `components/chat/`, `lib/store/slices/message.ts` | Dual output, streaming text, reasoning accordion |
| Mini-chat (floating assistant) | `components/ui/mini-chat/` | Tabbed mini-chat with thread support |
| Theme system | `lib/themes/`, `next-themes` integration | 4-theme architecture (was 6, simplified) |
| Pipeline visualization | `components/pipeline/` | 10-stage pipeline UI with stage status indicators |
| SOAR engine | `lib/engine/soar/`, `lib/store/slices/soar.ts` | Full self-optimizing reasoning engine |
| Steering system | `lib/engine/steering/` | 3-layer hybrid with contrastive vectors |
| Concept atlas | `components/concepts/`, `lib/store/slices/concepts.ts` | Force-directed graph, concept extraction |
| API utils (SSE, rate limiting) | `lib/api-utils.ts`, `lib/api-middleware.ts` | SSE writer pattern — reference for URLSession SSE implementation |
| Learning system | `lib/store/slices/learning.ts` | Spaced repetition, curriculum generation |

### Logic, Algorithms, Business Rules → pfc-app (v1)

These features were built in pfc-app and never ported to brainiac-2.0. The logic lives only here.

| What | Where in pfc-app | Why pfc-app only |
|------|-----------------|------------------|
| **Consensus engine** (core algorithm) | `lib/engine/research/consensus.ts` (223 lines) | `scoreConsensus()`, `buildConsensusReport()`, `decomposeQuery()`, `extractEvidence()`, `runConsensusPipeline()` — this is the entire consensus pipeline. Does not exist in brainiac-2.0 |
| **Consensus API route** | `app/api/consensus/route.ts` | SSE streaming consensus results. Reference for how consensus pipeline connects to the UI |
| **Consensus report rendering** | `components/chat/consensus-report.tsx` (227 lines) | `ConsensusReportCard` with claim grouping, level colors, "Save to Research Hub" button. Inline styles — convert to SwiftUI |
| **Consensus pill** | `components/chat/consensus-pill.tsx` (35 lines) | Small level badge (strong/moderate/contested/insufficient). Simple but specific color logic |
| **Paper detail view** | `components/research/paper-detail.tsx` (324 lines) | Full paper view with abstract, metadata, BibTeX export, notes, "Run Consensus" button. Cross-references consensus reports for badges. Inline styles |
| **Paper search** | `components/research/paper-search.tsx` (445 lines) | Semantic Scholar API integration, search results rendering, DOI import. The actual search logic |
| **Import paper modal** | `components/research/import-paper-modal.tsx` (396 lines) | DOI/URL import flow with metadata extraction |
| **Citation graph** | `components/research/citation-graph.tsx` (262 lines) | Radial SVG citation visualization. Cut from native v1, but logic is here if reconsidered |
| **Research sidebar** | `components/research/research-sidebar.tsx` (297 lines) | Collection-based paper organization, active paper selection |
| **Research workstation types** | `lib/types/research-workstation.ts` | `SavedPaper`, `ConsensusReport`, `ConsensusClaim`, `EvidenceItem`, `ResearchCollection`, `ConsensusLevel`, `CONSENSUS_LEVELS` |
| **Research store extensions** | `lib/store/slices/research.ts` (239 lines) | `saveConsensusReport`, `savePaper`, `createCollection`, `addPaperToCollection` — actions that wire consensus into the research library |
| **Writer mode toggle + embedded chat** | `components/notes/writer-editor.tsx`, `components/notes/chat-embed-block.tsx` | Writer mode UI concepts. brainiac-2.0 has the better notes editor, but pfc-app has the writer mode toggle pattern |

### Both — Merge the Best

| What | brainiac-2.0 provides | pfc-app provides |
|------|----------------------|------------------|
| **Research papers** | `ResearchPaper` type, `addResearchPaper`, `removeResearchPaper`, `scanNotesForResearch` | Extended `SavedPaper` type with `bibtex`, `openAccessPdfUrl`, `consensusReportId`, `collectionIds` |
| **Notes + Writer** | Full block editor with vaults, concepts, AI typewriter, undo/redo | Writer mode toggle, focus mode, embedded chat blocks |
| **Chat → Research wiring** | Citation extraction from AI responses, auto-add to library | "Run Consensus" button, consensus report save → research library |

### Key Insight for the Native Build

When the `brainiac-native` skill converts a feature to Swift:
1. **Look at brainiac-2.0 first** for how it should look and feel (UI patterns, component structure, state management)
2. **Look at pfc-app** for algorithm logic that only exists there (consensus engine, paper search, import flows)
3. **Never reference pfc-app for styling** — it uses inline styles. All visual patterns come from brainiac-2.0's Tailwind/Shadcn, then convert to SwiftUI + Liquid Glass
4. **Don't delete pfc-app** until the Swift app ships — it's the only source for consensus and research workstation logic

---

## 9. Complete Feature Audit — What Makes It to Swift

> Every feature from pfc-app and brainiac-2.0, evaluated for the native app.
> Philosophy: **Ship 25-30 polished features, not 60 mediocre ones.**

---

### TIER 1: CORE — Must Ship (reimagined in Swift)

These are the identity of Brainiac. Without them it's not the same app.

| # | Feature | Source | Swift Notes |
|---|---------|--------|-------------|
| 1 | **Chat + Streaming** | Both | Full streaming with token-by-token rendering. Native URLSession SSE |
| 2 | **Dual Output (Research + Layman)** | Both | Keep the split view — raw analysis with [DATA]/[MODEL]/[UNCERTAIN] tags + 5-section layman summary. This is what makes Brainiac unique |
| 3 | **10-Stage Pipeline** | Both | Triage → Memory → Routing → Statistical → Causal → Meta-Analysis → Bayesian → Synthesis → Adversarial → Calibration. Core analytical engine |
| 4 | **Notes System (Vault + Blocks)** | brainiac-2.0 | SiYuan-style blocks, vaults, page links, backlinks, undo/redo transactions. Markdown is the default font/format |
| 5 | **Deep Writer Mode** | NEW + pfc-app inspiration | **See detailed spec below (F2 enhanced)** — Ulysses/iA Writer hybrid with APA/MLA auto-formatting |
| 6 | **Research Library** | Both | Papers, citations, ResearchBooks (auto-categorized collections), BibTeX export |
| 7 | **Consensus Engine** | pfc-app | 5-stage pipeline: decompose query → search papers → extract evidence → score consensus → build report. Key differentiator |
| 8 | **Mini Chat** | brainiac-2.0 | Floating assistant with tabs (chat, notes, research, history). In Swift: detachable window |
| 9 | **Settings** | Both | Inference mode (API/Local), API keys (Keychain), model selection, appearance. **Must include:** AI provider disclosure, per-provider revocation toggle, trademark attribution notice (see §7 AI Compliance) |
| 10 | **Onboarding** | Both | First-run setup: pick LLM provider, set breathe interval, vault location. **Must include:** AI consent modal naming all active providers before first LLM call (Guideline 5.1.2(i)) |

### TIER 2: POWER FEATURES — Ship (polished)

These elevate the app from "good" to "this is my daily driver."

| # | Feature | Source | Swift Notes |
|---|---------|--------|-------------|
| 11 | **SOAR Engine** | brainiac-2.0 | Self-Organized Analytical Reasoning: detect learnability → generate curriculum → stepping-stone problems → grounded reward. Keep full engine |
| 12 | **Steering System** | brainiac-2.0 | 3-layer hybrid: contrastive vectors + Bayesian priors + k-NN memory. User thumbs up/down feedback loop |
| 13 | **Concept Atlas** | brainiac-2.0 | Force-directed concept graph. In Swift: use SpriteKit or Canvas for smooth 60fps |
| 14 | **Thinking Controls** | brainiac-2.0 | Play/pause (local only), stop, reroute (focus/explore/challenge/synthesize/simplify). Show `<think>` tag content in collapsible accordion |
| 15 | **TruthBot** | brainiac-2.0 | Independent truth assessment: overallTruthLikelihood, weaknesses, blind spots, improvements |
| 16 | **Live Controls** | brainiac-2.0 | Real-time sliders for focus depth, temperature scale, complexity bias, Bayesian prior strength. Local mode only for full control |
| 17 | **Concept Extraction** | brainiac-2.0 | Auto-extract concepts from notes (headings, bold terms, [[links]]). Feed into concept atlas |
| 18 | **Citation Search** | brainiac-2.0 | Regex + LLM citation extraction from AI responses → auto-add to research library. Semantic Scholar API integration |
| 19 | **Paper Search + DOI Import** | pfc-app | Search papers by keyword, import via DOI. Semantic Scholar backend |
| 20 | **Note AI (Typewriter Mode)** | brainiac-2.0 | AI writes directly into note blocks, token-by-token, with undo support |

### TIER 3: NATIVE-ONLY FEATURES — New for Swift

These don't exist in either web app and are what make native worth it.

| # | Feature | Swift Notes |
|---|---------|-------------|
| 21 | **F1: Ambience Engine** | 4 theme-paired audio tracks (Pitch White → silence/minimal, Sunny → warm jazz, Sunset → lo-fi ambient, OLED → deep space synth). AVAudioPlayer, crossfade on theme switch |
| 22 | **F3: Agent System** | Background Swift Actors: research agents, writing agents, synthesis agents. Web browse (URLSession), FS access (Security-Scoped Bookmarks), vault write (GRDB) |
| 23 | **F4: Modular Windowing + Tabs** | Every window has a bottom tab bar. Drag tabs out → new window. Drag tabs in → merge. Safari/Finder model. All windows share @Observable state for live sync |
| 24 | **F5: Breathe Mode** | Mandatory rest intervals. Frequency tone (432Hz). Typewriter text meditation. No skip |
| 25 | **F6: iCloud Vault Sync** | Vault = folder of .md + brainiac.db. iCloud container or user-selected folder |
| 26 | **F7: Liquid Search Bubbles** | LLM-enhanced prompt suggestions as glass pills that morph into chat input |
| 27 | **F8: Consensus Report in Notes** | Consensus reports embed directly into note pages as rich blocks — not just in chat. Tap any claim to see evidence |

---

### ENHANCED WRITER MODE SPEC (F2 Revised)

Writer Mode is a **toggle on the notes page**, not a separate app section.
Notes default to Markdown rendering. Flipping the Writer switch transforms the editor.

**The Switch:**
- Notes toolbar has a toggle: 📝 Notes ↔ ✍️ Writer
- Notes mode = block editor with markdown rendering (existing)
- Writer mode = distraction-free long-form writing environment

**Writer Mode Features:**

| Feature | Inspiration | Description |
|---------|-------------|-------------|
| **Focus Mode** | iA Writer | Active paragraph at full opacity, rest at 30%. Typewriter scrolling (cursor stays at vertical center). Zero chrome |
| **Library Pane** | Ulysses | Three-pane: Groups → Sheets → Editor. All vault .md files. Drag-drop reorder |
| **Academic Formatting** | Essayist, Pages | Toggle between APA, MLA, Chicago, IEEE styles. Auto-formats: title page, headers, margins, citations, bibliography |
| **Word Count Bar** | Ulysses | Bottom status: word count, character count, reading time, paragraph count. Writing session timer |
| **Export Presets** | Pages, Ulysses | One-click export to: PDF (formatted), DOCX, LaTeX, plain .md |
| **Citation Insertion** | Zotero | `@cite{key}` syntax in editor → renders as (Author, Year) or [1] depending on format style. Pulls from Research Library |
| **AI Writing Assistant** | — | Floating button: "Continue writing", "Rephrase selection", "Expand this point", "Add citation for this claim" |
| **Outline View** | Scrivener | Sidebar shows document outline from headings. Click to jump. Drag to reorder sections |

**What Writer Mode is NOT:**
- Not a separate notes format (same vault .md files)
- Not a markdown vs plain text toggle (markdown is always the format)
- Not a rich text editor (it's still markdown, just beautifully rendered)

---

### CUT — Does Not Make It to Swift

These features are either web-specific, redundant with better native alternatives, or not worth the complexity.

| Feature | Source | Reason to Cut |
|---------|--------|---------------|
| **API Routes** | Both | No server — direct Swift function calls |
| **Rate Limiting / Middleware** | brainiac-2.0 | No HTTP endpoints |
| **Daemon (Node.js process)** | brainiac-2.0 | Replaced by Swift Actors (Agent System) |
| **CSS / Tailwind / Framer Motion** | Both | Replaced by SwiftUI + Liquid Glass + native springs |
| **Bundler config** | Both | No Next.js, no PostCSS, no webpack |
| **Pixel Art Mascots** (PixelSun, PixelMoon, PixelBook) | Both | Charming in web, wrong aesthetic for Liquid Glass. Use SF Symbols instead |
| **Animated Wallpapers** (Sunny clouds, Sunset gradient, Cosmic swirl) | Both | Replaced by Liquid Glass translucency — the desktop IS the wallpaper showing through glass. **Exception:** OLED's animated starfield persists as the one theme with a custom backdrop |
| **Canvas Mode** (spatial notes layout) | pfc-app | Too complex for v1, notes + writer is enough. Consider for v2 |
| **Visualizer Page** (D3 charts, time series, correlation matrix) | Both | Analytics overkill for v1. Concept Atlas + Pipeline view is enough |
| **Diagnostics Page** | brainiac-2.0 | Merge essential info into Settings → Debug section |
| **Export Page** (dedicated route) | brainiac-2.0 | Export is a menu action (Cmd+Shift+E), not a page |
| **Docs Page** | brainiac-2.0 | Link to web docs or embed minimal help. Not a full page |
| **Glass Bubble Buttons** | Both | Web-specific glass imitation. Native Liquid Glass is the real thing |
| **Research Mode Bar** (mode toggle in chat) | brainiac-2.0 | Simplify: chat is always research-capable. Mode selection via Cmd+1/2/3 |
| **Cortex Archive** (snapshot/restore full pipeline state) | brainiac-2.0 | Niche power feature. Cut for v1, reconsider for v2 |
| **Steering Lab** (PCA projection, prior stats UI) | brainiac-2.0 | Steering engine runs under the hood. No dedicated lab UI needed — feedback is thumbs up/down |
| **Signal History Charts** | brainiac-2.0 | Too measurement-focused. Trust the pipeline, don't graph it |
| **Concept Mini-Map** | pfc-app | Concept Atlas is enough |
| **Graph View in Notes** | brainiac-2.0 | Concept Atlas page handles this. Notes sidebar doesn't need its own graph |
| **Research Copilot Page** | brainiac-2.0 | Merge into Research Library. Idea generator + novelty check become Agent tasks |
| **Citation Graph (radial SVG)** | pfc-app | Nice visual but low utility. Agent-driven citation search is more useful |
| **Import Paper Modal** (DOI/PDF import dialog) | pfc-app | Simplify: paste a DOI in chat or research library search bar. No modal needed |
| **Research Sidebar** (pfc-app version) | pfc-app | brainiac-2.0's research library is more mature. Use that pattern |
| **Learning Scheduler** (spaced repetition) | brainiac-2.0 | SOAR handles learning. Dedicated scheduler is over-engineering for v1 |
| **localStorage / writeVersioned** | Both | Replaced by GRDB.swift + UserDefaults + Keychain |

---

### FEATURE COUNT SUMMARY

| Category | Count |
|----------|-------|
| Core (Tier 1) | 10 |
| Power Features (Tier 2) | 10 |
| Native-Only (Tier 3) | 7 |
| **Total Features** | **27** |
| Cut | 25+ |

This gives a focused, polished app with the full analytical engine under the hood,
a world-class writing environment, and native-exclusive features that justify the
macOS build. Every feature earns its place.
