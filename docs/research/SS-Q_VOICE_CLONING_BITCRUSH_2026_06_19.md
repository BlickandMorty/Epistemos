# SS-Q — Voice cloning + bitcrush DSP + custom branded system voice (2026-06-19)

Read-only research (subagent), code-grounded + web. Feeds the VOICE ledger item. Owner: *"Apple premium by
default + voice cloning (create my own voice) and/or a bitcrush filter over any voice; the system voice = a
custom voice WITH the filter."* All local/on-device, MAS-safe. Extends SS-K (don't re-derive the picker/premium
default).

## Headline (what's actually possible, all on-device)
- **USE an existing Personal Voice for synthesis: YES** — `AVSpeechSynthesizer.requestPersonalVoiceAuthorization`
  + filter `speechVoices()` on the `.isPersonalVoice` trait (macOS 14+). **TRAIN a new Personal Voice in-app:
  NO** — the 15-min enrollment lives only in System Settings → Accessibility → Personal Voice; the app can
  deep-link there but cannot create one.
- **Bitcrush over ANY voice: YES, and the DSP ALREADY EXISTS in this repo** — `AmbientFrequencyLivePlayer.swift`
  has a verified bit-depth-crush + sample-rate-hold kernel. The only new work is routing
  `AVSpeechSynthesizer.write(_:toBufferCallback:)` PCM buffers through an `AVAudioEngine` graph (player →
  crusher → output). No entitlement, no cloud.
- **Apple premium default** = SS-K (`preferredVoice()` Premium>Enhanced>default); noted, not re-derived.

## Personal Voice (cloning) — what's possible + entitlement
- **API (verified):** `requestPersonalVoiceAuthorization { status in … }` → `PersonalVoiceAuthorizationStatus`
  (`.authorized/.denied/.notDetermined/.unsupported`). Once `.authorized`, the user's Personal Voice appears in
  `speechVoices()`, identified by `voice.voiceTraits.contains(.isPersonalVoice)`; build an `AVSpeechUtterance`
  with it like any voice → drops into `resolveVoice(identifier:)` (`EpistemosSpeechSynthesizer.swift:209-215`).
- **Platforms:** macOS 14+/iOS 17+, newer hardware; older devices return `.denied`. Created by the user in System
  Settings (~15-min training); apps only request authorization to USE, never train.
- **Entitlement/plist:** No special entitlement; gated by a system consent prompt. Apple does NOT clearly
  document `NSPersonalVoiceUsageDescription` as required (the working community impl adds no plist key) —
  **[unverified]** whether macOS shows app rationale; test on a Mac with a real Personal Voice. MAS entitlements
  unchanged.
- **Repo state:** Personal Voice NOT used anywhere (zero hits — confirms SS-K).

## Bitcrush DSP — the AVAudioEngine path
- `AVSpeechSynthesizer` exposes no effect insert. MAS-safe path = `synthesizer.write(utterance){ buffer in … }`
  → schedule `AVAudioPCMBuffer`s on an `AVAudioPlayerNode` in an `AVAudioEngine`, crusher node between player +
  output. **Gotcha:** `write` often emits **int16** → convert to **float32** via `AVAudioConverter` before
  scheduling or the player node silently no-ops.
