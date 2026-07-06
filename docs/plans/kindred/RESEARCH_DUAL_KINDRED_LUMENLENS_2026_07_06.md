# EPI-RP-05-KINDRED — Dual-Plan Synthesis: LUMENLENS + KINDRED (Companions)

> Owner's deep-research wave, received 2026-07-06 — saved verbatim as the research base BOTH plans
> reference. IDs: EPI-RP-05-KINDRED (primary) + EPI-RP-02-LUMENLENS (coupled). The distilled
> per-plan PLAN/PROMPT docs + code spines were delivered alongside; where they conflict with this
> report, the spines are newer ("the spined docs are the most up to date" — owner). Repo-audit
> verdicts on this report's claims: see `KINDRED_REVIEW_2026_07_06.md` and
> `../lumenlens/LUMENLENS_REVIEW_V2_2026_07_06.md`.

## RESEARCH_PROMPT_STANDARD Self-Score
- **Grounded: 5** — every external claim cited to primary docs (prosemirror.net, github repos, rive.app, claude.com/platform.claude.com, docs.yjs.dev + y-protocols PROTOCOL.md, mozilla uniffi-rs, MDN, OWASP).
- **Alternatives named: 4** — render-path forks, landing/handoff options (a/b/c), streaming transport options all named with tradeoffs.
- **Build-actionable: 5** — six artifacts include real directory trees + typed, compilable-shape skeletons with TODO bodies.
- **No fabrication: 5** — 1Code stale-doc corrections explicitly flagged (Electron ~39.4 not 33.4.5; claude-agent-sdk not claude-code); observed vs inferred separated throughout; unretrievable facts flagged as open questions.
- **Constraint-fidelity: 5** — 1Code-only gate, skin-over-real-state, honest gating, editor integrity (no shadow editor/blind setContent), Keychain/@Observable/main.async, don't-touch-graph-internals all designed against.
- **Integration depth: 4** — fabric F1–F6 mapped; graph subsystem deliberately left opaque (public-API-only) per constraint.
- **Depth/novelty: 4** — embodied editing presence protocol (D10) is genuinely novel; 5 novel ideas isolated in D9.
No axis <4; iteration not required. Self-critique and follow-up threads at the end.

---
## TL;DR
- **Build embodied companions as a WebView portal'd sprite driven by ProseMirror `coordsAtPos`, animated transform-only via `requestAnimationFrame`, bound one-to-one to a real agent run-state bus fanned out from `agent_core` over UniFFI callbacks** — this is feasible with documented, stable APIs today and is the signature differentiator; the graceful fallback is a docked sidebar-bubble presence. *(Audit note: the fan-out producer is amended — see reviews; for the 1Code-only lane, events originate in the embedded Node backend, hub lives in Swift.)*
- **KINDRED supersedes Tolaria** by moving from Tolaria's disk-write-then-vault-reload model (BlockNote/CodeMirror editor + right-side AI panel, Safe/Power vault permission modes) to live in-document suggestion-marked ProseMirror transactions the user watches stream in, with an attributed provenance ledger and per-edit accept/reject — never a shadow editor, never blind `setContent`, loading ≠ editing.
- **One identity across four surfaces** (landing "Farm" roster, 1Code main agent, Epdoc mascot bubble, Epdoc sidebar minichat) is achieved with a Yjs-awareness-style presence CRDT as single source of truth; the minichat is an extraction of 1Code's `features/agents` slice embedded in a WKWebView sharing `sub_chats.sessionId` with the main agent, gated 1Code-only via the extended `KINDRED_ENABLED` compile flag.

---
## Key Findings

