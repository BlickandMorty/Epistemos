# UI/UX Audit — AmbientFrequencyLivePlayer (real-time engine)

- **Auditor**: Codex T6 (codex/t6-uiux-2026-05-16)
- **Date**: 2026-05-17 (iter 2, depends on iter 1 audit doc)
- **Driver**: `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.C
- **Surface under audit**:
  - `Epistemos/Engine/AmbientFrequencyLivePlayer.swift` (384 LOC)
- **Companion audit**: `docs/audits/UI_UX_AmbientFrequencies_2026-05-17.md`
  covered the Settings view + generator; this iter focuses on the live
  AVAudioEngine player's render contract.
- **Verification mode**: Static review + numerical reasoning. Audio output
  capture is gated by the same env constraint logged in the iter-1 audit
  (no computer-use MCP, pre-existing main-broken `ContradictionFfi`
  typealias preventing a full xcodebuild). `cargo build -p agent_core`
  green; live-player code itself is pure Swift and compiles in isolation
  per the xcodebuild log (only error is the unrelated vault typealias).

## What this engine guarantees (and the audit traced)

The header doc at `AmbientFrequencyLivePlayer.swift:4-54` makes five
explicit claims. Each was traced to its implementation:

| Claim | Implementation | Verdict |
|---|---|---|
| Click-free freq changes via single phase accumulator (NCO/DDS) | `LivePlayerParameters.phase: Double` at line 261; advanced as `phase += smoothedFrequency / sampleRate` then `phase -= floor(phase)` (line 302-303). Phase never reset on parameter change. | ✅ |
| One-pole IIR smoothers (20 ms gain/pan, 80 ms freq) | `precomputeSmootherCoefficients` lines 273-279 with `α = exp(-1 / (τ·sampleRate))` per textbook IIR; applied per sample lines 295-298. At sampleRate=48000 and τ=0.020s, `α ≈ 0.99896` → ~20 ms 1/e time → matches the comment. | ✅ |
| SwiftUI ↔ audio thread bridge via plain Float reads/writes | `LivePlayerParameters: @unchecked Sendable`, ARM64v8 naturally-aligned single-copy atomicity for 32-bit values. Smoother absorbs tearing. See P2-2 below — same applies to the 64-bit `Int` parameters (`waveform`, `bitCrushDepth`, `sampleRateHold`), which ARM64v8 also guarantees atomic, but the doc comment only calls out 32-bit. | ✅ (correctness) / P3 (doc clarity) |
| Equal-power pan matches W3C Web Audio §6.3.3 | Line 358-361: `panX = (smoothedPan + 1) * 0.5`, `leftGain = cos(panX·π/2)`, `rightGain = sin(panX·π/2)`. `cos² + sin² = 1` ⇒ constant-power. Matches `AmbientFrequencyAudioGenerator.applyEqualPowerPan`. | ✅ |
| Real-time render block honors the no-allocations/no-locks contract | Lines 125-153 (Swift closure) and 281-372 (renderBlock) use only pointer arithmetic, scalar math, and primitive properties. No `print`, no Swift class method dispatch, no allocator calls. | ✅ |

## Findings

### P0 — blockers

None.

### P1 — must-fix

None unique to the live player. The user-facing P1s for this surface
(error-routing, state persistence, engine cleanup on view dismiss) all
landed in the iter-1 commit and apply via the Settings view that hosts
this player.

### P2 — defer (logged for follow-up iters)

**P2-1 — SRR `holdCounter` not reset when `sampleRateHold` changes mid-render.**

When the user drags the sample-rate-hold slider from e.g. 8 → 16 while
the held counter is mid-cycle (say counter = 3), the next ≤12 samples
output the stale `heldSample` from the previous setting before the
counter cycles back through zero and refreshes from the live waveform.
Audible glitch on SRR transitions.

- Repro: enable Play, drag SRR slider rapidly while a non-trivial
  signal is active. Listen for stair-step "stutter" instead of a smooth
  resolution shift.
- Fix sketch (single-file, additive):

  ```swift
  // In LivePlayerParameters:
  private var lastSeenSampleRateHold: Int = 1

  // In renderBlock, before the SRR branch:
  let hold = sampleRateHold
  if hold != lastSeenSampleRateHold {
      holdCounter = 0
      lastSeenSampleRateHold = hold
  }
  ```

- Not P1 because the dominant use case is set-and-leave; the audit
  spec (§4.C step 3) names "live frequency mod" as the click-free
  invariant, not SRR-scrub.

**P2-2 — Audible click on bit-crush / waveform / SRR step change.**

Unlike `gain`, `pan`, and `frequency`, the discrete parameters
`bitCrushDepth`, `sampleRateHold`, and `waveform` are applied
**instantly** in the render block (lines 305-353). Stepping the
bit-crush slider 16 → 8 changes the quantization grid in one sample,
producing a transient when a sample lands inside the new step's
boundary. Same for waveform Sine → Square (sample values diverge by
up to 2.0) and SRR 1 → 16 (next sample becomes a held value possibly
far from the current waveform output).

- Fix sketch: linearly crossfade between "old-quantized" and
  "new-quantized" outputs over ~20 ms when the parameter changes,
  reusing the gain smoother's α. For waveform: dual-render the old +
  new waveform during the crossfade window. Cost: ~5x render math
  during a transition; acceptable for the user-facing benefit.
- Not P1 because §4.C step 3 names frequency-scrub click-freeness as
  the invariant. Bit-crush/SRR transitions are step-quantized by
  design (1-bit slider increments).

**P2-3 — No handler for sample-rate route change (headphone unplug).**

`precomputeSmootherCoefficients(sampleRate:)` runs **once** during
`start()` (line 121). If macOS switches the audio route mid-playback
(unplug headphones → speaker, or 44.1 → 48 kHz), AVAudioEngine
internally restarts the chain but this code does not re-derive `α`.
The smoother time constants effectively scale with the new sample
rate, so a 20 ms target becomes ~22 ms or ~18 ms — not perceptible
to most users, but a precision defect.

- Fix sketch: observe `AVAudioEngineConfigurationChange`
  notifications (`NotificationCenter` on `AVAudioEngine`), call
  `engine.stop() / engine.start()` and re-run `precomputeSmoother…`.
- Defer: AVAudioEngine typically rebuilds on its own; impact is sub-ms
  time-constant drift.

**P2-4 — `smoothedFrequencyForUI` exposed but unread by the Settings UI.**

`AmbientFrequencyLivePlayer.currentSmoothedFrequency` (line 220) is
read in no SwiftUI view. The Settings view displays `liveFrequencyHz`
computed from the slider position — the engine's *target* — not the
smoothed actual value the user is hearing. Mild UX cost: during an
80 ms freq glide, the displayed value jumps but the audible value
arrives smoothly.

- Fix sketch: poll `livePlayer.currentSmoothedFrequency` via a
  `TimelineView(.periodic(1/30))` and show both the target and the
  current value while the smoother lags. Mostly informational; not on
  the §4.C audit gate.

### P3 — micro-nits

- **P3-1**: Header comment at line 28 mentions "Naturally-aligned 32-bit
  reads/writes are atomic on Apple Silicon" but the same guarantee
  extends to 64-bit values, which include the `Int` parameters here
  (`waveform`, `bitCrushDepth`, `sampleRateHold`). Comment expansion
  would harden the rationale.

- **P3-2**: 1-bit `bitCrush` produces three output levels (-1, 0, +1)
  rather than the two suggested by the "PC speaker beeper" comment
  (line 205). This is canonical musicdsp.org #124 midrise — the cited
  reference — so the implementation is correct; only the comment is
  loose.

- **P3-3**: Noise PRNG output range is `[-1.0, +0.99999988]` (line 326)
  — slightly asymmetric. Bias is ~1.2e-7, well below the 24-bit float
  noise floor. Pure micro-nit.

## Strengths (validated; preserve)

- Phase accumulator is `Double`, increments by `smoothedFrequency /
  sampleRate`, and is wrapped via `phase -= floor(phase)` — both
  bounded (no drift over multi-hour renders) and click-free under any
  frequency change (line 302-303).
- One-pole IIR α derived from `exp(-1 / (τ · fs))` — textbook musicdsp
  / Steinberg / Audio EQ Cookbook formula. Coefficient stored as
  Float; no allocation per sample.
- All three smoothers (`smoothedFrequency`, `smoothedPan`,
  `smoothedGain`) honor the same one-pole structure. No mismatched
  filter orders.
- Mute is implemented as a gain-target of zero with full smoothing
  (line 200-202) — no abrupt cuts, no phase reset.
- Real-time render block emits zero allocations / locks / Swift class
  dispatches. Verified line-by-line against the comment contract on
  line 53-54.
- Render block fallback path (line 131-138) zeroes all output buffers
  on the unexpected `bufferList.count < 2` case rather than producing
  garbage — defensive but cheap.
- `start()` and `stop()` are idempotent at lines 102 + 165, supporting
  the Settings-view `.onDisappear { livePlayer.stop() }` hook landed in
  iter 1.

## Numerical sanity (no audio device required)

- Bit-crush `levels = 2^(bits-1)` with midrise rounding maps symmetric
  input [-1, +1] to symmetric output — no DC drift across the full
  bit-depth range. Confirmed by inspection of
  `(sample * levels).rounded() / levels` for `bits ∈ [1, 16]`.
- Equal-power pan `cos² + sin² = 1` invariant holds by trig identity;
  no constant-power slip across `pan ∈ [-1, +1]`.
- Phase accumulator at `sampleRate = 48 kHz, frequency = 440 Hz`
  increments by 0.009167 per sample; Double mantissa precision
  (~2.2e-16 relative) drops 1 ULP every ~22 trillion samples
  (~14 years of continuous audio). Wrap via `floor` keeps phase
  bounded.

## Action taken this iter

- Filed this iter-2 audit doc.
- **No code edits this iter.** P1-class items are exhausted on this
  surface; P2 fixes (SRR `holdCounter` reset, switch-click crossfade,
  route-change resilience) are deferred per the driver's "fix P0/P1
  in place" guidance.
- Carry-overs flagged above for future iters or for a
  performance/audio-quality sub-mission.

## Carry-overs

- P2-1 through P2-4 above.
- Iter 3 candidates: F-VaultRecall-50 surface (when T4 lands),
  Settings → Diagnostics rows (most-recently-edited UI area).
