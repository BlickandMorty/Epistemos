# Plan 3 - Meeting/STT note (shipped code, Pass 9)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md` sections 6, 7, and 11. Scope: record or dictate a
> meeting/lecture transcript on-device, materialize it as a searchable note, and keep the source/provenance honest.
> No cloud STT. No Whisper/Kokoro/Python/subprocess on the MAS path.

## Shipped state `[VERIFIED-CODE]`
- **Live STT engine exists:** `EpistemosSpeechAnalyzer` is `@available(macOS 26.0, *)`, uses SpeechAnalyzer/
  SpeechTranscriber progressive transcription, handles model asset installation, converts AVAudioEngine tap buffers,
  and exposes `LiveResult.partial` / `LiveResult.final`.
- **UI facade now exists:** `LiveVoiceInputService` owns start/stop/readiness, model download progress, partial/final
  transcript state, and calls `EpistemosSpeechAnalyzer.shared.startLive(...)`.
- **Shared mic control is now honest:** `VoiceInputButton` consumes `LiveVoiceInputService.shared`, forwards partial text
  to `onPartial`, final text to `onFinal`, and no longer routes through `ComposerVoiceInputService.shared`.
- **Text-to-note pipeline already exists:** `TextCapturePipeline.runFromAudio(transcription:modelContext:)` sends
  transcribed text through the same clean/extract/persist/graph/trace path as typed capture.
- **Audio metadata comments are banned:** `TextCapturePipeline.stripHiddenCaptureMetadataComments` removes legacy
  `capture-provenance` and `audio-source` comments before persistence.
- **Meeting service now exists:** `MeetingNoteCaptureService` buffers final transcript segments, reads current partial
  text through `LiveVoiceInputService`, and finalizes through `TextCapturePipeline.runFromAudio(...)` with meeting
  frontmatter. It freezes `duration_seconds` when recording stops, so a delayed save does not inflate the capture
  duration. It also consumes `VoicePreferences.shared.dictationAutoStop == .auto` to stop capture 2 seconds after a
  final SpeechAnalyzer segment if no new partial speech arrives. Cumulative final transcripts replace prior buffered
  prefixes instead of duplicating the same speech into multiple paragraphs. The live transcript buffer is capped to
  `TextCapturePipeline.maxCleanedTextCharacters`, matching the capture pipeline envelope before UI display or note
  finalization. Model download progress is finite/clamped before display, and propagated voice/pipeline errors are
  capped before they reach UI state. Finalize failures use bounded categorical diagnostics instead of raw localized
  filesystem descriptions.
- **Meeting surface now exists:** `MeetingNoteView` is hosted by `UtilityWindowManager` as `.meetingNote`, and
  `LandingFeatureButton.meetingNote` opens it from the landing page. It reads the shared `UIState` theme, uses
  native capsule controls, and renders labels plus the live transcript in flat theme-token surfaces without hard
  dividers. The toolbar status label truncates long bounded diagnostics instead of expanding the row, and Save is
  disabled after a successful `.saved` state until the user starts a new capture so the same transcript cannot be saved
  repeatedly. A Settings row is not required for the first pass.

## Product promise
Meeting note is a user-driven Apple-native capture surface:
- Start recording/dictation, show live partial transcript, and let the user stop explicitly.
- If the user keeps the default auto-stop preference, final-silence pauses stop the capture; manual mode keeps recording
  until Stop is tapped.
- On stop, create a note containing the transcript and deterministic extractive summary from the existing
  `TextCapturePipeline` path.
- Keep raw audio off by default. If raw audio retention is later added, it must be an explicit user choice with a vault
  file path in frontmatter, never a hidden app-cache recording.
- MAS default is Apple Speech/SpeechAnalyzer only. Whisper is a Pro option only after separate packaging and privacy
  review; do not add it in this codepack.

## Delivered build
1. `Epistemos/Engine/MeetingNoteCaptureService.swift` `[VERIFIED-CODE]`.
   - Use `LiveVoiceInputService` as the only STT dependency.
   - Maintain an ordered transcript buffer of final segments plus the current partial segment.
   - Expose `State.idle/preparing/recording/finalizing/saved/error`.
   - Do not own AVAudioEngine or call SpeechAnalyzer directly.
