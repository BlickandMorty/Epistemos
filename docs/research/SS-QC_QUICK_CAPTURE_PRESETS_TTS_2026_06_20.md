# SS-QC — Quick Capture deep upgrade (destination presets) + TTS read-back (2026-06-20)

Owner: *"quick capture prioritizes the prose editor but I want more options — presets on what it should go to / what it
should be used for. still minimal but more robust; it was an afterthought and needs a deep upgrade to be more useful. also
add the model text-to-speech as well, so when you type something have it read back to you automatically or manually."*
Code-grounded. NON-INVASIVE (Prose stays default + its open path untouched). Cross-ref SS-K/SS-Q (voice).

## (C) Quick Capture — current + preset seam
`Views/Capture/QuickCaptureView.swift` (⌘⇧N overlay): one `TextEditor` (`:22`, form `:197-347`) + Dictate (`AudioRecorder`/
`AudioTranscriber` `:28-29`, `toggleAudioRecording :581-618`) + a client-side `PreviewSignals` chip strip (tags/@/tasks/URLs,
`:630-694`). Submit → `pipeline.run(rawText:modelContext:)` (`:309-310,548-578`) / `runFromAudio` (`:588`).
**Hardcoded Prose default:** `Engine/TextCapturePipeline.swift:253 run(...)` has ONE destination — `persistNote(:718-766)`
always creates an `SDPage` (`:727`), tagged `ArtifactKind.proseNote` (`:404`); "Open Note" → `NoteWindowManager.open(pageId:)`
(`:299`) → Prose editor. `CaptureResult.draftNoteID` exists but is always nil (`:88,378`) = a latent carrier for other targets.
**Destinations that already exist** (`Models/ArtifactKind.swift:25`: proseNote/document(Epdoc)/rawThought/source/code/run/
output): plain note (current), Epdoc (`EpdocEditorChromeView`), chat/mini-chat (`MiniChatWindowController.openNewChat :51`,
`AppCoordinator.handleMiniChatQuery :91`), task (NOTE: no `SDTask` model — a task = a `- [ ]` checklist note, not a separate
entity), code (`CodeEditorView`), HTML workspace (`HTMLWorkspacePackage`).
**Preset seam (minimal + robust):** (1) `CaptureDestination` enum (subset of `ArtifactKind` the capture supports) +
`CapturePreset = (destination, purpose/type label)`; persist last-used in UserDefaults (mirror `VoicePreferences` store
shape). (2) Add `destination:` param (default `.proseNote` = backward-compat) to `TextCapturePipeline.run`/`runFromAudio`;
branch the persist step (`:288-308`) — note/task/code/epdoc stay on `persistNote` (vary SDPage/ArtifactKind + template),
`.chat` routes to `MiniChatWindowController.openNewChat`/`handleMiniChatQuery`; carry non-note targets in `draftNoteID`.
(3) Compact preset `Menu`/quick-switch in the action bar `HStack` (`QuickCaptureView.swift:256`, beside Dictate); thread the
choice through `submitCapture()` (`:548`) + the confirmation card "Open" (`:417-428`) dispatches per-destination.

## (D) TTS read-back — honest status + seam
**Only `AVSpeechSynthesizer` — NO local/MLX/Kokoro neural TTS** (grep confirms; header `EpistemosSpeechSynthesizer.swift:6-7`
"Apple-native"). "Model voice" today = per-`SDModelProfile.voiceIdentifier` AVSpeech PERSONA (W9.1, `resolveVoice/preferredVoice
:209-228`), NOT a neural model. (A real neural TTS, e.g. Kokoro, is a separate larger item — cross-ref SS-Q; flag honestly.)
**Reusable wiring:** `EpistemosSpeechSynthesizer.shared` (actor, `:102`) `speak(_:voiceIdentifier:rate:pitch:)` (`:127`),
pause/resume/stop, observable `state`, interrupts in-flight on new `speak` (`:136-138`). `ReadAloudButton`
(`Views/Shared/ReadAloudButton.swift:25`) = drop-in manual control (auto-disables on empty `:113-115`). `VoicePreferences`
(`Engine/VoicePreferences.swift`) has `VoiceDecisionMode{.auto,.manual}` + keys; **GAP:** `agentResponseTTS==.auto` is defined
+ shown but NEVER consumed (no caller) — so auto-read is genuinely NEW wiring, not reuse.
**Read-back seam:** (1) manual: drop `ReadAloudButton(text: captureText, style:.icon)` into the action bar
(`QuickCaptureView.swift:256`) — ~3 lines, reuses the synth. (2) auto-on-type: add `VoicePreferenceKeys.quickCaptureReadBack`
(mirror `:50-78`); debounced `.onChange(of: captureText)` (~600-900ms) gated on `.auto` → `speak(lastCompletedSentence)`
(debounce essential — `speak` interrupts per call; read the just-finished sentence, not the whole buffer); `stop()` on overlay
close (`cleanupTransientCaptureState :446`). (3) toggle row in `VoicePreferencesSection.swift`.

## Ordered plan (minimal-but-robust)
**(D) TTS read-back FIRST (smaller, self-contained, no TK2 touch):** add ReadAloudButton (manual) → add quickCaptureReadBack
pref + Settings row → debounced auto-speak gated on the pref. **(C) Presets SECOND (touches pipeline routing):** define
CaptureDestination/CapturePreset + persist → `destination:` param + branch persist → compact preset Menu + per-destination
"Open". Prose remains default + untouched = non-invasive. Honest: state plainly that no neural TTS exists today ("model voice"
= AVSpeech persona); a neural-TTS model is a separate future item (SS-Q). Each step test-backed; single targeted swift build.
