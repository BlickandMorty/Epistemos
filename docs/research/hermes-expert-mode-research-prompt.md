# Research Brief: Hermes Expert Mode for Epistemos

**Status:** Research prompt — hand this to a fresh Claude/Codex session.
**Author:** Epistemos engineering, 2026-04-20.
**Goal:** Produce an actionable integration plan that lets Epistemos launch with a "Hermes Expert Mode" feature in v1.1 without destabilizing v1.
**Format:** Research only. No code edits from this brief. Output should be a separate implementation spec.

---

## 1. Context the research agent needs

Epistemos is a Swift 6 + Rust + Metal macOS knowledge workspace with a
persistent vault, knowledge graph, and an in-process agent (`agent_core`
crate + `MCPBridge.swift`). The native agent handles:

- Standard chat with Apple Intelligence, local MLX models, and cloud providers.
- Simple tool use through MCP: `read_note`, `search_vault`, `append_note`,
  `web_search`, `web_fetch`.
- Multi-turn reasoning within a single session (multi-turn FFI fix shipping
  in v1).

What it does NOT handle well, and what drives the need for Expert Mode:

- Multi-step agentic research with skill composition and plan revision.
- Browser/computer-use automation beyond simple `web_fetch`.
- Long-horizon memory across weeks of user activity.
- Tool ecosystems (GitHub tool, Slack tool, Shell tool, Figma tool, etc.)
- Community-maintained skills that evolve faster than Epistemos can ship them.

Hermes Agent (NousResearch) is the open-source agent system we want to
adopt as the Expert Mode engine. The key NousResearch repos:

