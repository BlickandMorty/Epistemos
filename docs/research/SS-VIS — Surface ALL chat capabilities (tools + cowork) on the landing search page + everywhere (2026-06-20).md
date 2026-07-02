# SS-VIS — Surface ALL chat capabilities (tools + cowork) on the landing search page + everywhere (2026-06-20)

Owner: *"I want the tools and cowork stuff — all the things attached to the chat — to be VISIBLE on the search page,
because if the user wants to start off using a tool they should be able to. Also they are not working. The ~50 tools I
always talk about should be there (maybe in a popover still) + the cowork stuff — literally ALL capable chat stuff should
be not only in the chat but on the search page and all places it should be. This falls under the HIDDEN RULE where things
are muddy and hidden, meaning our checks have NOT been working. This is a huge thing."* Code-grounded (Explore, file:line).
NON-INVASIVE, safe-additive (reuse the existing picker; one source of truth). Cross-ref SS-CLEAN (hidden/surface-parity gap).

## Ground truth — nothing is broken; the picker is just only mounted in chat
- **Single source of truth (already app-wide):** `AgentCommandCenterState.availableTools` (`State/AgentCommandCenterState.swift:153`)
  ← `ToolTierBridge` (`Bridge/ToolTierBridge.swift:405 loadTools / :241 surfacedTools`) ← Rust `agent_core/src/tools/registry.rs`
  (~50+ surfaced tools; MAS allowlist = 33 at `ToolTierBridge.swift:194-235`). Refreshed at `AppBootstrap.swift:2591-2596`.
- **The chat picker (reuse this):** `AgentToolTogglePanel` (`Views/Chat/AgentToolTogglePanel.swift`) — takes
  `(agentCommandCenter, theme, onRunSkill)` (`:16-22`) and ALREADY renders tools grouped by agent + MCP servers + COWORK
  connectors + skills, purely from the injected state. Opened in chat from `ChatInputBar.swift:1497 toolPanelButton` →
  popover `:1508`, gated `!availableTools.isEmpty` (`:1131`).
- **Cowork (chat-only today):** `Views/Chat/CoworkPanel.swift` (opened `ChatInputBar.swift:1047`), `CoworkContextPanel.swift`
  (`:1028`), `Engine/CoworkChatMode.swift` (Chat/Act axis; toggle in `RootView.swift:1699-1725` — chat surface only),
  `CoworkConnectorDirectory`/`CoworkRunContext`/`ComposerMessageQueue`. Computer-use (`macos.interact/perceive/screen_watch`)
  surfaces only through the same tool list.
- **The landing search page:** `Views/Landing/LandingView.swift` (2813 lines). Search field `landingSearchInputLine:1221`;
  submit `submitLandingSearch():1890` ALREADY starts a real chat (`chat.startNewChat() :1906` → `MainChatSubmissionRouter.submit :1916`).
  Its only tool affordance is fixed chips in `landingSearchExpandedToolRow:1086` (Command/Mention/Attach/Saved/AllNotes/voice)
  — it does NOT list the ~50 tools or cowork. A grep of LandingView for `AgentToolTogglePanel|CoworkPanel|toolPanelButton`
  returns NOTHING.
- **WHY "not working"/hidden:** NO flag, nothing broken — the picker views are simply not mounted on landing. Landing even
  already injects `agentCommandCenter` (`:87`) and reads `availableTools` for the Farm/Companion flow (`:430`) — so the tools
  "exist but don't show up" on search purely because the picker isn't placed there. Pure surface-asymmetry.

## Fix — safe-additive: mount the EXISTING picker on the search surface (one registry, one picker)
1. **Landing tools/cowork launcher [S→M]:** add a "Tools / Cowork" button into `landingSearchStageTools` (`LandingView.swift:943`)
   or `landingSearchExpandedToolRow` (`:1086`), modeled on the existing in-flow `InlineRuntimePicker` toggle (`:955,:992`).
   Present `AgentToolTogglePanel(agentCommandCenter:theme:onRunSkill:)` — IDENTICAL to `ChatInputBar.swift:1508`. No new tool
   list (single source of truth). Popover is fine (owner: "maybe in a popover still").
2. **Start-with-a-tool handoff [S]:** selecting a tool/cowork action sets the chosen tool enabled + (for cowork/act) sets
   `CoworkChatMode`/operating mode = act, THEN calls the existing `submitLandingSearch()` (`:1890`) so the session starts a
   chat already armed with that capability. The handoff plumbing exists (`startNewChat` + `MainChatSubmissionRouter.submit`).
3. **Cowork panel parity [S-M]:** optionally surface `CoworkPanel`/`CoworkContextPanel` from landing the same way chat does
   (reuse, don't clone), OR fold cowork actions into the same launcher popover. Keep it minimal (owner: granular-but-minimal).
4. **"All places it should be" [M]:** audit every surface that should expose capabilities (mini-chat, graph tunnel chat,
   Epdoc/code mini-chat) and mount the SAME panel where a user could "start off using a tool." MiniChat already targets
   surfaces (`MiniChatTarget`); ensure its tool affordance reaches the full catalog too.

## Verify they actually WORK from search (owner: "they are not working")
Beyond surfacing: confirm a tool launched from search actually executes end-to-end (the catalog populates — check the tool
count is non-zero per tier; if empty on launch, that's the `rebuildToolCatalog` timing / tier-gating, not the picker). Test:
launching a tool from the landing picker enables it + starts a chat that can invoke it; cowork/act mode reaches the device-
agent stack. Honest capability gating (local fast/think; cloud agent/liveAgent) preserved.

## Order
[S→M] (1)+(2) landing tools/cowork launcher reusing AgentToolTogglePanel + the submit handoff (the owner's core ask) →
(3) cowork panel parity → (4) sweep the other surfaces. Each test-backed; single targeted swift build. NON-INVASIVE; one
registry + one picker. Cross-ref SS-CLEAN (the surface-parity scan that should have caught this), SS-HW (mini-chat surface
targeting), SS-BWB (unified surfaces).

Sources: Explore code map (file:line above) — LandingView, ChatInputBar, AgentToolTogglePanel, CoworkPanel/ChatMode,
AgentCommandCenterState, ToolTierBridge, agent_core/src/tools/registry.rs.
