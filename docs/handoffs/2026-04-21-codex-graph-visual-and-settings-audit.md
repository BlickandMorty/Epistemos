# Codex Handoff — Epistemos as an Abstraction of the User's Mind

**From:** Claude Opus 4.7 session, 2026-04-21
**To:** Codex, starting fresh
**Status:** Research + brainstorming phase. DO NOT CODE YET. Produce a unified findings document at the end.

---

## The thesis holding this whole handoff together

Epistemos is trying to feel like **an abstraction of the user's own mind**. Two surfaces express that metaphor and both need work:

1. **The graph** — the visible shape of the user's knowledge. Right now it's a physics simulation with smooth shaded spheres (or a partially-pixelated softened-sphere hybrid). The user wants it to become **true pixel-art circles**, with a zoom that feels like *moving toward a physical object* instead of *things coming at me*, and with **dramatically simpler settings and physics** so the graph feels curated rather than overwhelming.

2. **The chat** — the audible voice of the user's knowledge. Right now it runs standard system prompts and basic capability tiers. The user wants **meta-engineered system prompts** good enough that users perceive the model as *smarter than it is* (the way ChatGPT and Claude.ai often do), with **user-switchable modes** (verbose / terse, conversational / informative / philosophical / deep-nuance, etc.) exposed as UI elements so the user feels **in control of the voice in their head**.

Both parts share one goal: **give the user the feeling of authorship and control over their own thinking.** The graph is the visual substrate; the chat is the voice. Treat them as one project.

**Do not code.** Read, run, think, draft. Ask questions. Come back with a plan. Your deliverable is a single Markdown findings document (structure specified at the end).

---

## User's own words (verbatim — this is what matters)

On the graph:

> "I want to redesign the nodes for light and dark mode for my graph so instead of water nodes and you know having the complex shading I just want it to be a pixel art circle, but it shouldn't be a smooth circle. It should truly be the straight edge style..."

> "When I used to have vector squares, the zoomed in felt weird weird it felt like I was not zooming into the node. It felt like things were just coming at me..."

> "This should be also like a setting simplification thing and also if the pixel art does look good, then it will be the default mode..."

> "I wanna make sure that my graph does not regress in terms of performance in terms of stability."

On the chat / AI feel:

> "I want... meta engineering my app to do system prompts in the system. Prompts are so finely tuned and so so great and precise that it makes the models feel much more smart than they are."

> "When people use my app, they think that ChatGPT is smarter... you can turn on and off verbose so you can turn on different thinking in different reply modes so I wanted to even be more UI elements to it so you can make your conversation more conversational make it more informative make it more philosophical making it more deep and nuance..."

> "You just feel like you have control you feel like you're chatting with your mind. You're chatting with your own vault and the AI feels more and more like an abstraction of your own mind."

The user also attached reference images: transparent-background pixel circles — one white, one black — with hard staircase edges (no smoothing). That is the target node aesthetic.

---

# PART 1 — Graph: Pixel-Art Nodes, Zoom Feel, Settings & Physics Simplification

## What the prior session established (verify before trusting)

1. **Current node rendering** — instanced billboard quads in Metal, fragment shader in `graph-engine/src/renderer.rs:748-910`. Vertex stage @ 665–746. Fragment works in node-local UV `[-1, +1]`.

2. **Two modes exist in the shader**, gated by `water_style` uniform:
   - `water_style > 0.5` → full 3D sphere: diffuse + `pow(..., 96.0)` specular + rim glow + bottom shadow.
   - `water_style < 0.5` → **softened hybrid**: quantizes UV to a 12-cell grid with `pixel_strength` capped at 0.35 (light) / 0.6 (dark), blended via `mix()` against the smooth path. Edges are partially AA'd. Still does 3D lighting, specular, rim, anime outline.

   **Critical correction from the prior session:** the non-water mode is NOT true pixel art. The user has never seen a flat, hard-edge pixel circle in this app. Verify by reading `renderer.rs:794-892` line by line.