2. Meeting source metadata contract in `TextCapturePipeline` `[VERIFIED-CODE]`.
   - Prefer `CaptureSourceMetadata` with `source`, `source_kind`, `captured_at`, `duration_seconds`, and optional
     `audio_source` fields.
   - Thread it into `run(rawText:modelContext:)`, `runFromAudio(transcription:modelContext:)`, and `persistNote(...)`.
   - Store metadata in `SDPage.frontMatter`; do not reintroduce hidden HTML comments.
3. `MeetingNoteCaptureService.finalize(modelContext:)` calls `TextCapturePipeline.runFromAudio(...)` `[VERIFIED-CODE]`.
   - The transcript remains the canonical note body.
   - The existing title/summary/entities/tasks extraction remains deterministic and MAS-safe.
   - Graph and mutation envelope behavior stays owned by `TextCapturePipeline`.
4. `Epistemos/Views/Meeting/MeetingNoteView.swift` `[VERIFIED-CODE]`.
   - Live transcript pane, Start/Stop, Save note, discard confirmation, error/unavailable states.
   - No editor embedding; opening or editing the saved note is Plan 2's editor surface.
5. Landing feature button `[VERIFIED-CODE]`.
   - Extend `LandingFeatureButton` with `meetingNote`.
   - Route it to a utility window or sheet owned by Plan 3.
   - Button label must be honest if SpeechAnalyzer/microphone is unavailable.

## Note shape
The saved markdown should be inspectable and durable:

```markdown
# Meeting notes from June 28, 2026

## Summary

<deterministic summary from TextCapturePipeline>

## Transcript

<final transcript segments, in capture order>

## Action Items

- [ ] <tasks extracted by TextCapturePipeline>
```

Required frontmatter keys:
- `source = meeting_stt`
- `source_kind = audio_transcript`
- `captured_at = <ISO-8601 timestamp>`
- `duration_seconds = <integer>`
- `stt_engine = apple_speechanalyzer`

Optional frontmatter keys:
- `audio_source = Meeting Audio/<file>.m4a` only if the user explicitly chose to retain audio.

## Boundaries
- Do not edit `Epistemos/Goose/*` or `Epistemos/Agent/*`.
- Do not build Plan 2 editor features here. Meeting note creates a note; Plan 2 owns the editor/viewer surfaces.
- Do not add cloud STT, Whisper, Python, subprocess, Chromium, or hidden audio retention to the MAS path.
- Do not claim speaker diarization unless a real diarization implementation exists. Speaker labels are manual/editable
  until proven otherwise.
- Do not summarize through non-Goose AI. The first MAS pass uses deterministic `TextCapturePipeline` extraction.

## Verification gates
- Source guard proves `MeetingNoteCaptureService` depends on `LiveVoiceInputService`, not `EpistemosSpeechAnalyzer`.
- Source guard proves `runFromAudio(...)` accepts and persists frontmatter metadata without hidden comments.
- Unit test proves final transcript segments are joined in order and partial text is not duplicated into the saved body.
- Unit test proves the meeting transcript buffer is capped to `TextCapturePipeline.maxCleanedTextCharacters` before save.
- Unit test proves saved meeting notes include `source = meeting_stt`, `source_kind = audio_transcript`,
  `captured_at`, `duration_seconds`, and `stt_engine = apple_speechanalyzer`.
- Unit test proves stopping freezes `duration_seconds` before a delayed save.
- Unit test proves the auto dictation preference stops capture after final silence.
- Unit test proves unexpected finalize errors do not expose local filesystem paths in UI-facing state.
- UI source guard proves the landing button opens the meeting note surface and does not touch Goose or Plan 2 editor
  surfaces.
- UI source guard proves saved meeting transcripts cannot be saved again via the button or keyboard shortcut, and long
  status labels cannot expand the toolbar.
- MAS boundary guard proves no cloud STT, Whisper, Python, subprocess, Chromium, or Kokoro path enters meeting capture.

## Delivery order
1. Add this codepack + source guards. `[DONE]`
2. Add `CaptureSourceMetadata` to `TextCapturePipeline` and tests. `[DONE]`
3. Add `MeetingNoteCaptureService` over `LiveVoiceInputService` and tests. `[DONE]`
4. Add `MeetingNoteView` and utility-window route. `[DONE]`
5. Add the landing feature button. `[DONE]`
6. Run source guards, focused Swift parse/typecheck, and then the relevant Xcode tests when other lanes are quiet.
