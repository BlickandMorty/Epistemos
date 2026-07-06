# PLAN — KINDRED (Companions)
ID: EPI-RP-05-KINDRED · Codename: KINDRED · Compiled 2026-07-06 · 1Code/Experimental only
Research base: `RESEARCH_DUAL_KINDRED_LUMENLENS_2026_07_06.md` (read before building).
Amendments: §K-AMEND at the end (repo-audited 2026-07-06 — BINDING; overrides the body where they conflict).

## Executive thesis
A companion is ONE living agent identity that appears across four connected surfaces —
landing Farm roster, 1Code main agent, Epdoc mascot bubble, Epdoc sidebar minichat — and
jumps to wherever it is actually working. On the editor it feels like a real creature
physically editing the document: its body tracks the exact word being written, gliding along
the caret, resting when idle. The mascot is a static+emotive SKIN over real streamed agent
run-state — never fake animation. This supersedes Tolaria (a disk-write-then-reload agent
panel) with in-document suggestion-marked edits, honest provenance, multi-surface identity,
and embodied presence — inside a Tiptap WebView driven by a real agent loop.

## D1 — Tolaria supersession (matrix)
Tolaria (tolaria.md, Tauri+React+Rust) writes agent edits to disk, then reloads the vault
("disk-first," "preserving unsaved editor content"), with Safe/Power permission modes and a
right-side AI Agent Panel over five CLI agents. Its ceiling: no per-edit accept/reject
suggestion layer on the live doc, no in-document attributed provenance, no embodied presence.

| Tolaria | KINDRED equivalent + the beat |
|---|---|
| Disk write + vault reload | Live suggestion-marked ProseMirror transactions; no reload flash; loading != editing |
| Git change tracking | changeset + provenance ledger: author=companion-id, turn, ranges, before/after, rationale, citation, accept-state |
| Right-side AI panel | Epdoc sidebar minichat = SAME companion as the main agent (continuity) |
| Tool action cards | Embodied mascot following the caret + presence across four surfaces |
| AGENTS.md persona | Per-companion persona + gated vault MCP + identity/memory/obligation history |
| Safe/Power modes | Compile-time 1Code gate + runtime per-turn approval; MAS has NO companion surface |

Patterns stolen (cited in research): Cursor (inline diff review, Cmd+Backspace cancel — and
its failure mode of edits applying WITHOUT the diff, which we explicitly avoid); Notion AI /
Google Docs suggestion mode (hover accept/reject; SUGGESTIONS_INLINE vs PREVIEW modes for
dry-run); Word track changes (mark-schema ancestor).

## D2 — Edit/diff/trace engine (builds on LUMENLENS Fork A)
Companion streamed tokens enter as suggestion-marked transactions the user watches, batched
at block boundaries. Mid-stream cancel maps to abortAllClaudeSessions + revert of unaccepted
insertion marks. Conflicting user edits remap agent ranges through tr.mapping; changedRange
recomputes in new-doc coords. Malformed partial markdown is buffered until a complete block
token parses. Attributed changeset -> LUMENLENS provenance ledger. WebView diff UX: word/char
diff (the 1Code side already ships @git-diff-view/react + @pierre/diffs), inline + side-by-side
prose diff, hover-to-explain via a widget Decoration, jump-between-changes via coordsAtPos.

## D3 — Presence protocol (one identity, four surfaces)
Single source of truth: CompanionPresence { identity, activity, emote, location,
obligation_history, clock } in agent_core. Fan-out: agent_core run-state stream -> UniFFI
callback -> DispatchQueue.main.async -> @Observable CompanionState -> native surfaces + a
WebView bridge. Model = Yjs awareness (one entry, monotonic clock, last-writer-wins, coalesced
~33ms fan-out). Jump-to-where-it-works: activity->location mapping pins the mascot on the
surface it's acting on; the roster shows "currently editing <note>". Continuity: the main
agent and the minichat share sessionId (1Code sub_chats.sessionId) -> same context window,
same companion. Cross-surface selection opens the profile (id/job/current activity/history).
*(→ K-AMEND 1: hub = Swift CompanionState; producers = Node backend via /host ws + native
events; the agent_core placement is deferred to schema/June-future.)*

