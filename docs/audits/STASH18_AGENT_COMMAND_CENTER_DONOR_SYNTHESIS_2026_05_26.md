# Stash 18 Agent Command Center Donor Synthesis - 2026-05-26

Status: recovered as donor notes, not restored as live UI.

Superseding deletion note, 2026-06-25: the old native chat route described
below has been deleted. `ChatCoordinator`, `ChatState`, `ChatInputBar`,
`MessageBubble`, `MiniChat`, and `MainChatSubmissionRouter` are historical
references only and must not be used as live restoration targets. Any future
use of these donor ideas belongs in the AgentClone/fusion-backed chat rebuild.

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

- AgentClone/fusion owns the live chat path. Request-inspector ideas should be
  rebuilt there, not restored through `ChatCoordinator` or old `ChatState`.
- Shared capability controls and model/runtime pickers may inform the rebuild
  only when they are not tied to the deleted old chat surface.
- Boxed tool execution previews are visual-language references, not a reason to
  restore `MessageBubble`.

Live-port rule:

Do not create another page shell. If more of this idea is ported, add a compact agent trace strip or message-level inspector inside the rebuilt AgentClone/fusion chat, sourced only from runtime receipts and verified diagnostics.

### Brain Picker

Useful ideas:

- One compact runtime control that shows model, operating mode, and provider-native effort.
- Menu sections for model selection, mode selection, native effort, and density.
- Rows include icon, title, detail, shortcut, and selected state.

Current architecture target:

- `LocalModelToolbarMenu`, `InlineRuntimePickerPanel`, and the AgentClone/fusion
  model-selection surface are the live picker targets.
- `ChatBrainPickerMenu` and the deleted old `ChatInputBar` must stay absent.

Live-port rule:

Preserve a single current picker path. Any visual upgrades should happen in the
AgentClone/fusion picker surface or live shared picker primitives, not in a
resurrected `BrainPickerMenu` or `ChatBrainPickerMenu`.

### Command Bar

Useful ideas:

- Floating native composer chrome with inline runtime control.
- Visible slash token and mention chips.
- Running versus ready state in the composer.
- Strong keyboard-first affordance for `/` commands and `@` context.

Current architecture target:

- AgentClone/fusion owns main chat composition.
- `Epistemos/Views/Landing/LandingView.swift` may launch the protected new route
  and may keep shared slash/runtime controls, but it must not route through the
  deleted native chat backend.
- `MiniChatView` is deleted and must not be restored as a utility composer.

Live-port rule:

Only port composer details by extending these fused composers. Do not re-add `CommandBarView.swift`.

### Inspector Panel

Useful ideas:

- Tabs for context, capabilities, plan, execution, and hierarchy.
- The inspector must be truthful: every displayed value comes from compile-time or runtime diagnostics, not guessed SwiftUI state.
- Plan presentation can switch between rendered and source views.

Current architecture target:

- Rebuild request-inspector data from AgentClone/fusion runtime receipts and
  Epistemos-owned guard contracts.
- `AgentChatState` may preserve lightweight launch/session metadata, but old
  `ChatBrainSnapshot`/`ChatCoordinator` plumbing is not a live target.
- The expandable inspector belongs in the rebuilt AgentClone/fusion chat surface,
  not the deleted `MessageBubble` family.

Live-port rule:

If this becomes live UI, build it as a message-level request-inspector
disclosure backed by AgentClone/fusion receipts. Do not read live truth directly
from local view state.

### Suggestion Popover

Useful ideas:

- A unified low-latency dropdown for slash commands, mentions, and runtime brains.
- Slash menu combines built-in commands with discovered skills.
- Keyboard-highlighted rows with no-results state.

Current architecture target:

- `Epistemos/Views/Chat/SlashCommandPopover.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- The rebuilt AgentClone/fusion composer surface.

Live-port rule:

Unify slash and skill discovery in the existing popovers. Do not restore `SuggestionPopoverView.swift`.

## Recovery Result

This stash@{18} slice is preserved as an architecture donor. The old live files remain absent, and the next safe implementation slice is:

1. Add a compact request-inspector disclosure to the rebuilt AgentClone/fusion
   chat surface using current runtime receipts.
2. Fold any missing runtime-effort/density affordance into the live picker path.
3. Keep landing and main chat off the deleted native chat backend.
