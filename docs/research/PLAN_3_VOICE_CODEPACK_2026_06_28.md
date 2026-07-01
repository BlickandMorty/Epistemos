# Plan 3 — Voice codepack (shipped code, Pass 8)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §11`. Scope: Apple-native STT plus Kokoro-only TTS gating.
> This codepack is grounded in current source and supersedes older broad voice notes where they conflict. Plan 3 owns
> voice engines/settings/shared controls; Plan 2 editor surfaces are integration consumers only.

## Shipped state `[VERIFIED-CODE]`
- **Kokoro-only TTS is honestly unavailable until the native engine is wired:** `EpistemosSpeechSynthesizer.speak()`
  refuses playback while `KokoroVoiceGateStatus.isReady == false` and the native Kokoro synthesis engine is not linked.
  It does not call `AVSpeechSynthesizer.speak` as a silent fallback. `ReadAloudButton` remains visible through native
  capsule chrome but disables itself with the same Kokoro-only unavailable status.
- **Legacy Apple voice code is unwired from the shipped TTS path:** the AVSpeech catalogue, global default identifier,
  Personal Voice helpers, and voice-quality hints remain in code only for compatibility and future migration. Shipped
  read-aloud/TTS surfaces do not expose an Apple voice picker or use AVSpeech as the playback path.
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
- **Legacy Apple voice compatibility helpers stay source-guarded:** `preferredVoice()` resolves installed voices by
  Premium > Enhanced > Default, `speak(..., prosody:)` still has an SSML/plain utterance builder for any future migration,
  and those helpers are not wired into shipped playback while Kokoro synthesis is unavailable.
- **Personal Voice authorization is live but not a shipped TTS fallback:** `EpistemosSpeechSynthesizer` wraps
  `AVSpeechSynthesizer.personalVoiceAuthorizationStatus` and `requestPersonalVoiceAuthorization` behind a macOS 14+
  availability gate. `ModelVoicePickerSection` exposes an unavailable TTS state until Kokoro synthesis is live and keeps
  any hidden legacy picker affordances on theme-derived tints instead of hardcoded system colors.
- **Pro Kokoro gate is honest:** `KokoroVoiceGateStatus` exists as a status-only gate. MAS returns unavailable, Pro
  requires `EPISTEMOS_KOKORO_VOICE_PRO_V0=1`, and missing `KokoroRuntimeManifest.json` / segmented
  `mattmireles/kokoro-coreml` bundle assets keeps text-to-speech unavailable with no Apple AVSpeech fallback. Package
  verification rejects symlink-routed or non-regular model artifacts, requires a bounded no-follow runtime manifest with
  the expected repo/platform/language/token-bucket/model-package/runtime-asset/voice fields, requires JSON numeric
  fields to be finite integers, caps declared per-file and total package bytes before digesting any listed artifact, and
  verifies the listed segmented `.mlpackage`, runtime vocab/HNSF, and `af_heart` voice file sizes plus SHA-256 digests
  before reporting `packageReady`. Package-ready status carries manifest-derived package evidence (Core ML package
  count, voice count, runtime asset count, checked file count, and declared bytes) without exposing local roots.
  `isReady` remains false until real neural synthesis is wired and
  selectable. Status details use bounded-before-trim model-relative diagnostics with ellipsis inside configured caps
  instead of local absolute model paths. A Pro-only
  Voice settings section now shows the `TTS unavailable` / `Kokoro neural voice` runtime affordance and keeps TTS
  unavailable until both the checked package and real native Kokoro synthesis runtime are proven.
- **Local Kokoro package install/removal is real but runtime-disabled:** `KokoroVoicePackageInstaller` lets Pro users choose a
  prepared `kokoro-82m-coreml` folder (or its parent), validates it with the existing gate, rejects symlink descendants,
  rejects symlink-routed install roots before Application Support writes, stages it under Application Support with backup/restore finalization, revalidates the installed package before the
  settings row reports `packageReady`, and a failed replacement install rolls back to the previous package instead of deleting the backup; the same Pro settings row now displays the gate's manifest-derived package
  evidence and can remove the installed local package, returning the gate to missing-model status without enabling the neural runtime. There is still no committed Kokoro model asset,
  neural inference runtime, Python, subprocess, network downloader, or MAS-visible Kokoro row.
- **Voice live smoke covers Pro Kokoro gate, settings presentation, and checked package install/removal:** the bounded
  operator smoke now exercises the checked installer stage, gate-backed removal, manifest-derived package evidence, and
  runtime-disabled `packageReady` presentation without enabling neural inference.

## Delivered MAS-safe fixes
1. **Gate shipped TTS as Kokoro-only.** `[DONE]` `EpistemosSpeechSynthesizer.speak()` returns no playback while Kokoro
   synthesis is unavailable, disables read-aloud controls through `isTextToSpeechAvailable()`, and does not use AVSpeech
   as the fallback path.
2. **Keep legacy Apple voice helpers compatibility-only.** `[DONE]` AVSpeech voice catalogue, preferred-voice,
   SSML/prosody, and Personal Voice helpers remain guarded for compatibility but are unwired from shipped playback.
3. **Remove visible Apple voice selection from Quick Capture.** `[DONE]` Quick Capture keeps the shared read-aloud
   affordance but no longer surfaces a point-of-use Apple voice picker.
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
- `[DONE]` Add a Pro-only Voice settings status/runtime affordance that says "TTS unavailable" until the checked package
  gate and real Kokoro native synthesis runtime are both proven. The disabled target runtime is "Kokoro neural voice";
  there is no Apple AVSpeech fallback lane.