## D4 — Emote state machine (skin over real state)
Run-states -> Rive inputs: thinking->isThinking, reading/searching->isReading,
editing->isWriting(+word-follow), toolRunning->isWorking, awaitingApproval->needsApproval,
done->trigDone, blocked/error->hasError. Each is produced ONLY by a real claude-agent-sdk
event. Motion-with-meaning: idle breathing loop (ambient, allowed), anticipation before a
write, spring easing on transitions — all bound to real events. Forbidden: fake typing with
no text_delta arriving.

## D4b — Mascot art verdict: Rive, one .riv, both paths
Native = rive-ios (RiveViewModel + data binding). WebView = @rive-app/canvas with the SAME
file. One vector rig -> visually identical + kills demo-grade artifacts (seams, sub-pixel
misalignment, transform-origin drift, HiDPI jaggies) because there is no runtime PNG
compositing. State-machine inputs are the design<->engineering contract; accessories are
fixed-anchor layers set in the editor. Attachment payoff is documented (mascot-as-retention).
*(→ K-AMEND 5: licensing CLOSED — runtimes MIT/free; authoring export from $9/mo. Verdict stands.)*

## D10 — Embodied editing presence (headline)
coordsAtPos(pos) -> viewport rect for the write head; an absolutely-positioned/portal'd Rive
sprite animated transform-only in a rAF loop keyed on elapsed time (correct at 120Hz);
spring/lerp toward target; scroll-follow throttled to one read per frame; teleport on far
jumps; retreat to the sidebar bubble on turn end. Behavioral grammar: approach (first
text_delta) -> settle at the first range -> write (synced to streamed insertions) -> step to
the next change (changedRange) -> retreat on stop_reason:end_turn -> emote done. User-takeover:
yield on any user transaction inside the edited range — never fight the cursor. Restraint:
opt-in/auto, prefers-reduced-motion (no glide), quiet-edit mode, never obscure the edited text
(sprite offset above the caret). Fallback if full word-following is too costly: sidebar-bubble
presence.

## D5 — Creation & management in 1Code + landing handoff (OPEN QUESTION preserved)
Robust flow (durable persistence, re-edit every attribute, templates/presets, validation,
duplication, graceful missing-provider handling). Defines: persona/voice, base model+provider,
gated tool/MCP allowances, obligation profile, tamagotchi appearance (.riv+accent), memory/
vault scope. Best-in-class surveyed: OpenAI GPT Builder (conversational Create + direct
Configure tabs, version history), Claude Projects (instructions + persistent knowledge). The
old CompanionCreationFlow.swift is DELETED; creation moves to 1Code.
LANDING HANDOFF — options, not silently resolved: (a) landing `+` opens the 1Code creator;
(b) 1-tap quick-create on landing, full edit in 1Code; (c) landing view/select/query only.
Criteria: creation is authority-defining (persona, MCP scope) so it belongs where the agent
lives. RECOMMENDATION: (c) with a thin `+` deep-link toward (a). Owner leans 1Code-primary;
owner confirms.

## D6 — Feels-alive attachment + anti-uncanny
Attachment stack: identity + continuity + obligation + memory ("it remembers editing your
note last week," via ledger replay) + emotive acknowledgment. Anti-Clippy guardrails (Clippy
was optimized-for-first-use, intrusive, un-disableable, personality-without-usefulness): the
companion is quiet by default, speaks when it has done real work, never false-cheerful, always
disableable (1Code-only + opt-in), emotes only what's real.

## D7 — Honest gating + security
Bound (no per-turn ask): persona preamble; persona-scoped vault-MCP READ; chat. Gated (per-turn
approval): tool calls, file writes (agent edits ARE destructive), network, destructive ops.
Agent-edits-doc safety: dry-run preview, confirm, undo (single source-tagged stack), per-edit
accept/reject, revert-everything-this-turn (ledger replay). Prompt-injection (OWASP LLM01
defense-in-depth; dual-LLM/quarantine): untrusted vault/web reads never enter the persona
channel and never authorize a gated action by themselves; bound the trusted:untrusted ratio.
UI: a capability chip separating can-do (bound) from is-doing (this turn).

## D8 — Performance + failure table
Coalesce presence to ~33ms before crossing the bridge; transform-only sprite; the mascot reads
the presence bus, not the token firehose. @Observable not ObservableObject; never block
@MainActor; UniFFI callbacks main.async never .sync.
Dropped bridge message -> idempotent clock-based presence re-syncs next tick. Agent crash
mid-edit -> unaccepted suggestion marks remain revertible; sprite -> error emote. WebView reload
with pending edits -> loadEpoch invalidates stale transactions; marks re-hydrate from the ledger.
Offline model -> awaitingApproval/blocked emote, no fake activity.

