# Stash 18 UI/UX Closeout - 2026-05-26

Status: closed for current product UI/UX recovery; preserved as donor reference.

Source: `stash@{18}` (`WIP on main: 31214a4d Update progress and mark three runtime issues as patched`).

Recovery rule: inspected with `git stash show`, `git diff`, and `git show`
only. No stash was popped, dropped, checked out, or bulk-applied.

## Why This Closes The Remaining UI/UX Slice

The remaining `stash@{18}` UI diff is older than current `main`. Comparing
current `HEAD` to the stash shows that a raw recovery would delete current live
surfaces, including:

- `Epistemos/Views/Chat/AgentRunTimelineView.swift`
- `Epistemos/Views/Chat/AnswerPacketBadge.swift`
- `Epistemos/Views/Chat/ChatBrainPickerMenu.swift`
- `Epistemos/Views/Chat/ComposerMicButton.swift`
- `Epistemos/Views/Chat/ContextWindowCompactBadge.swift`
- `Epistemos/Views/Chat/ProcessDisclosureViews.swift`
- `Epistemos/Views/Chat/SlashCommandPopover.swift`
- `Epistemos/Views/Chat/VaultRecallProvenanceCard.swift`
- `Epistemos/Views/Landing/Farm/LandingFarmView.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift`
- `Epistemos/Views/Graph/GraphFPSHUD.swift`

Those are not throwaway files. They are the current fused chat, provenance,
landing, graph, and runtime surfaces the app now depends on.

## Durable Donor Pieces Already Present

The user-visible parts that looked valuable in the stash are already represented
on current `main` in newer form:

- Chat artifact cards expose a rendered/source presentation toggle.
- Assistant and user chat markdown use role-specific typography.
- Chat messages carry process/provenance affordances through the fused chat
  surface, not the removed Agent Command Center shell.
- Landing Wave and Session Intelligence source files are present on main.
- Farm landing files are present on main.
- Graph snappy defaults are guarded by `GraphPhysicsSettingsAuditTests`.
- Code editor syntax-core integration and `nsColorForSyntaxKind` are present on
  main.
- Transclusion rendering is handled by `EditableTransclusionView` plus
  `TransclusionOverlayManager2`; the old non-interactive
  `TransclusionOverlayView.swift` donor file is intentionally not restored.

## What Must Stay Out

Do not restore these raw from `stash@{18}`:

- `Epistemos/Views/AgentCommandCenter/*`
- `Epistemos/Views/Notes/TransclusionOverlayView.swift`

The old Agent Command Center shell was already archived as a donor in
`docs/audits/STASH18_AGENT_COMMAND_CENTER_DONOR_SYNTHESIS_2026_05_26.md`. The
old transclusion overlay is superseded by the editable transclusion path.

## Result

`stash@{18}` remains preserved as a historical donor reference, but it is no
longer an active product-recovery queue item. Future work should continue from
current `origin/main`, not from this stash.

Next active recovery queues:

1. `stash@{15}` graph behavior only with graph performance gates.
2. `stash@{3}` / `stash@{6}` VaultRecall and Eidos visibility nuance.
3. `stash@{16}` approval UI donor ideas.
4. Deferred architecture waves from `docs/DEFERRED_WORK_GUARANTEE_2026_05_23.md`.