- `[DONE]` Add a Pro-only local checked-package installer/remover so a prepared package can reach `packageReady` and be
  cleared again without adding a network downloader or neural runtime.
- Store model assets outside MAS target resources; never commit model weights.
- Integrate through the existing model download manager only after that manager is proven healthy.
- The Pro runtime row must continue saying "TTS unavailable" until a checked package and proven Kokoro synthesis runtime
  exist; package readiness without synthesis must not enable playback.
- Do not add Python/subprocess inference on the MAS path.

## Shipped files / source guards
- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift` — Kokoro-only TTS availability gate; legacy AVSpeech helpers remain
  compatibility-only and are not the shipped playback path.
- `Epistemos/Views/Shared/ReadAloudButton.swift` — shared Kokoro-only read-aloud control on native capsule chrome with
  theme-derived progress drawing and honest unavailable state.
- `Epistemos/Views/Shared/ModelVoicePickerSection.swift` — unavailable Kokoro-only TTS state plus hidden legacy Apple
  voice compatibility helpers.
- `Epistemos/Engine/VoicePreferences.swift` — keep keys, but only expose keys with consumers.
- `Epistemos/Views/Settings/VoicePreferencesSection.swift` — remove or honestly gate `agentResponseTTS` until wired, and
  keep visible rationale/preview controls on shared native chrome.
- `Epistemos/Engine/LiveVoiceInputService.swift` — facade over `EpistemosSpeechAnalyzer` with bounded transcript output,
  finite/clamped model download progress, and capped user-facing status/error text.
- `Epistemos/Views/Shared/VoiceInputButton.swift` — consume the live facade, present disabled honesty, and use shared
  native toolbar chrome.
- `Epistemos/Views/Settings/VoiceSettingsDetailView.swift` — composes visible voice preferences with the Pro-only Kokoro
  status/runtime affordance.
- `Epistemos/VoicePro/KokoroVoiceProSettingsSection.swift` — Pro-only `TTS unavailable` / `Kokoro neural voice` row backed
  by the gate status, with theme-derived badge tints, manifest-derived package evidence, and shared native capsule install/remove/refresh chrome.
- `Epistemos/VoicePro/KokoroVoicePackageInstaller.swift` — Pro-only local checked-package installer/remover with symlink
  descendant rejection, staged copy, failed-finalization rollback, gate-backed removal, and bounded status diagnostics.
- `scripts/voice-live-smoke.swift` — bounded operator smoke for transcript/status helpers plus the Pro Kokoro gate,
  settings presentation, manifest-derived package evidence, and checked package install/removal without enabling the neural runtime.
- `EpistemosTests/VoiceCodepackPlan3Tests.swift` — source guards for voice floor, inert-toggle removal/wiring, STT facade,
  Pro Kokoro status/install/remove UI, and no Kokoro/MAS subprocess leakage.

## Plan boundaries
- Do not edit `Epistemos/Goose/*` or `Epistemos/Agent/*`.
- Do not build Plan 2 editor features here. If `noteReadAloud` needs an editor consumer, Plan 2 owns the editor mount;
  Plan 3 owns the voice service contract and honest Settings row.
- Do not add cloud STT/TTS as the default. Apple Speech remains the native STT lane. Kokoro is the only shipped TTS lane;
  do not ship AVSpeech/basic system voice as read-aloud/TTS fallback.
- Do not surface a "Premium" or "neural" label unless the selected voice/runtime proves that capability.

## Verification gates
- Unit/source tests prove `speak()` does not call `AVSpeechSynthesizer.speak` while Kokoro synthesis is unavailable.
- Source guards prove Personal Voice access stays compatibility-only and unavailable TTS UI uses shared theme chrome
  without hardcoded system colors or ad hoc bordered/link buttons.
- Settings source guard proves every visible Auto/Manual row has a behavior consumer or an honest unavailable state.
- STT source guard proves `VoiceInputButton` no longer routes only to the removed `ComposerVoiceInputService` stub and
  does not regress to ad hoc borderless/raw accent chrome.
- STT facade tests prove partial/final transcript helpers stay inside the capture pipeline text envelope before callbacks.
- macOS 26 compile guard proves `EpistemosSpeechAnalyzer` remains `@available(macOS 26.0, *)`.
- Kokoro gate tests prove malformed, symlink-routed, non-regular, placeholder, digest-mismatched, or
  oversized/invalid-manifest model artifacts keep TTS unavailable with no AVSpeech fallback and without exposing local
  model roots in UI-facing status details.
- MAS boundary guard proves no Kokoro weights, Python, subprocess, or Chromium-like runtime enters the App Store target.

## Delivery order
1. [DONE] Gate shipped TTS as Kokoro-only and add tests.
2. [DONE] Wire or remove `agentResponseTTS`; add a source guard so it cannot regress to a visible no-op.
3. [DONE] Add `LiveVoiceInputService` over `EpistemosSpeechAnalyzer`.
4. [DONE] Rewire `VoiceInputButton` to live STT or hide/disable it honestly where unsupported.
5. [DONE] Add SSML/prosody fallback.
6. [DONE] Add Personal Voice authorization.
7. [DONE] Add the Kokoro Pro gate as status-only.
8. [DONE] Add the Pro-only Kokoro settings status/runtime affordance.
9. [DONE] Add a local checked-package installer/remover. Network model download and neural inference integration remain
   deferred until model download health and real audio synthesis are proven.