## D9 — Competitive synthesis + novel ideas
Compared: Tolaria, Cursor, Copilot Workspace, Notion AI, Devin, character.ai/Poe, Mem/Reflect,
tamagotchi-class. Novel 3-5: (1) sprite gaze/body tracking the exact word via coordsAtPos bound
to streamed insertions — no shipping product does this; (2) one presence CRDT lighting up four
heterogeneous native+WebView surfaces lock-step; (3) ledger-backed "it remembers what it did for
you" as an attachment mechanic; (4) the mascot emote as an honest debugger of agent state; (5) a
capability chip separating can-do from is-doing.

## D-star — Deep Fabric F1-F6
F1 vault: companion edits are vault .md; memory reads the vault. F2 capability: the companion is
the primary CALLER of the registry (ResearchHub/Capture/Editor) via per-turn-approved tools. F3
presence: the companion DEFINES the presence contract. F4 graph: links what it touches via the
PUBLIC API only. F5 provenance: attributed actions span features via ledger.rs. F6 state bus:
emotes + word-following bind to the real state bus across native + WebView.

## Phased build order (witnessable proven-done bars)
- **K0 Gate.** DONE: MAS build has zero companion surface; leak-detector CI row proves no
  companion symbols in the defaults build; #error fires if companion code compiles without the flag.
- **K1 Run-state bus.** DONE: the mascot emote changes ONLY when a real claude-agent-sdk event
  fires (test: no event -> no emote change).
- **K2 Presence fan-out.** DONE: the same identity shows consistent state on all four surfaces;
  a dropped message self-heals on the next tick.
- **K3 Mascot render.** DONE: one companion.riv renders identically native (rive-ios) + WebView
  (@rive-app/canvas); no seams/clipping at 1x/2x.
- **K4 Suggestion streaming.** DONE: the user watches edits stream in, accepts/rejects each, and
  cancels mid-stream cleanly. (Depends on LUMENLENS L1.)
- **K5 Embodied presence.** DONE: the sprite tracks the exact word as it's written; degrades on
  fast scroll; respects prefers-reduced-motion; yields to the user; never covers edited text.
- **K6 Minichat extraction.** DONE: the minichat and the main agent are provably the same
  companion (shared session/context). (Fork extraction from .research-clones/1code.)
- **K7 Creation/management in 1Code.** DONE: create -> a distinct companion appears on the roster
  with correct authority; old CompanionCreationFlow.swift deleted.
- **K8 Gating/security UI.** DONE: a file write is provably blocked until approved; revert removes
  all of a turn's suggestions; injected note text authorizes nothing.

## Dependencies on other plans (external seams)
- LUMENLENS (EPI-RP-02): SuggestionAdapter ingestion, provenance ledger, epoch-stamped bridge.
- SIGILRY (EPI-RP-04, Icons): the mascot art identity / rig assets feed here (K3).

## Open questions (preserved)
1. Landing/handoff boundary — options a/b/c; recommend (c); owner confirms.
2. Rive runtime licensing/pricing — *(CLOSED: runtimes MIT/free; Cadet $9/mo export. K-AMEND 5.)*
3. Exact 1Code streaming contract — *(CLOSED: `claude.chat` subscription wrapped by
   IPCChatTransport; reconnectToStream exists. K-AMEND 6.)*
4. 1Code Drizzle exact columns — *(CLOSED: session_id + stream_id + mode + messages(JSON) on
   sub_chats; worktree/branch/pr on chats. K-AMEND 6.)*
5. coordsAtPos performance on very large docs / fast scroll — micro-benchmark on a 50k-word doc.
6. Embodied sprite vs suggestion-mark: track the insertion mark's leading edge or the caret;
   behavior across multiple simultaneous edit ranges.
7. Prompt-injection quarantine granularity — dedicated quarantine LLM (dual-LLM) vs per-turn
   approval + context-ratio bounding.

