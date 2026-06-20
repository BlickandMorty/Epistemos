# SS-AN — Homepage→graph "fold/squish" transition glitch → native Apple-blur-replace (2026-06-20)

Owner (verbatim): *"on the homepage when I click the Home graph the animation is weird… it's like the transition…
that entire page kind of like squishes… I want that whole animation to be more native — the buttons do an Apple
blur replace, they blur, they disappear, and the only thing left is the graph… it shouldn't do the popping and
pop out… just have the buttons blur and disappear, and the sidebar button, the toolbar button at the bottom, and
then the graph itself just blurry reappear, fast motion… all the things on the homepage/landing should just blur,
no flicker, no folding animation. That folding animation is a big glitch — a really important hardening and repair."*
A REPAIR (high priority). Code-grounded. Cross-ref SS-U (dark/light WKWebView crash) for the "don't destroy+rebuild
NSView on toggle" lesson.

## Root cause (the fold/squish IS this)
The home content is a `ZStack` view-swap keyed on `ui.homeContent` (`.greeting`/`.graph`,
`State/UIState.swift:360-365`), router at `Views/Landing/LandingView.swift:361-377`. The glitch = a **`.scale`
transition driven by a spring, applied to BOTH branches, animated TWICE**:
1. Greeting branch `.transition(.opacity.combined(with: .scale(scale: 0.94)))` — `LandingView.swift:367-369`.
2. Graph branch `.transition(.opacity.combined(with: .scale(scale: 0.94)))` — `LandingView.swift:373-375`.
3. Driver spring `.animation(.spring(response:0.42,dampingFraction:0.84,blendDuration:0.1), value: ui.homeContent)`
   — `LandingView.swift:459-462`.
4. **DOUBLE-FIRE:** `setEmbeddedGraphVisible` ALSO wraps the same `ui.homeContent` mutation in its own
   `withAnimation(.spring(...))` — `App/EpistemosApp.swift:1137` (trigger path: graph tile `LandingView.swift:891-899`
   → `toggleGraphForCurrentLocation()` `:2507` → `KnowledgeGraphShortcutDispatcher.toggle` `EpistemosApp.swift:1043`
   → `setEmbeddedGraphVisible` `:1125-1141`). The mutation animates once by `withAnimation` + once by the view's
   `.animation(value:)` → classic double-fire flicker.

**Why it folds:** `.scale(0.94)` animates the WHOLE page's rendered geometry 94%↔100%; the full-bleed
`MetalGraphRepresentable` canvas + `GeometryReader`-positioned inspector (`Views/Home/HomeGraphEmbeddedView.swift:187`)
re-measure mid-spring; spring overshoot + a Metal `NSView` that doesn't scale in lockstep = visible fold/squish.

**Secondary flicker sources:**
- 420 ms `Task.sleep` gate before `embeddedCanvasReady=true` (`HomeGraphEmbeddedView.swift:350-358`) → graph blank
  during scale-in, then pops.
- Two racing fade systems: SwiftUI `.opacity` (0.42 s spring) vs AppKit `view.animator().alphaValue` easeOut 0.32 s
  (`HomeGraphEmbeddedView.swift:404-420`).
- Toolbar reveal gated by a separate 350 ms delay (`App/RootView.swift:321-332`) + `toolbarGlassVisible`
  (`RootView.swift:242-248`).

## The buttons the owner means
Top toolbar (sidebar + settings): `RootView` `.toolbar` `:287-312`; `sidebar.left` History button `:505-519`;
settings/greeting ControlGroup `rootToolbarControls` `:448-503`; gated by `showLandingToolbarControls` `:228-232` /
`embeddedHomeGraphContentVisible` (they hard-cut today, no transition). Bottom command dock `landingPixelCommands`
inside `greetingContent` (`LandingView.swift:685`) — already rides the greeting transition.

## Fix plan — single fast easeOut blur-replace, no scale, no double-fire, no race
1. **Kill the fold:** delete `.combined(with: .scale(scale: 0.94))` at `LandingView.swift:368` AND `:374`.
2. **Kill the double-fire:** remove the `withAnimation(.spring(...))` wrapper in `setEmbeddedGraphVisible`
   (`EpistemosApp.swift:1137`); let the single view-level `.animation(value: ui.homeContent)` own timing.
3. **Blur-replace transitions** (add a tiny reusable `BlurFadeModifier` = `.blur(radius:)`+`.opacity()`; the `.blur`
   primitive is already used at `LandingView.swift:364`):
   - Greeting (outgoing) `:367-369`: `.asymmetric(insertion:.opacity, removal:.modifier(active: BlurFade(blur:18,
     opacity:0), identity: BlurFade(blur:0,opacity:1)))` — buttons/greeting blur away.
   - Graph (incoming) `:373-375`: `.asymmetric(insertion:.modifier(active: BlurFade(blur:14,opacity:0),
     identity: BlurFade(blur:0,opacity:1)), removal:.opacity)` — graph blur-reappears fast.
4. **Flat fast driver** (no spring overshoot = no pop): `LandingView.swift:459-462` →
   `.animation(reduceMotion ? nil : .easeOut(duration:0.28), value: ui.homeContent)`.
5. **Buttons blur out (not hard-cut):** keep the toolbar items mounted; drive their `.blur(radius:)`+`.opacity` from
   `embeddedHomeGraphContentVisible` with the same `.easeOut(0.28)` (`RootView.swift:448` `rootToolbarControls`).
6. **Remove the graph pop-in + AppKit race:** shorten/drop the 420 ms gate (`HomeGraphEmbeddedView.swift:350-353`)
   so the canvas is ready as it blurs in; remove the separate `NSAnimationContext` alpha fade (`:404-420`) — set
   `view.alphaValue = 1.0` immediately and let SwiftUI own the one fade (this is the main flicker source: 0.28 vs
   0.32 s timelines).

**Perf caveat (verify):** SwiftUI `.blur` over the live `MetalGraphRepresentable` (`NSViewRepresentable`) may stutter.
If so, keep greeting/buttons on the SwiftUI blur path but drive the GRAPH's blur via its Metal view's
`layer.filters` / `CIFilter` (Gaussian) instead of SwiftUI `.blur`. Test on-device.

## Ordered build steps
1. [S] Steps 1–2 (delete `.scale`, remove the double `withAnimation`) — kills the fold immediately. Single targeted
   swift build.
2. [S] Steps 3–4 (`BlurFadeModifier` + asymmetric blur transitions + flat easeOut driver).
3. [S] Step 5 (toolbar buttons blur out via `embeddedHomeGraphContentVisible`).
4. [S] Step 6 (drop pop-in gate + AppKit alpha race).
5. Honest witness: this is a VISUAL repair the headless loop can't fully verify — mark the "feels native, no
   flicker" confirmation PENDING OWNER VERIFICATION (on-device); ship the code + a snapshot/logic test where
   possible (e.g. assert no `.scale` in the transition, reduceMotion path nil), no green-without-witness.

Key files: `Views/Landing/LandingView.swift:361-377,459-462,685,891-899,2507` · `App/EpistemosApp.swift:1043,1125-1141`
· `App/RootView.swift:228-232,242-248,287-312,321-332,448-519` · `Views/Home/HomeGraphEmbeddedView.swift:187,350-358,
404-420`. Cross-ref SS-U, SS-SH (perf discipline).
