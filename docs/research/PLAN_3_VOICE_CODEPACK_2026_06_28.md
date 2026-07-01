# Plan 3 — Voice codepack (shipped code, Pass 8)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §11`. Scope: Apple-native voice polish first, then Pro neural voice.
> This codepack is grounded in current source and supersedes older broad voice notes where they conflict. Plan 3 owns
> voice engines/settings/shared controls; Plan 2 editor surfaces are integration consumers only.

## Shipped state `[VERIFIED-CODE]`
- **TTS is real and MAS-safe:** `Epistemos/Engine/EpistemosSpeechSynthesizer.swift` wraps `AVSpeechSynthesizer` as
  `@MainActor @Observable`, supports speak/pause/resume/stop, per-range progress, voice catalogue, global default voice
  identifier, and honest `voiceQualityHint()`. `ReadAloudButton` renders the shared TTS control through native capsule
  chrome and theme-derived progress colors.
- **Voice picker is real:** `VoicePreferencesSection` mounts `ModelVoicePickerSection`, persists the global default via
  `EpistemosSpeechSynthesizer.setGlobalDefaultVoiceIdentifier`, and surfaces the premium-download hint. Its Why/Preview
  actions render through shared `ToolbarCapsuleButton` chrome, and rationale text uses theme-derived muted foreground
  plus surface tint instead of local borderless/raw secondary styling.
- **Visible auto toggles are consumer-backed:** `VoicePreferences.shared.noteReadAloud == .auto` is consumed by
  `ProseEditorView`; `quickCaptureReadBack == .auto` is consumed by `QuickCaptureView`; `dictationAutoStop == .auto`
  is consumed by `MeetingNoteCaptureService` as a 2-second auto-stop after final silence.
- **No-op Settings toggles are hidden:** `VoicePreferencesSection` no longer displays `agentResponseTTS`,
  `brainDumpHotkeyDictate`, or `perModelVoicePersona` rows until those keys have real behavior consumers.
- **Shared mic control is now backed by live Apple STT:** `VoiceInputButton` consumes `LiveVoiceInputService.shared`,
  forwards partial/final transcript text, and no longer routes through the removed `ComposerVoiceInputService` stub.
- **Shared mic control uses native toolbar chrome:** `VoiceInputButton` renders through `ToolbarCapsuleButton`, derives
  recording pulse color from `UIState.theme`, and avoids local borderless/raw accent styling so composer/toolbar hosts get
  the same native control contract as Meeting/STT.
- **Shared mic callbacks are capture-owner gated:** because `LiveVoiceInputService.shared` is global, only the
  `VoiceInputButton` instance that starts capture forwards partial/final transcript text or tears down the service on
  disappearance. Other mounted buttons can reflect/stop global recording state without consuming transcript into the
  wrong host surface.
- **Live macOS 26 STT is surfaced:** `LiveVoiceInputService` wraps `EpistemosSpeechAnalyzer` readiness/start/stop,
  model-download progress, and partial/final transcript state for reusable UI consumption. Meeting/STT builds on this
  facade. Final SpeechAnalyzer segments are buffered and drained in order so fast final events cannot overwrite one
  another before the UI consumes them; partial, final, buffered, and consumed transcript strings are capped to the
  `TextCapturePipeline.maxCleanedTextCharacters` envelope before host callbacks receive them. External SpeechAnalyzer
  failures are mapped to bounded domain/code diagnostics before they reach voice UI status text or public analyzer logs,
  with raw status/domain strings bounded before trimming or punctuation validation and status ellipsis kept inside the
  configured cap.
- **Reusable mic API has no inert auto-stop flag:** `VoiceInputButton` is manual by design; surfaces that support
  automatic silence-stop own the policy at their capture-service boundary.
- **Preferred voice floor is quality-first:** `preferredVoice()` now resolves installed voices by Premium > Enhanced >
  Default and uses locale only as a tie-breaker; the language constructor is not the normal floor.
- **SSML/prosody fallback exists:** `speak(..., prosody:)` builds an SSML utterance when possible and falls back to a
  plain utterance while preserving rate/pitch clamping.
- **Personal Voice authorization is live:** `EpistemosSpeechSynthesizer` wraps
  `AVSpeechSynthesizer.personalVoiceAuthorizationStatus` and `requestPersonalVoiceAuthorization` behind a macOS 14+
  availability gate. `ModelVoicePickerSection` exposes a native capsule affordance to request access, refreshes the voice
  catalogue after authorization, and keeps the picker on theme-derived tints instead of hardcoded system colors.
