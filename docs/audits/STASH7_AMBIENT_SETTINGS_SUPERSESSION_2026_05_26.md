# Stash 7 Ambient / Settings Supersession Audit - 2026-05-26

Status: remaining non-voice `stash@{7}` slices reviewed and retired as
superseded by current `main`.

Source: `stash@{7}` (`auto-stash for ff pull 160254`).

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied. The
stash was inspected with compare-only commands against current `main`.

## What Was Already Recovered

- Voice input button service bridge:
  `docs/audits/STASH7_VOICE_INPUT_SERVICE_RECOVERY_2026_05_26.md`.

## Ambient Frequency Result

The ambient files in `stash@{7}` are older than current `main`.

Raw restoring them would remove current behavior that is now covered by live
source and tests:

- compact Frequencies and Sounds flow in `AmbientFrequencySettingsView`
- persistent `AmbientPlaybackState` / live player lifetime outside Settings
- per-layer mixer controls and FX state
- retro music/composer controls
- expanded ambient generator tests for mixer, music, FX, and compact settings

The stash contained the older `livePlayerStopsWhenSettingsDisappear` assertion,
while current `main` intentionally has
`livePlayerPersistsOutsideAmbientFrequencySettings`. The current behavior wins.

## Settings Health Result

The Settings health-row deltas in `stash@{7}` predate the newer verified-floor
chip strip work now on `main`. Restoring those files would revert richer current
rows back to older orange-chip copy and remove newer row structure.

The useful idea from the stash is preserved: do not show green production truth
unless a real production consumer and witness/falsifier back it. That idea is now
carried by the verified-floor chip strip docs and tests on `main`.

## App Shell / Search Result

The remaining app-shell and search-index deltas are stale relative to current
`AppBootstrap`, `RootView`, `ChatCoordinator`, and `SearchIndexService`.
Compare-only inspection found no narrow non-stale slice to port from `stash@{7}`
after the voice bridge.

## Retirement Decision

Do not apply the remaining `stash@{7}` files raw. Keep the stash for historical
audit until the user approves dropping old recovery material, but treat the
remaining ambient/settings/app-shell diff as closed by supersession.