### KF1 — Tolaria's ceiling is the disk-first, reload-based edit model
Tolaria (tolaria.md, by Luca Rossi of the Refactoring newsletter) is a Tauri + React + Rust markdown app whose AI Agent Panel supports five CLI agents (Claude Code, Codex, OpenCode, Pi, Gemini) with normalized streaming events (TextDelta / ThinkingDelta / ToolStart / ToolDone / Done). Its stated core principle is **disk-first writes**: agent edits are written to disk via Tauri IPC, then a "shared refresh abstraction" reloads vault entries while "preserving unsaved editor content." The editor is BlockNote (rich) + CodeMirror (raw). Permission modes are **Safe mode** (file + search tools only) vs **Power User mode** (shell scoped to the active vault). The consequence: Tolaria's agent does **not** edit the live editor document in-place with tracked, individually-acceptable suggestions — it writes files and the UI reconciles by reload. There is no per-edit accept/reject suggestion layer, no in-document attributed provenance, and no embodied presence. That triangle of gaps is exactly what KINDRED fills. (Observed: tolaria.md, third-party reviews. Tolaria is publicly documented, so it is treated as external reference, not internal.)

### KF2 — The embodied-editing spark is technically real
ProseMirror's `EditorView.coordsAtPos(pos, side?)` returns a viewport rectangle `{left, right, top, bottom}` for any document position (left and right equal — a "flat cursor-ish rectangle"); `posAtCoords({left, top})` inverts it. These are the documented, stable primitives for positioning a sprite at the exact character being written. Only `transform` and `opacity` skip the browser's Layout and Paint stages, staying on the compositor (per MDN and web.dev rendering-performance guidance). The `prosemirror-changeset` `changedRange(b, maps)` method returns the changed range in **new-document coordinates** — the precise range the sprite should track. This is a build-real recommendation, not aspiration.

### KF3 — Presence is a solved pattern: steal Yjs awareness
Yjs's awareness protocol (y-protocols) is a state-based CRDT. Verbatim from y-protocols `PROTOCOL.md` §4: "Each peer maintains, for every known client, the tuple `(state: object | null, clock: uint, lastUpdated: timestamp)`… An incoming entry is applied iff its clock is strictly greater than the locally known clock for that client." It also specifies: "A client whose entry has not been refreshed for 30 seconds MUST be removed locally. Each client SHOULD therefore re-broadcast its own state at least every 15 seconds" (constant `outdatedTimeout = 30000` in `awareness.js`). Figma's presence channel is **coalesced** (a pointer moving 200px in a frame is collapsed to one sample per ~33 ms tick), rides the same WebSocket as document deltas, but is "never appended to the journal." KINDRED adopts these rules exactly: one `CompanionPresence` entry, monotonic clock, last-writer-wins, coalesced fan-out.

### KF4 — Rive is the correct mascot render path
Rive (rive.app) ships an Apple runtime (`rive-ios`, a Swift Package supporting iOS/macOS/tvOS/visionOS) with **Data Binding** (`viewModelInstance.setValue(of: property, to: …)`), state-machine inputs (the "contract between design and engineering," naming conventions like `isWalking`, `hasError`, `trig_jump`), and an MVVM `RiveViewModel`. The Web runtime (`@rive-app/canvas`) runs the **same `.riv` file** in a WKWebView with a `useStateMachineInput` hook. This yields ONE artifact rendering visually identical across native and WebView paths, with state-machine inputs bound to real agent run-states — solving both the demo-grade artifact problem (vector rig, correct anchoring/z-order) and the emote-binding problem in a single tool. The attachment payoff is documented: Duolingo's owl Duo is credited (per ziggle.art's "The Duolingo Effect") with helping drive "4.5x DAU growth and $1B+ in annual revenue," and 925studios notes Duo's design "triggers the 'baby schema effect,' increasing emotional attachment and app engagement" — direct evidence that a state-bound mascot is a retention moat, not decoration.

