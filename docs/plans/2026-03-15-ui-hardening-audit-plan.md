# UI Hardening Audit Plan — 2026-03-15

## Scope

- main chat scroll stability
- mini chat scroll stability
- notes scroll stability and layout churn
- toolbar dynamics refactor and legacy residue
- dead UI code and control-system bloat
- accessibility and performance smoke coverage

## Highest-risk paths

1. `Epistemos/Views/Chat/ChatView.swift`
2. `Epistemos/Views/MiniChat/MiniChatView.swift`
3. `Epistemos/Views/Notes/ProseEditorRepresentable.swift`
4. `Epistemos/Views/Notes/TransclusionOverlayManager.swift`
5. `Epistemos/Views/Notes/ClickableTextView.swift`
6. `Epistemos/Theme/ToolbarMorphSurface.swift`
7. `Epistemos/Theme/NativeButtonStyles.swift`
8. `Epistemos/App/RootView.swift`

## Confirmed initial findings

- Main chat forcibly scrolls to bottom on every message-count change without checking whether the user intentionally scrolled away.
- Mini chat has the same unconditional bottom-follow behavior.
- Classic TextKit 1 notes editor refreshes transclusion and rendered-table overlays directly on scroll notifications, which creates avoidable layout churn during scrolling.
- `NativeToolbarToggle` is compiled but currently has no call sites.
- The repo had no dedicated reusable UI hardening harness before this pass.

## Initial fix set

1. Add a durable UI hardening harness under `tools/ui_hardening_skill/` and a repo-local audit skill under `.agents/skills/ui_ux_hardening_audit/`.
2. Introduce shared scroll auto-follow policy and geometry tracking for main chat, mini chat, and note chat history.
3. Coalesce classic notes overlay refresh work during scroll.
4. Add regression coverage for auto-follow logic and overlay scroll coalescing.
5. Run targeted tests, build verification, and the new harness scripts.

## Deferred / follow-up checks

- Toolbar morph surface frame collection and animation-driver conflicts under active hover/expand stress.
- Additional dead-code removals after the current tree is green.
- Optional promotion of more note/editor scenarios into automated tests if the first pass surfaces more deterministic failures.
