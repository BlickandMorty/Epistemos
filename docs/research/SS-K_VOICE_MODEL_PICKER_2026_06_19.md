# SS-K — Voice-model picker (Settings + chat-surface contextual) (2026-06-19)

Read-only research (subagent), code-grounded. Feeds SETTINGS_SIMPLIFICATION_HUB + the VOICE-MODEL-PICKER +
VOICE high-def ledger items. Owner: *"choose different voice models in settings, and a picker on the chat
surfaces that only fires when you use TTS"* + the known macOS-26 "voice still plain/low-def" regression.

## Headline
**MOSTLY EXISTS — the picker is built + wired; the macOS-26 "plain voice" root is a ~2-line fallback bug, and
the chat-surface contextual picker is the one genuinely-new piece.** The app already has a real Apple-native
TTS stack with a per-model voice picker (grouped by quality tier), a Settings home, a chat-surface speaker
button, and a Pro-gated `say` agent tool. The owner's "low-def voice" complaint traces to a specific fallback
path, not a missing feature.

## Already REAL
- **Synthesizer core** — `EpistemosSpeechSynthesizer.swift:42` `@MainActor @Observable` singleton wrapping
  `AVSpeechSynthesizer` (`:110`); speak/pause/resume/stop + per-range progress; pre-warms `speechVoices()` `:118`.
- **Voice catalogue + selection** — `availableVoices(language:)` enumerates `speechVoices()`, maps to
  `VoiceOption`, sorts by quality tier (`:186-203`). `resolveVoice(identifier:)` uses the **explicit
  `AVSpeechSynthesisVoice(identifier:)` path (`:209-215`) — the correct premium-honoring API.**
- **Quality tiers** — `VoiceQualityTier{default,enhanced,premium,premiumAvailable}` (`:74-88`); `tier(for:)`
  reads `voice.quality` (`:256-263`).
- **Per-model persistence** — `SDModelProfile.swift:83 voiceIdentifier:String?`, `:88 voiceRate`, `:91
  voicePitch` (SwiftData `@Model`, per-profile — NOT global `@AppStorage`).
- **Settings picker UI** — `Views/Shared/ModelVoicePickerSection.swift` — `Picker` grouped by tier (`:73-86`),
  rate/pitch sliders, "Hear preview", quality hint + "Open Manage Voices…" deep-link (`:192-197`). Mounted in
  `Views/ModelProfiles/ModelProfileDetailView.swift:179`.
- **Settings auto/manual prefs** — `Views/Settings/VoicePreferencesSection.swift` under the **Cognitive** tab
  (`CognitiveSettingsSection.swift:74` → `SettingsView.swift:470 case cognitive`); `perModelVoicePersona` row
  (`:52-57`).
- **Chat-surface speaker button** — `Views/Shared/ReadAloudButton.swift` (icon/labeled/progress styles) on
  assistant bubbles at `Views/Chat/MessageBubble.swift:407` `.opacity(0.6)`; context menu Speak/Pause/Resume/Stop
  (`:93-109`). **Gap: MessageBubble passes only `text:`, NO `voiceIdentifier` → chat read-aloud always falls to
  `preferredVoice()`.**
- **Rust `say` tool** — `agent_core/src/tools/media.rs:678 TextToSpeechHandler` spawns `say` (`:711`) hardened
  (`:716`), 8000-char cap, 60s timeout; `media.text_to_speech` (`registry.rs:480`), **Pro-tier only**
  (`CHAT_PRO_EXTRA registry.rs:1153`). Agent-callable, distinct from the in-app Swift AVSpeech path.
- **Personal Voice: NOT used** (no `requestPersonalVoiceAuthorization`/`AVSpeechSynthesisProviderVoice` — grep
  empty).

## The plain-voice ROOT + fix
The explicit-identifier path is correct, but **`preferredVoice()` `:219-228` is the bug.** When no per-model
`voiceIdentifier` is set (the default, and the case for ALL chat read-aloud since MessageBubble passes none),
`resolveVoice(nil)`→`preferredVoice()`: (1) tries `en`+`.premium` `:221`, (2) `en`+`.enhanced` `:224`, (3) else
falls to `AVSpeechSynthesisVoice(language: currentLanguageCode())` `:227` — **exactly the macOS-26-regressing
default-by-language path** that returns the Compact voice even when an enhanced/premium voice is installed.
Steps 1-2 only fire if the premium voice is already downloaded locally (Apple has no programmatic install API;
the `:235-252` hint correctly points to Manage Voices). **Fix [S]:** replace the `:227` language fallback with an
explicit best-of `speechVoices()` scan — pick the highest `.quality` voice for the user's language by
`qualityRank`, use `(language:)` only as last resort + surface the "no enhanced/premium installed → Manage
Voices" hint more aggressively. **Unverified:** exact macOS-26 `speechVoices()` quality-flag behavior on the
owner's machine — needs a runtime probe.