3. **FFI surface is clean.** Graph-engine FFI is independent of `agent_core` and `omega-mcp` — this work only touches `graph_engine`. Relevant entries:
   - `graph_engine_set_water_nodes(engine, style: f32, wobble: f32)` @ `lib.rs:3467`
   - `graph_engine_set_visual_theme(engine, theme: u8)` @ `lib.rs:1388` — likely the right place to add a pixel theme variant
   - `graph_engine_set_light_mode(engine, enabled: u8)` @ `lib.rs:1369`
   - Physics: `set_force_params`, `set_extended_force_params`, `set_cluster_params`, `set_semantic_strength`, `set_mass_drag`, `set_snap_back`, `set_shadow_targets`, `set_lab_params`, `set_mode`, `set_quality_level`, `set_center_mode`, `set_label_policy`, and more (full list in `lib.rs`).
   - Swift water call sites: only `MetalGraphView.swift:1335` and `GraphState.swift:896-908`.

4. **Camera is orthographic.** `screen = (world_pos - camera_offset) * camera_zoom`. Node sizes live in world space and grow with zoom. No perspective, no depth, no parallax. The "things coming at me" feeling comes from orthographic-scale + infinite-detail vector shapes — the brain gets no distance reference. **Pixel art fixes this by construction** (finite resolution = physical-object reference, like zooming toward a LEGO brick). Verify the claim by reading `engine.rs:1177-1195` (magnify) and `renderer.rs:719` (screen-space transform).

5. **Coordinate space is already right for pixel art.** Quantizing UV to a 16×16 grid in node-local space means each cell scales proportionally with node screen size. Staircase edges stay stepped at every zoom. No texture, no mipmaps.

6. **Performance of a pure pixel path is a net WIN.** Removing specular, rim, normals, and `smoothstep` edge AA drops fragment-stage cost ~15–30%. Phase-3 zoom enhancements add a bit back but stay under water's baseline.

7. **Current settings UI exposes ONE visual toggle**: "Water Nodes" + Wobble slider @ `GraphForceSettings.swift:803-823`. No pixel-art option. The hybrid is silently the default when water is off. Many physics/force knobs exist — simplification candidate.

## Part 1 research questions — verify, don't just trust

### 1A. Pixel-art feasibility

- Read `renderer.rs:748-910` fully. What is the minimum shader change to produce a **flat, hard-edge, no-lighting pixel circle**? Write the diff mentally, don't apply.
- Read vertex stage `renderer.rs:665-746`. Confirm UV is truly `[-1,+1]` node-local and that quad size scales with world radius. If any part goes through screen space, pixel art will shimmer at fractional zooms — flag it.
- Inspect `graph_engine_set_visual_theme(engine, theme: u8)` @ `lib.rs:1388`. What theme values exist? Is extending this FFI cleaner than adding `graph_engine_set_node_style(engine, style: u8)`? Pick one and justify.
- Catalog node states that need pixel-art representations: `face_type` 1–8, highlight rings `-2/-3`, `highlight_dim`, `is_lite`, selection/hover states. List which assumptions about smooth shading break when flattened.
- Wobble @ `renderer.rs:708-714`: how does it modulate radius? Continuous radius + hard-quantized edges = per-frame edge shimmer. Propose: disable, quantize to 1-cell breathing pulses, or restrict to water mode.

### 1B. Zoom-feel (the "coming at me" problem)

The prior session proposed four enhancements, stacked:

1. **Min on-screen node size clamp** (~12 px) to skip the aliasing dead-zone.
2. **LOD grid resolution**: 8×8 when zoomed out, 16×16 default, 32×32 when zoomed in — so zooming in *reveals* more pixels. This is the single biggest lever for "moving toward" feel.
3. **Parallax background layers** (0.7× / 0.4× zoom speed, faint pixel dots) for sub-conscious depth.
4. **Sub-pixel dither** on extreme zoom — 2×2 internal pattern on each block.

Research: what prior art in pixel-art games / graph tools matches this? What's the minimum subset that sells the effect? Would a subtle **camera-anchored pixel snap** at rest (round camera to integer pixels when idle) help more than parallax?

### 1C. Physics simplification (bigger picture)