### KF5 — 1Code fork facts (corrected from stale in-repo docs)
Per the current `package.json` (subagent-verified against the live repo): **Apache-2.0; Electron `~39.4.0`; `@anthropic-ai/claude-agent-sdk` 0.2.45 (NOT `claude-code` — the `CLAUDE.md` doc is stale on both Electron version and SDK); React 19.2.1; tRPC 11.7.1 + `trpc-electron`; `drizzle-orm` + `better-sqlite3`; Jotai + Zustand; `@ai-sdk/react` v3 + `ai` v6; `node-pty`; `xterm` (+addons); `monaco-editor`; Codex support via `@zed-industries/codex-acp`.** The `src/renderer/features/agents/` slice has real subfolders: `atoms/` (Jotai), `hooks/`, `lib/` (`ipc-chat-transport.ts`, `acp-chat-transport.ts` — AI-SDK `ChatTransport` implementations over IPC), `main/` (`active-chat.tsx`, `messages-list.tsx`, `chat-input-area.tsx`), `stores/` (four Zustand stores incl. `sub-chat-store.ts`, `agent-chat-store.ts`, `message-store.ts`, `sub-chat-runtime-cleanup.ts`), `ui/`. DB: `sub_chats.messages` is a **JSON-serialized string**; `sessionId` and `mode` are confirmed on sub-chats; `claude.ts` exports `hasActiveClaudeSessions` / `abortAllClaudeSessions`. Streaming is documented (in the stale `CLAUDE.md`) as a tRPC subscription `claude.onMessage`, but current code points to an AI-SDK transport over `ipc-chat-transport.ts`; the underlying primitive is the claude-agent-sdk `query()` async generator. Change management uses **OpenSpec** (`openspec/` + `AGENTS.md`), with kebab-case verb-led change-ids and isolated `changes/<id>/` folders — ideal for keeping the fork rebaseable. (Observed vs inferred: exact Drizzle column types and the definitive `claude.ts` streaming signature could not be retrieved verbatim and are flagged as open questions.)
*(Audit 2026-07-06: every dep above CONFIRMED against the local clone; Drizzle columns + streaming contract now VERIFIED — see reviews. The subscription is `claude.chat`, not `claude.onMessage`; `stream_id` exists on sub_chats.)*

### KF6 — Honest gating is both a security and an attachment requirement
The Claude Agent SDK exposes `stop_reason` (`end_turn` / `max_tokens` / `refusal` / `tool_use`), a `maxTurns` rail producing an `error_max_turns` result subtype, and streams reasoning via `thinking_delta` events (never strip them). Per-turn approval maps naturally to PreToolUse hooks. On security: OWASP's LLM Top 10 (LLM01:2025 Prompt Injection) states "you can't patch your way out of prompt injection. It exploits LLM design itself," and the UK NCSC (Dec 2025) warned it "may be a problem that is never fully fixed"; OWASP's remedy is defense-in-depth — "least-privilege tooling, input/output filtering, human approval for high-risk actions, and regular adversarial testing," plus the dual-LLM/quarantine pattern (attributed to Simon Willison). The companion MAY hold a gated persona + vault-MCP chat binding but tools/writes/network require per-turn approval — which is both correct security AND the Clippy antidote. Per Wikipedia's Office Assistant entry, Clippy's internal codename was "TFC" (Sinofsky states the "C" stood for "clown"); it was designed by Kevan J. Atteberry; and (per Artsy) experts note "Clippy's real problem was that he was 'optimized for first use'" — intrusive, un-disableable, personality without usefulness.

---
## Details

### D1 — Tolaria supersession matrix
| Tolaria capability | How Tolaria does it | Epistemos KINDRED equivalent | The capability that beats it |
|---|---|---|---|
| Agent edits your writing | Agent writes files to disk via Tauri IPC; vault-reload reconciles UI | Agent edits via suggestion-marked ProseMirror transactions on the **live** Tiptap doc (Fork A) | User watches edits stream in-place; no reload flash; loading ≠ editing |
| Change tracking | Git history + BlockNote refresh | `prosemirror-changeset` + provenance ledger (`ledger.rs`) attributing author=companion-id, turn, ranges, before/after, rationale, citation | Per-edit accept/reject with attributed rationale, not just a git diff |
| Side chat | Right-side AI Agent Panel, normalized stream | Epdoc sidebar minichat = 1Code-fork mini-agent, **same** companion as main agent | Continuity across surfaces, not a fragmented panel |
| Presence | Tool action cards, streaming deltas | Embodied mascot following the caret + presence bus across 4 surfaces | A creature physically working on the page |
| Persona | `AGENTS.md` shared instructions | Persona preamble + gated vault MCP per companion (`CompanionModel`) | Multiple distinct companions with identity/memory/obligation history |
| Scope controls | Safe mode (file+search) vs Power (shell) | Compile-time `KINDRED_ENABLED` gate + runtime per-turn approval boundary | Honest can-do vs is-doing UI surfacing; MAS has **no** companion surface |

