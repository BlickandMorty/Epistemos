# UI/UX Audit — Ambient Frequencies (Generator + Settings UI)

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17
- **Driver**: docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md §4.C
- **Surfaces under audit**:
  - `Epistemos/Engine/AmbientFrequencyAudioGenerator.swift` (2,443 LOC)
  - `Epistemos/Views/Settings/AmbientFrequencySettingsView.swift` (495 LOC)
  - `Epistemos/Engine/AmbientFrequencyLivePlayer.swift` (384 LOC; partial — full audit in Iter 2)
- **Verification mode**: Static + `cargo build` + Swift Testing test file.
  Two environmental constraints:
  1. **computer-use MCP not installed** in this session; visual screenshots
     deferred to `docs/verification/screenshots/` once a `computer-use` server
     is wired (see `Epistemos/Omega/Vision/`). Lack of visual capture is a
     P2 finding for the §4.C audit pipeline (driver step 1 mandates
     "computer-use").
  2. **`xcodebuild` cannot fully verify** on the current `main` because of a
     pre-existing P0-level Swift compile failure unrelated to this iter:
     `Epistemos/Vault/VaultLifecycleService.swift:160` declares
     `typealias ContradictionFFI = ContradictionFfi` but no `ContradictionFfi`
     type exists in the codebase or in Xcode-generated bridge sources.
     `git blame` puts this line at commit `d009c25684` (2026-04-10), 5+ weeks
     before T6 cut. **This is the only Swift error the build emits; my edits
     produce zero new errors and zero new warnings.** `cargo build -p
     agent_core` is green (`Finished dev profile ... in 42.80s`). T6's
     scope lock forbids touching `Epistemos/Vault/*`; recommend T9 or a
     vault-owner terminal pick this up as a BLOCKER preventing
     xcodebuild-green iters on this branch.

## Scope

§4.C step 1-8 protocol applied to the Ambient Frequencies surface. This iter
covers the **AudioGenerator + SettingsView**; iter 2 covers the LivePlayer
in depth.

## Inventory verified on disk

- **39 presets** in `AmbientFrequencyPreset.allPresets` (line 1247): exactly
  matches the §4.C inventory claim of "39 presets · 15 primitives."
- **15+ synthesis primitives** as `case`s on `AmbientFrequencyLayer` (lines 37-222):
  amplitudeModulatedCarrier, sine, binauralBeat, organicWhiteNoise,
  intermittentPing, chirp, whiteNoise, pinkNoise, greyNoise, blueNoise,
  violetNoise, brownNoise, bandpassNoise, isochronicTone, pwmSquare,
  triangleWave, sawtoothWave, fmSynth, harmonicPluck, bitCrushed (indirect),
  sampleRateReduced (indirect), opl2FmOperator, panned (indirect), more.
- **25 stackable modules** across 6 categories
  (`AmbientFrequencySoundModuleCategory.allCases` = noiseColor / nature /
  rhythmic / texture / drone / retro at line 1631).
- **Persistence keys** (Settings):
  - `epistemos.ambientFrequencies.presetID` ✅
  - `epistemos.ambientFrequencies.durationMinutes` ✅
  - `epistemos.ambientFrequencies.customMixEnabled` ✅
  - `epistemos.ambientFrequencies.activeModuleIds` ✅
  - Live-player state — **NOT persisted** (see P1-2 below).

## Findings

### P0 — blockers

None identified from static + structural review. Confirmation requires
audio-on-device verification (deferred to next iter once a render harness
ships).

### P1 — must-fix

**P1-1 — Live-player error messages mis-routed into Export section.**

`AmbientFrequencySettingsView.swift:219-221` writes the result of a failed
`livePlayer.start()` into `exportStatus`. `exportStatus` is rendered inside
the **Export** section at line 196-198, far below the Play button. A user
clicking Play and hitting an audio-engine error would see the error text
appear in an unrelated section, with no visual link to the trigger control.

- **Fix**: introduce a separate `livePlayerStatus: String?` shown immediately
  beneath the Play button. Keep `exportStatus` Export-only.
- **Repro**: revoke microphone+audio entitlement or force `AVAudioFormat`
  init to fail (e.g., 0-channel output route), click Play, observe error
  appearing under Export instead of beside Play.

**P1-2 — Live-player parameter state does not survive relaunch.**

§4.C step 7 (Persistence) requires "Per-layer pan + bit-crush + SRR state
must survive a relaunch." The base preset / module set is persisted via
`@AppStorage`, but the **live-player** controls are all `@State`:

| State | File:line | Persisted? |
|---|---|---|
| `liveFrequencySliderPosition` | line 23 | ❌ |
| `livePan` | line 24 | ❌ |
| `liveGain` | line 25 | ❌ |
| `liveWaveform` | line 26 | ❌ |
| `liveBitCrush` | line 27 | ❌ |
| `liveSampleRateHold` | line 28 | ❌ |

- **Fix**: promote all six to `@AppStorage` under the
  `epistemos.ambientFrequencies.live*` keyspace. Waveform stores raw `Int`
  via `rawValue`/`init?(rawValue:)`. All other knobs are `Double` (slider
  precision compatible).
