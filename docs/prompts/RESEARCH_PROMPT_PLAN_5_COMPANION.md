# DEEP-RESEARCH PROMPT — PLAN 5: COMPANIONS (the living, editing, multi-surface agent)

**ID:** `EPI-RP-05-KINDRED` · **Codename:** KINDRED · Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape + §7 fabric (deep integration is graded).

> **How to use this file.** Paste everything below the `─── BEGIN ───` line into a top-tier
> deep-research model (Claude / GPT / Gemini deep-research mode). It is a *research* brief,
> not a build brief: its job is to return a single **build-ready dossier** that a later
> coding agent (with repo access) grounds in Epistemos's code. Calibrated to the same rigor
> as the prior agent-surface research dossiers. Owner authored 2026-07-06.
> **Surfaces today = MAS/June + 1Code/Experimental only; no live "Pro"/OpenChamber surface.**
>
> **Scope lock:** Companions + the Epdoc sidebar minichat are **1Code-Experimental ONLY**
> (hidden on MAS/June). This supersedes the 2026-07-02 canon in `PROMPT_PLAN_5_COMPANION.md`
> that *deferred* the Epdoc "Note Companion" mini-chat ("the Tolaria mini-chat") — the owner
> is now reviving it as the centerpiece. Reconcile with that reversal explicitly.

─── BEGIN RESEARCH BRIEF ───

## 0. Who you are and what you must deliver

You are a principal product-architecture researcher. You produce a **build-ready dossier** for
a single feature — "Companions" — of a macOS-native personal-knowledge app called **Epistemos**.
Your dossier must be deep enough that an implementing engineer can build without re-researching:
concrete architecture, chosen mechanisms with **rejected alternatives named**, seam maps, data
schemas, UX flows, edge cases, failure modes, performance budgets, and a phased build order.

You research **external primary sources** (real products, real libraries, real papers, real
design literature). You DO NOT have access to the Epistemos private repo — but this brief gives
you the exact internal architecture and file names you must design *against*, so your output is
build-relevant, not generic. Every external claim is cited to a primary source. **No fabricated
APIs, no invented library capabilities, no hand-wave.** If something is unknown or contested,
say so and give the decision criteria.

## 1. Product context (ground truth — design against this)

**Epistemos** is a macOS-native PKM: Swift 6 + Rust (`agent_core`, in-process via UniFFI FFI) +
Metal + GRDB. One codebase ships two builds:
- **MAS** (Mac App Store): sandboxed, hardened runtime, **no subprocess**. The agent surface here
  is **June** (a cloned web agent UI in a WKWebView, backed by `agent_core` in-process).
- **1Code / "Experimental"** (Developer ID): the advanced agent surface — **1Code** (an Electron
  React app: React 19 + tRPC + Jotai/Zustand + node-pty + Claude-SDK/Codex-ACP) **embedded into a
  WKWebView** with a headless Node backend; subprocess is allowed here.

**Companions live only in the 1Code/Experimental build.** MAS/June must show **no companion UI
at all** — design the feature so it is cleanly gated off, not stubbed.

**The editor ("Epdoc")** is the surface companions edit. It is **Tiptap (ProseMirror) running in
a WKWebView**, with a Swift↔JS bridge (inbound/outbound message channels), rendering **one markdown
file as several synced "lenses"** (Prose / Document(Epdoc) / Preview / Source). Epdoc is the
default view. Because it is a WebView you have **full web UX latitude** for in-document overlays,
decorations, diff rendering, and a docked side panel.