- [`NousResearch/Hermes-Function-Calling`](https://github.com/NousResearch/Hermes-Function-Calling) — prompt format + function-calling conventions.
- [`NousResearch/hermes-agent`](https://github.com/NousResearch/hermes-agent) — the agent framework itself.
- [`NousResearch/hermes-agent-self-evolution`](https://github.com/NousResearch/hermes-agent-self-evolution) — auto-skill generation patterns.
- [`NousResearch/atropos`](https://github.com/NousResearch/atropos) — RL trajectory training (probably out of scope for Expert Mode but note for reference).

The integration has been attempted before and failed. Previous attempt
tried to port Hermes Python internals into Swift via FFI. That path is
permanently rejected. The new direction is: run Hermes as a bundled
managed subprocess, talk to it over a local HTTP + SSE transport, wire
it into Epistemos's MCP tool layer, and render its activity in a
dedicated UI surface.

The user explicitly wants:

1. Plug-and-play feel. Minimal engineering surface area.
2. Fool-proof. Not another architecture that needs constant rescue.
3. A button in the UI that sends a prompt to Hermes.
4. A dedicated "Hermes Expert Mode" surface in the UI — different from the
   standard chat, styled as a first-class feature not a hidden mode.
5. macOS notification when a Hermes task completes, that click-routes
   back to the relevant Hermes surface in-app.
6. Auto-update from NousResearch repos — detect upstream updates and
   apply them without user effort (but without dynamic code execution
   that would violate App Store rules).
7. Custom config presets bundled with the app. User signs in once; the
   app pre-configures Hermes with optimal settings for a research-notes
   workspace.
8. Full access to Hermes's plugin/tool ecosystem: browser control,
   computer use, memory tools, shell, etc.

The research output must respect these constraints:

- Direct distribution (notarized, not Mac App Store) for v1.1 Expert
  Mode. MAS build will remain agent-free / chat-only. Do not contort
  the design to satisfy MAS at v1.1; solve the DD path well.
- Swift 6 strict concurrency, actor-isolation correctness, no
  `@MainActor` heavy work.
- Python subprocess must be codesigned, notarized, and declared in the
  app's Privacy manifest.
- No runtime `pip install`, no dynamic code download beyond signed
  updates handled through the update mechanism this brief will define.

## 2. Research questions (the spine of the output)

Answer these in the implementation spec you produce. Each is numbered so
follow-up work can reference them by ID.

### 2.1 — Subprocess lifecycle and bundling

- **RQ-1.** What is the cleanest way to ship a relocatable Python
  runtime inside `Epistemos.app/Contents/Resources/hermes-runtime/`?
  Evaluate `python-build-standalone` (astral-sh/python-build-standalone)
  vs. `pyinstaller`-style frozen bundles vs. a vendored Python
  framework. Prefer python-build-standalone unless there's a concrete
  reason not to. Cite the exact directory structure and signing flags
  required for notarization.
- **RQ-2.** How should the Hermes source and its Python dependency tree
  be pre-frozen into a bundled venv? Produce a build-phase script
  (conceptually, not as final code) that: creates the venv at build
  time on the engineer's machine, installs hermes-agent + its pinned
  dependency graph, flattens into the app bundle, codesigns the result.
- **RQ-3.** How should `HermesSubprocessManager` (Swift class) manage
  lifecycle? Specifically: when to start (lazy on first Expert Mode
  request? at app launch?), when to stop (app termination? explicit
  user disable?), how to detect crashes, how to restart cleanly, and
  how to surface subprocess health to the UI. Include an OTP-style
  supervision analysis — what's the right restart policy?
- **RQ-4.** What's the ideal Python ↔ Swift transport? Evaluate: local
  HTTP on 127.0.0.1 with SSE, UNIX domain sockets, or a Swift Subprocess
  wrapper reading JSON-lines from stdout. Pick one, justify, and specify
  the exact wire protocol (JSON schema for each message type).
- **RQ-5.** How does Hermes discover that Epistemos is its host? I.e.,
  how does the subprocess know which MCP tools it has access to, what
  the user's current vault path is, and what the current model
  configuration is? Specify the bootstrap handshake sequence.

### 2.2 — MCP tool bridge

- **RQ-6.** Epistemos already hosts an MCP server via `MCPBridge.swift`
  and `omega-mcp` Rust crate. How do we expose that server's tool
  catalog to the Hermes subprocess? Specify: which tools should the
  Expert Mode see vs. the Standard Mode? What's the security model —
  does Hermes get the same tool gate as native agents, or a stricter /
  more permissive one?
- **RQ-7.** Hermes has its own native tool protocol (function-calling
  format). How do we map MCP tool schemas into Hermes's expected
  function signatures, and tool results back into MCP result envelopes?
  Write a translation layer spec.
- **RQ-8.** What's the authentication model? If the MCP server is
  listening on localhost, how do we prevent other processes on the
  user's Mac from hitting it? Propose a per-launch shared secret in an
  environment variable.

### 2.3 — UI surface

- **RQ-9.** What does the Hermes Expert Mode UI look like? Produce a
  detailed SwiftUI component tree for a new view:
  `HermesExpertView.swift`. It should render as a first-class feature,
  not a hidden setting. Design direction: a dedicated sidebar entry
  next to Chat and Notes, with a sub-workspace that shows:
  - A prompt input at the top.
  - A running task list on the left (each task = one user prompt →
    Hermes resolution).
  - Active task's live activity on the right: Think → Plan → Act →
    Observe loop, rendered as a structured vertical feed with tool
    cards and a terminal-feel surface for stdout.
  - Persistent access to the task history across app restarts (stored
    in SwiftData as `SDHermesTask` / `SDHermesStep`).
- **RQ-10.** How does the "send to Hermes" flow start? Evaluate:
  (a) a dedicated button in the main chat composer ("Send to Expert"),
  (b) a Cmd+Shift+H global shortcut that opens the Expert prompt modal,
  (c) a right-click action on selected text in any view to hand off to
  Expert Mode. Recommend the combination that gives the plug-and-play
  feel.
- **RQ-11.** Render the "terminal-feel" activity surface with what?
  Evaluate: SwiftTerm (native, fast, ANSI-safe), WKWebView + xterm.js
  (heavier, more flexible), or a custom SwiftUI renderer (lightest,
  least fidelity). Default recommendation: SwiftTerm unless the
  research finds a blocker.
- **RQ-12.** How do we render Hermes's tool calls? Each Hermes tool
  invocation should produce a structured card (not raw JSON). Specify
  cards for at minimum: browser action, shell command, file edit, web
  search, memory write, note append. Each card has: tool name, args
  summary, status chip (Pending/Running/Done/Failed), duration, result
  preview, expandable raw payload.

### 2.4 — macOS notification integration

- **RQ-13.** How do we send a macOS user notification when a Hermes
  task completes? Specify: use `UNUserNotificationCenter`, request
  permissions on first Expert Mode use, include task title and a
  1-line result summary. Do NOT spam — notifications only for tasks
  that took > 20 seconds OR were explicitly marked "notify when done"
  by the user when they submitted.
- **RQ-14.** How does clicking the notification deep-link back into
  the app? Specify: notification userInfo carries `taskID`, app
  `willPresent` handler routes to `HermesExpertView` and selects that
  task. If app is closed, the notification launch opens the app
  directly on the Expert task.
- **RQ-15.** What's the in-app notification equivalent? A "pending
  tasks" dot on the sidebar + a non-intrusive banner when a task
  completes while the user is in another view.

### 2.5 — Auto-update from upstream

- **RQ-16.** How does Expert Mode stay current with NousResearch
  upstream? Evaluate three strategies:
  - **Strategy A** — ship hermes-agent pinned into the bundle; update
    when Epistemos itself ships. Safest, slowest, requires Epistemos
    release for every Hermes bump.
  - **Strategy B** — ship a thin hermes-agent bootstrapper that
    downloads a signed zip from Epistemos's own update server (CDN
    hosting a curated build of hermes-agent + its deps). Medium
    complexity, fast updates, requires Epistemos to maintain release
    engineering for the Python layer.
  - **Strategy C** — direct pull from NousResearch releases with
    signature verification. Fastest upstream sync, highest risk, must
    prove the update payload doesn't constitute "dynamic code
    execution" under Apple guidelines for direct distribution
    (probably fine for DD, definitely not for MAS).
  Recommend one. Detail the update UX: "New Expert Mode version
  available. Review changes." (never auto-install without user OK for
  major version bumps, auto-install patch updates silently).
- **RQ-17.** How do we cryptographically verify an update payload?
  Specify: Ed25519 signature on the update manifest, public key baked
  into the Epistemos binary at build time, signature check before any
  file is written to disk.
- **RQ-18.** What's the rollback path if an update breaks Expert Mode?
  Keep the previous hermes-runtime in
  `~/Library/Application Support/Epistemos/HermesRuntime/<version>/`
  for N versions (propose N=3). On subprocess crash loop, auto-roll
  back one version and notify the user.

### 2.6 — Custom config presets

- **RQ-19.** What does the `hermes.config.yaml` preset look like for a
  research-notes workspace? Produce a complete annotated example
  covering: system prompt / persona, tool allowlist, tool priority
  ordering, memory depth, reasoning effort defaults, vault mount path,
  MCP endpoint, maximum autonomy (read-only vs read-write vs
  computer-use), approval requirements for destructive tools. The
  preset should encode the opinion "this is an app for researchers and
  note-takers — default to reading, asking, summarizing, and writing
  notes; require approval for anything that modifies state beyond the
  vault."
- **RQ-20.** How does the user override the preset? Propose a Settings
  panel path: Settings → Expert Mode → Advanced, with a preset
  dropdown (Research, Coding, Writing, Custom) and a "Raw YAML" editor
  for power users. Keep normal users away from the YAML.
- **RQ-21.** How do we signal to Hermes the user's identity and
  preferences? The preset should include hooks for: user's vault
  shape, most-used models, cloud provider keys (never in the preset
  itself — only references to Keychain items), and writing style
  (pulled from the user's recent notes for anchoring).

### 2.7 — Plugin / tool ecosystem

For each plugin below, answer: how does Hermes integrate it, what does
Epistemos need to bridge, what are the App-Store and DD implications,
and what's the security/permission surface?

- **RQ-22. Browser control.** Hermes has browser-use integrations
  (likely via playwright or similar). What's the cleanest way to
  bundle a headless browser and let Hermes drive it? How do we render
  "Hermes is using the browser" transparently in the UI so the user
  isn't surprised? What permissions (Accessibility, Automation) does
  macOS require?
- **RQ-23. Computer use.** Hermes can drive the desktop via Apple
  Event / AXorcist-style interfaces. Epistemos already has `omega-ax`
  (AX tree) and `DeviceAgentService.swift`. Can Hermes reuse those
  through MCP? If not, what's the bridge? This is the most sensitive
  permission surface; document the consent flow.
- **RQ-24. Memory tools.** Hermes has procedural memory and a
  self-evolution loop. How does its memory interact with Epistemos's
  vault? Proposal: Hermes gets a `vault_memory` MCP tool that can
  read/write a dedicated `__hermes__/` subfolder in the vault, where
  all procedural memory + evolved skills live as markdown or YAML.
  User sees them as normal notes; Hermes sees them as memory. Single
  source of truth. Validate this design.
- **RQ-25. Shell / terminal tools.** For researchers this is often
  running scripts, grepping logs, checking git status. Propose a
  restricted shell tool that runs in a sandboxed cwd inside
  `~/Library/Application Support/Epistemos/HermesWorkspace/`, with a
  denylist of dangerous commands and explicit approval for anything
  outside that workspace.
- **RQ-26. File system tools.** Full-disk read for research requires
  user consent. What's the permission model? Propose: per-folder
  Security-Scoped Bookmarks that the user grants explicitly, with a
  clear UI showing "Expert Mode can read: [list of folders]."
- **RQ-27. Web search / research tools.** Hermes has tools like
  Serper, Tavily, SearxNG. Which should ship by default? Propose a
  bundled default with user-provided API keys, plus Perplexity /
  Anthropic web search as fallback through Epistemos's existing
  provider layer.
- **RQ-28. Code execution.** Researchers often want "run this Python
  snippet" or "spin up a notebook." What's the scope? Propose:
  sandboxed Python code runner inside the Hermes runtime itself, with
  output streaming to a result card. No persistent environment; each
  snippet runs in an isolated temp dir.
- **RQ-29. Document processing.** PDF parsing, docx reading, image
  OCR. Hermes ecosystem has these as tools. Bundle or integrate?

### 2.8 — Research-notes workflow specifically

The user's core use case is research and notes. Design for that.

- **RQ-30.** What does a typical research task look like end-to-end?
  Produce a concrete worked example: user asks "Build me a literature
  review on post-quantum cryptography focused on lattice-based
  schemes, pull citations from ArXiv, save findings to a new note in
  `~/vault/Research/PQC/`." Walk through every step Hermes would take,
  every tool call, every approval, every notification, and every note
  created in the vault.
- **RQ-31.** How does Hermes's output flow back into Epistemos's
  knowledge substrate? Proposal: every Hermes task produces at minimum
  one note in the vault, with structured frontmatter linking back to
  the task, the tool calls, and the source materials. The graph picks
  up these notes automatically via `GraphBuilder`.
- **RQ-32.** How do we prevent Hermes from polluting the user's vault?
  Propose: all Hermes-generated notes land in a dedicated
  `__hermes__/tasks/<date>/<task-id>/` subfolder by default, with an
  explicit "promote to main vault" action that moves a note into the
  user's chosen location.

## 3. Deliverables the research must produce

Produce, at minimum, the following artifacts. Each should be saved
under `docs/research/` in the repo.

1. **`hermes-expert-mode-implementation-spec.md`** — the master
   document answering all RQs above. Structured in the same numbered
   sections.
2. **`hermes-bundling-build-phase.md`** — the exact build-phase
   script recipe (python-build-standalone download + pinned
   hermes-agent venv freeze + codesign step) with rationale.
3. **`hermes-wire-protocol.md`** — the JSON schema for every message
   that crosses Swift ↔ Python boundary. Include bootstrap handshake,
   tool invocation envelope, result envelope, error envelope,
   streaming deltas.
4. **`hermes-expert-view-ui-spec.md`** — SwiftUI component tree for
   `HermesExpertView`, with wireframes in text form (not images),
   state-machine diagram of task status transitions, and the
   interaction patterns for all three entry points (button / shortcut
   / right-click).
5. **`hermes-preset-research-notes.yaml`** — the annotated default
   config preset, ready to bundle.
6. **`hermes-update-strategy.md`** — the auto-update mechanism,
   including signature verification, rollback, and UX copy.
7. **`hermes-tool-catalog.md`** — table of every Hermes tool we plan
   to enable at v1.1, with permissions, approval requirements, App
   Store impact, and the MCP bridge status.
8. **`hermes-risks-and-failure-modes.md`** — honest risk register.
   What happens when Python startup takes 8 seconds on a cold boot?
   What happens when the user's Python bundle gets corrupted? What
   happens when Hermes enters a retry loop and burns through their
   Anthropic rate limit? Each risk must have a concrete mitigation.

## 4. Success criteria

The research is complete when:

- Every RQ above has an answer that a junior engineer could implement
  from (concrete file paths, function signatures, wire format fields).
- The implementation spec fits in a 2-engineer-week build for the
  minimum viable integration (prompt in → Hermes runs → result lands
  in vault → notification fires) and a 2-engineer-month build for the
  full plugin ecosystem.
- Every App Store and sandbox implication is flagged, with the MAS
  build path (if different) explicitly spelled out.
- The risk register includes at minimum 10 concrete failure modes,
  each with a named mitigation.
- The preset YAML is concrete enough to ship.

## 5. Non-goals (don't burn research time on these)

- Competing with Hermes on agent benchmarks. Not our game.
- Porting Hermes internals to Swift. Permanently rejected.
- Rewriting Epistemos's native agent. It stays. Expert Mode is
  additive.
- Multi-user / cloud-hosted Hermes. Local-only.
- Training or fine-tuning hermes-agent. Consume upstream releases.
- MAS compliance for the full Expert Mode at v1.1. DD only.
- Speculative features users haven't asked for (multi-agent
  orchestration, agent-to-agent protocols, agent swarms, etc.).

## 6. Input constraints to respect

- Swift 6 strict concurrency. `@MainActor @Observable` for UI state.
- Actor isolation for anything that touches the subprocess.
- No `DispatchQueue.main.sync` anywhere.
- No `@MainActor` on inference or subprocess-IO paths.
- `AsyncStream.bufferingNewest(256)` for token streams.
- All secrets in Keychain via `Keychain.swift`.
- All FFI / subprocess errors thrown, never silently swallowed.
- SwiftData for persistence (`SDHermesTask`, `SDHermesStep`).

## 7. Reference material the research should ingest

Start here, follow citations as needed:

- NousResearch GitHub organization: https://github.com/NousResearch
- Hermes Function Calling format:
  https://github.com/NousResearch/Hermes-Function-Calling
- Hermes Agent:
  https://github.com/NousResearch/hermes-agent
- Hermes Self-Evolution:
  https://github.com/NousResearch/hermes-agent-self-evolution
- MCP (Model Context Protocol):
  https://modelcontextprotocol.io + the Swift SDK at
  https://github.com/modelcontextprotocol/swift-sdk
- Python Build Standalone:
  https://github.com/astral-sh/python-build-standalone
- Apple notarization + hardened runtime + entitlements for bundled
  subprocess: developer.apple.com Hardened Runtime docs.
- Swift Subprocess: https://github.com/swiftlang/swift-subprocess
- UNUserNotificationCenter docs on developer.apple.com.
- SwiftTerm: https://github.com/migueldeicaza/SwiftTerm
- Internal repo docs:
  - `docs/HERMES_INTEGRATION_RESEARCH.md` (prior research)
  - `docs/agent-system/AGENT_ARCHITECTURE.md`
  - `MCPBridge.swift`
  - `agent_core/src/bridge.rs`
  - `omega-mcp/src/dispatcher.rs`
  - CLAUDE.md (non-negotiable constraints)

## 8. Tone and style guidance

- Be opinionated. Pick one approach per RQ and defend it. A wishy-washy
  "it depends" isn't useful.
- Favor boring, proven patterns over clever ones.
- When in doubt, prefer fewer moving parts.
- When the easier path has a specific downside, name the downside
  quantitatively, not vaguely.
- No marketing copy. Engineering only.

## 9. What "done" looks like for this research

A fresh engineer can sit down with the output of this research and,
following the implementation spec plus the seven supporting docs,
ship a working Hermes Expert Mode feature end-to-end without having
to re-research any decisions. If the engineer has to go back and
research anything not covered here, the research is incomplete.

---

**Handoff instruction to the research agent:**
Start by reading `docs/HERMES_INTEGRATION_RESEARCH.md` and the current
state of `MCPBridge.swift` + `omega-mcp/src/dispatcher.rs`. Then
produce the 8 deliverable documents in section 3, in that order.
Before beginning, confirm in writing that you understand the
non-goals in section 5, because those are the most common failure
modes in prior attempts.