## Settings picker design
A real per-model picker already lives in `ModelProfileDetailView` (model-profile detail, NOT the Settings tab
tree). Per SS-B (voice = disclosure under Models/General, not a new top-level home): auto/manual prefs are
already correctly under **Cognitive**. Recommended [S/M]: add a **global default-voice** `ModelVoicePicker
Section` row under **Models** (`SettingsView.swift:78 case models`) or General, persisted via
`@AppStorage("epistemos.voice.defaultIdentifier")` as the app-wide fallback chat read-aloud reads (closes the
"MessageBubble passes no identifier" gap). Reuse the existing grouped-by-tier picker verbatim; bind it to the
new `@AppStorage` string.

## Chat-surface contextual TTS picker design ("only fires when you use TTS")
The speaker button is already on every assistant bubble (`MessageBubble.swift:407`). Two low-clutter options:
- **[S] Context-menu submenu** — `ReadAloudButton.contextActions` (`:93-109`) already hosts Speak/Pause/etc.
  Add a "Voice…" submenu listing `availableVoices(language:)` grouped by tier; selection re-invokes
  `synth.speak(text, voiceIdentifier:)`. Zero new always-on chrome.
- **[M] Inline popover-on-speak** — on tap-speak, present a compact `.popover` anchored to the button with the
  tier-grouped picker, defaulting to the resolved voice; dismisses on play, never renders unless speak is
  engaged. Reuse `ModelVoicePickerSection.picker`.
Either way `ReadAloudButton` must start passing a `voiceIdentifier` (it accepts one at `:37`; MessageBubble
doesn't supply it).

## Higher-def lanes + honest gating
- **Apple AVSpeech premium/enhanced — local, MAS-safe** — already the live path, the right default, no network,
  no subprocess.
- **macOS `say` subprocess** — Pro-tier *agent tool* only (`media.rs`/`registry.rs:1153`), hardened; per
  no-sidecar doctrine stays Pro-gated + agent-invoked; do NOT route the in-app read-aloud button through it.
- **Personal Voice** — not wired; a local MAS-safe higher-def add (needs `requestPersonalVoiceAuthorization`
  entitlement). Candidate [L].
- **Neural/cloud TTS (Kokoro/Piper/ElevenLabs/OpenAI)** — only in research docs, NOT product code. Local-first:
  do NOT add cloud/neural TTS now; exhaust Apple premium + Personal Voice first. Cloud TTS = Pro + network +
  REAL-API-verified; local neural = Pro-Gated/Research until provenance gate + witnesses land.

## Ordered plan
1. **[S]** Fix `preferredVoice()` `:227` to scan `speechVoices()` for highest-quality language match — kills the
   macOS-26 compact-voice regression. (The owner's #1 voice complaint.)
2. **[S]** Make `MessageBubble.swift:407` pass a `voiceIdentifier` (global `@AppStorage` default or active
   profile's) so chat read-aloud honors the chosen voice.
3. **[S]** Add "Voice…" submenu to `ReadAloudButton.contextActions` — the contextual chat-surface picker, zero
   new chrome.
4. **[M]** Global default-voice `ModelVoicePickerSection` row under Settings → Models/General with `@AppStorage`.
5. **[M]** Inline popover-on-speak variant (if the submenu feels too hidden).
6. **[L]** Personal Voice lane as a local higher-def upgrade.

Key files: `Engine/EpistemosSpeechSynthesizer.swift` (selection; bug `:219-228`) · `Views/Shared/ModelVoice
PickerSection.swift` (settings picker) · `Views/Shared/ReadAloudButton.swift` (chat speak control, accepts
voiceId `:37`) · `Views/Chat/MessageBubble.swift:407` (missing voiceIdentifier) · `Models/SDModelProfile.swift
:83-91` (per-model persistence) · `Views/Settings/VoicePreferencesSection.swift` + `CognitiveSettingsSection
.swift:74` (settings home) · `Views/ModelProfiles/ModelProfileDetailView.swift:179` · `agent_core/src/tools/
media.rs:676-994` + `registry.rs:1153` (Pro `say` tool).