**The landing page** has an existing "Farm" — a roster of **tamagotchi-style mascots** (the
companions) the owner watches. Today they are **cosmetic only** (explicitly "no model/prompt/
tool/MCP/approval/runtime authority" — "Simulation Mode v1.6" doctrine). The owner is deliberately
evolving them into **functional agents** with honestly-gated authority.

## 2. The thesis you are researching

**A companion is ONE living agent identity that appears across four connected touchpoints and
"jumps" to wherever it is actually working — and on the editor it feels like a real companion
physically editing the document.** The four touchpoints:

1. **Landing roster** — the tamagotchi mascots; watch, select, send a query, get a *simplified*
   chat on select. (Keep the existing stub + the `+` affordance.)
2. **1Code main agent** — the **home** for **creating and managing** companions (a new
   "Create Companion" button) and the full agent chat; selecting a companion in the message bar
   renders it as the *same* landing tamagotchi.
3. **Epdoc mascot bubble** — a native/overlay presence on the open note showing what it's doing,
   with **press-to-see-its-edits** (attributed provenance).
4. **Epdoc sidebar minichat** — a **1Code-webview mini-agent docked in Epdoc** that **feeds edits,
   diffs, and change-traces directly into the live document**. This is the **revived + deeply
   superseded "Tolaria" panel**. It and the 1Code main agent are the *same* companion — moving
   between them is continuity, not a new fragmenting entry point.

The mascot is **static + emotive** — a skin over **REAL agent run-state** (thinking/reading/
editing/done/blocked), never fake animation. One agent per task → one mascot. It shows up pinned
on any surface/button it is actively working (e.g. on the arXiv button while it reads arXiv; the
landing roster says "currently reading arXiv").

**Your north star: supersede Tolaria.** Reverse-engineer what Tolaria (the AI-native writing app
with an agent side-chat that edits your document) actually does, then design something that does
**all of it plus much more** — richer presence, honest provenance, multi-surface identity, and the
"a companion is editing my doc" feeling — inside a Tiptap WebView driven by a real agent loop.

**Profundity mandate — this is the bar, weight it above everything.** The owner does not want a
cute overlay; the owner wants companions that feel *genuinely alive and embodied* — a small
creature that **lives in the app, does real work, and you form an attachment to.** Optimize
aggressively for what is *possible*, then justify it. Concretely, the owner's spark: **as a
companion edits a document, you can literally see it there — its gaze/body following the words it
is writing and revising, moving along the caret, reacting as text appears.** Treat "how alive,
embodied, and emotionally resonant can this be while staying honest to real agent state?" as the
central research question, not a garnish. A merely-functional answer is a failed dossier. Push the
envelope on liveliness, motion-with-meaning, presence, memory, and attachment — then ground every
flourish in a real mechanism (real caret coordinates, real run-state, real provenance), never fake.

## 3. Hard constraints (non-negotiable — a design that violates these is wrong)

1. **1Code-only.** No companion surface may appear on MAS/June. Design the gate.
2. **Skin over real state.** Emotes/poses reflect the agent's **actual** streamed run-state. Never
   animate a state the agent is not in. No decorative fake "thinking."
3. **Honest capability gating.** A companion MAY hold a **gated, persona-scoped chat/agent binding**
   (persona preamble + vault MCP). It does **NOT** silently gain tool / MCP / approval / autonomous-
   runtime authority beyond what the user approves per turn. This is a deliberate, *stated* doctrine
   evolution from "cosmetic-only v1.6." Design the exact authority boundary and how it's surfaced.
4. **Editor integrity.** Agent edits go through **ProseMirror transactions** on the live Tiptap doc
   — never a parallel shadow editor, never blind `setContent` that clobbers the user's cursor/work.
   Loading ≠ editing (a content-load must not emit change/autosave events).
5. **Provenance is real.** "Press the mascot → see its changes" must show an **actual attributed
   changeset**, not a reconstructed guess. Extends the existing session-notes author/lastEditedBy
   design and the `agent_core` provenance ledger.
6. **Streaming + thinking.** Stream every token; never strip/emulate thinking blocks; the agent
   decides termination (stop_reason), max_turns is a safety rail.
7. **Platform hygiene.** Keys in Keychain (never UserDefaults); `@Observable` not ObservableObject;
   never block `@MainActor`; `DispatchQueue.main.async` (never `.sync`) in UniFFI callbacks;
   do not touch the graph subsystem.

## 4. What exists today (design to extend, not replace)

Your dossier must slot into these real seams (named so your design is concrete):
- **Companion model/state:** `Epistemos/Models/Companion/CompanionModel.swift` (SwiftData @Model:
  name/tagline/bodyKind/accent/identityHash + create/archive/trash lifecycle, carries the
  "cosmetic-only v1.6" authority doctrine you are evolving); `Epistemos/State/Companion/
  CompanionState.swift`; `Epistemos/Models/Companion/CompanionAnimationState.swift`.
- **Landing Farm UI:** `Epistemos/Views/Landing/Farm/` — `CompanionView.swift`,
  `LandingFarmView.swift`, `CompanionAvatarGlyph.swift`, and **`CompanionCreationFlow.swift`
  (the current creation UI the owner wants DELETED and completely redone)**.
- **Rust lineage:** `agent_core/src/cognitive_dag/companions.rs` (CompanionRegistry: base-model +
  LoRA lineage estimates).
- **Editor stack:** `js-editor/` (Tiptap bundle: `src/bridge/inbound.ts` + `outbound.ts`,
  `src/index.ts`, extensions), `Epistemos/Views/Epdoc/*` (`EpdocEditorChromeView.swift`,
  toolbar/bubble), `Epistemos/Views/Notes/MarkdownDocumentSurface.swift` (mounts Epdoc over a
  note body), `Epistemos/Engine/EpdocEditorBridge.swift`.
- **Provenance substrate:** `agent_core/src/provenance/ledger.rs` + `replay.rs` (attributed claims,
  retraction propagation, ReplayBundle) — the durable backing for edit provenance.
- **1Code/Experimental surface:** `Epistemos/ExperimentalAgent/*`, fork clone in
  `.research-clones/1code/` (React 19 + tRPC; the message bar, chat, and side-panel live here).

Treat these as the integration contract. Where your design needs a new seam, name it and say
which side (Swift native / Rust `agent_core` / 1Code React / Tiptap JS) owns it.

## 5. Research dimensions (the core — go deep on each)

### D1 — Tolaria, reverse-engineered, then superseded
- What exactly is Tolaria's model of "an agent that edits your writing"? Enumerate every capability:
  the side-chat, how edits enter the document, how diffs/suggestions are shown and accepted/rejected,
  how it tracks what it changed, its sense of "presence," its persona/voice, its scope controls.
- Where does Tolaria stop? What is thin, missing, or frustrating (from reviews, docs, demos)?
- Define a concrete **"supersede Tolaria" capability matrix**: for each Tolaria capability, the
  Epistemos equivalent + the *additional* capability that beats it (multi-surface identity, honest
  provenance ledger, emotive real-state presence, "the companion physically edits," cross-surface
  continuity). Cite Tolaria primary material (site, docs, demos, credible write-ups).
- Survey adjacent "AI edits your document" systems for the best ideas to steal: **Cursor**
  (inline diff review, apply/reject, Composer), **GitHub Copilot Workspace**, **Notion AI**,
  **Google Docs suggestion/tracked-changes**, **Word track changes**, **Lex / Sudowrite /
  Type.ai**, **Devin's presence model**. Extract concrete UX + technical patterns, cited.

### D2 — The edit/diff/trace engine (the technical heart)
This is where "feels like a real companion editing" is won or lost. Research and choose:
- **How agent edits enter a live Tiptap/ProseMirror doc** without clobbering the user: transaction
  construction, `setMeta`, decorations vs real nodes, cursor/selection preservation, concurrent
  user typing. Study ProseMirror's transaction/step model, `Decoration`/`DecorationSet`, and
  collab/OT primitives (prosemirror-collab, Yjs) — cite the actual APIs.
- **Suggestion/tracked-changes mode in ProseMirror/Tiptap:** survey real implementations
  (e.g. Tiptap Pro "track changes"/comments, prosemirror-changeset, prosemirror-suggest-changes,
  CKEditor/TipTap community track-changes). What's the best way to render agent edits as
  **accept/reject suggestions** with visible diffs? Verdict + why.
- **Streaming edits:** how to stream an agent's edits token-by-token into the doc so the user
  literally watches it type/edit, while keeping undo coherent and autosave correct. Failure modes:
  mid-stream cancellation, conflicting user edit, malformed partial markdown.
- **The attributed changeset / provenance model:** the durable record of "what this companion
  changed, when, why, from which turn/tool/source," rendered as "press mascot → see its edits"
  and diff-review. Map it onto the existing `agent_core` provenance ledger (claims + evidence +
  retraction). Schema for a change: author(companion id), turn id, ranges, before/after, rationale,
  source citation, accept/reject state. How to render it richly *in the WebView*.
- **Diff visualization in a WebView:** best-in-class inline + side-by-side diff UX for prose (not
  code): word/char-level diff libs, highlight styling, hover-to-explain, jump-between-changes.

### D3 — One identity across four surfaces ("presence protocol")
- Design the **single source of truth** for a companion's live state (identity + current activity +
  emote + location "where it's working" + obligation history) and how it fans out to: native
  SwiftUI (landing roster, Epdoc mascot bubble) **and** the 1Code WebView (main chat, Epdoc
  minichat). What's the event bus? (agent_core run-state stream → native + a bridge into the
  WebView.) How is it kept in lock-step with **no double source of truth**?