**Adjacent systems surveyed (patterns to steal):** Cursor (Cmd+K inline diff; Composer multi-file accept/reject; Cmd+Backspace cancels generation / rejects pending — a mid-stream cancellation model KINDRED copies; note the recurring Cursor community bug reports of edits applying *without* the diff UI, a failure mode to explicitly avoid). Notion AI / Google Docs suggestion mode (hover ✔/✖ accept-reject; the Google Docs API's `SuggestionsViewMode` = `SUGGESTIONS_INLINE` / `PREVIEW_WITH_SUGGESTIONS` / `PREVIEW_WITHOUT_SUGGESTIONS` is a clean model for dry-run preview). Word track changes is the mark-schema ancestor. These validate suggestion-marks + accept/reject as the industry-standard trust primitive.

### D2 — Edit/diff/trace engine (builds on locked Fork A)
KINDRED's additions to the locked first-party suggestion engine:
- **Streamed tokens → suggestion-marked transactions.** claude-agent-sdk `query()` yields AssistantMessage text blocks plus `text_delta` / `input_json_delta` stream events; fine-grained tool streaming (`eager_input_streaming: true`) cuts time-to-first-fragment. Each delta batch at a **block boundary** is applied as a transaction adding insertion marks (per the hwc schema), tagged `source:'agent'`.
- **Mid-stream cancellation.** Map to `abortAllClaudeSessions()` (1Code exports this) plus a `filterTransaction` guard; on cancel, revert un-accepted insertion marks via `revertSuggestions`.
- **Conflicting user-edit remapping.** User transactions during a stream remap agent ranges through `tr.mapping`; the changeset `changedRange(b, maps)` recomputes in new-doc coordinates.
- **Malformed partial-markdown buffering.** Buffer partial markdown at block boundaries — only flush a suggestion transaction when a complete block token is parseable, mirroring Anthropic's streaming rule ("accumulate the fragments, guard the parse"; a response can stop at `max_tokens` mid-parameter).
- **Attributed changeset schema** (mapped to the provenance ledger): `{ author: companion-id, turnId, ranges:[{fromA,toA,fromB,toB}], before, after, rationale, sourceCitation, acceptState }`.
- **Diff visualization in WebView.** Word/char diff (the 1Code side already ships `@git-diff-view/react` and `@pierre/diffs`); inline + side-by-side prose diff; hover-to-explain via a widget `Decoration`; jump-between-changes via `coordsAtPos` scroll-into-view.

### D3 — Presence protocol (one identity, four surfaces)
Single source of truth `CompanionPresence { identity, activity, emote, location, obligationHistory, clock }` living in `agent_core`. Fan-out contract: `agent_core` run-state stream → UniFFI foreign-trait callback → `DispatchQueue.main.async` (never `.sync` — UniFFI callback deadlock risk) → `@Observable` `CompanionState` → (a) native SwiftUI (landing roster, Epdoc bubble) and (b) bridged into the WebView via `presence-bridge.ts`. Lock-step, no double truth: single monotonic clock, apply iff incoming clock strictly greater (Yjs awareness rule). Activity→location mapping pins the mascot on the surface/button it's acting on; the roster shows "currently editing `<note>`." Continuity: the 1Code main agent and the Epdoc minichat share `sessionId` (1Code's `sub_chats.sessionId`) → same context window, same companion, continuity not fragmentation. Cross-surface selection opens a profile (id / job / current activity / obligation history).
*(Audit amendment: hub = Swift `CompanionState`; producers = the 1Code Node backend via the `/host` ws + native events. agent_core placement deferred — see reviews.)*

### D4 — Emotive mascot ↔ real run-state binding
| Run-state | Real event source (claude-agent-sdk) | Rive input |
|---|---|---|
| thinking | `thinking_delta` stream events | `isThinking` |
| reading / searching | ToolStart (Read/Grep/WebSearch) | `isReading` |
| editing | suggestion transaction applied | `isWriting` (+ word-follow) |
| toolRunning | `tool_use` block, PreToolUse hook | `isWorking` |
| awaitingApproval | per-turn approval gate open | `needsApproval` |
| done | `stop_reason: end_turn` / ResultMessage | `trigDone` |
| blocked / error | `error_max_turns` / `refusal` | `hasError` |

