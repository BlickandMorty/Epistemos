# Entry-Point Routing Inventory — 2026-06-24

> Read-only recon for authority hardening item #4 ("stabilize visible entry points") and a head-start on
> item #2 ("Work session schema / mini sessions"). Verified against current code on `main`. Companion to
> `docs/handoffs/HARDENING_NO_VAULT_HONESTY_LEDGER_2026_06_24.md` and the ACT_OSAURUS study handoff.

## The five Act entry points — engine / renderer / session / drift

| Surface | Entry point | Engine path | Renderer | Session identity | Drift / gap |
|---|---|---|---|---|---|
| **Main act chat** | `ChatView.submitMainChatQuery` (ChatView.swift:623) → `if actUsesOsaurus && LocalAgentLoop.shouldRouteActThroughOsaurus()` → `chat.runActOsaurusTurn` (ChatView.swift:631-632) | `ChatState.runActOsaurusTurn` (ChatState.swift:740) → `SharedActInference.actEventStreamIfArmed` → **`ActTurnStreamCore.consume`** (ChatState.swift:819) | native `ChatView` (`messages`/`streamingText`) | unified `SDChat` via `persistActTurn`→`ChatCoordinator` | **CANONICAL** — the reference surface |
| **Mini chat** | `MiniChatInputBar(chatID:)` (MiniChatView.swift:66) | `SharedActInference.actEventStreamIfArmed` (MiniChatView.swift:2502) → **`ActTurnStreamCore.consume`** (MiniChatView.swift:2519) | `MiniChatThread` (its OWN renderer) | `ThreadState.miniChatSession(id: chatID)` (flat, keyed by chatID `String`); persists to `SDChat`; `AppBootstrap.loadChat` | **shares ENGINE + stream core** with main (0.49b unification), but OWN state (`ThreadState`/`ChatThread`) + OWN renderer/input bar; **NO parentSessionID linkage** (see item #2 gap) |
| **Graph chat** | `HologramSearchSidebar.swift:1255` posts `NotificationCenter .submitActOsaurusPrompt` | bounces to **main act** (no own engine) | main act | main act's | escalation-only; no own engine/state — coherent, not stranded |
| **Note chat** | `NoteDetailWorkspaceView.swift:2566` posts `.submitActOsaurusPrompt` | bounces to **main act** (no own engine) | main act | main act's | escalation-only; same pattern as graph |
| **Landing search** | `LandingView` `landingSearchText` (:128); "Act search page" mode (:85); reveal/typewriter/blur anims (:155-156) | submits into the act/chat path | `LandingView` (Epistemos reveal IP) | — | IP-preserving (blur/typewriter reveal); search-page is a real mode |
| **Click-anywhere-to-search** | `LandingView.swift:363-373` — `.onTapGesture` on empty landing area opens the search popover (with outside-click dismiss handling) | → search popover | search popover | — | implemented; honors inline-picker dismiss |

## Findings

### Authority item #4 (stabilize visible entry points) — largely COHERENT
All six entry points exist and route deterministically. No stranded/dead chat stubs in the routing:
main act is canonical; mini shares the engine+core; graph/note escalate to main via the single
`.submitActOsaurusPrompt` notification; landing search + click-anywhere are implemented with the
Epistemos reveal IP intact. The ENGINE drift that the ACT handoff warned about is already resolved
(`ActTurnStreamCore.consume` is shared by main + mini; tested invariant in
`OntologyRefactorRegressionGuardTests.actSurfacesShareStreamingCore`). What remains is **state/render
drift**: mini chat keeps its own `ThreadState`/`ChatThread` + `MiniChatThread`/`MiniChatInputBar`,
parallel to main's `ChatState`/`ChatView`/`ChatInputBar`.

### Authority item #2 (Work mini-session schema) — the PRIMITIVE already exists; the UI doesn't use it
The authority's mini-session ontology (main session = tab/root; **attached** mini = child with
`parentSessionID`; **detached** = same child shown floating; recents show parent linkage;
duplicate-window prevention) is NOT wired into the mini-chat UI today. BUT a parent/child session
primitive ALREADY EXISTS in the Vault/agent layer (audit-first — do not rebuild it):
- `Epistemos/Vault/AgentSessionLineageStore.swift` — `parentSessionID: String?`,
  `parentSessionID(forChatThread:)`, emits `parent_session_id` JSON.
- `Epistemos/Vault/ConversationPersistence.swift` — `parentID: UUID?`.
- `Epistemos/Vault/SessionBrowser.swift:156-161` — parent/child session browsing.

The mini-chat UI's session model is `ThreadState.miniChatSession/ensureMiniChatSession/
upsertMiniChatSession` (ThreadState.swift:68-85), keyed flat by `chatID: String`, returning a
`ChatThread` with NO parent field. **Gap = bridge the mini-chat `ThreadState`/`ChatThread` model to the
existing `AgentSessionLineageStore` parent/child lineage**, then add attach/detach/promote +
focus-existing (duplicate-window prevention) semantics. This is a multi-fire build and the core of
Phase 2's mini-session product model; it should start from `AgentSessionLineageStore`, not a rewrite.

## Suggested next increments (all static / no external clone)
1. Map `ThreadState`/`ChatThread` fields vs `AgentSessionLineageStore`/`ConversationPersistence` to design
   the minimal `parentSessionID` bridge for mini sessions (a parity sub-ledger).
2. Inventory `MiniChatWindowController` for existing duplicate-window / focus-existing behavior (the
   authority requires "opening the same mini session focuses the existing surface, not a ghost").
3. Recents: confirm whether the unified recent-chats popover (0.48b) already distinguishes main vs mini
   rows, and whether it can show parent linkage.

(Runtime/visual proof of any of this still needs an owner-driven launch.)
