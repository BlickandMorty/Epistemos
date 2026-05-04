# Landing Liquid-Wave Search — Implementation Plan

> **Index status**: CANONICAL-OPERATIONAL — GPU Metal ASCII liquid-wave search surface (HomeView redesign) — 160×80 grid @ <1ms GPU per frame on M-series.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Date**: 2026-04-24
**Author**: Claude (Opus 4.7)
**Status**: Green-lit by user; Codex gave go-ahead. Implementation starts immediately after this doc.
**Branch**: spawn `feature/landing-liquid-wave` from current `codex/runtime-input-audit` HEAD (`70c98ea2`).

---

## 0. Anti-Collision Notice (for Codex, future me, anyone else)

**I am implementing only the files enumerated in §11 — `File Plan`.** All other code is off-limits. The uncommitted working-tree changes in these 4 files are Codex's in-progress work and I will not touch them:

- `Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos-AppStore.xcscheme`
- `Epistemos/Sync/NoteFileStorage.swift`
- `EpistemosTests/NoteSavingAuditTests.swift`
- `syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.rlib`

Commits will use **explicit path staging** (`git add <path>` per file) — never `git add -A` / `git add .` — so Codex's pending work stays in the working tree untouched until it's ready.

**All other search/input bars in the app are explicitly off-limits.** See §4 "Off-Limits Surfaces."

---

## 1. Executive Summary

Redesign HomeView's landing "click-anywhere-to-search" as a GPU-rendered ASCII liquid-wave surface with a compact flat bar that emerges from the wave at the click location like a sign lifted from a pool.

- **Stack**: Metal compute + fragment shader for the wave, SwiftUI for the bar chrome, `NSHapticFeedbackManager` for the haptic beat. **No Rust for this path** — FFI per-frame marshalling defeats the 16ms budget.
- **Scope**: only `Epistemos/Views/Landing/` — specifically the click handler and popover content in `LandingView.swift`. No other bar, composer, or input surface is modified.
- **Aesthetic**: minimal but opulent. Flat chrome (no vibrancy, no native NSPopover). Liquid-drop choreography with Worthington jet beat.
- **Performance contract**: zero idle cost, vsync-locked via `CAMetalDisplayLink`, paused under `windowOccluded`, fully collapsed under `accessibilityReduceMotion`.

---

## 2. Goals

1. Click anywhere on the empty landing surface → 3D-feeling ASCII wave ripples outward from click point (anisotropic, not a bullseye).
2. A compact flat search bar emerges from the wave at the click location with realistic "object pulled from water" physics (surface tension trail, snap, drip-back).
3. Font: SF Mono 14pt (down from 22pt). Max width: ~520pt (down from 900pt). Flat chrome, no native popover.
4. Haptic beat mirrors the visual decay on Magic Trackpad.
5. Note titles ride wave crests where amplitude exceeds a threshold (resurrecting an old beloved detail).
6. 60fps sustained at 160×80 ASCII grid on M-series Macs with <1ms GPU per frame.
7. Full `accessibilityReduceMotion` + `windowOccluded` compliance.

## 3. Non-Goals

- **Do not** touch any other input bar (ChatInputBar, MiniChat, HologramSearch, Notes sidebar, TaskInput, QuickCapture, ProseEditor title, command palette).
- **Do not** modify `ChatComposerTextEditor`, `ChatComposerInputMetrics`, `ChatComposerLayout`.
- **Do not** alter `PhysicsModifiers.swift` beyond optionally adding one new modifier at the bottom (preserve everything else — `ASCIIRippleText` etc. are in use elsewhere).
- **Do not** change `LandingShortcutDisplay` (shortcut pill sizing). Keep the existing shortcut pills and greeting.
- **Do not** introduce new third-party dependencies. Native Metal + AppKit + SwiftUI only.
- **Do not** introduce new Rust code. The `agent_core` crate is untouched.
- **Do not** break the existing `@`-mention picker, context attachments, `AssistantSendButton`, or submit path — these wrap around the new bar unchanged.

---

## 4. Off-Limits Surfaces (scope guard)

**These search/composer/input bars exist elsewhere. None of them are modified by this work.** Any PR diff that touches these is a bug in the implementation.

