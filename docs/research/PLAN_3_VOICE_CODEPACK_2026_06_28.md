# Plan 3 — Voice codepack (shipped code, Pass 8)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §11`. Scope: Apple-native STT plus Kokoro-only TTS gating.
> This codepack is grounded in current source and supersedes older broad voice notes where they conflict. Plan 3 owns
> voice engines/settings/shared controls; Plan 2 editor surfaces are integration consumers only.

## Shipped state `[VERIFIED-CODE]`
- **Kokoro-only TTS is live when a checked Pro CoreML package is installed:** `EpistemosSpeechSynthesizer.speak()`
  refuses playback while `KokoroVoiceGateStatus.isReady == false`; when the checked `mattmireles/kokoro-coreml`
  package is present in a Pro build, it renders through native `KokoroPipeline` + `AVAudioEngine` playback. It does not
  call `AVSpeechSynthesizer.speak` as a silent fallback.
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
  with raw status/domain strings bounded, control/whitespace-normalized, then punctuation-validated before voice UI
  display; status ellipsis stays inside the configured cap.
- **Reusable mic API has no inert auto-stop flag:** `VoiceInputButton` is manual by design; surfaces that support
  automatic silence-stop own the policy at their capture-service boundary.
- **Legacy Apple voice compatibility helpers stay source-guarded:** `preferredVoice()` resolves installed voices by
  Premium > Enhanced > Default, and the SSML/plain utterance builder remains for migration only. Those helpers are not
  wired into shipped playback; Kokoro is the playback path.
- **Personal Voice authorization is live but not a shipped TTS fallback:** `EpistemosSpeechSynthesizer` wraps
  `AVSpeechSynthesizer.personalVoiceAuthorizationStatus` and `requestPersonalVoiceAuthorization` behind a macOS 14+
  availability gate. `ModelVoicePickerSection` exposes an unavailable TTS state until the Kokoro package/runtime gate is ready and keeps
  any hidden legacy picker affordances on theme-derived tints instead of hardcoded system colors.
- **Pro Kokoro gate is honest:** `KokoroVoiceGateStatus` exists as the package/runtime gate. MAS returns unavailable, Pro
  requires `EPISTEMOS_KOKORO_VOICE_PRO_V0=1`, and missing `KokoroRuntimeManifest.json` / segmented
  `mattmireles/kokoro-coreml` bundle assets keeps text-to-speech unavailable with no Apple AVSpeech fallback. Package
  verification rejects symlink-routed or non-regular model artifacts, requires a bounded no-follow runtime manifest with
  the expected repo/platform/language/token-bucket/model-package/runtime-asset/voice fields, requires JSON numeric
  fields to be finite integers, requires every manifest-declared duration token-size package plus the bucket-specific
  f0ntrain/decoder_pre/decoder_har_post packages needed by the native Swift/CoreML pipeline, caps declared per-file and
  total package bytes before digesting any listed artifact, verifies the listed segmented `.mlpackage`, runtime
  vocab/HNSF, and `af_heart` voice file sizes plus SHA-256 digests, and parses the runtime vocab/HNSF plus exact
  256-Float32 starter voice shape before reporting `packageReady`. Package-ready status
  carries manifest-derived package evidence (Core ML package count, voice count, runtime asset count, checked file count,
  declared bytes, and a bounded printable bundle profile) without exposing local roots.
  `isReady` is true only when the checked package can feed the linked native playback path. Status details use
  bounded and control/whitespace-normalized model-relative diagnostics with ellipsis inside configured caps instead of
  local absolute model paths. A Pro-only Voice settings section now shows the `TTS unavailable` / `Kokoro neural voice` runtime affordance and
  selects `Kokoro neural voice` only when that package/runtime gate is ready.
- **Native Kokoro Swift/CoreML playback is wired:** `LocalPackages/KokoroPipeline` vendors
  the upstream Swift package pinned at `052bdcd8333d4ac38d77485a5067d9a1e3397cac`, `project.yml` links the
  `KokoroPipeline` product, and `KokoroCoreMLRuntimeLoader` turns a checked local package into CoreML model/runtime URLs,
  parses `runtime/kokoro-vocab.json` plus `runtime/hnsf_weights.json` through bounded no-follow reads, loads the exact
  `af_heart` 256-Float32 voice embedding, and instantiates `KokoroPipeline` on demand. `KokoroCoreMLSynthesizer` tokenizes
  supported raw vocabulary characters, chunks to the manifest duration-token cap, joins synthesized 24 kHz PCM, and
  `EpistemosSpeechSynthesizer` plays it through `AVAudioEngine` while advancing observable read-aloud progress from
  `AVAudioPlayerNode` render time. This remains native Swift/CoreML only: no model weights
  are committed and no network downloader is added. A higher-quality phonemizer remains future polish; the live path is
  an honest raw-vocabulary Kokoro path.
- **Local Kokoro package install/removal is real and playback-enabling:** `KokoroVoicePackageInstaller` lets Pro users choose a
  prepared `kokoro-82m-coreml` folder (or its parent), validates it with the existing gate, rejects symlink descendants,
  rejects symlink-routed install roots before Application Support writes, stages it under Application Support with backup/restore finalization, revalidates the installed package before the
  settings row reports `packageReady`, and a failed replacement install rolls back to the previous package instead of deleting the backup; the same Pro settings row now displays the gate's manifest-derived package
  evidence and can remove the installed local package, returning the gate to missing-model status. There is still no
  committed Kokoro model asset, network downloader, Python, subprocess, or MAS-visible Kokoro row.