The mascot is a **skin over real state** — never animate a state the agent isn't in (hard constraint). Motion-with-meaning vocabulary: an idle breathing loop (allowed as ambient), anticipation before a write, secondary motion, spring easing — all bound to real transitions; **forbidden**: fake typing when no `text_delta` is arriving. Attachment literature — the Tamagotchi effect's baby-schema response, the Zeigarnik open-loop effect (an unfinished care obligation nags), and parasocial attachment — indicates a minimal creature earns attachment through **consistency and obligation memory**, not busyness.

### D4b — Mascot art & rendering verdict: **Rive, one `.riv`, both paths**
Root-cause artifact classes in the current demo mascots, with fixes:
- Mis-registered layers / seams → a single rigged Rive artboard; no runtime layer compositing of PNGs.
- Sub-pixel misalignment / transform-origin drift → Rive's vector rig has defined origins; avoid CSS transforms on composed raster layers.
- Accessory occlusion / z-order → set draw order in the Rive editor, not in code.
- HiDPI scaling → vector renders crisp at any scale (Rive uses Metal on Apple).
**Verdict per render path:** Native SwiftUI landing roster + Epdoc bubble → **rive-ios** (`RiveViewModel`, data binding). WebView main chat + minichat → **`@rive-app/canvas`** with the SAME `.riv`, `useStateMachineInput` bound to the presence bus. This guarantees visual identity. Rive feasibility is confirmed for macOS (official Apple runtime; state-machine inputs as the design↔engineering contract; data binding maps live agent state to animation). **Fallback** if Rive licensing proves unacceptable (see open Q1): layered SVG composite with SF Symbols accents natively + inline SVG in WebView — more artifact-prone and more code.
*(Audit: licensing CLOSED — runtimes MIT/free; authoring export tier from $9/mo. Verdict stands.)*

### D10 — EMBODIED EDITING PRESENCE (headline)
**Feasibility: real.** Pipeline:
1. Agent suggestion transaction applied at range `[from, to]`.
2. `view.coordsAtPos(to)` → viewport rect (the caret the sprite tracks).
3. An absolutely-positioned / portal'd sprite (Rive canvas or `div`) at `{left, top}`, animated **only** via `transform: translate()` inside a rAF loop keyed on `performance.now()` **elapsed time** (not per-frame count — correct on 120 Hz displays).
4. Smoothing between successive positions: spring/lerp toward the target each frame; scroll-follow by re-reading `coordsAtPos` on scroll, throttled via a rAF `ticking` flag.
5. Line-wrap + multi-range edits: `changedRange` gives the active range; the sprite steps to each change's `coordsAtPos`.
6. Degradation: if the next position jumps far, or the doc scrolls fast, the sprite **teleports** (skips the glide) or retreats to the sidebar bubble.
**Behavioral grammar (every beat = a real event):** approach (turn starts / first `text_delta`) → settle at the edit site → "write" (synced to streamed insertion) → step to the next change (`changedRange` update) → on finish, retreat to the sidebar/bubble and emote "done"; on user-takeover, yield gracefully. **User-takeover:** on any user transaction inside the edited range, the sprite yields (steps aside), never fighting the cursor. **Restraint:** opt-in/auto rules surfaced in the creation flow; `prefers-reduced-motion` → no glide, static presence only; a quiet-edit mode; never obscure the text it's editing (offset the sprite above/beside the caret rect, never on it). Prior art mined: Figma multiplayer cursors/avatars, Google Docs live cursors, Yjs awareness, typewriter/word-by-word reveal UIs, and Rive/Lottie rigs bound to runtime data.