| Surface | File | Purpose |
|---|---|---|
| Chat composer | `Epistemos/Views/Chat/ChatInputBar.swift` | Main chat input |
| Mini chat | `Epistemos/Views/Chat/MiniChatView.swift` | Compact chat dock |
| Graph search | `Epistemos/Views/Graph/HologramSearchSidebar.swift` | Graph node finder |
| Notes search | `Epistemos/Views/Notes/NotesSidebar.swift` | `TextField("Search notes…")` |
| Task input | `Epistemos/Views/Omega/TaskInputBar.swift` | Omega task queue |
| Quick capture | `Epistemos/Views/Shared/QuickCaptureView.swift` | ⌘⇧N popover |
| Prose title | `Epistemos/Views/Notes/ProseEditorView.swift` | Markdown H1 |

Shared primitives (`ChatComposerTextEditor`, `ChatComposerInputMetrics`, `ComposerReferencePopover`, `AssistantSendButton`) remain **unchanged**. The landing bar still uses these so mentions/send work identically — only the *container chrome* and *size* are reskinned.

---

## 5. Architecture

### 5.1 Stack Rationale

| Layer | Tool | Why |
|---|---|---|
| Wave physics | Metal compute shader | 2D height field = textbook compute workload. `MTLComputePipelineState` dispatched once, ping-pong textures. |
| ASCII render | Metal fragment shader + glyph atlas | Alacritty/Kitty technique: rasterize each char once into an atlas, sample by height. <1ms for 160×80 grid. |
| Bar chrome | SwiftUI | Flat design is trivial; `ZStack + RoundedRectangle + 1pt stroke`. |
| Click detection | SwiftUI `.onTapGesture(coordinateSpace:)` | Already in place at `LandingView.swift:179`. Preserved. |
| Haptics | `NSHapticFeedbackManager.defaultPerformer` | App pattern. Chained `.levelChange` + `.alignment` fires. |

**Why not Rust for the wave**: UniFFI marshalling per-frame costs ~100µs round-trip for even small payloads. At 60fps that's 6% of our budget burned before any work. Rust is brilliant for the agent loop and logic but is the wrong tool for pixel pipelines. The Apple GPU is two metres away from the Rust process and one metre from Metal — use the shorter path.

### 5.2 Ping-Pong Texture Pattern

Two `MTLTexture` objects, `rFormat = .r32Float` (single height channel), size = grid resolution (default 160×80). Each tick:

```
t=N:   compute shader reads texture[prev], writes texture[curr]
t=N+1: compute shader reads texture[curr], writes texture[prev]
```

Pair ping-pongs. No copies, no allocations per frame. `MTLResourceStorageMode.private` for GPU-only textures.

