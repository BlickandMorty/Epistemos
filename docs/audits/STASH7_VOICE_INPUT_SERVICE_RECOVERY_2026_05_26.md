# Stash 7 Voice Input Service Recovery - 2026-05-26

Status: recovered as a focused voice-input slice from `stash@{7}`.

Source: `stash@{7}` (`auto-stash for ff pull 160254`).

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied. The
stash was inspected as a donor patch and only the durable voice-input bridge was
ported onto current `main`.

## What Was Recovered

- `VoiceInputButton` now uses the shared `ComposerVoiceInputService` recorder
  and transcription pipeline.
- The button no longer starts the older live `EpistemosSpeechAnalyzer` stream
  directly.
- `VoiceInputPermissionTests` now guards that the shared recorder pipeline stays
  wired.

## Why This Slice Is Narrow

The rest of `stash@{7}` is mixed with older ambient, localization, model, and
provider changes. Current `main` already contains the ambient playback state,
speech synthesizer clamp guards, single-resume Apple Speech continuation guard,
and the newer landing/ambient work. This slice avoids replaying stale deletions
over those newer surfaces.

## Verification Target

- `Epistemos/Views/Shared/VoiceInputButton.swift`
- `EpistemosTests/VoiceInputPermissionTests.swift`