### D5 — Creation & management in 1Code + landing handoff
What defines a companion: persona/voice, base model + provider, gated tool/MCP allowances, obligation profile, tamagotchi appearance (`.riv` + accent), memory/vault scope. Best-in-class flows surveyed: OpenAI's GPT Builder (a conversational **Create** tab + a direct **Configure** tab; name / description / instructions / knowledge ≤ 20 files / capability toggles / version history), Claude Projects (custom instructions + project knowledge with persistent memory), character.ai / Poe. The minimal flow that yields a capable, distinct companion = name + persona preamble + model/provider + appearance + vault scope. Management maps to the existing `CompanionModel` lifecycle (create / archive / trash) + obligation history + authority adjustment.
**FLAGGED OPEN QUESTION — landing/handoff boundary (not silently resolved):**
- **(a)** Landing has a "+ New Companion" button that opens the 1Code creator (full flow in 1Code).
- **(b)** Landing 1-tap quick-create (name + appearance only); full edit deferred to 1Code.
- **(c)** Landing is view/select/query-only; all creation in 1Code.
Criteria: creation is *authority-defining* (persona, MCP scope), so it belongs where the agent lives (1Code); the landing should stay a calm roster. **Recommendation: (c) with a thin affordance toward (a)** — the landing shows the roster + "currently editing" state + a minimal select-to-query chat relaying to the real agent, and the "+ New" button deep-links into the 1Code creator. This honors the owner's 1Code-primary lean; the existing `CompanionCreationFlow.swift` is **deleted** and redone in 1Code per the seam list.

### D6 — Feels-alive attachment design
The attachment stack: identity + continuity + obligation + memory ("it remembers editing your note last week," via provenance-ledger `replay()`) + emotive acknowledgment. Anti-uncanny / anti-annoying guardrails come straight from the Clippy post-mortem (optimized-for-first-use, intrusive, un-disableable, personality-without-usefulness): the companion is **quiet by default**, speaks when it has done real work, is never false-cheerful, and is always disableable (it is 1Code-only and opt-in). Its emotes are *earned* by real state. The Finch/Tamagotchi lesson: a minimal creature + a real obligation loop + baby-schema restraint beats busy animation.