## Self-critique + rubric
Weakest points: 1Code Drizzle columns + current claude.ts streaming signature not read verbatim
(inferred, flagged) *(both now CLOSED by repo audit)*; Rive licensing unconfirmed *(CLOSED)*;
embodied performance envelope reasoned not measured; the repo's CLAUDE.md is stale (Electron
version, SDK name) so anything sourced only from it is provisional. Rubric (1-5): Grounded 5 ·
Alternatives 4 · Build-actionable 5 · No fabrication 5 · Constraint-fidelity 5 · Integration
depth 4 · Depth/novelty 4. No axis < 4.

---

## §K-AMEND — Repo-audited binding amendments (2026-07-06; full evidence in `KINDRED_REVIEW_2026_07_06.md`)

1. **Presence placement (D3 corrected).** agent_core has ZERO connection to the 1Code backend.
   v1: producers = the Node backend (claude-agent-sdk events in claude.ts → electron-shim →
   **`/host` ws frame `{kind:"presence:state"}`** → one new case in
   `ExperimentalHostBridge.handle(kind:)` (:84)) + native events (KEELSTONE F3 reconcile states);
   **hub = `CompanionState.swift`** (@Observable, clock-guarded, Yjs rules); consumers = SwiftUI +
   both WebViews. `run_state.rs`/`presence.rs` = wire schema reference + future June lane, NOT v1
   Rust code. K1/K2 are built on the /host seam, not UniFFI.
2. **K0 is largely landed** (KEELSTONE `8a1ca87d1`): flags on all Epistemos-target configs,
   AppSurface guards live. Residual K0 = the KINDRED guard pair (`spine/CompanionEditGate.swift`),
   the `#if KINDRED_ENABLED` file-wrapping sweep, the CI leak-detector job (build
   `Epistemos-AppStore` + symbol scan in the EXISTING .github/workflows/ci.yml), and the JS gate
   (amendment 4).
3. **CompanionModel is EXTENDED, never rewritten** — new fields optional/defaulted (SwiftData
   lightweight migration; no VersionedSchema exists; users have rows). The v1.6 cosmetic-only
   doctrine comment (:7-11) is DELIBERATELY superseded — rewrite it to bound-vs-gated in the same
   commit. Coupled sites: CompanionRosterEntry, CreationFlow:322 (deleted K7), identityHash
   recompute, DeterministicPRNG seed. Lifecycle stays in CompanionState.swift.
4. **JS bundle gate = native injection.** One webpack bundle serves both targets (no DefinePlugin).
   companion JS is inert unless Swift (#if KINDRED_ENABLED) injects the bootstrap; MAS never
   injects. Optional follow-up: DefinePlugin second bundle for AppStore.
5. **Rive:** runtimes MIT/free (commercial OK); authoring export from $9/mo Cadet. Add the
   RiveRuntime SPM product to the **Epistemos target only** in project.yml + xcodegen. Verdict stands.
6. **Minichat grounding (verified):** reuse THE supervisor backend (one Node child, ledgered,
   reaped) — never a second backend; sessions are server-side. Streaming = tRPC subscription
   **`claude.chat`** wrapped by `IPCChatTransport` (NOT `claude.onMessage`); `reconnectToStream` +
   `sub_chats.stream_id` exist for resume; `abortAllClaudeSessions` at claude.ts:304. Fix the
   single-webview `ExperimentalStateBridge` assumption (per-webview routing) as a K6 work item.
7. **Two producers, one suggestion schema:** KINDRED feeds LUMENLENS's SuggestionPayload from the
   Node backend; June feeds it from agent_core/UniFFI. LUMENLENS owns the schema.
8. **Order:** KEELSTONE 0-4 → LUMENLENS L0-L5 → K4/K5. K0-residual + K1-K3 may run parallel to
   LUMENLENS. Landing/handoff (D5) needs the owner's call before K7.
9. **RECKONER seam (Plan 9 Data tab, `EPI-RP-09-RECKONER`) — the fifth place the companion works.**
   Plan 9's canon (`docs/prompts/PROMPT_PLAN_9_DATA_TABLES.md`) specifies an **in-tab agent chat**:
   that chat IS this companion — reuse the K6 minichat pattern (same shared-backend WKWebView,
   same `sub_chats.sessionId` continuity, same presence bus), NEVER a third chat system. The
   presence contract extends naturally: `Location.surface` gains a `dataTab` case; the mascot pins
   on the Data room while restructuring tables; dry-run→confirm→undo for agent table restructuring
   follows the same D7 gating (per-turn approval; revert-turn). KINDRED builds the pattern; Plan 9
   consumes it as an external seam — do not build Data-tab UI here.
