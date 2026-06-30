# Plan 3 — Voice codepack (shipped code, Pass 8)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §11`. Scope: Apple-native voice polish first, then Pro neural voice.
> This codepack is grounded in current source and supersedes older broad voice notes where they conflict. Plan 3 owns
> voice engines/settings/shared controls; Plan 2 editor surfaces are integration consumers only.

## Shipped state `[VERIFIED-CODE]`
- **TTS is real and MAS-safe:** `Epistemos/Engine/EpistemosSpeechSynthesizer.swift` wraps `AVSpeechSynthesizer` as
  `@MainActor @Observable`, supports speak/pause/resume/stop, per-range progress, voice catalogue, global default voice
  identifier, and honest `voiceQualityHint()`.
- **Voice picker is real:** `VoicePreferencesSection` mounts `ModelVoicePickerSection`, persists the global default via
  `EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier`, and surfaces the premium-download hint.
- **Visible auto toggles are consumer-backed:** `VoicePreferences.shared.noteReadAloud == .auto` is consumed by
  `ProseEditorView`; `quickCaptureReadBack == .auto` is consumed by `QuickCaptureView`; `dictationAutoStop == .auto`
  is consumed by `MeetingNoteCaptureService` as a 2-second auto-stop after final silence.
- **No-op Settings toggles are hidden:** `VoicePreferencesSection` no longer displays `agentResponseTTS`,
  `brainDumpHotkeyDictate`, or `perModelVoicePersona` rows until those keys have real behavior consumers.
- **Shared mic control is now backed by live Apple STT:** `VoiceInputButton` consumes `LiveVoiceInputService.shared`,
  forwards partial/final transcript text, and no longer routes through the removed `ComposerVoiceInputService` stub.
- **Shared mic callbacks are capture-owner gated:** because `LiveVoiceInputService.shared` is global, only the
  `VoiceInputButton` instance that starts capture forwards partial/final transcript text or tears down the service on
  disappearance. Other mounted buttons can reflect/stop global recording state without consuming transcript into the
  wrong host surface.
- **Live macOS 26 STT is surfaced:** `LiveVoiceInputService` wraps `EpistemosSpeechAnalyzer` readiness/start/stop,
  model-download progress, and partial/final transcript state for reusable UI consumption. Meeting/STT builds on this
  facade. Final SpeechAnalyzer segments are buffered and drained in order so fast final events cannot overwrite one
  another before the UI consumes them; partial, final, buffered, and consumed transcript strings are capped to the
  `TextCapturePipeline.maxCleanedTextCharacters` envelope before host callbacks receive them. External SpeechAnalyzer
  failures are mapped to bounded domain/code diagnostics before they reach voice UI status text.
- **Reusable mic API has no inert auto-stop flag:** `VoiceInputButton` is manual by design; surfaces that support
  automatic silence-stop own the policy at their capture-service boundary.
- **Preferred voice floor is quality-first:** `preferredVoice()` now resolves installed voices by Premium > Enhanced >
  Default and uses locale only as a tie-breaker; the language constructor is not the normal floor.
- **SSML/prosody fallback exists:** `speak(..., prosody:)` builds an SSML utterance when possible and falls back to a
  plain utterance while preserving rate/pitch clamping.
- **Pro Kokoro gate is honest:** `KokoroVoiceGateStatus` exists as a status-only gate. MAS returns unavailable, Pro
  requires `EPISTEMOS_KOKORO_VOICE_PRO_V0=1`, and missing `manifest.json`/`Kokoro82M.mlpackage` keeps AVSpeech as the
  runtime. Readiness rejects symlink-routed or non-regular model artifacts and requires a bounded no-follow JSON
  manifest object before reporting ready. Status details use bounded model-relative diagnostics instead of local absolute
  model paths. There is still no Kokoro model asset, picker row, or neural runtime.

## Delivered MAS-safe fixes
1. **Fix the preferred voice floor.** `[DONE]` `preferredVoice()` is identifier-first over installed voices:
   Premium > Enhanced > Default, with current locale only as a tie-breaker.
2. **Add SSML/prosody fallback path.** `[DONE]` `speak(..., prosody:)` tries
   `AVSpeechUtterance(ssmlRepresentation:)`, falls back to `AVSpeechUtterance(string:)`, and preserves clamped
   rate/pitch.
3. **Make `agentResponseTTS` honest.** `[DONE]` The Settings row is hidden until an assistant-stream completion
   consumer exists.