- **Pro Kokoro gate is honest:** `KokoroVoiceGateStatus` exists as a status-only gate. MAS returns unavailable, Pro
  requires `EPISTEMOS_KOKORO_VOICE_PRO_V0=1`, and missing `manifest.json`/`Kokoro82M.mlpackage` keeps AVSpeech as the
  runtime. Package verification rejects symlink-routed or non-regular model artifacts, requires a bounded no-follow install
  manifest with the expected schema/model/runtime/package fields, requires JSON numeric fields to be finite integers,
  caps declared per-file and total package bytes before digesting any listed artifact, and verifies the listed `.mlpackage` file sizes plus SHA-256 digests before reporting
  `packageReady`. `isReady` remains false until real neural synthesis is wired and
  selectable. Status details use bounded-before-trim model-relative diagnostics with ellipsis inside configured caps
  instead of local absolute model paths. A Pro-only
  Voice settings section now shows the `Apple AVSpeech` / `Pro neural voice` runtime affordance and keeps AVSpeech
  selected until both the checked package and real neural inference runtime are proven.
- **Local Kokoro package install is real but runtime-disabled:** `KokoroVoicePackageInstaller` lets Pro users choose a
  prepared `kokoro-82m-coreml` folder (or its parent), validates it with the existing gate, rejects symlink descendants,
  stages it under Application Support with backup/restore finalization, and revalidates the installed package before the
  settings row reports `packageReady`. There is still no committed Kokoro model asset, neural inference runtime, Python,
  subprocess, network downloader, or MAS-visible Kokoro row.

## Delivered MAS-safe fixes
1. **Fix the preferred voice floor.** `[DONE]` `preferredVoice()` is identifier-first over installed voices:
   Premium > Enhanced > Default, with current locale only as a tie-breaker.
2. **Add SSML/prosody fallback path.** `[DONE]` `speak(..., prosody:)` tries
   `AVSpeechUtterance(ssmlRepresentation:)`, falls back to `AVSpeechUtterance(string:)`, and preserves clamped
   rate/pitch.
3. **Add Personal Voice authorization.** `[DONE]` The shared voice picker can request Personal Voice access on macOS 14+,
   then refresh the AVSpeech voice catalogue so user-created voices can appear when Apple grants access.
4. **Make `agentResponseTTS` honest.** `[DONE]` The Settings row is hidden until an assistant-stream completion
   consumer exists.
5. **Make the mic honest while STT is disabled.** `[DONE]` `VoiceInputButton` no longer points at the removed composer
   stub; it consumes `LiveVoiceInputService` and reports unavailable/error states from that facade.
6. **Route macOS 26 dictation through `EpistemosSpeechAnalyzer`.** `[DONE]` `LiveVoiceInputService` wraps
   `EpistemosSpeechAnalyzer.startLive()` so UI surfaces consume partial/final text without owning AVAudioEngine details.

## Meeting/STT split
Meeting/lecture note should get its own codepack, but Voice provides the reusable live STT facade:
- `LiveVoiceInputService` owns start/stop/readiness, maps `EpistemosSpeechAnalyzer.LiveResult` to UI-friendly partial/final
  text, and exposes explicit unavailable states.
- Meeting capture builds on that facade, materializes transcript into a note, and saves through the deterministic
  `TextCapturePipeline` path. It must not couple directly to the composer mic button.

## Pro Kokoro lane `[STATUS GATE DELIVERED; RUNTIME DEFERRED]`
Kokoro-82M is Pro-only until packaging and model-download gates are proven:
- `[DONE]` Add `Epistemos/VoicePro/KokoroVoiceGateStatus.swift` with `.unavailable/.missingModel/.packageReady`;
  package-ready still keeps `isReady=false` until synthesis works.
- `[DONE]` Add a Pro-only Voice settings status/runtime affordance that says "Pro neural voice" but falls back to
  AVSpeech by disabling the Pro lane until the checked package gate and real neural inference runtime are both proven.
- `[DONE]` Add a Pro-only local checked-package installer so a prepared package can reach `packageReady` without adding
  a network downloader or neural runtime.
- Store model assets outside MAS target resources; never commit model weights.
- Integrate through the existing model download manager only after that manager is proven healthy.
- The Pro runtime row must continue saying "Pro neural voice" and fall back to AVSpeech instantly when missing or when
  package readiness exists without a proven inference runtime.
- Do not add Python/subprocess inference on the MAS path.