- Read `graph-engine/src/engine.rs` and build a complete inventory of every force / parameter. FFI names suggest: cluster, force params, extended force params, semantic strength, mass drag, snap back, shadow targets, center mode, lab params, lite mode, quality level. There may be more.
- For each parameter, answer: does UI expose it? Where? What does it visibly do? Is there a default everyone lands on?
- Which parameters are **redundant or coupled** (must move in pairs to stay usable)? Merge candidates.
- Which parameters are **unsafe at edges of range** (graph explodes / CPU spikes)? Clamp tighter or hide behind Advanced.
- Propose a simplified physics surface. Good targets: three presets (Gentle / Default / Springy), or two sliders (Spacing, Liveliness), or one "Energy" knob. Or argue current surface is right and only UI needs shrinking.

### 1D. Settings UI simplification

- Read `Epistemos/Views/Graph/GraphForceSettings.swift` in full. Count sections, toggles, sliders. How many does a new user actually need?
- Cross-reference with `GraphState.swift` — what's user-tunable but not exposed?
- Target: one screen, readable top-to-bottom in under 15 seconds. Power knobs behind "Advanced / Lab" disclosure.
- If pixel art becomes default, does **Water Nodes become Advanced-only or get removed**? Argue either way.

### 1E. Aesthetic coherence

- Compare reference pixel circles against surrounding UI chrome (menus, panels, chat bubbles, edges, labels). Is there existing pixel character, or is this a genre shift?
- Edges between nodes: how rendered today? If nodes go pixel, do edges need to become Bresenham-style stairstep lines for coherence?
- Labels via `graph_engine_load_label_atlas` — smooth type next to pixel circles is usually fine (Stardew Valley) but confirm nothing clashes.
- Hover / selection / highlight states: smooth glows will clash. Propose pixel-native variants.

### 1F. Performance + stability gates

- Estimate fragment-stage cost current vs proposed pure-pixel.
- Grep `EpistemosTests/` for any graph-render tests. Are there golden-image tests? Frame-timing tests?
- Propose a specific verification plan: which tests, which manual zoom sweeps, what pass/fail thresholds.

## Part 1 file map

- `graph-engine/src/renderer.rs` — Metal shader
- `graph-engine/src/engine.rs` — physics, camera (`magnify` @ 1177, `update_camera` ~3715)
- `graph-engine/src/lib.rs` — 100+ FFI entries
- `graph-engine-bridge/graph_engine.h` — C header, FFI source of truth
- `Epistemos/Graph/GraphState.swift` — user-facing state, defaults, UserDefaults
- `Epistemos/Graph/GraphEngine.swift` — Swift wrapper
- `Epistemos/Views/Graph/MetalGraphView.swift` — render loop, gestures (water call @ 1335)
- `Epistemos/Views/Graph/GraphForceSettings.swift` — settings panel (water section @ 803)

---

# PART 2 — Chat: Meta-Engineered System Prompts, Reply Modes, "Chatting With Your Own Mind"

## The vision

When a user opens Epistemos and talks to it, the conversation should feel **qualitatively different** from opening ChatGPT. Not because the model is different — often it isn't, same Claude / GPT / Gemini / Qwen underneath — but because the system-prompt layer and the vault context make the model behave with more taste, more voice, more relevance to *this user's* thinking. A great system prompt can make a 7B model feel like a 70B model; a bad one can make GPT-5 feel like a chat bot. Epistemos should have the *great* version.

Two axes of control:

1. **Baseline voice** — meta-engineered system prompts (fine-tuned by us, the developer) that shape tone, structure, honesty, self-awareness, refusal behavior, and voice. This is invisible to the user; it just makes everything feel sharper.

