# Halo V1 Editor Mount PR1 Deliberation — 2026-05-02

## Decision

Approve the narrow V1 Halo editor mount on `feature/landing-liquid-wave`.

The mount must use the existing `ProseEditorRepresentable2.Coordinator2` text-change path. It must not instantiate `HaloEditorBridge` in production, because `HaloEditorBridge` claims `NSTextView.delegate` and would break the existing editor delegate pipeline.

## Approved Write Set

- `Epistemos/State/ContextualShadowsState.swift`
- `Epistemos/Views/Notes/ProseEditorRepresentable2.swift`
- `Epistemos/Views/Halo/HaloButton.swift`
- `Epistemos/Views/Halo/ShadowPanelContent.swift`
- `EpistemosTests/HaloUITests.swift`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`

## Forbidden In This Slice

- No graph-engine or Rust FFI edits.
- No note-editor delegate replacement.
- No `HaloEditorBridge` production instantiation.
- No cloud, Hermes, or CLI involvement.
- No per-keystroke SwiftUI binding writes beyond the existing debounced editor path.

## Implementation Shape

Use one control surface and the shortest concrete path:

- `ContextualShadowsState` exposes the configured `ShadowSearchServicing` backend read-only.
- `Coordinator2` creates a `HaloController` only when the ambient recall gate is enabled and the Shadow backend is available.
- `textDidChange` feeds the controller directly after existing non-critical editor work.
- A tiny `NSHostingView` hosts `HaloButton` inside the scroll view.
- Clicking the glyph opens `ShadowPanelController` anchored to the editor scroll view's screen rect.

## Acceptance

- Focused Halo tests pass.
- Source guard proves production V1 uses the editor coordinator and not the bridge delegate.
- Touched-file audit shows no new `DispatchQueue.main.asyncAfter`, no `repeatForever`, and no direct `parent.text = tv.string`.