- **Simplest crusher = REUSE the existing kernel** — the repo already implements bitcrush as scalar math:
  bit-depth quantize `AmbientFrequencyLivePlayer.swift:699-702` (`levels=1<<(bits-1); (s*levels).rounded()/
  levels`) + sample-rate zero-order-hold `:687-697` + sanitizers `:50-63`. Wrap that math in an
  `AVAudioSourceNode`/manual buffer tap — no AUv3 registration, no C++ DSP kernel, all Swift. (`AVAudioUnit
  Distortion` is NOT a bitcrusher — don't substitute.)
- **Existing AVAudioEngine to reuse:** `AmbientFrequencyLivePlayer.swift:153 private let engine = AVAudioEngine()`
  — full working engine + `AVAudioSourceNode` render callback (`:352-390`), stereo format negotiation
  (`:322-348`), real-time discipline, AND the bitcrush DSP. The single highest-leverage asset. (`EpistemosSpeech
  Analyzer.swift` + `AudioTranscriber.swift` are capture/STT-side input — pattern reference only.)

## Architecture to add (file:line hooks)
1. **Extract the crusher math** from `AmbientFrequencyLivePlayer`'s `LivePlayerParameters` (`:687-702`) into a
   shared `nonisolated BitcrushKernel` (one source of truth for ambient + speech).
2. **`VoiceEffect` enum** — `none` / `bitcrush(depthBits:Int, sampleRateHold:Int)` + a "pixel-art signature"
   preset (e.g. `bitcrush(depthBits:6, sampleRateHold:4)`), tunable.
3. **Extend `EpistemosSpeechSynthesizer`** (`:127 speak(...)`): optional `effect: VoiceEffect = .none` + a private
   `AVAudioEngine`+`AVAudioPlayerNode` lane. `.none` keeps the current direct `synthesizer.speak` (zero
   regression to SS-K's path + delegate progress `:286-354`); with an effect → `write→convert→crush→schedule`.
4. **Branded system voice** = stored `(baseVoiceIdentifier, VoiceEffect.bitcrush(preset))`; home = new keys
   alongside `VoicePreferenceKeys` in `VoicePreferences.swift:50-78` (`systemVoiceIdentifier`+`systemVoiceEffect`).

## Honest gating + SS-K composition
- All AVFoundation, on-device, MAS-safe; bitcrush adds no entitlement; Personal Voice adds only the runtime auth
  prompt (+ possibly a usage string — verify).
- **Picker (SS-K `ModelVoicePickerSection.swift`):** already groups Premium/Enhanced/Default (`:88-96`) +
  deep-links Manage Voices (`:192-197`). SS-Q adds: (a) a **Personal Voice** group shown only after `.authorized`
  + an "Enable my Personal Voice" button (`requestPersonalVoiceAuthorization`) + a "Create in System Settings…"
  deep-link (mirror `NSWorkspace.shared.open` `:192-197`; exact URL anchor **[unverified]**); (b) a **bitcrush
  toggle + intensity slider** binding `VoiceEffect`, reusing the rate/pitch slider layout (`:100-120`).
- `ReadAloudButton.swift` + the per-model field (`SDModelProfile.voiceIdentifier:83`, wired `ModelProfile
  DetailView.swift:180`) need no shape change — they pass through `speak(...)` which gains the optional `effect`.
- **macOS-26 [unverified]:** confirm Personal Voice trait/availability + consent UI before shipping; the
  `write→engine` path is stable AVFoundation.
- **Pro `say` tool** (`agent_core/src/tools/media.rs:676`) shells `/usr/bin/say` — SEPARATE CLI path, no Personal
  Voice / bitcrush access; keep SS-Q entirely in the Swift AVFoundation lane.

## Ordered plan
1. **[S]** Extract shared `BitcrushKernel` from `AmbientFrequencyLivePlayer.swift:687-702`; add `VoiceEffect` +
   pixel-art preset; add `systemVoiceEffect`/`systemVoiceIdentifier` keys to `VoicePreferences.swift`.
2. **[S]** Add `requestPersonalVoiceAuthorization` + `.isPersonalVoice` filtering to `availableVoices`/a new
   `personalVoices()` (`EpistemosSpeechSynthesizer.swift:186-203`); surface a Personal Voice group + auth/deep-link
   in `ModelVoicePickerSection.swift`.
3. **[M]** Build the `write→AVAudioConverter(int16→float32)→AVAudioPlayerNode→crush→engine.output` lane behind the
   optional `effect` param; preserve the no-effect fast path + delegate progress; add the bitcrush toggle/slider.
4. **[M]** Wire the branded system voice (base + bitcrush preset) as default narration; Swift Testing (buffer
   conversion, quantize/hold parity with the ambient kernel, no-effect regression).
5. **[L]** On-device validation: Personal Voice auth on real Mac (+ whether `NSPersonalVoiceUsageDescription` is
   needed), macOS-26 behavior, real-time playback under thermal/route-change.

## Bottom line
SS-Q is mostly ASSEMBLY, not invention: the bitcrush kernel already ships; Personal Voice is a small auth+filter
add; the one new piece is the `write→AVAudioEngine` effect lane. All on-device, no cloud, MAS-safe.

Key files: `Engine/EpistemosSpeechSynthesizer.swift` (`:110,127,186-203,209-228,286-354`) · `Engine/Ambient
FrequencyLivePlayer.swift` (`:153,322-348,352-390,687-702` bitcrush DSP) · `Engine/VoicePreferences.swift:50-78`
· `Views/Shared/ModelVoicePickerSection.swift` (`:88-96,100-120,192-197`) · `Views/Shared/ReadAloudButton.swift`
· `Models/SDModelProfile.swift:83` · `Views/ModelProfiles/ModelProfileDetailView.swift:180` · `agent_core/src/
tools/media.rs:676`. Sources: Apple WWDC23 "Extend Speech Synthesis"; AVSpeechSynthesizer PersonalVoice
AuthorizationStatus docs; Ben Dodson Personal-Voice-in-app; Apple forums write/toBufferCallback→AVAudioEngine
int16→float32 (729218, 684419). Cross-ref SS-K.