**Source**: [Metal Best Practices — Ping-Pong](https://medium.com/@mateusz.kosikowski/image-processing-in-metal-part-2-processing-steps-and-playing-ping-pong-with-textures-e6f51d236d81), [Apple Metal Best Practices Guide](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/).

### 5.3 Frame Pipeline

```
CAMetalDisplayLink tick
  ↓
Inject any pending drop impulses (from Swift → uniform buffer)
  ↓
Compute pass: update height field (wave equation + damping + impulse)
  ↓
Compute pass: compute luminance from height + gradient (for 3D shading)
  ↓
Render pass: fragment shader samples glyph atlas by luminance → draws ASCII
  ↓
Present drawable
```

Uniform buffer (triple-buffered per Apple best practice) carries:
- `time` (float)
- `dropCount` (uint, up to 8)
- `drops[8]` = `(x, y, birthTime, strength)` each
- `waveParams` (c, damping, dx)
- `barRect` (for the "water parts around the bar" behaviour)

---

## 6. Water Physics

### 6.1 Linear Wave Equation (Finite-Difference Time Domain)

Discretized 2D wave equation — the standard textbook form used by every WebGL ripple demo:

```
h[x, y, t+1] = 2·h[x, y, t] − h[x, y, t−1]
             + c² · (h[x−1, y, t] + h[x+1, y, t] + h[x, y−1, t] + h[x, y+1, t] − 4·h[x, y, t])
             − damping · (h[x, y, t] − h[x, y, t−1])
```

- `c` — wave speed. 0.3 for visible-but-not-snappy propagation. CFL stability requires `c² ≤ 0.5` for 4-neighbour.
- `damping` — 0.995 per tick. Too high = instant dead pool. Too low = ringing that never settles.
- Ping-pong provides `h[t]` and `h[t−1]`; we write `h[t+1]`.

Explicit scheme is fine at our grid size; implicit would need iterative solvers that aren't worth it.

**Source**: [2D wave equation FDTD](https://beltoforion.de/en/recreational_mathematics/2d-wave-equation.php), [WebGL Ripples](https://github.com/m-ender/webgl-ripples).

### 6.2 Anisotropic Ripple (the "origin feels real" detail)

To avoid the Mario-bullseye look, impulse injection is anisotropic:

```
impulse[x, y] = strength
              · exp(−(dx² + dy²) / radius²)     // Gaussian falloff
              · (1 + 0.4 · cos(θ − φ_click))    // forward bias
```

Where `θ` is the angle from click point and `φ_click` is a direction inferred from cursor motion (captured as `lastCursorVelocity`). Ripple is stronger along cursor's forward axis, weaker perpendicular. Falls back to isotropic if no recent motion.

### 6.3 Drop Impact Choreography (~550ms total)

Based on fluid-dynamics literature of droplet-into-deep-pool impact — we model a stylised caricature that hits the beats viewers recognise, not a full Navier-Stokes sim.

**Sources for physics**: [Analysis of high-speed drop impact onto deep liquid pool (JFM)](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/analysis-of-highspeed-drop-impact-onto-deep-liquid-pool/EA1176C1DB539BBAB00F3EDA2FF151B9), [Initiation of the Worthington jet on droplet impact (arXiv 1712.06800)](https://arxiv.org/abs/1712.06800), [FYFD Worthington jet tag](https://fyfluiddynamics.com/tagged/worthington-jet/).

| t | beat | what the shader does |
|---|------|----------------------|
| 0ms | **impact flash** | inject +4.0 peak height at click, 1 cell, 1 frame — reads as a bright caustic |
| 30ms | **splash crown** | ring of 6–8 smaller positive impulses at radius=3 cells in a partial arc (facing cursor direction) |
| 60ms | **crater** | inject −2.5 negative impulse at click — height field dips; dark sparse chars collapse inward |
| 120ms | **Worthington jet** | single tall positive pulse at centre (+3.0), 2-cell radius, narrow vertical Gaussian; reads as `┃` column |
| 200ms | **secondary droplet** | tiny positive impulse 3 cells above click, quickly re-injected as falling `·` in the sprite layer |
| 250ms | **concentric waves** | natural propagation of all prior impulses (no new injection) — anisotropic ripple now visible |
| 350ms | **bar rim emergence** | draw ASCII box-drawing rim around `barRect`; simultaneously bar `opacity` 0→0.3 |
| 480ms | **chrome fade** | SwiftUI bar chrome opacity 0.3 → 1.0; water trail column (§8.4) begins its snap |
| 550ms | **settle** | ambient micro-wave (0.05 amplitude) begins; bar focused for input |

After `t=550ms` the ambient micro-wave continues indefinitely at trivial GPU cost — the pool is never fully still. Pauses on `windowOccluded`.

### 6.4 Note-Title Riders

A vector of `(text, x, y)` triples is bound per frame. The fragment shader checks if the current cell falls inside any title's bounding box AND the local height exceeds a threshold (e.g., `|h| > 0.15`). If so, it samples the title's glyph instead of the luminance-mapped wave glyph. Titles "ride" the crests — visible when the wave is at that location, invisible when flat.

Titles are sampled from `SDPage.recentDescriptor(limit: 8)` — pulled once at view-appear, not re-queried per frame.

---

## 7. Rendering Model

### 7.1 Glyph Atlas

Build once at startup. For the wave character ramp, we need only ~12 distinct chars; for the box-drawing rim, another ~16; for note titles, the full Latin range.

- Base font: `NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)` → SF Mono 14pt
- Atlas: 2048×512 RGBA8, 32×16px cells, ~1024 slots
- Rendered via `CTFontCreateWithName` + `CGBitmapContext` at app startup, uploaded to `MTLTexture` once
- Indexed by `(glyphIndex, cellU, cellV)` in a uniform lookup table

**Source**: [Alacritty announcement / technique](https://jwilm.io/blog/announcing-alacritty/), [Zutty compute-shader rendering](https://tomscii.sig7.se/2020/11/How-Zutty-works).

### 7.2 Luminance Ramp → Char

Density-sorted ASCII ramp (12 entries, wave-facing):

```
Index: 0     1  2  3  4  5  6  7  8  9  10 11
Char:  ' '   ·  .  -  ~  :  +  *  ░  ▒  ▓  █
```

Fragment shader formula per cell:

```
h        = sample heightTexture at (x, y)
shaded   = h + 0.3 · gradientY            // fake 3D shading: brighter on wave faces
index    = clamp(round(shaded · 11), 0, 11)
glyph    = glyphAtlas.uv(rampIndices[index])
color    = mix(theme.fontBase, theme.fontAccent, saturate(h))
output   = sampleGlyph(glyph, cellUV) · color
```

### 7.3 Performance Budget

| Item | Target |
|---|---|
| GPU compute pass | <0.3ms |
| GPU render pass | <0.4ms |
| CPU prep | <0.5ms |
| Total per frame | <1.2ms (7% of 16.7ms vsync budget) |
| Memory | 2× 160×80×4B textures = 100KB + 2MB atlas |

Grid resolution auto-adapts to window size (target: ~1 cell per 7pt horizontally, 1 per 14pt vertically = monospace aspect). On a 1400×900 window → ~200×64 grid.

---

## 8. Bar Design

### 8.1 Dimensions (compact spec)

| Property | Old | New |
|---|---|---|
| Max width | 900pt | 520pt |
| Min width | — | 420pt |
| Height | ~68pt (22pt font + padding) | 44pt |
| Corner radius | 24 | 12 |
| Input font | `.system(size: 22, weight: .regular)` | SF Mono 14pt (`AppDisplayTypography.monospace(size: 14)`) |
| Horizontal padding | 24 | 14 |
| Top/bottom padding | 20 / 18 | 10 / 10 |
| Control row spacing | 8 | 6 |

### 8.2 Flat Chrome

- **Fill**: `theme.surfaceBase.opacity(0.98)` (solid, not translucent). NO `.ultraThinMaterial`.
- **Border**: `1pt stroke` in `theme.fontAccent.opacity(0.28)`.
- **No** inner shadow, no glow, no rounded-corner bloom.
- **Cursor**: reuse the block cursor from `LiquidGreeting` (13×2pt rect, SF Mono-sized).
- **Placeholder**: `theme.mutedForeground.opacity(0.55)`.
- **Pills** (mode/model selectors): rect with 1pt border, no capsule blur. Padding 6×2.

### 8.3 Emergence Choreography

Before the bar is visible, a brief ASCII box-drawing rim is painted into the wave buffer itself for 150ms:

```
┌──────────────────────────────────┐
│                                  │
└──────────────────────────────────┘
```

These characters go into a separate "sprite layer" that the fragment shader composites over the wave (higher z). Characters: `┌┐└┘─│`.

SwiftUI chrome crossfades from `opacity: 0, offset: +14pt` to `opacity: 1, offset: 0` over 200ms using `Motion.settle` (spring(0.35, 0.65) — slight overshoot). Scale starts at 0.92 and springs to 1.0.

### 8.4 Water Trail (the "object pulled from water" detail)

While the bar is between 50% and 100% emerged (`t=300ms..480ms`):
- A column of `│` / `┃` chars is injected into the wave height buffer just below the bar's bottom edge
- Height values decay over time as surface tension gives up
- At `t=420ms` — **the snap moment** — the column breaks: height field values along the column are zeroed in segments, with a brief negative pulse at the break point (droplets falling back)
- 2–3 sprite-layer `·` chars fall at 1.5 cells/frame into the wave below

This is the signature moment — the frame where surface tension loses to gravity. Must be worth watching in slow-mo.

---

## 9. Haptics

Three-pulse damped beat on Magic Trackpad / Force Touch trackpad. Silent on external mouse (acceptable fallback).

```swift
// t=0ms — impact
performer.perform(.levelChange, performanceTime: .now)

// t=120ms — Worthington jet (the rebound thump)
performer.perform(.alignment, performanceTime: .now + 0.12)

// t=300ms — primary wave crest
performer.perform(.levelChange, performanceTime: .now + 0.30)
```

Haptic dispatcher is a new landing-scoped helper (`LandingWaveHaptics`) — **does not** modify the global `HapticHelper` enum used by sidebar/streaming haptics.

No haptic fires if:
- `accessibilityReduceMotion` is enabled
- `ui.windowOccluded`
- User setting `epistemos.landingHapticsEnabled` is false (new defaults key, defaults to true)

---

## 10. Accessibility

- Every timed animation guarded by `@Environment(\.accessibilityReduceMotion)`.
- Reduce-motion collapse: no wave at all, no drop, no emergence — bar fades in at click point over 120ms (`Motion.smooth`).
- Note-title riders: hidden to screen readers (`.accessibilityHidden(true)`) — they're decorative.
- Click target: full landing surface remains a single hit region; keyboard-triggered search (`⌘F` etc.) bypasses the animation entirely and focuses the bar instantly.
- `windowOccluded` gate: Metal renderer pauses `CAMetalDisplayLink` when window loses focus.

---

## 11. File Plan

### 11.1 New files (I will create)

| Path | Purpose |
|---|---|
| `Epistemos/Shaders/LandingWave.metal` | Compute + fragment shaders for wave + ASCII render |
| `Epistemos/Views/Landing/Wave/LandingWaveRenderer.swift` | `MTKView`-hosted renderer, owns textures, pipeline, uniforms |
| `Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift` | `NSViewRepresentable` wrapping `MTKView` + delegate |
| `Epistemos/Views/Landing/Wave/LandingWaveGlyphAtlas.swift` | Build glyph atlas from `NSFont` → `MTLTexture` at startup |
| `Epistemos/Views/Landing/Wave/LandingWaveChoreography.swift` | Timing constants, impulse sequences, `dropEvent` factory |
| `Epistemos/Views/Landing/Wave/LandingWaveHaptics.swift` | Three-pulse beat dispatcher, accessibility guards |
| `Epistemos/Views/Landing/Wave/LandingWaveOverlay.swift` | SwiftUI container replacing `.appKitPopover(...)` path |
| `Epistemos/Views/Landing/Wave/CompactFlatSearchBar.swift` | Reskinned bar chrome around existing `ChatComposerTextEditor` |
| `Epistemos/Views/Landing/Wave/LandingWaveDesign.swift` | Enum with compact dimensions (new `LandingWaveSearchLayout`) |
| `EpistemosTests/LandingWaveChoreographyTests.swift` | Unit tests for impulse timings + reduce-motion collapse |
| `EpistemosTests/LandingWaveGlyphAtlasTests.swift` | Atlas build determinism test |

### 11.2 Modified files (I will edit)

| Path | Nature of change |
|---|---|
| `Epistemos/Views/Landing/LandingView.swift` | Replace `.appKitPopover(isPresented:location:) { ... }` attached to the tap-gesture `Color.clear` with `.overlay { LandingWaveOverlay(...) }`. Preserve all existing state vars (`landingSearchText`, attachments, mention picker). |
| `Epistemos.xcodeproj/project.pbxproj` | Add new source files (via xcodegen re-run — CLAUDE.md: *never edit `.xcodeproj` directly*) |

### 11.3 Explicitly NOT modified

- `Epistemos/Theme/PhysicsModifiers.swift` (preserve `ASCIIRippleText` and friends — still used elsewhere)
- `Epistemos/Theme/EpistemosTheme.swift` (Motion tokens reused as-is)
- `Epistemos/Views/Landing/LiquidGreeting.swift` (typewriter greeting unchanged)
- `Epistemos/Views/Chat/ChatInputBar.swift` and all other composers
- `Epistemos/Views/Landing/SessionIntelligenceOverlay.swift`, `WorkspaceSwitcherOverlay.swift`, `TimeMachineView.swift`, `QuitSavePanelController.swift`
- The Rust `agent_core` crate — no changes
- `project.yml` — xcodegen template unchanged; `xcodegen` CLI invocation adds the files

---

## 12. Implementation Phases

Each phase gets its own commit. Never batch.

| # | Phase | Verify |
|---|-------|--------|
| 1 | Branch + shader stub (compiles, black screen) | `xcodebuild build` |
| 2 | Glyph atlas builder + test | `swift test --filter LandingWaveGlyphAtlasTests` |
| 3 | Wave compute shader + ping-pong (no input; see test impulse) | Runtime: click landing, see wave propagate |
| 4 | Fragment shader + luminance ramp (ASCII visible) | Runtime: see ASCII ripple on click |
| 5 | Drop-impact choreography (full 550ms sequence) | Runtime: see splash → jet → settle |
| 6 | Anisotropic ripple bias | Runtime: drag then click — ripple leans forward |
| 7 | Compact flat bar chrome (SwiftUI) + emergence spring | Runtime: bar rises at click point |
| 8 | Water-trail column + snap | Runtime: observe snap at t=420ms |
| 9 | Note-title riders | Runtime: recent note titles visible on crests |
| 10 | Haptic three-pulse beat | Runtime: on trackpad, feel beat |
| 11 | Reduce-motion + windowOccluded guards | `accessibilityReduceMotion` collapses to fade |
| 12 | Full build + test suite | `xcodebuild build 2>&1 \| xcbeautify`, `swift test` |

---

## 13. Verification Gates

Before marking the plan complete:

- [ ] `xcodebuild -scheme Epistemos -destination 'platform=macOS' build` succeeds, zero warnings new.
- [ ] `swift test` — full suite passes; zero regressions from the 2,679-test baseline.
- [ ] `cargo test --manifest-path agent_core/Cargo.toml` — unchanged (I touch no Rust).
- [ ] Runtime: cold launch → landing → click empty area → wave + bar emerge + haptic beat.
- [ ] Runtime: System Preferences → Accessibility → Reduce Motion ON → no wave, no drop, bar fades instantly.
- [ ] Runtime: Cmd+Tab away (window occluded) → wave pauses (no CPU/GPU activity visible in Instruments).
- [ ] Runtime: type `@` in landing bar → mention picker still works (existing path preserved).
- [ ] Runtime: click in main chat composer → `ChatInputBar` unaffected (no new animation, no changed size).
- [ ] Grep check: `grep -R "LandingSearchLayout" Epistemos/Views/Chat/` returns zero (scope isolation).

---

## 14. Commit Plan (per user memory: commit after every change)

Conventional-commit style. Every phase = one commit with the verification output in the message body.

```
feat(landing-wave): 01 scaffold Metal shader + glyph atlas
feat(landing-wave): 02 wave compute + ping-pong textures
feat(landing-wave): 03 ASCII fragment shader + luminance ramp
feat(landing-wave): 04 anisotropic ripple + drop choreography
feat(landing-wave): 05 compact flat bar + emergence spring
feat(landing-wave): 06 water-trail column + snap moment
feat(landing-wave): 07 note-title riders + recent-page query
feat(landing-wave): 08 three-pulse haptic beat
feat(landing-wave): 09 reduce-motion + occluded-window guards
feat(landing-wave): 10 swap LandingView popover path behind the overlay
```

Each commit uses `git add <specific paths>` — never `git add -A`.

---

## 15. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Glyph atlas sampling on non-monospace system fonts introduces jitter | Hard-wire SF Mono via `NSFont.monospacedSystemFont` — never trust the theme font |
| `CAMetalDisplayLink` availability gate (macOS 14+) | App minimum target is macOS 14+ (CLAUDE.md §MCP). If earlier target reintroduced, fall back to `CVDisplayLink` |
| User clicks near a window edge — bar clips | `clamp(barRect.origin, safeArea.origin, safeArea.size − barRect.size)` before emergence |
| Multiple rapid clicks stack impulses beyond uniform capacity (8 drops) | Ring-buffer oldest drop if over capacity |
| Landing `@`-mention popover interaction with overlay z-ordering | Mention popover already uses `.overlay(alignment: .topLeading)` — stack under `LandingWaveOverlay` at higher zIndex |
| Note-title query performance | `SDPage.recentDescriptor(limit: 8)` once per overlay open, cached to view state |

---

## 16. External References (research sources)

- **Water wave physics**:
  - [2D wave equation FDTD](https://beltoforion.de/en/recreational_mathematics/2d-wave-equation.php)
  - [WebGL Ripples (linear wave eq in shader)](https://github.com/m-ender/webgl-ripples)
  - [NVIDIA GPUGems Ch.1: Effective Water Simulation](https://developer.nvidia.com/gpugems/gpugems/part-i-natural-effects/chapter-1-effective-water-simulation-physical-models)
  - [Dynamic Water (pool ripple demo)](https://john-wigg.dev/DynamicWaterDemo/)
- **Droplet impact / Worthington jet**:
  - [Initiation of the Worthington jet on droplet impact (arXiv)](https://arxiv.org/abs/1712.06800)
  - [Analysis of high-speed drop impact onto deep liquid pool (JFM)](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/analysis-of-highspeed-drop-impact-onto-deep-liquid-pool/EA1176C1DB539BBAB00F3EDA2FF151B9)
  - [FYFD Worthington jet tag](https://fyfluiddynamics.com/tagged/worthington-jet/)
  - [Numerical Simulations of Droplet Impact onto a Pool Surface](https://dcwan.sjtu.edu.cn/userfiles/3118-20DCW-0051.pdf)
- **GPU terminal/glyph rendering**:
  - [Announcing Alacritty](https://jwilm.io/blog/announcing-alacritty/)
  - [Zutty: rendering a terminal with a compute shader](https://tomscii.sig7.se/2020/11/How-Zutty-works)
- **Metal + SwiftUI**:
  - [A Beginner's Guide to Metal Shaders in SwiftUI](https://medium.com/@garejakirit/a-beginners-guide-to-metal-shaders-in-swiftui-5e98ef3cb222)
  - [MetalKit in SwiftUI (Apple Dev Forums)](https://developer.apple.com/forums/thread/119112)
  - [Metal Best Practices — Triple Buffering](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/TripleBuffering.html)
  - [Metal Best Practices — Persistent Objects](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/MTLBestPracticesGuide/PersistentObjects.html)
  - [Image Processing in Metal — Ping-Pong Textures](https://medium.com/@mateusz.kosikowski/image-processing-in-metal-part-2-processing-steps-and-playing-ping-pong-with-textures-e6f51d236d81)
  - [Inferno — Metal shaders for SwiftUI (reference repo)](https://github.com/twostraws/Inferno)

---

## 17. Internal References (in-repo)

- `Epistemos/Views/Landing/LandingView.swift:160-230` — current click handler + NSPopover mount
- `Epistemos/Views/Landing/LandingView.swift:411-590` — current `landingSearchPopoverContent` (will be reused, wrapped in new chrome)
- `Epistemos/Theme/PhysicsModifiers.swift:185-214` — `SpringEntranceModifier` reused for bar emergence
- `Epistemos/Theme/EpistemosTheme.swift:1577-1591` — `Motion.{settle, elastic, smooth, micro, sharp}` reused
- `Epistemos/Views/Graph/MetalGraphView.swift` — existing Metal-in-SwiftUI pattern reference
- `Epistemos/Engine/MLXInferenceService.swift` — existing `MetalRuntimeManager` reference (for `MTLDevice` acquisition)
- `Epistemos/Shaders/ThinkingGlow.metal` — existing Metal shader reference (scaffolding pattern)
- Memory: `project_landing_wave_redesign.md` (high-level design)

---

## 18. When This Plan Is "Done"

This doc is the contract. Deviations require either:
1. An edit to this doc explaining the change, OR
2. A deliberate decision recorded in the commit message body.

Never silently drift from this plan. Codex, future-me, and any reviewer should be able to read this doc and know exactly what the landing wave should feel like, why each decision was made, and what is in vs. out of scope.