- **Voice live smoke covers Pro Kokoro gate, settings presentation, and checked package install/removal:** the bounded
  operator smoke now exercises the checked installer stage, gate-backed removal, manifest-derived package evidence, and
  package-ready `Kokoro neural voice` presentation without running a synthesis job.

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

## Pro Kokoro lane `[NATIVE COREML PLAYBACK WIRED]`
Kokoro-82M is Pro-only until packaging and model-download gates are proven:
- `[DONE]` Add `Epistemos/VoicePro/KokoroVoiceGateStatus.swift` with `.unavailable/.missingModel/.packageReady`;
  package-ready reports `isReady=true` only when the linked native playback path can consume the checked package.
- `[DONE]` Add a Pro-only Voice settings status/runtime affordance that says "TTS unavailable" until the checked package
  gate is ready, then selects "Kokoro neural voice"; there is no Apple AVSpeech fallback lane.
- `[DONE]` Add a Pro-only local checked-package installer/remover so a prepared package can reach `packageReady` and be
  cleared again without adding a network downloader.
- `[DONE]` Vendor the native Swift/CoreML `KokoroPipeline` source and add a checked-bundle runtime loader for CoreML
  model URLs plus vocab/HNSF/starter-voice runtime assets.
- `[DONE]` Add `KokoroCoreMLSynthesizer` and wire `EpistemosSpeechSynthesizer.speak()` to native CoreML synthesis plus
  `AVAudioEngine` playback for checked Pro packages.
- Store model assets outside MAS target resources; never commit model weights.
- Integrate through the existing model download manager only after that manager is proven healthy.
- The Pro runtime row must continue saying "TTS unavailable" until a checked package and linked native Kokoro runtime
  exist.
- Do not add Python/subprocess inference on the MAS path.

## Shipped files / source guards
- `Epistemos/Engine/EpistemosSpeechSynthesizer.swift` — Kokoro-only TTS availability gate and native CoreML audio
  playback bridge; legacy AVSpeech helpers remain compatibility-only and are not the shipped playback path.
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
- `Epistemos/VoicePro/KokoroCoreMLRuntimeLoader.swift` — native Swift/CoreML checked-bundle loader for
  `KokoroPipeline`, bounded runtime manifest/vocab/HNSF reads, and starter-voice embedding loading.
- `Epistemos/VoicePro/KokoroCoreMLSynthesizer.swift` — raw-vocabulary tokenizer/chunker plus `KokoroPipeline` PCM
  synthesis bridge.
- `LocalPackages/KokoroPipeline` — vendored upstream Swift package (`KokoroPipeline`) pinned at
  `052bdcd8333d4ac38d77485a5067d9a1e3397cac`; no model weights.
- `scripts/voice-live-smoke.swift` — bounded operator smoke for transcript/status helpers plus the Pro Kokoro gate,
  settings presentation, manifest-derived package evidence, and checked package install/removal without running synthesis.
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
- Unit/source tests prove `speak()` does not call `AVSpeechSynthesizer.speak`; checked Pro packages use the native Kokoro
  path.
- Source guards prove Personal Voice access stays compatibility-only and unavailable TTS UI uses shared theme chrome
  without hardcoded system colors or ad hoc bordered/link buttons.
- Settings source guard proves every visible Auto/Manual row has a behavior consumer or an honest unavailable state.
- STT source guard proves `VoiceInputButton` no longer routes only to the removed `ComposerVoiceInputService` stub and
  does not regress to ad hoc borderless/raw accent chrome.
- STT facade tests prove partial/final transcript helpers stay inside the capture pipeline text envelope before callbacks.
- macOS 26 compile guard proves `EpistemosSpeechAnalyzer` remains `@available(macOS 26.0, *)`.
- Kokoro gate tests prove malformed, symlink-routed, non-regular, placeholder, digest-mismatched,
  oversized/invalid-manifest, or invalid manifest-metadata model artifacts keep TTS unavailable with no AVSpeech fallback
  and without exposing local model roots in UI-facing status details.
- MAS boundary guard proves no Kokoro weights, Python, subprocess, or Chromium-like runtime enters the App Store target.
  The vendored `KokoroPipeline` package is native Swift/CoreML source only.

## Delivery order
1. [DONE] Gate shipped TTS as Kokoro-only and add tests.
2. [DONE] Wire or remove `agentResponseTTS`; add a source guard so it cannot regress to a visible no-op.
3. [DONE] Add `LiveVoiceInputService` over `EpistemosSpeechAnalyzer`.
4. [DONE] Rewire `VoiceInputButton` to live STT or hide/disable it honestly where unsupported.
5. [DONE] Add SSML/prosody fallback.
6. [DONE] Add Personal Voice authorization.
7. [DONE] Add the Kokoro Pro gate as status-only.
8. [DONE] Add the Pro-only Kokoro settings status/runtime affordance.
9. [DONE] Add a local checked-package installer/remover.
10. [DONE] Vendor native `KokoroPipeline` source and add a checked-bundle loader.
11. [DONE] Wire native CoreML raw-vocabulary synthesis and `AVAudioEngine` playback. Network model download and
    high-quality phonemization remain deferred polish.
