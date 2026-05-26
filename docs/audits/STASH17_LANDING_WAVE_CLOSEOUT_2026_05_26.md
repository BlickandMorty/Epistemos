# Stash 17 Landing Wave Closeout - 2026-05-26

Status: closed for current product UI recovery.

Source: `stash@{17}` (`codex-wip-parallel-during-landing-wave-session`).

Recovery rule: No stash was popped, dropped, checked out, or bulk-applied.

## What Was Recovered

The stash's user-visible Landing Wave and Session Intelligence intent is already
on current `main`:

- `Epistemos/Views/Landing/Wave/LandingWaveDesign.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveOverlay.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift`
- `Epistemos/Views/Landing/Wave/LandingWaveSearchBar.swift`
- `Epistemos/Views/Landing/SessionIntelligenceOverlay.swift`

The recovered main version is newer than the stash donor: it includes the Farm
surface, split chat controls, command/slash routing, ambient playback state,
context attachments, file attachments, and the current `MainChatSubmissionRouter`
path.

## What Was Superseded

The raw stash still differs in adjacent files such as `NoteInsightService`,
`LiveNoteScanner`, graph inspector state, backlinks, and large landing/tests
files. Those deltas are not safe to restore wholesale because current `main`
already contains newer fused-chat, graph, ambient, and landing surfaces.

Any future use of this stash should be a narrow donor comparison only, not a
product recovery merge.

## Queue Result

`stash@{17}` is no longer an active recovery queue item. Keep it only as a
historical preservation reference until the user approves retiring old recovery
refs.
