# Stash 18 Agent Command Center Donor Synthesis - 2026-05-26

Status: recovered as donor notes, not restored as live UI.

Source: `stash@{18}` (`WIP on main: 31214a4d Update progress and mark three runtime issues as patched`).

Recovery rule: this slice was inspected with `git show` only. No stash was popped, dropped, checked out, or bulk-applied.

## Why This Is Not A Raw Restore

The old Agent Command Center shell is intentionally removed after the fused-chat architecture. Current source guards fail if these files exist again:

- `Epistemos/Views/AgentCommandCenter/AgentCommandCenterView.swift`
- `Epistemos/Views/AgentCommandCenter/BrainPickerMenu.swift`
- `Epistemos/Views/AgentCommandCenter/CommandBarView.swift`
- `Epistemos/Views/AgentCommandCenter/InspectorPanelView.swift`
- `Epistemos/Views/AgentCommandCenter/SuggestionPopoverView.swift`

Restoring those files raw would reintroduce the deprecated parallel agent page. The durable work in the stash is UX behavior and visual language, so this recovery archives the donor ideas and pins where each idea belongs in the current fused surfaces.

## Donor UX Inventory

### Agent Workspace Shell

Useful ideas:

- A clear agent status header.
- Runtime chips for persona, route, trace readiness, and selected runtime.
- Quick counters for turns, messages, and enabled tools.
- A right-side inspector only when the user asks for advanced detail.

Current architecture target:

- `Epistemos/App/ChatCoordinator.swift` builds `ChatBrainSnapshot` and `ChatBrainSection` from the compiled request and runtime route.
- `Epistemos/Views/Chat/ChatInputBar.swift` and `Epistemos/Views/Shared/ChatCapabilityPill.swift` provide the always-visible mode and live tool signal.
- `Epistemos/Views/Chat/MessageBubble.swift` renders boxed tool execution previews.

Live-port rule:

Do not create another page shell. If more of this idea is ported, add a compact agent trace strip or message-level inspector inside current chat, sourced only from `ChatBrainSnapshot` and `CommandCenterExecutionDiagnostics`.

### Brain Picker

Useful ideas:

- One compact runtime control that shows model, operating mode, and provider-native effort.
- Menu sections for model selection, mode selection, native effort, and density.
- Rows include icon, title, detail, shortcut, and selected state.

Current architecture target:

- `Epistemos/Views/Chat/ChatBrainPickerMenu.swift` delegates to `LocalModelToolbarMenu`.
- `Epistemos/Views/Chat/ChatInputBar.swift` opts main chat into split controls.
- `Epistemos/Views/Landing/LandingView.swift` uses the compact picker in the landing composer.

Live-port rule:

Preserve the single current picker path. Any visual upgrades should happen in `LocalModelToolbarMenu` or its wrapper, not in a resurrected `BrainPickerMenu`.

### Command Bar

Useful ideas:

- Floating native composer chrome with inline runtime control.
- Visible slash token and mention chips.
- Running versus ready state in the composer.
- Strong keyboard-first affordance for `/` commands and `@` context.

Current architecture target:

- `Epistemos/Views/Chat/ChatInputBar.swift` owns main chat composition, slash command popover, attachments, context usage, and capability pill.
- `Epistemos/Views/Landing/LandingView.swift` owns the landing composer path and routes through `MainChatSubmissionRouter`.
- `Epistemos/Views/MiniChat/MiniChatView.swift` owns the utility chat composer.

Live-port rule:

Only port composer details by extending these fused composers. Do not re-add `CommandBarView.swift`.

### Inspector Panel

Useful ideas:

- Tabs for context, capabilities, plan, execution, and hierarchy.
- The inspector must be truthful: every displayed value comes from compile-time or runtime diagnostics, not guessed SwiftUI state.
- Plan presentation can switch between rendered and source views.

Current architecture target:

- `ChatCoordinator.buildMainChatBrainSnapshot(...)` already emits sections for resolved request, active agent, attachment contract, vault context, note context, graph context, file attachments, workspace awareness, conversation history, and execution plan.
- `AgentChatState.mainChatBrainSnapshot` persists the snapshot for the matching turn.
- `MessageBubble` and related chat presentation views are the right place for an expandable request inspector.

Live-port rule:

If this becomes live UI, build it as a message-level "Brain Snapshot" or "Request Inspector" disclosure backed by `ChatBrainSnapshot`. Do not read live truth directly from local view state.

### Suggestion Popover

Useful ideas:

- A unified low-latency dropdown for slash commands, mentions, and runtime brains.
- Slash menu combines built-in commands with discovered skills.
- Keyboard-highlighted rows with no-results state.

Current architecture target:

- `Epistemos/Views/Chat/SlashCommandPopover.swift`
- `Epistemos/Views/Chat/ChatInputBar.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- `Epistemos/Views/MiniChat/MiniChatView.swift`

Live-port rule:

Unify slash and skill discovery in the existing popovers. Do not restore `SuggestionPopoverView.swift`.

## Recovery Result

This stash@{18} slice is preserved as an architecture donor. The old live files remain absent, and the next safe implementation slice is:

1. Add a compact request-inspector disclosure to chat messages using `ChatBrainSnapshot`.
2. Fold any missing runtime-effort/density affordance into `LocalModelToolbarMenu`.
3. Keep landing and main chat on the fused `MainChatSubmissionRouter` path.