4. **Make the mic honest while STT is disabled.** `[DONE]` `VoiceInputButton` no longer points at the removed composer
   stub; it consumes `LiveVoiceInputService` and reports unavailable/error states from that facade.
5. **Route macOS 26 dictation through `EpistemosSpeechAnalyzer`.** `[DONE]` `LiveVoiceInputService` wraps
   `EpistemosSpeechAnalyzer.startLive()` so UI surfaces consume partial/final text without owning AVAudioEngine details.

## Meeting/STT split
Meeting/lecture note should get its own codepack, but Voice provides the reusable live STT facade:
- `LiveVoiceInputService` owns start/stop/readiness, maps `EpistemosSpeechAnalyzer.LiveResult` to UI-friendly partial/final
  text, and exposes explicit unavailable states.
- Meeting capture builds on that facade, materializes transcript into a note, and saves through the deterministic
  `TextCapturePipeline` path. It must not couple directly to the composer mic button.

## Pro Kokoro lane `[STATUS GATE DELIVERED; RUNTIME DEFERRED]`
Kokoro-82M is Pro-only until packaging and model-download gates are proven:
- `[DONE]` Add `Epistemos/VoicePro/KokoroVoiceGateStatus.swift` with `.unavailable/.missingModel/.ready`.
- Store model assets outside MAS target resources; never commit model weights.
- Integrate through the existing model download manager only after that manager is proven healthy.
- Picker row must say "Pro neural voice" and fall back to AVSpeech instantly when missing.
- Do not add Python/subprocess inference on the MAS path.

## Shipped files / source guards
- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift` — preferred voice floor + utterance builder/SSML fallback.
- `Epistemos/Engine/VoicePreferences.swift` — keep keys, but only expose keys with consumers.
- `Epistemos/Views/Settings/VoicePreferencesSection.swift` — remove or honestly gate `agentResponseTTS` until wired.
- `Epistemos/Engine/LiveVoiceInputService.swift` — facade over `EpistemosSpeechAnalyzer` with bounded transcript output,
  finite/clamped model download progress, and capped user-facing status/error text.
- `Epistemos/Views/Shared/VoiceInputButton.swift` — consume the live facade or present disabled honesty.
- `EpistemosTests/Plan3VoiceTests.swift` — source guards for voice floor, inert-toggle removal/wiring, STT facade, and no
  Kokoro/MAS subprocess leakage.

## Plan boundaries
- Do not edit `Epistemos/Goose/*` or `Epistemos/Agent/*`.
- Do not build Plan 2 editor features here. If `noteReadAloud` needs an editor consumer, Plan 2 owns the editor mount;
  Plan 3 owns the voice service contract and honest Settings row.
- Do not add cloud STT/TTS as the default. Apple Speech/AVSpeech are the MAS defaults; Whisper/Kokoro are Pro options.
- Do not surface a "Premium" or "neural" label unless the selected voice/runtime proves that capability.

## Verification gates
- Unit/source tests prove `preferredVoice` no longer depends on `AVSpeechSynthesisVoice(language:)` as the normal floor.
- Settings source guard proves every visible Auto/Manual row has a behavior consumer or an honest unavailable state.
- STT source guard proves `VoiceInputButton` no longer routes only to the removed `ComposerVoiceInputService` stub.
- STT facade tests prove partial/final transcript helpers stay inside the capture pipeline text envelope before callbacks.
- macOS 26 compile guard proves `EpistemosSpeechAnalyzer` remains `@available(macOS 26.0, *)`.
- Kokoro gate tests prove malformed, symlink-routed, non-regular, or oversized/invalid-manifest model artifacts keep
  AVSpeech as the runtime without exposing local model roots in UI-facing status details.
- MAS boundary guard proves no Kokoro weights, Python, subprocess, or Chromium-like runtime enters the App Store target.

## Delivery order
1. [DONE] Patch the AVSpeech preferred voice floor and add tests.
2. [DONE] Wire or remove `agentResponseTTS`; add a source guard so it cannot regress to a visible no-op.
3. [DONE] Add `LiveVoiceInputService` over `EpistemosSpeechAnalyzer`.
4. [DONE] Rewire `VoiceInputButton` to live STT or hide/disable it honestly where unsupported.
5. [DONE] Add SSML/prosody fallback.
6. [DONE] Add the Kokoro Pro gate as status-only. Packaging, picker UI, and runtime integration remain deferred until
   model download health is proven.