## Shipped files / source guards
- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift` — preferred voice floor + utterance builder/SSML fallback.
- `Epistemos/Views/Shared/ReadAloudButton.swift` — shared AVSpeech control on native capsule chrome with theme-derived
  progress drawing.
- `Epistemos/Views/Shared/ModelVoicePickerSection.swift` — global voice picker, Premium/Enhanced install hint, and
  macOS 14+ Personal Voice authorization affordance on shared native capsule chrome.
- `Epistemos/Engine/VoicePreferences.swift` — keep keys, but only expose keys with consumers.
- `Epistemos/Views/Settings/VoicePreferencesSection.swift` — remove or honestly gate `agentResponseTTS` until wired, and
  keep visible rationale/preview controls on shared native chrome.
- `Epistemos/Engine/LiveVoiceInputService.swift` — facade over `EpistemosSpeechAnalyzer` with bounded transcript output,
  finite/clamped model download progress, and capped user-facing status/error text.
- `Epistemos/Views/Shared/VoiceInputButton.swift` — consume the live facade, present disabled honesty, and use shared
  native toolbar chrome.
- `Epistemos/Views/Settings/VoiceSettingsDetailView.swift` — composes Apple voice controls with the Pro-only Kokoro
  status/runtime affordance outside the MAS-safe Apple picker.
- `Epistemos/VoicePro/KokoroVoiceProSettingsSection.swift` — Pro-only "Pro neural voice" row backed by the gate status,
  with theme-derived badge tints and shared native capsule install/refresh chrome.
- `Epistemos/VoicePro/KokoroVoicePackageInstaller.swift` — Pro-only local checked-package installer with symlink
  descendant rejection, staged copy, backup/restore finalization, and bounded status diagnostics.
- `EpistemosTests/VoiceCodepackPlan3Tests.swift` — source guards for voice floor, inert-toggle removal/wiring, STT facade,
  Pro Kokoro status/install UI, and no Kokoro/MAS subprocess leakage.

## Plan boundaries
- Do not edit `Epistemos/Goose/*` or `Epistemos/Agent/*`.
- Do not build Plan 2 editor features here. If `noteReadAloud` needs an editor consumer, Plan 2 owns the editor mount;
  Plan 3 owns the voice service contract and honest Settings row.
- Do not add cloud STT/TTS as the default. Apple Speech/AVSpeech are the MAS defaults; Whisper/Kokoro are Pro options.
- Do not surface a "Premium" or "neural" label unless the selected voice/runtime proves that capability.

## Verification gates
- Unit/source tests prove `preferredVoice` no longer depends on `AVSpeechSynthesisVoice(language:)` as the normal floor.
- Source guards prove Personal Voice access uses Apple's macOS 14+ AVSpeech authorization API and refreshes the shared
  voice picker without hardcoded system colors or ad hoc bordered/link buttons.
- Settings source guard proves every visible Auto/Manual row has a behavior consumer or an honest unavailable state.
- STT source guard proves `VoiceInputButton` no longer routes only to the removed `ComposerVoiceInputService` stub and
  does not regress to ad hoc borderless/raw accent chrome.
- STT facade tests prove partial/final transcript helpers stay inside the capture pipeline text envelope before callbacks.
- macOS 26 compile guard proves `EpistemosSpeechAnalyzer` remains `@available(macOS 26.0, *)`.
- Kokoro gate tests prove malformed, symlink-routed, non-regular, placeholder, digest-mismatched, or
  oversized/invalid-manifest model artifacts keep AVSpeech as the runtime without exposing local model roots in UI-facing
  status details.
- MAS boundary guard proves no Kokoro weights, Python, subprocess, or Chromium-like runtime enters the App Store target.

## Delivery order
1. [DONE] Patch the AVSpeech preferred voice floor and add tests.
2. [DONE] Wire or remove `agentResponseTTS`; add a source guard so it cannot regress to a visible no-op.
3. [DONE] Add `LiveVoiceInputService` over `EpistemosSpeechAnalyzer`.
4. [DONE] Rewire `VoiceInputButton` to live STT or hide/disable it honestly where unsupported.
5. [DONE] Add SSML/prosody fallback.
6. [DONE] Add Personal Voice authorization.
7. [DONE] Add the Kokoro Pro gate as status-only.
8. [DONE] Add the Pro-only Kokoro settings status/runtime affordance.
9. [DONE] Add a local checked-package installer. Network model download and neural inference integration remain deferred
   until model download health and real audio synthesis are proven.