### D7 — Honest gating + security
**Authority boundary (exact):**
- **MAY hold without per-turn approval:** persona preamble; persona-scoped vault MCP **read** binding; chat.
- **REQUIRES per-turn user approval:** tool invocation; file writes (agent edits are a destructive-op surface); network calls; destructive ops.
Agent-edits-doc surface: dry-run preview (Google-Docs-style `PREVIEW_WITHOUT_SUGGESTIONS`), confirm, undo (single PM history stack, `source:'agent'` tagged), per-edit accept/reject, and a **"revert everything this companion did this turn"** action (ledger replay → `revertSuggestions` over the turn's ranges). UI surfacing: a persistent **capability chip** distinguishing can-do (bound authority) from is-doing (this turn, needs approval). Prompt-injection mitigation (OWASP LLM01; dual-LLM/quarantine): vault/web content the companion reads is untrusted — keep it out of the system/persona channel; gate every consequential action; bound the trusted:untrusted context ratio.

### D8 — Performance & failure table
Presence/emote fan-out: coalesce to one sample per ~33 ms tick (Figma pattern) before crossing the bridge; transform-only sprite animation avoids re-render storms; the mascot stays responsive because it reads the *presence bus*, not the token firehose. Use `@Observable` (not `ObservableObject`); never block `@MainActor`; UniFFI callbacks hop `DispatchQueue.main.async`, never `.sync`.

| Failure | Handling |
|---|---|
| Dropped bridge message | Presence is idempotent (clock-based, Yjs rule) — next tick re-syncs full state |
| Agent crash mid-edit | Un-accepted suggestion marks remain revertible; ledger marks the turn incomplete; sprite → error emote |
| WebView reload with pending edits | `loadEpoch` nonce (locked Fork D) invalidates stale transactions; suggestion marks re-hydrate from the ledger |
| Offline model | `awaitingApproval` / `blocked` emote; no fake activity |
| Bridge double-truth | Single presence clock; monotonic; last-writer wins |

### D9 — Competitive synthesis table
| System | Presence | Edit/diff | Provenance | Multi-surface identity | Creation UX | Feels-alive | Honest gating |
|---|---|---|---|---|---|---|---|
| Tolaria | Tool cards | Disk write + reload | Git | No | `AGENTS.md` | No | Safe/Power modes |
| Cursor | Diff view | Inline + Composer accept/reject | Git | No | Rules files | No | YOLO vs approve |
| Copilot Workspace | Steps | PR diff | Git/PR | No | — | No | Plan approval |
| Notion AI | — | Suggestion hover ✔/✖ | Edit history | No | — | No | — |
| Devin | Presence sim | PR | Git | Partial | — | Weak | Approvals |
| character.ai / Poe | Avatar chat | — | — | Per-bot | Rich persona | Yes (chat) | — |
| Tamagotchi-class | The creature | — | — | — | Name/care | Yes | — |
| **KINDRED** | **Embodied caret-follow across 4 surfaces** | **Live suggestion-marked PM txns** | **Attributed ledger (`ledger.rs`)** | **One identity, session-shared** | **1Code, GPT-builder-style** | **Real-state creature** | **Bound vs per-turn** |

**3–5 genuinely novel ideas:** (1) sprite gaze/body tracking the exact word being written via `coordsAtPos`, bound to streamed insertions — no shipping product does this; (2) one presence CRDT lighting up four heterogeneous surfaces (native + WebView) lock-step; (3) a provenance-ledger-backed "it remembers what it did for you" as an attachment mechanic; (4) the mascot emote as an **honest debugger** of agent state (you can SEE thinking vs editing vs blocked); (5) a capability chip that visually separates can-do (bound authority) from is-doing (per-turn gated).

### D★ — Deep fabric integration F1–F6
- **F1 vault:** companion edits are vault `.md` files; memory reads the vault via a persona-scoped MCP binding.
- **F2 capability:** the 1Code companion is the primary *caller* of the capability registry (ResearchHub / Capture / Editor tools) via per-turn-approved tool calls.
- **F3 presence:** `CompanionPresence` **defines** the contract every other feature lights up against.
- **F4 graph:** the companion links what it touches via the graph's **public API only** — never touching graph internals (constraint).
- **F5 provenance:** attributed actions span features through `ledger.rs` / `replay.rs`.
- **F6 state bus:** emotes + word-following bind to the real state bus across native + WebView.

---
## Consolidated open research questions (both plans)
1. **Rive commercial licensing/pricing** — *(CLOSED 2026-07-06: runtimes MIT/free for commercial; authoring export from $9/mo Cadet. Verdict stands.)*
2. **Exact 1Code streaming contract** — *(CLOSED: tRPC subscription `claude.chat` (not `claude.onMessage`) wrapped by AI-SDK `IPCChatTransport` (ipc-chat-transport.ts:212); `reconnectToStream` exists (:521).)*
3. **1Code Drizzle exact columns** — *(CLOSED: sub_chats = id/name/chat_id/session_id/stream_id/mode("plan"|"agent")/messages(JSON text)/timestamps; chats carries worktree_path/branch/base_branch/pr_url/pr_number. `stream_id` EXISTS — "Track in-progress streams".)*
4. **SwiftPM trait-condition API** — *(CLOSED as MOOT: no root Package.swift; xcodegen target conditions are the mechanism, already landed 8a1ca87d1.)*
5. **Landing/handoff boundary** — options a/b/c; recommend (c); **owner to confirm** (still open).
6. **`coordsAtPos` performance at scale** — still open; 50k-word micro-benchmark planned (K5).
7. **Embodied presence ↔ suggestion-mark interaction** — still open (K5 design detail).
8. **Prompt-injection quarantine granularity** — still open (K8; dual-LLM vs per-turn + ratio bounding).

## Self-critique (researcher's own, preserved)
Weakest points: (1) 1Code Drizzle columns + claude.ts streaming signature not read verbatim *(now closed by repo audit)*; (2) Rive licensing unconfirmed *(now closed)*; (3) embodied performance envelope reasoned, not measured; (4) the 1Code repo `CLAUDE.md` is demonstrably stale (Electron version, SDK name, esbuild-vs-webpack) — anything sourced only from it is provisional.