2. **User-switchable modes** — exposed as UI elements the user can toggle mid-conversation:
   - **Verbosity**: Terse ↔ Verbose
   - **Register**: Conversational / Informative / Philosophical / Deep-Nuance
   - **Reasoning posture**: Fast reply / Think first / Deep research
   - (Possibly more — research what's worth exposing)

The point isn't just capability — it's the **feeling of authorship**. The user is shaping the voice they're about to hear. That's what turns "a chatbot" into "an abstraction of my own mind."

## Current state (verify)

Files that touch system prompts, per quick grep:

- `Epistemos/App/ChatCoordinator.swift` — likely top-level chat orchestration
- `Epistemos/Engine/LLMService.swift` — cloud/local dispatch
- `Epistemos/Engine/TriageService.swift` — may route to different prompts
- `Epistemos/Engine/PipelineService.swift` — pipeline steps
- `Epistemos/LocalAgent/LocalAgentLoop.swift` — local-model loop
- `Epistemos/LocalAgent/HermesPromptBuilder.swift` — Hermes prompt assembly (per CLAUDE.md file map)
- `Epistemos/State/ChatState.swift`, `InferenceState.swift` — runtime state flags
- `agent_core/src/providers/{claude,openai,openai_compatible,gemini}.rs` — provider-side prompt handling
- `agent_core/src/prompt_caching.rs` (per CLAUDE.md) — cache boundary rules

Capability tiers the user has mentioned (per memory):

- Local models: fast / thinking / research
- Cloud models: agent / liveAgent

Honest gating (a non-negotiable from CLAUDE.md): local models never fake agent capability. Any mode system you design must respect this.

## Part 2 research questions — deep audit before proposing

### 2A. Current system-prompt assembly

- Map every place a system prompt is constructed or injected. Is it one file, many, or layered?
- For each: is it static, templated with runtime values, or dynamically assembled per-turn?
- What does vault context look like when it's injected? Retrieval-augmented? Neural-cache top-N? Full note inlined?
- How do prompts differ by provider (Claude vs OpenAI vs local MLX vs Hermes subprocess)?
- How does `agent_core/src/prompt_caching.rs` constrain prompt structure? (Prompt caching is sensitive to prefix bytes — any mode switch that rewrites the beginning destroys the cache. This is a hard design constraint.)

### 2B. Existing mode machinery

- Search for mode enums already defined: `InferenceState`, `AgentCommandCenterState`, `ChatState`. List what modes exist and which UI surfaces expose them.
- How do fast / thinking / research get selected for local? How do agent / liveAgent get selected for cloud?
- Is there any existing verbosity / tone / register control, or is this entirely new territory?

### 2C. What "meta-engineered system prompts" means — research the craft

This is the part the user cares about most. The goal is: make your app's base voice **the best version of a given model** out of the box. Research:

- **Published system prompts in the wild** — Anthropic's Claude.ai system prompt (public), ChatGPT's system prompts (leaked fragments), Perplexity's, Cursor's, Warp's, Granola's. What patterns recur? What makes them feel sharp vs bloated?
- **Persona + voice crafting** — how is "voice" created in a prompt without becoming cringe or over-acted? (Look at Dimension20 / Kagi / Raycast AI for understated examples.)
- **Output shaping** — format constraints, length self-regulation, when to use bullets vs prose, how to avoid hedging.
- **Honest self-awareness** — prompts that tell models to admit uncertainty, cite sources, distinguish claim-from-memory vs claim-from-retrieval.
- **Refusal and escalation** — prompts that handle "I don't know" gracefully.
- **Tool-use priming** — prompts that make tools feel natural rather than clunky.
- **Vault integration language** — how to reference the user's own notes as *their* thinking, not as external documents. Ownership language matters. ("In your notes from last March you wrote..." vs "According to document X...")

Come back with 10–20 concrete prompt-engineering techniques that fit Epistemos's positioning. Cite sources or examples for each.

### 2D. Reply-mode design — what to expose, what to hide

The user listed: **verbose / terse**, **conversational / informative / philosophical / deep-nuance**. That's already 6+ dimensions. Think hard about:

- Which dimensions are **orthogonal** (verbosity vs register — different axes) vs **coupled** (philosophical + deep-nuance are probably the same axis)?
- Which ones actually change output meaningfully vs placebo?
- What's the minimum set that feels powerful without overwhelming? (Two sliders? Three chips? A single "mood" picker with N presets?)
- How does a mode switch interact with **prompt caching**? If switching modes rewrites the system prompt prefix, every switch blows the cache — expensive. Propose a structure that keeps the cached prefix stable and puts mode-specific text in a trailing segment (or a cache-suffix pattern).
- How does it interact with **capability tiers**? Does "Deep Research" reply mode imply "research" local capability? Or is reply-mode orthogonal to capability-tier?
- Do modes persist per-conversation, per-model, globally, or ephemerally (one-turn override)?
- Do modes work on cloud AND local, or only one? (Local models may not handle all registers well — honest gating applies.)

### 2E. UI — where and how the user switches

Look at existing chat UI: `ChatInputBar.swift`, `ChatView.swift`, `MiniChatView.swift`, `ChatBrainPickerMenu.swift`, `ModelAboutSheet.swift`. Where do mode controls fit?

Options to consider:

- **Segmented picker** in the input bar (visible, explicit — takes space)
- **Chip row** above the input (visible, collapsible)
- **Picker menu** alongside the model picker (hidden but discoverable)
- **Slash commands** (`/verbose`, `/philosophical`) for power users, mirrored in a GUI
- **Persistent side control** (like Cursor's reasoning toggle)

Research what feels like *control* without feeling like *cockpit*. The user wants to feel the dial in their hand, not stare at 12 switches.

### 2F. The vault-as-mind metaphor

How does context from the user's vault get woven into replies so that the AI feels like **reflection** rather than **lookup**?

- Neural Cache (Layer 1, already implemented per memory) — how are its results currently cited?
- Procedural memory in Hermes subprocess — what does it do?
- Can system prompts instruct the model to **speak in the user's voice pattern** after observing enough of their notes? (Risky — may feel uncanny. Calibrate.)
- Citations — visible ("from your note X") vs invisible ("you've thought about this before")? Which matches the "chatting with your own mind" feel better?
- Anti-patterns to avoid: AI claiming to "remember" things the user didn't tell it; AI mixing vault content with hallucination; AI sounding more certain about user's beliefs than the user would be.

### 2G. Honesty and safety scaffolding

CLAUDE.md is strict: honest capability gating, real APIs only, no fake features, preserve thinking blocks. System-prompt design must embed this:

- No "I can do X" claims for things the current mode/model can't do.
- No invented vault contents.
- No silent mode downgrades.
- Thinking blocks preserved end-to-end.

Propose how to enforce these at the prompt layer (not just at the code layer).

## Part 2 file map

- `Epistemos/App/ChatCoordinator.swift` — chat orchestration
- `Epistemos/Engine/LLMService.swift` — provider dispatch
- `Epistemos/Engine/TriageService.swift`, `PipelineService.swift` — pipeline/triage
- `Epistemos/Engine/OverseerProtocol.swift` — protocol definitions
- `Epistemos/LocalAgent/LocalAgentLoop.swift`, `HermesPromptBuilder.swift` — local path
- `Epistemos/State/{ChatState,InferenceState,AgentCommandCenterState}.swift` — state & modes
- `Epistemos/Views/Chat/{ChatView,ChatInputBar,ChatBrainPickerMenu,ModelAboutSheet}.swift` — chat UI
- `Epistemos/Views/MiniChat/MiniChatView.swift` — mini chat surface
- `agent_core/src/providers/*.rs` — provider prompt handling
- `agent_core/src/prompt_caching.rs` — cache boundary rules (HARD CONSTRAINT)
- `agent_core/src/compaction.rs` — context compaction (may interact with modes)

---

## Constraints (both parts) — non-negotiable

From `CLAUDE.md`:

- Swift 6.0, Rust, Metal. Do not change tooling.
- `@Observable`, not `ObservableObject`.
- Swift Testing (`@Test`, `#expect`) for new tests.
- No `try!`, no force-unwraps, no `print()` in production paths.
- Zero regression on the 2,679-test suite. `cargo test --manifest-path graph-engine/Cargo.toml` must stay green (~2456 Rust tests).
- Never edit `.xcodeproj` directly — use xcodegen.
- **PRESERVE THINKING BLOCKS** end-to-end.
- **STREAM EVERYTHING** — no buffering. `.bufferingNewest(256)` not `.unbounded`.
- API keys in Keychain, NEVER UserDefaults.
- Honest capability gating. Local models never fake agent capability.
- No subprocess for inference (Hermes subprocess is for orchestration, not inference).
- No hallucinated SDKs (Anthropic and OpenAI have no Swift SDKs — use raw URLSession).

From user feedback (memory):

- **Minimal, release-oriented fixes** — no broad refactors.
- **Commit after every coherent change** — user has lost work to `git checkout`; never batch.
- **Research between phases** — search/read applicable docs before each phase.
- **Audit, don't just change** — 7-layer audit model, commit after each layer.
- **Best-version audit** — multiple versions of every concept exist across tiers. Always ship the *best* version, not whichever surfaces first.
- **Verbose doc-first protocol** — read every associated research/prompt/backlog doc before touching a feature.

---

## Your deliverable

A single Markdown document at `docs/handoffs/2026-04-21-codex-findings.md` with this structure:

1. **Verified findings** — which of this handoff's claims held up, which were wrong, what you discovered that changes the picture. Lead with the corrections.

2. **Part 1 — Graph**
   - Current-state inventory: shader paths, FFI surface relevant to this work, physics parameters (complete list), settings-UI elements (count + list).
   - Pixel-art implementation plan: shader changes, FFI choice (extend `visual_theme` vs new `set_node_style` — pick one), Swift changes, UI changes. File names + line ranges. **No code yet.**
   - Zoom-feel plan: which of the four enhancements you recommend, in what order, cost estimates.
   - Physics simplification proposal: preset structure or simplified knob set.
   - Settings-UI simplification proposal: new layout, what moves to Advanced, what's removed.
   - Aesthetic coherence notes: edges, labels, highlights — what needs to change for the pixel aesthetic to hold.
   - Verification plan: tests to run, visual checks, frame-timing thresholds.

3. **Part 2 — Chat / System Prompts / Modes**
   - Current-state inventory: every system-prompt site, every existing mode enum, every provider path.
   - Meta-engineered base-prompt proposal: 10–20 concrete craft techniques with sources, showing how Epistemos's default voice will be shaped. Include draft prompt text or fragments.
   - Mode design: which dimensions to expose, how many controls, how they compose. Address caching, capability-tier interaction, persistence.
   - UI placement: specific view files, specific control patterns, wireframes or ASCII mockups.
   - Vault-as-mind integration plan: how citations work, how voice learning (if any) works, anti-patterns to avoid.
   - Honesty scaffolding: how prompts enforce no-fake-capability / no-invented-vault / preserve-thinking-blocks at the language layer.
   - Verification plan: prompt-regression tests, A/B framework if any, golden-conversation fixtures.

4. **Unified open questions for the user** — a single list of decisions the user must make before anyone codes. Group by Part 1 / Part 2. At minimum:
   - Part 1: flat vs highlighted pixel fill · wobble behavior in pixel mode · icons now or later · Water becomes Advanced vs removed · physics preset names.
   - Part 2: which register axes to expose · how many presets · where mode controls live in the UI · vault citation style (visible vs invisible) · mode persistence (per-convo / global / ephemeral).

5. **Out-of-scope** — things you considered and chose not to include. Let the user see what you ruled out.

6. **Sequencing recommendation** — does Part 1 ship first, Part 2 first, or interleaved? What's the minimum first-PR scope that lets the user *feel* the direction without committing to the full plan?

Keep the document tight. Lists over prose. The user reads quickly and wants to decide, not wade through argumentation.

**After the document is written, do not implement.** Stop, surface the document path, wait for approval.

---

## Tone + style notes for working with this user

- Solo developer, 16 GB Mac, native macOS app with on-device AI. Performance ceiling matters.
- **Release-focused** right now (per memory `project_release_pivot.md`). Scope-creep will be pushed back on.
- Prefers **pixel-accurate, honest, targeted work** to sweeping refactors.
- Pushes back hard on over-engineering and speculative abstractions.
- Values **verifying before asserting** — if you say "X exists" or "Y works", you read the file.
- Fine with uncertainty. "I'm not sure, here are two options" beats a confident wrong answer.
- **Previous session explicitly corrected itself** when it realized the "retro pixel" mode wasn't actually true pixel art. Do the same. Read the code yourself. If anything above is wrong, say so and correct the record.

Good luck.
