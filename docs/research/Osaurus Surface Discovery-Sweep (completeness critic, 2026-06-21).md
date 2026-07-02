---
id: D86EEE06-B82E-4923-8B1E-C3FF03B8B450
title: Osaurus Surface Discovery-Sweep (completeness critic, 2026-06-21)
---

# Osaurus Surface Discovery-Sweep (completeness critic, 2026-06-21)

Mandated by the addendum "COMPLETENESS / DISCOVERY-SWEEP" rule: enumerate EVERY consumer
of the chat backend / inference / model picker / tools, so the chat→act upgrade misses
nothing. Grounded in greps over `Epistemos/` (not memory). Each surface is classified:
**ACT** (gets the chat→act/Osaurus upgrade via the shared composer) · **SHARED** (a
backend dependency to route through act, not a UI surface) · **PORT** (quarantined chat
logic/IP to port) · **OUT** (out-of-scope, with reason).

## A. Distinct prompt-sending CHAT surfaces → ALL get ACT (one shared composer)


| Surface       | Primary file(s)                                                                                                                                                                                                               | Notes                                                                                                               |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Main chat     | `Views/Chat/ChatView.swift` + `ChatInputBar`, `ChatBrainPickerMenu`, `ChatSidebarView`, `InlineRuntimePickerPanel`, `AgentToolTogglePanel`, `SlashCommandPopover`, `Composer*` (CurrentAccessPlan/MicButton/ReferenceBrowser) | The reference UI act reskins. The `Composer*` family + InputBar = the shared composer's source material.            |
| MiniChat      | `Views/MiniChat/MiniChatView.swift` + `MiniChatWindowController.swift`                                                                                                                                                        | Floating window chat.                                                                                               |
| Note chat     | `Views/Notes/NoteChatSidebar.swift` + `NoteDetailWorkspaceView.swift`                                                                                                                                                         | Already has tools icon + model picker → bring to full act parity.                                                   |
| Graph chat    | `Views/Graph/HologramSearchSidebar.swift` + `HologramController/Overlay`, `NodeInspectorState`, `PinnedInspector`, `QueryResultsView`                                                                                         | Graph-context chat/query.                                                                                           |
| Landing       | `Views/Landing/LandingView.swift`                                                                                                                                                                                             | Holds model selection + dispatch — a launch/chat surface; uses `setPreferredChatModelSelection` + `InferenceState`. |
| HTMLWorkspace | `Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift`                                                                                                                                                                           | Prompt surface via patch router — VERIFY whether it sends model turns; if yes → ACT, else OUT.                      |
| Recall/Shadow | `Views/Halo/ShadowPanel.swift`, `Views/Recall/ContextualShadowsButton.swift`                                                                                                                                                  | Search-first; VERIFY if it issues model prompts → ACT, else OUT (search-only).                                      |


## B. SHARED backend consumers (route through act; single sources of truth)


| Dependency               | File                                                                                                                                                      | Role                                                                                                                                                                      |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `InferenceState`         | `State/InferenceState.swift` (60 consumers)                                                                                                               | Model-selection + resolver state. **Holds the live too-large→Qwen fallback (`:3072`)** → the no-silent-Qwen requirement lands in act's model selection, NOT a chat patch. |
| `EpistemosRuntimePicker` | `Engine/EpistemosRuntimePicker.swift` (+ `App/RootView.swift`, `Views/Chat/InlineRuntimePickerPanel.swift`)                                               | The runtime/brain picker — the P0 "installed models not clickable" surface. Its enumeration logic → **Epistemos Picks**.                                                  |
| `ChatCoordinator`        | `App/ChatCoordinator.swift`                                                                                                                               | Prompt-dispatch coordinator — the seam act drives.                                                                                                                        |
| model-selection API      | `setPreferredChatModelSelection` in `InferenceState`, `ChatCoordinator`, `LLMService`, `TriageService`, `AnswerPacketEmitter`, `AppBootstrap`, `RootView` | The shared selection path act must honor.                                                                                                                                 |
| tools/capability UI      | `Views/Shared/ChatCapabilityPill.swift`, `Views/Chat/AgentToolTogglePanel.swift`, `ChatBrainPickerMenu.swift`, `ModelAboutSheet.swift`                    | Tools + capability pills + per-model profiles → carry into the shared composer.                                                                                           |
| on-device server         | `Engine/LocalModelServer.swift` (:1337)                                                                                                                   | The osaurus-pattern server act's `runTurn` already targets.                                                                                                               |


## C. WORK-mode surface (already seamed)

`Epistemos/Work/WorkBackend.swift` + `WorkBackendGateStatus.swift` + `Views/Settings/WorkBackendHealthRow.swift`
exist (the "work = Goose/OpenCode" mode). Same quarantine + porting + surface-wiring rules apply (addendum).

## D. Settings model surfaces (wire to Epistemos Picks)

`Views/Settings/ModelStackSettingsView.swift`, `ModelVaultsSettingsView.swift`,
`ModelVaultsSidebarSection.swift`, `ActiveConstellationRow.swift`, `RuntimeTruthHealthRow.swift`,
`LocalRouteHonestyHealthRow.swift` — the model-stack settings → host/feed "Epistemos Picks".

## OUT (with reason)

- MOHAWK training-data JSON/JSONL hits for `setPreferredChatModelSelection` = fixture/training corpus, not live code.
- Pure graph-render views (`GraphFPSHUD`, `GraphWarmupView`, `MetalGraphView` render path) = no prompt dispatch.

## Ripple effects to track (per cycle)

Onboarding (`SetupAssistantView`), command palette / `SlashCommandPopover`, sidebars, the
approval modal (`ApprovalModalView`), tests/fixtures referencing chat behavior, and the
data carry-over (saved chats/sessions → act). Re-run this critic each cycle: "what surface/
consumer did we miss?" → append here + the build-progress ledger.

## Verdict for the wiring phase

Build ONE shared act composer over `ChatCoordinator` + `InferenceState` + the `Composer*`/
`ChatInputBar` family, with the act/Osaurus capability set (tools, model picker + Epistemos
Picks, honest no-fallback, streaming/thinking fidelity). Adopt it in surfaces A1–A5 (verify
A6–A7). Never delete the chat path — quarantine + port its IP. Conflict → favor Osaurus.