- **Repro**: open Ambient Frequencies, drag bit-crush slider to 4, switch
  to Triangle, quit + relaunch — sliders reset to their `@State` defaults
  (16-bit, Sine, etc).

**P1-3 — AVAudioEngine continues rendering when view disappears.**

`livePlayer` is `@State` and survives view life-cycle until the SwiftUI
state-store drops it. The view has no `.onDisappear { livePlayer.stop() }`,
so navigating to a different Settings tab while playback is active leaves
the engine and source node running — wasting CPU + leaking audio session
ownership. Idempotency of `start()`/`stop()` is already implemented in
`AmbientFrequencyLivePlayer:101-172`, so the fix is purely the view-side
hook.

- **Fix**: add `.onDisappear { livePlayer.stop(); livePlayerRunning = false }`
  on the `Form`.
- **Repro**: Play → switch Settings tab → audio audibly continues.

### P2 — nice-to-have

**P2-1 — Slider VoiceOver value not explicitly bound to display label.**

Sliders rely on SwiftUI's default `accessibilityValue` (raw numeric). VoiceOver
users scrubbing the frequency, pan, gain, bit-depth, and sample-rate-hold
sliders hear e.g. "0.55" instead of "440 Hz" / "Center" / "8-bit (NES/Amiga)".
Driver step 5 mandates VoiceOver labels for every slider.

- **Fix**: add `.accessibilityValue(...)` on each slider with the same
  formatted string already shown in the adjacent `LabeledContent`.
- **Repro**: enable VoiceOver, focus the frequency slider, hear the raw
  slider position rather than the Hz value.

**P2-2 — `bitDepthLabel` has gaps at 2/3/5/6/7/9-11/13-15.**

`bitDepthLabel(_:)` at line 437 falls through to "Nbit" for unlabeled
values. Acceptable, but the slider with `step: 1, range: 1...16` exposes
all integers — a richer table is straightforward.

- **Suggested**: add "3-bit (telephony μ-law era)", "12-bit (SNES era)" etc.
  Low priority.

**P2-3 — `PixelCrunchBadge` color depends on the system accent.**

Line 484 fills the pixel-art glyph with `.color(.accentColor)`. On graphite
or low-saturation accents, the badge loses the retro neon read. Driver
step 6 (pixel-art crisp + WCAG AA contrast) is mostly safe — the badge is
adjacent to text and `.accessibilityHidden(true)` — but a fixed retro hue
(e.g., a pixel-green) would honor the "PIXEL CRUNCH" brand reliably.

- **Suggested**: keep accentColor, layer a brand-color stroke; or guard
  contrast with a luminance check.

**P2-4 — Driver step 1 (computer-use) not exercised this iter.**

`Epistemos/Omega/Vision/VisualVerifyLoop.swift` exists but no
`computer-use` MCP is bound in this session. Visual screenshots deferred.
Documented for follow-up.

## Strengths (validated; preserve)

These passed the audit cleanly — recording them so we don't regress.

- **Click-free design verified statically**: the phase accumulator in
  `LivePlayer.renderBlock` (line 302-303) never resets on frequency change;
  one-pole IIR smoothers absorb parameter jumps
  (`AmbientFrequencyLivePlayer.swift:295-298`).
- **Equal-power pan matches W3C Web Audio §6.3.3** on both the offline
  engine (`AmbientFrequencyAudioGenerator.swift:2138-2147`) and the live
  player (lines 358-361). Constant-power invariant `L² + R² = 1`.
- **Bit-crush midrise quantization** matches musicdsp.org #124 on both
  paths (Generator 2111-2115; LivePlayer 350-353). `bitDepth=1` yields 2
  levels → audible square crush, not silent.
- **Real-time render block contract honored**: no allocations, no locks,
  no Swift class-method dispatch on the audio thread
  (LivePlayer 125-153 + 281-372).
- **`start()` / `stop()` are idempotent** (LivePlayer 101-102, 164-165).
- **Base preset + module set persist via `@AppStorage`** (Settings
  6-13) — survives relaunch.
- **`@unchecked Sendable` on `LivePlayerParameters` is justified inline**
  via the ARM64v8 atomic-Float guarantee + smoother coverage (lines
  229-232).

## Action taken this iter (additive only)

- Filed this audit doc.
- Applied P1-1, P1-2, P1-3 fixes additively (see commit).
- Added `EpistemosTests/UIUX_AmbientFrequencies_Persistence_Tests.swift`
  pinning the new `@AppStorage` keys (Swift Testing style).
- Did **not** delete or alter any preset, primitive, or existing public
  API.

## Carry-overs

- P2-1, P2-2, P2-3 deferred to a follow-up iter (smaller, isolated fixes).
- Visual / computer-use verification deferred until a computer-use MCP is
  bound in T6.
- Iter 2: deep audit of `AmbientFrequencyLivePlayer` (audio-thread DC drift,
  bit-crush + SRR composition, scrub click-free verification).