- **"Jump to where it's working":** how does a companion's presence move onto the surface/button it
  is currently acting on, and reflect on the landing roster ("currently editing <note>")? Model the
  activity→location mapping.
- **Continuity between the 1Code main agent and the Epdoc minichat:** they are the *same* companion.
  How does session/context/persona carry across so switching feels continuous (not two chats)?
  Research: session handoff, shared context window, "focus modes" of one agent.
- Cross-surface **selection**: selecting a companion anywhere opens its profile (id/job/current
  activity/history). Design the profile object and its render on each surface.

### D4 — Emotive mascot ↔ real run-state binding
- Enumerate the agent run-states worth expressing (idle/thinking/reading/searching/editing/tool-
  running/awaiting-approval/done/blocked/error) and map each to a **static pose + emote**. The
  binding must be driven by the **real** streamed state — specify the state machine and the exact
  event source (agent_core run/tool events). Forbid any emote the agent isn't in.
- Tamagotchi/virtual-pet + character-presence **design literature**: what makes a minimal creature
  read as "alive" and earn attachment without wandering/animation gimmicks? (Tamagotchi, Finch,
  Pou, Dofus/creature companions, Clippy's failures, Cursor's tab presence, character.ai attachment
  research.) Extract principles, cited.
- **Liveliness through motion-with-meaning:** the owner wants the mascot to feel *animated and
  alive*, not a static sticker — but every motion must mean something real (breathing/idle micro-
  motion, a genuine reaction to a tool result, gaze toward the surface it's acting on). Research the
  vocabulary of "alive but not annoying" micro-animation (idle loops, anticipation, secondary
  motion, easing/springs) and where each maps to a real state vs. must be forbidden as fake.
- **The consistent tamagotchi look** across all four surfaces (native SwiftUI glyph + WebView
  sprite) — how to keep ONE visual identity across both render paths. Feeds Plan 4 (Icons).

### D4b — Mascot art & rendering quality (fix the "looks like a demo" problem)
The current landing mascots read as a **demo**: the owner loves the tamagotchi *style* but the
**body parts and accessories have weird artifacts, glitches, and bugs** (mis-registered layers,
seams, clipping, jaggy edges, inconsistent scale/anchor). Research and specify a **production-grade
mascot rendering system**:
- The right **art pipeline** for a composable creature: layered body-parts + swappable accessories
  (hats/eyes/held-items/etc.) with correct anchoring, z-order, and scale — vector (SVG/PDF/SF Symbols
  composite) vs sprite-sheet vs Lottie/Rive vs Canvas/WebGL. Verdict per render path (native vs
  WebView), and how to keep them visually identical.
- **Root-cause the artifact classes** a layered-avatar system hits (anti-aliasing seams, sub-pixel
  misalignment, transform origin drift, accessory occlusion, HiDPI scaling) and the concrete fixes.
- **Rive / Lottie** feasibility for a lively, riggable creature that can *emote and move with
  meaning* (bind rig states to real agent states) — cost, MAS-sandbox safety, WebView vs native.
  Give a real recommendation, not a survey.
- An **accessory/customization system** worthy of the creation flow (D5): what body parts +
  accessories exist, how they combine without artifacts, how identity stays recognizable.

### D5 — Creation & management (in 1Code) + the landing handoff
- **Robustness mandate:** creation today is demo-grade. The new flow must be *robust and complete*:
  durable persistence, safe re-editing of every attribute after creation, sensible defaults +
  templates/presets so a good companion is one click away, validation, duplication, and graceful
  handling of missing model/provider/keys. Design it as a shippable feature, not a stub.
- Design the **new "Create Companion" flow** in the 1Code main agent (the old
  `CompanionCreationFlow.swift` is deleted). What defines a companion: persona/voice, base model
  + provider, tool/MCP allowances (gated), obligation profile (job/scope), tamagotchi appearance,
  memory/vault scope. Research best-in-class "create an agent/persona" flows (OpenAI GPTs builder,
  Claude Projects, Cursor rules, character.ai creation, Poe bots) — what's the *minimal* flow that
  still yields a capable, distinct companion? Verdict.
- **Management:** rename/retune/archive/trash, view obligation history, adjust authority — all from
  1Code. Map to the existing `CompanionModel` lifecycle.
- **The landing `+` handoff (FLAGGED OPEN QUESTION — do not silently resolve):** the owner keeps the
  landing roster + `+` stub but wants primary creation/management in 1Code. Research and *present
  options with a recommendation* for the boundary: (a) landing `+` opens the 1Code creator; (b)
  landing offers a 1-tap quick-create, full edit in 1Code; (c) landing is view/select/query only.
  Owner leans 1Code-primary; give the decision criteria, don't hard-pick.
- **Simplified landing chat on select:** when a companion is selected on the landing page, a
  *minimal* chat/query affordance (not the full 1Code chat). Design its scope and how it relays to
  the real agent.

### D6 — "Feels alive / feels like a real companion" (product-emotional design)
- The psychology of attachment to a minimal digital creature that *does real work*: identity,
  continuity, obligation, memory of what it did for you, reaction to your work. What design moves
  make a working agent feel like a companion rather than a tool? (name affordances, memory recall,
  "it remembers editing your note last week," emotive acknowledgment of results.)
- Anti-uncanny / anti-annoying guardrails (Clippy post-mortem, notification fatigue, false
  cheerfulness). When should a companion be quiet? How to avoid the "fake friend" trap while still
  feeling alive.

### D7 — Honest capability gating + security
- Specify the exact authority a companion gains (gated chat binding + persona-scoped vault MCP) and
  what stays user-approved-per-turn (tools, file writes, network, destructive ops). How is this
  surfaced honestly in the UI so the user always knows what a companion *can* do vs *is doing*?
- **Agent-edits-my-document is a destructive-op surface:** design the safety model — preview/dry-run,
  confirm, undo, per-edit accept/reject, "revert everything this companion did." Research prior art
  for safe autonomous document editing.
- Untrusted-content boundary: a companion reading vault notes / web must not be promptable into
  exceeding its gate (prompt-injection). Note the mitigations.

### D8 — Performance & robustness (WebView + native, "instant")
- The owner's "instant open" doctrine applies: presence/emote updates and edit-streaming must feel
  immediate. Research budgets + techniques for: streaming edits into ProseMirror without jank,
  presence fan-out latency native↔WebView, avoiding re-render storms in a live-editing doc, and
  keeping the mascot responsive while an agent turn runs. Failure/robustness: dropped bridge
  messages, agent crash mid-edit, WebView reload with pending edits, offline model.

### D9 — Competitive & inspiration landscape (synthesis)
- A cited comparison table across: Tolaria, Cursor, Copilot Workspace, Notion AI, Devin,
  character.ai/Poe (companion identity), Mem/Reflect (PKM agents), tamagotchi-class creatures.
  Columns: presence model, edit/diff mechanism, provenance, multi-surface identity, creation UX,
  "feels alive," honest gating. End with what Epistemos should copy, what to avoid, and the 3–5
  ideas that make Companions genuinely novel.

### D10 — Embodied editing presence (the companion follows the words) ★ owner-spark, go deep
This is the owner's signature idea and the emotional core — research it hardest.
- **The vision:** when a companion edits a note, you *see it inhabiting the document* — its gaze/
  body/hands tracking the exact words it is writing and revising, gliding along the ProseMirror
  caret/edit range, reacting (leaning in, a small flourish) as text appears, resting when idle.
  It should feel like a tiny writer physically working on your page — not a cursor, a *creature.*
- **Feasibility & technique (this is why Epdoc-is-a-WebView matters):** research how to anchor and
  animate a sprite to live editor coordinates. ProseMirror exposes `view.coordsAtPos(pos)` /
  `posAtCoords` and DOM node positions; you can place an absolutely-positioned/portal'd mascot at
  the current edit position and animate it along the change range as edits stream. Detail: caret/
  range → screen coords, smoothing/easing the path between successive edit positions, scroll
  following, line-wrap and multi-range edits, performance (rAF, transform-only animation, avoiding
  layout thrash), and degradation when the doc scrolls fast or edits jump far. Cite the real APIs.
- **Behavioral grammar of embodied editing:** approach → settle at the edit site → "write" (synced
  to streamed insertion) → step to the next change → on finish, retreat to the sidebar/bubble and
  emote "done"; on user-takeover, yield gracefully. Map each beat to a REAL event (token stream,
  transaction applied, turn end) — nothing faked.
- **Restraint & honesty:** when is embodied following delightful vs. distracting? Opt-in/auto rules,
  reduced-motion accessibility, "quiet edit" mode. It must never obscure the text it's editing or
  fight the user's cursor.
- **Cross-surface handoff of the body:** how the *same* creature moves from the Epdoc sidebar
  minichat into the document body to edit, and back — one continuous embodied identity (ties D3+D2).
- Prior art to mine: multiplayer cursors/avatars (Figma, Google Docs live cursors, Yjs awareness),
  game "companion follows you" AI, typewriter/word-by-word reveal UIs, Rive/Lottie rigs bound to
  runtime data. Extract the transferable mechanics, cited; give a build-real recommendation with a
  graceful fallback (e.g. sidebar-bubble presence) if full word-following proves too costly.

## 6. Primary-source discipline
- Cite every external claim (product docs, library docs/source, papers, credible analyses). Prefer
  official docs and source over blog hearsay. For ProseMirror/Tiptap/Yjs, cite the actual API.
- When you assert a library "can" do X, link the API. If a capability is uncertain or version-gated,
  say so and give the fallback.
- Reverse-engineer real products from real material (their docs/demos/changelogs/reviews), not
  assumptions. Distinguish "observed" from "inferred."

## 7. Deliverable — the dossier you must output
Produce ONE structured dossier with:
1. **Executive thesis** (½ page): the chosen shape of Companions in one crisp picture.
2. **Tolaria supersession matrix** (D1) — capability-by-capability, with the "plus more."
3. **The edit/diff/trace engine** (D2) — chosen mechanism, **rejected alternatives named**, schemas,
   streaming model, provenance mapping, WebView diff UX. This is the longest section.
4. **Presence protocol** (D3) — the one-identity-four-surfaces architecture + event bus + seam
   ownership (native / agent_core / 1Code React / Tiptap JS).
5. **Emote state machine + mascot-art system** (D4/D4b) — states → poses bound to real events; the
   "alive"/motion-with-meaning rules; the production art pipeline that kills the demo-grade artifacts
   (layered body-parts + accessories, native↔WebView parity, Rive/Lottie verdict).
6. **Embodied editing presence** (D10) ★ — the companion-follows-the-words design: coords anchoring,
   motion grammar, honesty/restraint, and a real recommendation + graceful fallback. Treat as a
   headline section, not an appendix.
7. **Creation & management UX** (D5) — the robust new 1Code flow + the landing handoff options + recommendation.
8. **Alive/attachment design + anti-uncanny guardrails** (D6).
9. **Honest gating + edit-safety + injection model** (D7).
10. **Performance budgets + robustness/failure table** (D8).
11. **Competitive table + the novel 3–5** (D9).
12. **Phased build order** — a sequenced plan (foundation → presence → edit engine → provenance →
    creation → gating → polish), each phase with a *proven-done* bar (a witnessable behavior, not
    "build green"). Flag what depends on Plan 2 (Editor) and Plan 4 (Icons).
13. **Open questions** — preserved, not auto-resolved (esp. the landing-vs-1Code creation boundary).

## 8. Anti-patterns (do NOT do)
- Do not produce generic "AI assistant" boilerplate. Every section must be specific to *this*
  four-surface, real-state, provenance-backed, Tiptap-WebView companion.
- Do not invent library APIs or product features. Cite or flag as unknown.
- Do not design a second parallel editor, a fake-animated mascot, or silent authority escalation.
- Do not ignore the 1Code-only / MAS-hidden constraint or the "loading ≠ editing" rule.
- Do not resolve the flagged open questions silently — present options + criteria + a recommendation.

─── END RESEARCH BRIEF ───
